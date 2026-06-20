import Foundation

// MARK: - Core Models

public struct Activity: Identifiable, Codable {
    public let id: String
    public let providerId: String
    public let title: String
    public let category: ActivityCategory
    public let description: String
    public let images: [String]
    public let rules: [String]
    public let minParticipants: Int
    public let maxParticipants: Int
    public let pricePerUnit: Double
    public let unit: PriceUnit
    public let durationMinutes: Int
    public let location: ActivityLocation
    public let tags: [String]
    public let ageRestrictions: AgeRestrictions?
    public let skillLevel: SkillLevel?
    public let equipmentNeeded: [String]
    public let isActive: Bool
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(id: String, providerId: String, title: String, category: ActivityCategory, 
                description: String, images: [String], rules: [String], minParticipants: Int, 
                maxParticipants: Int, pricePerUnit: Double, unit: PriceUnit, 
                durationMinutes: Int, location: ActivityLocation, tags: [String], 
                ageRestrictions: AgeRestrictions? = nil, skillLevel: SkillLevel? = nil, 
                equipmentNeeded: [String], isActive: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.providerId = providerId
        self.title = title
        self.category = category
        self.description = description
        self.images = images
        self.rules = rules
        self.minParticipants = minParticipants
        self.maxParticipants = maxParticipants
        self.pricePerUnit = pricePerUnit
        self.unit = unit
        self.durationMinutes = durationMinutes
        self.location = location
        self.tags = tags
        self.ageRestrictions = ageRestrictions
        self.skillLevel = skillLevel
        self.equipmentNeeded = equipmentNeeded
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ActivityCategory: String, CaseIterable, Codable {
    case sport = "sport"
    case game = "game"
    case workshop = "workshop"
    case culture = "culture"
    case outdoor = "outdoor"
    case fitness = "fitness"
    case food = "food"
    case education = "education"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .sport: return "Sport"
        case .game: return "Games"
        case .workshop: return "Workshop"
        case .culture: return "Culture"
        case .outdoor: return "Outdoor"
        case .fitness: return "Fitness"
        case .food: return "Food & Dining"
        case .education: return "Education"
        case .other: return "Other"
        }
    }
    
    public var icon: String {
        switch self {
        case .sport: return "figure.run"
        case .game: return "gamecontroller"
        case .workshop: return "hammer"
        case .culture: return "theatermasks"
        case .outdoor: return "leaf"
        case .fitness: return "dumbbell"
        case .food: return "fork.knife"
        case .education: return "book"
        case .other: return "star"
        }
    }
}

public enum PriceUnit: String, Codable {
    case person = "person"
    case team = "team"
    case slot = "slot"
    case hour = "hour"
    
    public var displayName: String {
        switch self {
        case .person: return "per person"
        case .team: return "per team"
        case .slot: return "per slot"
        case .hour: return "per hour"
        }
    }
}

public enum SkillLevel: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case any = "any"
    
    public var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .any: return "Any Level"
        }
    }
}

public struct ActivityLocation: Codable {
    public let lat: Double
    public let lng: Double
    public let address: String
    public let neighborhood: String?
    
    public init(lat: Double, lng: Double, address: String, neighborhood: String? = nil) {
        self.lat = lat
        self.lng = lng
        self.address = address
        self.neighborhood = neighborhood
    }
}

public struct AgeRestrictions: Codable {
    public let minAge: Int?
    public let maxAge: Int?
    
    public init(minAge: Int? = nil, maxAge: Int? = nil) {
        self.minAge = minAge
        self.maxAge = maxAge
    }
}

// MARK: - Provider Models

public struct ActivityProvider: Identifiable, Codable {
    public let id: String
    public let name: String
    public let type: ProviderType
    public let contact: ProviderContact
    public let geo: ProviderGeo
    public let amenities: [String]
    public let rating: Double?
    public let reviewCount: Int?
    public let verificationTier: VerificationTier
    public let isActive: Bool
    
    public init(id: String, name: String, type: ProviderType, contact: ProviderContact, 
                geo: ProviderGeo, amenities: [String], rating: Double? = nil, 
                reviewCount: Int? = nil, verificationTier: VerificationTier, isActive: Bool) {
        self.id = id
        self.name = name
        self.type = type
        self.contact = contact
        self.geo = geo
        self.amenities = amenities
        self.rating = rating
        self.reviewCount = reviewCount
        self.verificationTier = verificationTier
        self.isActive = isActive
    }
}

public enum ProviderType: String, Codable {
    case venue = "venue"
    case company = "company"
    case individual = "individual"
}

public enum VerificationTier: String, Codable {
    case unverified = "unverified"
    case basic = "basic"
    case verified = "verified"
    case premium = "premium"
}

public struct ProviderContact: Codable {
    public let email: String?
    public let phone: String?
    public let website: String?
    
    public init(email: String? = nil, phone: String? = nil, website: String? = nil) {
        self.email = email
        self.phone = phone
        self.website = website
    }
}

public struct ProviderGeo: Codable {
    public let lat: Double
    public let lng: Double
    public let city: String
    public let neighborhood: String?
    public let address: String
    
    public init(lat: Double, lng: Double, city: String, neighborhood: String? = nil, address: String) {
        self.lat = lat
        self.lng = lng
        self.city = city
        self.neighborhood = neighborhood
        self.address = address
    }
}

// MARK: - Session Models

public struct ActivitySession: Identifiable, Codable {
    public let id: String
    public let activityId: String
    public let startAt: Date
    public let endAt: Date
    public let capacity: Int
    public let bookedCount: Int
    public let priceOverride: Double?
    public let bookingWindow: BookingWindow
    public let status: SessionStatus
    
    public init(id: String, activityId: String, startAt: Date, endAt: Date, capacity: Int, 
                bookedCount: Int, priceOverride: Double? = nil, bookingWindow: BookingWindow, 
                status: SessionStatus) {
        self.id = id
        self.activityId = activityId
        self.startAt = startAt
        self.endAt = endAt
        self.capacity = capacity
        self.bookedCount = bookedCount
        self.priceOverride = priceOverride
        self.bookingWindow = bookingWindow
        self.status = status
    }
}

public struct BookingWindow: Codable {
    public let opensAt: Date
    public let closesAt: Date
    
    public init(opensAt: Date, closesAt: Date) {
        self.opensAt = opensAt
        self.closesAt = closesAt
    }
}

public enum SessionStatus: String, Codable {
    case open = "open"
    case limited = "limited"
    case full = "full"
    case closed = "closed"
    case cancelled = "cancelled"
    
    public var displayName: String {
        switch self {
        case .open: return "Available"
        case .limited: return "Limited Spots"
        case .full: return "Full"
        case .closed: return "Closed"
        case .cancelled: return "Cancelled"
        }
    }
    
    public var isAvailable: Bool {
        return self == .open || self == .limited
    }
}

// MARK: - Group Models

public struct ActivityGroup: Identifiable, Codable {
    public let id: String
    public let organizerId: String
    public let name: String
    public let activityId: String?
    public let sessionId: String?
    public let cityId: String
    public let status: GroupStatus
    public let preferences: GroupPreferences
    public let invitedUserIds: [String]
    public var participantUserIds: [String]
    public let partnerRequestId: String?
    public let chatThreadId: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(id: String, organizerId: String, name: String, activityId: String? = nil, 
                sessionId: String? = nil, cityId: String, status: GroupStatus, 
                preferences: GroupPreferences, invitedUserIds: [String], 
                participantUserIds: [String], partnerRequestId: String? = nil, 
                chatThreadId: String? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.organizerId = organizerId
        self.name = name
        self.activityId = activityId
        self.sessionId = sessionId
        self.cityId = cityId
        self.status = status
        self.preferences = preferences
        self.invitedUserIds = invitedUserIds
        self.participantUserIds = participantUserIds
        self.partnerRequestId = partnerRequestId
        self.chatThreadId = chatThreadId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum GroupStatus: String, CaseIterable, Codable {
    case planning = "planning"
    case booking = "booking"
    case confirmed = "confirmed"
    case completed = "completed"
    case cancelled = "cancelled"
    
    public var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .booking: return "Booking"
        case .confirmed: return "Confirmed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    public var icon: String {
        switch self {
        case .planning: return "lightbulb"
        case .booking: return "calendar.badge.clock"
        case .confirmed: return "checkmark.circle"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
}

public struct GroupPreferences: Codable {
    public let categories: [ActivityCategory]?
    public let skillLevel: String?
    public let timeBands: [String]?
    public let priceRange: BudgetRange?
    public let preferredLocation: LocationFilter?
    
    public init(categories: [ActivityCategory]? = nil,
                skillLevel: String? = nil,
                timeBands: [String]? = nil,
                priceRange: BudgetRange? = nil,
                preferredLocation: LocationFilter? = nil) {
        self.categories = categories
        self.skillLevel = skillLevel
        self.timeBands = timeBands
        self.priceRange = priceRange
        self.preferredLocation = preferredLocation
    }
}

public struct BudgetRange: Codable {
    public let min: Double
    public let max: Double
    
    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }
}

// MARK: - Partner Request Models

public struct PartnerRequest: Identifiable, Codable {
    public let id: String
    public let organizerId: String
    public let activityCategory: ActivityCategory
    public let cityId: String
    public let neighborhood: String?
    public let skillLevel: String?
    public let message: String
    public let desiredWindow: DateWindow
    public let preferredDays: [String]?
    public let frequency: Frequency
    public let status: PartnerRequestStatus
    public let interestedUserIds: [String]
    public let matchedGroupId: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(id: String, organizerId: String, activityCategory: ActivityCategory, 
                cityId: String, neighborhood: String? = nil, skillLevel: String? = nil, 
                message: String, desiredWindow: DateWindow, preferredDays: [String]? = nil, 
                frequency: Frequency, status: PartnerRequestStatus, 
                interestedUserIds: [String], matchedGroupId: String? = nil, 
                createdAt: Date, updatedAt: Date) {
        self.id = id
        self.organizerId = organizerId
        self.activityCategory = activityCategory
        self.cityId = cityId
        self.neighborhood = neighborhood
        self.skillLevel = skillLevel
        self.message = message
        self.desiredWindow = desiredWindow
        self.preferredDays = preferredDays
        self.frequency = frequency
        self.status = status
        self.interestedUserIds = interestedUserIds
        self.matchedGroupId = matchedGroupId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct DateWindow: Codable {
    public let from: Date
    public let to: Date
    
    public init(from: Date, to: Date) {
        self.from = from
        self.to = to
    }
}

public enum Frequency: String, CaseIterable, Codable {
    case oneOff = "one_off"
    case recurring = "recurring"
    
    public var displayName: String {
        switch self {
        case .oneOff: return "One-time"
        case .recurring: return "Recurring"
        }
    }
}

public enum PartnerRequestStatus: String, Codable {
    case open = "open"
    case matched = "matched"
    case closed = "closed"
    
    public var displayName: String {
        switch self {
        case .open: return "Looking for Partners"
        case .matched: return "Matched"
        case .closed: return "Closed"
        }
    }
}

// MARK: - Booking Models

public struct Booking: Identifiable, Codable {
    public let id: String
    public let groupId: String
    public let activityId: String
    public let sessionId: String
    public let organizerId: String
    public let participants: [BookingParticipant]
    public let totalAmount: Double
    public let currency: String
    public let status: BookingStatus
    public let paymentIntentId: String?
    public let settlement: BookingSettlement?
    public let cancellation: BookingCancellation?
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(id: String, groupId: String, activityId: String, sessionId: String, 
                organizerId: String, participants: [BookingParticipant], 
                totalAmount: Double, currency: String, status: BookingStatus, 
                paymentIntentId: String? = nil, settlement: BookingSettlement? = nil, 
                cancellation: BookingCancellation? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.groupId = groupId
        self.activityId = activityId
        self.sessionId = sessionId
        self.organizerId = organizerId
        self.participants = participants
        self.totalAmount = totalAmount
        self.currency = currency
        self.status = status
        self.paymentIntentId = paymentIntentId
        self.settlement = settlement
        self.cancellation = cancellation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum BookingStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case awaitingSplit = "awaiting_split"
    case confirmed = "confirmed"
    case cancelled = "cancelled"
    case completed = "completed"
    case refunded = "refunded"
    
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .awaitingSplit: return "Awaiting Payment"
        case .confirmed: return "Confirmed"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        case .refunded: return "Refunded"
        }
    }
}

public struct BookingParticipant: Codable {
    public let userId: String
    public let userName: String
    public let role: ParticipantRole
    public let status: ParticipantStatus
    
    public init(userId: String, userName: String, role: ParticipantRole, status: ParticipantStatus) {
        self.userId = userId
        self.userName = userName
        self.role = role
        self.status = status
    }
}

public enum ParticipantRole: String, Codable {
    case organizer = "organizer"
    case participant = "participant"
}

public enum ParticipantStatus: String, Codable {
    case invited = "invited"
    case accepted = "accepted"
    case declined = "declined"
    case paid = "paid"
}

public struct BookingSettlement: Codable {
    public let splits: [SplitShare]
    public let fees: [PaymentFee]
    public let collectedAt: Date?
    
    public init(splits: [SplitShare], fees: [PaymentFee], collectedAt: Date? = nil) {
        self.splits = splits
        self.fees = fees
        self.collectedAt = collectedAt
    }
}

public struct BookingCancellation: Codable {
    public let reason: String
    public let cancelledBy: String
    public let cancelledAt: Date
    public let refundAmount: Double?
    
    public init(reason: String, cancelledBy: String, cancelledAt: Date, refundAmount: Double? = nil) {
        self.reason = reason
        self.cancelledBy = cancelledBy
        self.cancelledAt = cancelledAt
        self.refundAmount = refundAmount
    }
}

// MARK: - Split Payment Models

public struct SplitIntent: Identifiable, Codable {
    public let id: String
    public let bookingId: String
    public let shareType: SplitShareType
    public let shares: [SplitShare]
    public let status: SplitStatus
    public let expiresAt: Date
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(id: String, bookingId: String, shareType: SplitShareType, shares: [SplitShare], 
                status: SplitStatus, expiresAt: Date, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.bookingId = bookingId
        self.shareType = shareType
        self.shares = shares
        self.status = status
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum SplitShareType: String, CaseIterable, Codable {
    case even = "even"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .even: return "Equal Split"
        case .custom: return "Custom Split"
        }
    }
}

public enum SplitStatus: String, Codable {
    case pending = "pending"
    case partial = "partial"
    case paid = "paid"
    case expired = "expired"
    case cancelled = "cancelled"
    
    public var displayName: String {
        switch self {
        case .pending: return "Awaiting Payment"
        case .partial: return "Partially Paid"
        case .paid: return "Fully Paid"
        case .expired: return "Expired"
        case .cancelled: return "Cancelled"
        }
    }
}

public struct SplitShare: Codable {
    public let userId: String
    public let userName: String
    public let amount: Double
    public let status: SplitShareStatus
    public let paymentIntentId: String?
    public let paidAt: Date?
    
    public init(userId: String, userName: String, amount: Double, status: SplitShareStatus, 
                paymentIntentId: String? = nil, paidAt: Date? = nil) {
        self.userId = userId
        self.userName = userName
        self.amount = amount
        self.status = status
        self.paymentIntentId = paymentIntentId
        self.paidAt = paidAt
    }
}

public enum SplitShareStatus: String, Codable {
    case pending = "pending"
    case paid = "paid"
    case failed = "failed"
}

public struct PaymentFee: Codable {
    public let type: String
    public let amount: Double
    public let description: String
    
    public init(type: String, amount: Double, description: String) {
        self.type = type
        self.amount = amount
        self.description = description
    }
}

// MARK: - Search and Filter Models
public struct SearchLocation: Codable {
    public let lat: Double
    public let lng: Double
    public let radiusKm: Double?
    
    public init(lat: Double, lng: Double, radiusKm: Double? = nil) {
        self.lat = lat
        self.lng = lng
        self.radiusKm = radiusKm
    }
}

public struct SearchResponse: Codable {
    public let activities: [Activity]
    public let total: Int
    public let reasonCodes: [String]
    public let nextCursor: String?
    
    public init(activities: [Activity], total: Int, reasonCodes: [String], nextCursor: String? = nil) {
        self.activities = activities
        self.total = total
        self.reasonCodes = reasonCodes
        self.nextCursor = nextCursor
    }
}

// MARK: - Request Models

public struct GroupDraft: Codable {
    public let name: String
    public let activityId: String?
    public let preferences: GroupPreferences
    public let inviteUserIds: [String]?
    
    public init(name: String, activityId: String? = nil, preferences: GroupPreferences, 
                inviteUserIds: [String]? = nil) {
        self.name = name
        self.activityId = activityId
        self.preferences = preferences
        self.inviteUserIds = inviteUserIds
    }
}

public struct PartnerRequestDraft: Codable {
    public let activityCategory: ActivityCategory
    public let cityId: String
    public let neighborhood: String?
    public let skillLevel: String?
    public let message: String
    public let desiredWindow: DateWindow
    public let preferredDays: [String]?
    public let frequency: Frequency
    
    public init(activityCategory: ActivityCategory, cityId: String, neighborhood: String? = nil, 
                skillLevel: String? = nil, message: String, desiredWindow: DateWindow, 
                preferredDays: [String]? = nil, frequency: Frequency) {
        self.activityCategory = activityCategory
        self.cityId = cityId
        self.neighborhood = neighborhood
        self.skillLevel = skillLevel
        self.message = message
        self.desiredWindow = desiredWindow
        self.preferredDays = preferredDays
        self.frequency = frequency
    }
}

public struct BookingRequest: Codable {
    public let groupId: String
    public let activityId: String
    public let sessionId: String
    public let participants: [String]
    
    public init(groupId: String, activityId: String, sessionId: String, participants: [String]) {
        self.groupId = groupId
        self.activityId = activityId
        self.sessionId = sessionId
        self.participants = participants
    }
}

public struct SplitIntentRequest: Codable {
    public let bookingId: String
    public let shareType: SplitShareType
    public let customShares: [CustomShare]?
    
    public init(bookingId: String, shareType: SplitShareType, customShares: [CustomShare]? = nil) {
        self.bookingId = bookingId
        self.shareType = shareType
        self.customShares = customShares
    }
}

public struct CustomShare: Codable { public let userId: String; public let amount: Double; public init(userId: String, amount: Double) { self.userId = userId; self.amount = amount } }

// MARK: - Error Types

public enum ActivitiesServiceError: LocalizedError {
    case notAuthenticated
    case networkError(String)
    case invalidRequest(String)
    case notFound(String)
    case unauthorized
    case paymentFailed(String)
    case invalidResponse
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .notFound(let item):
            return "\(item) not found"
        case .unauthorized:
            return "Not authorized to perform this action"
        case .paymentFailed(let reason):
            return "Payment failed: \(reason)"
        case .invalidResponse:
            return "Invalid response from server"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Types used by Firestore decoder helpers
public struct Location: Codable { public let latitude: Double; public let longitude: Double }
public enum PaymentStatus: String, Codable { case pending, paid, failed }
public struct Cancellation: Codable { public let reason: String; public let cancelledAt: Date }
public struct TimeWindow: Codable { public let from: Date; public let to: Date }
public enum Weekday: String, Codable { case monday, tuesday, wednesday, thursday, friday, saturday, sunday }
public enum ActivityFrequency: String, Codable { case one_off = "one_off", recurring = "recurring" }
public struct ContactInfo: Codable {
    public let phone: String?
    public let email: String?
    public let website: String?
    public let socialMedia: [String: String]
    
    public init(phone: String? = nil, email: String? = nil, website: String? = nil, socialMedia: [String: String] = [:]) {
        self.phone = phone
        self.email = email
        self.website = website
        self.socialMedia = socialMedia
    }
}

// MARK: - Shared small enums used by service & mocks
public enum InvitationResponse: String, Codable {
    case accepted
    case declined
}

public enum WeatherDependency: String, Codable {
    case none
    case weatherPermitting
    case indoor
}