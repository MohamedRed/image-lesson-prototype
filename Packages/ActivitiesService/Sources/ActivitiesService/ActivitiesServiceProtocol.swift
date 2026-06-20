import Foundation
import Combine

public protocol ActivitiesServiceProtocol {
    // MARK: - Activity Catalog
    func getActivities(
        cityId: String,
        filters: ActivityFilters?
    ) -> AnyPublisher<[Activity], Error>
    
    func getActivity(id: String) -> AnyPublisher<Activity?, Error>
    
    func getActivitySessions(
        activityId: String,
        dateRange: DateRange?
    ) -> AnyPublisher<[ActivitySession], Error>
    
    func getProviders(cityId: String) -> AnyPublisher<[ActivityProvider], Error>
    
    // MARK: - Search
    func searchActivities(
        query: String,
        cityId: String,
        filters: ActivityFilters?,
        limit: Int
    ) -> AnyPublisher<ActivitySearchResponse, Error>
    
    func getRecommendations(
        cityId: String,
        limit: Int
    ) -> AnyPublisher<[Activity], Error>
    
    // MARK: - Groups
    func createGroup(request: GroupCreationRequest) -> AnyPublisher<String, Error>
    
    func getGroup(id: String) -> AnyPublisher<ActivityGroup?, Error>
    
    func getUserGroups(status: GroupStatus?) -> AnyPublisher<[ActivityGroup], Error>
    
    func inviteToGroup(
        groupId: String,
        userIds: [String],
        message: String?
    ) -> AnyPublisher<Void, Error>
    
    func respondToInvitation(
        groupId: String,
        response: InvitationResponse
    ) -> AnyPublisher<Void, Error>
    
    func leaveGroup(groupId: String) -> AnyPublisher<Void, Error>
    
    func updateGroupPreferences(
        groupId: String,
        preferences: GroupPreferences
    ) -> AnyPublisher<Void, Error>
    
    // MARK: - Bookings
    func createBooking(request: BookingCreationRequest) -> AnyPublisher<String, Error>
    
    func getBooking(id: String) -> AnyPublisher<Booking?, Error>
    
    func getUserBookings(status: BookingStatus?) -> AnyPublisher<[Booking], Error>
    
    func cancelBooking(
        bookingId: String,
        reason: String
    ) -> AnyPublisher<Void, Error>
    
    func confirmBooking(bookingId: String) -> AnyPublisher<Void, Error>
    
    // MARK: - Split Payments
    func createSplitIntent(
        bookingId: String,
        shareType: SplitShareType,
        customShares: [CustomShare]?
    ) -> AnyPublisher<String, Error>
    
    func getSplitIntent(id: String) -> AnyPublisher<SplitIntent?, Error>
    
    func paySplitShare(
        splitId: String,
        paymentMethodId: String
    ) -> AnyPublisher<PaymentResult, Error>
    
    func cancelSplitIntent(splitId: String) -> AnyPublisher<Void, Error>
    
    // MARK: - Partner Matching
    func createPartnerRequest(
        request: PartnerRequestDraft
    ) -> AnyPublisher<String, Error>
    
    func getPartnerRequests(
        cityId: String,
        category: ActivityCategory?,
        neighborhood: String?
    ) -> AnyPublisher<[PartnerRequest], Error>
    
    func expressInterest(requestId: String) -> AnyPublisher<Void, Error>
    
    func matchPartners(requestId: String) -> AnyPublisher<[PartnerCandidate], Error>
    
    func acceptPartner(
        requestId: String,
        partnerUserId: String,
        groupName: String?
    ) -> AnyPublisher<String, Error>
    
    func closePartnerRequest(requestId: String) -> AnyPublisher<Void, Error>
    
    // MARK: - AI Features
    func getActivityPerspectives(activityId: String) -> AnyPublisher<ActivityPerspectives, Error>
    
    func generateGroupSuggestions(
        groupId: String
    ) -> AnyPublisher<[ActivitySuggestion], Error>
}

// MARK: - Supporting Types
public struct ActivityFilters: Codable {
    public let categories: [ActivityCategory]?
    public let priceRange: PriceRange?
    public let skillLevels: [SkillLevel]?
    public let dateRange: DateRange?
    public let location: LocationFilter?
    
    public init(
        categories: [ActivityCategory]? = nil,
        priceRange: PriceRange? = nil,
        skillLevels: [SkillLevel]? = nil,
        dateRange: DateRange? = nil,
        location: LocationFilter? = nil
    ) {
        self.categories = categories
        self.priceRange = priceRange
        self.skillLevels = skillLevels
        self.dateRange = dateRange
        self.location = location
    }
}

public struct PriceRange: Codable {
    public let min: Double
    public let max: Double
    
    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }
}

public struct LocationFilter: Codable {
    public let centerLatitude: Double
    public let centerLongitude: Double
    public let radiusKm: Double
    
    public init(centerLatitude: Double, centerLongitude: Double, radiusKm: Double) {
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.radiusKm = radiusKm
    }
}

public struct DateRange: Codable {
    public let from: Date
    public let to: Date
    
    public init(from: Date, to: Date) {
        self.from = from
        self.to = to
    }
}

public struct GroupCreationRequest {
    public let name: String
    public let cityId: String
    public let preferences: GroupPreferences
    public let invitedUserIds: [String]
    
    public init(
        name: String,
        cityId: String,
        preferences: GroupPreferences,
        invitedUserIds: [String] = []
    ) {
        self.name = name
        self.cityId = cityId
        self.preferences = preferences
        self.invitedUserIds = invitedUserIds
    }
}

public struct BookingCreationRequest {
    public let groupId: String
    public let activityId: String
    public let sessionId: String
    public let participants: [BookingParticipant]
    
    public init(
        groupId: String,
        activityId: String,
        sessionId: String,
        participants: [BookingParticipant]
    ) {
        self.groupId = groupId
        self.activityId = activityId
        self.sessionId = sessionId
        self.participants = participants
    }
}

public struct PaymentResult {
    public let success: Bool
    public let paymentIntentId: String
    public let status: String
    public let clientSecret: String?
    
    public init(success: Bool, paymentIntentId: String, status: String, clientSecret: String? = nil) {
        self.success = success
        self.paymentIntentId = paymentIntentId
        self.status = status
        self.clientSecret = clientSecret
    }
}

public struct ActivitySearchResponse {
    public let activities: [Activity]
    public let total: Int
    public let searchMetrics: SearchMetrics?
    
    public init(activities: [Activity], total: Int, searchMetrics: SearchMetrics? = nil) {
        self.activities = activities
        self.total = total
        self.searchMetrics = searchMetrics
    }
}

public struct SearchMetrics {
    public let queryTime: TimeInterval
    public let resultCount: Int
    public let filters: [String]
    
    public init(queryTime: TimeInterval, resultCount: Int, filters: [String]) {
        self.queryTime = queryTime
        self.resultCount = resultCount
        self.filters = filters
    }
}

public struct ActivityPerspectives {
    public let beginnerTips: [String]
    public let expertInsights: [String]
    public let safetyNotes: [String]
    public let culturalContext: String?
    
    public init(
        beginnerTips: [String],
        expertInsights: [String],
        safetyNotes: [String],
        culturalContext: String? = nil
    ) {
        self.beginnerTips = beginnerTips
        self.expertInsights = expertInsights
        self.safetyNotes = safetyNotes
        self.culturalContext = culturalContext
    }
}

public struct ActivitySuggestion {
    public let activityId: String
    public let title: String
    public let reason: String
    public let matchScore: Double
    
    public init(activityId: String, title: String, reason: String, matchScore: Double) {
        self.activityId = activityId
        self.title = title
        self.reason = reason
        self.matchScore = matchScore
    }
}