import Foundation

public struct AIMessage: Identifiable, Codable, Hashable {
    public let id: String
    public let content: String
    public let isUser: Bool
    public let timestamp: Date
    public let context: [String: AnyCodable]?
    public let suggestedActions: [AIAction]
    
    public init(
        id: String = UUID().uuidString,
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        context: [String: AnyCodable]? = nil,
        suggestedActions: [AIAction] = []
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.context = context
        self.suggestedActions = suggestedActions
    }
}

public struct AIReply: Codable, Hashable {
    public let content: String
    public let suggestedRecipes: [Recipe]
    public let suggestedEdits: [MealPlanEdit]
    public let followUpQuestions: [String]
    public let confidence: Double
    public let sources: [String]
    
    public init(
        content: String,
        suggestedRecipes: [Recipe] = [],
        suggestedEdits: [MealPlanEdit] = [],
        followUpQuestions: [String] = [],
        confidence: Double = 1.0,
        sources: [String] = []
    ) {
        self.content = content
        self.suggestedRecipes = suggestedRecipes
        self.suggestedEdits = suggestedEdits
        self.followUpQuestions = followUpQuestions
        self.confidence = confidence
        self.sources = sources
    }
}

public struct AIAction: Codable, Hashable {
    public let type: AIActionType
    public let title: String
    public let description: String?
    public let parameters: [String: AnyCodable]
    
    public init(
        type: AIActionType,
        title: String,
        description: String? = nil,
        parameters: [String: AnyCodable] = [:]
    ) {
        self.type = type
        self.title = title
        self.description = description
        self.parameters = parameters
    }
}

public enum AIActionType: String, Codable, CaseIterable {
    case replaceMeal = "replace_meal"
    case addRecipe = "add_recipe"
    case adjustServing = "adjust_serving"
    case suggestAlternative = "suggest_alternative"
    case updatePreferences = "update_preferences"
    case regeneratePlan = "regenerate_plan"
    case priceCompare = "price_compare"
    case scheduleReminder = "schedule_reminder"
}

public struct MealPlanEdit: Codable, Hashable {
    public let type: EditType
    public let day: Int
    public let mealSlot: MealSlotType
    public let newRecipeId: String?
    public let newServingSize: Double?
    public let reason: String
    
    public init(
        type: EditType,
        day: Int,
        mealSlot: MealSlotType,
        newRecipeId: String? = nil,
        newServingSize: Double? = nil,
        reason: String
    ) {
        self.type = type
        self.day = day
        self.mealSlot = mealSlot
        self.newRecipeId = newRecipeId
        self.newServingSize = newServingSize
        self.reason = reason
    }
}

public enum EditType: String, Codable, CaseIterable {
    case replace
    case remove
    case adjustServing
    case reschedule
}

public struct HealthProfile: Codable, Hashable {
    public let userId: String
    public let trackedNutrients: [String]
    public let goals: [HealthGoal]
    public let bodyRegionConcerns: [BodyRegion]
    public let symptoms: [String]
    public let flaggedConditions: [String]
    public let medicalDisclaimer: Bool
    public let updatedAt: Date
    
    public init(
        userId: String,
        trackedNutrients: [String] = [],
        goals: [HealthGoal] = [],
        bodyRegionConcerns: [BodyRegion] = [],
        symptoms: [String] = [],
        flaggedConditions: [String] = [],
        medicalDisclaimer: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.trackedNutrients = trackedNutrients
        self.goals = goals
        self.bodyRegionConcerns = bodyRegionConcerns
        self.symptoms = symptoms
        self.flaggedConditions = flaggedConditions
        self.medicalDisclaimer = medicalDisclaimer
        self.updatedAt = updatedAt
    }
}

public struct HealthGoal: Codable, Hashable {
    public let type: GoalType
    public let target: Double
    public let unit: String
    public let timeframe: Timeframe
    public let priority: Priority
    
    public init(
        type: GoalType,
        target: Double,
        unit: String,
        timeframe: Timeframe = .daily,
        priority: Priority = .medium
    ) {
        self.type = type
        self.target = target
        self.unit = unit
        self.timeframe = timeframe
        self.priority = priority
    }
}

public enum GoalType: String, Codable, CaseIterable {
    case weightLoss
    case weightGain
    case muscleGain
    case energyBoost
    case immuneSupport
    case heartHealth
    case brainHealth
    case digestiveHealth
    case customNutrient
}

public enum Timeframe: String, Codable, CaseIterable {
    case daily
    case weekly
    case monthly
}

public enum Priority: String, Codable, CaseIterable {
    case low
    case medium
    case high
}

public struct BodyRegion: Codable, Hashable {
    public let name: String
    public let anatomicalId: String
    public let concernLevel: Priority
    public let relatedNutrients: [String]
    public let notes: String?
    
    public init(
        name: String,
        anatomicalId: String,
        concernLevel: Priority = .medium,
        relatedNutrients: [String] = [],
        notes: String? = nil
    ) {
        self.name = name
        self.anatomicalId = anatomicalId
        self.concernLevel = concernLevel
        self.relatedNutrients = relatedNutrients
        self.notes = notes
    }
}

public struct NutritionAdvice: Codable, Hashable {
    public let bodyRegions: [BodyRegion]
    public let recommendedNutrients: [String]
    public let avoidedIngredients: [String]
    public let suggestedRecipes: [Recipe]
    public let planCriteria: PlanCriteria
    public let disclaimer: String
    
    public init(
        bodyRegions: [BodyRegion],
        recommendedNutrients: [String],
        avoidedIngredients: [String],
        suggestedRecipes: [Recipe],
        planCriteria: PlanCriteria,
        disclaimer: String
    ) {
        self.bodyRegions = bodyRegions
        self.recommendedNutrients = recommendedNutrients
        self.avoidedIngredients = avoidedIngredients
        self.suggestedRecipes = suggestedRecipes
        self.planCriteria = planCriteria
        self.disclaimer = disclaimer
    }
}

// Helper for type-erased JSON encoding
public struct AnyCodable: Codable, Hashable {
    private let value: Any

    public init(_ value: Any) {
        self.value = value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let arrayValue = value as? [Any] {
            let wrapped = arrayValue.map { AnyCodable($0) }
            try container.encode(wrapped)
        } else if let dictValue = value as? [String: Any] {
            let wrapped = dictValue.mapValues { AnyCodable($0) }
            try container.encode(wrapped)
        } else {
            try container.encodeNil()
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue
        } else {
            value = NSNull()
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        if let hashableValue = value as? AnyHashable {
            hashableValue.hash(into: &hasher)
        }
    }
    
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        if let lhsValue = lhs.value as? AnyHashable,
           let rhsValue = rhs.value as? AnyHashable {
            return lhsValue == rhsValue
        }
        return false
    }
}