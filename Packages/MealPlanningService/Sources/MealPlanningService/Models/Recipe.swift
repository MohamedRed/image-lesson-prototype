import Foundation

public struct Recipe: Identifiable, Codable, Hashable {
    public let id: String?
    public let title: String
    public let description: String
    public let images: [String]
    public let videoUrl: String?
    public let sourcePlatform: SourcePlatform
    public let sourceAuthor: String?
    public let sourceAttribution: String?
    public let tags: [String]
    public let cuisines: [String]
    public let steps: [RecipeStep]
    public let ingredients: [Ingredient]
    public let utensils: [Utensil]
    public let nutrition: NutrientProfile?
    public let servings: Int
    public let prepTimeMinutes: Int
    public let cookTimeMinutes: Int
    public let totalTimeMinutes: Int
    public let difficultyLevel: DifficultyLevel
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String? = nil,
        title: String,
        description: String,
        images: [String] = [],
        videoUrl: String? = nil,
        sourcePlatform: SourcePlatform,
        sourceAuthor: String? = nil,
        sourceAttribution: String? = nil,
        tags: [String] = [],
        cuisines: [String] = [],
        steps: [RecipeStep] = [],
        ingredients: [Ingredient] = [],
        utensils: [Utensil] = [],
        nutrition: NutrientProfile? = nil,
        servings: Int,
        prepTimeMinutes: Int,
        cookTimeMinutes: Int,
        totalTimeMinutes: Int,
        difficultyLevel: DifficultyLevel,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.images = images
        self.videoUrl = videoUrl
        self.sourcePlatform = sourcePlatform
        self.sourceAuthor = sourceAuthor
        self.sourceAttribution = sourceAttribution
        self.tags = tags
        self.cuisines = cuisines
        self.steps = steps
        self.ingredients = ingredients
        self.utensils = utensils
        self.nutrition = nutrition
        self.servings = servings
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.totalTimeMinutes = totalTimeMinutes
        self.difficultyLevel = difficultyLevel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum SourcePlatform: String, Codable, CaseIterable {
    case instagram
    case tiktok
    case youtube
    case web
    case manual
}

public enum DifficultyLevel: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}

public struct RecipeStep: Identifiable, Codable, Hashable {
    public let id: String
    public let stepNumber: Int
    public let startTime: TimeInterval?
    public let endTime: TimeInterval?
    public let instruction: String
    public let shortInstruction: String?
    public let utensilRefs: [String]
    public let timerSeconds: Int?
    public let videoClipUrl: String?
    public let temperature: Temperature?
    public let notes: String?
    
    public init(
        id: String = UUID().uuidString,
        stepNumber: Int,
        startTime: TimeInterval? = nil,
        endTime: TimeInterval? = nil,
        instruction: String,
        shortInstruction: String? = nil,
        utensilRefs: [String] = [],
        timerSeconds: Int? = nil,
        videoClipUrl: String? = nil,
        temperature: Temperature? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.startTime = startTime
        self.endTime = endTime
        self.instruction = instruction
        self.shortInstruction = shortInstruction
        self.utensilRefs = utensilRefs
        self.timerSeconds = timerSeconds
        self.videoClipUrl = videoClipUrl
        self.temperature = temperature
        self.notes = notes
    }
}

public struct Temperature: Codable, Hashable {
    public let value: Double
    public let unit: TemperatureUnit
    
    public init(value: Double, unit: TemperatureUnit) {
        self.value = value
        self.unit = unit
    }
}

public enum TemperatureUnit: String, Codable, CaseIterable {
    case celsius = "°C"
    case fahrenheit = "°F"
}

public struct Ingredient: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let quantity: Double?
    public let unit: String?
    public let notes: String?
    public let substitutions: [String]
    public let allergens: [Allergen]
    public let category: IngredientCategory?
    public let isOptional: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        notes: String? = nil,
        substitutions: [String] = [],
        allergens: [Allergen] = [],
        category: IngredientCategory? = nil,
        isOptional: Bool = false
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.notes = notes
        self.substitutions = substitutions
        self.allergens = allergens
        self.category = category
        self.isOptional = isOptional
    }
}

public enum IngredientCategory: String, Codable, CaseIterable {
    case produce
    case meat
    case dairy
    case pantry
    case spices
    case condiments
    case frozen
    case canned
}

public enum Allergen: String, Codable, CaseIterable {
    case nuts
    case peanuts
    case shellfish
    case fish
    case eggs
    case dairy
    case soy
    case wheat
    case gluten
    case sesame
}

public struct Utensil: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let category: UtensilCategory
    public let isEssential: Bool
    public let alternatives: [String]
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        category: UtensilCategory,
        isEssential: Bool = true,
        alternatives: [String] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isEssential = isEssential
        self.alternatives = alternatives
    }
}

public enum UtensilCategory: String, Codable, CaseIterable {
    case cookware
    case bakeware
    case knives
    case smallAppliances
    case handTools
    case measuring
}

public struct NutrientProfile: Codable, Hashable {
    public let calories: Double
    public let macros: Macronutrients
    public let micronutrients: [String: Double]
    public let perServing: Bool
    
    public init(
        calories: Double,
        macros: Macronutrients,
        micronutrients: [String: Double] = [:],
        perServing: Bool = true
    ) {
        self.calories = calories
        self.macros = macros
        self.micronutrients = micronutrients
        self.perServing = perServing
    }
}

public struct Macronutrients: Codable, Hashable {
    public let protein: Double // grams
    public let carbs: Double // grams
    public let fat: Double // grams
    public let fiber: Double // grams
    public let sugar: Double // grams
    
    public init(
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double = 0,
        sugar: Double = 0
    ) {
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
    }
}