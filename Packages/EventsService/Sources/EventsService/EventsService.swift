import Foundation
import Combine

/// Events service protocol defining all event-related operations
public protocol EventsServicing {
    // MARK: - Discovery & Search
    func searchEvents(_ query: String, filters: EventFilters) async throws -> [Event]
    func getEvent(id: String) async throws -> Event?
    func getUpcomingEvents(limit: Int) async throws -> [Event]
    func getEventsByCategory(_ category: EventCategory, limit: Int) async throws -> [Event]
    
    // MARK: - Event Sessions
    func getEventSessions(eventId: String) async throws -> [EventSession]
    func getSession(id: String) async throws -> EventSession?
    
    // MARK: - Groups & RSVPs
    func createAttendanceGroup(_ draft: AttendanceGroupDraft) async throws -> AttendanceGroup
    func inviteFriends(groupId: String, userIds: [String]) async throws
    func updateRSVP(groupId: String, attending: Bool) async throws
    func getMyGroups() async throws -> [AttendanceGroup]
    func getGroup(id: String) async throws -> AttendanceGroup?
    func leaveGroup(groupId: String) async throws
    
    // MARK: - Tickets & Orders
    func linkExternalTickets(_ link: TicketLink) async throws -> TicketLinkResult
    func createTicketOrder(_ request: TicketOrderRequest) async throws -> TicketOrder
    func getOrder(id: String) async throws -> TicketOrder?
    func getMyOrders() async throws -> [TicketOrder]
    func confirmOrder(orderId: String) async throws -> TicketOrder
    func cancelOrder(orderId: String) async throws
    
    // MARK: - Split Payments
    func createSplitIntent(_ request: SplitIntentRequest) async throws -> SplitIntent
    func getSplitIntent(id: String) async throws -> SplitIntent?
    func paySplit(splitId: String) async throws
    
    // MARK: - Promoters
    func getPromoter(id: String) async throws -> EventPromoter?
    func getPromoterEvents(promoterId: String) async throws -> [Event]
    
    // MARK: - AI Assistant
    func askAI(_ query: String, context: [String: Any]) async throws -> EventAIResponse
    func createEventAlert(criteria: EventFilters) async throws -> String
    func deleteEventAlert(alertId: String) async throws
    
    // MARK: - Friends & Social
    func getFriends() async throws -> [EventsFriend]
    func getFriendActivity() async throws -> [FriendEventActivity]
    func getEventsWithFriends() async throws -> [(Event, [EventsFriend])]
    func sendEventInvite(eventId: String, friendIds: [String], message: String?) async throws
    func getEventInvites() async throws -> [EventInvite]
    func respondToInvite(inviteId: String, response: InviteResponse) async throws
    
    // MARK: - Chat & Messaging  
    func getGroupChatId(groupId: String) async throws -> String?
    func createGroupChat(groupId: String) async throws -> String
    func sendGroupMessage(chatId: String, message: String) async throws
    func getGroupMessages(chatId: String, limit: Int) async throws -> [GroupChatMessage]
    func markMessagesRead(chatId: String, messageIds: [String]) async throws
    
    // MARK: - Ride Integration
    func getRideQuote(eventId: String, pickupLocation: LocationCoordinate, departureTime: Date?, passengerCount: Int?) async throws -> RideQuote
    func bookEventRide(quoteId: String, groupId: String?, shareRide: Bool?) async throws -> RideBookingResult  
    func getEventRideBookings(eventId: String) async throws -> [RideBookingRequest]
    
    // MARK: - Real-time Updates
    var groupUpdates: AnyPublisher<AttendanceGroup, Never> { get }
    var orderUpdates: AnyPublisher<TicketOrder, Never> { get }
    var eventUpdates: AnyPublisher<Event, Never> { get }
    var friendActivityUpdates: AnyPublisher<FriendEventActivity, Never> { get }
    var inviteUpdates: AnyPublisher<EventInvite, Never> { get }
    var chatMessageUpdates: AnyPublisher<GroupChatMessage, Never> { get }
}

/// Analytics events for tracking
public enum EventsAnalyticsEvent: String {
    case eventViewed = "event_viewed"
    case eventSaved = "event_saved"
    case eventShared = "event_shared"
    case groupCreated = "group_created"
    case groupJoined = "group_joined"
    case rsvpCreated = "rsvp_created"
    case orderCreated = "order_created"
    case orderConfirmed = "order_confirmed"
    case splitPaid = "split_paid"
    case aiQueryRun = "ai_query_run"
    case aiSuggestionClicked = "ai_suggestion_clicked"
    case ticketLinked = "ticket_linked"
    case rideQuoteRequested = "ride_quote_requested"
}

/// Error types for Events operations
public enum EventsError: LocalizedError {
    case eventNotFound
    case groupNotFound
    case orderNotFound
    case sessionNotFound
    case promoterNotFound
    case invalidRequest
    case insufficientCapacity
    case paymentFailed
    case unauthorized
    case networkError
    case serverError(String)
    
    public var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return "Event not found"
        case .groupNotFound:
            return "Attendance group not found"
        case .orderNotFound:
            return "Order not found"
        case .sessionNotFound:
            return "Session not found"
        case .promoterNotFound:
            return "Promoter not found"
        case .invalidRequest:
            return "Invalid request"
        case .insufficientCapacity:
            return "Not enough tickets available"
        case .paymentFailed:
            return "Payment processing failed"
        case .unauthorized:
            return "You don't have permission to perform this action"
        case .networkError:
            return "Network connection error"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}