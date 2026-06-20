import Combine
import Foundation

public final class MockDebateService: DebateServicing {
    public var connectionState: AnyPublisher<ConnectionState, Never> { 
        _connectionState.eraseToAnyPublisher() 
    }
    
    public var debateEvents: AnyPublisher<DebateEvent, Never> { 
        _debateEvents.eraseToAnyPublisher() 
    }
    
    public var timelineEvents: AnyPublisher<TimelineEvent, Never> { 
        _timelineEvents.eraseToAnyPublisher() 
    }
    
    public var factCheckResults: AnyPublisher<FactCheckResult, Never> { 
        _factCheckResults.eraseToAnyPublisher() 
    }
    
    public var participantTracks: AnyPublisher<[ParticipantTrack], Never> { 
        _participantTracks.eraseToAnyPublisher() 
    }
    
    public var isMicrophoneEnabled: AnyPublisher<Bool, Never> { 
        _isMicrophoneEnabled.eraseToAnyPublisher() 
    }
    
    public var isCameraEnabled: AnyPublisher<Bool, Never> { 
        _isCameraEnabled.eraseToAnyPublisher() 
    }
    
    private let _connectionState = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let _debateEvents = PassthroughSubject<DebateEvent, Never>()
    private let _timelineEvents = PassthroughSubject<TimelineEvent, Never>()
    private let _factCheckResults = PassthroughSubject<FactCheckResult, Never>()
    private let _participantTracks = CurrentValueSubject<[ParticipantTrack], Never>([])
    private let _isMicrophoneEnabled = CurrentValueSubject<Bool, Never>(false)
    private let _isCameraEnabled = CurrentValueSubject<Bool, Never>(false)
    
    private var mockTimer: Timer?
    
    public init() {}
    
    public func joinDebate(debateId: String, role: DebateRole) async throws {
        _connectionState.send(.connecting)
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        _connectionState.send(.connected)
        _debateEvents.send(.debateStarted)
        
        // Simulate participants joining
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self._debateEvents.send(.participantJoined(
                participantId: "alice",
                name: "Alice Johnson",
                role: .debater
            ))
            
            self._participantTracks.send([
                ParticipantTrack(
                    id: "alice",
                    participantId: "alice",
                    participantName: "Alice Johnson",
                    role: .debater,
                    audioTrack: nil,
                    videoTrack: nil,
                    isScreenShare: false
                )
            ])
        }
        
        // Simulate timeline events
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self._timelineEvents.send(TimelineEvent(
                id: "event1",
                debaterId: "alice",
                debaterName: "Alice Johnson",
                title: "Declaration of Independence",
                description: "The founding document that declared American independence",
                date: Date(),
                historicalDate: "1776-07-04",
                sources: ["https://archives.gov/founding-docs"],
                factCheckStatus: .verified,
                createdAt: Date()
            ))
        }
        
        // Simulate fact check result
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            self._factCheckResults.send(FactCheckResult(
                eventId: "event1",
                status: .verified,
                explanation: "The Declaration of Independence was indeed signed on July 4, 1776",
                sources: ["National Archives"],
                confidence: 0.95
            ))
        }
    }
    
    public func leaveDebate() {
        mockTimer?.invalidate()
        mockTimer = nil
        _connectionState.send(.disconnected)
        _debateEvents.send(.debateEnded)
    }
    
    public func toggleMicrophone() async {
        _isMicrophoneEnabled.send(!_isMicrophoneEnabled.value)
    }
    
    public func toggleCamera() async {
        _isCameraEnabled.send(!_isCameraEnabled.value)
    }
    
    public func shareScreen() async throws {
        // Mock implementation
    }
    
    public func stopScreenShare() async {
        // Mock implementation
    }
    
    public func addTimelineEvent(_ event: TimelineEventInput) async throws {
        let newEvent = TimelineEvent(
            id: UUID().uuidString,
            debaterId: "user",
            debaterName: "You",
            title: event.title,
            description: event.description,
            date: Date(),
            historicalDate: event.historicalDate,
            sources: event.sources,
            factCheckStatus: .pending,
            createdAt: Date()
        )
        _timelineEvents.send(newEvent)
        
        // Simulate fact checking after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self._factCheckResults.send(FactCheckResult(
                eventId: newEvent.id,
                status: .verified,
                explanation: "Fact check completed",
                sources: ["Mock verification"],
                confidence: 0.85
            ))
        }
    }
    
    public func requestFactCheck(eventId: String) async throws {
        // Simulate fact check request
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self._factCheckResults.send(FactCheckResult(
                eventId: eventId,
                status: .verified,
                explanation: "Re-verified successfully",
                sources: ["Additional source"],
                confidence: 0.90
            ))
        }
    }
    
    public func createDebate(_ config: DebateConfig) async throws -> String {
        return "mock-debate-\(UUID().uuidString.prefix(8))"
    }
    
    public func listDebates() async throws -> [DebateInfo] {
        return [
            DebateInfo(
                id: "debate1",
                title: "Climate Change Solutions",
                description: "Discussing practical approaches to combat climate change",
                category: "Environment",
                hostName: "Dr. Sarah Green",
                participantCount: 3,
                maxDebaters: 4,
                isLive: true,
                scheduledAt: nil,
                thumbnailUrl: nil
            ),
            DebateInfo(
                id: "debate2",
                title: "AI Ethics in Healthcare",
                description: "Exploring the ethical implications of AI in medical diagnosis",
                category: "Technology",
                hostName: "Prof. John Smith",
                participantCount: 2,
                maxDebaters: 4,
                isLive: false,
                scheduledAt: Date().addingTimeInterval(3600),
                thumbnailUrl: nil
            ),
            DebateInfo(
                id: "debate3",
                title: "Universal Basic Income",
                description: "Pros and cons of implementing UBI",
                category: "Economics",
                hostName: "Maria Rodriguez",
                participantCount: 4,
                maxDebaters: 4,
                isLive: true,
                thumbnailUrl: nil
            )
        ]
    }
}