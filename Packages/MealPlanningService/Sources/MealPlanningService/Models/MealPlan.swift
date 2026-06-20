import Foundation

public struct MealPlan: Identifiable, Codable, Hashable {
    public let id: String?
    public let userId: String
    public let weekStartDate: Date
    public let preferences: MealPlanPreferences
    public let days: [DayPlan]
    public let optimizationMetadata: OptimizationMetadata?
    public let shoppingListId: String?
    public let status: MealPlanStatus
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String? = nil,
        userId: String,
        weekStartDate: Date,
        preferences: MealPlanPreferences,
        days: [DayPlan] = [],
        optimizationMetadata: OptimizationMetadata? = nil,
        shoppingListId: String? = nil,
        status: MealPlanStatus = .draft,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.weekStartDate = weekStartDate
        self.preferences = preferences
        self.days = days
        self.optimizationMetadata = optimizationMetadata
        self.shoppingListId = shoppingListId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum MealPlanStatus: String, Codable, CaseIterable {
    case draft
    case active
    case completed
    case archived
}

public struct MealPlanPreferences: Codable, Hashable {
    public let dietary: [DietaryRestriction]
    public let allergies: [Allergen]
    public let macroTargets: MacroTargets?
    public let timeBudgetMinutes: Int
    public let costBudgetRange: MoneyRange?
    public let cuisines: [String]
    public let utensilsMinimize: Bool
    public let weekendComplexityHigh: Bool
    public let leftoversPolicy: LeftoversPolicy
    public let dislikedIngredients: [String]
    public let preferredMealTimes: [MealSlotType: TimeRange]
    
    public init(
        dietary: [DietaryRestriction] = [],
        allergies: [Allergen] = [],
        macroTargets: MacroTargets? = nil,
        timeBudgetMinutes: Int = 30,
        costBudgetRange: MoneyRange? = nil,
        cuisines: [String] = [],
        utensilsMinimize: Bool = false,
        weekendComplexityHigh: Bool = true,
        leftoversPolicy: LeftoversPolicy = .moderate,
        dislikedIngredients: [String] = [],
        preferredMealTimes: [MealSlotType: TimeRange] = [:]
    ) {
        self.dietary = dietary
        self.allergies = allergies
        self.macroTargets = macroTargets
        self.timeBudgetMinutes = timeBudgetMinutes
        self.costBudgetRange = costBudgetRange
        self.cuisines = cuisines
        self.utensilsMinimize = utensilsMinimize
        self.weekendComplexityHigh = weekendComplexityHigh
        self.leftoversPolicy = leftoversPolicy
        self.dislikedIngredients = dislikedIngredients
        self.preferredMealTimes = preferredMealTimes
    }
}

public enum DietaryRestriction: String, Codable, CaseIterable {
    case vegetarian
    case vegan
    case ketogenic
    case paleo
    case mediterranean
    case lowCarb
    case lowFat
    case highProtein
    case glutenFree
    case dairyFree
    case halal
    case kosher
}

public enum LeftoversPolicy: String, Codable, CaseIterable {
    case none
    case minimal
    case moderate
    case maximize
}

public struct MacroTargets: Codable, Hashable {
    public let dailyCalories: Double?
    public let proteinGrams: Double?
    public let carbGrams: Double?
    public let fatGrams: Double?
    public let fiberGrams: Double?
    
    public init(
        dailyCalories: Double? = nil,
        proteinGrams: Double? = nil,
        carbGrams: Double? = nil,
        fatGrams: Double? = nil,
        fiberGrams: Double? = nil
    ) {
        self.dailyCalories = dailyCalories
        self.proteinGrams = proteinGrams
        self.carbGrams = carbGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
    }
}

public struct MoneyRange: Codable, Hashable {
    public let min: Double
    public let max: Double
    public let currency: String
    
    public init(min: Double, max: Double, currency: String = "MAD") {
        self.min = min
        self.max = max
        self.currency = currency
    }
}

public struct TimeRange: Codable, Hashable {
    public let start: String // HH:mm format
    public let end: String // HH:mm format
    
    public init(start: String, end: String) {
        self.start = start
        self.end = end
    }
}

public struct DayPlan: Identifiable, Codable, Hashable {
    public let id: String
    public let dayOfWeek: Int // 0 = Sunday
    public let date: Date
    public let meals: [MealSlot]
    public let dailyNutrition: NutrientProfile?
    
    public init(
        id: String = UUID().uuidString,
        dayOfWeek: Int,
        date: Date,
        meals: [MealSlot] = [],
        dailyNutrition: NutrientProfile? = nil
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.date = date
        self.meals = meals
        self.dailyNutrition = dailyNutrition
    }
}

public struct MealSlot: Identifiable, Codable, Hashable {
    public let id: String
    public let type: MealSlotType
    public let recipeId: String?
    public let recipe: Recipe?
    public let servingSize: Double
    public let notes: String?
    public let plannedTime: String? // HH:mm format
    public let isLeftover: Bool
    public let leftoverFromMealId: String?
    
    public init(
        id: String = UUID().uuidString,
        type: MealSlotType,
        recipeId: String? = nil,
        recipe: Recipe? = nil,
        servingSize: Double = 1.0,
        notes: String? = nil,
        plannedTime: String? = nil,
        isLeftover: Bool = false,
        leftoverFromMealId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.recipeId = recipeId
        self.recipe = recipe
        self.servingSize = servingSize
        self.notes = notes
        self.plannedTime = plannedTime
        self.isLeftover = isLeftover
        self.leftoverFromMealId = leftoverFromMealId
    }
}

public enum MealSlotType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack
}

public struct OptimizationMetadata: Codable, Hashable {
    public let totalScore: Double
    public let costScore: Double
    public let timeScore: Double
    public let varietyScore: Double
    public let constraintsSatisfied: [String]
    public let constraintsViolated: [String]
    public let alternativeCount: Int
    public let generationTimeSeconds: Double
    
    public init(
        totalScore: Double,
        costScore: Double,
        timeScore: Double,
        varietyScore: Double,
        constraintsSatisfied: [String] = [],
        constraintsViolated: [String] = [],
        alternativeCount: Int = 0,
        generationTimeSeconds: Double = 0
    ) {
        self.totalScore = totalScore
        self.costScore = costScore
        self.timeScore = timeScore
        self.varietyScore = varietyScore
        self.constraintsSatisfied = constraintsSatisfied
        self.constraintsViolated = constraintsViolated
        self.alternativeCount = alternativeCount
        self.generationTimeSeconds = generationTimeSeconds
    }
}

public struct PlanCriteria: Codable, Hashable {
    public let preferences: MealPlanPreferences
    public let weekStartDate: Date
    public let candidateRecipeIds: [String]?
    public let theme: String?
    public let prioritizeVariety: Bool
    public let allowIncompleteNutrition: Bool
    
    public init(
        preferences: MealPlanPreferences,
        weekStartDate: Date,
        candidateRecipeIds: [String]? = nil,
        theme: String? = nil,
        prioritizeVariety: Bool = true,
        allowIncompleteNutrition: Bool = true
    ) {
        self.preferences = preferences
        self.weekStartDate = weekStartDate
        self.candidateRecipeIds = candidateRecipeIds
        self.theme = theme
        self.prioritizeVariety = prioritizeVariety
        self.allowIncompleteNutrition = allowIncompleteNutrition
    }
}