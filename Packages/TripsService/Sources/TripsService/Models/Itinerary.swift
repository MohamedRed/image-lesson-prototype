import Foundation

// MARK: - Itinerary Models

/// Complete trip itinerary with days and segments
public struct Itinerary: Codable, Hashable {
    public let id: String
    public var days: [ItineraryDay]
    public var segments: [Segment]
    public var alternativeOptions: [String: [Segment]] // segmentId -> alternatives
    public var optimizationScore: OptimizationScore?
    public let generatedAt: Date
    public var lastModifiedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        days: [ItineraryDay] = [],
        segments: [Segment] = [],
        alternativeOptions: [String: [Segment]] = [:],
        optimizationScore: OptimizationScore? = nil,
        generatedAt: Date = Date(),
        lastModifiedAt: Date = Date()
    ) {
        self.id = id
        self.days = days
        self.segments = segments
        self.alternativeOptions = alternativeOptions
        self.optimizationScore = optimizationScore
        self.generatedAt = generatedAt
        self.lastModifiedAt = lastModifiedAt
    }
}

/// A single day in the itinerary
public struct ItineraryDay: Codable, Hashable, Identifiable {
    public let id: String
    public let dayNumber: Int
    public let date: Date
    public var title: String
    public var segments: [String] // Segment IDs in chronological order
    public var notes: String?
    public var weather: WeatherInfo?
    public var accommodation: String? // Booking ID
    
    public init(
        id: String = UUID().uuidString,
        dayNumber: Int,
        date: Date,
        title: String,
        segments: [String] = [],
        notes: String? = nil,
        weather: WeatherInfo? = nil,
        accommodation: String? = nil
    ) {
        self.id = id
        self.dayNumber = dayNumber
        self.date = date
        self.title = title
        self.segments = segments
        self.notes = notes
        self.weather = weather
        self.accommodation = accommodation
    }
}

/// A segment of the itinerary (flight, activity, meal, etc.)
public struct Segment: Codable, Hashable, Identifiable {
    public let id: String
    public let type: SegmentType
    public var title: String
    public var description: String?
    public var timeWindow: DateInterval
    public var location: Location
    public var content: SegmentContent
    public var cost: Money?
    public var bookingRef: String?
    public var mediaRefs: [String]
    public var notes: String?
    public var safety: SafetyInfo?
    public var status: SegmentStatus
    public var metadata: SegmentMetadata
    
    public init(
        id: String = UUID().uuidString,
        type: SegmentType,
        title: String,
        description: String? = nil,
        timeWindow: DateInterval,
        location: Location,
        content: SegmentContent,
        cost: Money? = nil,
        bookingRef: String? = nil,
        mediaRefs: [String] = [],
        notes: String? = nil,
        safety: SafetyInfo? = nil,
        status: SegmentStatus = .planned,
        metadata: SegmentMetadata = SegmentMetadata()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.timeWindow = timeWindow
        self.location = location
        self.content = content
        self.cost = cost
        self.bookingRef = bookingRef
        self.mediaRefs = mediaRefs
        self.notes = notes
        self.safety = safety
        self.status = status
        self.metadata = metadata
    }
}

/// Type of segment
public enum SegmentType: String, Codable, CaseIterable {
    case flight
    case hotel
    case transport  // Local transport, transfers
    case activity
    case meal
    case rest
    case shopping
    case checkin    // Hotel check-in/out
    case customs    // Immigration, customs
}

/// Segment content details
public enum SegmentContent: Codable, Hashable {
    case flight(FlightInfo)
    case hotel(HotelInfo)
    case transport(TransportInfo)
    case activity(ActivityInfo)
    case meal(MealInfo)
    case rest(RestInfo)
    case shopping(ShoppingInfo)
    case checkin(CheckinInfo)
    case customs(CustomsInfo)
    
    private enum CodingKeys: String, CodingKey {
        case type, content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "flight":
            let info = try container.decode(FlightInfo.self, forKey: .content)
            self = .flight(info)
        case "hotel":
            let info = try container.decode(HotelInfo.self, forKey: .content)
            self = .hotel(info)
        case "transport":
            let info = try container.decode(TransportInfo.self, forKey: .content)
            self = .transport(info)
        case "activity":
            let info = try container.decode(ActivityInfo.self, forKey: .content)
            self = .activity(info)
        case "meal":
            let info = try container.decode(MealInfo.self, forKey: .content)
            self = .meal(info)
        case "rest":
            let info = try container.decode(RestInfo.self, forKey: .content)
            self = .rest(info)
        case "shopping":
            let info = try container.decode(ShoppingInfo.self, forKey: .content)
            self = .shopping(info)
        case "checkin":
            let info = try container.decode(CheckinInfo.self, forKey: .content)
            self = .checkin(info)
        case "customs":
            let info = try container.decode(CustomsInfo.self, forKey: .content)
            self = .customs(info)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown segment type")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .flight(let info):
            try container.encode("flight", forKey: .type)
            try container.encode(info, forKey: .content)
        case .hotel(let info):
            try container.encode("hotel", forKey: .type)
            try container.encode(info, forKey: .content)
        case .transport(let info):
            try container.encode("transport", forKey: .type)
            try container.encode(info, forKey: .content)
        case .activity(let info):
            try container.encode("activity", forKey: .type)
            try container.encode(info, forKey: .content)
        case .meal(let info):
            try container.encode("meal", forKey: .type)
            try container.encode(info, forKey: .content)
        case .rest(let info):
            try container.encode("rest", forKey: .type)
            try container.encode(info, forKey: .content)
        case .shopping(let info):
            try container.encode("shopping", forKey: .type)
            try container.encode(info, forKey: .content)
        case .checkin(let info):
            try container.encode("checkin", forKey: .type)
            try container.encode(info, forKey: .content)
        case .customs(let info):
            try container.encode("customs", forKey: .type)
            try container.encode(info, forKey: .content)
        }
    }
}

/// Flight information
public struct FlightInfo: Codable, Hashable {
    public let airline: String
    public let flightNumber: String
    public let departure: Airport
    public let arrival: Airport
    public let departureTime: Date
    public let arrivalTime: Date
    public let duration: TimeInterval
    public let bookingClass: String?
    public let seatNumbers: [String]?
    public let baggageAllowance: String?
    
    public init(
        airline: String,
        flightNumber: String,
        departure: Airport,
        arrival: Airport,
        departureTime: Date,
        arrivalTime: Date,
        duration: TimeInterval,
        bookingClass: String? = nil,
        seatNumbers: [String]? = nil,
        baggageAllowance: String? = nil
    ) {
        self.airline = airline
        self.flightNumber = flightNumber
        self.departure = departure
        self.arrival = arrival
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.duration = duration
        self.bookingClass = bookingClass
        self.seatNumbers = seatNumbers
        self.baggageAllowance = baggageAllowance
    }
}

/// Airport information
public struct Airport: Codable, Hashable {
    public let code: String // IATA code
    public let name: String
    public let city: String
    public let country: String
    public let terminal: String?
    
    public init(code: String, name: String, city: String, country: String, terminal: String? = nil) {
        self.code = code
        self.name = name
        self.city = city
        self.country = country
        self.terminal = terminal
    }
}

/// Hotel information
public struct HotelInfo: Codable, Hashable {
    public let name: String
    public let address: String
    public let checkInTime: Date
    public let checkOutTime: Date
    public let confirmationNumber: String?
    public let roomType: String?
    public let amenities: [String]
    public let contactInfo: ContactInfo?
    
    public init(
        name: String,
        address: String,
        checkInTime: Date,
        checkOutTime: Date,
        confirmationNumber: String? = nil,
        roomType: String? = nil,
        amenities: [String] = [],
        contactInfo: ContactInfo? = nil
    ) {
        self.name = name
        self.address = address
        self.checkInTime = checkInTime
        self.checkOutTime = checkOutTime
        self.confirmationNumber = confirmationNumber
        self.roomType = roomType
        self.amenities = amenities
        self.contactInfo = contactInfo
    }
}

/// Transport information
public struct TransportInfo: Codable, Hashable {
    public let type: TransportType
    public let provider: String?
    public let vehicleInfo: String?
    public let pickupLocation: String
    public let dropoffLocation: String
    public let pickupTime: Date
    public let estimatedDuration: TimeInterval
    public let confirmationNumber: String?
    
    public init(
        type: TransportType,
        provider: String? = nil,
        vehicleInfo: String? = nil,
        pickupLocation: String,
        dropoffLocation: String,
        pickupTime: Date,
        estimatedDuration: TimeInterval,
        confirmationNumber: String? = nil
    ) {
        self.type = type
        self.provider = provider
        self.vehicleInfo = vehicleInfo
        self.pickupLocation = pickupLocation
        self.dropoffLocation = dropoffLocation
        self.pickupTime = pickupTime
        self.estimatedDuration = estimatedDuration
        self.confirmationNumber = confirmationNumber
    }
}

/// Transport type
public enum TransportType: String, Codable, CaseIterable {
    case taxi
    case rideshare
    case bus
    case train
    case subway
    case ferry
    case rental
    case privateHire = "private"
    case walk
}

/// Activity information
public struct ActivityInfo: Codable, Hashable {
    public let name: String
    public let type: ActivityType
    public let venue: String?
    public let address: String
    public let duration: TimeInterval
    public let ticketRequired: Bool
    public let ticketInfo: String?
    public let guideInfo: String?
    public let difficulty: ActivityDifficulty?
    
    public init(
        name: String,
        type: ActivityType,
        venue: String? = nil,
        address: String,
        duration: TimeInterval,
        ticketRequired: Bool = false,
        ticketInfo: String? = nil,
        guideInfo: String? = nil,
        difficulty: ActivityDifficulty? = nil
    ) {
        self.name = name
        self.type = type
        self.venue = venue
        self.address = address
        self.duration = duration
        self.ticketRequired = ticketRequired
        self.ticketInfo = ticketInfo
        self.guideInfo = guideInfo
        self.difficulty = difficulty
    }
}

/// Activity difficulty
public enum ActivityDifficulty: String, Codable, CaseIterable {
    case easy
    case moderate
    case challenging
    case extreme
}

/// Meal information
public struct MealInfo: Codable, Hashable {
    public let restaurant: String
    public let cuisine: String
    public let address: String
    public let reservationTime: Date?
    public let reservationName: String?
    public let dietaryOptions: [DietaryRestriction]
    public let priceRange: PriceRange?
    
    public init(
        restaurant: String,
        cuisine: String,
        address: String,
        reservationTime: Date? = nil,
        reservationName: String? = nil,
        dietaryOptions: [DietaryRestriction] = [],
        priceRange: PriceRange? = nil
    ) {
        self.restaurant = restaurant
        self.cuisine = cuisine
        self.address = address
        self.reservationTime = reservationTime
        self.reservationName = reservationName
        self.dietaryOptions = dietaryOptions
        self.priceRange = priceRange
    }
}

/// Price range
public enum PriceRange: String, Codable, CaseIterable {
    case budget = "$"
    case moderate = "$$"
    case expensive = "$$$"
    case luxury = "$$$$"
}

/// Rest information
public struct RestInfo: Codable, Hashable {
    public let location: String
    public let purpose: String
    public let duration: TimeInterval
    
    public init(location: String, purpose: String, duration: TimeInterval) {
        self.location = location
        self.purpose = purpose
        self.duration = duration
    }
}

/// Shopping information
public struct ShoppingInfo: Codable, Hashable {
    public let venue: String
    public let type: ShoppingType
    public let address: String
    public let recommendedItems: [String]
    
    public init(venue: String, type: ShoppingType, address: String, recommendedItems: [String] = []) {
        self.venue = venue
        self.type = type
        self.address = address
        self.recommendedItems = recommendedItems
    }
}

/// Shopping type
public enum ShoppingType: String, Codable, CaseIterable {
    case market
    case mall
    case boutique
    case souvenirs
    case groceries
    case duty_free
}

/// Check-in information
public struct CheckinInfo: Codable, Hashable {
    public let type: CheckinType
    public let location: String
    public let time: Date
    public let confirmationNumber: String?
    public let documents: [String]
    
    public init(
        type: CheckinType,
        location: String,
        time: Date,
        confirmationNumber: String? = nil,
        documents: [String] = []
    ) {
        self.type = type
        self.location = location
        self.time = time
        self.confirmationNumber = confirmationNumber
        self.documents = documents
    }
}

/// Check-in type
public enum CheckinType: String, Codable, CaseIterable {
    case hotel_checkin
    case hotel_checkout
    case flight_checkin
}

/// Customs information
public struct CustomsInfo: Codable, Hashable {
    public let type: CustomsType
    public let location: String
    public let estimatedDuration: TimeInterval
    public let documents: [String]
    
    public init(
        type: CustomsType,
        location: String,
        estimatedDuration: TimeInterval,
        documents: [String] = []
    ) {
        self.type = type
        self.location = location
        self.estimatedDuration = estimatedDuration
        self.documents = documents
    }
}

/// Customs type
public enum CustomsType: String, Codable, CaseIterable {
    case immigration
    case customs
    case security
}

/// Segment status
public enum SegmentStatus: String, Codable, CaseIterable {
    case planned
    case booked
    case confirmed
    case inProgress
    case completed
    case cancelled
    case disrupted
}

/// Segment metadata
public struct SegmentMetadata: Codable, Hashable {
    public var isHighlight: Bool
    public var photogenic: Bool
    public var familyFriendly: Bool
    public var accessibilityRating: Int? // 1-5
    public var crowdLevel: CrowdLevel?
    public var tags: [String]
    
    public init(
        isHighlight: Bool = false,
        photogenic: Bool = false,
        familyFriendly: Bool = true,
        accessibilityRating: Int? = nil,
        crowdLevel: CrowdLevel? = nil,
        tags: [String] = []
    ) {
        self.isHighlight = isHighlight
        self.photogenic = photogenic
        self.familyFriendly = familyFriendly
        self.accessibilityRating = accessibilityRating
        self.crowdLevel = crowdLevel
        self.tags = tags
    }
}

/// Crowd level
public enum CrowdLevel: String, Codable, CaseIterable {
    case low
    case moderate
    case high
    case extreme
}

/// Location information
public struct Location: Codable, Hashable {
    public let name: String
    public let address: String?
    public let coordinates: Coordinates?
    public let timezone: String?
    public let mapURL: String?
    
    public init(
        name: String,
        address: String? = nil,
        coordinates: Coordinates? = nil,
        timezone: String? = nil,
        mapURL: String? = nil
    ) {
        self.name = name
        self.address = address
        self.coordinates = coordinates
        self.timezone = timezone
        self.mapURL = mapURL
    }
}

/// GPS coordinates
public struct Coordinates: Codable, Hashable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Weather information
public struct WeatherInfo: Codable, Hashable {
    public let temperature: Temperature
    public let condition: WeatherCondition
    public let precipitation: Int // Percentage
    public let humidity: Int // Percentage
    public let windSpeed: Int // km/h
    
    public init(
        temperature: Temperature,
        condition: WeatherCondition,
        precipitation: Int,
        humidity: Int,
        windSpeed: Int
    ) {
        self.temperature = temperature
        self.condition = condition
        self.precipitation = precipitation
        self.humidity = humidity
        self.windSpeed = windSpeed
    }
}

/// Temperature range
public struct Temperature: Codable, Hashable {
    public let min: Int
    public let max: Int
    public let unit: TemperatureUnit
    
    public init(min: Int, max: Int, unit: TemperatureUnit = .celsius) {
        self.min = min
        self.max = max
        self.unit = unit
    }
}

/// Temperature unit
public enum TemperatureUnit: String, Codable, CaseIterable {
    case celsius
    case fahrenheit
}

/// Weather condition
public enum WeatherCondition: String, Codable, CaseIterable {
    case sunny
    case partly_cloudy
    case cloudy
    case rainy
    case stormy
    case snowy
    case windy
    case foggy
}

/// Safety information
public struct SafetyInfo: Codable, Hashable {
    public let riskLevel: RiskLevel
    public let warnings: [String]
    public let emergencyContacts: [ContactInfo]
    public let nearestHospital: String?
    public let nearestPolice: String?
    
    public init(
        riskLevel: RiskLevel,
        warnings: [String] = [],
        emergencyContacts: [ContactInfo] = [],
        nearestHospital: String? = nil,
        nearestPolice: String? = nil
    ) {
        self.riskLevel = riskLevel
        self.warnings = warnings
        self.emergencyContacts = emergencyContacts
        self.nearestHospital = nearestHospital
        self.nearestPolice = nearestPolice
    }
}

/// Risk level
public enum RiskLevel: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case extreme
}

/// Contact information
public struct ContactInfo: Codable, Hashable {
    public let name: String
    public let phone: String?
    public let email: String?
    public let website: String?
    
    public init(
        name: String,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil
    ) {
        self.name = name
        self.phone = phone
        self.email = email
        self.website = website
    }
}

/// Optimization score for the itinerary
public struct OptimizationScore: Codable, Hashable {
    public let overall: Double // 0-100
    public let cost: Double
    public let time: Double
    public let variety: Double
    public let safety: Double
    public let accessibility: Double
    public let explanation: String
    
    public init(
        overall: Double,
        cost: Double,
        time: Double,
        variety: Double,
        safety: Double,
        accessibility: Double,
        explanation: String
    ) {
        self.overall = overall
        self.cost = cost
        self.time = time
        self.variety = variety
        self.safety = safety
        self.accessibility = accessibility
        self.explanation = explanation
    }
}