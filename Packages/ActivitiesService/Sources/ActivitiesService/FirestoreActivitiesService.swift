import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import StripePaymentSheet
import FirebaseCore

public class FirestoreActivitiesService: ActivitiesServiceProtocol {
    private let db = Firestore.firestore()
    private lazy var functions: Functions = {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        return Functions.functions()
    }()
    private let auth = Auth.auth()
    private var cancellables = Set<AnyCancellable>()
    
    public init() {}
    
    // MARK: - Activity Catalog
    
    public func getActivities(
        cityId: String,
        filters: ActivityFilters?
    ) -> AnyPublisher<[Activity], Error> {
        Future<[Activity], Error> { promise in
            let callable = self.functions.httpsCallable("getActivities")
            let data: [String: Any] = [
                "cityId": cityId,
                "filters": self.encodeFilters(filters)
            ]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let activitiesData = data["activities"] as? [[String: Any]] else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                let activities = activitiesData.compactMap { activityData in
                    try? self.decodeActivity(from: activityData)
                }
                
                promise(.success(activities))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getActivity(id: String) -> AnyPublisher<Activity?, Error> {
        Future<Activity?, Error> { promise in
            let callable = self.functions.httpsCallable("getActivity")
            let data = ["activityId": id]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let activityData = data["activity"] as? [String: Any] else {
                    promise(.success(nil))
                    return
                }
                
                do {
                    let activity = try self.decodeActivity(from: activityData)
                    promise(.success(activity))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getActivitySessions(
        activityId: String,
        dateRange: DateRange?
    ) -> AnyPublisher<[ActivitySession], Error> {
        Future<[ActivitySession], Error> { promise in
            let callable = self.functions.httpsCallable("getActivitySessions")
            var data: [String: Any] = ["activityId": activityId]
            
            if let dateRange = dateRange {
                data["dateRange"] = [
                    "from": dateRange.from.timeIntervalSince1970,
                    "to": dateRange.to.timeIntervalSince1970
                ]
            }
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let sessionsData = data["sessions"] as? [[String: Any]] else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                let sessions = sessionsData.compactMap { sessionData in
                    try? self.decodeSession(from: sessionData)
                }
                
                promise(.success(sessions))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getProviders(cityId: String) -> AnyPublisher<[ActivityProvider], Error> {
        Future<[ActivityProvider], Error> { promise in
            let callable = self.functions.httpsCallable("getProviders")
            let data = ["cityId": cityId]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let providersData = data["providers"] as? [[String: Any]] else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                let providers = providersData.compactMap { providerData in
                    try? self.decodeProvider(from: providerData)
                }
                
                promise(.success(providers))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Search
    
    public func searchActivities(
        query: String,
        cityId: String,
        filters: ActivityFilters?,
        limit: Int
    ) -> AnyPublisher<ActivitySearchResponse, Error> {
        Future<ActivitySearchResponse, Error> { promise in
            let callable = self.functions.httpsCallable("searchActivities")
            let data: [String: Any] = [
                "query": query,
                "cityId": cityId,
                "filters": self.encodeFilters(filters),
                "limit": limit
            ]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let activitiesData = data["activities"] as? [[String: Any]],
                      let total = data["total"] as? Int else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                let activities = activitiesData.compactMap { activityData in
                    try? self.decodeActivity(from: activityData)
                }
                
                let response = ActivitySearchResponse(
                    activities: activities,
                    total: total
                )
                
                promise(.success(response))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getRecommendations(
        cityId: String,
        limit: Int
    ) -> AnyPublisher<[Activity], Error> {
        Future<[Activity], Error> { promise in
            let callable = self.functions.httpsCallable("getRecommendations")
            let data = [
                "cityId": cityId,
                "limit": limit
            ]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let activitiesData = data["activities"] as? [[String: Any]] else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                let activities = activitiesData.compactMap { activityData in
                    try? self.decodeActivity(from: activityData)
                }
                
                promise(.success(activities))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Groups
    
    public func createGroup(request: GroupCreationRequest) -> AnyPublisher<String, Error> {
        Future<String, Error> { promise in
            let callable = self.functions.httpsCallable("createGroup")
            let data: [String: Any] = [
                "name": request.name,
                "cityId": request.cityId,
                "preferences": self.encodeGroupPreferences(request.preferences),
                "invitedUserIds": request.invitedUserIds
            ]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let groupId = data["groupId"] as? String else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                promise(.success(groupId))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getGroup(id: String) -> AnyPublisher<ActivityGroup?, Error> {
        Future<ActivityGroup?, Error> { promise in
            let callable = self.functions.httpsCallable("getGroup")
            let data = ["groupId": id]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let groupData = data["group"] as? [String: Any] else {
                    promise(.success(nil))
                    return
                }
                
                do {
                    let group = try self.decodeGroup(from: groupData)
                    promise(.success(group))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getUserGroups(status: GroupStatus?) -> AnyPublisher<[ActivityGroup], Error> {
        Future<[ActivityGroup], Error> { promise in
            let callable = self.functions.httpsCallable("getUserGroups")
            var data: [String: Any] = [:]
            
            if let status = status {
                data["status"] = status.rawValue
            }
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let groupsData = data["groups"] as? [[String: Any]] else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                let groups = groupsData.compactMap { groupData in
                    try? self.decodeGroup(from: groupData)
                }
                
                promise(.success(groups))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func inviteToGroup(
        groupId: String,
        userIds: [String],
        message: String?
    ) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            let callable = self.functions.httpsCallable("inviteToGroup")
            var data: [String: Any] = [
                "groupId": groupId,
                "userIds": userIds
            ]
            
            if let message = message {
                data["message"] = message
            }
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func respondToInvitation(
        groupId: String,
        response: InvitationResponse
    ) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            let callable = self.functions.httpsCallable("respondToInvitation")
            let data = [
                "groupId": groupId,
                "response": response.rawValue
            ]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func leaveGroup(groupId: String) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            let callable = self.functions.httpsCallable("leaveGroup")
            let data = ["groupId": groupId]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func updateGroupPreferences(
        groupId: String,
        preferences: GroupPreferences
    ) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            let callable = self.functions.httpsCallable("updateGroupPreferences")
            let data = [
                "groupId": groupId,
                "preferences": self.encodeGroupPreferences(preferences)
            ]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Bookings
    
    public func createBooking(request: BookingCreationRequest) -> AnyPublisher<String, Error> {
        Future<String, Error> { promise in
            let callable = self.functions.httpsCallable("createBooking")
            let data: [String: Any] = [
                "groupId": request.groupId,
                "activityId": request.activityId,
                "sessionId": request.sessionId,
                "participants": request.participants.map { participant in
                    [
                        "userId": participant.userId,
                        "userName": participant.userName,
                        "role": participant.role.rawValue,
                        "status": participant.status.rawValue
                    ]
                }
            ]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let bookingId = data["bookingId"] as? String else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                promise(.success(bookingId))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getBooking(id: String) -> AnyPublisher<Booking?, Error> {
        Future<Booking?, Error> { promise in
            let callable = self.functions.httpsCallable("getBooking")
            let data = ["bookingId": id]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let bookingData = data["booking"] as? [String: Any] else {
                    promise(.success(nil))
                    return
                }
                
                do {
                    let booking = try self.decodeBooking(from: bookingData)
                    promise(.success(booking))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getUserBookings(status: BookingStatus?) -> AnyPublisher<[Booking], Error> {
        Future<[Booking], Error> { promise in
            let callable = self.functions.httpsCallable("getUserBookings")
            var data: [String: Any] = [:]
            
            if let status = status {
                data["status"] = status.rawValue
            }
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let bookingsData = data["bookings"] as? [[String: Any]] else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                let bookings = bookingsData.compactMap { bookingData in
                    try? self.decodeBooking(from: bookingData)
                }
                
                promise(.success(bookings))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func cancelBooking(
        bookingId: String,
        reason: String
    ) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            let callable = self.functions.httpsCallable("cancelBooking")
            let data = [
                "bookingId": bookingId,
                "reason": reason
            ]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func confirmBooking(bookingId: String) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            let callable = self.functions.httpsCallable("confirmBooking")
            let data = ["bookingId": bookingId]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Split Payments
    
    public func createSplitIntent(
        bookingId: String,
        shareType: SplitShareType,
        customShares: [CustomShare]?
    ) -> AnyPublisher<String, Error> {
        Future<String, Error> { promise in
            let callable = self.functions.httpsCallable("createSplitIntent")
            var data: [String: Any] = [
                "bookingId": bookingId,
                "shareType": shareType.rawValue
            ]
            
            if let customShares = customShares {
                data["customShares"] = customShares.map { share in
                    [
                        "userId": share.userId,
                        "amount": share.amount
                    ]
                }
            }
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let splitId = data["splitId"] as? String else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                promise(.success(splitId))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getSplitIntent(id: String) -> AnyPublisher<SplitIntent?, Error> {
        Future<SplitIntent?, Error> { promise in
            let callable = self.functions.httpsCallable("getSplitIntent")
            let data = ["splitId": id]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any] else {
                    promise(.success(nil))
                    return
                }
                
                do {
                    let splitIntent = try self.decodeSplitIntent(from: data)
                    promise(.success(splitIntent))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func paySplitShare(
        splitId: String,
        paymentMethodId: String
    ) -> AnyPublisher<PaymentResult, Error> {
        Future<PaymentResult, Error> { promise in
            let callable = self.functions.httpsCallable("paySplitShare")
            let data = [
                "splitId": splitId,
                "paymentMethodId": paymentMethodId
            ]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let success = data["success"] as? Bool,
                      let paymentIntentId = data["paymentIntentId"] as? String,
                      let status = data["status"] as? String else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                let paymentResult = PaymentResult(
                    success: success,
                    paymentIntentId: paymentIntentId,
                    status: status,
                    clientSecret: data["clientSecret"] as? String
                )
                
                promise(.success(paymentResult))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func cancelSplitIntent(splitId: String) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            let callable = self.functions.httpsCallable("cancelSplitIntent")
            let data = ["splitId": splitId]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Partner Matching
    
    public func createPartnerRequest(
        request: PartnerRequestDraft
    ) -> AnyPublisher<String, Error> {
        Future<String, Error> { promise in
            let callable = self.functions.httpsCallable("createPartnerRequest")
            let data: [String: Any] = [
                "activityCategory": request.activityCategory.rawValue,
                "cityId": request.cityId,
                "neighborhood": request.neighborhood ?? NSNull(),
                "skillLevel": request.skillLevel ?? NSNull(),
                "message": request.message,
                "desiredWindow": [
                    "from": request.desiredWindow.from.timeIntervalSince1970 * 1000,
                    "to": request.desiredWindow.to.timeIntervalSince1970 * 1000
                ],
                "preferredDays": request.preferredDays ?? NSNull(),
                "frequency": request.frequency.rawValue
            ]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let requestId = data["requestId"] as? String else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                promise(.success(requestId))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getPartnerRequests(
        cityId: String,
        category: ActivityCategory?,
        neighborhood: String?
    ) -> AnyPublisher<[PartnerRequest], Error> {
        Future<[PartnerRequest], Error> { promise in
            let callable = self.functions.httpsCallable("listPartnerRequests")
            var data: [String: Any] = ["cityId": cityId]
            
            if let category = category {
                data["category"] = category.rawValue
            }
            if let neighborhood = neighborhood {
                data["neighborhood"] = neighborhood
            }
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let requestsData = data["requests"] as? [[String: Any]] else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                let requests = requestsData.compactMap { requestData in
                    try? self.decodePartnerRequest(from: requestData)
                }
                
                promise(.success(requests))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func expressInterest(requestId: String) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            let callable = self.functions.httpsCallable("expressInterest")
            let data = ["requestId": requestId]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func matchPartners(requestId: String) -> AnyPublisher<[PartnerCandidate], Error> {
        Future<[PartnerCandidate], Error> { promise in
            let callable = self.functions.httpsCallable("matchPartners")
            let data = ["requestId": requestId]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let candidatesData = data["candidates"] as? [[String: Any]] else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                let candidates = candidatesData.compactMap { candidateData in
                    try? self.decodePartnerCandidate(from: candidateData)
                }
                
                promise(.success(candidates))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func acceptPartner(
        requestId: String,
        partnerUserId: String,
        groupName: String?
    ) -> AnyPublisher<String, Error> {
        Future<String, Error> { promise in
            let callable = self.functions.httpsCallable("acceptPartner")
            var data: [String: Any] = [
                "requestId": requestId,
                "partnerUserId": partnerUserId
            ]
            
            if let groupName = groupName {
                data["groupName"] = groupName
            }
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let groupId = data["groupId"] as? String else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                promise(.success(groupId))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func closePartnerRequest(requestId: String) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            let callable = self.functions.httpsCallable("closePartnerRequest")
            let data = ["requestId": requestId]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - AI Features
    
    public func getActivityPerspectives(activityId: String) -> AnyPublisher<ActivityPerspectives, Error> {
        Future<ActivityPerspectives, Error> { promise in
            let callable = self.functions.httpsCallable("getActivityPerspectives")
            let data = ["activityId": activityId]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let beginnerTips = data["beginnerTips"] as? [String],
                      let expertInsights = data["expertInsights"] as? [String],
                      let safetyNotes = data["safetyNotes"] as? [String] else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                let perspectives = ActivityPerspectives(
                    beginnerTips: beginnerTips,
                    expertInsights: expertInsights,
                    safetyNotes: safetyNotes,
                    culturalContext: data["culturalContext"] as? String
                )
                
                promise(.success(perspectives))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func generateGroupSuggestions(
        groupId: String
    ) -> AnyPublisher<[ActivitySuggestion], Error> {
        Future<[ActivitySuggestion], Error> { promise in
            let callable = self.functions.httpsCallable("generateGroupSuggestions")
            let data = ["groupId": groupId]
            
            callable.call(data) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let suggestionsData = data["suggestions"] as? [[String: Any]] else {
                    promise(.failure(ActivitiesServiceError.invalidResponse))
                    return
                }
                
                let suggestions = suggestionsData.compactMap { suggestionData in
                    try? self.decodeActivitySuggestion(from: suggestionData)
                }
                
                promise(.success(suggestions))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Helper Extensions
private extension FirestoreActivitiesService {
    
    // MARK: - Encoding Helpers
    
    func encodeFilters(_ filters: ActivityFilters?) -> [String: Any] {
        guard let filters = filters else { return [:] }
        
        var encoded: [String: Any] = [:]
        
        if let categories = filters.categories {
            encoded["categories"] = categories.map { $0.rawValue }
        }
        
        if let priceRange = filters.priceRange {
            encoded["priceRange"] = [
                "min": priceRange.min,
                "max": priceRange.max
            ]
        }
        
        if let skillLevels = filters.skillLevels {
            encoded["skillLevels"] = skillLevels.map { $0.rawValue }
        }
        
        if let dateRange = filters.dateRange {
            encoded["dateRange"] = [
                "from": dateRange.from.timeIntervalSince1970,
                "to": dateRange.to.timeIntervalSince1970
            ]
        }
        
        if let location = filters.location {
            encoded["location"] = [
                "centerLatitude": location.centerLatitude,
                "centerLongitude": location.centerLongitude,
                "radiusKm": location.radiusKm
            ]
        }
        
        return encoded
    }
    
    func encodeGroupPreferences(_ preferences: GroupPreferences) -> [String: Any] {
        var encoded: [String: Any] = [:]
        
        if let categories = preferences.categories, !categories.isEmpty {
            encoded["categories"] = categories.map { $0.rawValue }
        }
        
        if let skillLevel = preferences.skillLevel {
            encoded["skillLevel"] = skillLevel
        }
        
        if let timeBands = preferences.timeBands, !timeBands.isEmpty {
            encoded["timeBands"] = timeBands
        }
        
        if let priceRange = preferences.priceRange {
            encoded["priceRange"] = [
                "min": priceRange.min,
                "max": priceRange.max
            ]
        }
        
        if let location = preferences.preferredLocation {
            encoded["preferredLocation"] = [
                "centerLatitude": location.centerLatitude,
                "centerLongitude": location.centerLongitude,
                "radiusKm": location.radiusKm
            ]
        }
        
        return encoded
    }
    
    // MARK: - Decoding Helpers
    
    func decodeActivity(from data: [String: Any]) throws -> Activity {
        guard let id = data["id"] as? String,
              let providerId = data["providerId"] as? String,
              let title = data["title"] as? String,
              let categoryRaw = data["category"] as? String,
              let category = ActivityCategory(rawValue: categoryRaw),
              let description = data["description"] as? String,
              let location = data["location"] as? [String: Any] else {
            throw ActivitiesServiceError.invalidResponse
        }
        let loc = try decodeLocation(from: location)
        let images = data["images"] as? [String] ?? []
        let rules = data["rules"] as? [String] ?? []
        let minParticipants = data["minParticipants"] as? Int ?? (data["min"] as? Int ?? 1)
        let maxParticipants = data["maxParticipants"] as? Int ?? (data["max"] as? Int ?? 10)
        let pricePerUnit = data["pricePerUnit"] as? Double ?? (data["price"] as? Double ?? 0)
        let unit = PriceUnit(rawValue: (data["unit"] as? String ?? "person")) ?? .person
        let durationMinutes = data["durationMinutes"] as? Int ?? Int((data["duration"] as? TimeInterval ?? 0) / 60)
        let tags = data["tags"] as? [String] ?? []
        let ageRestrictions: AgeRestrictions? = {
            let minAge = data["minAge"] as? Int
            let maxAge = data["maxAge"] as? Int
            if minAge == nil && maxAge == nil { return nil }
            return AgeRestrictions(minAge: minAge, maxAge: maxAge)
        }()
        let skillLevel = (data["skillLevel"] as? String).flatMap { SkillLevel(rawValue: $0) }
        let equipmentNeeded = data["equipmentNeeded"] as? [String] ?? (data["equipment"] as? [String] ?? [])
        let isActive = data["isActive"] as? Bool ?? true
        let createdAt = decodeDate(from: data["createdAt"]) ?? Date()
        let updatedAt = decodeDate(from: data["updatedAt"]) ?? Date()
        return Activity(
            id: id,
            providerId: providerId,
            title: title,
            category: category,
            description: description,
            images: images,
            rules: rules,
            minParticipants: minParticipants,
            maxParticipants: maxParticipants,
            pricePerUnit: pricePerUnit,
            unit: unit,
            durationMinutes: durationMinutes,
            location: loc,
            tags: tags,
            ageRestrictions: ageRestrictions,
            skillLevel: skillLevel,
            equipmentNeeded: equipmentNeeded,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    func decodeProvider(from data: [String: Any]) throws -> ActivityProvider {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let typeRaw = data["type"] as? String,
              let type = ProviderType(rawValue: typeRaw) else {
            throw ActivitiesServiceError.invalidResponse
        }
        
        return ActivityProvider(
            id: id,
            name: name,
            type: type,
            contact: ProviderContact(
                email: (data["contactInfo"] as? [String: Any])?["email"] as? String,
                phone: (data["contactInfo"] as? [String: Any])?["phone"] as? String,
                website: (data["contactInfo"] as? [String: Any])?["website"] as? String
            ),
            geo: ProviderGeo(
                lat: (data["location"] as? [String: Any])?["lat"] as? Double ?? 0,
                lng: (data["location"] as? [String: Any])?["lng"] as? Double ?? 0,
                city: (data["location"] as? [String: Any])?["city"] as? String ?? "",
                neighborhood: (data["location"] as? [String: Any])?["neighborhood"] as? String,
                address: (data["location"] as? [String: Any])?["address"] as? String ?? ""
            ),
            amenities: data["amenities"] as? [String] ?? [],
            rating: data["rating"] as? Double,
            reviewCount: data["reviewCount"] as? Int,
            verificationTier: VerificationTier(rawValue: (data["verificationTier"] as? String ?? "unverified")) ?? .unverified,
            isActive: data["isActive"] as? Bool ?? true
        )
    }
    
    func decodeSession(from data: [String: Any]) throws -> ActivitySession {
        guard let id = data["id"] as? String,
              let activityId = data["activityId"] as? String,
              let startAt = decodeDate(from: data["startTime"]),
              let endAt = decodeDate(from: data["endTime"]) else {
            throw ActivitiesServiceError.invalidResponse
        }
        let capacity = data["maxParticipants"] as? Int ?? 0
        let booked = data["currentParticipants"] as? Int ?? 0
        let status = SessionStatus(rawValue: (data["status"] as? String ?? "open")) ?? .open
        let bookingWindow = BookingWindow(
            opensAt: decodeDate(from: data["bookingOpensAt"]) ?? startAt,
            closesAt: decodeDate(from: data["bookingClosesAt"]) ?? endAt
        )
        return ActivitySession(
            id: id,
            activityId: activityId,
            startAt: startAt,
            endAt: endAt,
            capacity: capacity,
            bookedCount: booked,
            priceOverride: data["pricePerPerson"] as? Double,
            bookingWindow: bookingWindow,
            status: status
        )
    }
    
    func decodeGroup(from data: [String: Any]) throws -> ActivityGroup {
        guard let id = data["id"] as? String,
              let organizerId = data["organizerId"] as? String,
              let name = data["name"] as? String,
              let cityId = data["cityId"] as? String,
              let statusRaw = data["status"] as? String,
              let status = GroupStatus(rawValue: statusRaw) else {
            throw ActivitiesServiceError.invalidResponse
        }
        
        let preferences = decodeGroupPreferences(from: data["preferences"] as? [String: Any])
        
        return ActivityGroup(
            id: id,
            organizerId: organizerId,
            name: name,
            activityId: data["activityId"] as? String,
            sessionId: data["sessionId"] as? String,
            cityId: cityId,
            status: status,
            preferences: preferences,
            invitedUserIds: data["invitedUserIds"] as? [String] ?? [],
            participantUserIds: data["participantUserIds"] as? [String] ?? [],
            partnerRequestId: data["partnerRequestId"] as? String,
            chatThreadId: data["chatThreadId"] as? String,
            createdAt: decodeDate(from: data["createdAt"]) ?? Date(),
            updatedAt: decodeDate(from: data["updatedAt"]) ?? Date()
        )
    }
    
    func decodeBooking(from data: [String: Any]) throws -> Booking {
        guard let id = data["id"] as? String,
              let groupId = data["groupId"] as? String,
              let activityId = data["activityId"] as? String,
              let sessionId = data["sessionId"] as? String,
              let organizerId = data["organizerId"] as? String,
              let statusRaw = data["status"] as? String,
              let status = BookingStatus(rawValue: statusRaw),
              let totalAmount = data["totalAmount"] as? Double else {
            throw ActivitiesServiceError.invalidResponse
        }
        
        let participantsData = data["participants"] as? [[String: Any]] ?? []
        let participants = participantsData.compactMap { participantData in
            try? decodeBookingParticipant(from: participantData)
        }
        
        return Booking(
            id: id,
            groupId: groupId,
            activityId: activityId,
            sessionId: sessionId,
            organizerId: organizerId,
            participants: participants,
            totalAmount: totalAmount,
            currency: (data["currency"] as? String) ?? "USD",
            status: status,
            paymentIntentId: data["paymentIntentId"] as? String,
            settlement: nil,
            cancellation: nil,
            createdAt: decodeDate(from: data["createdAt"]) ?? Date(),
            updatedAt: decodeDate(from: data["updatedAt"]) ?? Date()
        )
    }
    
    func decodeSplitIntent(from data: [String: Any]) throws -> SplitIntent {
        guard let id = data["id"] as? String,
              let bookingId = data["bookingId"] as? String,
              let shareTypeRaw = data["shareType"] as? String,
              let shareType = SplitShareType(rawValue: shareTypeRaw),
              let statusRaw = data["status"] as? String,
              let status = SplitStatus(rawValue: statusRaw),
              let expiresAt = decodeDate(from: data["expiresAt"]) else {
            throw ActivitiesServiceError.invalidResponse
        }
        
        let sharesData = data["shares"] as? [[String: Any]] ?? []
        let shares = sharesData.compactMap { shareData in
            try? decodeSplitShare(from: shareData)
        }
        
        return SplitIntent(
            id: id,
            bookingId: bookingId,
            shareType: shareType,
            shares: shares,
            status: status,
            expiresAt: expiresAt,
            createdAt: decodeDate(from: data["createdAt"]) ?? Date(),
            updatedAt: decodeDate(from: data["updatedAt"]) ?? Date()
        )
    }
    
    func decodePartnerRequest(from data: [String: Any]) throws -> PartnerRequest {
        guard let id = data["id"] as? String,
              let organizerId = data["organizerId"] as? String,
              let activityCategoryRaw = data["activityCategory"] as? String,
              let activityCategory = ActivityCategory(rawValue: activityCategoryRaw),
              let cityId = data["cityId"] as? String,
              let message = data["message"] as? String,
              let statusRaw = data["status"] as? String,
              let status = PartnerRequestStatus(rawValue: statusRaw) else {
            throw ActivitiesServiceError.invalidResponse
        }
        
        let desiredWindow = try decodeTimeWindow(from: data["desiredWindow"] as? [String: Any])
         
         return PartnerRequest(
             id: id,
             organizerId: organizerId,
             activityCategory: activityCategory,
             cityId: cityId,
             neighborhood: data["neighborhood"] as? String,
             skillLevel: decodeSkillLevel(from: data["skillLevel"] as? String)?.rawValue,
             message: message,
             desiredWindow: desiredWindow,
             preferredDays: decodeWeekdays(from: data["preferredDays"] as? [String]),
             frequency: (decodeFrequency(from: data["frequency"] as? String) ?? .oneOff),
             status: status,
             interestedUserIds: data["interestedUserIds"] as? [String] ?? [],
             matchedGroupId: data["matchedGroupId"] as? String,
             createdAt: decodeDate(from: data["createdAt"]) ?? Date(),
             updatedAt: decodeDate(from: data["updatedAt"]) ?? Date()
         )
    }
    
    func decodePartnerCandidate(from data: [String: Any]) throws -> PartnerCandidate {
        guard let userId = data["userId"] as? String,
              let userName = data["userName"] as? String,
              let matchScore = data["matchScore"] as? Double,
              let reasonCodes = data["reasonCodes"] as? [String] else {
            throw ActivitiesServiceError.invalidResponse
        }
        
        return PartnerCandidate(
            userId: userId,
            userName: userName,
            matchScore: matchScore,
            reasonCodes: reasonCodes
        )
    }
    
    func decodeActivitySuggestion(from data: [String: Any]) throws -> ActivitySuggestion {
        guard let activityId = data["activityId"] as? String,
              let title = data["title"] as? String,
              let reason = data["reason"] as? String,
              let matchScore = data["matchScore"] as? Double else {
            throw ActivitiesServiceError.invalidResponse
        }
        
        return ActivitySuggestion(
            activityId: activityId,
            title: title,
            reason: reason,
            matchScore: matchScore
        )
    }
    
    // MARK: - Additional Decoding Helpers
    
    func decodeLocation(from data: [String: Any]) throws -> ActivityLocation {
        guard let lat = data["latitude"] as? Double,
              let lng = data["longitude"] as? Double,
              let address = data["address"] as? String else {
            throw ActivitiesServiceError.invalidResponse
        }
        return ActivityLocation(lat: lat, lng: lng, address: address, neighborhood: data["neighborhood"] as? String)
    }
    
    func decodePriceRange(from data: [String: Any]?) -> PriceRange? {
        guard let data = data,
              let min = data["min"] as? Double,
              let max = data["max"] as? Double else {
            return nil
        }
        return PriceRange(min: min, max: max)
    }
    
    func decodeSkillLevels(from data: [String]?) -> [SkillLevel] {
        return data?.compactMap { SkillLevel(rawValue: $0) } ?? []
    }
    
    func decodeWeatherDependency(from raw: String?) -> WeatherDependency? {
        guard let raw = raw else { return nil }
        return WeatherDependency(rawValue: raw)
    }
    
    func decodeContactInfo(from data: [String: Any]?) -> ContactInfo? {
        guard let data = data else { return nil }
        
        return ContactInfo(
            phone: data["phone"] as? String,
            email: data["email"] as? String,
            website: data["website"] as? String,
            socialMedia: data["socialMedia"] as? [String: String] ?? [:]
        )
    }
    
    func decodeSpecialties(from data: [String]?) -> [ActivityCategory] {
        return data?.compactMap { ActivityCategory(rawValue: $0) } ?? []
    }
    
    func decodeGroupPreferences(from data: [String: Any]?) -> GroupPreferences {
        guard let data = data else {
            return GroupPreferences(categories: nil, skillLevel: nil, timeBands: nil, priceRange: nil, preferredLocation: nil)
        }
        let categories = (data["categories"] as? [String])?.compactMap { ActivityCategory(rawValue: $0) }
        let skillLevel = decodeSkillLevel(from: data["skillLevel"] as? String)?.rawValue
        let timeBands = data["timeBands"] as? [String]
        let priceRange: BudgetRange? = {
            guard let pr = decodePriceRange(from: data["priceRange"] as? [String: Any]) else { return nil }
            return BudgetRange(min: pr.min, max: pr.max)
        }()
        let preferredLocation: LocationFilter? = {
            guard let loc = data["preferredLocation"] as? [String: Any],
                  let lat = loc["centerLatitude"] as? Double,
                  let lng = loc["centerLongitude"] as? Double,
                  let r = loc["radiusKm"] as? Double else { return nil }
            return LocationFilter(centerLatitude: lat, centerLongitude: lng, radiusKm: r)
        }()
        return GroupPreferences(
            categories: categories,
            skillLevel: skillLevel,
            timeBands: timeBands,
            priceRange: priceRange,
            preferredLocation: preferredLocation
        )
    }
    
    func decodeBookingParticipant(from data: [String: Any]) throws -> BookingParticipant {
        guard let userId = data["userId"] as? String,
              let userName = data["userName"] as? String else {
            throw ActivitiesServiceError.invalidResponse
        }
        return BookingParticipant(
            userId: userId,
            userName: userName,
            role: .participant,
            status: .invited
        )
    }
    
    func decodeSplitShare(from data: [String: Any]) throws -> SplitShare {
        guard let userId = data["userId"] as? String,
              let userName = data["userName"] as? String,
              let amount = data["amount"] as? Double,
              let statusRaw = data["status"] as? String,
              let status = SplitShareStatus(rawValue: statusRaw) else {
            throw ActivitiesServiceError.invalidResponse
        }
        
        return SplitShare(
            userId: userId,
            userName: userName,
            amount: amount,
            status: status,
            paymentIntentId: data["paymentIntentId"] as? String,
            paidAt: decodeDate(from: data["paidAt"])
        )
    }
    
    func decodeTimeWindow(from data: [String: Any]?) throws -> DateWindow {
        guard let data = data,
              let from = decodeDate(from: data["from"]),
              let to = decodeDate(from: data["to"]) else {
            throw ActivitiesServiceError.invalidResponse
        }
        return DateWindow(from: from, to: to)
    }
    
    func decodeSkillLevel(from raw: String?) -> SkillLevel? {
        guard let raw = raw else { return nil }
        return SkillLevel(rawValue: raw)
    }
    
    func decodeWeekdays(from data: [String]?) -> [String]? { return data }
    
    func decodeFrequency(from raw: String?) -> Frequency? { return Frequency(rawValue: raw ?? "") }
    
    func decodeDate(from value: Any?) -> Date? {
        if let timestamp = value as? Double {
            return Date(timeIntervalSince1970: timestamp / 1000) // Convert from milliseconds
        } else if let seconds = value as? TimeInterval {
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }
}