import Foundation

public struct Booking: Identifiable, Codable, Equatable {
    public let id: String
    public let userId: String
    public let propertyRef: AccommodationProperty
    public let roomTypeRef: RoomType
    public let ratePlanRef: RatePlan
    public let guests: [Guest]
    public let dateRange: DateRange
    public let priceSnapshot: PriceBreakdown
    public let paymentInfo: PaymentInfo
    public let status: BookingStatus
    public let providerConfirmation: ProviderConfirmation?
    public let specialRequests: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String,
        userId: String,
        propertyRef: AccommodationProperty,
        roomTypeRef: RoomType,
        ratePlanRef: RatePlan,
        guests: [Guest],
        dateRange: DateRange,
        priceSnapshot: PriceBreakdown,
        paymentInfo: PaymentInfo,
        status: BookingStatus,
        providerConfirmation: ProviderConfirmation? = nil,
        specialRequests: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.propertyRef = propertyRef
        self.roomTypeRef = roomTypeRef
        self.ratePlanRef = ratePlanRef
        self.guests = guests
        self.dateRange = dateRange
        self.priceSnapshot = priceSnapshot
        self.paymentInfo = paymentInfo
        self.status = status
        self.providerConfirmation = providerConfirmation
        self.specialRequests = specialRequests
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct Guest: Codable, Equatable {
    public let firstName: String
    public let lastName: String
    public let email: String?
    public let phone: String?
    public let dateOfBirth: Date?
    public let isLead: Bool
    
    public init(
        firstName: String,
        lastName: String,
        email: String? = nil,
        phone: String? = nil,
        dateOfBirth: Date? = nil,
        isLead: Bool = false
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.dateOfBirth = dateOfBirth
        self.isLead = isLead
    }
}

public struct PaymentInfo: Codable, Equatable {
    public let method: PaymentMethod
    public let stripePaymentIntentId: String?
    public let stripePaymentMethodId: String?
    public let last4: String?
    public let brand: String?
    public let status: PaymentStatus
    
    public init(
        method: PaymentMethod,
        stripePaymentIntentId: String? = nil,
        stripePaymentMethodId: String? = nil,
        last4: String? = nil,
        brand: String? = nil,
        status: PaymentStatus
    ) {
        self.method = method
        self.stripePaymentIntentId = stripePaymentIntentId
        self.stripePaymentMethodId = stripePaymentMethodId
        self.last4 = last4
        self.brand = brand
        self.status = status
    }
}

public enum PaymentMethod: String, Codable {
    case card = "CARD"
    case applePay = "APPLE_PAY"
    case googlePay = "GOOGLE_PAY"
    case bankTransfer = "BANK_TRANSFER"
    case payAtProperty = "PAY_AT_PROPERTY"
}

public enum PaymentStatus: String, Codable {
    case pending = "PENDING"
    case processing = "PROCESSING"
    case succeeded = "SUCCEEDED"
    case failed = "FAILED"
    case refunded = "REFUNDED"
    case partialRefund = "PARTIAL_REFUND"
}

public enum BookingStatus: String, Codable {
    case pending = "PENDING"
    case confirmed = "CONFIRMED"
    case cancelled = "CANCELLED"
    case completed = "COMPLETED"
    case noShow = "NO_SHOW"
    case inProgress = "IN_PROGRESS"
    
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        case .noShow: return "No Show"
        case .inProgress: return "In Progress"
        }
    }
}

public struct ProviderConfirmation: Codable, Equatable {
    public let provider: String
    public let confirmationCode: String
    public let providerBookingId: String?
    public let providerStatus: String?
    public let deepLink: String?
    
    public init(
        provider: String,
        confirmationCode: String,
        providerBookingId: String? = nil,
        providerStatus: String? = nil,
        deepLink: String? = nil
    ) {
        self.provider = provider
        self.confirmationCode = confirmationCode
        self.providerBookingId = providerBookingId
        self.providerStatus = providerStatus
        self.deepLink = deepLink
    }
}