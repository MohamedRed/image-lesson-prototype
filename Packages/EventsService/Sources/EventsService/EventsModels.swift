import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Core Event Models

public struct Event: Codable, Identifiable, Equatable {
    @DocumentID public var id: String?
    public let promoterId: String
    public let title: String
    public let category: EventCategory
    public let description: String
    public let images: [String]
    public let rules: [String]
    public let priceTiers: [PriceTier]
    public let location: GeoPoint
    public let venueName: String
    public let neighborhood: String?
    public let startAt: Date
    public let endAt: Date
    public let recurrence: RecurrenceRule?
    public let ageRestrictions: AgeRestriction?
    public let indoor: Bool
    public let tags: [String]
    public let seating: SeatingInfo
    public let status: EventStatus
    @ServerTimestamp public var createdAt: Date?
    @ServerTimestamp public var updatedAt: Date?
    
    public init(
        id: String? = nil,
        promoterId: String,
        title: String,
        category: EventCategory,
        description: String,
        images: [String] = [],
        rules: [String] = [],
        priceTiers: [PriceTier],
        location: GeoPoint,
        venueName: String,
        neighborhood: String? = nil,
        startAt: Date,
        endAt: Date,
        recurrence: RecurrenceRule? = nil,
        ageRestrictions: AgeRestriction? = nil,
        indoor: Bool = true,
        tags: [String] = [],
        seating: SeatingInfo,
        status: EventStatus = .published
    ) {
        self.id = id
        self.promoterId = promoterId
        self.title = title
        self.category = category
        self.description = description
        self.images = images
        self.rules = rules
        self.priceTiers = priceTiers
        self.location = location
        self.venueName = venueName
        self.neighborhood = neighborhood
        self.startAt = startAt
        self.endAt = endAt
        self.recurrence = recurrence
        self.ageRestrictions = ageRestrictions
        self.indoor = indoor
        self.tags = tags
        self.seating = seating
        self.status = status
    }
}

public enum EventCategory: String, Codable, CaseIterable {
    case music
    case culture
    case sports
    case theater
    case conference
    case family
    case other
}

public enum EventStatus: String, Codable {
    case draft
    case published
    case soldOut = "sold_out"
    case cancelled
}

public struct PriceTier: Codable, Equatable {
    public let name: String
    public let priceMAD: Double
    public let currency: String
    public let description: String?
    
    public init(name: String, priceMAD: Double, currency: String = "MAD", description: String? = nil) {
        self.name = name
        self.priceMAD = priceMAD
        self.currency = currency
        self.description = description
    }
}

public struct SeatingInfo: Codable, Equatable {
    public let hasSeatMap: Bool
    public let generalAdmission: Bool
    public let totalCapacity: Int?
    
    public init(hasSeatMap: Bool = false, generalAdmission: Bool = true, totalCapacity: Int? = nil) {
        self.hasSeatMap = hasSeatMap
        self.generalAdmission = generalAdmission
        self.totalCapacity = totalCapacity
    }
}

public struct AgeRestriction: Codable, Equatable {
    public let minimumAge: Int?
    public let requiresGuardian: Bool
    
    public init(minimumAge: Int? = nil, requiresGuardian: Bool = false) {
        self.minimumAge = minimumAge
        self.requiresGuardian = requiresGuardian
    }
}

public struct RecurrenceRule: Codable, Equatable {
    public let frequency: RecurrenceFrequency
    public let interval: Int
    public let daysOfWeek: [Int]?
    public let endDate: Date?
    
    public init(frequency: RecurrenceFrequency, interval: Int = 1, daysOfWeek: [Int]? = nil, endDate: Date? = nil) {
        self.frequency = frequency
        self.interval = interval
        self.daysOfWeek = daysOfWeek
        self.endDate = endDate
    }
}

public enum RecurrenceFrequency: String, Codable {
    case daily
    case weekly
    case monthly
}

// MARK: - Event Session Models

public struct EventSession: Codable, Identifiable, Equatable {
    @DocumentID public var id: String?
    public let eventId: String
    public let startAt: Date
    public let endAt: Date
    public let capacityByTier: [String: Int]
    public let status: SessionStatus
    @ServerTimestamp public var createdAt: Date?
    
    public init(
        id: String? = nil,
        eventId: String,
        startAt: Date,
        endAt: Date,
        capacityByTier: [String: Int],
        status: SessionStatus = .scheduled
    ) {
        self.id = id
        self.eventId = eventId
        self.startAt = startAt
        self.endAt = endAt
        self.capacityByTier = capacityByTier
        self.status = status
    }
}

public enum SessionStatus: String, Codable {
    case scheduled
    case limited
    case soldOut = "sold_out"
    case cancelled
}

// MARK: - Attendance Group Models

public struct AttendanceGroup: Codable, Identifiable, Equatable {
    @DocumentID public var id: String?
    public let organizerId: String
    public let eventId: String
    public let sessionId: String?
    public let name: String
    public let status: GroupStatus
    public let invitedUserIds: [String]
    public let participantUserIds: [String]
    public let chatThreadId: String?
    @ServerTimestamp public var createdAt: Date?
    @ServerTimestamp public var updatedAt: Date?
    
    public init(
        id: String? = nil,
        organizerId: String,
        eventId: String,
        sessionId: String? = nil,
        name: String,
        status: GroupStatus = .planning,
        invitedUserIds: [String] = [],
        participantUserIds: [String] = [],
        chatThreadId: String? = nil
    ) {
        self.id = id
        self.organizerId = organizerId
        self.eventId = eventId
        self.sessionId = sessionId
        self.name = name
        self.status = status
        self.invitedUserIds = invitedUserIds
        self.participantUserIds = participantUserIds
        self.chatThreadId = chatThreadId
    }
}

public enum GroupStatus: String, Codable {
    case planning
    case ordering
    case confirmed
    case attended
    case cancelled
}

// MARK: - Ticket Order Models

public struct TicketOrder: Codable, Identifiable, Equatable {
    @DocumentID public var id: String?
    public let groupId: String
    public let eventId: String
    public let sessionId: String?
    public let promoterId: String
    public let organizerId: String
    public let lineItems: [OrderLineItem]
    public let totalAmount: Double
    public let currency: String
    public let status: OrderStatus
    public let paymentIntentId: String?
    public let tickets: [Ticket]
    public let settlement: OrderSettlement?
    @ServerTimestamp public var createdAt: Date?
    @ServerTimestamp public var updatedAt: Date?
    
    public init(
        id: String? = nil,
        groupId: String,
        eventId: String,
        sessionId: String? = nil,
        promoterId: String,
        organizerId: String,
        lineItems: [OrderLineItem],
        totalAmount: Double,
        currency: String = "MAD",
        status: OrderStatus = .pending,
        paymentIntentId: String? = nil,
        tickets: [Ticket] = [],
        settlement: OrderSettlement? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.eventId = eventId
        self.sessionId = sessionId
        self.promoterId = promoterId
        self.organizerId = organizerId
        self.lineItems = lineItems
        self.totalAmount = totalAmount
        self.currency = currency
        self.status = status
        self.paymentIntentId = paymentIntentId
        self.tickets = tickets
        self.settlement = settlement
    }
}

public enum OrderStatus: String, Codable {
    case pending
    case awaitingSplit = "awaiting_split"
    case confirmed
    case cancelled
    case refunded
}

public struct OrderLineItem: Codable, Equatable {
    public let tierName: String
    public let quantity: Int
    public let unitPrice: Double
    
    public init(tierName: String, quantity: Int, unitPrice: Double) {
        self.tierName = tierName
        self.quantity = quantity
        self.unitPrice = unitPrice
    }
}

public struct Ticket: Codable, Equatable {
    public let code: String
    public let qrUrl: String?
    public let seat: String?
    
    public init(code: String, qrUrl: String? = nil, seat: String? = nil) {
        self.code = code
        self.qrUrl = qrUrl
        self.seat = seat
    }
}

public struct OrderSettlement: Codable, Equatable {
    public let splits: [SplitShare]
    public let fees: [Fee]
    public let collectedAt: Date?
    
    public init(splits: [SplitShare], fees: [Fee] = [], collectedAt: Date? = nil) {
        self.splits = splits
        self.fees = fees
        self.collectedAt = collectedAt
    }
}

public struct Fee: Codable, Equatable {
    public let type: String
    public let amount: Double
    
    public init(type: String, amount: Double) {
        self.type = type
        self.amount = amount
    }
}

// MARK: - Split Payment Models

public struct SplitIntent: Codable, Identifiable, Equatable {
    @DocumentID public var id: String?
    public let orderId: String
    public let shareType: ShareType
    public let shares: [SplitShare]
    public let status: SplitStatus
    public let expiresAt: Date
    @ServerTimestamp public var createdAt: Date?
    
    public init(
        id: String? = nil,
        orderId: String,
        shareType: ShareType,
        shares: [SplitShare],
        status: SplitStatus = .pending,
        expiresAt: Date
    ) {
        self.id = id
        self.orderId = orderId
        self.shareType = shareType
        self.shares = shares
        self.status = status
        self.expiresAt = expiresAt
    }
}

public enum ShareType: String, Codable {
    case even
    case custom
}

public enum SplitStatus: String, Codable {
    case pending
    case paid
    case expired
}

public struct SplitShare: Codable, Equatable {
    public let userId: String
    public let amount: Double
    public let isPaid: Bool
    
    public init(userId: String, amount: Double, isPaid: Bool = false) {
        self.userId = userId
        self.amount = amount
        self.isPaid = isPaid
    }
}

// MARK: - Promoter Models

public struct EventPromoter: Codable, Identifiable, Equatable {
    @DocumentID public var id: String?
    public let name: String
    public let contact: PromoterContact
    public let verificationTier: VerificationTier
    public let payoutAccount: String?
    public let isActive: Bool
    @ServerTimestamp public var createdAt: Date?
    @ServerTimestamp public var updatedAt: Date?
    
    public init(
        id: String? = nil,
        name: String,
        contact: PromoterContact,
        verificationTier: VerificationTier = .basic,
        payoutAccount: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.contact = contact
        self.verificationTier = verificationTier
        self.payoutAccount = payoutAccount
        self.isActive = isActive
    }
}

public struct PromoterContact: Codable, Equatable {
    public let email: String
    public let phone: String?
    public let website: String?
    
    public init(email: String, phone: String? = nil, website: String? = nil) {
        self.email = email
        self.phone = phone
        self.website = website
    }
}

public enum VerificationTier: String, Codable {
    case basic
    case verified
    case premium
}

// MARK: - Search & Filter Models

public struct EventFilters: Codable {
    public let categories: [EventCategory]?
    public let priceRange: PriceRange?
    public let dateRange: DateRange?
    public let cityId: String?
    public let neighborhood: String?
    public let indoor: Bool?
    public let tags: [String]?
    public let searchRadius: Double?
    
    public init(
        categories: [EventCategory]? = nil,
        priceRange: PriceRange? = nil,
        dateRange: DateRange? = nil,
        cityId: String? = nil,
        neighborhood: String? = nil,
        indoor: Bool? = nil,
        tags: [String]? = nil,
        searchRadius: Double? = nil
    ) {
        self.categories = categories
        self.priceRange = priceRange
        self.dateRange = dateRange
        self.cityId = cityId
        self.neighborhood = neighborhood
        self.indoor = indoor
        self.tags = tags
        self.searchRadius = searchRadius
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

public struct DateRange: Codable {
    public let from: Date
    public let to: Date
    
    public init(from: Date, to: Date) {
        self.from = from
        self.to = to
    }
}

// MARK: - AI Response Models

public struct EventAIResponse: Codable {
    public let answer: String
    public let suggestedEvents: [Event]
    public let reasonCodes: [String]
    public let followUpPrompts: [String]
    
    public init(
        answer: String,
        suggestedEvents: [Event] = [],
        reasonCodes: [String] = [],
        followUpPrompts: [String] = []
    ) {
        self.answer = answer
        self.suggestedEvents = suggestedEvents
        self.reasonCodes = reasonCodes
        self.followUpPrompts = followUpPrompts
    }
}

// MARK: - Request/Response DTOs

public struct AttendanceGroupDraft: Codable {
    public let eventId: String
    public let sessionId: String?
    public let name: String
    public let invitedUserIds: [String]
    
    public init(eventId: String, sessionId: String? = nil, name: String, invitedUserIds: [String] = []) {
        self.eventId = eventId
        self.sessionId = sessionId
        self.name = name
        self.invitedUserIds = invitedUserIds
    }
}

public struct TicketOrderRequest: Codable {
    public let groupId: String
    public let eventId: String
    public let sessionId: String?
    public let lineItems: [OrderLineItem]
    
    public init(groupId: String, eventId: String, sessionId: String? = nil, lineItems: [OrderLineItem]) {
        self.groupId = groupId
        self.eventId = eventId
        self.sessionId = sessionId
        self.lineItems = lineItems
    }
}

public struct SplitIntentRequest: Codable {
    public let orderId: String
    public let shareType: ShareType
    public let customShares: [String: Double]?
    
    public init(orderId: String, shareType: ShareType, customShares: [String: Double]? = nil) {
        self.orderId = orderId
        self.shareType = shareType
        self.customShares = customShares
    }
}

public struct TicketLink: Codable {
    public let groupId: String
    public let eventId: String
    public let externalUrl: String
    public let provider: String?
    
    public init(groupId: String, eventId: String, externalUrl: String, provider: String? = nil) {
        self.groupId = groupId
        self.eventId = eventId
        self.externalUrl = externalUrl
        self.provider = provider
    }
}

public struct TicketLinkResult: Codable {
    public let success: Bool
    public let ticketCodes: [String]?
    public let message: String?
    
    public init(success: Bool, ticketCodes: [String]? = nil, message: String? = nil) {
        self.success = success
        self.ticketCodes = ticketCodes
        self.message = message
    }
}

// MARK: - Friends & Social

/// Friend information for events context
public struct EventsFriend: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let profileImageURL: URL?
    public let preferredCategories: [EventCategory]
    public let mutualFriendsCount: Int
    public let isOnline: Bool
    public let lastSeen: Date?
    
    public init(
        id: String,
        name: String,
        profileImageURL: URL? = nil,
        preferredCategories: [EventCategory] = [],
        mutualFriendsCount: Int = 0,
        isOnline: Bool = false,
        lastSeen: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.profileImageURL = profileImageURL
        self.preferredCategories = preferredCategories
        self.mutualFriendsCount = mutualFriendsCount
        self.isOnline = isOnline
        self.lastSeen = lastSeen
    }
}

/// Friend's event activity
public struct FriendEventActivity: Codable, Identifiable, Hashable {
    public let id: String
    public let friendId: String
    public let friendName: String
    public let eventId: String
    public let eventTitle: String
    public let activityType: FriendActivityType
    public let timestamp: Date
    public let isVisible: Bool
    
    public init(
        id: String = UUID().uuidString,
        friendId: String,
        friendName: String,
        eventId: String,
        eventTitle: String,
        activityType: FriendActivityType,
        timestamp: Date = Date(),
        isVisible: Bool = true
    ) {
        self.id = id
        self.friendId = friendId
        self.friendName = friendName
        self.eventId = eventId
        self.eventTitle = eventTitle
        self.activityType = activityType
        self.timestamp = timestamp
        self.isVisible = isVisible
    }
}

/// Types of friend activities
public enum FriendActivityType: String, Codable, CaseIterable {
    case saved = "saved"
    case attending = "attending"
    case interested = "interested"
    case ordered = "ordered"
    case reviewed = "reviewed"
    
    public var displayName: String {
        switch self {
        case .saved: return "Saved"
        case .attending: return "Attending"
        case .interested: return "Interested"
        case .ordered: return "Got tickets"
        case .reviewed: return "Reviewed"
        }
    }
}

/// Event invitation
public struct EventInvite: Codable, Identifiable, Hashable {
    public let id: String
    public let fromUserId: String
    public let fromUserName: String
    public let toUserId: String
    public let eventId: String
    public let eventTitle: String
    public let message: String?
    public let createdAt: Date
    public let response: InviteResponse?
    public let respondedAt: Date?
    
    public init(
        id: String = UUID().uuidString,
        fromUserId: String,
        fromUserName: String,
        toUserId: String,
        eventId: String,
        eventTitle: String,
        message: String? = nil,
        createdAt: Date = Date(),
        response: InviteResponse? = nil,
        respondedAt: Date? = nil
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.toUserId = toUserId
        self.eventId = eventId
        self.eventTitle = eventTitle
        self.message = message
        self.createdAt = createdAt
        self.response = response
        self.respondedAt = respondedAt
    }
}

/// Invite response type
public enum InviteResponse: String, Codable, CaseIterable {
    case accepted = "accepted"
    case declined = "declined"
    case maybe = "maybe"
    
    public var displayName: String {
        switch self {
        case .accepted: return "Going"
        case .declined: return "Can't go"
        case .maybe: return "Maybe"
        }
    }
}

// MARK: - Chat & Messaging

/// Group chat message
public struct GroupChatMessage: Codable, Identifiable, Hashable {
    public let id: String
    public let chatId: String
    public let userId: String
    public let userName: String
    public let userAvatarURL: URL?
    public let content: String
    public let messageType: ChatMessageType
    public let timestamp: Date
    public let readBy: [String]
    public let isSystemMessage: Bool
    public let replyToId: String?
    
    public init(
        id: String = UUID().uuidString,
        chatId: String,
        userId: String,
        userName: String,
        userAvatarURL: URL? = nil,
        content: String,
        messageType: ChatMessageType = .text,
        timestamp: Date = Date(),
        readBy: [String] = [],
        isSystemMessage: Bool = false,
        replyToId: String? = nil
    ) {
        self.id = id
        self.chatId = chatId
        self.userId = userId
        self.userName = userName
        self.userAvatarURL = userAvatarURL
        self.content = content
        self.messageType = messageType
        self.timestamp = timestamp
        self.readBy = readBy
        self.isSystemMessage = isSystemMessage
        self.replyToId = replyToId
    }
}

/// Chat message types
public enum ChatMessageType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case location = "location"
    case eventDetails = "event_details"
    case rideDetails = "ride_details"
    case system = "system"
    
    public var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .location: return "Location"
        case .eventDetails: return "Event"
        case .rideDetails: return "Ride"
        case .system: return "System"
        }
    }
}

// MARK: - Ride Integration

/// Ride quote for event transportation
public struct RideQuote: Codable, Identifiable, Hashable {
    public let id: String
    public let eventId: String
    public let pickupLocation: LocationCoordinate
    public let dropoffLocation: LocationCoordinate
    public let departureTime: Date
    public let estimatedDuration: Int // minutes
    public let estimatedFare: Int // MAD
    public let passengerCount: Int
    public let vehicleType: String
    public let expiresAt: Date
    public let deepLinkUrl: String
    
    public init(
        id: String = UUID().uuidString,
        eventId: String,
        pickupLocation: LocationCoordinate,
        dropoffLocation: LocationCoordinate,
        departureTime: Date,
        estimatedDuration: Int,
        estimatedFare: Int,
        passengerCount: Int,
        vehicleType: String,
        expiresAt: Date,
        deepLinkUrl: String
    ) {
        self.id = id
        self.eventId = eventId
        self.pickupLocation = pickupLocation
        self.dropoffLocation = dropoffLocation
        self.departureTime = departureTime
        self.estimatedDuration = estimatedDuration
        self.estimatedFare = estimatedFare
        self.passengerCount = passengerCount
        self.vehicleType = vehicleType
        self.expiresAt = expiresAt
        self.deepLinkUrl = deepLinkUrl
    }
}

/// Ride booking request
public struct RideBookingRequest: Codable, Identifiable, Hashable {
    public let id: String
    public let quoteId: String
    public let eventId: String
    public let userId: String
    public let groupId: String?
    public let pickupLocation: LocationCoordinate
    public let dropoffLocation: LocationCoordinate
    public let departureTime: Date
    public let passengerCount: Int
    public let estimatedFare: Int
    public let status: RideBookingStatus
    public let shareRide: Bool
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        quoteId: String,
        eventId: String,
        userId: String,
        groupId: String? = nil,
        pickupLocation: LocationCoordinate,
        dropoffLocation: LocationCoordinate,
        departureTime: Date,
        passengerCount: Int,
        estimatedFare: Int,
        status: RideBookingStatus = .pending,
        shareRide: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.quoteId = quoteId
        self.eventId = eventId
        self.userId = userId
        self.groupId = groupId
        self.pickupLocation = pickupLocation
        self.dropoffLocation = dropoffLocation
        self.departureTime = departureTime
        self.passengerCount = passengerCount
        self.estimatedFare = estimatedFare
        self.status = status
        self.shareRide = shareRide
        self.createdAt = createdAt
    }
}

/// Ride booking status
public enum RideBookingStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed" 
    case cancelled = "cancelled"
    case completed = "completed"
    
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        }
    }
}

/// Ride booking result
public struct RideBookingResult: Codable, Hashable {
    public let bookingId: String
    public let status: String
    public let deepLinks: RideDeepLinks
    public let estimatedFare: Int
    public let departureTime: Date
    public let message: String
    
    public init(
        bookingId: String,
        status: String,
        deepLinks: RideDeepLinks,
        estimatedFare: Int,
        departureTime: Date,
        message: String
    ) {
        self.bookingId = bookingId
        self.status = status
        self.deepLinks = deepLinks
        self.estimatedFare = estimatedFare
        self.departureTime = departureTime
        self.message = message
    }
}

/// Deep links for different ride providers
public struct RideDeepLinks: Codable, Hashable {
    public let uber: String?
    public let careem: String?
    public let inDrive: String?
    public let liiveRide: String
    
    public init(uber: String? = nil, careem: String? = nil, inDrive: String? = nil, liiveRide: String) {
        self.uber = uber
        self.careem = careem
        self.inDrive = inDrive
        self.liiveRide = liiveRide
    }
}

/// Location coordinate for ride integration
public struct LocationCoordinate: Codable, Hashable {
    public let latitude: Double
    public let longitude: Double
    public let address: String?
    
    public init(latitude: Double, longitude: Double, address: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }
}