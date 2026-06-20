import Foundation
import CoreLocation

public struct AccommodationProperty: Identifiable, Codable, Equatable {
    public let id: String
    public let providerRefs: [ProviderReference]
    public let name: String
    public let brand: String?
    public let type: AccommodationType
    public let rating: Double?
    public let reviewsCount: Int
    public let address: Address
    public let coordinates: CLLocationCoordinate2D
    public let photos: [Photo]
    public let amenities: [String]
    public let safetyFeatures: [String]
    public let checkInTime: String
    public let checkOutTime: String
    public let policies: PropertyPolicies
    public let priceRange: PriceRange?
    
    public init(
        id: String,
        providerRefs: [ProviderReference],
        name: String,
        brand: String? = nil,
        type: AccommodationType,
        rating: Double? = nil,
        reviewsCount: Int,
        address: Address,
        coordinates: CLLocationCoordinate2D,
        photos: [Photo],
        amenities: [String],
        safetyFeatures: [String],
        checkInTime: String,
        checkOutTime: String,
        policies: PropertyPolicies,
        priceRange: PriceRange? = nil
    ) {
        self.id = id
        self.providerRefs = providerRefs
        self.name = name
        self.brand = brand
        self.type = type
        self.rating = rating
        self.reviewsCount = reviewsCount
        self.address = address
        self.coordinates = coordinates
        self.photos = photos
        self.amenities = amenities
        self.safetyFeatures = safetyFeatures
        self.checkInTime = checkInTime
        self.checkOutTime = checkOutTime
        self.policies = policies
        self.priceRange = priceRange
    }
}

// Explicit Equatable conformance to avoid synthesis issues due to external type extensions
extension AccommodationProperty {
    public static func == (lhs: AccommodationProperty, rhs: AccommodationProperty) -> Bool {
        return lhs.id == rhs.id
    }
}

public enum AccommodationType: String, Codable, CaseIterable {
    case hotel = "HOTEL"
    case hostel = "HOSTEL"
    case apartment = "APARTMENT"
    case room = "ROOM"
    case homestay = "HOMESTAY"
    case bedAndBreakfast = "BED_AND_BREAKFAST"
    case vacationRental = "VACATION_RENTAL"
    
    public var displayName: String {
        switch self {
        case .hotel: return "Hotel"
        case .hostel: return "Hostel"
        case .apartment: return "Apartment"
        case .room: return "Room"
        case .homestay: return "Homestay"
        case .bedAndBreakfast: return "B&B"
        case .vacationRental: return "Vacation Rental"
        }
    }
}

public struct Address: Codable, Equatable {
    public let street: String?
    public let city: String
    public let state: String?
    public let postalCode: String?
    public let country: String
    public let formattedAddress: String
    
    public init(
        street: String? = nil,
        city: String,
        state: String? = nil,
        postalCode: String? = nil,
        country: String,
        formattedAddress: String
    ) {
        self.street = street
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
        self.formattedAddress = formattedAddress
    }
}

public struct Photo: Codable, Equatable {
    public let id: String
    public let url: String
    public let thumbnailUrl: String?
    public let caption: String?
    public let width: Int?
    public let height: Int?
    
    public init(
        id: String,
        url: String,
        thumbnailUrl: String? = nil,
        caption: String? = nil,
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.caption = caption
        self.width = width
        self.height = height
    }
}

public struct PropertyPolicies: Codable, Equatable {
    public let cancellationPolicy: CancellationPolicy
    public let childrenAllowed: Bool
    public let petsAllowed: Bool
    public let smokingAllowed: Bool
    public let partyEventsAllowed: Bool
    public let additionalRules: [String]
    
    public init(
        cancellationPolicy: CancellationPolicy,
        childrenAllowed: Bool = true,
        petsAllowed: Bool = false,
        smokingAllowed: Bool = false,
        partyEventsAllowed: Bool = false,
        additionalRules: [String] = []
    ) {
        self.cancellationPolicy = cancellationPolicy
        self.childrenAllowed = childrenAllowed
        self.petsAllowed = petsAllowed
        self.smokingAllowed = smokingAllowed
        self.partyEventsAllowed = partyEventsAllowed
        self.additionalRules = additionalRules
    }
}

public struct CancellationPolicy: Codable, Equatable {
    public let type: CancellationType
    public let refundableUntil: Date?
    public let penaltyAmount: Decimal?
    public let description: String
    
    public init(
        type: CancellationType,
        refundableUntil: Date? = nil,
        penaltyAmount: Decimal? = nil,
        description: String
    ) {
        self.type = type
        self.refundableUntil = refundableUntil
        self.penaltyAmount = penaltyAmount
        self.description = description
    }
}

public enum CancellationType: String, Codable {
    case flexible = "FLEXIBLE"
    case moderate = "MODERATE"
    case strict = "STRICT"
    case nonRefundable = "NON_REFUNDABLE"
}

public struct PriceRange: Codable, Equatable {
    public let min: Decimal
    public let max: Decimal
    public let currency: String
    
    public init(min: Decimal, max: Decimal, currency: String) {
        self.min = min
        self.max = max
        self.currency = currency
    }
}

public struct ProviderReference: Codable, Equatable {
    public let provider: String
    public let providerPropertyId: String
    public let deepLink: String?
    public let terms: String?
    
    public init(
        provider: String,
        providerPropertyId: String,
        deepLink: String? = nil,
        terms: String? = nil
    ) {
        self.provider = provider
        self.providerPropertyId = providerPropertyId
        self.deepLink = deepLink
        self.terms = terms
    }
}

// MARK: - CLLocationCoordinate2D Codable Extension
extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}