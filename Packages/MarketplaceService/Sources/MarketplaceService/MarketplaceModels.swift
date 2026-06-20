import Foundation
import FirebaseFirestoreSwift
import CoreLocation

// MARK: - Core Models per Section 5 of implementation-plan.md

public struct City: Codable, Identifiable {
    @DocumentID public var id: String?
    public let name: String
    public let neighborhoods: [String]
    public let defaultCurrency: String // "MAD"
    public let settings: CitySettings
    
    public struct CitySettings: Codable {
        public let maxDeliveryRadiusKm: Double
        public let meetupSafetyTipsUrl: String?
    }
}

public struct Listing: Codable, Identifiable {
    @DocumentID public var id: String?
    public let cityId: String
    public let neighborhoodId: String?
    public let title: String
    public let description: String
    public let category: ListingCategory
    public let condition: ItemCondition
    public let price: Money
    public let images: [String] // Storage URLs
    public let thumbnails: [String] // Storage URLs for thumbnails
    public let sellerId: String
    public var status: ListingStatus
    public let createdAt: Date
    public var updatedAt: Date
    public let location: Location
    public let deliveryOptions: DeliveryOptions
    public let attributes: [String: String] // Category-specific attributes
    public let embedding: [Double]? // Vector embeddings for search
    public let moderation: ModerationInfo?
    
    public struct Location: Codable {
        public let lat: Double
        public let lng: Double
        public let addressLine: String?
        public let arrondissement: String? // For Casablanca/Rabat
        
        public var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        public init(
            lat: Double,
            lng: Double,
            addressLine: String? = nil,
            arrondissement: String? = nil
        ) {
            self.lat = lat
            self.lng = lng
            self.addressLine = addressLine
            self.arrondissement = arrondissement
        }
    }
    
    public struct DeliveryOptions: Codable {
        public let meetup: Bool
        public let courier: Bool

        public init(meetup: Bool, courier: Bool) {
            self.meetup = meetup
            self.courier = courier
        }
    }
    
    public struct ModerationInfo: Codable {
        public let status: ModerationStatus
        public let reasons: [String]
    }
}

public enum ListingCategory: String, Codable, CaseIterable {
    case electronics = "electronics"
    case furniture = "furniture"
    case apparel = "apparel"
    case carParts = "car_parts"
    case books = "books"
    case sports = "sports"
    case toys = "toys"
    case appliances = "appliances"
    case jewelry = "jewelry"
    case art = "art"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .electronics: return "Electronics"
        case .furniture: return "Furniture"
        case .apparel: return "Apparel"
        case .carParts: return "Car Parts"
        case .books: return "Books"
        case .sports: return "Sports"
        case .toys: return "Toys"
        case .appliances: return "Appliances"
        case .jewelry: return "Jewelry"
        case .art: return "Art"
        case .other: return "Other"
        }
    }
    
    // Category-specific Try Lab capabilities per Section 6
    public var tryLabCapabilities: [TryLabCapability] {
        switch self {
        case .apparel:
            return [.tryOn]
        case .carParts:
            return [.fitCheck, .tutorial]
        case .furniture:
            return [.arPlacement]
        default:
            return []
        }
    }
}

public enum TryLabCapability: String, Codable {
    case tryOn = "try_on"
    case fitCheck = "fit_check"
    case tutorial = "tutorial"
    case arPlacement = "ar_placement"
}

public enum ItemCondition: String, Codable, CaseIterable {
    case new = "new"
    case likeNew = "like_new"
    case good = "good"
    case fair = "fair"
    
    public var displayName: String {
        switch self {
        case .new: return "New"
        case .likeNew: return "Like New"
        case .good: return "Good"
        case .fair: return "Fair"
        }
    }
}

public enum ListingStatus: String, Codable {
    case active = "active"
    case reserved = "reserved"
    case sold = "sold"
    case removed = "removed"
}

public enum ModerationStatus: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case flagged = "flagged"
    case rejected = "rejected"
}

public struct Money: Codable, Equatable {
    public let amount: Int // In cents/minor units
    public let currency: String // "MAD", "USD", etc.
    
    public var displayAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: Double(amount) / 100)) ?? "\(currency) \(amount/100)"
    }
    
    public init(amount: Int, currency: String = "MAD") {
        self.amount = amount
        self.currency = currency
    }
}

// MARK: - User Models

public struct MarketplaceUser: Codable, Identifiable {
    @DocumentID public var id: String?
    public let displayName: String
    public let photoUrl: String?
    public let phoneVerified: Bool
    public let seller: SellerInfo?
    public let buyer: BuyerInfo?
    public let preferences: UserPreferences?
    
    public struct SellerInfo: Codable {
        public let kycStatus: KYCStatus
        public let rating: Double
        public let stats: SellerStats
        
        public struct SellerStats: Codable {
            public let soldCount: Int
            public let cancelRate: Double
        }
    }
    
    public struct BuyerInfo: Codable {
        public let rating: Double
    }
    
    public struct UserPreferences: Codable {
        public let neighborhoods: [String]
        public let categories: [String]
        public let priceBand: PriceBand?
        
        public struct PriceBand: Codable {
            public let min: Int
            public let max: Int
        }
    }
}

public enum KYCStatus: String, Codable {
    case none = "none"
    case pending = "pending"
    case verified = "verified"
    case rejected = "rejected"
}

// MARK: - Messaging Models

public struct Conversation: Codable, Identifiable {
    @DocumentID public var id: String?
    public let participants: [String] // User IDs
    public let listingId: String
    public let lastMessageAt: Date
    public let unreadCount: [String: Int] // Per participant
}

public struct Message: Codable, Identifiable {
    @DocumentID public var id: String?
    public let conversationId: String
    public let senderId: String
    public let type: MessageType
    public let content: String
    public let createdAt: Date
    
    public enum MessageType: String, Codable {
        case text = "text"
        case image = "image"
        case system = "system"
    }

    public init(
        id: String? = nil,
        conversationId: String,
        senderId: String,
        type: MessageType,
        content: String,
        createdAt: Date
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.type = type
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - Offer Models

public struct Offer: Codable, Identifiable {
    @DocumentID public var id: String?
    public let listingId: String
    public let buyerId: String
    public let amount: Money
    public var status: OfferStatus
    public let createdAt: Date
    public var updatedAt: Date?

    public init(
        id: String? = nil,
        listingId: String,
        buyerId: String,
        amount: Money,
        status: OfferStatus,
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.listingId = listingId
        self.buyerId = buyerId
        self.amount = amount
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum OfferStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case withdrawn = "withdrawn"
    case expired = "expired"
}

public enum OfferAction: String, Codable {
    case accept = "accept"
    case decline = "decline"
    case withdraw = "withdraw"
}

// MARK: - Reservation Models

public struct Reservation: Codable, Identifiable {
    @DocumentID public var id: String?
    public let listingId: String
    public let buyerId: String
    public var status: ReservationStatus
    public let meetup: MeetupDetails?
    public let delivery: DeliveryDetails?
    public let createdAt: Date
    public var completedAt: Date?
    
    public struct MeetupDetails: Codable {
        public let when: Date
        public let locationName: String
        public let coordinates: Coordinates?

        enum CodingKeys: String, CodingKey { case when, locationName = "where", coordinates }
    }
    
    public struct DeliveryDetails: Codable {
        public let courierJobId: String?
        public let estimatedDelivery: Date?
    }
}

public enum ReservationStatus: String, Codable {
    case pending = "pending"
    case confirmed = "confirmed"
    case completed = "completed"
    case cancelled = "cancelled"
}

// MARK: - Payment Models

public struct Payment: Codable, Identifiable {
    @DocumentID public var id: String?
    public let reservationId: String
    public let escrowIntentId: String? // Stripe payment intent ID
    public let method: PaymentMethod
    public var status: PaymentStatus
    public let amount: Money
    public let timeline: PaymentTimeline
    
    public struct PaymentTimeline: Codable {
        public let authorizedAt: Date?
        public let capturedAt: Date?
        public let refundedAt: Date?
    }
}

public enum PaymentMethod: String, Codable {
    case cod = "cod" // Cash on delivery
    case cardEscrow = "card_escrow" // Stripe Connect escrow (phase 2)
}

public enum PaymentStatus: String, Codable {
    case pending = "pending"
    case authorized = "authorized"
    case captured = "captured"
    case refunded = "refunded"
    case failed = "failed"
}

// MARK: - Alert Models (AI Watchers)

public struct Alert: Codable, Identifiable {
    @DocumentID public var id: String?
    public let userId: String
    public let queryDSL: String // Query in DSL format
    public let cityId: String
    public let neighborhoods: [String]
    public let priceRange: PriceRange?
    public let categories: [String]
    public let createdAt: Date
    public var isActive: Bool
    
    public struct PriceRange: Codable {
        public let min: Int
        public let max: Int
    }
}

// MARK: - Interaction Tracking

public struct Interaction: Codable, Identifiable {
    @DocumentID public var id: String?
    public let userId: String
    public let type: InteractionType
    public let entityId: String
    public let entityType: EntityType
    public let timestamp: Date
    public let context: [String: String]?
}

public enum InteractionType: String, Codable {
    case view = "view"
    case save = "save"
    case contact = "contact"
    case offer = "offer"
    case purchase = "purchase"
    case flag = "flag"
    case like = "like"
    case dislike = "dislike"
}

public enum EntityType: String, Codable {
    case listing = "listing"
    case user = "user"
}

// MARK: - Cross-App Traits (Parent AI Integration)

public struct UserTraits: Codable {
    public let userId: String
    public let traits: Traits
    public let updatedAt: Date
    public let provenance: Provenance

    public init(userId: String, traits: Traits, updatedAt: Date, provenance: Provenance) {
        self.userId = userId
        self.traits = traits
        self.updatedAt = updatedAt
        self.provenance = provenance
    }
    
    public struct Traits: Codable {
        public let carModel: String?
        public let clothingSizes: ClothingSizes?
        public let stylePreferences: [String]?
        public let diySkillLevel: String?

        public init(
            carModel: String? = nil,
            clothingSizes: ClothingSizes? = nil,
            stylePreferences: [String]? = nil,
            diySkillLevel: String? = nil
        ) {
            self.carModel = carModel
            self.clothingSizes = clothingSizes
            self.stylePreferences = stylePreferences
            self.diySkillLevel = diySkillLevel
        }
        
        public struct ClothingSizes: Codable {
            public let tops: String?
            public let bottoms: String?
            public let shoes: String?

            public init(tops: String? = nil, bottoms: String? = nil, shoes: String? = nil) {
                self.tops = tops
                self.bottoms = bottoms
                self.shoes = shoes
            }
        }
    }
    
    public struct Provenance: Codable {
        public let app: String
        public let scope: String
        public let consentId: String

        public init(app: String, scope: String, consentId: String) {
            self.app = app
            self.scope = scope
            self.consentId = consentId
        }
    }
}

public struct ConsentGrant: Codable, Identifiable {
    @DocumentID public var id: String?
    public let userId: String
    public let scope: String // e.g., "marketplace:car_profile_read"
    public var status: ConsentStatus
    public let createdAt: Date
    public let expiresAt: Date?
}

public enum ConsentStatus: String, Codable {
    case granted = "granted"
    case revoked = "revoked"
}

// MARK: - Helper Types

public struct Coordinates: Codable, Equatable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Search & Filter Models

public struct SearchFilters: Codable {
    public let cityId: String
    public let neighborhoods: [String]?
    public let categories: [ListingCategory]?
    public let priceRange: PriceRange?
    public let condition: ItemCondition?
    public let hasImages: Bool?
    public let deliveryOptions: DeliveryOptionsFilter?

    public init(
        cityId: String,
        neighborhoods: [String]? = nil,
        categories: [ListingCategory]? = nil,
        priceRange: PriceRange? = nil,
        condition: ItemCondition? = nil,
        hasImages: Bool? = nil,
        deliveryOptions: DeliveryOptionsFilter? = nil
    ) {
        self.cityId = cityId
        self.neighborhoods = neighborhoods
        self.categories = categories
        self.priceRange = priceRange
        self.condition = condition
        self.hasImages = hasImages
        self.deliveryOptions = deliveryOptions
    }
    
    public struct PriceRange: Codable {
        public let min: Int?
        public let max: Int?
    }
    
    public struct DeliveryOptionsFilter: Codable {
        public let meetup: Bool?
        public let courier: Bool?
    }
}

// MARK: - AI Models

public struct AIResponse: Codable {
    public let answer: String
    // Extended fields used by mock AI; optional for compatibility
    public let confidence: Double?
    public let sources: [String]?
    public let followUpSuggestions: [String]?
    public let actionButtons: [AIActionButton]?
    // Original fields kept for future provider responses
    public let suggestedActions: [SuggestedAction]?
    public let reasonCodes: [String]?

    public init(
        answer: String,
        confidence: Double? = nil,
        sources: [String]? = nil,
        followUpSuggestions: [String]? = nil,
        actionButtons: [AIActionButton]? = nil,
        suggestedActions: [SuggestedAction]? = nil,
        reasonCodes: [String]? = nil
    ) {
        self.answer = answer
        self.confidence = confidence
        self.sources = sources
        self.followUpSuggestions = followUpSuggestions
        self.actionButtons = actionButtons
        self.suggestedActions = suggestedActions
        self.reasonCodes = reasonCodes
    }
    
    public struct SuggestedAction: Codable {
        public let type: String
        public let label: String
        public let data: [String: String]
    }
}

public struct AIActionButton: Codable {
    public let title: String
    public let action: String

    public init(title: String, action: String) {
        self.title = title
        self.action = action
    }
}

public struct NegotiationSuggestion: Codable {
    public let suggestedPrice: Money
    public let reasoning: String
    public let comparables: [String]? // Listing IDs
    public let draftMessage: String

    public init(
        suggestedPrice: Money,
        reasoning: String,
        comparables: [String]? = nil,
        draftMessage: String
    ) {
        self.suggestedPrice = suggestedPrice
        self.reasoning = reasoning
        self.comparables = comparables
        self.draftMessage = draftMessage
    }
}

// MARK: - Plugin Models (Try Lab)

public struct PluginInput: Codable {
    public let category: String
    public let action: String
    public let data: [String: String]
    
    public init(category: String, action: String, data: [String: String]) {
        self.category = category
        self.action = action
        self.data = data
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(category, forKey: .category)
        try container.encode(action, forKey: .action)
        try container.encode(data, forKey: .data)
    }
    
    enum CodingKeys: String, CodingKey {
        case category, action, data
    }
}

public struct PluginOutput: Codable {
    public let success: Bool
    public let result: [String: String]?
    public let error: String?
}

// MARK: - Draft Models for Creation

public struct ListingDraft {
    public let title: String
    public let description: String
    public let category: ListingCategory
    public let condition: ItemCondition
    public let price: Money
    public let images: [Data] // Raw image data
    public let location: Listing.Location
    public let deliveryOptions: Listing.DeliveryOptions
    public let attributes: [String: String]
    
    public init(
        title: String,
        description: String,
        category: ListingCategory,
        condition: ItemCondition,
        price: Money,
        images: [Data],
        location: Listing.Location,
        deliveryOptions: Listing.DeliveryOptions,
        attributes: [String: String] = [:]
    ) {
        self.title = title
        self.description = description
        self.category = category
        self.condition = condition
        self.price = price
        self.images = images
        self.location = location
        self.deliveryOptions = deliveryOptions
        self.attributes = attributes
    }
}

public struct ListingUpdate {
    public let title: String?
    public let description: String?
    public let price: Money?
    public let status: ListingStatus?
    public let deliveryOptions: Listing.DeliveryOptions?
    
    public init(
        title: String? = nil,
        description: String? = nil,
        price: Money? = nil,
        status: ListingStatus? = nil,
        deliveryOptions: Listing.DeliveryOptions? = nil
    ) {
        self.title = title
        self.description = description
        self.price = price
        self.status = status
        self.deliveryOptions = deliveryOptions
    }
}

public struct MessageDraft {
    public let type: Message.MessageType
    public let content: String
    public let imageData: Data? // For image messages
    
    public init(type: Message.MessageType, content: String, imageData: Data? = nil) {
        self.type = type
        self.content = content
        self.imageData = imageData
    }
}

public struct ReservationDetails {
    public let meetup: Reservation.MeetupDetails?
    public let delivery: Reservation.DeliveryDetails?
    public let paymentMethod: PaymentMethod
    
    public init(
        meetup: Reservation.MeetupDetails? = nil,
        delivery: Reservation.DeliveryDetails? = nil,
        paymentMethod: PaymentMethod = .cod
    ) {
        self.meetup = meetup
        self.delivery = delivery
        self.paymentMethod = paymentMethod
    }
}

public struct AlertCriteria {
    public let query: String
    public let cityId: String
    public let neighborhoods: [String]
    public let categories: [ListingCategory]
    public let priceRange: Alert.PriceRange?
    
    public init(
        query: String,
        cityId: String,
        neighborhoods: [String] = [],
        categories: [ListingCategory] = [],
        priceRange: Alert.PriceRange? = nil
    ) {
        self.query = query
        self.cityId = cityId
        self.neighborhoods = neighborhoods
        self.categories = categories
        self.priceRange = priceRange
    }
}

public struct RecContext {
    public let userId: String
    public let cityId: String
    public let currentLocation: Coordinates?
    public let sessionHistory: [String]? // Recent listing IDs viewed
    
    public init(
        userId: String,
        cityId: String,
        currentLocation: Coordinates? = nil,
        sessionHistory: [String]? = nil
    ) {
        self.userId = userId
        self.cityId = cityId
        self.currentLocation = currentLocation
        self.sessionHistory = sessionHistory
    }
}

// MARK: - Trait Scopes for Cross-App Integration

public enum TraitScope: String, Codable {
    case carProfileRead = "marketplace:car_profile_read"
    case clothingSizesRead = "marketplace:clothing_sizes_read"
    case stylePreferencesRead = "marketplace:style_preferences_read"
    case diySkillRead = "marketplace:diy_skill_read"
}