import Foundation
import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseFunctions
import FirebaseAuth

/// Firestore-based implementation of EventsServicing
public final class FirestoreEventsService: EventsServicing {
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    private let auth = Auth.auth()
    
    private let groupUpdatesSubject = PassthroughSubject<AttendanceGroup, Never>()
    private let orderUpdatesSubject = PassthroughSubject<TicketOrder, Never>()
    private let eventUpdatesSubject = PassthroughSubject<Event, Never>()
    private let friendActivityUpdatesSubject = PassthroughSubject<FriendEventActivity, Never>()
    private let inviteUpdatesSubject = PassthroughSubject<EventInvite, Never>()
    private let chatMessageUpdatesSubject = PassthroughSubject<GroupChatMessage, Never>()
    
    private var listeners: [ListenerRegistration] = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Collections
    
    private var eventsCollection: CollectionReference {
        db.collection("events")
    }
    
    private var sessionsCollection: CollectionReference {
        db.collection("eventSessions")
    }
    
    private var groupsCollection: CollectionReference {
        db.collection("attendanceGroups")
    }
    
    private var ordersCollection: CollectionReference {
        db.collection("ticketOrders")
    }
    
    private var splitsCollection: CollectionReference {
        db.collection("splitIntents")
    }
    
    private var promotersCollection: CollectionReference {
        db.collection("eventPromoters")
    }
    
    private var chatsCollection: CollectionReference {
        db.collection("chats")
    }
    
    // MARK: - Initialization
    
    public init() {
        setupListeners()
    }
    
    deinit {
        listeners.forEach { $0.remove() }
    }
    
    // MARK: - Discovery & Search
    
    public func searchEvents(_ query: String, filters: EventFilters) async throws -> [Event] {
        let callable = functions.httpsCallable("events-search")
        
        let data: [String: Any] = [
            "query": query,
            "filters": try encodeToDict(filters)
        ]
        
        let result = try await callable.call(data)
        
        guard let eventsData = result.data as? [[String: Any]] else {
            throw EventsError.invalidRequest
        }
        
        return try eventsData.map { dict in
            try decodeFromDict(dict, as: Event.self)
        }
    }
    
    public func getEvent(id: String) async throws -> Event? {
        let document = try await eventsCollection.document(id).getDocument()
        return try document.data(as: Event.self)
    }
    
    public func getUpcomingEvents(limit: Int) async throws -> [Event] {
        let query = eventsCollection
            .whereField("startAt", isGreaterThan: Date())
            .whereField("status", isEqualTo: EventStatus.published.rawValue)
            .order(by: "startAt")
            .limit(to: limit)
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Event.self) }
    }
    
    public func getEventsByCategory(_ category: EventCategory, limit: Int) async throws -> [Event] {
        let query = eventsCollection
            .whereField("category", isEqualTo: category.rawValue)
            .whereField("status", isEqualTo: EventStatus.published.rawValue)
            .whereField("startAt", isGreaterThan: Date())
            .order(by: "startAt")
            .limit(to: limit)
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Event.self) }
    }
    
    // MARK: - Event Sessions
    
    public func getEventSessions(eventId: String) async throws -> [EventSession] {
        let query = sessionsCollection
            .whereField("eventId", isEqualTo: eventId)
            .whereField("startAt", isGreaterThan: Date())
            .order(by: "startAt")
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: EventSession.self) }
    }
    
    public func getSession(id: String) async throws -> EventSession? {
        let document = try await sessionsCollection.document(id).getDocument()
        return try document.data(as: EventSession.self)
    }
    
    // MARK: - Groups & RSVPs
    
    public func createAttendanceGroup(_ draft: AttendanceGroupDraft) async throws -> AttendanceGroup {
        guard let _ = auth.currentUser?.uid else {
            throw EventsError.unauthorized
        }
        
        let callable = functions.httpsCallable("events-groups-create")
        let data = try encodeToDict(draft)
        
        let result = try await callable.call(data)
        
        guard let groupData = result.data as? [String: Any] else {
            throw EventsError.serverError("Failed to create group")
        }
        
        return try decodeFromDict(groupData, as: AttendanceGroup.self)
    }
    
    public func inviteFriends(groupId: String, userIds: [String]) async throws {
        let callable = functions.httpsCallable("events-groups-invite")
        
        let data: [String: Any] = [
            "groupId": groupId,
            "userIds": userIds
        ]
        
        _ = try await callable.call(data)
    }
    
    public func updateRSVP(groupId: String, attending: Bool) async throws {
        guard let _ = auth.currentUser?.uid else {
            throw EventsError.unauthorized
        }
        
        let callable = functions.httpsCallable("events-groups-rsvp")
        
        let data: [String: Any] = [
            "groupId": groupId,
            "attending": attending
        ]
        
        _ = try await callable.call(data)
    }
    
    public func getMyGroups() async throws -> [AttendanceGroup] {
        guard let userId = auth.currentUser?.uid else {
            throw EventsError.unauthorized
        }
        
        let query = groupsCollection
            .whereField("participantUserIds", arrayContains: userId)
            .whereField("status", in: [GroupStatus.planning.rawValue, GroupStatus.ordering.rawValue, GroupStatus.confirmed.rawValue])
            .order(by: "createdAt", descending: true)
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: AttendanceGroup.self) }
    }
    
    public func getGroup(id: String) async throws -> AttendanceGroup? {
        let document = try await groupsCollection.document(id).getDocument()
        return try document.data(as: AttendanceGroup.self)
    }
    
    public func leaveGroup(groupId: String) async throws {
        let callable = functions.httpsCallable("events-groups-leave")
        
        let data: [String: Any] = [
            "groupId": groupId
        ]
        
        _ = try await callable.call(data)
    }
    
    // MARK: - Tickets & Orders
    
    public func linkExternalTickets(_ link: TicketLink) async throws -> TicketLinkResult {
        let callable = functions.httpsCallable("events-tickets-link")
        let data = try encodeToDict(link)
        
        let result = try await callable.call(data)
        
        guard let resultData = result.data as? [String: Any] else {
            throw EventsError.invalidRequest
        }
        
        return try decodeFromDict(resultData, as: TicketLinkResult.self)
    }
    
    public func createTicketOrder(_ request: TicketOrderRequest) async throws -> TicketOrder {
        let callable = functions.httpsCallable("events-orders-create")
        let data = try encodeToDict(request)
        
        let result = try await callable.call(data)
        
        guard let orderData = result.data as? [String: Any] else {
            throw EventsError.serverError("Failed to create order")
        }
        
        return try decodeFromDict(orderData, as: TicketOrder.self)
    }
    
    public func getOrder(id: String) async throws -> TicketOrder? {
        let document = try await ordersCollection.document(id).getDocument()
        return try document.data(as: TicketOrder.self)
    }
    
    public func getMyOrders() async throws -> [TicketOrder] {
        guard let userId = auth.currentUser?.uid else {
            throw EventsError.unauthorized
        }
        
        let query = ordersCollection
            .whereField("organizerId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: TicketOrder.self) }
    }
    
    public func confirmOrder(orderId: String) async throws -> TicketOrder {
        let callable = functions.httpsCallable("events-orders-confirm")
        
        let data: [String: Any] = [
            "orderId": orderId
        ]
        
        let result = try await callable.call(data)
        
        guard let orderData = result.data as? [String: Any] else {
            throw EventsError.serverError("Failed to confirm order")
        }
        
        return try decodeFromDict(orderData, as: TicketOrder.self)
    }
    
    public func cancelOrder(orderId: String) async throws {
        let callable = functions.httpsCallable("events-orders-cancel")
        
        let data: [String: Any] = [
            "orderId": orderId
        ]
        
        _ = try await callable.call(data)
    }
    
    // MARK: - Split Payments
    
    public func createSplitIntent(_ request: SplitIntentRequest) async throws -> SplitIntent {
        let callable = functions.httpsCallable("events-splits-createIntent")
        let data = try encodeToDict(request)
        
        let result = try await callable.call(data)
        
        guard let splitData = result.data as? [String: Any] else {
            throw EventsError.serverError("Failed to create split intent")
        }
        
        return try decodeFromDict(splitData, as: SplitIntent.self)
    }
    
    public func getSplitIntent(id: String) async throws -> SplitIntent? {
        let document = try await splitsCollection.document(id).getDocument()
        return try document.data(as: SplitIntent.self)
    }
    
    public func paySplit(splitId: String) async throws {
        let callable = functions.httpsCallable("events-splits-pay")
        
        let data: [String: Any] = [
            "splitId": splitId
        ]
        
        _ = try await callable.call(data)
    }
    
    // MARK: - Promoters
    
    public func getPromoter(id: String) async throws -> EventPromoter? {
        let document = try await promotersCollection.document(id).getDocument()
        return try document.data(as: EventPromoter.self)
    }
    
    public func getPromoterEvents(promoterId: String) async throws -> [Event] {
        let query = eventsCollection
            .whereField("promoterId", isEqualTo: promoterId)
            .whereField("status", isEqualTo: EventStatus.published.rawValue)
            .order(by: "startAt", descending: true)
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Event.self) }
    }
    
    // MARK: - AI Assistant
    
    public func askAI(_ query: String, context: [String: Any]) async throws -> EventAIResponse {
        let callable = functions.httpsCallable("events-ai-answer")
        
        var data: [String: Any] = [
            "query": query
        ]
        
        data.merge(context) { _, new in new }
        
        let result = try await callable.call(data)
        
        guard let responseData = result.data as? [String: Any] else {
            throw EventsError.serverError("Invalid AI response")
        }
        
        return try decodeFromDict(responseData, as: EventAIResponse.self)
    }
    
    public func createEventAlert(criteria: EventFilters) async throws -> String {
        let callable = functions.httpsCallable("events-ai-createWatcher")
        let data = try encodeToDict(criteria)
        
        let result = try await callable.call(data)
        
        guard let alertId = result.data as? String else {
            throw EventsError.serverError("Failed to create alert")
        }
        
        return alertId
    }
    
    public func deleteEventAlert(alertId: String) async throws {
        let callable = functions.httpsCallable("events-ai-deleteWatcher")
        
        let data: [String: Any] = [
            "alertId": alertId
        ]
        
        _ = try await callable.call(data)
    }
    
    // MARK: - Friends & Social
    
    public func getFriends() async throws -> [EventsFriend] {
        let callable = functions.httpsCallable("events-friends-list")
        let result = try await callable.call([:])
        
        guard let friendsData = result.data as? [[String: Any]] else {
            return []
        }
        
        return try friendsData.map { try decodeFromDict($0, as: EventsFriend.self) }
    }
    
    public func getFriendActivity() async throws -> [FriendEventActivity] {
        let callable = functions.httpsCallable("events-friends-activity")
        let result = try await callable.call([:])
        
        guard let activityData = result.data as? [[String: Any]] else {
            return []
        }
        
        return try activityData.map { try decodeFromDict($0, as: FriendEventActivity.self) }
    }
    
    public func getEventsWithFriends() async throws -> [(Event, [EventsFriend])] {
        let callable = functions.httpsCallable("events-friends-eventsWithFriends")
        let result = try await callable.call([:])
        
        guard let rows = result.data as? [[String: Any]] else {
            return []
        }
        
        return try rows.map { row in
            let eventDict = row["event"] as? [String: Any] ?? [:]
            let friendsArray = row["friends"] as? [[String: Any]] ?? []
            let event = try decodeFromDict(eventDict, as: Event.self)
            let friends = try friendsArray.map { try decodeFromDict($0, as: EventsFriend.self) }
            return (event, friends)
        }
    }
    
    public func sendEventInvite(eventId: String, friendIds: [String], message: String?) async throws {
        let callable = functions.httpsCallable("events-invites-send")
        let data: [String: Any] = [
            "eventId": eventId,
            "friendIds": friendIds,
            "message": message as Any
        ]
        _ = try await callable.call(data)
    }
    
    public func getEventInvites() async throws -> [EventInvite] {
        let callable = functions.httpsCallable("events-invites-list")
        let result = try await callable.call([:])
        
        guard let invitesData = result.data as? [[String: Any]] else {
            return []
        }
        
        return try invitesData.map { try decodeFromDict($0, as: EventInvite.self) }
    }
    
    public func respondToInvite(inviteId: String, response: InviteResponse) async throws {
        let callable = functions.httpsCallable("events-invites-respond")
        let data: [String: Any] = [
            "inviteId": inviteId,
            "response": response.rawValue
        ]
        _ = try await callable.call(data)
    }
    
    // MARK: - Chat & Messaging
    
    public func getGroupChatId(groupId: String) async throws -> String? {
        let document = try await groupsCollection.document(groupId).getDocument()
        let group: AttendanceGroup? = try document.data(as: AttendanceGroup.self)
        return group?.chatThreadId
    }
    
    public func createGroupChat(groupId: String) async throws -> String {
        let callable = functions.httpsCallable("events-chat-create")
        let data: [String: Any] = ["groupId": groupId]
        let result = try await callable.call(data)
        guard let chatId = result.data as? String else {
            throw EventsError.serverError("Failed to create chat")
        }
        return chatId
    }
    
    public func sendGroupMessage(chatId: String, message: String) async throws {
        let callable = functions.httpsCallable("events-chat-send")
        let data: [String: Any] = [
            "chatId": chatId,
            "message": message
        ]
        _ = try await callable.call(data)
    }
    
    public func getGroupMessages(chatId: String, limit: Int) async throws -> [GroupChatMessage] {
        let snapshot = try await chatsCollection
            .document(chatId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        let messages: [GroupChatMessage] = try snapshot.documents.compactMap { doc in
            try doc.data(as: GroupChatMessage.self)
        }
        
        return messages.sorted { $0.timestamp < $1.timestamp }
    }
    
    public func markMessagesRead(chatId: String, messageIds: [String]) async throws {
        let callable = functions.httpsCallable("events-chat-markRead")
        let data: [String: Any] = [
            "chatId": chatId,
            "messageIds": messageIds
        ]
        _ = try await callable.call(data)
    }
    
    // MARK: - Ride Integration
    
    public func getRideQuote(eventId: String, pickupLocation: LocationCoordinate, departureTime: Date?, passengerCount: Int?) async throws -> RideQuote {
        let callable = functions.httpsCallable("events-rides-quote")
        var data: [String: Any] = [
            "eventId": eventId,
            "pickupLocation": try encodeToDict(pickupLocation)
        ]
        if let departureTime = departureTime { data["departureTime"] = Timestamp(date: departureTime) }
        if let passengerCount = passengerCount { data["passengerCount"] = passengerCount }
        
        let result = try await callable.call(data)
        guard let dict = result.data as? [String: Any] else {
            throw EventsError.serverError("Failed to get ride quote")
        }
        return try decodeFromDict(dict, as: RideQuote.self)
    }
    
    public func bookEventRide(quoteId: String, groupId: String?, shareRide: Bool?) async throws -> RideBookingResult {
        let callable = functions.httpsCallable("events-rides-book")
        var data: [String: Any] = ["quoteId": quoteId]
        if let groupId = groupId { data["groupId"] = groupId }
        if let shareRide = shareRide { data["shareRide"] = shareRide }
        
        let result = try await callable.call(data)
        guard let dict = result.data as? [String: Any] else {
            throw EventsError.serverError("Failed to book ride")
        }
        return try decodeFromDict(dict, as: RideBookingResult.self)
    }
    
    public func getEventRideBookings(eventId: String) async throws -> [RideBookingRequest] {
        let callable = functions.httpsCallable("events-rides-bookings")
        let result = try await callable.call(["eventId": eventId])
        
        guard let list = result.data as? [[String: Any]] else {
            return []
        }
        
        return try list.map { try decodeFromDict($0, as: RideBookingRequest.self) }
    }
    
    // MARK: - Real-time Updates
    
    public var groupUpdates: AnyPublisher<AttendanceGroup, Never> {
        groupUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var orderUpdates: AnyPublisher<TicketOrder, Never> {
        orderUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var eventUpdates: AnyPublisher<Event, Never> {
        eventUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var friendActivityUpdates: AnyPublisher<FriendEventActivity, Never> {
        friendActivityUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var inviteUpdates: AnyPublisher<EventInvite, Never> {
        inviteUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var chatMessageUpdates: AnyPublisher<GroupChatMessage, Never> {
        chatMessageUpdatesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func setupListeners() {
        guard let userId = auth.currentUser?.uid else { return }
        
        // Listen to user's groups
        let groupListener = groupsCollection
            .whereField("participantUserIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                for document in documents {
                    if let group = try? document.data(as: AttendanceGroup.self) {
                        self?.groupUpdatesSubject.send(group)
                    }
                }
            }
        listeners.append(groupListener)
        
        // Listen to user's orders
        let orderListener = ordersCollection
            .whereField("organizerId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                for document in documents {
                    if let order = try? document.data(as: TicketOrder.self) {
                        self?.orderUpdatesSubject.send(order)
                    }
                }
            }
        listeners.append(orderListener)
        
        // Optional: Listen to social updates if collections exist
        let invitesListener = db.collection("eventInvites")
            .whereField("toUserId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                for document in documents {
                    if let invite = try? document.data(as: EventInvite.self) {
                        self?.inviteUpdatesSubject.send(invite)
                    }
                }
            }
        listeners.append(invitesListener)
    }
    
    private func encodeToDict<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return dict ?? [:]
    }
    
    private func decodeFromDict<T: Decodable>(_ dict: [String: Any], as type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(type, from: data)
    }
}