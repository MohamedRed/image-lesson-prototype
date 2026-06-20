import Foundation
import Combine
import ActivitiesService

@MainActor
class ActivitiesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var activities: [Activity] = []
    @Published var myGroups: [ActivityGroup] = []
    @Published var myBookings: [Booking] = []
    @Published var partnerRequests: [PartnerRequest] = []
    @Published var recommendations: [Activity] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedFilters = ActivityFilters()
    
    // MARK: - State Management
    @Published var selectedActivity: Activity?
    @Published var selectedGroup: ActivityGroup?
    @Published var selectedBooking: Booking?
    @Published var showingActivityDetail = false
    @Published var showingGroupDetail = false
    @Published var showingBookingDetail = false
    @Published var showingCreateGroup = false
    @Published var showingCreatePartnerRequest = false
    @Published var showingSplitPayment = false
    
    // MARK: - Dependencies
    private let activitiesService: ActivitiesServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let defaultCityId = "casablanca" // TODO: Get from user location/preferences
    
    init(activitiesService: ActivitiesServiceProtocol = FirestoreActivitiesService()) {
        self.activitiesService = activitiesService
        setupSearchBinding()
    }
    
    // MARK: - Initial Data Loading
    func loadInitialData() {
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadActivities() }
                group.addTask { await self.loadMyGroups() }
                group.addTask { await self.loadMyBookings() }
                group.addTask { await self.loadRecommendations() }
                group.addTask { await self.loadPartnerRequests() }
            }
        }
    }
    
    // MARK: - Activity Operations
    func loadActivities() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let activities = try await activitiesService
                .getActivities(cityId: defaultCityId, filters: selectedFilters)
                .async()
            
            self.activities = activities
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadRecommendations() async {
        do {
            let recommendations = try await activitiesService
                .getRecommendations(cityId: defaultCityId, limit: 10)
                .async()
            
            self.recommendations = recommendations
        } catch {
            // Silently fail for recommendations
            print("Failed to load recommendations: \(error)")
        }
    }
    
    func searchActivities() async {
        guard !searchText.isEmpty else {
            await loadActivities()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await activitiesService
                .searchActivities(
                    query: searchText,
                    cityId: defaultCityId,
                    filters: selectedFilters,
                    limit: 50
                )
                .async()
            
            self.activities = response.activities
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func selectActivity(_ activity: Activity) {
        selectedActivity = activity
        showingActivityDetail = true
    }
    
    // Allow views to fetch sessions without exposing the service
    func fetchActivitySessions(activityId: String, dateRange: DateRange?) async throws -> [ActivitySession] {
        try await activitiesService
            .getActivitySessions(activityId: activityId, dateRange: dateRange)
            .async()
    }
    
    // MARK: - Group Operations
    func loadMyGroups() async {
        do {
            let groups = try await activitiesService
                .getUserGroups(status: nil)
                .async()
            
            self.myGroups = groups
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func createGroup(name: String, preferences: GroupPreferences, invitedUserIds: [String] = []) async {
        do {
            let request = GroupCreationRequest(
                name: name,
                cityId: defaultCityId,
                preferences: preferences,
                invitedUserIds: invitedUserIds
            )
            
            let groupId = try await activitiesService
                .createGroup(request: request)
                .async()
            
            // Reload groups to include the new one
            await loadMyGroups()
            
            showingCreateGroup = false
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func selectGroup(_ group: ActivityGroup) {
        selectedGroup = group
        showingGroupDetail = true
    }
    
    func inviteToGroup(groupId: String, userIds: [String], message: String? = nil) async {
        do {
            try await activitiesService
                .inviteToGroup(groupId: groupId, userIds: userIds, message: message)
                .async()
            
            // Reload groups to get updated invitation status
            await loadMyGroups()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func respondToInvitation(groupId: String, response: InvitationResponse) async {
        do {
            try await activitiesService
                .respondToInvitation(groupId: groupId, response: response)
                .async()
            
            // Reload groups to reflect the response
            await loadMyGroups()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func leaveGroup(groupId: String) async {
        do {
            try await activitiesService
                .leaveGroup(groupId: groupId)
                .async()
            
            // Remove from local list and reload
            await loadMyGroups()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Booking Operations
    func loadMyBookings() async {
        do {
            let bookings = try await activitiesService
                .getUserBookings(status: nil)
                .async()
            
            self.myBookings = bookings
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func createBooking(
        groupId: String,
        activityId: String,
        sessionId: String,
        participants: [BookingParticipant]
    ) async {
        do {
            let request = BookingCreationRequest(
                groupId: groupId,
                activityId: activityId,
                sessionId: sessionId,
                participants: participants
            )
            
            let bookingId = try await activitiesService
                .createBooking(request: request)
                .async()
            
            // Reload bookings to include the new one
            await loadMyBookings()
            await loadMyGroups() // Groups status may have changed
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func selectBooking(_ booking: Booking) {
        selectedBooking = booking
        showingBookingDetail = true
    }
    
    func cancelBooking(bookingId: String, reason: String) async {
        do {
            try await activitiesService
                .cancelBooking(bookingId: bookingId, reason: reason)
                .async()
            
            // Reload bookings to reflect cancellation
            await loadMyBookings()
            await loadMyGroups()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Split Payment Operations
    func createSplitPayment(
        bookingId: String,
        shareType: SplitShareType,
        customShares: [CustomShare]? = nil
    ) async {
        do {
            let splitId = try await activitiesService
                .createSplitIntent(
                    bookingId: bookingId,
                    shareType: shareType,
                    customShares: customShares
                )
                .async()
            
            // Reload bookings to reflect split payment status
            await loadMyBookings()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func paySplitShare(splitId: String, paymentMethodId: String) async {
        do {
            let result = try await activitiesService
                .paySplitShare(splitId: splitId, paymentMethodId: paymentMethodId)
                .async()
            
            if result.success {
                // Reload bookings to reflect payment
                await loadMyBookings()
                showingSplitPayment = false
            } else {
                self.errorMessage = "Payment failed: \(result.status)"
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Partner Matching Operations
    func loadPartnerRequests() async {
        do {
            let requests = try await activitiesService
                .getPartnerRequests(
                    cityId: defaultCityId,
                    category: nil,
                    neighborhood: nil
                )
                .async()
            
            self.partnerRequests = requests
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func createPartnerRequest(_ request: PartnerRequestDraft) async {
        do {
            let requestId = try await activitiesService
                .createPartnerRequest(request: request)
                .async()
            
            // Reload partner requests
            await loadPartnerRequests()
            showingCreatePartnerRequest = false
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func expressInterest(in requestId: String) async {
        do {
            try await activitiesService
                .expressInterest(requestId: requestId)
                .async()
            
            // Reload to reflect interest
            await loadPartnerRequests()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func matchPartners(for requestId: String) async -> [PartnerCandidate] {
        do {
            return try await activitiesService
                .matchPartners(requestId: requestId)
                .async()
        } catch {
            self.errorMessage = error.localizedDescription
            return []
        }
    }
    
    func acceptPartner(requestId: String, partnerUserId: String, groupName: String? = nil) async {
        do {
            let groupId = try await activitiesService
                .acceptPartner(
                    requestId: requestId,
                    partnerUserId: partnerUserId,
                    groupName: groupName
                )
                .async()
            
            // Reload all relevant data
            await loadPartnerRequests()
            await loadMyGroups()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - AI Features
    func getActivityPerspectives(for activityId: String) async -> ActivityPerspectives? {
        do {
            return try await activitiesService
                .getActivityPerspectives(activityId: activityId)
                .async()
        } catch {
            print("Failed to load activity perspectives: \(error)")
            return nil
        }
    }
    
    func generateGroupSuggestions(for groupId: String) async -> [ActivitySuggestion] {
        do {
            return try await activitiesService
                .generateGroupSuggestions(groupId: groupId)
                .async()
        } catch {
            print("Failed to generate group suggestions: \(error)")
            return []
        }
    }
    
    // MARK: - Filter Management
    func updateFilters(_ filters: ActivityFilters) {
        selectedFilters = filters
        Task {
            if searchText.isEmpty {
                await loadActivities()
            } else {
                await searchActivities()
            }
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    private func setupSearchBinding() {
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.searchActivities()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Publisher Extension for Async/Await
extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = self
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        case .finished:
                            break
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
}