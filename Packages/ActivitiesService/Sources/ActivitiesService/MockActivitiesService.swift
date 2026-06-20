import Foundation
import Combine

public class MockActivitiesService: ActivitiesServiceProtocol, ObservableObject {
    
    // MARK: - Mock Data Storage
    private var mockActivities: [Activity] = []
    private var mockGroups: [ActivityGroup] = []
    private var mockBookings: [Booking] = []
    private var mockProviders: [ActivityProvider] = []
    private var mockPartnerRequests: [PartnerRequest] = []
    private var mockSplitIntents: [SplitIntent] = []
    
    // MARK: - Initialization
    public init() {
        setupMockData()
    }
    
    // MARK: - Activity Catalog
    
    public func getActivities(cityId: String, filters: ActivityFilters?) -> AnyPublisher<[Activity], Error> {
        let filtered = mockActivities.filter { activity in
            // Apply filters if provided
            if let filters = filters {
                if let categories = filters.categories, !categories.isEmpty {
                    guard categories.contains(activity.category) else { return false }
                }
                
                if let priceRange = filters.priceRange {
                    guard activity.pricePerUnit >= priceRange.min && activity.pricePerUnit <= priceRange.max else { return false }
                }
                
                if let skillLevels = filters.skillLevels, !skillLevels.isEmpty {
                    if let activitySkill = activity.skillLevel {
                        guard skillLevels.contains(activitySkill) else { return false }
                    }
                }
            }
            return true
        }
        
        return Just(filtered)
            .delay(for: .milliseconds(500), scheduler: RunLoop.main) // Simulate network delay
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func getActivity(id: String) -> AnyPublisher<Activity?, Error> {
        let activity = mockActivities.first { $0.id == id }
        return Just(activity)
            .delay(for: .milliseconds(300), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func getActivitySessions(activityId: String, dateRange: DateRange?) -> AnyPublisher<[ActivitySession], Error> {
        // Generate mock sessions for the activity
        let sessions = generateMockSessions(for: activityId, dateRange: dateRange)
        return Just(sessions)
            .delay(for: .milliseconds(400), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func getProviders(cityId: String) -> AnyPublisher<[ActivityProvider], Error> {
        return Just(mockProviders)
            .delay(for: .milliseconds(300), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Search
    
    public func searchActivities(query: String, cityId: String, filters: ActivityFilters?, limit: Int) -> AnyPublisher<ActivitySearchResponse, Error> {
        let searchResults = mockActivities.filter { activity in
            activity.title.localizedCaseInsensitiveContains(query) ||
            activity.description.localizedCaseInsensitiveContains(query) ||
            activity.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
        
        let limited = Array(searchResults.prefix(limit))
        let response = ActivitySearchResponse(
            activities: limited,
            total: searchResults.count,
            searchMetrics: SearchMetrics(
                queryTime: 0.15,
                resultCount: limited.count,
                filters: filters?.categories?.map { $0.rawValue } ?? []
            )
        )
        
        return Just(response)
            .delay(for: .milliseconds(600), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func getRecommendations(cityId: String, limit: Int) -> AnyPublisher<[Activity], Error> {
        let recommendations = Array(mockActivities.shuffled().prefix(limit))
        return Just(recommendations)
            .delay(for: .milliseconds(400), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Groups
    
    public func createGroup(request: GroupCreationRequest) -> AnyPublisher<String, Error> {
        let groupId = UUID().uuidString
        let newGroup = ActivityGroup(
            id: groupId,
            organizerId: "current_user_id",
            name: request.name,
            cityId: request.cityId,
            status: .planning,
            preferences: request.preferences,
            invitedUserIds: request.invitedUserIds,
            participantUserIds: ["current_user_id"],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        mockGroups.append(newGroup)
        
        return Just(groupId)
            .delay(for: .milliseconds(800), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func getGroup(id: String) -> AnyPublisher<ActivityGroup?, Error> {
        let group = mockGroups.first { $0.id == id }
        return Just(group)
            .delay(for: .milliseconds(300), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func getUserGroups(status: GroupStatus?) -> AnyPublisher<[ActivityGroup], Error> {
        var filtered = mockGroups.filter { group in
            group.participantUserIds.contains("current_user_id") || group.organizerId == "current_user_id"
        }
        
        if let status = status {
            filtered = filtered.filter { $0.status == status }
        }
        
        return Just(filtered)
            .delay(for: .milliseconds(400), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func inviteToGroup(groupId: String, userIds: [String], message: String?) -> AnyPublisher<Void, Error> {
        if let index = mockGroups.firstIndex(where: { $0.id == groupId }) {
            var g = mockGroups[index]
            g = ActivityGroup(
                id: g.id,
                organizerId: g.organizerId,
                name: g.name,
                activityId: g.activityId,
                sessionId: g.sessionId,
                cityId: g.cityId,
                status: g.status,
                preferences: g.preferences,
                invitedUserIds: g.invitedUserIds + userIds,
                participantUserIds: g.participantUserIds,
                partnerRequestId: g.partnerRequestId,
                chatThreadId: g.chatThreadId,
                createdAt: g.createdAt,
                updatedAt: Date()
            )
            mockGroups[index] = g
        }
        
        return Just(())
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func respondToInvitation(groupId: String, response: InvitationResponse) -> AnyPublisher<Void, Error> {
        if let index = mockGroups.firstIndex(where: { $0.id == groupId }) {
            var g = mockGroups[index]
            var participants = g.participantUserIds
            var invited = g.invitedUserIds
            if response == .accepted { participants.append("current_user_id") }
            invited.removeAll { $0 == "current_user_id" }
            g = ActivityGroup(
                id: g.id,
                organizerId: g.organizerId,
                name: g.name,
                activityId: g.activityId,
                sessionId: g.sessionId,
                cityId: g.cityId,
                status: g.status,
                preferences: g.preferences,
                invitedUserIds: invited,
                participantUserIds: participants,
                partnerRequestId: g.partnerRequestId,
                chatThreadId: g.chatThreadId,
                createdAt: g.createdAt,
                updatedAt: Date()
            )
            mockGroups[index] = g
        }
        
        return Just(())
            .delay(for: .milliseconds(400), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func leaveGroup(groupId: String) -> AnyPublisher<Void, Error> {
        if let index = mockGroups.firstIndex(where: { $0.id == groupId }) {
            var g = mockGroups[index]
            var participants = g.participantUserIds
            participants.removeAll { $0 == "current_user_id" }
            g = ActivityGroup(
                id: g.id,
                organizerId: g.organizerId,
                name: g.name,
                activityId: g.activityId,
                sessionId: g.sessionId,
                cityId: g.cityId,
                status: g.status,
                preferences: g.preferences,
                invitedUserIds: g.invitedUserIds,
                participantUserIds: participants,
                partnerRequestId: g.partnerRequestId,
                chatThreadId: g.chatThreadId,
                createdAt: g.createdAt,
                updatedAt: Date()
            )
            mockGroups[index] = g
        }
        
        return Just(())
            .delay(for: .milliseconds(400), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func updateGroupPreferences(groupId: String, preferences: GroupPreferences) -> AnyPublisher<Void, Error> {
        if let index = mockGroups.firstIndex(where: { $0.id == groupId }) {
            let g = mockGroups[index]
            mockGroups[index] = ActivityGroup(
                id: g.id,
                organizerId: g.organizerId,
                name: g.name,
                activityId: g.activityId,
                sessionId: g.sessionId,
                cityId: g.cityId,
                status: g.status,
                preferences: preferences,
                invitedUserIds: g.invitedUserIds,
                participantUserIds: g.participantUserIds,
                partnerRequestId: g.partnerRequestId,
                chatThreadId: g.chatThreadId,
                createdAt: g.createdAt,
                updatedAt: Date()
            )
        }
        
        return Just(())
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Bookings
    
    public func createBooking(request: BookingCreationRequest) -> AnyPublisher<String, Error> {
        let bookingId = UUID().uuidString
        let newBooking = Booking(
            id: bookingId,
            groupId: request.groupId,
            activityId: request.activityId,
            sessionId: request.sessionId,
            organizerId: "current_user_id",
            participants: request.participants,
            totalAmount: Double.random(in: 50...300),
            currency: "MAD",
            status: .pending,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        mockBookings.append(newBooking)
        
        return Just(bookingId)
            .delay(for: .milliseconds(800), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func getBooking(id: String) -> AnyPublisher<Booking?, Error> {
        let booking = mockBookings.first { $0.id == id }
        return Just(booking)
            .delay(for: .milliseconds(300), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func getUserBookings(status: BookingStatus?) -> AnyPublisher<[Booking], Error> {
        var filtered = mockBookings.filter { booking in
            booking.organizerId == "current_user_id" || 
            booking.participants.contains { $0.userId == "current_user_id" }
        }
        
        if let status = status {
            filtered = filtered.filter { $0.status == status }
        }
        
        return Just(filtered)
            .delay(for: .milliseconds(400), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func cancelBooking(bookingId: String, reason: String) -> AnyPublisher<Void, Error> {
        if let index = mockBookings.firstIndex(where: { $0.id == bookingId }) {
            var b = mockBookings[index]
            b = Booking(
                id: b.id,
                groupId: b.groupId,
                activityId: b.activityId,
                sessionId: b.sessionId,
                organizerId: b.organizerId,
                participants: b.participants,
                totalAmount: b.totalAmount,
                currency: b.currency,
                status: .cancelled,
                paymentIntentId: b.paymentIntentId,
                settlement: b.settlement,
                cancellation: b.cancellation,
                createdAt: b.createdAt,
                updatedAt: Date()
            )
            mockBookings[index] = b
        }
        
        return Just(())
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func confirmBooking(bookingId: String) -> AnyPublisher<Void, Error> {
        if let index = mockBookings.firstIndex(where: { $0.id == bookingId }) {
            var b = mockBookings[index]
            b = Booking(
                id: b.id,
                groupId: b.groupId,
                activityId: b.activityId,
                sessionId: b.sessionId,
                organizerId: b.organizerId,
                participants: b.participants,
                totalAmount: b.totalAmount,
                currency: b.currency,
                status: .confirmed,
                paymentIntentId: b.paymentIntentId,
                settlement: b.settlement,
                cancellation: b.cancellation,
                createdAt: b.createdAt,
                updatedAt: Date()
            )
            mockBookings[index] = b
        }
        
        return Just(())
            .delay(for: .milliseconds(600), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Split Payments
    
    public func createSplitIntent(bookingId: String, shareType: SplitShareType, customShares: [CustomShare]?) -> AnyPublisher<String, Error> {
        let splitId = UUID().uuidString
        let splitIntent = SplitIntent(
            id: splitId,
            bookingId: bookingId,
            shareType: shareType,
            shares: customShares?.map { share in
                SplitShare(
                    userId: share.userId,
                    userName: "",
                    amount: share.amount,
                    status: .pending
                )
            } ?? [],
            status: .pending,
            expiresAt: Date().addingTimeInterval(7*24*60*60),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        mockSplitIntents.append(splitIntent)
        
        return Just(splitId)
            .delay(for: .milliseconds(700), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func getSplitIntent(id: String) -> AnyPublisher<SplitIntent?, Error> {
        let splitIntent = mockSplitIntents.first { $0.id == id }
        return Just(splitIntent)
            .delay(for: .milliseconds(300), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func paySplitShare(splitId: String, paymentMethodId: String) -> AnyPublisher<PaymentResult, Error> {
        let result = PaymentResult(
            success: true,
            paymentIntentId: "pi_mock_\(UUID().uuidString)",
            status: "succeeded",
            clientSecret: nil
        )
        
        return Just(result)
            .delay(for: .milliseconds(1000), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func cancelSplitIntent(splitId: String) -> AnyPublisher<Void, Error> {
        if let index = mockSplitIntents.firstIndex(where: { $0.id == splitId }) {
            let s = mockSplitIntents[index]
            mockSplitIntents[index] = SplitIntent(
                id: s.id,
                bookingId: s.bookingId,
                shareType: s.shareType,
                shares: s.shares,
                status: .cancelled,
                expiresAt: s.expiresAt,
                createdAt: s.createdAt,
                updatedAt: Date()
            )
        }
        
        return Just(())
            .delay(for: .milliseconds(400), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Partner Matching
    
    public func createPartnerRequest(request: PartnerRequestDraft) -> AnyPublisher<String, Error> {
        let requestId = UUID().uuidString
        let partnerRequest = PartnerRequest(
            id: requestId,
            organizerId: "current_user_id",
            activityCategory: request.activityCategory,
            cityId: request.cityId,
            neighborhood: request.neighborhood,
            skillLevel: request.skillLevel,
            message: request.message,
            desiredWindow: DateWindow(from: request.desiredWindow.from, to: request.desiredWindow.to),
            preferredDays: request.preferredDays,
            frequency: request.frequency,
            status: .open,
            interestedUserIds: [],
            matchedGroupId: nil,
            createdAt: Date().addingTimeInterval(-2 * 24 * 60 * 60),
            updatedAt: Date().addingTimeInterval(-2 * 24 * 60 * 60)
        )
        
        mockPartnerRequests.append(partnerRequest)
        
        return Just(requestId)
            .delay(for: .milliseconds(700), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func getPartnerRequests(cityId: String, category: ActivityCategory?, neighborhood: String?) -> AnyPublisher<[PartnerRequest], Error> {
        var filtered = mockPartnerRequests.filter { $0.cityId == cityId && $0.status == .open }
        
        if let category = category {
            filtered = filtered.filter { $0.activityCategory == category }
        }
        
        if let neighborhood = neighborhood {
            filtered = filtered.filter { $0.neighborhood == neighborhood }
        }
        
        return Just(filtered)
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func expressInterest(requestId: String) -> AnyPublisher<Void, Error> {
        return Just(())
            .delay(for: .milliseconds(400), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func matchPartners(requestId: String) -> AnyPublisher<[PartnerCandidate], Error> {
        let mockCandidates = [
            PartnerCandidate(
                userId: "candidate_1",
                userName: "Alex M.",
                matchScore: 0.89,
                reasonCodes: ["same_skill_level", "nearby_location", "common_interests"],
                mutualFriends: 2,
                skillLevel: "intermediate"
            ),
            PartnerCandidate(
                userId: "candidate_2", 
                userName: "Sarah K.",
                matchScore: 0.76,
                reasonCodes: ["compatible_schedule", "similar_experience"],
                mutualFriends: 1,
                skillLevel: "beginner"
            )
        ]
        
        return Just(mockCandidates)
            .delay(for: .milliseconds(800), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func acceptPartner(requestId: String, partnerUserId: String, groupName: String?) -> AnyPublisher<String, Error> {
        let groupId = UUID().uuidString
        return Just(groupId)
            .delay(for: .milliseconds(600), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func closePartnerRequest(requestId: String) -> AnyPublisher<Void, Error> {
        if let index = mockPartnerRequests.firstIndex(where: { $0.id == requestId }) {
            let p = mockPartnerRequests[index]
            mockPartnerRequests[index] = PartnerRequest(
                id: p.id,
                organizerId: p.organizerId,
                activityCategory: p.activityCategory,
                cityId: p.cityId,
                neighborhood: p.neighborhood,
                skillLevel: p.skillLevel,
                message: p.message,
                desiredWindow: p.desiredWindow,
                preferredDays: p.preferredDays,
                frequency: p.frequency,
                status: .closed,
                interestedUserIds: p.interestedUserIds,
                matchedGroupId: p.matchedGroupId,
                createdAt: p.createdAt,
                updatedAt: Date()
            )
        }
        
        return Just(())
            .delay(for: .milliseconds(400), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - AI Features
    
    public func getActivityPerspectives(activityId: String) -> AnyPublisher<ActivityPerspectives, Error> {
        let perspectives = ActivityPerspectives(
            beginnerTips: [
                "Start with basic techniques to build foundation",
                "Don't rush - focus on proper form first",
                "Ask questions - instructors love helping newcomers"
            ],
            expertInsights: [
                "This activity develops both physical and mental discipline",
                "Advanced practitioners focus on breathing techniques",
                "Consider the historical significance of traditional methods"
            ],
            safetyNotes: [
                "Always warm up properly before starting",
                "Listen to your body and take breaks when needed", 
                "Proper equipment is essential for injury prevention"
            ],
            culturalContext: "This activity has deep roots in Moroccan tradition and is practiced throughout the region."
        )
        
        return Just(perspectives)
            .delay(for: .milliseconds(600), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func generateGroupSuggestions(groupId: String) -> AnyPublisher<[ActivitySuggestion], Error> {
        let suggestions = [
            ActivitySuggestion(
                activityId: "activity_1",
                title: "Moroccan Cooking Workshop",
                reason: "Based on your group's interest in cultural activities",
                matchScore: 0.92
            ),
            ActivitySuggestion(
                activityId: "activity_2", 
                title: "Atlas Mountains Hiking",
                reason: "Perfect for your group's fitness level and outdoor preferences",
                matchScore: 0.85
            )
        ]
        
        return Just(suggestions)
            .delay(for: .milliseconds(700), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

// MARK: - Private Helpers

private extension MockActivitiesService {
    
    func setupMockData() {
        // Setup mock providers
        mockProviders = [
            ActivityProvider(
                id: "provider_1",
                name: "Casa Sports Club", 
                type: .venue,
                contact: ProviderContact(email: "info@casasports.ma", phone: "+212 522 123 456", website: nil),
                geo: ProviderGeo(lat: 33.5731, lng: -7.5898, city: "casablanca", neighborhood: "Maarif", address: "123 Bd Moulay Youssef, Casablanca"),
                amenities: ["parking", "changing_rooms", "equipment_rental"],
                rating: 4.6,
                reviewCount: 127,
                verificationTier: .verified,
                isActive: true
            ),
            ActivityProvider(
                id: "provider_2", 
                name: "Chef Amina's Kitchen",
                type: .individual,
                contact: ProviderContact(email: "amina@cookinglove.ma", phone: "+212 661 234 567", website: nil),
                geo: ProviderGeo(lat: 33.5640, lng: -7.6140, city: "casablanca", neighborhood: "Gauthier", address: "456 Rue des Pins, Casablanca"),
                amenities: ["kitchen", "ingredients_provided", "takeaway"],
                rating: 4.9,
                reviewCount: 89,
                verificationTier: .verified,
                isActive: true
            )
        ]
        
        // Setup mock activities
        mockActivities = [
            Activity(
                id: "activity_1",
                providerId: "provider_1",
                title: "Soccer Training Session",
                category: .sport,
                description: "Professional soccer training for all skill levels. Learn techniques, tactics, and teamwork in a fun environment.",
                images: ["https://example.com/soccer1.jpg", "https://example.com/soccer2.jpg"],
                rules: [
                    "Bring your own water bottle",
                    "Wear appropriate sports attire",
                    "Arrive 10 minutes early for warm-up"
                ],
                minParticipants: 6,
                maxParticipants: 22,
                pricePerUnit: 25.0,
                unit: .person,
                durationMinutes: 90,
                location: ActivityLocation(
                    lat: 33.5731,
                    lng: -7.5898,
                    address: "Casa Sports Club, Bd Moulay Youssef",
                    neighborhood: "Maarif"
                ),
                tags: ["soccer", "football", "team sport", "fitness"],
                ageRestrictions: AgeRestrictions(minAge: 12, maxAge: 50),
                skillLevel: .any,
                equipmentNeeded: ["soccer_cleats", "shin_guards"],
                isActive: true,
                createdAt: Date().addingTimeInterval(-20 * 24 * 60 * 60),
                updatedAt: Date().addingTimeInterval(-1 * 24 * 60 * 60)
            ),
            Activity(
                id: "activity_2",
                providerId: "provider_2", 
                title: "Moroccan Tagine Cooking Class",
                category: .food,
                description: "Learn to cook authentic Moroccan tagine with traditional spices and techniques passed down through generations.",
                images: ["https://example.com/cooking1.jpg"],
                rules: [
                    "Vegetarian options available",
                    "All ingredients and equipment provided",
                    "Recipe cards included to take home"
                ],
                minParticipants: 2,
                maxParticipants: 8,
                pricePerUnit: 65.0,
                unit: .person,
                durationMinutes: 180,
                location: ActivityLocation(
                    lat: 33.5640,
                    lng: -7.6140,
                    address: "Chef Amina's Kitchen, Rue des Pins",
                    neighborhood: "Gauthier"
                ),
                tags: ["cooking", "moroccan cuisine", "tagine", "traditional"],
                ageRestrictions: AgeRestrictions(minAge: 16, maxAge: nil),
                skillLevel: .beginner,
                equipmentNeeded: [],
                isActive: true,
                createdAt: Date().addingTimeInterval(-15 * 24 * 60 * 60),
                updatedAt: Date().addingTimeInterval(-3 * 24 * 60 * 60)
            ),
            Activity(
                id: "activity_3",
                providerId: "provider_1",
                title: "Yoga & Meditation Workshop",
                category: .fitness,
                description: "Combine physical yoga practice with mindfulness meditation for complete wellness. Suitable for all levels.",
                images: ["https://example.com/yoga1.jpg", "https://example.com/yoga2.jpg"],
                rules: [
                    "Bring your own yoga mat",
                    "Comfortable clothing recommended", 
                    "No food 2 hours before session"
                ],
                minParticipants: 4,
                maxParticipants: 15,
                pricePerUnit: 35.0,
                unit: .person,
                durationMinutes: 75,
                location: ActivityLocation(
                    lat: 33.5731,
                    lng: -7.5898,
                    address: "Casa Sports Club, Bd Moulay Youssef",
                    neighborhood: "Maarif"
                ),
                tags: ["yoga", "meditation", "wellness", "mindfulness"],
                ageRestrictions: AgeRestrictions(minAge: 18, maxAge: nil),
                skillLevel: .any,
                equipmentNeeded: ["yoga_mat", "water_bottle"],
                isActive: true,
                createdAt: Date().addingTimeInterval(-10 * 24 * 60 * 60),
                updatedAt: Date().addingTimeInterval(-1 * 24 * 60 * 60)
            )
        ]
        
        // Setup mock groups
        mockGroups = [
            ActivityGroup(
                id: "group_1",
                organizerId: "current_user_id",
                name: "Weekend Warriors",
                cityId: "casablanca",
                status: .planning,
                preferences: GroupPreferences(
                    categories: [.sport, .fitness],
                    skillLevel: "intermediate",
                    timeBands: ["weekend_mornings"],
                    priceRange: BudgetRange(min: 20, max: 80),
                    preferredLocation: nil
                ),
                invitedUserIds: ["user_2", "user_3"],
                participantUserIds: ["current_user_id"],
                createdAt: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                updatedAt: Date().addingTimeInterval(-2 * 24 * 60 * 60)
            ),
            ActivityGroup(
                id: "group_2",
                organizerId: "user_4",
                name: "Cooking Enthusiasts",
                cityId: "casablanca", 
                status: .booking,
                preferences: GroupPreferences(
                    categories: [.food, .culture],
                    skillLevel: "beginner",
                    timeBands: ["evening"],
                    priceRange: BudgetRange(min: 50, max: 100),
                    preferredLocation: nil
                ),
                invitedUserIds: [],
                participantUserIds: ["current_user_id", "user_4", "user_5"],
                createdAt: Date().addingTimeInterval(-5 * 24 * 60 * 60),
                updatedAt: Date().addingTimeInterval(-1 * 24 * 60 * 60)
            )
        ]
        
        // Setup mock bookings
        mockBookings = [
            Booking(
                id: "booking_1",
                groupId: "group_2",
                activityId: "activity_2", 
                sessionId: "session_1",
                organizerId: "user_4",
                participants: [
                    BookingParticipant(
                        userId: "current_user_id",
                        userName: "You",
                        role: .participant,
                        status: .accepted
                    ),
                    BookingParticipant(
                        userId: "user_4",
                        userName: "Sara",
                        role: .organizer,
                        status: .accepted
                    )
                ],
                totalAmount: 130.0,
                currency: "MAD",
                status: .confirmed,
                createdAt: Date().addingTimeInterval(-3 * 24 * 60 * 60),
                updatedAt: Date().addingTimeInterval(-2 * 24 * 60 * 60)
            )
        ]
        
        // Setup mock partner requests
        mockPartnerRequests = [
            PartnerRequest(
                id: "partner_1",
                organizerId: "user_6",
                activityCategory: .sport,
                cityId: "casablanca",
                neighborhood: "Maarif",
                skillLevel: "intermediate",
                message: "Looking for a tennis partner for weekend games!",
                desiredWindow: DateWindow(from: Date(), to: Date().addingTimeInterval(14 * 24 * 60 * 60)),
                preferredDays: ["saturday", "sunday"],
                frequency: .recurring,
                status: .open,
                interestedUserIds: [],
                matchedGroupId: nil,
                createdAt: Date().addingTimeInterval(-2 * 24 * 60 * 60),
                updatedAt: Date().addingTimeInterval(-2 * 24 * 60 * 60)
            )
        ]
    }
    
    func generateMockSessions(for activityId: String, dateRange: DateRange?) -> [ActivitySession] {
        let calendar = Calendar.current
        let startDate = dateRange?.from ?? Date()
        let endDate = dateRange?.to ?? Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
        
        var sessions: [ActivitySession] = []
        var currentDate = startDate
        
        while currentDate <= endDate && sessions.count < 10 {
            if calendar.component(.weekday, from: currentDate) != 1 { // Skip Sundays
                let sessionStart = calendar.date(bySettingHour: Int.random(in: 9...18), minute: 0, second: 0, of: currentDate) ?? currentDate
                let sessionEnd = sessionStart.addingTimeInterval(90 * 60) // 90 minutes
                
                let session = ActivitySession(
                    id: "session_\(UUID().uuidString)",
                    activityId: activityId,
                    startAt: sessionStart,
                    endAt: sessionEnd,
                    capacity: Int.random(in: 8...20),
                    bookedCount: Int.random(in: 0...5),
                    priceOverride: nil,
                    bookingWindow: BookingWindow(
                        opensAt: sessionStart.addingTimeInterval(-7 * 24 * 60 * 60), // 7 days before
                        closesAt: sessionStart.addingTimeInterval(-2 * 60 * 60) // 2 hours before
                    ),
                    status: .open
                )
                sessions.append(session)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return sessions
    }
}

// MARK: - Mock Helper Types

public struct PartnerCandidate {
    public let userId: String
    public let userName: String
    public let matchScore: Double
    public let reasonCodes: [String]
    public let mutualFriends: Int?
    public let skillLevel: String?
    
    public init(userId: String, userName: String, matchScore: Double, reasonCodes: [String], mutualFriends: Int? = nil, skillLevel: String? = nil) {
        self.userId = userId
        self.userName = userName
        self.matchScore = matchScore
        self.reasonCodes = reasonCodes
        self.mutualFriends = mutualFriends
        self.skillLevel = skillLevel
    }
}