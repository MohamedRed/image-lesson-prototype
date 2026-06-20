import Combine
@preconcurrency import LiveKit
import Foundation

@MainActor
public protocol LiveKitCoreServicing: Sendable {
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
    var agentAudioTrack: AnyPublisher<Track?, Never> { get }
    var audioTrack: AnyPublisher<Track?, Never> { get }
    var isMicrophoneEnabled: AnyPublisher<Bool, Never> { get }

    func start() async throws
    func stop()
    func toggleMicrophone() async

    // Generic LiveKit handler registration (no knowledge of higher-level packages)
    func registerTextStreamHandler(for topic: String, handler: @escaping @Sendable (TextStreamReader, Participant.Identity) -> Void) async throws
    func registerRpcMethod(_ name: String, handler: @escaping @Sendable (RpcInvocationData) async throws -> String) async throws
}

// Mirror the minimal connection state used across modules
public enum ConnectionState: Equatable {
    case connecting
    case connected
    case connectedNoAgent
    case reconnecting
    case disconnected
    case failed(String)
}

public final class LiveKitCoreService: NSObject, LiveKitCoreServicing {
    public var connectionState: AnyPublisher<ConnectionState, Never> { _connectionState.eraseToAnyPublisher() }
    public var agentAudioTrack: AnyPublisher<Track?, Never> { _agentAudioTrack.eraseToAnyPublisher() }
    public var audioTrack: AnyPublisher<Track?, Never> { _audioTrack.eraseToAnyPublisher() }
    public var isMicrophoneEnabled: AnyPublisher<Bool, Never> { _isMicrophoneEnabled.eraseToAnyPublisher() }

    private let room = Room()
    private let apiBaseURL: URL
    private let feature: String

    private let _connectionState = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let _agentAudioTrack = CurrentValueSubject<Track?, Never>(nil)
    private let _audioTrack = CurrentValueSubject<Track?, Never>(nil)
    private let _isMicrophoneEnabled = CurrentValueSubject<Bool, Never>(false)

    private var agentParticipant: Participant?
    private var agentTrackPublication: TrackPublication?

    public init(apiBaseURL: URL, feature: String = "ride-sharing") {
        self.apiBaseURL = apiBaseURL
        self.feature = feature
        super.init()
        room.add(delegate: self)
    }

    public func start() async throws {
        _connectionState.send(.connecting)
        do {
            let details = try await fetchConnectionDetails()
            try await room.connect(url: details.serverUrl, token: details.participantToken)
        } catch {
            _connectionState.send(.failed(error.localizedDescription))
            throw error
        }
    }

    public func stop() {
        Task { await room.disconnect() }
    }

    public func toggleMicrophone() async {
        let participant = room.localParticipant
        let newState = !participant.isMicrophoneEnabled()
        do {
            try await participant.setMicrophone(enabled: newState)
            _isMicrophoneEnabled.send(newState)
        } catch {
            // swallow for now; propagate via state if needed
        }
    }

    // MARK: - Handler registration
    public func registerTextStreamHandler(for topic: String, handler: @escaping @Sendable (TextStreamReader, Participant.Identity) -> Void) async throws {
        try await room.registerTextStreamHandler(for: topic, onNewStream: handler)
    }

    public func registerRpcMethod(_ name: String, handler: @escaping @Sendable (RpcInvocationData) async throws -> String) async throws {
        try await room.registerRpcMethod(name, handler: handler)
    }

    private struct ConnectionDetails: Decodable {
        let serverUrl: String
        let participantToken: String
    }

    private func fetchConnectionDetails() async throws -> ConnectionDetails {
        let url = apiBaseURL.appendingPathComponent("livekitToken")
        
        // Send POST request with feature parameter
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["feature": feature]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ConnectionDetails.self, from: data)
    }
}

extension LiveKitCoreService: @preconcurrency RoomDelegate {
    public func room(_ room: Room, didUpdateConnectionState state: LiveKit.ConnectionState, from _: LiveKit.ConnectionState) {
        switch state {
        case .connected:
            self.agentParticipant = room.agentParticipant
            if let agent = self.agentParticipant {
                self.agentTrackPublication = agent.audioTracks.first
                self._agentAudioTrack.send(self.agentTrackPublication?.track)
                _connectionState.send(.connected)
            } else {
                _connectionState.send(.connectedNoAgent)
            }

            if let localAudio = room.localParticipant.audioTracks.first {
                _audioTrack.send(localAudio.track)
            }
            _isMicrophoneEnabled.send(room.localParticipant.isMicrophoneEnabled())

        case .connecting:
            _connectionState.send(.connecting)
        case .reconnecting:
            _connectionState.send(.reconnecting)
        case .disconnected:
            agentParticipant = nil
            agentTrackPublication = nil
            _agentAudioTrack.send(nil)
            _audioTrack.send(nil)
            _connectionState.send(.disconnected)
        @unknown default:
            break
        }
    }

    public func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        if agentParticipant == nil, let newAgent = room.agentParticipant {
            agentParticipant = newAgent
            if _connectionState.value == .connectedNoAgent { _connectionState.send(.connected) }
        }
    }

    public func room(_ room: Room, participant: RemoteParticipant, didSubscribe trackPublication: TrackPublication, track: Track) {
        if participant.identity == agentParticipant?.identity, track.kind == .audio {
            agentTrackPublication = trackPublication
            _agentAudioTrack.send(track)
        }
    }

    public func room(_ room: Room, participant: RemoteParticipant, didUnsubscribe trackPublication: TrackPublication, track: Track) {
        if participant.identity == agentParticipant?.identity, track.kind == .audio {
            agentTrackPublication = nil
            _agentAudioTrack.send(nil)
        }
    }

    public func room(_ room: Room, participant: Participant, didUpdate track: TrackPublication, isMuted: Bool) {
        if participant is LocalParticipant, track.kind == .audio {
            _isMicrophoneEnabled.send(!isMuted)
            _audioTrack.send(track.track)
        }
    }
}

