import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import LiveKitCore
import Collections

public protocol FriendsServicing {
    var currentUserId: String? { get }
    var friends: AnyPublisher<[FriendProfile], Never> { get }
    var friendRequests: AnyPublisher<[Friendship], Never> { get }
    var conversations: AnyPublisher<[Conversation], Never> { get }
    var presenceStatuses: AnyPublisher<[String: PresenceStatus], Never> { get }
    
    func sendFriendRequest(to userId: String) async throws
    func acceptFriendRequest(_ friendship: Friendship) async throws
    func declineFriendRequest(_ friendship: Friendship) async throws
    func cancelFriendRequest(_ friendship: Friendship) async throws
    func blockUser(_ userId: String) async throws
    func unblockUser(_ userId: String) async throws
    func removeFriend(_ userId: String) async throws
    
    func createConversation(with userIds: [String], title: String?) async throws -> Conversation
    func createGroupConversation(with userIds: [String], title: String) async throws -> Conversation
    func addParticipants(to conversationId: String, userIds: [String]) async throws
    func removeParticipant(from conversationId: String, userId: String) async throws
    func updateConversationTitle(_ conversationId: String, title: String) async throws
    
    func sendMessage(to conversationId: String, draft: MessageDraft) async throws
    func editMessage(_ messageId: String, in conversationId: String, newContent: String) async throws
    func deleteMessage(_ messageId: String, in conversationId: String) async throws
    func getMessages(for conversationId: String, limit: Int) -> AnyPublisher<[Message], Error>
    func markAsRead(_ conversationId: String) async throws
    
    func updatePresence(_ status: PresenceStatus.Status) async throws
    func setTyping(in conversationId: String, isTyping: Bool) async throws
    func getTypingUsers(in conversationId: String) -> AnyPublisher<[String], Never>
    
    func generateInviteLink(maxUses: Int, expiresIn: TimeInterval, context: InviteContext?) async throws -> InviteInfo
    func resolveInviteLink(_ code: String) async throws -> InviteInfo
    func acceptInvite(_ code: String) async throws -> String
    
    func hashContacts(_ phoneNumbers: [String]) async throws -> [String]
    func findUsersByContacts(_ hashedPhones: [String]) async throws -> [MatchedContact]
    func searchUsers(_ query: String, limit: Int) async throws -> [FriendProfile]
    func getMutualFriends(with userId: String, limit: Int) async throws -> [FriendProfile]
    
    func createWatchParty(in conversationId: String, mediaURL: String?, title: String?) async throws -> (roomName: String, watchPartyId: String)
    func joinWatchParty(_ conversationId: String) async throws -> (roomName: String, playback: Any)
    func leaveWatchParty(_ conversationId: String) async throws
    func updatePlayback(in conversationId: String, action: String, positionMs: Int?) async throws
    func getWatchParty(_ conversationId: String) async throws -> (exists: Bool, data: [String: Any]?)
    
    func uploadAttachment(_ data: Data, type: String, conversationId: String) async throws -> String
}

public final class FriendsService: FriendsServicing, ObservableObject {
    
    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    private let storage = Storage.storage()
    private let auth = Auth.auth()
    
    private var cancellables = Set<AnyCancellable>()
    private let friendsSubject = CurrentValueSubject<[FriendProfile], Never>([])
    private let requestsSubject = CurrentValueSubject<[Friendship], Never>([])
    private let conversationsSubject = CurrentValueSubject<[Conversation], Never>([])
    private let presenceSubject = CurrentValueSubject<[String: PresenceStatus], Never>([:])
    
    private var friendsListener: ListenerRegistration?
    private var requestsListener: ListenerRegistration?
    private var conversationsListener: ListenerRegistration?
    private var presenceListener: ListenerRegistration?
    
    public init() {
        setupAuthListener()
    }
    
    deinit {
        cleanupListeners()
    }
    
    // MARK: - Public Properties
    
    public var currentUserId: String? {
        auth.currentUser?.uid
    }
    
    public var friends: AnyPublisher<[FriendProfile], Never> {
        friendsSubject.eraseToAnyPublisher()
    }
    
    public var friendRequests: AnyPublisher<[Friendship], Never> {
        requestsSubject.eraseToAnyPublisher()
    }
    
    public var conversations: AnyPublisher<[Conversation], Never> {
        conversationsSubject.eraseToAnyPublisher()
    }
    
    public var presenceStatuses: AnyPublisher<[String: PresenceStatus], Never> {
        presenceSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Authentication
    
    private func setupAuthListener() {
        auth.addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.setupDataListeners(for: user.uid)
            } else {
                self?.cleanupListeners()
                self?.clearData()
            }
        }
    }
    
    private func setupDataListeners(for userId: String) {
        setupFriendsListener(userId: userId)
        setupRequestsListener(userId: userId)
        setupConversationsListener(userId: userId)
        setupPresenceListener()
    }
    
    private func cleanupListeners() {
        friendsListener?.remove()
        requestsListener?.remove()
        conversationsListener?.remove()
        presenceListener?.remove()
    }
    
    private func clearData() {
        friendsSubject.send([])
        requestsSubject.send([])
        conversationsSubject.send([])
        presenceSubject.send([:])
    }
    
    // MARK: - Data Listeners
    
    private func setupFriendsListener(userId: String) {
        friendsListener = db.collection("friendships")
            .whereField("users", arrayContains: userId)
            .whereField("status", isEqualTo: "accepted")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                Task {
                    var friends: [FriendProfile] = []
                    
                    for doc in documents {
                        let friendship = try? doc.data(as: Friendship.self)
                        guard let friendship = friendship else { continue }
                        
                        let friendId = friendship.users.first { $0 != userId } ?? ""
                        if !friendId.isEmpty {
                            let friendDoc = try? await self.db.collection("users").document(friendId).getDocument()
                            if let friendData = friendDoc?.data(),
                               let profile = try? Firestore.Decoder().decode(FriendProfile.self, from: friendData["profile"] as? [String: Any] ?? [:]) {
                                friends.append(FriendProfile(
                                    id: friendId,
                                    displayName: profile.displayName,
                                    photoURL: profile.photoURL,
                                    handle: profile.handle,
                                    city: profile.city,
                                    hashedPhone: profile.hashedPhone
                                ))
                            }
                        }
                    }
                    
                    await MainActor.run {
                        self.friendsSubject.send(friends)
                    }
                }
            }
    }
    
    private func setupRequestsListener(userId: String) {
        requestsListener = db.collection("friendships")
            .whereField("users", arrayContains: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                let requests = documents.compactMap { doc -> Friendship? in
                    try? doc.data(as: Friendship.self)
                }
                
                self.requestsSubject.send(requests)
            }
    }
    
    private func setupConversationsListener(userId: String) {
        conversationsListener = db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                let conversations = documents.compactMap { doc -> Conversation? in
                    try? doc.data(as: Conversation.self)
                }
                
                self.conversationsSubject.send(conversations)
            }
    }
    
    private func setupPresenceListener() {
        presenceListener = db.collection("presence")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                var statuses: [String: PresenceStatus] = [:]
                for doc in documents {
                    if let status = try? doc.data(as: PresenceStatus.self) {
                        statuses[status.userId] = status
                    }
                }
                
                self.presenceSubject.send(statuses)
            }
    }
    
    // MARK: - Friend Management
    
    public func sendFriendRequest(to userId: String) async throws {
        let function = functions.httpsCallable("friends_sendFriendRequest")
        let result = try await function.call(["userId": userId])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func acceptFriendRequest(_ friendship: Friendship) async throws {
        let function = functions.httpsCallable("friends_acceptFriendRequest")
        let result = try await function.call(["friendshipId": friendship.id])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func declineFriendRequest(_ friendship: Friendship) async throws {
        let function = functions.httpsCallable("friends_declineFriendRequest")
        let result = try await function.call(["friendshipId": friendship.id])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func cancelFriendRequest(_ friendship: Friendship) async throws {
        let function = functions.httpsCallable("friends_cancelFriendRequest")
        let result = try await function.call(["friendshipId": friendship.id])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func blockUser(_ userId: String) async throws {
        let function = functions.httpsCallable("friends_blockUser")
        let result = try await function.call(["userId": userId])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func unblockUser(_ userId: String) async throws {
        let function = functions.httpsCallable("friends_unblockUser")
        let result = try await function.call(["userId": userId])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func removeFriend(_ userId: String) async throws {
        let function = functions.httpsCallable("friends_removeFriend")
        let result = try await function.call(["userId": userId])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    // MARK: - Conversation Management
    
    public func createConversation(with userIds: [String], title: String?) async throws -> Conversation {
        let function = functions.httpsCallable("friends_createConversation")
        let result = try await function.call([
            "participants": userIds,
            "title": title as Any
        ])
        
        guard let data = result.data as? [String: Any],
              let conversationData = data["conversation"] as? [String: Any] else {
            throw FriendsError.requestFailed
        }
        
        return try Firestore.Decoder().decode(Conversation.self, from: conversationData)
    }
    
    public func createGroupConversation(with userIds: [String], title: String) async throws -> Conversation {
        let function = functions.httpsCallable("friends_createGroupConversation")
        let result = try await function.call([
            "participants": userIds,
            "title": title
        ])
        
        guard let data = result.data as? [String: Any],
              let conversationData = data["conversation"] as? [String: Any] else {
            throw FriendsError.requestFailed
        }
        
        return try Firestore.Decoder().decode(Conversation.self, from: conversationData)
    }
    
    public func addParticipants(to conversationId: String, userIds: [String]) async throws {
        let function = functions.httpsCallable("friends_addParticipants")
        let result = try await function.call([
            "conversationId": conversationId,
            "userIds": userIds
        ])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func removeParticipant(from conversationId: String, userId: String) async throws {
        let function = functions.httpsCallable("friends_removeParticipant")
        let result = try await function.call([
            "conversationId": conversationId,
            "userId": userId
        ])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func updateConversationTitle(_ conversationId: String, title: String) async throws {
        let function = functions.httpsCallable("friends_updateTitle")
        let result = try await function.call([
            "conversationId": conversationId,
            "title": title
        ])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    // MARK: - Messaging
    
    public func sendMessage(to conversationId: String, draft: MessageDraft) async throws {
        let function = functions.httpsCallable("friends_sendMessage")
        
        var messageData: [String: Any] = [
            "conversationId": conversationId,
            "type": draft.type.rawValue,
            "content": draft.content,
            "attachments": draft.attachments.map { attachment in
                [
                    "url": attachment.url,
                    "thumbURL": attachment.thumbURL as Any,
                    "kind": attachment.kind.rawValue
                ]
            }
        ]
        
        if let action = draft.action {
            messageData["action"] = [
                "kind": action.kind,
                "refId": action.refId,
                "refKind": action.refKind,
                "meta": action.meta.mapValues { $0.value }
            ]
        }
        
        let result = try await function.call(messageData)
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func editMessage(_ messageId: String, in conversationId: String, newContent: String) async throws {
        let function = functions.httpsCallable("friends_editMessage")
        let result = try await function.call([
            "conversationId": conversationId,
            "messageId": messageId,
            "newContent": newContent
        ])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func deleteMessage(_ messageId: String, in conversationId: String) async throws {
        let function = functions.httpsCallable("friends_deleteMessage")
        let result = try await function.call([
            "conversationId": conversationId,
            "messageId": messageId
        ])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func getMessages(for conversationId: String, limit: Int = 50) -> AnyPublisher<[Message], Error> {
        return db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .snapshotPublisher()
            .map { snapshot in
                snapshot.documents.compactMap { doc -> Message? in
                    try? doc.data(as: Message.self)
                }
            }
            .eraseToAnyPublisher()
    }
    
    public func markAsRead(_ conversationId: String) async throws {
        guard let userId = currentUserId else { return }
        
        try await db.collection("conversations")
            .document(conversationId)
            .updateData([
                "unreadCount.\(userId)": 0
            ])
    }
    
    // MARK: - Presence & Typing
    
    public func updatePresence(_ status: PresenceStatus.Status) async throws {
        let function = functions.httpsCallable("friends_updatePresence")
        let result = try await function.call([
            "status": status.rawValue
        ])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func setTyping(in conversationId: String, isTyping: Bool) async throws {
        let function = functions.httpsCallable("friends_setTyping")
        let result = try await function.call([
            "conversationId": conversationId,
            "isTyping": isTyping
        ])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func getTypingUsers(in conversationId: String) -> AnyPublisher<[String], Never> {
        return db.collection("typing")
            .whereField("conversationId", isEqualTo: conversationId)
            .whereField("isTyping", isEqualTo: true)
            .snapshotPublisher()
            .map { snapshot in
                snapshot.documents.compactMap { doc in
                    doc.data()["userId"] as? String
                }
            }
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }
    
    // MARK: - Invites
    
    public func generateInviteLink(maxUses: Int = 10, expiresIn: TimeInterval = 604800, context: InviteContext? = nil) async throws -> InviteInfo {
        let function = functions.httpsCallable("friends_generateInvite")
        
        var inviteData: [String: Any] = [
            "maxUses": maxUses,
            "expiresIn": expiresIn
        ]
        
        if let context = context {
            inviteData["context"] = [
                "source": context.source,
                "featureId": context.featureId as Any,
                "metadata": context.metadata?.mapValues { $0.value } as Any
            ]
        }
        
        let result = try await function.call(inviteData)
        
        guard let data = result.data as? [String: Any],
              let inviteInfoData = data["invite"] as? [String: Any] else {
            throw FriendsError.requestFailed
        }
        
        return try Firestore.Decoder().decode(InviteInfo.self, from: inviteInfoData)
    }
    
    public func resolveInviteLink(_ code: String) async throws -> InviteInfo {
        let function = functions.httpsCallable("friends_resolveInvite")
        let result = try await function.call(["code": code])
        
        guard let data = result.data as? [String: Any],
              let inviteInfoData = data["invite"] as? [String: Any] else {
            throw FriendsError.requestFailed
        }
        
        return try Firestore.Decoder().decode(InviteInfo.self, from: inviteInfoData)
    }
    
    public func acceptInvite(_ code: String) async throws -> String {
        let function = functions.httpsCallable("friends_acceptInvite")
        let result = try await function.call(["code": code])
        
        guard let data = result.data as? [String: Any],
              let friendshipId = data["friendshipId"] as? String else {
            throw FriendsError.requestFailed
        }
        
        return friendshipId
    }
    
    // MARK: - Contact Discovery
    
    public func hashContacts(_ phoneNumbers: [String]) async throws -> [String] {
        let function = functions.httpsCallable("friends_hashContacts")
        let result = try await function.call(["phoneNumbers": phoneNumbers])
        
        guard let data = result.data as? [String: Any],
              let hashedPhones = data["hashedPhones"] as? [String] else {
            throw FriendsError.requestFailed
        }
        
        return hashedPhones
    }
    
    public func findUsersByContacts(_ hashedPhones: [String]) async throws -> [MatchedContact] {
        let function = functions.httpsCallable("friends_findUsersByHashedPhone")
        let result = try await function.call(["hashedPhones": hashedPhones])
        
        guard let data = result.data as? [String: Any],
              let matchesData = data["matches"] as? [[String: Any]] else {
            throw FriendsError.requestFailed
        }
        
        return try matchesData.map { matchData in
            try Firestore.Decoder().decode(MatchedContact.self, from: matchData)
        }
    }
    
    public func searchUsers(_ query: String, limit: Int = 20) async throws -> [FriendProfile] {
        let function = functions.httpsCallable("friends_searchUsers")
        let result = try await function.call([
            "query": query,
            "limit": limit
        ])
        
        guard let data = result.data as? [String: Any],
              let resultsData = data["results"] as? [[String: Any]] else {
            throw FriendsError.requestFailed
        }
        
        return try resultsData.map { resultData in
            let userId = resultData["userId"] as? String ?? ""
            let displayName = resultData["displayName"] as? String ?? ""
            let handle = resultData["handle"] as? String
            let photoURL = resultData["photoURL"] as? String
            let city = resultData["city"] as? String
            
            return FriendProfile(
                id: userId,
                displayName: displayName,
                photoURL: photoURL,
                handle: handle,
                city: city,
                hashedPhone: nil
            )
        }
    }
    
    public func getMutualFriends(with userId: String, limit: Int = 10) async throws -> [FriendProfile] {
        let function = functions.httpsCallable("friends_getMutualFriends")
        let result = try await function.call([
            "targetUserId": userId,
            "limit": limit
        ])
        
        guard let data = result.data as? [String: Any],
              let mutualFriendsData = data["mutualFriends"] as? [[String: Any]] else {
            throw FriendsError.requestFailed
        }
        
        return try mutualFriendsData.map { friendData in
            let userId = friendData["userId"] as? String ?? ""
            let displayName = friendData["displayName"] as? String ?? ""
            let photoURL = friendData["photoURL"] as? String
            
            return FriendProfile(
                id: userId,
                displayName: displayName,
                photoURL: photoURL,
                handle: nil,
                city: nil,
                hashedPhone: nil
            )
        }
    }
    
    // MARK: - Watch Party / LiveKit
    
    public func createWatchParty(in conversationId: String, mediaURL: String? = nil, title: String? = nil) async throws -> (roomName: String, watchPartyId: String) {
        let function = functions.httpsCallable("friends_createWatchParty")
        let result = try await function.call([
            "conversationId": conversationId,
            "mediaURL": mediaURL as Any,
            "title": title as Any
        ])
        
        guard let data = result.data as? [String: Any],
              let roomName = data["roomName"] as? String,
              let watchPartyId = data["watchPartyId"] as? String else {
            throw FriendsError.requestFailed
        }
        
        return (roomName: roomName, watchPartyId: watchPartyId)
    }
    
    public func joinWatchParty(_ conversationId: String) async throws -> (roomName: String, playback: Any) {
        let function = functions.httpsCallable("friends_joinWatchParty")
        let result = try await function.call(["conversationId": conversationId])
        
        guard let data = result.data as? [String: Any],
              let roomName = data["roomName"] as? String,
              let playback = data["playback"] else {
            throw FriendsError.requestFailed
        }
        
        return (roomName: roomName, playback: playback)
    }
    
    public func leaveWatchParty(_ conversationId: String) async throws {
        let function = functions.httpsCallable("friends_leaveWatchParty")
        let result = try await function.call(["conversationId": conversationId])
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func updatePlayback(in conversationId: String, action: String, positionMs: Int? = nil) async throws {
        let function = functions.httpsCallable("friends_updatePlayback")
        
        var playbackData: [String: Any] = [
            "conversationId": conversationId,
            "action": action
        ]
        
        if let positionMs = positionMs {
            playbackData["positionMs"] = positionMs
        }
        
        let result = try await function.call(playbackData)
        
        if let data = result.data as? [String: Any], let success = data["success"] as? Bool, !success {
            throw FriendsError.requestFailed
        }
    }
    
    public func getWatchParty(_ conversationId: String) async throws -> (exists: Bool, data: [String: Any]?) {
        let function = functions.httpsCallable("friends_getWatchParty")
        let result = try await function.call(["conversationId": conversationId])
        
        guard let data = result.data as? [String: Any],
              let exists = data["exists"] as? Bool else {
            throw FriendsError.requestFailed
        }
        
        return (exists: exists, data: exists ? data : nil)
    }
    
    // MARK: - File Upload
    
    public func uploadAttachment(_ data: Data, type: String, conversationId: String) async throws -> String {
        let filename = "\(UUID().uuidString).\(type)"
        let storageRef = storage.reference()
            .child("conversations")
            .child(conversationId)
            .child("attachments")
            .child(filename)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/\(type)"
        
        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
}

// MARK: - Error Types

public enum FriendsError: LocalizedError {
    case requestFailed
    case notAuthenticated
    case invalidData
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Request failed"
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidData:
            return "Invalid data received"
        case .networkError:
            return "Network error"
        }
    }
}

// MARK: - Extensions

extension Query {
    func snapshotPublisher() -> AnyPublisher<QuerySnapshot, Error> {
        return Future<QuerySnapshot, Error> { promise in
            self.addSnapshotListener { snapshot, error in
                if let error = error {
                    promise(.failure(error))
                } else if let snapshot = snapshot {
                    promise(.success(snapshot))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}