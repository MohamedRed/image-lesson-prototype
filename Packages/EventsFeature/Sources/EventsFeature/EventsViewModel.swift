import SwiftUI
import Combine
import EventsService

@MainActor
public final class EventsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var upcomingEvents: [Event] = []
    @Published var trendingEvents: [Event] = []
    @Published var myGroups: [AttendanceGroup] = []
    @Published var myOrders: [TicketOrder] = []
    @Published var searchResults: [Event] = []
    @Published var selectedEvent: Event?
    @Published var selectedGroup: AttendanceGroup?
    @Published var currentFilters = EventFilters()
    @Published var searchQuery = ""
    @Published var aiMessages: [AIMessage] = []
    @Published var aiResponse: EventAIResponse?
    
    // MARK: - UI State
    
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSearch = false
    @Published var showEventDetail = false
    @Published var showGroupCreation = false
    
    // MARK: - Services
    
    private let eventsService: EventsServicing
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(eventsService: EventsServicing? = nil) {
        // Use provided service or create one based on environment
        self.eventsService = eventsService ?? EventsServiceFactory.createService()
        setupSubscriptions()
    }
    
    // MARK: - Data Loading
    
    func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadUpcomingEvents()
            }
            group.addTask {
                await self.loadMyGroups()
            }
            group.addTask {
                await self.loadMyOrders()
            }
        }
    }
    
    func loadUpcomingEvents() async {
        do {
            let events = try await eventsService.getUpcomingEvents(limit: 20)
            await MainActor.run {
                self.upcomingEvents = events
            }
        } catch {
            await handleError(error)
        }
    }
    
    func loadEventsByCategory(_ category: EventCategory) async {
        do {
            let events = try await eventsService.getEventsByCategory(category, limit: 10)
            await MainActor.run {
                self.trendingEvents = events
            }
        } catch {
            await handleError(error)
        }
    }
    
    func loadMyGroups() async {
        do {
            let groups = try await eventsService.getMyGroups()
            await MainActor.run {
                self.myGroups = groups
            }
        } catch {
            await handleError(error)
        }
    }
    
    func loadMyOrders() async {
        do {
            let orders = try await eventsService.getMyOrders()
            await MainActor.run {
                self.myOrders = orders
            }
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - Search
    
    func performSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isSearching = true
        
        do {
            let results = try await eventsService.searchEvents(searchQuery, filters: currentFilters)
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        } catch {
            await MainActor.run {
                self.isSearching = false
            }
            await handleError(error)
        }
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        currentFilters = EventFilters()
    }
    
    // MARK: - Event Actions
    
    func selectEvent(_ event: Event) {
        selectedEvent = event
        showEventDetail = true
    }
    
    func saveEvent(_ event: Event) async {
        // TODO: Implement save/bookmark functionality
        do {
            // Track save interaction
            // Analytics would be tracked in the service layer
        } catch {
            await handleError(error)
        }
    }
    
    func shareEvent(_ event: Event) {
        // TODO: Implement sharing functionality
    }
    
    // MARK: - Group Actions
    
    func createGroup(for event: Event, name: String, invitedFriends: [String]) async {
        do {
            let draft = AttendanceGroupDraft(
                eventId: event.id!,
                sessionId: nil, // User can select session later
                name: name,
                invitedUserIds: invitedFriends
            )
            
            let group = try await eventsService.createAttendanceGroup(draft)
            
            await MainActor.run {
                self.myGroups.append(group)
                self.selectedGroup = group
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    func joinGroup(_ groupId: String) async {
        do {
            try await eventsService.updateRSVP(groupId: groupId, attending: true)
            await loadMyGroups()
        } catch {
            await handleError(error)
        }
    }
    
    func leaveGroup(_ groupId: String) async {
        do {
            try await eventsService.leaveGroup(groupId: groupId)
            await loadMyGroups()
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - Ticket Actions
    
    func createOrder(for group: AttendanceGroup, lineItems: [OrderLineItem]) async {
        do {
            let request = TicketOrderRequest(
                groupId: group.id!,
                eventId: group.eventId,
                sessionId: group.sessionId,
                lineItems: lineItems
            )
            
            let order = try await eventsService.createTicketOrder(request)
            
            await MainActor.run {
                self.myOrders.append(order)
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    func linkExternalTickets(groupId: String, eventId: String, url: String) async {
        do {
            let link = TicketLink(
                groupId: groupId,
                eventId: eventId,
                externalUrl: url
            )
            
            let result = try await eventsService.linkExternalTickets(link)
            
            if !result.success {
                await handleError(EventsError.serverError(result.message ?? "Failed to link tickets"))
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - AI Assistant
    
    func sendAIMessage(_ message: String) async {
        let userMessage = AIMessage(content: message, isUser: true, timestamp: Date())
        aiMessages.append(userMessage)
        
        do {
            let response = try await eventsService.askAI(message, context: buildAIContext())
            
            let assistantMessage = AIMessage(
                content: response.answer,
                isUser: false,
                timestamp: Date(),
                suggestedEvents: response.suggestedEvents
            )
            
            await MainActor.run {
                self.aiMessages.append(assistantMessage)
                self.aiResponse = response
            }
            
        } catch {
            let errorMessage = AIMessage(
                content: "I'm sorry, I couldn't process your request right now. Please try again.",
                isUser: false,
                timestamp: Date()
            )
            
            await MainActor.run {
                self.aiMessages.append(errorMessage)
            }
            
            await handleError(error)
        }
    }
    
    func createEventAlert(_ criteria: EventFilters) async {
        do {
            let alertId = try await eventsService.createEventAlert(criteria: criteria)
            // Handle success (show confirmation)
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - Event Sessions
    
    func getEventSessions(eventId: String) async throws -> [EventSession] {
        try await eventsService.getEventSessions(eventId: eventId)
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Real-time updates
        eventsService.groupUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedGroup in
                guard let self = self else { return }
                
                if let index = self.myGroups.firstIndex(where: { $0.id == updatedGroup.id }) {
                    self.myGroups[index] = updatedGroup
                }
            }
            .store(in: &cancellables)
        
        eventsService.orderUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedOrder in
                guard let self = self else { return }
                
                if let index = self.myOrders.firstIndex(where: { $0.id == updatedOrder.id }) {
                    self.myOrders[index] = updatedOrder
                }
            }
            .store(in: &cancellables)
    }
    
    private func buildAIContext() -> [String: Any] {
        var context: [String: Any] = [:]
        
        // Add user's current groups and interests
        context["currentGroups"] = myGroups.count
        context["upcomingEvents"] = upcomingEvents.count
        
        // Add location context if available
        // context["location"] = userLocation
        
        return context
    }
    
    private func handleError(_ error: Error) async {
        await MainActor.run {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
}

// MARK: - AI Message Model

public struct AIMessage: Identifiable {
    public let id = UUID()
    public let content: String
    public let isUser: Bool
    public let timestamp: Date
    public let suggestedEvents: [Event]?
    
    public init(content: String, isUser: Bool, timestamp: Date, suggestedEvents: [Event]? = nil) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.suggestedEvents = suggestedEvents
    }
}