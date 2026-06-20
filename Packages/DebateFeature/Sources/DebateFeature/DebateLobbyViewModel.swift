import Foundation
import Combine
import DebateService

@MainActor
class DebateLobbyViewModel: ObservableObject {
    @Published var debates: [DebateInfo] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let service: DebateServicing
    private var cancellables = Set<AnyCancellable>()
    
    init(service: DebateServicing? = nil) {
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
    }
    
    func loadDebates() async {
        isLoading = true
        errorMessage = ""
        showError = false
        
        do {
            debates = try await service.listDebates()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func createDebate(_ config: DebateConfig) async {
        do {
            let debateId = try await service.createDebate(config)
            // Reload debates to show the new one
            await loadDebates()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func joinDebate(debateId: String, role: DebateRole) async {
        // This would typically navigate to DebateRoomView
        // For now, just attempt to join
        do {
            try await service.joinDebate(debateId: debateId, role: role)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}