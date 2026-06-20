import Foundation

// MARK: - Leaderboards & Competitions

/// Leaderboard entry with privacy-preserving anonymization
public struct LeaderboardEntry: Codable, Identifiable {
    public let id: String
    public let anonymizedId: String // k-anonymity preserved
    public let bucket: LeaderboardBucket
    public let score: Double
    public let rank: Int
    public let percentile: Double
    public let metrics: LeaderboardMetrics
    public let lastUpdated: Date
    public let trend: ScoreTrend
    
    public enum ScoreTrend: String, Codable {
        case up
        case down
        case stable
    }
    
    public init(
        id: String = UUID().uuidString,
        anonymizedId: String,
        bucket: LeaderboardBucket,
        score: Double,
        rank: Int,
        percentile: Double,
        metrics: LeaderboardMetrics,
        lastUpdated: Date = Date(),
        trend: ScoreTrend = .stable
    ) {
        self.id = id
        self.anonymizedId = anonymizedId
        self.bucket = bucket
        self.score = score
        self.rank = rank
        self.percentile = percentile
        self.metrics = metrics
        self.lastUpdated = lastUpdated
        self.trend = trend
    }
}

/// Leaderboard bucketing for privacy
public struct LeaderboardBucket: Codable {
    public let geoLevel: GeoLevel
    public let ageBracket: AgeBracket?
    public let category: CompetitionCategory
    
    public enum GeoLevel: String, Codable {
        case city
        case state
        case country
        case continent
        case global
    }
    
    public enum AgeBracket: String, Codable {
        case under20 = "<20"
        case twenties = "20-29"
        case thirties = "30-39"
        case forties = "40-49"
        case fifties = "50-59"
        case sixties = "60-69"
        case seventiesPlus = "70+"
    }
    
    public enum CompetitionCategory: String, Codable {
        case overall
        case steps
        case activity
        case wellness
        case challenges
        case custom
    }
    
    public init(
        geoLevel: GeoLevel,
        ageBracket: AgeBracket? = nil,
        category: CompetitionCategory = .overall
    ) {
        self.geoLevel = geoLevel
        self.ageBracket = ageBracket
        self.category = category
    }
}

/// Composite leaderboard metrics
public struct LeaderboardMetrics: Codable {
    public let steps: Int
    public let activeMinutes: Int
    public let vo2Estimate: Double?
    public let adherenceRate: Double
    public let restingHeartRate: Int?
    public let sleepQualityScore: Double?
    public let nutritionScore: Double?
    public let stressScore: Double?
    public let compositeScore: Double
    
    public init(
        steps: Int,
        activeMinutes: Int,
        vo2Estimate: Double? = nil,
        adherenceRate: Double,
        restingHeartRate: Int? = nil,
        sleepQualityScore: Double? = nil,
        nutritionScore: Double? = nil,
        stressScore: Double? = nil,
        compositeScore: Double
    ) {
        self.steps = steps
        self.activeMinutes = activeMinutes
        self.vo2Estimate = vo2Estimate
        self.adherenceRate = adherenceRate
        self.restingHeartRate = restingHeartRate
        self.sleepQualityScore = sleepQualityScore
        self.nutritionScore = nutritionScore
        self.stressScore = stressScore
        self.compositeScore = compositeScore
    }
}

/// Health challenge for competitions
public struct HealthChallenge: Codable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let type: ChallengeType
    public let startDate: Date
    public let endDate: Date
    public let rules: [String]
    public let prizes: [Prize]?
    public let participants: Int
    public let isPublic: Bool
    public let createdBy: String
    public var status: ChallengeStatus
    
    public enum ChallengeType: String, Codable {
        case steps
        case distance
        case calories
        case workouts
        case meditation
        case hydration
        case custom
    }
    
    public enum ChallengeStatus: String, Codable {
        case upcoming
        case active
        case completed
        case cancelled
    }
    
    public struct Prize: Codable {
        public let rank: Int
        public let title: String
        public let description: String
        public let value: String?
        
        public init(rank: Int, title: String, description: String, value: String? = nil) {
            self.rank = rank
            self.title = title
            self.description = description
            self.value = value
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        type: ChallengeType,
        startDate: Date,
        endDate: Date,
        rules: [String],
        prizes: [Prize]? = nil,
        participants: Int = 0,
        isPublic: Bool = true,
        createdBy: String,
        status: ChallengeStatus = .upcoming
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.rules = rules
        self.prizes = prizes
        self.participants = participants
        self.isPublic = isPublic
        self.createdBy = createdBy
        self.status = status
    }
}

// MARK: - Health Professionals

/// Health professional profile
public struct HealthProfessional: Codable, Identifiable {
    public let id: String
    public let type: ProfessionalType
    public let name: String
    public let title: String
    public let bio: String
    public let specialties: [String]
    public let credentials: [Credential]
    public let verification: VerificationStatus
    public let rating: Double?
    public let reviewsCount: Int
    public let availability: AvailabilityInfo
    public let services: [ServiceOffering]
    public let languages: [String]
    public let imageUrl: String?
    public let location: Location?
    public let telehealthEnabled: Bool
    
    public enum ProfessionalType: String, Codable, CaseIterable {
        case doctor
        case nurse
        case dietician
        case nutritionist
        case personalTrainer
        case physicalTherapist
        case mentalHealthCounselor
        case healthCoach
        case specialist
    }
    
    public struct Credential: Codable {
        public let type: String
        public let issuer: String
        public let year: Int
        public let verified: Bool
        
        public init(type: String, issuer: String, year: Int, verified: Bool) {
            self.type = type
            self.issuer = issuer
            self.year = year
            self.verified = verified
        }
    }
    
    public enum VerificationStatus: String, Codable {
        case pending
        case verified
        case suspended
        case rejected
    }
    
    public struct AvailabilityInfo: Codable {
        public let nextAvailable: Date?
        public let bookingLeadTime: TimeInterval
        public let sessionDuration: TimeInterval
        public let timezone: String
        
        public init(
            nextAvailable: Date? = nil,
            bookingLeadTime: TimeInterval = 86400, // 24 hours
            sessionDuration: TimeInterval = 3600, // 1 hour
            timezone: String
        ) {
            self.nextAvailable = nextAvailable
            self.bookingLeadTime = bookingLeadTime
            self.sessionDuration = sessionDuration
            self.timezone = timezone
        }
    }
    
    public struct ServiceOffering: Codable {
        public let name: String
        public let description: String
        public let duration: TimeInterval
        public let price: Price?
        public let isOnline: Bool
        
        public struct Price: Codable {
            public let amount: Double
            public let currency: String
            
            public init(amount: Double, currency: String) {
                self.amount = amount
                self.currency = currency
            }
        }
        
        public init(
            name: String,
            description: String,
            duration: TimeInterval,
            price: Price? = nil,
            isOnline: Bool = false
        ) {
            self.name = name
            self.description = description
            self.duration = duration
            self.price = price
            self.isOnline = isOnline
        }
    }
    
    public struct Location: Codable {
        public let address: String
        public let city: String
        public let state: String?
        public let country: String
        public let latitude: Double?
        public let longitude: Double?
        
        public init(
            address: String,
            city: String,
            state: String? = nil,
            country: String,
            latitude: Double? = nil,
            longitude: Double? = nil
        ) {
            self.address = address
            self.city = city
            self.state = state
            self.country = country
            self.latitude = latitude
            self.longitude = longitude
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        type: ProfessionalType,
        name: String,
        title: String,
        bio: String,
        specialties: [String],
        credentials: [Credential],
        verification: VerificationStatus,
        rating: Double? = nil,
        reviewsCount: Int = 0,
        availability: AvailabilityInfo,
        services: [ServiceOffering],
        languages: [String] = ["English"],
        imageUrl: String? = nil,
        location: Location? = nil,
        telehealthEnabled: Bool = false
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.title = title
        self.bio = bio
        self.specialties = specialties
        self.credentials = credentials
        self.verification = verification
        self.rating = rating
        self.reviewsCount = reviewsCount
        self.availability = availability
        self.services = services
        self.languages = languages
        self.imageUrl = imageUrl
        self.location = location
        self.telehealthEnabled = telehealthEnabled
    }
}

/// Health appointment booking
public struct HealthAppointment: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let professionalId: String
    public let professionalName: String
    public let service: String
    public let dateTime: Date
    public let duration: TimeInterval
    public let type: AppointmentType
    public let status: AppointmentStatus
    public let notes: String?
    public let videoLink: String?
    public let price: Double?
    public let currency: String?
    public let paymentStatus: PaymentStatus?
    public let createdAt: Date
    
    public enum AppointmentType: String, Codable {
        case inPerson
        case telehealth
        case phone
    }
    
    public enum AppointmentStatus: String, Codable {
        case pending
        case confirmed
        case cancelled
        case completed
        case noShow
    }
    
    public enum PaymentStatus: String, Codable {
        case pending
        case paid
        case refunded
        case failed
    }
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        professionalId: String,
        professionalName: String,
        service: String,
        dateTime: Date,
        duration: TimeInterval,
        type: AppointmentType,
        status: AppointmentStatus = .pending,
        notes: String? = nil,
        videoLink: String? = nil,
        price: Double? = nil,
        currency: String? = nil,
        paymentStatus: PaymentStatus? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.professionalId = professionalId
        self.professionalName = professionalName
        self.service = service
        self.dateTime = dateTime
        self.duration = duration
        self.type = type
        self.status = status
        self.notes = notes
        self.videoLink = videoLink
        self.price = price
        self.currency = currency
        self.paymentStatus = paymentStatus
        self.createdAt = createdAt
    }
}