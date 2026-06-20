import Foundation

// MARK: - Shortlist Model

public struct Shortlist: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var description: String
    public var propertyIds: [String]
    public let userId: String
    public let createdAt: Date
    public var updatedAt: Date
    public var isPrivate: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        propertyIds: [String] = [],
        userId: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPrivate: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.propertyIds = propertyIds
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPrivate = isPrivate
    }
}

// MARK: - Saved Property Filter

public struct SavedPropertiesFilter: Codable {
    public let priceRange: ClosedRange<Double>?
    public let propertyTypes: Set<AccommodationType>
    public let minimumRating: Double
    public let sortBy: SortOption
    
    public enum SortOption: String, CaseIterable, Codable {
        case dateAdded = "date_added"
        case priceAscending = "price_asc"
        case priceDescending = "price_desc"
        case rating = "rating"
        case alphabetical = "alphabetical"
        
        public var title: String {
            switch self {
            case .dateAdded: return "Date Added"
            case .priceAscending: return "Price: Low to High"
            case .priceDescending: return "Price: High to Low"
            case .rating: return "Rating"
            case .alphabetical: return "Alphabetical"
            }
        }
    }
    
    public init(
        priceRange: ClosedRange<Double>? = nil,
        propertyTypes: Set<AccommodationType> = [],
        minimumRating: Double = 0,
        sortBy: SortOption = .dateAdded
    ) {
        self.priceRange = priceRange
        self.propertyTypes = propertyTypes
        self.minimumRating = minimumRating
        self.sortBy = sortBy
    }
}

// MARK: - Favorite Property

public struct FavoriteProperty: Identifiable, Codable {
    public let id: String
    public let propertyId: String
    public let userId: String
    public let addedAt: Date
    public var notes: String?
    
    public init(
        id: String = UUID().uuidString,
        propertyId: String,
        userId: String,
        addedAt: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.propertyId = propertyId
        self.userId = userId
        self.addedAt = addedAt
        self.notes = notes
    }
}

// MARK: - Recently Viewed Property

public struct RecentlyViewedProperty: Identifiable, Codable {
    public let id: String
    public let propertyId: String
    public let userId: String
    public let viewedAt: Date
    public var viewCount: Int
    
    public init(
        id: String = UUID().uuidString,
        propertyId: String,
        userId: String,
        viewedAt: Date = Date(),
        viewCount: Int = 1
    ) {
        self.id = id
        self.propertyId = propertyId
        self.userId = userId
        self.viewedAt = viewedAt
        self.viewCount = viewCount
    }
}

// MARK: - Saved Properties Response

public struct SavedPropertiesResponse: Codable {
    public let favorites: [AccommodationProperty]
    public let shortlists: [Shortlist]
    public let recentlyViewed: [AccommodationProperty]
    
    public init(
        favorites: [AccommodationProperty],
        shortlists: [Shortlist],
        recentlyViewed: [AccommodationProperty]
    ) {
        self.favorites = favorites
        self.shortlists = shortlists
        self.recentlyViewed = recentlyViewed
    }
}

// MARK: - Shortlist Update Request

public struct ShortlistUpdateRequest: Codable {
    public let name: String?
    public let description: String?
    public let propertyIds: [String]?
    public let isPrivate: Bool?
    
    public init(
        name: String? = nil,
        description: String? = nil,
        propertyIds: [String]? = nil,
        isPrivate: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.propertyIds = propertyIds
        self.isPrivate = isPrivate
    }
}