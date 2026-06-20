import Foundation

// MARK: - Health Programs & Insights

/// Multi-step health improvement program
public struct HealthProgram: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let goal: HealthGoal
    public let title: String
    public let description: String
    public let steps: [ProgramStep]
    public let schedule: ProgramSchedule
    public let personalizationFactors: [String: String]
    public var progress: ProgramProgress
    public let outcomes: [ExpectedOutcome]
    public let createdAt: Date
    public var updatedAt: Date
    public var status: ProgramStatus
    
    public enum ProgramStatus: String, Codable {
        case draft
        case active
        case paused
        case completed
        case abandoned
    }
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        goal: HealthGoal,
        title: String,
        description: String,
        steps: [ProgramStep],
        schedule: ProgramSchedule,
        personalizationFactors: [String: String] = [:],
        progress: ProgramProgress = ProgramProgress(),
        outcomes: [ExpectedOutcome] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: ProgramStatus = .draft
    ) {
        self.id = id
        self.userId = userId
        self.goal = goal
        self.title = title
        self.description = description
        self.steps = steps
        self.schedule = schedule
        self.personalizationFactors = personalizationFactors
        self.progress = progress
        self.outcomes = outcomes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
    }
}

/// Individual step in a health program
public struct ProgramStep: Codable, Identifiable {
    public let id: String
    public let type: StepType
    public let title: String
    public let description: String
    public let targetValue: TargetMetric?
    public let duration: TimeInterval?
    public let resources: [StepResource]
    public let dependencies: [String] // IDs of prerequisite steps
    public var isCompleted: Bool
    public var completedAt: Date?
    public var feedback: String?
    
    public enum StepType: String, Codable {
        case task
        case workout
        case nutrition
        case education
        case assessment
        case milestone
    }
    
    public struct TargetMetric: Codable {
        public let name: String
        public let value: Double
        public let unit: String
        
        public init(name: String, value: Double, unit: String) {
            self.name = name
            self.value = value
            self.unit = unit
        }
    }
    
    public struct StepResource: Codable {
        public let type: ResourceType
        public let title: String
        public let url: String?
        public let content: String?
        
        public enum ResourceType: String, Codable {
            case video
            case article
            case pdf
            case link
            case text
        }
        
        public init(type: ResourceType, title: String, url: String? = nil, content: String? = nil) {
            self.type = type
            self.title = title
            self.url = url
            self.content = content
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        type: StepType,
        title: String,
        description: String,
        targetValue: TargetMetric? = nil,
        duration: TimeInterval? = nil,
        resources: [StepResource] = [],
        dependencies: [String] = [],
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        feedback: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.targetValue = targetValue
        self.duration = duration
        self.resources = resources
        self.dependencies = dependencies
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.feedback = feedback
    }
}

/// Program schedule configuration
public struct ProgramSchedule: Codable {
    public let startDate: Date
    public let endDate: Date
    public let frequency: Frequency
    public let reminders: [ReminderTime]
    
    public enum Frequency: String, Codable {
        case daily
        case weekdays
        case weekends
        case custom
    }
    
    public struct ReminderTime: Codable {
        public let time: String // "HH:mm" format
        public let days: [Int]? // 1-7, nil means all days
        
        public init(time: String, days: [Int]? = nil) {
            self.time = time
            self.days = days
        }
    }
    
    public init(
        startDate: Date,
        endDate: Date,
        frequency: Frequency,
        reminders: [ReminderTime] = []
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.frequency = frequency
        self.reminders = reminders
    }
}

/// Program progress tracking
public struct ProgramProgress: Codable {
    public var completedSteps: Int
    public var totalSteps: Int
    public var adherenceRate: Double
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastActivityDate: Date?
    public var milestones: [Milestone]
    
    public struct Milestone: Codable {
        public let name: String
        public let achievedAt: Date
        public let value: String?
        
        public init(name: String, achievedAt: Date, value: String? = nil) {
            self.name = name
            self.achievedAt = achievedAt
            self.value = value
        }
    }
    
    public init(
        completedSteps: Int = 0,
        totalSteps: Int = 0,
        adherenceRate: Double = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastActivityDate: Date? = nil,
        milestones: [Milestone] = []
    ) {
        self.completedSteps = completedSteps
        self.totalSteps = totalSteps
        self.adherenceRate = adherenceRate
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActivityDate = lastActivityDate
        self.milestones = milestones
    }
}

/// Expected outcome from a program
public struct ExpectedOutcome: Codable {
    public let metric: String
    public let expectedChange: Double
    public let unit: String
    public let timeframe: String
    public let confidence: Double // 0-1
    
    public init(
        metric: String,
        expectedChange: Double,
        unit: String,
        timeframe: String,
        confidence: Double
    ) {
        self.metric = metric
        self.expectedChange = expectedChange
        self.unit = unit
        self.timeframe = timeframe
        self.confidence = confidence
    }
}

/// Health insight or preventive tip
public struct HealthInsight: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let type: InsightType
    public let category: InsightCategory
    public let title: String
    public let description: String
    public let trigger: InsightTrigger
    public let evidenceLinks: [EvidenceLink]
    public let severity: InsightSeverity
    public let recommendedActions: [RecommendedAction]
    public let createdAt: Date
    public var isRead: Bool
    public var isDismissed: Bool
    
    public enum InsightType: String, Codable {
        case preventive
        case corrective
        case educational
        case motivational
        case warning
    }
    
    public enum InsightCategory: String, Codable {
        case nutrition
        case activity
        case sleep
        case stress
        case vitals
        case medication
        case general
    }
    
    public enum InsightSeverity: String, Codable {
        case low
        case medium
        case high
        case critical
    }
    
    public struct InsightTrigger: Codable {
        public let condition: String
        public let value: String?
        public let threshold: String?
        
        public init(condition: String, value: String? = nil, threshold: String? = nil) {
            self.condition = condition
            self.value = value
            self.threshold = threshold
        }
    }
    
    public struct EvidenceLink: Codable {
        public let source: String
        public let title: String
        public let url: String
        public let credibilityScore: Double
        
        public init(source: String, title: String, url: String, credibilityScore: Double) {
            self.source = source
            self.title = title
            self.url = url
            self.credibilityScore = credibilityScore
        }
    }
    
    public struct RecommendedAction: Codable {
        public let title: String
        public let description: String
        public let actionType: ActionType
        public let priority: Int
        
        public enum ActionType: String, Codable {
            case program
            case appointment
            case lifestyle
            case monitoring
            case education
        }
        
        public init(title: String, description: String, actionType: ActionType, priority: Int) {
            self.title = title
            self.description = description
            self.actionType = actionType
            self.priority = priority
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        type: InsightType,
        category: InsightCategory,
        title: String,
        description: String,
        trigger: InsightTrigger,
        evidenceLinks: [EvidenceLink] = [],
        severity: InsightSeverity,
        recommendedActions: [RecommendedAction] = [],
        createdAt: Date = Date(),
        isRead: Bool = false,
        isDismissed: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.category = category
        self.title = title
        self.description = description
        self.trigger = trigger
        self.evidenceLinks = evidenceLinks
        self.severity = severity
        self.recommendedActions = recommendedActions
        self.createdAt = createdAt
        self.isRead = isRead
        self.isDismissed = isDismissed
    }
}

/// Health news item
public struct HealthNewsItem: Codable, Identifiable {
    public let id: String
    public let title: String
    public let summary: String
    public let content: String?
    public let source: NewsSource
    public let tags: [String]
    public let credibilityScore: Double
    public let publishedAt: Date
    public let imageUrl: String?
    public let readMoreUrl: String
    public let relevanceScore: Double?
    
    public struct NewsSource: Codable {
        public let name: String
        public let type: SourceType
        public let verified: Bool
        
        public enum SourceType: String, Codable {
            case medical
            case research
            case news
            case blog
            case government
        }
        
        public init(name: String, type: SourceType, verified: Bool) {
            self.name = name
            self.type = type
            self.verified = verified
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        summary: String,
        content: String? = nil,
        source: NewsSource,
        tags: [String],
        credibilityScore: Double,
        publishedAt: Date,
        imageUrl: String? = nil,
        readMoreUrl: String,
        relevanceScore: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.content = content
        self.source = source
        self.tags = tags
        self.credibilityScore = credibilityScore
        self.publishedAt = publishedAt
        self.imageUrl = imageUrl
        self.readMoreUrl = readMoreUrl
        self.relevanceScore = relevanceScore
    }
}