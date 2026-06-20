import Foundation
import Combine

public final class MockFriendsService: FriendsServicing {
    public var currentUserId: String? { "current_user" }

    private let friendsSubject = CurrentValueSubject<[FriendProfile], Never>([])
    private let requestsSubject = CurrentValueSubject<[Friendship], Never>([])
    private let conversationsSubject = CurrentValueSubject<[Conversation], Never>([])
    private let presenceSubject = CurrentValueSubject<[String: PresenceStatus], Never>([:])

    public var friends: AnyPublisher<[FriendProfile], Never> { friendsSubject.eraseToAnyPublisher() }
    public var friendRequests: AnyPublisher<[Friendship], Never> { requestsSubject.eraseToAnyPublisher() }
    public var conversations: AnyPublisher<[Conversation], Never> { conversationsSubject.eraseToAnyPublisher() }
    public var presenceStatuses: AnyPublisher<[String : PresenceStatus], Never> { presenceSubject.eraseToAnyPublisher() }

    public init() {
        seed()
    }

    private func seed() {
        let me = "current_user"
        let alex = FriendProfile(id: "friend_1", displayName: "Alex", photoURL: nil, handle: "alex", city: "Rabat")
        let sam  = FriendProfile(id: "friend_2", displayName: "Sam", photoURL: nil, handle: "sam", city: "Casablanca")
        friendsSubject.send([alex, sam])

        presenceSubject.send([
            alex.id: PresenceStatus(userId: alex.id, status: .online, lastActiveAt: Date()),
            sam.id: PresenceStatus(userId: sam.id, status: .away, lastActiveAt: Date().addingTimeInterval(-300))
        ])

        let convo = Conversation(
            id: "c1",
            type: .direct,
            participants: [me, alex.id],
            admins: [],
            title: nil,
            lastMessageAt: Date().addingTimeInterval(-1800),
            unreadCount: [me: 0, alex.id: 1],
            linkedFeature: nil,
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date()
        )
        conversationsSubject.send([convo])
    }

    // MARK: - Friends graph
    public func sendFriendRequest(to userId: String) async throws {}
    public func acceptFriendRequest(_ friendship: Friendship) async throws {}
    public func declineFriendRequest(_ friendship: Friendship) async throws {}
    public func cancelFriendRequest(_ friendship: Friendship) async throws {}
    public func blockUser(_ userId: String) async throws {}
    public func unblockUser(_ userId: String) async throws {}
    public func removeFriend(_ userId: String) async throws {}

    // MARK: - Conversations
    public func createConversation(with userIds: [String], title: String?) async throws -> Conversation {
        let conv = Conversation(
            id: UUID().uuidString,
            type: userIds.count > 1 ? .group : .direct,
            participants: [currentUserId ?? "current_user"] + userIds,
            admins: [],
            title: title,
            lastMessageAt: Date(),
            unreadCount: [:],
            linkedFeature: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        var list = conversationsSubject.value
        list.append(conv)
        conversationsSubject.send(list)
        return conv
    }
    public func createGroupConversation(with userIds: [String], title: String) async throws -> Conversation {
        try await createConversation(with: userIds, title: title)
    }
    public func addParticipants(to conversationId: String, userIds: [String]) async throws {}
    public func removeParticipant(from conversationId: String, userId: String) async throws {}
    public func updateConversationTitle(_ conversationId: String, title: String) async throws {}

    // MARK: - Messages
    public func sendMessage(to conversationId: String, draft: MessageDraft) async throws {}
    public func editMessage(_ messageId: String, in conversationId: String, newContent: String) async throws {}
    public func deleteMessage(_ messageId: String, in conversationId: String) async throws {}
    public func getMessages(for conversationId: String, limit: Int) -> AnyPublisher<[Message], Error> {
        // Create sample messages with various action cards
        let messages = [
            // Welcome message
            Message(
                id: "m1",
                senderId: "friend_1",
                type: .text,
                content: "Hey! Want to share a ride to downtown?",
                attachments: [],
                action: nil,
                createdAt: Date().addingTimeInterval(-3600),
                editedAt: nil,
                deletedAt: nil
            ),
            
            // Ride sharing action card
            Message(
                id: "m2",
                senderId: "friend_1",
                type: .action,
                content: "I've created a ride share for us",
                attachments: [],
                action: Message.ActionCard(
                    kind: "ride_sharing",
                    refId: "ride_123",
                    refKind: "ride_request",
                    meta: [
                        "pickup": AnyCodable("Hay Riad, Rabat"),
                        "destination": AnyCodable("Medina, Rabat"),
                        "etaMin": AnyCodable(15),
                        "seats": AnyCodable(3),
                        "price": AnyCodable(25.0)
                    ]
                ),
                createdAt: Date().addingTimeInterval(-3000),
                editedAt: nil,
                deletedAt: nil
            ),
            
            // Food delivery action card
            Message(
                id: "m3",
                senderId: currentUserId ?? "current_user",
                type: .action,
                content: "Let's order lunch together!",
                attachments: [],
                action: Message.ActionCard(
                    kind: "food_delivery",
                    refId: "order_456",
                    refKind: "group_order",
                    meta: [
                        "restaurant": AnyCodable("Le Dhow Restaurant"),
                        "items": AnyCodable(["Tagine", "Couscous", "Pastilla"]),
                        "total": AnyCodable(180.50),
                        "deliveryTime": AnyCodable("12:30 PM")
                    ]
                ),
                createdAt: Date().addingTimeInterval(-2400),
                editedAt: nil,
                deletedAt: nil
            ),
            
            // Marketplace action card
            Message(
                id: "m4",
                senderId: "friend_2",
                type: .action,
                content: "Check out this item I'm selling",
                attachments: [],
                action: Message.ActionCard(
                    kind: "marketplace",
                    refId: "item_789",
                    refKind: "listing",
                    meta: [
                        "itemName": AnyCodable("iPhone 13 Pro"),
                        "price": AnyCodable(8500.00),
                        "condition": AnyCodable("Like New"),
                        "category": AnyCodable("Electronics")
                    ]
                ),
                createdAt: Date().addingTimeInterval(-1800),
                editedAt: nil,
                deletedAt: nil
            ),
            
            // Watch party action card
            Message(
                id: "m5",
                senderId: "friend_1",
                type: .action,
                content: "Starting a watch party!",
                attachments: [],
                action: Message.ActionCard(
                    kind: "watch_party",
                    refId: "party_321",
                    refKind: "watch_session",
                    meta: [
                        "title": AnyCodable("Morocco vs Portugal - World Cup"),
                        "participants": AnyCodable(5),
                        "startTime": AnyCodable("8:00 PM")
                    ]
                ),
                createdAt: Date().addingTimeInterval(-1200),
                editedAt: nil,
                deletedAt: nil
            ),
            
            // Debate action card
            Message(
                id: "m6",
                senderId: "friend_2",
                type: .action,
                content: "Join this interesting debate",
                attachments: [],
                action: Message.ActionCard(
                    kind: "debate",
                    refId: "debate_654",
                    refKind: "live_debate",
                    meta: [
                        "topic": AnyCodable("Should Morocco invest more in renewable energy?"),
                        "participants": AnyCodable(24),
                        "status": AnyCodable("live"),
                        "moderator": AnyCodable("Dr. Hassan")
                    ]
                ),
                createdAt: Date().addingTimeInterval(-600),
                editedAt: nil,
                deletedAt: nil
            ),
            
            // AI Tutor action card
            Message(
                id: "m7",
                senderId: currentUserId ?? "current_user",
                type: .action,
                content: "Want to study together?",
                attachments: [],
                action: Message.ActionCard(
                    kind: "ai_tutor",
                    refId: "session_987",
                    refKind: "study_session",
                    meta: [
                        "subject": AnyCodable("Arabic Literature"),
                        "difficulty": AnyCodable("Intermediate"),
                        "duration": AnyCodable("45 minutes")
                    ]
                ),
                createdAt: Date().addingTimeInterval(-300),
                editedAt: nil,
                deletedAt: nil
            ),
            
            // Home services action card
            Message(
                id: "m8",
                senderId: "friend_1",
                type: .action,
                content: "Found a great plumber for the building",
                attachments: [],
                action: Message.ActionCard(
                    kind: "home_services",
                    refId: "service_111",
                    refKind: "booking",
                    meta: [
                        "service": AnyCodable("Plumbing Repair"),
                        "professional": AnyCodable("Ahmed's Plumbing"),
                        "scheduledDate": AnyCodable("Tomorrow at 2 PM"),
                        "price": AnyCodable(350.00)
                    ]
                ),
                createdAt: Date().addingTimeInterval(-120),
                editedAt: nil,
                deletedAt: nil
            ),
            
            // Location sharing action card
            Message(
                id: "m9",
                senderId: "friend_2",
                type: .action,
                content: "I'm here!",
                attachments: [],
                action: Message.ActionCard(
                    kind: "location_share",
                    refId: "loc_222",
                    refKind: "live_location",
                    meta: [
                        "address": AnyCodable("Morocco Mall, Casablanca"),
                        "lat": AnyCodable(33.5731),
                        "lng": AnyCodable(-7.6588)
                    ]
                ),
                createdAt: Date().addingTimeInterval(-60),
                editedAt: nil,
                deletedAt: nil
            ),
            
            // Regular text message
            Message(
                id: "m10",
                senderId: currentUserId ?? "current_user",
                type: .text,
                content: "These action cards are really useful! 🎉",
                attachments: [],
                action: nil,
                createdAt: Date(),
                editedAt: nil,
                deletedAt: nil
            )
        ]
        
        return Just(messages)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    public func markAsRead(_ conversationId: String) async throws {}

    // MARK: - Presence & typing
    public func updatePresence(_ status: PresenceStatus.Status) async throws {}
    public func setTyping(in conversationId: String, isTyping: Bool) async throws {}
    public func getTypingUsers(in conversationId: String) -> AnyPublisher<[String], Never> { Just([]).eraseToAnyPublisher() }

    // MARK: - Invites
    public func generateInviteLink(maxUses: Int, expiresIn: TimeInterval, context: InviteContext?) async throws -> InviteInfo {
        InviteInfo(code: "ABC123", url: "https://liive.app/invite/ABC123", expiresAt: Date().addingTimeInterval(604800), maxUses: maxUses, usageCount: 0, context: context)
    }
    public func resolveInviteLink(_ code: String) async throws -> InviteInfo {
        InviteInfo(code: code, url: "https://liive.app/invite/\(code)", expiresAt: Date().addingTimeInterval(604800), maxUses: 10, usageCount: 1, context: nil)
    }
    public func acceptInvite(_ code: String) async throws -> String { "friendship_\(code)" }

    // MARK: - Contacts and search
    public func hashContacts(_ phoneNumbers: [String]) async throws -> [String] { phoneNumbers.map { _ in UUID().uuidString } }
    public func findUsersByContacts(_ hashedPhones: [String]) async throws -> [MatchedContact] { [] }
    public func searchUsers(_ query: String, limit: Int) async throws -> [FriendProfile] { friendsSubject.value.filter { $0.displayName.lowercased().contains(query.lowercased()) } }
    public func getMutualFriends(with userId: String, limit: Int) async throws -> [FriendProfile] { [] }

    // MARK: - Watch party / media
    public func createWatchParty(in conversationId: String, mediaURL: String?, title: String?) async throws -> (roomName: String, watchPartyId: String) { ("friends_\(conversationId)", UUID().uuidString) }
    public func joinWatchParty(_ conversationId: String) async throws -> (roomName: String, playback: Any) { ("friends_\(conversationId)", [:] as [String: Any]) }
    public func leaveWatchParty(_ conversationId: String) async throws {}
    public func updatePlayback(in conversationId: String, action: String, positionMs: Int?) async throws {}
    public func getWatchParty(_ conversationId: String) async throws -> (exists: Bool, data: [String : Any]?) { (false, nil) }

    // MARK: - Uploads
    public func uploadAttachment(_ data: Data, type: String, conversationId: String) async throws -> String { "https://example.com/mock.jpg" }
}



