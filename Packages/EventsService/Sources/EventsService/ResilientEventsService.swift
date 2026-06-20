import Foundation
import Combine

/// Resilient Events Service with comprehensive error handling and offline support
public final class ResilientEventsService: EventsServicing, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: EventsError?
    @Published public private(set) var isOffline: Bool = false
    
    // MARK: - Private Properties
    
    private let baseService: EventsServicing
    private let errorBoundary: EventsErrorBoundaryService
    private let offlineStorage: EventsOfflineStorageService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Real-time Updates
    
    public var groupUpdates: AnyPublisher<AttendanceGroup, Never> {
        baseService.groupUpdates
    }
    
    public var orderUpdates: AnyPublisher<TicketOrder, Never> {
        baseService.orderUpdates
    }
    
    public var eventUpdates: AnyPublisher<Event, Never> {
        baseService.eventUpdates
    }
    
    public var friendActivityUpdates: AnyPublisher<FriendEventActivity, Never> {
        baseService.friendActivityUpdates
    }
    
    public var inviteUpdates: AnyPublisher<EventInvite, Never> {
        baseService.inviteUpdates
    }
    
    public var chatMessageUpdates: AnyPublisher<GroupChatMessage, Never> {
        baseService.chatMessageUpdates
    }
    
    // MARK: - Initialization
    
    public init(baseService: EventsServicing) {
        self.baseService = baseService
        self.errorBoundary = EventsErrorBoundaryService()
        self.offlineStorage = EventsOfflineStorageService()
        
        setupBindings()
    }
    
    // MARK: - Discovery & Search
    
    public func searchEvents(_ query: String, filters: EventFilters) async throws -> [Event] {
        return try await executeWithResilience {
            try await self.baseService.searchEvents(query, filters: filters)
        } fallback: {
            // Return cached events if offline
            let cached = self.offlineStorage.getCachedEvents()
            return self.filterCachedEvents(cached, query: query, filters: filters)
        }
    }
    
    public func getEvent(id: String) async throws -> Event? {
        return try await executeWithResilience {
            let event = try await self.baseService.getEvent(id: id)
            // Cache the event
            if let event = event {
                self.offlineStorage.cacheEvents([event])
            }
            return event
        } fallback: {
            // Try to find in cache
            return self.offlineStorage.getCachedEvents().first { $0.id == id }
        }
    }
    
    public func getUpcomingEvents(limit: Int) async throws -> [Event] {
        return try await executeWithResilience {
            let events = try await self.baseService.getUpcomingEvents(limit: limit)
            self.offlineStorage.cacheEvents(events)
            return events
        } fallback: {
            let cached = self.offlineStorage.getCachedEvents()
            return Array(cached.prefix(limit))
        }
    }
    
    public func getEventsByCategory(_ category: EventCategory, limit: Int) async throws -> [Event] {
        return try await executeWithResilience {
            try await self.baseService.getEventsByCategory(category, limit: limit)
        } fallback: {
            let cached = self.offlineStorage.getCachedEvents()
            return Array(cached.filter { $0.category == category }.prefix(limit))
        }
    }
    
    // MARK: - Event Sessions
    
    public func getEventSessions(eventId: String) async throws -> [EventSession] {
        return try await executeWithResilience {
            try await self.baseService.getEventSessions(eventId: eventId)
        }
    }
    
    public func getSession(id: String) async throws -> EventSession? {
        return try await executeWithResilience {
            try await self.baseService.getSession(id: id)
        }
    }
    
    // MARK: - Groups & RSVPs
    
    public func createAttendanceGroup(_ draft: AttendanceGroupDraft) async throws -> AttendanceGroup {
        return try await executeWithResilience {
            try await self.baseService.createAttendanceGroup(draft)
        } fallback: {
            // Queue for offline sync
            self.offlineStorage.queueOfflineAction(OfflineAction(
                type: .createGroup,
                data: [
                    "eventId": draft.eventId,
                    "sessionId": draft.sessionId ?? "",
                    "name": draft.name,
                    "invitedUserIds": draft.invitedUserIds
                ]
            ))
            
            // Return optimistic result
            return AttendanceGroup(
                id: UUID().uuidString,
                organizerId: "current_user", // Would get from auth
                eventId: draft.eventId,
                sessionId: draft.sessionId,
                name: draft.name,
                status: .planning,
                invitedUserIds: draft.invitedUserIds,
                participantUserIds: ["current_user"],
                chatThreadId: nil
            )
        }
    }
    
    public func inviteFriends(groupId: String, userIds: [String]) async throws {
        try await executeWithResilience {
            try await self.baseService.inviteFriends(groupId: groupId, userIds: userIds)
        }
    }
    
    public func updateRSVP(groupId: String, attending: Bool) async throws {
        try await executeWithResilience {
            try await self.baseService.updateRSVP(groupId: groupId, attending: attending)
        } fallback: {
            // Queue for offline sync
            self.offlineStorage.queueOfflineAction(OfflineAction(
                type: .updateRSVP,
                data: [
                    "groupId": groupId,
                    "attending": attending
                ]
            ))
        }
    }
    
    public func getMyGroups() async throws -> [AttendanceGroup] {
        return try await executeWithResilience {
            let groups = try await self.baseService.getMyGroups()
            self.offlineStorage.cacheGroups(groups)
            return groups
        } fallback: {
            return self.offlineStorage.getCachedGroups()
        }
    }
    
    public func getGroup(id: String) async throws -> AttendanceGroup? {
        return try await executeWithResilience {
            try await self.baseService.getGroup(id: id)
        } fallback: {
            return self.offlineStorage.getCachedGroups().first { $0.id == id }
        }
    }
    
    public func leaveGroup(groupId: String) async throws {
        try await executeWithResilience {
            try await self.baseService.leaveGroup(groupId: groupId)
        }
    }
    
    // MARK: - Tickets & Orders
    
    public func linkExternalTickets(_ link: TicketLink) async throws -> TicketLinkResult {
        return try await executeWithResilience {
            try await self.baseService.linkExternalTickets(link)
        }
    }
    
    public func createTicketOrder(_ request: TicketOrderRequest) async throws -> TicketOrder {
        return try await executeWithResilience {
            try await self.baseService.createTicketOrder(request)
        } fallback: {
            // Queue for offline sync
            self.offlineStorage.queueOfflineAction(OfflineAction(
                type: .createOrder,
                data: [
                    "groupId": request.groupId,
                    "eventId": request.eventId,
                    "sessionId": request.sessionId ?? "",
                    "lineItems": request.lineItems.map { item in
                        [
                            "tierName": item.tierName,
                            "quantity": item.quantity,
                            "unitPrice": item.unitPrice
                        ]
                    }
                ]
            ))
            
            // Return optimistic result
            return TicketOrder(
                id: UUID().uuidString,
                groupId: request.groupId,
                eventId: request.eventId,
                sessionId: request.sessionId,
                promoterId: "unknown_promoter",
                organizerId: "current_user",
                lineItems: request.lineItems.map { item in
                    OrderLineItem(
                        tierName: item.tierName,
                        quantity: item.quantity,
                        unitPrice: item.unitPrice
                    )
                },
                totalAmount: request.lineItems.reduce(0.0) { sum, item in
                    sum + (item.unitPrice * Double(item.quantity))
                },
                currency: "MAD",
                status: .pending,
                paymentIntentId: nil,
                tickets: [],
                settlement: nil
            )
        }
    }
    
    public func getOrder(id: String) async throws -> TicketOrder? {
        return try await executeWithResilience {
            try await self.baseService.getOrder(id: id)
        } fallback: {
            return self.offlineStorage.getCachedOrders().first { $0.id == id }
        }
    }
    
    public func getMyOrders() async throws -> [TicketOrder] {
        return try await executeWithResilience {
            let orders = try await self.baseService.getMyOrders()
            self.offlineStorage.cacheOrders(orders)
            return orders
        } fallback: {
            return self.offlineStorage.getCachedOrders()
        }
    }
    
    public func confirmOrder(orderId: String) async throws -> TicketOrder {
        return try await executeWithResilience {
            try await self.baseService.confirmOrder(orderId: orderId)
        }
    }
    
    public func cancelOrder(orderId: String) async throws {
        try await executeWithResilience {
            try await self.baseService.cancelOrder(orderId: orderId)
        }
    }
    
    // MARK: - Split Payments
    
    public func createSplitIntent(_ request: SplitIntentRequest) async throws -> SplitIntent {
        return try await executeWithResilience {
            try await self.baseService.createSplitIntent(request)
        }
    }
    
    public func getSplitIntent(id: String) async throws -> SplitIntent? {
        return try await executeWithResilience {
            try await self.baseService.getSplitIntent(id: id)
        }
    }
    
    public func paySplit(splitId: String) async throws {
        try await executeWithResilience {
            try await self.baseService.paySplit(splitId: splitId)
        }
    }
    
    // MARK: - Promoters
    
    public func getPromoter(id: String) async throws -> EventPromoter? {
        return try await executeWithResilience {
            try await self.baseService.getPromoter(id: id)
        }
    }
    
    public func getPromoterEvents(promoterId: String) async throws -> [Event] {
        return try await executeWithResilience {
            try await self.baseService.getPromoterEvents(promoterId: promoterId)
        }
    }
    
    // MARK: - AI Assistant
    
    public func askAI(_ query: String, context: [String: Any]) async throws -> EventAIResponse {
        return try await executeWithResilience {
            try await self.baseService.askAI(query, context: context)
        }
    }
    
    public func createEventAlert(criteria: EventFilters) async throws -> String {
        return try await executeWithResilience {
            try await self.baseService.createEventAlert(criteria: criteria)
        }
    }
    
    public func deleteEventAlert(alertId: String) async throws {
        try await executeWithResilience {
            try await self.baseService.deleteEventAlert(alertId: alertId)
        }
    }
    
    // MARK: - Friends & Social
    
    public func getFriends() async throws -> [EventsFriend] {
        return try await executeWithResilience {
            let friends = try await self.baseService.getFriends()
            self.offlineStorage.cacheFriends(friends)
            return friends
        } fallback: {
            return self.offlineStorage.getCachedFriends()
        }
    }
    
    public func getFriendActivity() async throws -> [FriendEventActivity] {
        return try await executeWithResilience {
            try await self.baseService.getFriendActivity()
        }
    }
    
    public func getEventsWithFriends() async throws -> [(Event, [EventsFriend])] {
        return try await executeWithResilience {
            try await self.baseService.getEventsWithFriends()
        }
    }
    
    public func sendEventInvite(eventId: String, friendIds: [String], message: String?) async throws {
        try await executeWithResilience {
            try await self.baseService.sendEventInvite(eventId: eventId, friendIds: friendIds, message: message)
        }
    }
    
    public func getEventInvites() async throws -> [EventInvite] {
        return try await executeWithResilience {
            try await self.baseService.getEventInvites()
        }
    }
    
    public func respondToInvite(inviteId: String, response: InviteResponse) async throws {
        try await executeWithResilience {
            try await self.baseService.respondToInvite(inviteId: inviteId, response: response)
        }
    }
    
    // MARK: - Chat & Messaging
    
    public func getGroupChatId(groupId: String) async throws -> String? {
        return try await executeWithResilience {
            try await self.baseService.getGroupChatId(groupId: groupId)
        }
    }
    
    public func createGroupChat(groupId: String) async throws -> String {
        return try await executeWithResilience {
            try await self.baseService.createGroupChat(groupId: groupId)
        }
    }
    
    public func sendGroupMessage(chatId: String, message: String) async throws {
        try await executeWithResilience {
            try await self.baseService.sendGroupMessage(chatId: chatId, message: message)
        } fallback: {
            // Queue for offline sync
            self.offlineStorage.queueOfflineAction(OfflineAction(
                type: .sendMessage,
                data: [
                    "chatId": chatId,
                    "message": message
                ]
            ))
        }
    }
    
    public func getGroupMessages(chatId: String, limit: Int) async throws -> [GroupChatMessage] {
        return try await executeWithResilience {
            try await self.baseService.getGroupMessages(chatId: chatId, limit: limit)
        }
    }
    
    public func markMessagesRead(chatId: String, messageIds: [String]) async throws {
        try await executeWithResilience {
            try await self.baseService.markMessagesRead(chatId: chatId, messageIds: messageIds)
        }
    }
    
    // MARK: - Ride Integration
    
    public func getRideQuote(eventId: String, pickupLocation: LocationCoordinate, departureTime: Date?, passengerCount: Int?) async throws -> RideQuote {
        return try await executeWithResilience {
            try await self.baseService.getRideQuote(
                eventId: eventId,
                pickupLocation: pickupLocation,
                departureTime: departureTime,
                passengerCount: passengerCount
            )
        }
    }
    
    public func bookEventRide(quoteId: String, groupId: String?, shareRide: Bool?) async throws -> RideBookingResult {
        return try await executeWithResilience {
            try await self.baseService.bookEventRide(quoteId: quoteId, groupId: groupId, shareRide: shareRide)
        }
    }
    
    public func getEventRideBookings(eventId: String) async throws -> [RideBookingRequest] {
        return try await executeWithResilience {
            try await self.baseService.getEventRideBookings(eventId: eventId)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind error boundary state
        errorBoundary.$isOffline
            .assign(to: \.isOffline, on: self)
            .store(in: &cancellables)
        
        errorBoundary.$networkError
            .compactMap { $0 }
            .map { EventsError.networkError }
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
    }
    
    private func executeWithResilience<T>(
        operation: @escaping () async throws -> T,
        fallback: (() async -> T)? = nil
    ) async throws -> T {
        setLoading(true)
        defer { setLoading(false) }
        
        let result = await errorBoundary.execute(
            operation: operation,
            fallback: fallback,
            retryPolicy: .exponentialBackoff
        )
        
        switch result {
        case .success(let value):
            clearError()
            return value
        case .failure(let error):
            setError(error)
            throw error
        }
    }
    
    private func setLoading(_ loading: Bool) {
        Task { @MainActor in
            self.isLoading = loading
        }
    }
    
    private func setError(_ error: EventsError) {
        Task { @MainActor in
            self.error = error
        }
    }
    
    private func clearError() {
        Task { @MainActor in
            self.error = nil
        }
    }
    
    private func filterCachedEvents(
        _ events: [Event],
        query: String,
        filters: EventFilters
    ) -> [Event] {
        var filtered = events
        
        // Apply text filter
        if !query.isEmpty {
            let searchTerms = query.lowercased().components(separatedBy: " ")
            filtered = filtered.filter { event in
                let searchableText = [
                    event.title,
                    event.description,
                    event.venueName
                ].joined(separator: " ").lowercased()
                
                return searchTerms.allSatisfy { searchableText.contains($0) }
            }
        }
        
        // Apply category filter
        if let cats = filters.categories, !cats.isEmpty {
            filtered = filtered.filter { cats.contains($0.category) }
        }
        
        // Apply date range filter
        if let dateRange = filters.dateRange {
            filtered = filtered.filter { event in
                event.startAt >= dateRange.from && event.startAt <= dateRange.to
            }
        }
        
        return filtered
    }
}