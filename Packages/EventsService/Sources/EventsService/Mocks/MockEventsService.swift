import Foundation
import Combine
import FirebaseFirestore

/// Mock implementation of EventsService for testing and demos
public final class MockEventsService: EventsServicing {
    
    // MARK: - Properties
    
    private var mockEvents: [Event] = []
    private var mockGroups: [AttendanceGroup] = []
    private var mockOrders: [TicketOrder] = []
    private var mockFriends: [EventsFriend] = []
    private var mockInvites: [EventInvite] = []
    private var mockMessages: [String: [GroupChatMessage]] = [:] // chatId -> messages
    
    // MARK: - Publishers
    
    private let groupUpdatesSubject = PassthroughSubject<AttendanceGroup, Never>()
    private let orderUpdatesSubject = PassthroughSubject<TicketOrder, Never>()
    private let eventUpdatesSubject = PassthroughSubject<Event, Never>()
    private let friendActivitySubject = PassthroughSubject<FriendEventActivity, Never>()
    private let inviteUpdatesSubject = PassthroughSubject<EventInvite, Never>()
    private let chatMessageSubject = PassthroughSubject<GroupChatMessage, Never>()
    
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
        friendActivitySubject.eraseToAnyPublisher()
    }
    
    public var inviteUpdates: AnyPublisher<EventInvite, Never> {
        inviteUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var chatMessageUpdates: AnyPublisher<GroupChatMessage, Never> {
        chatMessageSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init() {
        setupMockData()
    }
    
    // MARK: - Discovery & Search
    
    public func searchEvents(_ query: String, filters: EventFilters) async throws -> [Event] {
        try await simulateNetworkDelay()
        
        var results = mockEvents
        
        // Apply text search
        if !query.isEmpty {
            let searchTerms = query.lowercased().components(separatedBy: " ")
            results = results.filter { event in
                let searchableText = "\(event.title) \(event.description) \(event.venueName)".lowercased()
                return searchTerms.allSatisfy { searchableText.contains($0) }
            }
        }
        
        // Apply filters
        if let categories = filters.categories, !categories.isEmpty {
            results = results.filter { categories.contains($0.category) }
        }
        
        if let dateRange = filters.dateRange {
            results = results.filter { event in
                event.startAt >= dateRange.from && event.startAt <= dateRange.to
            }
        }
        
        return results
    }
    
    public func getEvent(id: String) async throws -> Event? {
        try await simulateNetworkDelay()
        return mockEvents.first { $0.id == id }
    }
    
    public func getUpcomingEvents(limit: Int) async throws -> [Event] {
        try await simulateNetworkDelay()
        let upcoming = mockEvents.filter { $0.startAt > Date() }
            .sorted { $0.startAt < $1.startAt }
        return Array(upcoming.prefix(limit))
    }
    
    public func getEventsByCategory(_ category: EventCategory, limit: Int) async throws -> [Event] {
        try await simulateNetworkDelay()
        let filtered = mockEvents.filter { $0.category == category }
        return Array(filtered.prefix(limit))
    }
    
    // MARK: - Event Sessions
    
    public func getEventSessions(eventId: String) async throws -> [EventSession] {
        try await simulateNetworkDelay()
        
        guard let event = mockEvents.first(where: { $0.id == eventId }) else {
            return []
        }
        
        return [
            EventSession(
                id: "\(eventId)_session_1",
                eventId: eventId,
                startAt: event.startAt,
                endAt: event.endAt,
                capacityByTier: ["General": 100, "VIP": 20],
                status: .scheduled
            ),
            EventSession(
                id: "\(eventId)_session_2",
                eventId: eventId,
                startAt: event.startAt.addingTimeInterval(86400), // Next day
                endAt: event.endAt.addingTimeInterval(86400),
                capacityByTier: ["General": 100, "VIP": 20],
                status: .limited
            )
        ]
    }
    
    public func getSession(id: String) async throws -> EventSession? {
        try await simulateNetworkDelay()
        let firstId = mockEvents.first?.id ?? ""
        let allSessions = try await getEventSessions(eventId: firstId)
        return allSessions.first { $0.id == id }
    }
    
    // MARK: - Groups & RSVPs
    
    public func createAttendanceGroup(_ draft: AttendanceGroupDraft) async throws -> AttendanceGroup {
        try await simulateNetworkDelay()
        
        let group = AttendanceGroup(
            id: UUID().uuidString,
            organizerId: "current_user",
            eventId: draft.eventId,
            sessionId: draft.sessionId,
            name: draft.name,
            status: .planning,
            invitedUserIds: draft.invitedUserIds,
            participantUserIds: ["current_user"],
            chatThreadId: "chat_\(UUID().uuidString)"
        )
        
        mockGroups.append(group)
        groupUpdatesSubject.send(group)
        
        return group
    }
    
    public func inviteFriends(groupId: String, userIds: [String]) async throws {
        try await simulateNetworkDelay()
        
        guard let index = mockGroups.firstIndex(where: { $0.id == groupId }) else {
            throw EventsError.groupNotFound
        }
        
        let current = mockGroups[index]
        let updated = AttendanceGroup(
            id: current.id,
            organizerId: current.organizerId,
            eventId: current.eventId,
            sessionId: current.sessionId,
            name: current.name,
            status: current.status,
            invitedUserIds: current.invitedUserIds + userIds,
            participantUserIds: current.participantUserIds,
            chatThreadId: current.chatThreadId
        )
        mockGroups[index] = updated
        groupUpdatesSubject.send(updated)
    }
    
    public func updateRSVP(groupId: String, attending: Bool) async throws {
        try await simulateNetworkDelay()
        
        guard let index = mockGroups.firstIndex(where: { $0.id == groupId }) else {
            throw EventsError.groupNotFound
        }
        
        let current = mockGroups[index]
        var participants = current.participantUserIds
        if attending {
            if !participants.contains("current_user") {
                participants.append("current_user")
            }
            let updated = AttendanceGroup(
                id: current.id,
                organizerId: current.organizerId,
                eventId: current.eventId,
                sessionId: current.sessionId,
                name: current.name,
                status: .confirmed,
                invitedUserIds: current.invitedUserIds,
                participantUserIds: participants,
                chatThreadId: current.chatThreadId
            )
            mockGroups[index] = updated
            groupUpdatesSubject.send(updated)
        } else {
            participants.removeAll { $0 == "current_user" }
            let updated = AttendanceGroup(
                id: current.id,
                organizerId: current.organizerId,
                eventId: current.eventId,
                sessionId: current.sessionId,
                name: current.name,
                status: current.status,
                invitedUserIds: current.invitedUserIds,
                participantUserIds: participants,
                chatThreadId: current.chatThreadId
            )
            mockGroups[index] = updated
            groupUpdatesSubject.send(updated)
        }
    }
    
    public func getMyGroups() async throws -> [AttendanceGroup] {
        try await simulateNetworkDelay()
        return mockGroups.filter { 
            $0.participantUserIds.contains("current_user") || 
            $0.organizerId == "current_user" 
        }
    }
    
    public func getGroup(id: String) async throws -> AttendanceGroup? {
        try await simulateNetworkDelay()
        return mockGroups.first { $0.id == id }
    }
    
    public func leaveGroup(groupId: String) async throws {
        try await simulateNetworkDelay()
        
        guard let index = mockGroups.firstIndex(where: { $0.id == groupId }) else {
            throw EventsError.groupNotFound
        }
        
        let current = mockGroups[index]
        let newParticipants = current.participantUserIds.filter { $0 != "current_user" }
        let updated = AttendanceGroup(
            id: current.id,
            organizerId: current.organizerId,
            eventId: current.eventId,
            sessionId: current.sessionId,
            name: current.name,
            status: current.status,
            invitedUserIds: current.invitedUserIds,
            participantUserIds: newParticipants,
            chatThreadId: current.chatThreadId
        )
        mockGroups[index] = updated
        groupUpdatesSubject.send(updated)
    }
    
    // MARK: - Tickets & Orders
    
    public func linkExternalTickets(_ link: TicketLink) async throws -> TicketLinkResult {
        try await simulateNetworkDelay()
        
        // Simulate parsing external ticket URL
        let ticketCodes = ["TKT-\(UUID().uuidString.prefix(8))", "TKT-\(UUID().uuidString.prefix(8))"]
        
        return TicketLinkResult(
            success: true,
            ticketCodes: ticketCodes,
            message: "Successfully linked \(ticketCodes.count) tickets"
        )
    }
    
    public func createTicketOrder(_ request: TicketOrderRequest) async throws -> TicketOrder {
        try await simulateNetworkDelay()
        
        let order = TicketOrder(
            id: UUID().uuidString,
            groupId: request.groupId,
            eventId: request.eventId,
            sessionId: request.sessionId,
            promoterId: "mock_promoter",
            organizerId: "current_user",
            lineItems: request.lineItems,
            totalAmount: request.lineItems.reduce(0) { $0 + ($1.unitPrice * Double($1.quantity)) },
            currency: "MAD",
            status: .pending,
            paymentIntentId: "pi_\(UUID().uuidString)",
            tickets: [],
            settlement: nil
        )
        
        mockOrders.append(order)
        orderUpdatesSubject.send(order)
        
        // Simulate order confirmation after delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if let idx = mockOrders.firstIndex(where: { $0.id == order.id }) {
                let current = mockOrders[idx]
                let confirmed = TicketOrder(
                    id: current.id,
                    groupId: current.groupId,
                    eventId: current.eventId,
                    sessionId: current.sessionId,
                    promoterId: current.promoterId,
                    organizerId: current.organizerId,
                    lineItems: current.lineItems,
                    totalAmount: current.totalAmount,
                    currency: current.currency,
                    status: .confirmed,
                    paymentIntentId: current.paymentIntentId,
                    tickets: current.tickets,
                    settlement: current.settlement
                )
                mockOrders[idx] = confirmed
                orderUpdatesSubject.send(confirmed)
            }
        }
        
        return order
    }
    
    public func getOrder(id: String) async throws -> TicketOrder? {
        try await simulateNetworkDelay()
        return mockOrders.first { $0.id == id }
    }
    
    public func getMyOrders() async throws -> [TicketOrder] {
        try await simulateNetworkDelay()
        return mockOrders.filter { $0.organizerId == "current_user" }
    }
    
    public func confirmOrder(orderId: String) async throws -> TicketOrder {
        try await simulateNetworkDelay()
        
        guard let index = mockOrders.firstIndex(where: { $0.id == orderId }) else {
            throw EventsError.orderNotFound
        }
        
        let current = mockOrders[index]
        // Generate mock tickets compatible with Ticket model
        var tickets: [Ticket] = []
        for lineItem in current.lineItems {
            for _ in 0..<lineItem.quantity {
                let code = "TKT-\(UUID().uuidString.prefix(8))"
                tickets.append(Ticket(code: code, qrUrl: nil, seat: lineItem.tierName))
            }
        }
        
        let updated = TicketOrder(
            id: current.id,
            groupId: current.groupId,
            eventId: current.eventId,
            sessionId: current.sessionId,
            promoterId: current.promoterId,
            organizerId: current.organizerId,
            lineItems: current.lineItems,
            totalAmount: current.totalAmount,
            currency: current.currency,
            status: .confirmed,
            paymentIntentId: current.paymentIntentId,
            tickets: tickets,
            settlement: current.settlement
        )
        
        mockOrders[index] = updated
        orderUpdatesSubject.send(updated)
        
        return updated
    }
    
    public func cancelOrder(orderId: String) async throws {
        try await simulateNetworkDelay()
        
        guard let index = mockOrders.firstIndex(where: { $0.id == orderId }) else {
            throw EventsError.orderNotFound
        }
        
        let current = mockOrders[index]
        let updated = TicketOrder(
            id: current.id,
            groupId: current.groupId,
            eventId: current.eventId,
            sessionId: current.sessionId,
            promoterId: current.promoterId,
            organizerId: current.organizerId,
            lineItems: current.lineItems,
            totalAmount: current.totalAmount,
            currency: current.currency,
            status: .cancelled,
            paymentIntentId: current.paymentIntentId,
            tickets: current.tickets,
            settlement: current.settlement
        )
        mockOrders[index] = updated
        orderUpdatesSubject.send(updated)
    }
    
    // MARK: - Split Payments
    
    public func createSplitIntent(_ request: SplitIntentRequest) async throws -> SplitIntent {
        try await simulateNetworkDelay()
        
        guard let order = mockOrders.first(where: { $0.id == request.orderId }) else {
            throw EventsError.orderNotFound
        }
        
        let count = request.customShares?.count ?? 2
        let equalAmount = order.totalAmount / Double(max(count, 1))
        
        let shares: [SplitShare]
        if let custom = request.customShares, !custom.isEmpty {
            shares = custom.map { SplitShare(userId: $0.key, amount: $0.value, isPaid: false) }
        } else {
            shares = [
                SplitShare(userId: "user1", amount: equalAmount, isPaid: false),
                SplitShare(userId: "user2", amount: equalAmount, isPaid: false)
            ]
        }
        
        return SplitIntent(
            orderId: request.orderId,
            shareType: request.shareType,
            shares: shares,
            expiresAt: Date().addingTimeInterval(86400) // 24 hours
        )
    }
    
    public func getSplitIntent(id: String) async throws -> SplitIntent? {
        try await simulateNetworkDelay()
        
        return SplitIntent(
            id: id,
            orderId: "mock_order",
            shareType: .even,
            shares: [
                SplitShare(userId: "user1", amount: 250, isPaid: true),
                SplitShare(userId: "user2", amount: 250, isPaid: false)
            ],
            expiresAt: Date().addingTimeInterval(86400)
        )
    }
    
    public func paySplit(splitId: String) async throws {
        try await simulateNetworkDelay()
        // Mock payment processing
    }
    
    // MARK: - Promoters
    
    public func getPromoter(id: String) async throws -> EventPromoter? {
        try await simulateNetworkDelay()
        
        return EventPromoter(
            id: id,
            name: "Mock Entertainment",
            contact: PromoterContact(
                email: "contact@mockentertainment.com",
                phone: "+212600000000",
                website: "https://mockentertainment.com"
            ),
            verificationTier: .verified,
            payoutAccount: nil,
            isActive: true
        )
    }
    
    public func getPromoterEvents(promoterId: String) async throws -> [Event] {
        try await simulateNetworkDelay()
        return mockEvents.filter { $0.promoterId == promoterId }
    }
    
    // MARK: - AI Assistant
    
    public func askAI(_ query: String, context: [String: Any]) async throws -> EventAIResponse {
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds for AI processing
        
        let suggestedEvents = Array(mockEvents.prefix(3))
        
        return EventAIResponse(
            answer: generateMockAIResponse(query),
            suggestedEvents: suggestedEvents,
            reasonCodes: ["personalized", "trending", "nearby"],
            followUpPrompts: [
                "Show me events this weekend",
                "Find family-friendly activities",
                "What's popular in my area?"
            ]
        )
    }
    
    public func createEventAlert(criteria: EventFilters) async throws -> String {
        try await simulateNetworkDelay()
        return "alert_\(UUID().uuidString)"
    }
    
    public func deleteEventAlert(alertId: String) async throws {
        try await simulateNetworkDelay()
    }
    
    // MARK: - Friends & Social
    
    public func getFriends() async throws -> [EventsFriend] {
        try await simulateNetworkDelay()
        
        if mockFriends.isEmpty {
            setupMockFriends()
        }
        
        return mockFriends
    }
    
    public func getFriendActivity() async throws -> [FriendEventActivity] {
        try await simulateNetworkDelay()
        
        return [
            FriendEventActivity(
                friendId: "friend_1",
                friendName: "Sarah Chen",
                eventId: mockEvents.first?.id ?? "event_1",
                eventTitle: mockEvents.first?.title ?? "Jazz Night",
                activityType: .attending,
                timestamp: Date().addingTimeInterval(-3600)
            ),
            FriendEventActivity(
                friendId: "friend_2",
                friendName: "Ahmed Hassan",
                eventId: mockEvents.last?.id ?? "event_2",
                eventTitle: mockEvents.last?.title ?? "Tech Summit",
                activityType: .interested,
                timestamp: Date().addingTimeInterval(-7200)
            )
        ]
    }
    
    public func getEventsWithFriends() async throws -> [(Event, [EventsFriend])] {
        try await simulateNetworkDelay()
        
        var results: [(Event, [EventsFriend])] = []
        
        for event in mockEvents.prefix(3) {
            let attendingFriends = Array(mockFriends.shuffled().prefix(Int.random(in: 1...3)))
            results.append((event, attendingFriends))
        }
        
        return results
    }
    
    public func sendEventInvite(eventId: String, friendIds: [String], message: String?) async throws {
        try await simulateNetworkDelay()
        
        for friendId in friendIds {
            let invite = EventInvite(
                fromUserId: "current_user",
                fromUserName: "You",
                toUserId: friendId,
                eventId: eventId,
                eventTitle: mockEvents.first { $0.id == eventId }?.title ?? "Event",
                message: message
            )
            mockInvites.append(invite)
            inviteUpdatesSubject.send(invite)
        }
    }
    
    public func getEventInvites() async throws -> [EventInvite] {
        try await simulateNetworkDelay()
        return mockInvites.filter { $0.toUserId == "current_user" && $0.response == nil }
    }
    
    public func respondToInvite(inviteId: String, response: InviteResponse) async throws {
        try await simulateNetworkDelay()
        
        guard let index = mockInvites.firstIndex(where: { $0.id == inviteId }) else {
            throw EventsError.invalidRequest
        }
        
        let current = mockInvites[index]
        let updated = EventInvite(
            id: current.id,
            fromUserId: current.fromUserId,
            fromUserName: current.fromUserName,
            toUserId: current.toUserId,
            eventId: current.eventId,
            eventTitle: current.eventTitle,
            message: current.message,
            createdAt: current.createdAt,
            response: response,
            respondedAt: Date()
        )
        mockInvites[index] = updated
        inviteUpdatesSubject.send(updated)
    }
    
    // MARK: - Chat & Messaging
    
    public func getGroupChatId(groupId: String) async throws -> String? {
        try await simulateNetworkDelay()
        
        guard let group = mockGroups.first(where: { $0.id == groupId }) else {
            return nil
        }
        
        return group.chatThreadId
    }
    
    public func createGroupChat(groupId: String) async throws -> String {
        try await simulateNetworkDelay()
        
        let chatId = "chat_\(UUID().uuidString)"
        
        // Add welcome message
        let welcomeMessage = GroupChatMessage(
            chatId: chatId,
            userId: "system",
            userName: "System",
            content: "Welcome to the group chat! Coordinate your plans here.",
            messageType: .system,
            readBy: [],
            isSystemMessage: true
        )
        
        if mockMessages[chatId] == nil {
            mockMessages[chatId] = []
        }
        mockMessages[chatId]?.append(welcomeMessage)
        
        return chatId
    }
    
    public func sendGroupMessage(chatId: String, message: String) async throws {
        try await simulateNetworkDelay()
        
        let newMessage = GroupChatMessage(
            chatId: chatId,
            userId: "current_user",
            userName: "You",
            content: message,
            messageType: .text,
            readBy: ["current_user"]
        )
        
        if mockMessages[chatId] == nil {
            mockMessages[chatId] = []
        }
        mockMessages[chatId]?.append(newMessage)
        chatMessageSubject.send(newMessage)
        
        // Simulate friend response after delay
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            let response = GroupChatMessage(
                chatId: chatId,
                userId: "friend_1",
                userName: "Sarah",
                content: "Sounds great! Count me in 🎉",
                messageType: .text,
                readBy: []
            )
            mockMessages[chatId]?.append(response)
            chatMessageSubject.send(response)
        }
    }
    
    public func getGroupMessages(chatId: String, limit: Int) async throws -> [GroupChatMessage] {
        try await simulateNetworkDelay()
        
        guard let messages = mockMessages[chatId] else {
            return []
        }
        
        return Array(messages.suffix(limit))
    }
    
    public func markMessagesRead(chatId: String, messageIds: [String]) async throws {
        try await simulateNetworkDelay()
        
        guard let existing = mockMessages[chatId] else { return }
        var updatedMessages: [GroupChatMessage] = []
        updatedMessages.reserveCapacity(existing.count)
        for msg in existing {
            if messageIds.contains(msg.id) && !msg.readBy.contains("current_user") {
                let newMsg = GroupChatMessage(
                    id: msg.id,
                    chatId: msg.chatId,
                    userId: msg.userId,
                    userName: msg.userName,
                    userAvatarURL: msg.userAvatarURL,
                    content: msg.content,
                    messageType: msg.messageType,
                    timestamp: msg.timestamp,
                    readBy: msg.readBy + ["current_user"],
                    isSystemMessage: msg.isSystemMessage,
                    replyToId: msg.replyToId
                )
                updatedMessages.append(newMsg)
            } else {
                updatedMessages.append(msg)
            }
        }
        mockMessages[chatId] = updatedMessages
    }
    
    // MARK: - Ride Integration
    
    public func getRideQuote(eventId: String, pickupLocation: LocationCoordinate, departureTime: Date?, passengerCount: Int?) async throws -> RideQuote {
        try await simulateNetworkDelay()
        
        guard let event = mockEvents.first(where: { $0.id == eventId }) else {
            throw EventsError.eventNotFound
        }
        
        let dropoffLocation = LocationCoordinate(
            latitude: event.location.latitude,
            longitude: event.location.longitude,
            address: event.venueName
        )
        
        let departure = departureTime ?? event.startAt.addingTimeInterval(-1800) // 30 min before
        let passengers = passengerCount ?? 1
        
        return RideQuote(
            eventId: eventId,
            pickupLocation: pickupLocation,
            dropoffLocation: dropoffLocation,
            departureTime: departure,
            estimatedDuration: Int.random(in: 15...45),
            estimatedFare: 50 + (passengers * 10),
            passengerCount: passengers,
            vehicleType: passengers > 4 ? "SUV" : "Sedan",
            expiresAt: Date().addingTimeInterval(900), // 15 minutes
            deepLinkUrl: "liive://ride/book?event=\(eventId)"
        )
    }
    
    public func bookEventRide(quoteId: String, groupId: String?, shareRide: Bool?) async throws -> RideBookingResult {
        try await simulateNetworkDelay()
        
        return RideBookingResult(
            bookingId: "booking_\(UUID().uuidString)",
            status: "pending",
            deepLinks: RideDeepLinks(
                uber: "uber://ride?event=mock",
                careem: "careem://ride?event=mock",
                inDrive: "indrive://ride?event=mock",
                liiveRide: "liive://ride/book?event=mock"
            ),
            estimatedFare: 75,
            departureTime: Date().addingTimeInterval(7200),
            message: "Ride booking initiated"
        )
    }
    
    public func getEventRideBookings(eventId: String) async throws -> [RideBookingRequest] {
        try await simulateNetworkDelay()
        return []
    }
    
    // MARK: - Helper Methods
    
    private func setupMockData() {
        // Create sample events
        mockEvents = [
            createMockEvent(
                id: "1",
                title: "Jazz Night at Blue Note",
                category: .music,
                description: "An evening of smooth jazz featuring local and international artists",
                venueName: "Blue Note Casablanca",
                price: 150,
                startDate: Date().addingTimeInterval(86400 * 3) // 3 days from now
            ),
            createMockEvent(
                id: "2",
                title: "Moroccan Food Festival",
                category: .culture,
                description: "Celebrate the rich flavors of Moroccan cuisine with top chefs",
                venueName: "Hassan II Square",
                price: 0,
                startDate: Date().addingTimeInterval(86400 * 7) // 1 week from now
            ),
            createMockEvent(
                id: "3",
                title: "Tech Summit Morocco 2024",
                category: .conference,
                description: "Connect with tech leaders and innovators from across Africa",
                venueName: "Casablanca Convention Center",
                price: 500,
                startDate: Date().addingTimeInterval(86400 * 14) // 2 weeks from now
            ),
            createMockEvent(
                id: "4",
                title: "Stand-up Comedy Night",
                category: .theater,
                description: "Laugh out loud with Morocco's funniest comedians",
                venueName: "L'Uzine",
                price: 100,
                startDate: Date().addingTimeInterval(86400 * 5)
            ),
            createMockEvent(
                id: "5",
                title: "Art Exhibition: Modern Morocco",
                category: .culture,
                description: "Explore contemporary Moroccan art from emerging artists",
                venueName: "Villa des Arts",
                price: 50,
                startDate: Date().addingTimeInterval(86400 * 10)
            ),
            createMockEvent(
                id: "6",
                title: "Beach Volleyball Tournament",
                category: .sports,
                description: "Join the summer beach volleyball championship",
                venueName: "Ain Diab Beach",
                price: 200,
                startDate: Date().addingTimeInterval(86400 * 12)
            ),
            createMockEvent(
                id: "7",
                title: "Kids Science Workshop",
                category: .family,
                description: "Fun and educational science experiments for children",
                venueName: "Morocco Mall",
                price: 80,
                startDate: Date().addingTimeInterval(86400 * 6)
            ),
            createMockEvent(
                id: "8",
                title: "Sunset Yoga Session",
                category: .other,
                description: "Relax and rejuvenate with yoga by the ocean",
                venueName: "Corniche Beach",
                price: 60,
                startDate: Date().addingTimeInterval(86400 * 2)
            )
        ]
    }
    
    private func setupMockFriends() {
        mockFriends = [
            EventsFriend(
                id: "friend_1",
                name: "Sarah Chen",
                profileImageURL: URL(string: "https://example.com/sarah.jpg"),
                preferredCategories: [.music, .culture],
                mutualFriendsCount: 12,
                isOnline: true
            ),
            EventsFriend(
                id: "friend_2",
                name: "Ahmed Hassan",
                profileImageURL: URL(string: "https://example.com/ahmed.jpg"),
                preferredCategories: [.sports, .conference],
                mutualFriendsCount: 8,
                isOnline: false,
                lastSeen: Date().addingTimeInterval(-3600)
            ),
            EventsFriend(
                id: "friend_3",
                name: "Maria Rodriguez",
                profileImageURL: URL(string: "https://example.com/maria.jpg"),
                preferredCategories: [.culture, .family],
                mutualFriendsCount: 15,
                isOnline: true
            ),
            EventsFriend(
                id: "friend_4",
                name: "Youssef El Amrani",
                profileImageURL: URL(string: "https://example.com/youssef.jpg"),
                preferredCategories: [.theater, .music],
                mutualFriendsCount: 5,
                isOnline: false,
                lastSeen: Date().addingTimeInterval(-7200)
            )
        ]
    }
    
    private func createMockEvent(
        id: String,
        title: String,
        category: EventCategory,
        description: String,
        venueName: String,
        price: Double,
        startDate: Date
    ) -> Event {
        let priceTiers: [PriceTier] = price == 0 ? 
            [PriceTier(name: "Free", priceMAD: 0, description: "Free admission")] :
            [
                PriceTier(name: "General", priceMAD: price, description: "General admission"),
                PriceTier(name: "VIP", priceMAD: price * 2, description: "VIP experience with extras")
            ]
        
        return Event(
            id: "event_\(id)",
            promoterId: "promoter_\(id)",
            title: title,
            category: category,
            description: description,
            images: [
                "https://picsum.photos/400/300?random=\(id)",
                "https://picsum.photos/400/300?random=\(id)_2"
            ],
            rules: ["No outside food or drinks", "Age 18+ with valid ID", "Doors close 30 minutes after start"],
            priceTiers: priceTiers,
            location: GeoPoint(latitude: 33.5731 + Double.random(in: -0.05...0.05),
                                longitude: -7.5898 + Double.random(in: -0.05...0.05)),
            venueName: venueName,
            neighborhood: ["Maarif", "Gauthier", "Anfa", "Corniche"].randomElement()!,
            startAt: startDate,
            endAt: startDate.addingTimeInterval(10800), // 3 hours
            indoor: Bool.random(),
            tags: generateTags(for: category),
            seating: SeatingInfo(hasSeatMap: false, generalAdmission: true),
            status: .published
        )
    }
    
    private func generateTags(for category: EventCategory) -> [String] {
        switch category {
        case .music:
            return ["live music", "jazz", "nightlife", "entertainment"]
        case .culture:
            return ["culture", "festival", "exhibition", "art"]
        case .sports:
            return ["fitness", "competition", "outdoor"]
        case .theater:
            return ["performance", "standup", "comedy"]
        case .conference:
            return ["networking", "technology", "innovation", "professional"]
        case .family:
            return ["kids", "educational", "family-friendly"]
        case .other:
            return ["event", "casablanca", "entertainment"]
        }
    }
    
    private func generateMockAIResponse(_ query: String) -> String {
        let lowerQuery = query.lowercased()
        
        if lowerQuery.contains("jazz") || lowerQuery.contains("music") {
            return "I found some great music events coming up! The Jazz Night at Blue Note features amazing local and international artists. It's happening in 3 days and promises to be an unforgettable evening of smooth jazz."
        } else if lowerQuery.contains("family") || lowerQuery.contains("kids") {
            return "Looking for family activities? The Kids Science Workshop at Morocco Mall is perfect! It's educational and fun, with hands-on experiments that children love. There's also the Moroccan Food Festival which is free and family-friendly."
        } else if lowerQuery.contains("weekend") {
            return "This weekend has some exciting options! The Sunset Yoga Session is happening in 2 days if you want to relax by the ocean. For something more lively, the Jazz Night at Blue Note is in 3 days."
        } else if lowerQuery.contains("cheap") || lowerQuery.contains("free") || lowerQuery.contains("budget") {
            return "Great news for budget-conscious event goers! The Moroccan Food Festival at Hassan II Square is completely free. The Art Exhibition at Villa des Arts is also very affordable at just 50 MAD."
        } else {
            return "I've found several interesting events that might match what you're looking for. From music and arts to sports and wellness, there's something for everyone in Casablanca this week. What type of experience are you in the mood for?"
        }
    }
    
    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
}

// MARK: - Firebase GeoPoint Mock (unused, kept for compatibility)

public struct FirebaseGeoPoint: Codable, Hashable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}