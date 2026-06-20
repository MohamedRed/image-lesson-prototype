import Foundation

// MARK: - Core Trip Models

/// Main trip entity representing a complete travel plan
public struct Trip: Identifiable, Codable, Hashable {
    public let id: String
    public let ownerId: String
    public var members: [TripMember]
    public var title: String
    public var description: String?
    public var scope: TripScope
    public var duration: TripDuration
    public var startWindow: DateInterval?
    public var constraints: TripConstraints
    public var status: TripStatus
    public var itinerary: Itinerary?
    public var bookings: [Booking]
    public var compliancePack: CompliancePack?
    public var budgetPlan: BudgetPlan?
    public var mediaRefs: [String]
    public var metadata: TripMetadata
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        ownerId: String,
        members: [TripMember] = [],
        title: String,
        description: String? = nil,
        scope: TripScope,
        duration: TripDuration,
        startWindow: DateInterval? = nil,
        constraints: TripConstraints,
        status: TripStatus = .draft,
        itinerary: Itinerary? = nil,
        bookings: [Booking] = [],
        compliancePack: CompliancePack? = nil,
        budgetPlan: BudgetPlan? = nil,
        mediaRefs: [String] = [],
        metadata: TripMetadata = TripMetadata(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerId = ownerId
        self.members = members
        self.title = title
        self.description = description
        self.scope = scope
        self.duration = duration
        self.startWindow = startWindow
        self.constraints = constraints
        self.status = status
        self.itinerary = itinerary
        self.bookings = bookings
        self.compliancePack = compliancePack
        self.budgetPlan = budgetPlan
        self.mediaRefs = mediaRefs
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Trip member with role and permissions
public struct TripMember: Codable, Hashable {
    public let userId: String
    public let name: String
    public let role: MemberRole
    public let joinedAt: Date
    public var preferences: TravelerPreferences?
    
    public init(userId: String, name: String, role: MemberRole, joinedAt: Date = Date(), preferences: TravelerPreferences? = nil) {
        self.userId = userId
        self.name = name
        self.role = role
        self.joinedAt = joinedAt
        self.preferences = preferences
    }
}

/// Member role in the trip
public enum MemberRole: String, Codable, CaseIterable {
    case owner
    case editor
    case viewer
}

/// Trip scope (geographical extent)
public enum TripScope: String, Codable, CaseIterable {
    case local       // Within city/region
    case domestic    // Within country
    case international // Multiple countries
    case intercontinental // Multiple continents
}

/// Trip duration configuration
public struct TripDuration: Codable, Hashable {
    public let days: Int
    public let nights: Int
    public let isFlexible: Bool
    
    public init(days: Int, nights: Int, isFlexible: Bool = false) {
        self.days = days
        self.nights = nights
        self.isFlexible = isFlexible
    }
}

/// Trip planning constraints
public struct TripConstraints: Codable, Hashable {
    public var budget: BudgetConstraint?
    public var seasons: [Season]
    public var visaRequirements: [String]
    public var accessibility: AccessibilityNeeds
    public var dietary: [DietaryRestriction]
    public var mobility: MobilityLevel
    public var familyFriendly: Bool
    public var petFriendly: Bool
    public var mustInclude: [String] // POI IDs or locations
    public var mustAvoid: [String]
    
    public init(
        budget: BudgetConstraint? = nil,
        seasons: [Season] = [],
        visaRequirements: [String] = [],
        accessibility: AccessibilityNeeds = AccessibilityNeeds(),
        dietary: [DietaryRestriction] = [],
        mobility: MobilityLevel = .normal,
        familyFriendly: Bool = false,
        petFriendly: Bool = false,
        mustInclude: [String] = [],
        mustAvoid: [String] = []
    ) {
        self.budget = budget
        self.seasons = seasons
        self.visaRequirements = visaRequirements
        self.accessibility = accessibility
        self.dietary = dietary
        self.mobility = mobility
        self.familyFriendly = familyFriendly
        self.petFriendly = petFriendly
        self.mustInclude = mustInclude
        self.mustAvoid = mustAvoid
    }
}

/// Budget constraint
public struct BudgetConstraint: Codable, Hashable {
    public let total: Money
    public let perPerson: Bool
    public let flexibility: BudgetFlexibility
    public var allocations: [BudgetCategory: Money]?
    
    public init(total: Money, perPerson: Bool = false, flexibility: BudgetFlexibility = .moderate, allocations: [BudgetCategory: Money]? = nil) {
        self.total = total
        self.perPerson = perPerson
        self.flexibility = flexibility
        self.allocations = allocations
    }
}

/// Budget flexibility level
public enum BudgetFlexibility: String, Codable, CaseIterable {
    case strict     // Cannot exceed
    case moderate   // Up to 10% over
    case flexible   // Up to 25% over
    case luxury     // Budget is a guideline
}

/// Budget categories
public enum BudgetCategory: String, Codable, CaseIterable {
    case flights
    case accommodation
    case transport
    case activities
    case food
    case shopping
    case insurance
    case other
}

/// Seasonal preferences
public enum Season: String, Codable, CaseIterable {
    case spring
    case summer
    case fall
    case winter
    case dry
    case wet
    case shoulder // Off-peak travel times
}

/// Accessibility needs
public struct AccessibilityNeeds: Codable, Hashable {
    public var wheelchairAccessible: Bool
    public var visualAssistance: Bool
    public var hearingAssistance: Bool
    public var cognitiveSupport: Bool
    public var mobilityAids: [String]
    
    public init(
        wheelchairAccessible: Bool = false,
        visualAssistance: Bool = false,
        hearingAssistance: Bool = false,
        cognitiveSupport: Bool = false,
        mobilityAids: [String] = []
    ) {
        self.wheelchairAccessible = wheelchairAccessible
        self.visualAssistance = visualAssistance
        self.hearingAssistance = hearingAssistance
        self.cognitiveSupport = cognitiveSupport
        self.mobilityAids = mobilityAids
    }
}

/// Dietary restrictions
public enum DietaryRestriction: String, Codable, CaseIterable {
    case vegetarian
    case vegan
    case halal
    case kosher
    case glutenFree
    case dairyFree
    case nutAllergy
    case shellfish
    case diabetic
}

/// Mobility level
public enum MobilityLevel: String, Codable, CaseIterable {
    case limited    // Minimal walking, needs assistance
    case moderate   // Some walking okay, needs breaks
    case normal     // Regular activity level
    case active     // Enjoys walking and physical activities
    case athletic   // High physical demands acceptable
}

/// Trip status
public enum TripStatus: String, Codable, CaseIterable {
    case draft      // Being planned
    case planned    // Itinerary complete
    case booked     // Bookings confirmed
    case active     // Trip in progress
    case completed  // Trip finished
    case cancelled  // Trip cancelled
}

/// Trip metadata
public struct TripMetadata: Codable, Hashable {
    public var tags: [String]
    public var theme: TripTheme?
    public var inspirationSources: [String]
    public var plannerVersion: String
    public var lastModifiedBy: String?
    
    public init(
        tags: [String] = [],
        theme: TripTheme? = nil,
        inspirationSources: [String] = [],
        plannerVersion: String = "1.0",
        lastModifiedBy: String? = nil
    ) {
        self.tags = tags
        self.theme = theme
        self.inspirationSources = inspirationSources
        self.plannerVersion = plannerVersion
        self.lastModifiedBy = lastModifiedBy
    }
}

/// Trip theme
public enum TripTheme: String, Codable, CaseIterable {
    case adventure
    case relaxation
    case cultural
    case culinary
    case romantic
    case family
    case business
    case educational
    case wellness
    case photography
    case sports
    case festival
}

/// Traveler preferences
public struct TravelerPreferences: Codable, Hashable {
    public var destinations: [String]
    public var climatePreference: ClimatePreference?
    public var activityTypes: [ActivityType]
    public var accommodationType: AccommodationType
    public var transportPreference: TransportPreference
    public var languages: [String]
    
    public init(
        destinations: [String] = [],
        climatePreference: ClimatePreference? = nil,
        activityTypes: [ActivityType] = [],
        accommodationType: AccommodationType = .hotel,
        transportPreference: TransportPreference = .balanced,
        languages: [String] = []
    ) {
        self.destinations = destinations
        self.climatePreference = climatePreference
        self.activityTypes = activityTypes
        self.accommodationType = accommodationType
        self.transportPreference = transportPreference
        self.languages = languages
    }
}

/// Climate preferences
public enum ClimatePreference: String, Codable, CaseIterable {
    case tropical
    case temperate
    case dry
    case cold
    case mediterranean
}

/// Activity types
public enum ActivityType: String, Codable, CaseIterable {
    case sightseeing
    case adventure
    case beach
    case hiking
    case cultural
    case shopping
    case nightlife
    case culinary
    case wellness
    case sports
    case wildlife
    case photography
}

/// Accommodation type
public enum AccommodationType: String, Codable, CaseIterable {
    case hotel
    case hostel
    case airbnb
    case resort
    case camping
    case luxury
}

/// Transport preference
public enum TransportPreference: String, Codable, CaseIterable {
    case publicTransport
    case rental
    case rideshare
    case walking
    case balanced
}

/// Money representation
public struct Money: Codable, Hashable {
    public let amount: Decimal
    public let currency: String // ISO 4217 code
    
    public init(amount: Decimal, currency: String = "USD") {
        self.amount = amount
        self.currency = currency
    }
    
    public init(amount: Double, currency: String = "USD") {
        self.amount = Decimal(amount)
        self.currency = currency
    }
}