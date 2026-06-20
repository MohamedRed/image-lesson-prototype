import Combine
import Foundation
import LiveKitCore

// MARK: - Public API

public protocol DebateServicing: Sendable {
    // Publishers
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
    var debateEvents: AnyPublisher<DebateEvent, Never> { get }
    var timelineEvents: AnyPublisher<TimelineEvent, Never> { get }
    var factCheckResults: AnyPublisher<FactCheckResult, Never> { get }
    var participantTracks: AnyPublisher<[ParticipantTrack], Never> { get }
    var isMicrophoneEnabled: AnyPublisher<Bool, Never> { get }
    var isCameraEnabled: AnyPublisher<Bool, Never> { get }
    
    // Lifecycle
    func joinDebate(debateId: String, role: DebateRole) async throws
    func leaveDebate()
    func toggleMicrophone() async
    func toggleCamera() async
    func shareScreen() async throws
    func stopScreenShare() async
    
    // Timeline
    func addTimelineEvent(_ event: TimelineEventInput) async throws
    func requestFactCheck(eventId: String) async throws
    
    // Debate Management
    func createDebate(_ config: DebateConfig) async throws -> String
    func listDebates() async throws -> [DebateInfo]
}

// MARK: - Data Models

public enum DebateRole: String, Codable {
    case debater
    case moderator
    case spectator
}

public enum ConnectionState: Equatable {
    case connecting
    case connected
    case reconnecting
    case disconnected
    case failed(String)
}

public enum DebateEvent: Equatable {
    case debateStarted
    case debateEnded
    case speakerChanged(participantId: String, name: String)
    case participantJoined(participantId: String, name: String, role: DebateRole)
    case participantLeft(participantId: String)
    case moderatorAction(type: ModeratorActionType, targetId: String?)
    case error(String)
}

public enum ModeratorActionType: String, Equatable {
    case mute
    case unmute
    case removeParticipant
    case pauseDebate
    case resumeDebate
}

public struct TimelineEvent: Equatable, Identifiable {
    public let id: String
    public let debaterId: String
    public let debaterName: String
    public let title: String
    public let description: String
    public let date: Date
    public let historicalDate: String // e.g., "1776-07-04"
    public let sources: [String]
    public var factCheckStatus: FactCheckStatus
    public let createdAt: Date
}

public enum FactCheckStatus: String, Equatable, Codable {
    case pending
    case verified
    case disputed
    case false_claim = "false"
    case needsSource
    case unknown
}

public struct FactCheckResult: Equatable {
    public let eventId: String
    public let status: FactCheckStatus
    public let explanation: String?
    public let sources: [String]
    public let confidence: Double
}

public struct ParticipantTrack: Identifiable {
    public let id: String
    public let participantId: String
    public let participantName: String
    public let role: DebateRole
    public let audioTrack: Any?
    public let videoTrack: Any?
    public let isScreenShare: Bool
}

public struct TimelineEventInput {
    public let title: String
    public let description: String
    public let historicalDate: String
    public let sources: [String]
    
    public init(title: String, description: String, historicalDate: String, sources: [String]) {
        self.title = title
        self.description = description
        self.historicalDate = historicalDate
        self.sources = sources
    }
}

public struct DebateConfig {
    public let title: String
    public let description: String
    public let category: String
    public let maxDebaters: Int
    public let isPublic: Bool
    public let scheduledAt: Date?
    
    public init(title: String, description: String, category: String, 
                maxDebaters: Int = 4, isPublic: Bool = true, scheduledAt: Date? = nil) {
        self.title = title
        self.description = description
        self.category = category
        self.maxDebaters = maxDebaters
        self.isPublic = isPublic
        self.scheduledAt = scheduledAt
    }
}

public struct DebateInfo: Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let category: String
    public let hostName: String
    public let participantCount: Int
    public let maxDebaters: Int
    public let isLive: Bool
    public let scheduledAt: Date?
    public let thumbnailUrl: String?
}