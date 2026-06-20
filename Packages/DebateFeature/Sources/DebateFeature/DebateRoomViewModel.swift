import Foundation
import Combine
import DebateService

@MainActor
class DebateRoomViewModel: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var participants: [ParticipantTrack] = []
    @Published var timelineEvents: [TimelineEvent] = []
    @Published var factCheckResults: [String: FactCheckResult] = [:]
    @Published var isMicEnabled = false
    @Published var isCameraEnabled = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    let debateId: String
    let role: DebateRole
    let service: DebateServicing
    private var cancellables = Set<AnyCancellable>()
    
    init(debateId: String, role: DebateRole, service: DebateServicing? = nil) {
        self.debateId = debateId
        self.role = role
        
        #if DEBUG
        self.service = service ?? MockDebateService()
        #else
        if let service = service {
            self.service = service
        } else {
            // Read API URL from Info.plist
            let apiURLString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "http://localhost:5001"
            let apiURL = URL(string: apiURLString)!
            self.service = DebateLiveKitService(apiBaseURL: apiURL)
        }
        #endif
        
        setupBindings()
    }
    
    func joinDebate() async {
        do {
            try await service.joinDebate(debateId: debateId, role: role)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func leaveDebate() {
        service.leaveDebate()
    }
    
    func toggleMicrophone() {
        Task {
            await service.toggleMicrophone()
        }
    }
    
    func toggleCamera() {
        Task {
            await service.toggleCamera()
        }
    }
    
    func addTimelineEvent(_ event: TimelineEventInput) async {
        do {
            try await service.addTimelineEvent(event)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func requestFactCheck(for eventId: String) async {
        do {
            try await service.requestFactCheck(eventId: eventId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func setupBindings() {
        // Connection state
        service.connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)
        
        // Participant tracks
        service.participantTracks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tracks in
                self?.participants = tracks
            }
            .store(in: &cancellables)
        
        // Timeline events
        service.timelineEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                // Add or update event
                if let index = self.timelineEvents.firstIndex(where: { $0.id == event.id }) {
                    self.timelineEvents[index] = event
                } else {
                    self.timelineEvents.append(event)
                }
                // Sort by historical date
                self.timelineEvents.sort { $0.historicalDate < $1.historicalDate }
            }
            .store(in: &cancellables)
        
        // Fact check results
        service.factCheckResults
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let self = self else { return }
                self.factCheckResults[result.eventId] = result
                
                // Update the corresponding timeline event
                if let index = self.timelineEvents.firstIndex(where: { $0.id == result.eventId }) {
                    self.timelineEvents[index].factCheckStatus = result.status
                }
            }
            .store(in: &cancellables)
        
        // Microphone state
        service.isMicrophoneEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.isMicEnabled = enabled
            }
            .store(in: &cancellables)
        
        // Camera state
        service.isCameraEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.isCameraEnabled = enabled
            }
            .store(in: &cancellables)
        
        // Debate events
        service.debateEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleDebateEvent(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleDebateEvent(_ event: DebateEvent) {
        switch event {
        case .error(let message):
            errorMessage = message
            showError = true
        case .participantJoined(let id, let name, let role):
            print("Participant joined: \(name) as \(role)")
        case .participantLeft(let id):
            print("Participant left: \(id)")
        case .moderatorAction(let type, let targetId):
            print("Moderator action: \(type) on \(targetId ?? "all")")
        default:
            break
        }
    }
}