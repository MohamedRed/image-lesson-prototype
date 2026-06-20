import Foundation
import CoreLocation

// MARK: - Search Request
public struct SearchRequest: Codable {
    public let location: SearchLocation
    public let dateRange: DateRange
    public let guests: GuestConfiguration
    public let filters: SearchFilters?
    public let sortBy: SortOption?
    public let pageToken: String?
    
    public init(
        location: SearchLocation,
        dateRange: DateRange,
        guests: GuestConfiguration,
        filters: SearchFilters? = nil,
        sortBy: SortOption? = nil,
        pageToken: String? = nil
    ) {
        self.location = location
        self.dateRange = dateRange
        self.guests = guests
        self.filters = filters
        self.sortBy = sortBy
        self.pageToken = pageToken
    }
}

public enum SearchLocation: Codable {
    case coordinates(lat: Double, lng: Double)
    case placeId(String)
    case address(String)
    
    private enum CodingKeys: String, CodingKey {
        case type
        case lat
        case lng
        case placeId
        case address
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "coordinates":
            let lat = try container.decode(Double.self, forKey: .lat)
            let lng = try container.decode(Double.self, forKey: .lng)
            self = .coordinates(lat: lat, lng: lng)
        case "placeId":
            let placeId = try container.decode(String.self, forKey: .placeId)
            self = .placeId(placeId)
        case "address":
            let address = try container.decode(String.self, forKey: .address)
            self = .address(address)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid location type")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .coordinates(let lat, let lng):
            try container.encode("coordinates", forKey: .type)
            try container.encode(lat, forKey: .lat)
            try container.encode(lng, forKey: .lng)
        case .placeId(let placeId):
            try container.encode("placeId", forKey: .type)
            try container.encode(placeId, forKey: .placeId)
        case .address(let address):
            try container.encode("address", forKey: .type)
            try container.encode(address, forKey: .address)
        }
    }
}

public struct GuestConfiguration: Codable, Equatable {
    public let rooms: Int
    public let adults: Int
    public let children: Int
    public let childrenAges: [Int]
    
    public init(rooms: Int = 1, adults: Int, children: Int = 0, childrenAges: [Int] = []) {
        self.rooms = rooms
        self.adults = adults
        self.children = children
        self.childrenAges = childrenAges
    }
}

public struct SearchFilters: Codable, Equatable {
    public let budgetMin: Decimal?
    public let budgetMax: Decimal?
    public let rating: Double?
    public let amenities: [String]?
    public let types: [AccommodationType]?
    public let cancellable: Bool?
    public let accessibilityNeeds: [String]?
    public let brands: [String]?
    public let mealPlans: [MealPlan]?
    
    public init(
        budgetMin: Decimal? = nil,
        budgetMax: Decimal? = nil,
        rating: Double? = nil,
        amenities: [String]? = nil,
        types: [AccommodationType]? = nil,
        cancellable: Bool? = nil,
        accessibilityNeeds: [String]? = nil,
        brands: [String]? = nil,
        mealPlans: [MealPlan]? = nil
    ) {
        self.budgetMin = budgetMin
        self.budgetMax = budgetMax
        self.rating = rating
        self.amenities = amenities
        self.types = types
        self.cancellable = cancellable
        self.accessibilityNeeds = accessibilityNeeds
        self.brands = brands
        self.mealPlans = mealPlans
    }
}

public enum SortOption: String, Codable, CaseIterable {
    case relevance = "RELEVANCE"
    case priceAsc = "PRICE_ASC"
    case priceDesc = "PRICE_DESC"
    case rating = "RATING"
    case distance = "DISTANCE"
    case popularity = "POPULARITY"
    
    public var displayName: String {
        switch self {
        case .relevance: return "Best Match"
        case .priceAsc: return "Price: Low to High"
        case .priceDesc: return "Price: High to Low"
        case .rating: return "Rating"
        case .distance: return "Distance"
        case .popularity: return "Popularity"
        }
    }
}

// MARK: - Search Response
public struct SearchResponse: Codable {
    public let properties: [AccommodationProperty]
    public let availability: [String: AvailabilitySummary]
    public let totalResults: Int
    public let pageToken: String?
    public let searchId: String
    public let cacheMetadata: CacheMetadata?
    
    public init(
        properties: [AccommodationProperty],
        availability: [String: AvailabilitySummary],
        totalResults: Int,
        pageToken: String? = nil,
        searchId: String,
        cacheMetadata: CacheMetadata? = nil
    ) {
        self.properties = properties
        self.availability = availability
        self.totalResults = totalResults
        self.pageToken = pageToken
        self.searchId = searchId
        self.cacheMetadata = cacheMetadata
    }
}

public struct AvailabilitySummary: Codable, Equatable {
    public let propertyId: String
    public let isAvailable: Bool
    public let lowestPrice: Decimal?
    public let currency: String?
    public let roomsAvailable: Int?
    
    public init(
        propertyId: String,
        isAvailable: Bool,
        lowestPrice: Decimal? = nil,
        currency: String? = nil,
        roomsAvailable: Int? = nil
    ) {
        self.propertyId = propertyId
        self.isAvailable = isAvailable
        self.lowestPrice = lowestPrice
        self.currency = currency
        self.roomsAvailable = roomsAvailable
    }
}

public struct CacheMetadata: Codable, Equatable {
    public let cached: Bool
    public let cacheAge: TimeInterval?
    public let ttl: TimeInterval?
    
    public init(cached: Bool, cacheAge: TimeInterval? = nil, ttl: TimeInterval? = nil) {
        self.cached = cached
        self.cacheAge = cacheAge
        self.ttl = ttl
    }
}

// MARK: - Recommendations
public struct RecommendationRequest: Codable {
    public let userId: String?
    public let sessionId: String?
    public let context: RecommendationContext
    public let limit: Int?
    
    public init(
        userId: String? = nil,
        sessionId: String? = nil,
        context: RecommendationContext,
        limit: Int? = nil
    ) {
        self.userId = userId
        self.sessionId = sessionId
        self.context = context
        self.limit = limit
    }
}

public struct RecommendationContext: Codable {
    public let tripId: String?
    public let location: SearchLocation?
    public let dateRange: DateRange?
    public let budget: Budget?
    public let preferences: UserPreferences?
    
    public init(
        tripId: String? = nil,
        location: SearchLocation? = nil,
        dateRange: DateRange? = nil,
        budget: Budget? = nil,
        preferences: UserPreferences? = nil
    ) {
        self.tripId = tripId
        self.location = location
        self.dateRange = dateRange
        self.budget = budget
        self.preferences = preferences
    }
}

public struct Budget: Codable, Equatable {
    public let min: Decimal
    public let max: Decimal
    public let currency: String
    
    public init(min: Decimal, max: Decimal, currency: String) {
        self.min = min
        self.max = max
        self.currency = currency
    }
}

public struct UserPreferences: Codable, Equatable {
    public let favoriteTypes: [AccommodationType]?
    public let favoriteAmenities: [String]?
    public let favoriteBrands: [String]?
    public let accessibilityNeeds: [String]?
    
    public init(
        favoriteTypes: [AccommodationType]? = nil,
        favoriteAmenities: [String]? = nil,
        favoriteBrands: [String]? = nil,
        accessibilityNeeds: [String]? = nil
    ) {
        self.favoriteTypes = favoriteTypes
        self.favoriteAmenities = favoriteAmenities
        self.favoriteBrands = favoriteBrands
        self.accessibilityNeeds = accessibilityNeeds
    }
}

public struct RecommendationResponse: Codable {
    public let recommendations: [RecommendedProperty]
    public let explanations: [String: String]
    
    public init(
        recommendations: [RecommendedProperty],
        explanations: [String: String] = [:]
    ) {
        self.recommendations = recommendations
        self.explanations = explanations
    }
}

public struct RecommendedProperty: Codable {
    public let property: AccommodationProperty
    public let score: Double
    public let explanation: String
    public let matchReasons: [String]
    
    public init(
        property: AccommodationProperty,
        score: Double,
        explanation: String,
        matchReasons: [String] = []
    ) {
        self.property = property
        self.score = score
        self.explanation = explanation
        self.matchReasons = matchReasons
    }
}