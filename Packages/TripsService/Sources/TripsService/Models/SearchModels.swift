import Foundation

// MARK: - Search & Discovery Models

/// Destination search result
public struct Destination: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let country: String
    public let region: String?
    public let type: DestinationType
    public let description: String
    public let imageURL: String?
    public let climate: ClimateInfo?
    public let popularMonths: [Int]
    public let attractions: [String]
    public let avgCostPerDay: Money?
    public let safetyRating: Double? // 0-5
    public let tags: [String]
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        country: String,
        region: String? = nil,
        type: DestinationType,
        description: String,
        imageURL: String? = nil,
        climate: ClimateInfo? = nil,
        popularMonths: [Int] = [],
        attractions: [String] = [],
        avgCostPerDay: Money? = nil,
        safetyRating: Double? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.region = region
        self.type = type
        self.description = description
        self.imageURL = imageURL
        self.climate = climate
        self.popularMonths = popularMonths
        self.attractions = attractions
        self.avgCostPerDay = avgCostPerDay
        self.safetyRating = safetyRating
        self.tags = tags
    }
}

/// Destination type
public enum DestinationType: String, Codable, CaseIterable {
    case city
    case beach
    case mountain
    case countryside
    case island
    case desert
    case historic
    case modern
}

/// Climate information
public struct ClimateInfo: Codable, Hashable {
    public let type: ClimateType
    public let avgTemperature: [Int] // Monthly averages
    public let rainyMonths: [Int]
    public let bestMonths: [Int]
    
    public init(
        type: ClimateType,
        avgTemperature: [Int],
        rainyMonths: [Int],
        bestMonths: [Int]
    ) {
        self.type = type
        self.avgTemperature = avgTemperature
        self.rainyMonths = rainyMonths
        self.bestMonths = bestMonths
    }
}

/// Climate type
public enum ClimateType: String, Codable, CaseIterable {
    case tropical
    case dry
    case temperate
    case continental
    case polar
    case mediterranean
}

/// Destination search filters
public struct DestinationFilters: Codable {
    public var types: [DestinationType]?
    public var climate: ClimateType?
    public var maxBudgetPerDay: Money?
    public var minSafetyRating: Double?
    public var activities: [ActivityType]?
    public var familyFriendly: Bool?
    public var visaFree: Bool?
    
    public init(
        types: [DestinationType]? = nil,
        climate: ClimateType? = nil,
        maxBudgetPerDay: Money? = nil,
        minSafetyRating: Double? = nil,
        activities: [ActivityType]? = nil,
        familyFriendly: Bool? = nil,
        visaFree: Bool? = nil
    ) {
        self.types = types
        self.climate = climate
        self.maxBudgetPerDay = maxBudgetPerDay
        self.minSafetyRating = minSafetyRating
        self.activities = activities
        self.familyFriendly = familyFriendly
        self.visaFree = visaFree
    }
}

/// Point of Interest
public struct PointOfInterest: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let type: POIType
    public let description: String
    public let location: Location
    public let rating: Double? // 0-5
    public let reviewCount: Int?
    public let priceLevel: PriceRange?
    public let openingHours: OpeningHours?
    public let duration: TimeInterval // Recommended visit duration
    public let ticketPrice: Money?
    public let bookingRequired: Bool
    public let imageURLs: [String]
    public let tags: [String]
    public let accessibility: AccessibilityInfo?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        type: POIType,
        description: String,
        location: Location,
        rating: Double? = nil,
        reviewCount: Int? = nil,
        priceLevel: PriceRange? = nil,
        openingHours: OpeningHours? = nil,
        duration: TimeInterval,
        ticketPrice: Money? = nil,
        bookingRequired: Bool = false,
        imageURLs: [String] = [],
        tags: [String] = [],
        accessibility: AccessibilityInfo? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.location = location
        self.rating = rating
        self.reviewCount = reviewCount
        self.priceLevel = priceLevel
        self.openingHours = openingHours
        self.duration = duration
        self.ticketPrice = ticketPrice
        self.bookingRequired = bookingRequired
        self.imageURLs = imageURLs
        self.tags = tags
        self.accessibility = accessibility
    }
}

/// POI type
public enum POIType: String, Codable, CaseIterable {
    case museum
    case monument
    case park
    case beach
    case restaurant
    case shopping
    case entertainment
    case religious
    case viewpoint
    case market
    case nightlife
    case sports
}

/// Opening hours
public struct OpeningHours: Codable, Hashable {
    public let monday: DayHours?
    public let tuesday: DayHours?
    public let wednesday: DayHours?
    public let thursday: DayHours?
    public let friday: DayHours?
    public let saturday: DayHours?
    public let sunday: DayHours?
    public let holidays: DayHours?
    
    public init(
        monday: DayHours? = nil,
        tuesday: DayHours? = nil,
        wednesday: DayHours? = nil,
        thursday: DayHours? = nil,
        friday: DayHours? = nil,
        saturday: DayHours? = nil,
        sunday: DayHours? = nil,
        holidays: DayHours? = nil
    ) {
        self.monday = monday
        self.tuesday = tuesday
        self.wednesday = wednesday
        self.thursday = thursday
        self.friday = friday
        self.saturday = saturday
        self.sunday = sunday
        self.holidays = holidays
    }
}

/// Hours for a single day
public struct DayHours: Codable, Hashable {
    public let open: String
    public let close: String
    public let breaks: [TimeRange]?
    
    public init(open: String, close: String, breaks: [TimeRange]? = nil) {
        self.open = open
        self.close = close
        self.breaks = breaks
    }
}

/// Time range
public struct TimeRange: Codable, Hashable {
    public let start: String
    public let end: String
    
    public init(start: String, end: String) {
        self.start = start
        self.end = end
    }
}

/// Accessibility information
public struct AccessibilityInfo: Codable, Hashable {
    public let wheelchairAccessible: Bool
    public let audioGuide: Bool
    public let visualAids: Bool
    public let signLanguage: Bool
    public let brailleAvailable: Bool
    public let assistanceAvailable: Bool
    
    public init(
        wheelchairAccessible: Bool = false,
        audioGuide: Bool = false,
        visualAids: Bool = false,
        signLanguage: Bool = false,
        brailleAvailable: Bool = false,
        assistanceAvailable: Bool = false
    ) {
        self.wheelchairAccessible = wheelchairAccessible
        self.audioGuide = audioGuide
        self.visualAids = visualAids
        self.signLanguage = signLanguage
        self.brailleAvailable = brailleAvailable
        self.assistanceAvailable = assistanceAvailable
    }
}

/// Flight search option
public struct FlightOption: Codable, Hashable, Identifiable {
    public let id: String
    public let outbound: FlightLeg
    public let inbound: FlightLeg?
    public let price: Money
    public let bookingClass: String
    public let baggageIncluded: BaggageInfo
    public let changeable: Bool
    public let refundable: Bool
    public let provider: String
    public let deepLink: String?
    
    public init(
        id: String = UUID().uuidString,
        outbound: FlightLeg,
        inbound: FlightLeg? = nil,
        price: Money,
        bookingClass: String,
        baggageIncluded: BaggageInfo,
        changeable: Bool,
        refundable: Bool,
        provider: String,
        deepLink: String? = nil
    ) {
        self.id = id
        self.outbound = outbound
        self.inbound = inbound
        self.price = price
        self.bookingClass = bookingClass
        self.baggageIncluded = baggageIncluded
        self.changeable = changeable
        self.refundable = refundable
        self.provider = provider
        self.deepLink = deepLink
    }
}

/// Flight leg (one direction)
public struct FlightLeg: Codable, Hashable {
    public let segments: [FlightSegment]
    public let totalDuration: TimeInterval
    public let stops: Int
    
    public init(segments: [FlightSegment], totalDuration: TimeInterval, stops: Int) {
        self.segments = segments
        self.totalDuration = totalDuration
        self.stops = stops
    }
}

/// Flight segment (single flight)
public struct FlightSegment: Codable, Hashable {
    public let airline: String
    public let flightNumber: String
    public let departure: Airport
    public let arrival: Airport
    public let departureTime: Date
    public let arrivalTime: Date
    public let duration: TimeInterval
    public let aircraft: String?
    
    public init(
        airline: String,
        flightNumber: String,
        departure: Airport,
        arrival: Airport,
        departureTime: Date,
        arrivalTime: Date,
        duration: TimeInterval,
        aircraft: String? = nil
    ) {
        self.airline = airline
        self.flightNumber = flightNumber
        self.departure = departure
        self.arrival = arrival
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.duration = duration
        self.aircraft = aircraft
    }
}

/// Baggage information
public struct BaggageInfo: Codable, Hashable {
    public let carry: Int
    public let checked: Int
    public let weight: Int // kg
    
    public init(carry: Int, checked: Int, weight: Int) {
        self.carry = carry
        self.checked = checked
        self.weight = weight
    }
}

/// Hotel search option
public struct HotelOption: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let address: String
    public let location: Location
    public let starRating: Int
    public let guestRating: Double?
    public let reviewCount: Int?
    public let roomTypes: [RoomType]
    public let amenities: [String]
    public let images: [String]
    public let cancellationPolicy: String
    public let provider: String
    public let deepLink: String?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        address: String,
        location: Location,
        starRating: Int,
        guestRating: Double? = nil,
        reviewCount: Int? = nil,
        roomTypes: [RoomType],
        amenities: [String],
        images: [String],
        cancellationPolicy: String,
        provider: String,
        deepLink: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.location = location
        self.starRating = starRating
        self.guestRating = guestRating
        self.reviewCount = reviewCount
        self.roomTypes = roomTypes
        self.amenities = amenities
        self.images = images
        self.cancellationPolicy = cancellationPolicy
        self.provider = provider
        self.deepLink = deepLink
    }
}

/// Room type
public struct RoomType: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let maxOccupancy: Int
    public let bedConfiguration: String
    public let size: Int? // Square meters
    public let price: Money
    public let breakfast: Bool
    public let available: Int
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        maxOccupancy: Int,
        bedConfiguration: String,
        size: Int? = nil,
        price: Money,
        breakfast: Bool,
        available: Int
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.maxOccupancy = maxOccupancy
        self.bedConfiguration = bedConfiguration
        self.size = size
        self.price = price
        self.breakfast = breakfast
        self.available = available
    }
}

/// Availability calendar
public struct AvailabilityCalendar: Codable, Hashable {
    public let type: AvailabilityType
    public let location: String
    public let month: Date
    public let days: [DayAvailability]
    
    public init(
        type: AvailabilityType,
        location: String,
        month: Date,
        days: [DayAvailability]
    ) {
        self.type = type
        self.location = location
        self.month = month
        self.days = days
    }
}

/// Availability type
public enum AvailabilityType: String, Codable, CaseIterable {
    case flight
    case hotel
    case activity
}

/// Day availability
public struct DayAvailability: Codable, Hashable {
    public let date: Date
    public let available: Bool
    public let price: Money?
    public let remaining: Int?
    
    public init(
        date: Date,
        available: Bool,
        price: Money? = nil,
        remaining: Int? = nil
    ) {
        self.date = date
        self.available = available
        self.price = price
        self.remaining = remaining
    }
}