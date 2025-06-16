import Combine
import LiveKit
import Foundation

@MainActor
public protocol GliteImageLessonServicing: Sendable {
    /// A stream of connection state updates for the lesson.
    var connectionState: AnyPublisher<ConnectionState, Never> { get }

    /// A stream of data events happening during the lesson.
    var lessonEvents: AnyPublisher<LessonEvent, Never> { get }

    /// A stream of the agent's audio track.
    var agentAudioTrack: AnyPublisher<Track?, Never> { get }

    /// A stream of the local participant's audio track.
    /// Used to power the audio visualizer.
    var audioTrack: AnyPublisher<Track?, Never> { get }

    /// A stream of the microphone enabled state.
    var isMicrophoneEnabled: AnyPublisher<Bool, Never> { get }

    /// Starts the lesson service, connects to the backend, and joins the room.
    /// - Throws: An error if the connection details cannot be fetched or the connection fails.
    @MainActor
    func start() async throws

    /// Stops the lesson service and disconnects from the room.
    @MainActor
    func stop()

    /// Toggles the local participant's microphone on and off.
    @MainActor
    func toggleMicrophone() async
}

// MARK: - Data Models

/// Represents the various states of the connection to the lesson service.
public enum ConnectionState: Equatable {
    case connecting
    case connected
    case connectedNoAgent
    case reconnecting
    case disconnected
    case failed(String)

    public var description: String {
        switch self {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .connectedNoAgent: return "Connected, waiting for agent..."
        case .reconnecting: return "Reconnecting..."
        case .disconnected: return "Disconnected"
        case .failed(let error): return "Failed: \(error)"
        }
    }
}

/// Represents all possible data-driven events that can occur during a lesson,
/// originating from the service layer.
public enum LessonEvent: Equatable {
    /// The agent has spoken.
    case agentSaid(String, isFinal: Bool)
    /// The user has spoken.
    case userSaid(String, isFinal: Bool)
    /// The main lesson image has been received.
    case showLessonImage(url: URL)
    /// An image generated from the user's description has been received.
    case showUserImage(url: URL, id: String?)
    /// A loading indicator should be shown for the user image.
    case showUserImageLoading(id: String)
    /// The similarity score for the user's description has been received.
    case showSimilarityScore(score: Double, bestScore: Double, accepted: Bool)
    /// A specific word should be highlighted in the UI.
    case highlightWord(String)
    /// The lesson has ended. The view model should use this to build and display its own summary.
    case lessonEnded(originalImageDescription: String)
}

/// A data structure holding all the necessary information for the end-of-lesson summary screen.
public struct EndLessonSummary: Codable, Equatable, Identifiable {
    public let id: UUID
    public let originalImageUrl: URL?
    public let originalImageDescription: String
    public let bestUserImageUrl: URL?
    public let bestUserScore: Double?

    public init(id: UUID = UUID(), originalImageUrl: URL?, originalImageDescription: String, bestUserImageUrl: URL?, bestUserScore: Double?) {
        self.id = id
        self.originalImageUrl = originalImageUrl
        self.originalImageDescription = originalImageDescription
        self.bestUserImageUrl = bestUserImageUrl
        self.bestUserScore = bestUserScore
    }
}
