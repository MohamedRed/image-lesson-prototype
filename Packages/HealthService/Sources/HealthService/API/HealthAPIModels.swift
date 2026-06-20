import Foundation

// MARK: - API Request Models

public struct CreateProgramRequest: Codable {
    public let goal: HealthGoal
    public let constraints: [String: String]
    public let preferences: [String: String]
    
    public init(
        goal: HealthGoal,
        constraints: [String: String] = [:],
        preferences: [String: String] = [:]
    ) {
        self.goal = goal
        self.constraints = constraints
        self.preferences = preferences
    }
}

public struct ProgressUpdateRequest: Codable {
    public let stepId: String
    public let completed: Bool
    public let feedback: String?
    public let metrics: [String: Double]?
    
    public init(
        stepId: String,
        completed: Bool,
        feedback: String? = nil,
        metrics: [String: Double]? = nil
    ) {
        self.stepId = stepId
        self.completed = completed
        self.feedback = feedback
        self.metrics = metrics
    }
}

public struct HealthKitImportRequest: Codable {
    public let observations: [HealthObservation]
    public let manifest: ImportManifest
    
    public struct ImportManifest: Codable {
        public let startDate: Date
        public let endDate: Date
        public let dataTypes: [String]
        public let recordCount: Int
        public let checksum: String?
        
        public init(
            startDate: Date,
            endDate: Date,
            dataTypes: [String],
            recordCount: Int,
            checksum: String? = nil
        ) {
            self.startDate = startDate
            self.endDate = endDate
            self.dataTypes = dataTypes
            self.recordCount = recordCount
            self.checksum = checksum
        }
    }
    
    public init(observations: [HealthObservation], manifest: ImportManifest) {
        self.observations = observations
        self.manifest = manifest
    }
}

public struct BookAppointmentRequest: Codable {
    public let professionalId: String
    public let serviceId: String
    public let dateTime: Date
    public let type: HealthAppointment.AppointmentType
    public let notes: String?
    public let paymentMethodId: String?
    
    public init(
        professionalId: String,
        serviceId: String,
        dateTime: Date,
        type: HealthAppointment.AppointmentType,
        notes: String? = nil,
        paymentMethodId: String? = nil
    ) {
        self.professionalId = professionalId
        self.serviceId = serviceId
        self.dateTime = dateTime
        self.type = type
        self.notes = notes
        self.paymentMethodId = paymentMethodId
    }
}

public struct VoiceInterpretRequest: Codable {
    public let transcript: String
    public let context: VoiceContext?
    
    public struct VoiceContext: Codable {
        public let activePrograms: [String]
        public let currentGoals: [String]
        public let recentInsights: [String]
        
        public init(
            activePrograms: [String] = [],
            currentGoals: [String] = [],
            recentInsights: [String] = []
        ) {
            self.activePrograms = activePrograms
            self.currentGoals = currentGoals
            self.recentInsights = recentInsights
        }
    }
    
    public init(transcript: String, context: VoiceContext? = nil) {
        self.transcript = transcript
        self.context = context
    }
}

// MARK: - API Response Models

public struct HealthOverviewResponse: Codable {
    public let profile: HealthProfile
    public let todaySummary: DaySummary
    public let activeProgramSteps: [ProgramStep]
    public let insights: [HealthInsight]
    public let leaderboardPosition: LeaderboardPosition?
    
    public struct DaySummary: Codable {
        public let date: Date
        public let steps: Int
        public let activeMinutes: Int
        public let calories: Int
        public let sleepHours: Double?
        public let heartRateAvg: Int?
        public let stressScore: Double?
        public let hydration: Double?
        public let completedTasks: Int
        public let totalTasks: Int
        
        public init(
            date: Date,
            steps: Int,
            activeMinutes: Int,
            calories: Int,
            sleepHours: Double? = nil,
            heartRateAvg: Int? = nil,
            stressScore: Double? = nil,
            hydration: Double? = nil,
            completedTasks: Int,
            totalTasks: Int
        ) {
            self.date = date
            self.steps = steps
            self.activeMinutes = activeMinutes
            self.calories = calories
            self.sleepHours = sleepHours
            self.heartRateAvg = heartRateAvg
            self.stressScore = stressScore
            self.hydration = hydration
            self.completedTasks = completedTasks
            self.totalTasks = totalTasks
        }
    }
    
    public struct LeaderboardPosition: Codable {
        public let rank: Int
        public let percentile: Double
        public let bucket: String
        public let trend: String
        
        public init(rank: Int, percentile: Double, bucket: String, trend: String) {
            self.rank = rank
            self.percentile = percentile
            self.bucket = bucket
            self.trend = trend
        }
    }
    
    public init(
        profile: HealthProfile,
        todaySummary: DaySummary,
        activeProgramSteps: [ProgramStep],
        insights: [HealthInsight],
        leaderboardPosition: LeaderboardPosition? = nil
    ) {
        self.profile = profile
        self.todaySummary = todaySummary
        self.activeProgramSteps = activeProgramSteps
        self.insights = insights
        self.leaderboardPosition = leaderboardPosition
    }
}

public struct ObservationsResponse: Codable {
    public let observations: [HealthObservation]
    public let totalCount: Int
    public let hasMore: Bool
    public let nextPageToken: String?
    
    public init(
        observations: [HealthObservation],
        totalCount: Int,
        hasMore: Bool,
        nextPageToken: String? = nil
    ) {
        self.observations = observations
        self.totalCount = totalCount
        self.hasMore = hasMore
        self.nextPageToken = nextPageToken
    }
}

public struct CreateProgramResponse: Codable {
    public let program: HealthProgram
    public let estimatedDuration: String
    public let difficultyLevel: String
    public let expectedOutcomes: [String]
    
    public init(
        program: HealthProgram,
        estimatedDuration: String,
        difficultyLevel: String,
        expectedOutcomes: [String]
    ) {
        self.program = program
        self.estimatedDuration = estimatedDuration
        self.difficultyLevel = difficultyLevel
        self.expectedOutcomes = expectedOutcomes
    }
}

public struct LeaderboardResponse: Codable {
    public let entries: [LeaderboardEntry]
    public let userPosition: LeaderboardEntry?
    public let bucket: String
    public let lastUpdated: Date
    public let totalParticipants: Int
    
    public init(
        entries: [LeaderboardEntry],
        userPosition: LeaderboardEntry? = nil,
        bucket: String,
        lastUpdated: Date,
        totalParticipants: Int
    ) {
        self.entries = entries
        self.userPosition = userPosition
        self.bucket = bucket
        self.lastUpdated = lastUpdated
        self.totalParticipants = totalParticipants
    }
}

public struct NewsResponse: Codable {
    public let articles: [HealthNewsItem]
    public let totalCount: Int
    public let hasMore: Bool
    public let nextPageToken: String?
    public let personalizationTags: [String]
    
    public init(
        articles: [HealthNewsItem],
        totalCount: Int,
        hasMore: Bool,
        nextPageToken: String? = nil,
        personalizationTags: [String] = []
    ) {
        self.articles = articles
        self.totalCount = totalCount
        self.hasMore = hasMore
        self.nextPageToken = nextPageToken
        self.personalizationTags = personalizationTags
    }
}

public struct ProfessionalSearchResponse: Codable {
    public let professionals: [HealthProfessional]
    public let totalCount: Int
    public let hasMore: Bool
    public let nextPageToken: String?
    public let filters: SearchFilters
    
    public struct SearchFilters: Codable {
        public let availableSpecialties: [String]
        public let availableTypes: [String]
        public let priceRange: PriceRange?
        
        public struct PriceRange: Codable {
            public let min: Double
            public let max: Double
            public let currency: String
            
            public init(min: Double, max: Double, currency: String) {
                self.min = min
                self.max = max
                self.currency = currency
            }
        }
        
        public init(
            availableSpecialties: [String],
            availableTypes: [String],
            priceRange: PriceRange? = nil
        ) {
            self.availableSpecialties = availableSpecialties
            self.availableTypes = availableTypes
            self.priceRange = priceRange
        }
    }
    
    public init(
        professionals: [HealthProfessional],
        totalCount: Int,
        hasMore: Bool,
        nextPageToken: String? = nil,
        filters: SearchFilters
    ) {
        self.professionals = professionals
        self.totalCount = totalCount
        self.hasMore = hasMore
        self.nextPageToken = nextPageToken
        self.filters = filters
    }
}

public struct BookAppointmentResponse: Codable {
    public let appointment: HealthAppointment
    public let confirmationCode: String
    public let paymentIntent: String?
    public let calendarLink: String?
    public let preparation: [String]?
    
    public init(
        appointment: HealthAppointment,
        confirmationCode: String,
        paymentIntent: String? = nil,
        calendarLink: String? = nil,
        preparation: [String]? = nil
    ) {
        self.appointment = appointment
        self.confirmationCode = confirmationCode
        self.paymentIntent = paymentIntent
        self.calendarLink = calendarLink
        self.preparation = preparation
    }
}

public struct VoiceInterpretResponse: Codable {
    public let intent: VoiceIntent
    public let extractedData: [String: String]
    public let nextPrompt: String?
    public let suggestedActions: [SuggestedAction]
    
    public enum VoiceIntent: String, Codable {
        case logObservation
        case askQuestion
        case setGoal
        case checkProgress
        case findProfessional
        case scheduleAppointment
        case getInsights
        case unknown
    }
    
    public struct SuggestedAction: Codable {
        public let title: String
        public let action: String
        public let parameters: [String: String]?
        
        public init(title: String, action: String, parameters: [String: String]? = nil) {
            self.title = title
            self.action = action
            self.parameters = parameters
        }
    }
    
    public init(
        intent: VoiceIntent,
        extractedData: [String: String] = [:],
        nextPrompt: String? = nil,
        suggestedActions: [SuggestedAction] = []
    ) {
        self.intent = intent
        self.extractedData = extractedData
        self.nextPrompt = nextPrompt
        self.suggestedActions = suggestedActions
    }
}

// MARK: - FHIR Mapping Models

public struct FHIRObservation: Codable {
    public let resourceType: String
    public let id: String
    public let status: String
    public let category: [FHIRCodeableConcept]
    public let code: FHIRCodeableConcept
    public let subject: FHIRReference
    public let effectiveDateTime: String
    public let valueQuantity: FHIRQuantity?
    public let valueString: String?
    public let valueBoolean: Bool?
    
    public struct FHIRCodeableConcept: Codable {
        public let coding: [FHIRCoding]
        public let text: String?
        
        public init(coding: [FHIRCoding], text: String? = nil) {
            self.coding = coding
            self.text = text
        }
    }
    
    public struct FHIRCoding: Codable {
        public let system: String
        public let code: String
        public let display: String?
        
        public init(system: String, code: String, display: String? = nil) {
            self.system = system
            self.code = code
            self.display = display
        }
    }
    
    public struct FHIRReference: Codable {
        public let reference: String
        
        public init(reference: String) {
            self.reference = reference
        }
    }
    
    public struct FHIRQuantity: Codable {
        public let value: Double
        public let unit: String
        public let system: String?
        public let code: String?
        
        public init(value: Double, unit: String, system: String? = nil, code: String? = nil) {
            self.value = value
            self.unit = unit
            self.system = system
            self.code = code
        }
    }
    
    public init(
        resourceType: String = "Observation",
        id: String,
        status: String = "final",
        category: [FHIRCodeableConcept],
        code: FHIRCodeableConcept,
        subject: FHIRReference,
        effectiveDateTime: String,
        valueQuantity: FHIRQuantity? = nil,
        valueString: String? = nil,
        valueBoolean: Bool? = nil
    ) {
        self.resourceType = resourceType
        self.id = id
        self.status = status
        self.category = category
        self.code = code
        self.subject = subject
        self.effectiveDateTime = effectiveDateTime
        self.valueQuantity = valueQuantity
        self.valueString = valueString
        self.valueBoolean = valueBoolean
    }
}