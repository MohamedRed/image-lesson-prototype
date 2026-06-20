import Foundation
import Combine
import FriendsService

@MainActor
public class FriendsViewModel: ObservableObject {
    @Published var friends: [FriendProfile] = []
    @Published var friendRequests: [Friendship] = []
    @Published var conversations: [Conversation] = []
    @Published var presenceStatuses: [String: PresenceStatus] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let friendsService: FriendsServicing
    private var cancellables = Set<AnyCancellable>()
    
    public init(friendsService: FriendsServicing = FriendsService()) {
        self.friendsService = friendsService
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Subscribe to friends updates
        friendsService.friends
            .receive(on: DispatchQueue.main)
            .assign(to: \.friends, on: self)
            .store(in: &cancellables)
        
        // Subscribe to friend requests updates
        friendsService.friendRequests
            .receive(on: DispatchQueue.main)
            .assign(to: \.friendRequests, on: self)
            .store(in: &cancellables)
        
        // Subscribe to conversations updates
        friendsService.conversations
            .receive(on: DispatchQueue.main)
            .assign(to: \.conversations, on: self)
            .store(in: &cancellables)
        
        // Subscribe to presence updates
        friendsService.presenceStatuses
            .receive(on: DispatchQueue.main)
            .assign(to: \.presenceStatuses, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    var onlineFriends: [FriendProfile] {
        friends.filter { friend in
            presenceStatuses[friend.id]?.status == .online
        }
    }
    
    var incomingRequests: [Friendship] {
        friendRequests.filter { request in
            request.requestedBy != friendsService.currentUserId && request.status == .pending
        }
    }
    
    var outgoingRequests: [Friendship] {
        friendRequests.filter { request in
            request.requestedBy == friendsService.currentUserId && request.status == .pending
        }
    }
    
    // MARK: - Friend Management
    
    func sendFriendRequest(to userId: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await friendsService.sendFriendRequest(to: userId)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func acceptFriendRequest(_ friendship: Friendship) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await friendsService.acceptFriendRequest(friendship)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func declineFriendRequest(_ friendship: Friendship) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await friendsService.declineFriendRequest(friendship)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func cancelFriendRequest(_ friendship: Friendship) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await friendsService.cancelFriendRequest(friendship)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func blockUser(_ userId: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await friendsService.blockUser(userId)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func unblockUser(_ userId: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await friendsService.unblockUser(userId)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func removeFriend(_ userId: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await friendsService.removeFriend(userId)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Conversation Management
    
    func startConversation(with userIds: [String]) async throws -> Conversation {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            return try await friendsService.createConversation(with: userIds, title: nil)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func createGroupConversation(with userIds: [String], title: String) async throws -> Conversation {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            return try await friendsService.createGroupConversation(with: userIds, title: title)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func sendMessage(to conversationId: String, content: String, type: Message.MessageType = .text) async throws {
        let draft = MessageDraft(type: type, content: content)
        
        do {
            try await friendsService.sendMessage(to: conversationId, draft: draft)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func sendActionCard(to conversationId: String, content: String, actionCard: ActionCardPayload) async throws {
        let actionCardMessage = Message.ActionCard(
            kind: actionCard.kind,
            refId: actionCard.refId,
            refKind: actionCard.kind,
            meta: actionCard.meta
        )
        
        let draft = MessageDraft(
            type: .action,
            content: content,
            action: actionCardMessage
        )
        
        do {
            try await friendsService.sendMessage(to: conversationId, draft: draft)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Search and Discovery
    
    func searchUsers(query: String, limit: Int = 20) async throws -> [FriendProfile] {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            return try await friendsService.searchUsers(query, limit: limit)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func findUsersByContacts(_ phoneNumbers: [String]) async throws -> [MatchedContact] {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let hashedPhones = try await friendsService.hashContacts(phoneNumbers)
            return try await friendsService.findUsersByContacts(hashedPhones)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func getMutualFriends(with userId: String) async throws -> [FriendProfile] {
        do {
            return try await friendsService.getMutualFriends(with: userId, limit: 10)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Presence
    
    func updatePresence(_ status: PresenceStatus.Status) async throws {
        do {
            try await friendsService.updatePresence(status)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func setTyping(in conversationId: String, isTyping: Bool) async throws {
        do {
            try await friendsService.setTyping(in: conversationId, isTyping: isTyping)
        } catch {
            // Don't show typing errors to user
        }
    }
    
    // MARK: - Invites
    
    func generateInviteLink(maxUses: Int = 10, expiresIn: TimeInterval = 604800, context: InviteContext? = nil) async throws -> InviteInfo {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            return try await friendsService.generateInviteLink(maxUses: maxUses, expiresIn: expiresIn, context: context)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func resolveInviteLink(_ code: String) async throws -> InviteInfo {
        do {
            return try await friendsService.resolveInviteLink(code)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func acceptInvite(_ code: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            _ = try await friendsService.acceptInvite(code)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Watch Party
    
    func createWatchParty(in conversationId: String, mediaURL: String? = nil, title: String? = nil) async throws -> (roomName: String, watchPartyId: String) {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            return try await friendsService.createWatchParty(in: conversationId, mediaURL: mediaURL, title: title)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func joinWatchParty(_ conversationId: String) async throws -> (roomName: String, playback: Any) {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            return try await friendsService.joinWatchParty(conversationId)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Utility
    
    func clearError() {
        errorMessage = nil
    }
    
    func getFriend(by id: String) -> FriendProfile? {
        friends.first { $0.id == id }
    }
    
    func getConversation(by id: String) -> Conversation? {
        conversations.first { $0.id == id }
    }
    
    func isOnline(_ userId: String) -> Bool {
        presenceStatuses[userId]?.status == .online
    }
    
    func getPresenceStatus(_ userId: String) -> PresenceStatus.Status {
        presenceStatuses[userId]?.status ?? .offline
    }
}