import Combine
import Foundation
import LiveKitCore
import FirebaseFirestore
import FirebaseAuth

@MainActor
public final class DebateLiveKitService: DebateServicing {
    // MARK: - Public Publishers
    
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
        core.isMicrophoneEnabled 
    }
    
    public var isCameraEnabled: AnyPublisher<Bool, Never> { 
        _isCameraEnabled.eraseToAnyPublisher() 
    }
    
    // MARK: - Private Properties
    
    private let core: LiveKitCoreServicing
    private let apiBaseURL: URL
    private let db = Firestore.firestore()
    
    private let _connectionState = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let _debateEvents = PassthroughSubject<DebateEvent, Never>()
    private let _timelineEvents = PassthroughSubject<TimelineEvent, Never>()
    private let _factCheckResults = PassthroughSubject<FactCheckResult, Never>()
    private let _participantTracks = CurrentValueSubject<[ParticipantTrack], Never>([])
    private let _isCameraEnabled = CurrentValueSubject<Bool, Never>(false)
    
    private var currentDebateId: String?
    private var currentRole: DebateRole?
    private var cancellables = Set<AnyCancellable>()
    private var timelineListener: ListenerRegistration?
    private var factCheckListener: ListenerRegistration?
    
    // MARK: - Initialization
    
    public init(apiBaseURL: URL) {
        self.apiBaseURL = apiBaseURL
        self.core = LiveKitCoreService(apiBaseURL: apiBaseURL, feature: "debate")
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    public func joinDebate(debateId: String, role: DebateRole) async throws {
        currentDebateId = debateId
        currentRole = role
        
        _connectionState.send(.connecting)
        
        do {
            // Start LiveKit connection
            try await core.start()
            
            // Setup listeners for this debate
            setupDebateListeners(debateId: debateId)
            
            // Register RPC handlers for debate-specific features
            try await registerDebateRPCHandlers()
            
            _connectionState.send(.connected)
            _debateEvents.send(.debateStarted)
            
        } catch {
            _connectionState.send(.failed(error.localizedDescription))
            throw error
        }
    }
    
    public func leaveDebate() {
        core.stop()
        cleanupListeners()
        currentDebateId = nil
        currentRole = nil
        _connectionState.send(.disconnected)
        _debateEvents.send(.debateEnded)
    }
    
    public func toggleMicrophone() async {
        await core.toggleMicrophone()
    }
    
    public func toggleCamera() async {
        // TODO: Implement camera toggle when video support is added
        _isCameraEnabled.send(!_isCameraEnabled.value)
    }
    
    public func shareScreen() async throws {
        // TODO: Implement screen sharing
    }
    
    public func stopScreenShare() async {
        // TODO: Stop screen sharing
    }
    
    public func addTimelineEvent(_ event: TimelineEventInput) async throws {
        guard let debateId = currentDebateId,
              let userId = Auth.auth().currentUser?.uid else {
            throw DebateError.notInDebate
        }
        
        let eventData: [String: Any] = [
            "debaterId": userId,
            "debaterName": Auth.auth().currentUser?.displayName ?? "Anonymous",
            "title": event.title,
            "description": event.description,
            "historicalDate": event.historicalDate,
            "sources": event.sources,
            "factCheckStatus": FactCheckStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("debates").document(debateId)
            .collection("timeline").addDocument(data: eventData)
    }
    
    public func requestFactCheck(eventId: String) async throws {
        guard let debateId = currentDebateId else {
            throw DebateError.notInDebate
        }
        
        // Trigger fact check by updating the event
        try await db.collection("debates").document(debateId)
            .collection("timeline").document(eventId)
            .updateData(["requestFactCheck": true])
    }
    
    public func createDebate(_ config: DebateConfig) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw DebateError.notAuthenticated
        }
        
        let debateData: [String: Any] = [
            "title": config.title,
            "description": config.description,
            "category": config.category,
            "hostId": userId,
            "hostName": Auth.auth().currentUser?.displayName ?? "Anonymous",
            "maxDebaters": config.maxDebaters,
            "isPublic": config.isPublic,
            "isLive": false,
            "participantCount": 0,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        if let scheduledAt = config.scheduledAt {
            var data = debateData
            data["scheduledAt"] = Timestamp(date: scheduledAt)
            let doc = try await db.collection("debates").addDocument(data: data)
            return doc.documentID
        } else {
            let doc = try await db.collection("debates").addDocument(data: debateData)
            return doc.documentID
        }
    }
    
    public func listDebates() async throws -> [DebateInfo] {
        let snapshot = try await db.collection("debates")
            .whereField("isPublic", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            return DebateInfo(
                id: doc.documentID,
                title: data["title"] as? String ?? "",
                description: data["description"] as? String ?? "",
                category: data["category"] as? String ?? "",
                hostName: data["hostName"] as? String ?? "",
                participantCount: data["participantCount"] as? Int ?? 0,
                maxDebaters: data["maxDebaters"] as? Int ?? 4,
                isLive: data["isLive"] as? Bool ?? false,
                scheduledAt: (data["scheduledAt"] as? Timestamp)?.dateValue(),
                thumbnailUrl: data["thumbnailUrl"] as? String
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        core.connectionState
            .map { state -> ConnectionState in
                switch state {
                case .connecting: return .connecting
                case .connected, .connectedNoAgent: return .connected
                case .reconnecting: return .reconnecting
                case .disconnected: return .disconnected
                case .failed(let msg): return .failed(msg)
                }
            }
            .sink { [weak self] state in
                self?._connectionState.send(state)
            }
            .store(in: &cancellables)
    }
    
    private func setupDebateListeners(debateId: String) {
        // Listen to timeline events
        timelineListener = db.collection("debates").document(debateId)
            .collection("timeline")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                for doc in documents {
                    let data = doc.data()
                    let event = TimelineEvent(
                        id: doc.documentID,
                        debaterId: data["debaterId"] as? String ?? "",
                        debaterName: data["debaterName"] as? String ?? "",
                        title: data["title"] as? String ?? "",
                        description: data["description"] as? String ?? "",
                        date: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        historicalDate: data["historicalDate"] as? String ?? "",
                        sources: data["sources"] as? [String] ?? [],
                        factCheckStatus: FactCheckStatus(rawValue: data["factCheckStatus"] as? String ?? "") ?? .pending,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                    self?._timelineEvents.send(event)
                }
            }
        
        // Listen to fact check results
        factCheckListener = db.collection("debates").document(debateId)
            .collection("factChecks")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                for doc in documents {
                    let data = doc.data()
                    let result = FactCheckResult(
                        eventId: data["eventId"] as? String ?? "",
                        status: FactCheckStatus(rawValue: data["status"] as? String ?? "") ?? .unknown,
                        explanation: data["explanation"] as? String,
                        sources: data["sources"] as? [String] ?? [],
                        confidence: data["confidence"] as? Double ?? 0.0
                    )
                    self?._factCheckResults.send(result)
                }
            }
    }
    
    private func registerDebateRPCHandlers() async throws {
        // Register handlers for moderator actions, fact-check requests, etc.
        try await core.registerRpcMethod("moderatorAction") { data in
            // Handle moderator actions
            return "{\"success\": true}"
        }
    }
    
    private func cleanupListeners() {
        timelineListener?.remove()
        factCheckListener?.remove()
        timelineListener = nil
        factCheckListener = nil
    }
}

// MARK: - Error Types

public enum DebateError: LocalizedError {
    case notInDebate
    case notAuthenticated
    case invalidRole
    case debateFull
    
    public var errorDescription: String? {
        switch self {
        case .notInDebate:
            return "You must be in a debate to perform this action"
        case .notAuthenticated:
            return "You must be signed in to participate"
        case .invalidRole:
            return "Your role doesn't allow this action"
        case .debateFull:
            return "This debate has reached maximum capacity"
        }
    }
}