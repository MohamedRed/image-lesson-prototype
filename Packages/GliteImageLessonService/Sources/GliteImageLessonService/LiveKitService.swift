import Combine
@preconcurrency import LiveKit
import Foundation

@MainActor
public final class LiveKitService: NSObject, GliteImageLessonServicing {

    // MARK: - Nested Actor for State Management
    
    // This actor is responsible for stitching together transcription fragments
    // that may be sent from LiveKit in multiple parts. By managing a buffer of
    // partial messages, it ensures a smooth, continuous stream of text is
    // delivered to the view model, handling out-of-order or updated segments.
    private actor TranscriptionState {
        private struct PartialMessageID: Hashable {
            let segmentID: String
            let participantID: Participant.Identity
        }

        private struct PartialMessage {
            var content: String
            let timestamp: Date
            var streamID: String

            mutating func appendContent(_ newContent: String) {
                content += newContent
            }

            mutating func replaceContent(_ newContent: String, streamID: String) {
                content = newContent
                self.streamID = streamID
            }
        }
        
        private lazy var partialMessages: [PartialMessageID: PartialMessage] = [:]

        private enum TranscriptionAttributes: String {
            case final = "lk.transcription_final"
            case segment = "lk.segment_id"
        }

        func processIncoming(message: String, reader: TextStreamReader, participantIdentity: Participant.Identity, localParticipantId: Participant.Identity?) -> LessonEvent? {
            let segmentID = reader.info.attributes[TranscriptionAttributes.segment.rawValue] ?? reader.info.id
            let partialID = PartialMessageID(segmentID: segmentID, participantID: participantIdentity)
            let currentStreamID = reader.info.id
            
            let timestamp: Date
            let updatedContent: String

            if var existingMessage = partialMessages[partialID] {
                if existingMessage.streamID == currentStreamID {
                    existingMessage.appendContent(message)
                } else {
                    existingMessage.replaceContent(message, streamID: currentStreamID)
                }
                updatedContent = existingMessage.content
                timestamp = existingMessage.timestamp
                partialMessages[partialID] = existingMessage
            } else {
                updatedContent = message
                timestamp = reader.info.timestamp
                partialMessages[partialID] = PartialMessage(
                    content: updatedContent,
                    timestamp: timestamp,
                    streamID: currentStreamID
                )
                cleanupPreviousTurn(participantIdentity, exceptSegmentID: segmentID)
            }
            
            let isFinal = reader.info.attributes[TranscriptionAttributes.final.rawValue] == "true"
            if isFinal {
                partialMessages[partialID] = nil
            }
            
            if participantIdentity == localParticipantId {
                return .userSaid(updatedContent, isFinal: isFinal)
            } else {
                return .agentSaid(updatedContent, isFinal: isFinal)
            }
        }
        
        private func cleanupPreviousTurn(_ participantID: Participant.Identity, exceptSegmentID: String) {
            let keysToRemove = partialMessages.keys.filter {
                $0.participantID == participantID && $0.segmentID != exceptSegmentID
            }

            for key in keysToRemove {
                partialMessages[key] = nil
            }
        }
    }


    // MARK: - Public Properties

    public var connectionState: AnyPublisher<ConnectionState, Never> {
        _connectionState.eraseToAnyPublisher()
    }

    public var lessonEvents: AnyPublisher<LessonEvent, Never> {
        _lessonEvents.eraseToAnyPublisher()
    }

    public var agentAudioTrack: AnyPublisher<Track?, Never> {
        _agentAudioTrack.eraseToAnyPublisher()
    }

    public var audioTrack: AnyPublisher<Track?, Never> {
        _audioTrack.eraseToAnyPublisher()
    }

    public var isMicrophoneEnabled: AnyPublisher<Bool, Never> {
        _isMicrophoneEnabled.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private let room = Room()
    private let transcriptionState = TranscriptionState()
    private let apiBaseURL: URL

    private let _connectionState = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let _lessonEvents = PassthroughSubject<LessonEvent, Never>()
    private let _agentAudioTrack = CurrentValueSubject<Track?, Never>(nil)
    private let _audioTrack = CurrentValueSubject<Track?, Never>(nil)
    private let _isMicrophoneEnabled = CurrentValueSubject<Bool, Never>(false)

    private var agentParticipant: Participant?
    private var agentTrackPublication: TrackPublication?

    // MARK: - Lifecycle

    /// Creates a new instance of the `LiveKitService`.
    /// - Parameter apiBaseURL: The base URL for the backend API that provides connection details.
    public init(apiBaseURL: URL) {
        self.apiBaseURL = apiBaseURL
        super.init()
        room.add(delegate: self)
    }

    // MARK: - Public Methods

    public func start() async throws {
        _connectionState.send(.connecting)
        
        do {
            // 1. Fetch connection details from our API
            let connectionDetails = try await fetchConnectionDetails()
            
            // 2. Connect to the LiveKit room
            try await room.connect(
                url: connectionDetails.serverUrl,
                token: connectionDetails.participantToken
            )
            
            // 3. Set up data handlers for RPC and transcription
            try await setUpDataHandlers()
            try await registerRpcHandlers()
            
            print("Successfully connected to room: \(connectionDetails.roomName)")
            
        } catch {
            _connectionState.send(.failed(error.localizedDescription))
            throw error
        }
    }

    public func stop() {
        Task {
            await room.disconnect()
            print("Stopping LiveKit Service...")
        }
    }

    public func toggleMicrophone() async {
        let participant = room.localParticipant
        let newMicState = !participant.isMicrophoneEnabled()
        do {
            try await participant.setMicrophone(enabled: newMicState)
            _isMicrophoneEnabled.send(newMicState)
        } catch {
            print("Failed to toggle microphone: \(error)")
        }
    }

    // MARK: - Private Methods

    private func fetchConnectionDetails() async throws -> ConnectionDetails {
        let url = apiBaseURL.appendingPathComponent("connection-details")
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let connectionDetails = try JSONDecoder().decode(ConnectionDetails.self, from: data)
        return connectionDetails
    }

    private func setUpDataHandlers() async throws {
        let transcriptionTopic = "lk.transcription"

        try await room.registerTextStreamHandler(for: transcriptionTopic) { [weak self] reader, participantIdentity in
            guard let self else { return }
            
            Task {
                for try await message in reader where !message.isEmpty {
                    if let event = await self.transcriptionState.processIncoming(
                        message: message,
                        reader: reader,
                        participantIdentity: participantIdentity,
                        localParticipantId: self.room.localParticipant.identity
                    ) {
                        await self._lessonEvents.send(event)
                    }
                }
            }
        }
    }

    private func registerRpcHandlers() async throws {
        // A helper to decode RPC payloads safely
        @Sendable func decodePayload<T: Decodable>(_ data: RpcInvocationData) throws -> T {
            guard let payloadData = data.payload.data(using: .utf8) else {
                throw PayloadError(msg: "Could not get data from payload string")
            }
            return try JSONDecoder().decode(T.self, from: payloadData)
        }

        try await room.registerRpcMethod("image_task") { [weak self] (data: RpcInvocationData) -> String in
            do {
                let payload: ImageTaskPayload = try decodePayload(data)
                if let url = URL(string: payload.url) {
                    await self?._lessonEvents.send(.showLessonImage(url: url))
                }
            } catch { print("Failed to handle image_task RPC: \(error)") }
            return "ack"
        }

        try await room.registerRpcMethod("user_image") { [weak self] (data: RpcInvocationData) -> String in
            do {
                let payload: UserImagePayload = try decodePayload(data)
                if let url = URL(string: payload.url) {
                    await self?._lessonEvents.send(.showUserImage(url: url, id: payload.user_image_id))
                }
            } catch { print("Failed to handle user_image RPC: \(error)") }
            return "ack"
        }
        
        try await room.registerRpcMethod("updating_user_image") { [weak self] (data: RpcInvocationData) -> String in
            do {
                let payload: UpdatingUserImagePayload = try decodePayload(data)
                await self?._lessonEvents.send(.showUserImageLoading(id: payload.user_image_id))
            } catch { print("Failed to handle updating_user_image RPC: \(error)") }
            return "ack"
        }
        
        try await room.registerRpcMethod("similarity_score") { [weak self] (data: RpcInvocationData) -> String in
            do {
                let payload: SimilarityScorePayload = try decodePayload(data)
                await self?._lessonEvents.send(.showSimilarityScore(score: payload.score, bestScore: payload.bestScore, accepted: payload.accepted))
            } catch { print("Failed to handle similarity_score RPC: \(error)") }
            return "ack"
        }
        
        try await room.registerRpcMethod("show_word") { [weak self] (data: RpcInvocationData) -> String in
            do {
                let payload: ShowWordPayload = try decodePayload(data)
                await self?._lessonEvents.send(.highlightWord(payload.word))
            } catch { print("Failed to handle show_word RPC: \(error)") }
            return "ack"
        }
        
        try await room.registerRpcMethod("end_lesson_info") { [weak self] (data: RpcInvocationData) -> String in
            do {
                let payload: EndLessonInfoPayload = try decodePayload(data)
                await self?._lessonEvents.send(.lessonEnded(originalImageDescription: payload.original_image_description))
            } catch { print("Failed to handle end_lesson_info RPC: \(error)") }
            return "ack"
        }
    }
}

// MARK: - API Data Models

struct ConnectionDetails: Decodable {
    let serverUrl: String
    let roomName: String
    let participantName: String
    let participantToken: String
}

// MARK: - RPC Payloads
private struct PayloadError: Error, LocalizedError { let msg: String; var errorDescription: String? { msg } }
private struct ImageTaskPayload: Decodable { let url: String }
private struct UserImagePayload: Decodable { let url: String; let user_image_id: String? }
private struct UpdatingUserImagePayload: Decodable { let user_image_id: String }
private struct SimilarityScorePayload: Decodable { 
    let score: Double
    let bestScore: Double
    let accepted: Bool
}
private struct ShowWordPayload: Decodable { let word: String }
private struct EndLessonInfoPayload: Decodable { let original_image_description: String }


// MARK: - RoomDelegate

extension LiveKitService: @preconcurrency RoomDelegate {
    public func room(_ room: Room, didUpdateConnectionState connectionState: LiveKit.ConnectionState, from oldConnectionState: LiveKit.ConnectionState) {
        switch connectionState {
        case .connected:
            self.agentParticipant = room.agentParticipant
            
            if let agent = self.agentParticipant {
                self.agentTrackPublication = agent.audioTracks.first
                self._agentAudioTrack.send(self.agentTrackPublication?.track)
                _connectionState.send(.connected)
            } else {
                _connectionState.send(.connectedNoAgent)
            }
            
            if let localAudioPublication = room.localParticipant.audioTracks.first {
                self._audioTrack.send(localAudioPublication.track)
            }
            self._isMicrophoneEnabled.send(room.localParticipant.isMicrophoneEnabled())
            
        case .connecting:
            _connectionState.send(.connecting)
            
        case .reconnecting:
            _connectionState.send(.reconnecting)
            
        case .disconnected:
            self.agentParticipant = nil
            self.agentTrackPublication = nil
            self._agentAudioTrack.send(nil)
            self._audioTrack.send(nil)
            _connectionState.send(.disconnected)
            
        @unknown default:
            // Handle future cases gracefully
            print("Unknown connection state: \(connectionState)")
        }
    }
    
    public func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        // After a participant connects, we re-evaluate if the agent is now present using our extension.
        // This removes the duplicate/buggy logic and uses our extension as the single source of truth.
        if self.agentParticipant == nil, let newAgent = room.agentParticipant {
            self.agentParticipant = newAgent

            // If we were waiting for the agent, update the state to fully connected.
            if _connectionState.value == .connectedNoAgent {
                _connectionState.send(.connected)
            }
        }
    }

    public func room(_ room: Room, participant: RemoteParticipant, didSubscribe trackPublication: TrackPublication, track: Track) {
        // If this track belongs to our tracked agent, publish it
        if participant.identity == self.agentParticipant?.identity, track.kind == .audio {
            self.agentTrackPublication = trackPublication
            self._agentAudioTrack.send(track)
        }
    }

    public func room(_ room: Room, participant: RemoteParticipant, didUnsubscribe trackPublication: TrackPublication, track: Track) {
        // If the agent's track was unsubscribed, clear it
        if participant.identity == self.agentParticipant?.identity, track.kind == .audio {
            self.agentTrackPublication = nil
            self._agentAudioTrack.send(nil)
        }
    }

    public func room(_ room: Room, participant: Participant, didUpdate track: TrackPublication, isMuted: Bool) {
        // Update microphone state if it's the local user's audio track
        if participant is LocalParticipant, track.kind == .audio {
            _isMicrophoneEnabled.send(!isMuted)
            _audioTrack.send(track.track)
        }
    }
    
    // We will add more delegate methods here as needed
} 
