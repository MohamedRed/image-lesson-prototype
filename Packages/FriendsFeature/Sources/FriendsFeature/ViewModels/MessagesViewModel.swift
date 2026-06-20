import Foundation
import Combine
import FriendsService

@MainActor
class MessagesViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var typingUsers: [String] = []
    @Published var isTyping = false {
        didSet {
            if isTyping != oldValue {
                Task {
                    try? await friendsService.setTyping(in: conversationId, isTyping: isTyping)
                }
            }
        }
    }
    
    private let conversationId: String
    private let friendsService: FriendsServicing
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?
    
    init(conversationId: String, friendsService: FriendsServicing) {
        self.conversationId = conversationId
        self.friendsService = friendsService
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Subscribe to messages
        friendsService.getMessages(for: conversationId, limit: 50)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] messages in
                    self?.messages = messages.sorted { $0.createdAt < $1.createdAt }
                }
            )
            .store(in: &cancellables)
        
        // Subscribe to typing users
        friendsService.getTypingUsers(in: conversationId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userIds in
                guard let self = self else { return }
                // Filter out current user
                self.typingUsers = userIds.filter { $0 != self.friendsService.currentUserId }
            }
            .store(in: &cancellables)
        
        // Auto-stop typing after a delay
        $isTyping
            .debounce(for: .seconds(3), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isTyping = false
            }
            .store(in: &cancellables)
    }
}

// MARK: - Contact Import ViewModel

@MainActor
class ContactsImportViewModel: ObservableObject {
    @Published var contacts: [ContactInfo] = []
    @Published var matchedUsers: [MatchedContact] = []
    @Published var isLoading = false
    @Published var hasRequestedPermission = false
    @Published var errorMessage: String?
    
    private let friendsService: FriendsServicing
    
    init(friendsService: FriendsServicing) {
        self.friendsService = friendsService
    }
    
    func requestContactsPermission() {
        // TODO: Implement contacts permission request
        hasRequestedPermission = true
    }
    
    func loadContacts() {
        // TODO: Load contacts from device
        contacts = [] // Placeholder
    }
    
    func findMatchingUsers() async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let phoneNumbers = contacts.compactMap { $0.phoneNumber }
        
        do {
            matchedUsers = try await friendsService.findUsersByContacts(phoneNumbers)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

struct ContactInfo {
    let name: String
    let phoneNumber: String?
}