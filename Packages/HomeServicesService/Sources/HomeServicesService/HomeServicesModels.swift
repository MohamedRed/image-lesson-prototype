import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Codable JSON type for arbitrary attributes
public enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
        } else if let dictValue = try? container.decode([String: JSONValue].self) {
            self = .object(dictValue)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - Service Category
public struct ServiceCategory: Codable, Identifiable {
    @DocumentID public var id: String?
    public var name: String
    public var nameAr: String?  // Arabic/Darija name
    public var nameFr: String?  // French name
    public var icon: String
    public var attributesSchema: [String: JSONValue]?
    public var isActive: Bool
    public var displayOrder: Int
    
    public init(id: String? = nil, name: String, nameAr: String? = nil, nameFr: String? = nil, 
                icon: String, attributesSchema: [String: JSONValue]? = nil, 
                isActive: Bool = true, displayOrder: Int = 0) {
        self.id = id
        self.name = name
        self.nameAr = nameAr
        self.nameFr = nameFr
        self.icon = icon
        self.attributesSchema = attributesSchema
        self.isActive = isActive
        self.displayOrder = displayOrder
    }
}

// MARK: - Pro Profile
public struct ProProfile: Codable, Identifiable {
    @DocumentID public var id: String?
    public var userId: String
    public var name: String
    public var skills: [String]
    public var serviceArea: ServiceArea
    public var verificationTier: VerificationTier
    public var rating: Double
    public var jobsCount: Int
    public var badges: [String]
    public var availability: Availability
    public var languages: [String]
    public var phoneNumber: String?
    public var profileImageUrl: String?
    public var experienceYears: Int
    public var emergencyAvailable: Bool
    public var reviewsCount: Int
    public var isVerified: Bool
    public var tier: Tier
    public var portfolio: [PortfolioItem]
    public var businessName: String?
    @ServerTimestamp public var createdAt: Date?
    
    public enum VerificationTier: String, Codable {
        case unverified
        case basic  // ID verified
        case professional  // ID + business docs
        case certified  // Full KYC + certifications
    }
    
    public enum Tier: String, Codable {
        case bronze
        case silver
        case gold
        case platinum
    }
    
    public struct ServiceArea: Codable {
        public var city: String
        public var arrondissements: [String]?
        public var radiusKm: Double?
        public var address: String?
        public var coordinates: Coordinates?
        
        public init(city: String, arrondissements: [String]? = nil, radiusKm: Double? = nil, address: String? = nil, coordinates: Coordinates? = nil) {
            self.city = city
            self.arrondissements = arrondissements
            self.radiusKm = radiusKm
            self.address = address
            self.coordinates = coordinates
        }
        
        public struct Coordinates: Codable {
            public var latitude: Double
            public var longitude: Double
            
            public init(latitude: Double, longitude: Double) {
                self.latitude = latitude
                self.longitude = longitude
            }
        }
    }
    
    public struct Availability: Codable {
        public var daysOfWeek: [String]
        public var timeSlots: [TimeSlot]?
        public var workingHours: WorkingHours?
        public var emergencyAvailable: Bool?
        
        public init(daysOfWeek: [String], timeSlots: [TimeSlot]? = nil, workingHours: WorkingHours? = nil, emergencyAvailable: Bool? = nil) {
            self.daysOfWeek = daysOfWeek
            self.timeSlots = timeSlots
            self.workingHours = workingHours
            self.emergencyAvailable = emergencyAvailable
        }
        
        public struct DaySchedule: Codable {
            public var start: String
            public var end: String
            
            public init(start: String, end: String) {
                self.start = start
                self.end = end
            }
        }
        
        public struct WorkingHours: Codable {
            public var monday: DaySchedule?
            public var tuesday: DaySchedule?
            public var wednesday: DaySchedule?
            public var thursday: DaySchedule?
            public var friday: DaySchedule?
            public var saturday: DaySchedule?
            public var sunday: DaySchedule?
        }
    }
    
    public struct TimeSlot: Codable {
        public var start: String  // "09:00"
        public var end: String    // "17:00"
        
        public init(start: String, end: String) {
            self.start = start
            self.end = end
        }
    }
    
    public struct PortfolioItem: Codable {
        public var title: String?
        public var description: String?
        public var imageUrl: String?
        public var completedAt: Date?
        
        public init(title: String? = nil, description: String? = nil, imageUrl: String? = nil, completedAt: Date? = nil) {
            self.title = title
            self.description = description
            self.imageUrl = imageUrl
            self.completedAt = completedAt
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case name
        case businessName
        case skills
        case serviceArea
        case location
        case verificationTier
        case tier
        case rating
        case jobsCount
        case reviewsCount
        case badges
        case availability
        case languages
        case phoneNumber
        case profileImageUrl
        case experienceYears
        case experience
        case emergencyAvailable
        case isVerified
        case portfolio
        case createdAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.userId = try container.decode(String.self, forKey: .userId)
        // name or businessName
        var decodedName = try container.decodeIfPresent(String.self, forKey: .name)
        if decodedName == nil {
            decodedName = try container.decodeIfPresent(String.self, forKey: .businessName)
        }
        self.name = decodedName ?? ""
        self.businessName = try container.decodeIfPresent(String.self, forKey: .businessName)
        self.skills = try container.decodeIfPresent([String].self, forKey: .skills) ?? []
        // serviceArea or legacy location
        if let area = try container.decodeIfPresent(ServiceArea.self, forKey: .serviceArea) {
            self.serviceArea = area
        } else if let legacyLocation = try container.decodeIfPresent(LegacyLocation.self, forKey: .location) {
            self.serviceArea = ServiceArea(
                city: legacyLocation.city,
                arrondissements: nil,
                radiusKm: nil,
                address: legacyLocation.address,
                coordinates: legacyLocation.coordinates.map { ServiceArea.Coordinates(latitude: $0.latitude, longitude: $0.longitude) }
            )
        } else {
            self.serviceArea = ServiceArea(city: "")
        }
        // verificationTier or legacy flags
        if let vt = try container.decodeIfPresent(VerificationTier.self, forKey: .verificationTier) {
            self.verificationTier = vt
        } else {
            self.verificationTier = .unverified
        }
        self.tier = try container.decodeIfPresent(Tier.self, forKey: .tier) ?? .bronze
        self.isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        self.jobsCount = try container.decodeIfPresent(Int.self, forKey: .jobsCount) ?? 0
        self.reviewsCount = try container.decodeIfPresent(Int.self, forKey: .reviewsCount) ?? 0
        self.badges = try container.decodeIfPresent([String].self, forKey: .badges) ?? []
        self.availability = try container.decodeIfPresent(Availability.self, forKey: .availability) ?? Availability(daysOfWeek: [])
        self.languages = try container.decodeIfPresent([String].self, forKey: .languages) ?? []
        self.phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        self.profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        // experience
        self.experienceYears = try container.decodeIfPresent(Int.self, forKey: .experienceYears)
            ?? container.decodeIfPresent(Int.self, forKey: .experience) ?? 0
        // emergencyAvailable might be top-level; if not, keep what's inside availability
        let topLevelEmergency = try container.decodeIfPresent(Bool.self, forKey: .emergencyAvailable)
        self.emergencyAvailable = topLevelEmergency ?? self.availability.emergencyAvailable ?? false
        self.portfolio = try container.decodeIfPresent([PortfolioItem].self, forKey: .portfolio) ?? []
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(name, forKey: .name)
        try container.encode(skills, forKey: .skills)
        try container.encode(serviceArea, forKey: .serviceArea)
        try container.encode(verificationTier, forKey: .verificationTier)
        try container.encode(rating, forKey: .rating)
        try container.encode(jobsCount, forKey: .jobsCount)
        try container.encode(badges, forKey: .badges)
        try container.encode(availability, forKey: .availability)
        try container.encode(languages, forKey: .languages)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encodeIfPresent(profileImageUrl, forKey: .profileImageUrl)
        try container.encode(experienceYears, forKey: .experienceYears)
        try container.encode(emergencyAvailable, forKey: .emergencyAvailable)
        try container.encode(reviewsCount, forKey: .reviewsCount)
        try container.encode(isVerified, forKey: .isVerified)
        try container.encode(tier, forKey: .tier)
        try container.encodeIfPresent(businessName, forKey: .businessName)
        try container.encode(portfolio, forKey: .portfolio)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
    
    // Designated initializer for constructing profiles in code (e.g., tests/mocks)
    public init(
        id: String? = nil,
        userId: String,
        name: String,
        skills: [String] = [],
        serviceArea: ServiceArea,
        verificationTier: VerificationTier = .unverified,
        rating: Double = 0,
        jobsCount: Int = 0,
        badges: [String] = [],
        availability: Availability = Availability(daysOfWeek: []),
        languages: [String] = [],
        phoneNumber: String? = nil,
        profileImageUrl: String? = nil,
        experienceYears: Int = 0,
        emergencyAvailable: Bool = false,
        reviewsCount: Int = 0,
        isVerified: Bool = false,
        tier: Tier = .bronze,
        portfolio: [PortfolioItem] = [],
        businessName: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.skills = skills
        self.serviceArea = serviceArea
        self.verificationTier = verificationTier
        self.rating = rating
        self.jobsCount = jobsCount
        self.badges = badges
        self.availability = availability
        self.languages = languages
        self.phoneNumber = phoneNumber
        self.profileImageUrl = profileImageUrl
        self.experienceYears = experienceYears
        self.emergencyAvailable = emergencyAvailable
        self.reviewsCount = reviewsCount
        self.isVerified = isVerified
        self.tier = tier
        self.portfolio = portfolio
        self.businessName = businessName
        self.createdAt = createdAt
    }
    
    private struct LegacyLocation: Codable {
        var address: String?
        var city: String
        var coordinates: LegacyCoordinates?
    }
    
    private struct LegacyCoordinates: Codable {
        var latitude: Double
        var longitude: Double
    }
}

// MARK: - RFQ (Request for Quote)
public struct RFQ: Codable, Identifiable {
    @DocumentID public var id: String?
    public var customerId: String
    public var categoryId: String
    public var scope: RFQScope
    public var location: Location
    public var media: [String]
    public var budgetRange: BudgetRange?
    public var siteVisitRequested: Bool
    public var status: RFQStatus
    @ServerTimestamp public var createdAt: Date?
    public var expiresAt: Date?
    
    public enum RFQStatus: String, Codable {
        case draft
        case open
        case awarded
        case cancelled
    }
    
    public struct RFQScope: Codable {
        public var title: String
        public var description: String
        public var attributes: [String: JSONValue]?  // Category-specific attributes
        public var urgency: Urgency
        
        public enum Urgency: String, Codable {
            case asap
            case flexible
            case scheduled
        }
        
        public init(title: String, description: String, attributes: [String: JSONValue]? = nil, urgency: Urgency = .flexible) {
            self.title = title
            self.description = description
            self.attributes = attributes
            self.urgency = urgency
        }
    }
    
    public struct Location: Codable {
        public var lat: Double
        public var lng: Double
        public var city: String
        public var arrondissement: String?
        public var address: String?
        
        public init(lat: Double, lng: Double, city: String, arrondissement: String? = nil, address: String? = nil) {
            self.lat = lat
            self.lng = lng
            self.city = city
            self.arrondissement = arrondissement
            self.address = address
        }
    }
    
    public struct BudgetRange: Codable {
        public var min: Double
        public var max: Double
        public var currency: String = "MAD"
        
        public init(min: Double, max: Double, currency: String = "MAD") {
            self.min = min
            self.max = max
            self.currency = currency
        }
    }
}

// MARK: - Bid
public struct Bid: Codable, Identifiable {
    @DocumentID public var id: String?
    public var rfqId: String
    public var proId: String
    public var proName: String?
    public var amountMAD: Double
    public var timelineDays: Int
    public var includesMaterials: Bool
    public var visitRequired: Bool
    public var message: String?
    public var status: BidStatus
    public var counters: CounterInfo
    public var autoAcceptAbove: Double?
    @ServerTimestamp public var createdAt: Date?
    public var expiresAt: Date?
    
    public enum BidStatus: String, Codable {
        case active
        case countered
        case accepted
        case withdrawn
        case expired
    }
    
    public struct CounterInfo: Codable {
        public var customerCount: Int
        public var proCount: Int
        
        public init(customerCount: Int = 0, proCount: Int = 0) {
            self.customerCount = customerCount
            self.proCount = proCount
        }
    }
}

// MARK: - Contract
public struct Contract: Codable, Identifiable {
    @DocumentID public var id: String?
    public var rfqId: String
    public var customerId: String
    public var proId: String
    public var agreedScope: RFQ.RFQScope
    public var priceMAD: Double
    public var milestones: [Milestone]
    public var startAt: Date?
    public var cancellationPolicy: String?
    public var status: ContractStatus
    @ServerTimestamp public var createdAt: Date?
    
    public enum ContractStatus: String, Codable {
        case pending
        case active
        case completed
        case cancelled
    }
    
    public struct Milestone: Codable, Identifiable {
        public var id: String
        public var description: String
        public var amountMAD: Double
        public var dueDate: Date?
        public var status: MilestoneStatus
        
        public enum MilestoneStatus: String, Codable {
            case pending
            case inProgress
            case completed
            case approved
        }
        
        public init(id: String, description: String, amountMAD: Double, dueDate: Date? = nil, status: MilestoneStatus = .pending) {
            self.id = id
            self.description = description
            self.amountMAD = amountMAD
            self.dueDate = dueDate
            self.status = status
        }
    }
}

// MARK: - Escrow
public struct Escrow: Codable, Identifiable {
    @DocumentID public var id: String?
    public var contractId: String
    public var amounts: [EscrowAmount]
    public var paymentMethod: PaymentMethod
    public var holdbacks: Double?
    public var pspRefs: [String: String]?
    
    public enum PaymentMethod: String, Codable {
        case cash
        case card
        case wallet
    }
    
    public struct EscrowAmount: Codable {
        public var milestoneId: String
        public var amount: Double
        public var status: EscrowStatus
        
        public enum EscrowStatus: String, Codable {
            case pending
            case held
            case released
            case refunded
        }
        
        public init(milestoneId: String, amount: Double, status: EscrowStatus = .pending) {
            self.milestoneId = milestoneId
            self.amount = amount
            self.status = status
        }
    }
}

// MARK: - Review
public struct Review: Codable, Identifiable {
    @DocumentID public var id: String?
    public var contractId: String
    public var fromUserId: String
    public var toUserId: String
    public var rating: Int  // 1-5
    public var text: String?
    public var categoryId: String
    @ServerTimestamp public var createdAt: Date?
}

// MARK: - Dispute
public struct Dispute: Codable, Identifiable {
    @DocumentID public var id: String?
    public var contractId: String
    public var side: DisputeSide
    public var reason: String
    public var evidence: [String]
    public var status: DisputeStatus
    public var resolution: String?
    @ServerTimestamp public var createdAt: Date?
    
    public enum DisputeSide: String, Codable {
        case customer
        case pro
    }
    
    public enum DisputeStatus: String, Codable {
        case open
        case investigating
        case resolved
        case escalated
    }
}

// MARK: - Message
public struct Message: Codable, Identifiable {
    @DocumentID public var id: String?
    public var threadId: String
    public var fromUserId: String
    public var text: String
    public var attachments: [String]
    public var type: MessageType
    public var piiRedactionState: String?
    @ServerTimestamp public var createdAt: Date?
    
    public enum MessageType: String, Codable {
        case chat
        case counter
        case system
    }
}

// MARK: - Request/Response Models
public struct RFQDraft {
    public var categoryId: String
    public var scope: RFQ.RFQScope
    public var location: RFQ.Location
    public var budgetRange: RFQ.BudgetRange?
    public var siteVisitRequested: Bool
    public var media: [String]
    
    public init(categoryId: String, scope: RFQ.RFQScope, location: RFQ.Location, 
                budgetRange: RFQ.BudgetRange? = nil, siteVisitRequested: Bool = false, media: [String] = []) {
        self.categoryId = categoryId
        self.scope = scope
        self.location = location
        self.budgetRange = budgetRange
        self.siteVisitRequested = siteVisitRequested
        self.media = media
    }
}

public struct NewBid {
    public var rfqId: String
    public var amountMAD: Double
    public var timelineDays: Int
    public var includesMaterials: Bool
    public var visitRequired: Bool
    public var message: String?
    public var autoAcceptAbove: Double?
    
    public init(rfqId: String, amountMAD: Double, timelineDays: Int, 
                includesMaterials: Bool = false, visitRequired: Bool = false, 
                message: String? = nil, autoAcceptAbove: Double? = nil) {
        self.rfqId = rfqId
        self.amountMAD = amountMAD
        self.timelineDays = timelineDays
        self.includesMaterials = includesMaterials
        self.visitRequired = visitRequired
        self.message = message
        self.autoAcceptAbove = autoAcceptAbove
    }
}

public struct Counter {
    public var bidId: String
    public var newAmountMAD: Double?
    public var newTimelineDays: Int?
    
    public init(bidId: String, newAmountMAD: Double? = nil, newTimelineDays: Int? = nil) {
        self.bidId = bidId
        self.newAmountMAD = newAmountMAD
        self.newTimelineDays = newTimelineDays
    }
}

public struct EscrowRequest {
    public var contractId: String
    public var method: Escrow.PaymentMethod
    public var milestones: [Contract.Milestone]?
    
    public init(contractId: String, method: Escrow.PaymentMethod, milestones: [Contract.Milestone]? = nil) {
        self.contractId = contractId
        self.method = method
        self.milestones = milestones
    }
}

public struct NewReview {
    public var contractId: String
    public var rating: Int
    public var text: String?
    
    public init(contractId: String, rating: Int, text: String? = nil) {
        self.contractId = contractId
        self.rating = rating
        self.text = text
    }
}