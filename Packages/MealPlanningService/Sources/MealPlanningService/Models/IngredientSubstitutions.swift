import Foundation

/// Ingredient substitution and allergen management
public struct IngredientSubstitutions {
    
    // MARK: - Common Allergens
    
    public static let commonAllergens = [
        "milk", "dairy", "lactose",
        "eggs",
        "peanuts", "peanut",
        "tree nuts", "almonds", "walnuts", "cashews", "pistachios", "pecans",
        "wheat", "gluten",
        "soy", "soybean",
        "fish", "salmon", "tuna", "cod",
        "shellfish", "shrimp", "crab", "lobster", "clams", "mussels",
        "sesame"
    ]
    
    // MARK: - Substitution Rules
    
    public static let substitutionRules: [String: [IngredientSubstitution]] = [
        
        // Dairy Substitutions
        "milk": [
            IngredientSubstitution(
                substitute: "almond milk",
                ratio: 1.0,
                category: .dairy,
                allergenFree: [.dairy],
                notes: "Unsweetened almond milk works best for savory dishes"
            ),
            IngredientSubstitution(
                substitute: "oat milk",
                ratio: 1.0,
                category: .dairy,
                allergenFree: [.dairy],
                notes: "Creamier texture, great for baking"
            ),
            IngredientSubstitution(
                substitute: "coconut milk",
                ratio: 1.0,
                category: .dairy,
                allergenFree: [.dairy],
                notes: "Rich flavor, best for curries and desserts"
            )
        ],
        
        "butter": [
            IngredientSubstitution(
                substitute: "olive oil",
                ratio: 0.75,
                category: .dairy,
                allergenFree: [.dairy],
                notes: "Use 3/4 the amount, adds different flavor profile"
            ),
            IngredientSubstitution(
                substitute: "coconut oil",
                ratio: 1.0,
                category: .dairy,
                allergenFree: [.dairy],
                notes: "Solid at room temperature, good for baking"
            ),
            IngredientSubstitution(
                substitute: "vegan butter",
                ratio: 1.0,
                category: .dairy,
                allergenFree: [.dairy],
                notes: "Direct replacement with similar properties"
            )
        ],
        
        "heavy cream": [
            IngredientSubstitution(
                substitute: "coconut cream",
                ratio: 1.0,
                category: .dairy,
                allergenFree: [.dairy],
                notes: "Thick part from canned coconut milk"
            ),
            IngredientSubstitution(
                substitute: "cashew cream",
                ratio: 1.0,
                category: .dairy,
                allergenFree: [.dairy],
                contains: [.treeNuts],
                notes: "Soak cashews 4 hours, blend with water"
            )
        ],
        
        "cheese": [
            IngredientSubstitution(
                substitute: "nutritional yeast",
                ratio: 0.25,
                category: .dairy,
                allergenFree: [.dairy],
                notes: "Adds cheesy flavor, use much less"
            ),
            IngredientSubstitution(
                substitute: "cashew cheese",
                ratio: 1.0,
                category: .dairy,
                allergenFree: [.dairy],
                contains: [.treeNuts],
                notes: "Homemade or store-bought vegan cheese"
            )
        ],
        
        // Egg Substitutions
        "eggs": [
            IngredientSubstitution(
                substitute: "flax eggs",
                ratio: 1.0,
                category: .eggs,
                allergenFree: [.eggs],
                notes: "1 tbsp ground flaxseed + 3 tbsp water per egg"
            ),
            IngredientSubstitution(
                substitute: "chia eggs",
                ratio: 1.0,
                category: .eggs,
                allergenFree: [.eggs],
                notes: "1 tbsp chia seeds + 3 tbsp water per egg"
            ),
            IngredientSubstitution(
                substitute: "applesauce",
                ratio: 0.25, // 1/4 cup per egg
                category: .eggs,
                allergenFree: [.eggs],
                notes: "Best for moist baked goods, adds sweetness"
            ),
            IngredientSubstitution(
                substitute: "aquafaba",
                ratio: 3.0, // 3 tbsp per egg
                category: .eggs,
                allergenFree: [.eggs],
                notes: "Liquid from canned chickpeas, great for binding"
            )
        ],
        
        // Wheat/Gluten Substitutions
        "all-purpose flour": [
            IngredientSubstitution(
                substitute: "rice flour",
                ratio: 1.0,
                category: .wheat,
                allergenFree: [.wheat, .gluten],
                notes: "Light texture, may need binding agent"
            ),
            IngredientSubstitution(
                substitute: "almond flour",
                ratio: 1.0,
                category: .wheat,
                allergenFree: [.wheat, .gluten],
                contains: [.treeNuts],
                notes: "Adds protein and healthy fats"
            ),
            IngredientSubstitution(
                substitute: "oat flour",
                ratio: 1.0,
                category: .wheat,
                allergenFree: [.wheat, .gluten],
                notes: "Make by grinding oats, adds fiber"
            ),
            IngredientSubstitution(
                substitute: "coconut flour",
                ratio: 0.25,
                category: .wheat,
                allergenFree: [.wheat, .gluten],
                notes: "Very absorbent, use much less and add liquid"
            )
        ],
        
        "bread crumbs": [
            IngredientSubstitution(
                substitute: "crushed rice crackers",
                ratio: 1.0,
                category: .wheat,
                allergenFree: [.wheat, .gluten],
                notes: "Gluten-free coating alternative"
            ),
            IngredientSubstitution(
                substitute: "crushed cornflakes",
                ratio: 1.0,
                category: .wheat,
                allergenFree: [.wheat, .gluten],
                notes: "Adds crunch to coatings"
            )
        ],
        
        "soy sauce": [
            IngredientSubstitution(
                substitute: "tamari",
                ratio: 1.0,
                category: .soy,
                allergenFree: [.soy, .wheat, .gluten],
                notes: "Wheat-free soy sauce alternative"
            ),
            IngredientSubstitution(
                substitute: "coconut aminos",
                ratio: 1.0,
                category: .soy,
                allergenFree: [.soy, .wheat, .gluten],
                notes: "Soy-free, slightly sweeter taste"
            )
        ],
        
        // Nut Substitutions
        "peanuts": [
            IngredientSubstitution(
                substitute: "sunflower seeds",
                ratio: 1.0,
                category: .nuts,
                allergenFree: [.peanuts, .treeNuts],
                notes: "Similar texture and protein content"
            ),
            IngredientSubstitution(
                substitute: "pumpkin seeds",
                ratio: 1.0,
                category: .nuts,
                allergenFree: [.peanuts, .treeNuts],
                notes: "Rich in minerals, slightly different flavor"
            )
        ],
        
        "peanut butter": [
            IngredientSubstitution(
                substitute: "sunflower seed butter",
                ratio: 1.0,
                category: .nuts,
                allergenFree: [.peanuts, .treeNuts],
                notes: "Most similar texture and usage"
            ),
            IngredientSubstitution(
                substitute: "tahini",
                ratio: 1.0,
                category: .nuts,
                allergenFree: [.peanuts, .treeNuts],
                contains: [.sesame],
                notes: "Sesame seed paste, slightly bitter"
            )
        ],
        
        "almonds": [
            IngredientSubstitution(
                substitute: "sunflower seeds",
                ratio: 1.0,
                category: .nuts,
                allergenFree: [.treeNuts],
                notes: "Different flavor but similar crunch"
            )
        ]
    ]
    
    // MARK: - Dietary Preference Substitutions
    
    public static let dietarySubstitutions: [DietaryPreference: [String: [IngredientSubstitution]]] = [
        .vegetarian: [
            "chicken": [
                IngredientSubstitution(
                    substitute: "tofu",
                    ratio: 1.0,
                    category: .protein,
                    allergenFree: [],
                    contains: [.soy],
                    notes: "Firm tofu works best, press out water first"
                ),
                IngredientSubstitution(
                    substitute: "tempeh",
                    ratio: 1.0,
                    category: .protein,
                    allergenFree: [],
                    contains: [.soy],
                    notes: "Fermented soy with nutty flavor"
                ),
                IngredientSubstitution(
                    substitute: "mushrooms",
                    ratio: 1.0,
                    category: .protein,
                    allergenFree: [],
                    notes: "Portobello or shiitake for meaty texture"
                )
            ],
            "ground beef": [
                IngredientSubstitution(
                    substitute: "lentils",
                    ratio: 1.0,
                    category: .protein,
                    allergenFree: [],
                    notes: "Brown or green lentils, pre-cooked"
                ),
                IngredientSubstitution(
                    substitute: "plant-based ground meat",
                    ratio: 1.0,
                    category: .protein,
                    allergenFree: [],
                    notes: "Commercial meat alternatives"
                )
            ]
        ],
        
        .vegan: [
            "honey": [
                IngredientSubstitution(
                    substitute: "maple syrup",
                    ratio: 1.0,
                    category: .sweetener,
                    allergenFree: [],
                    notes: "Plant-based sweetener with similar consistency"
                ),
                IngredientSubstitution(
                    substitute: "agave nectar",
                    ratio: 0.75,
                    category: .sweetener,
                    allergenFree: [],
                    notes: "Sweeter than honey, use less"
                )
            ]
        ]
    ]
    
    // MARK: - Helper Functions
    
    /// Find substitutions for an ingredient based on allergens and dietary preferences
    public static func findSubstitutions(
        for ingredient: String,
        avoiding allergens: [AllergenType] = [],
        following diet: DietaryPreference? = nil
    ) -> [IngredientSubstitution] {
        
        var substitutions: [IngredientSubstitution] = []
        let normalizedIngredient = ingredient.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check direct substitution rules
        if let directSubs = substitutionRules[normalizedIngredient] {
            substitutions.append(contentsOf: directSubs)
        }
        
        // Check partial matches for compound ingredients
        for (key, subs) in substitutionRules {
            if normalizedIngredient.contains(key) && key != normalizedIngredient {
                substitutions.append(contentsOf: subs)
            }
        }
        
        // Add dietary-specific substitutions
        if let diet = diet,
           let dietSubs = dietarySubstitutions[diet]?[normalizedIngredient] {
            substitutions.append(contentsOf: dietSubs)
        }
        
        // Filter based on allergen restrictions
        if !allergens.isEmpty {
            substitutions = substitutions.filter { substitution in
                // Must be free of avoided allergens
                let avoidsAllergens = allergens.allSatisfy { allergen in
                    substitution.allergenFree.contains(allergen)
                }
                
                // Must not contain avoided allergens
                let doesntContainAllergens = allergens.allSatisfy { allergen in
                    !substitution.contains.contains(allergen)
                }
                
                return avoidsAllergens && doesntContainAllergens
            }
        }
        
        return substitutions
    }
    
    /// Check if an ingredient contains any of the specified allergens
    public static func containsAllergens(_ ingredient: String, allergens: [AllergenType]) -> [AllergenType] {
        let normalizedIngredient = ingredient.lowercased()
        var foundAllergens: [AllergenType] = []
        
        for allergen in allergens {
            let allergenKeywords = getAllergenKeywords(allergen)
            
            if allergenKeywords.contains(where: { normalizedIngredient.contains($0) }) {
                foundAllergens.append(allergen)
            }
        }
        
        return foundAllergens
    }
    
    private static func getAllergenKeywords(_ allergen: AllergenType) -> [String] {
        switch allergen {
        case .dairy:
            return ["milk", "dairy", "lactose", "butter", "cream", "cheese", "yogurt", "whey", "casein"]
        case .eggs:
            return ["egg", "eggs", "albumin"]
        case .peanuts:
            return ["peanut", "peanuts", "groundnut"]
        case .treeNuts:
            return ["almond", "walnut", "cashew", "pistachio", "pecan", "hazelnut", "macadamia", "brazil nut"]
        case .wheat:
            return ["wheat", "flour", "bread", "pasta", "semolina", "bulgur"]
        case .gluten:
            return ["gluten", "wheat", "barley", "rye", "oats", "malt"]
        case .soy:
            return ["soy", "soybean", "tofu", "tempeh", "miso", "edamame"]
        case .fish:
            return ["fish", "salmon", "tuna", "cod", "halibut", "anchovy"]
        case .shellfish:
            return ["shrimp", "crab", "lobster", "clam", "mussel", "oyster", "scallop"]
        case .sesame:
            return ["sesame", "tahini"]
        }
    }
}

// MARK: - Models

public struct IngredientSubstitution {
    public let substitute: String
    public let ratio: Double // Conversion ratio (substitute amount / original amount)
    public let category: SubstitutionCategory
    public let allergenFree: [AllergenType]
    public let contains: [AllergenType]
    public let notes: String
    public let difficulty: SubstitutionDifficulty
    public let tasteImpact: TasteImpact
    
    public init(
        substitute: String,
        ratio: Double,
        category: SubstitutionCategory,
        allergenFree: [AllergenType],
        contains: [AllergenType] = [],
        notes: String,
        difficulty: SubstitutionDifficulty = .easy,
        tasteImpact: TasteImpact = .minimal
    ) {
        self.substitute = substitute
        self.ratio = ratio
        self.category = category
        self.allergenFree = allergenFree
        self.contains = contains
        self.notes = notes
        self.difficulty = difficulty
        self.tasteImpact = tasteImpact
    }
}

public enum AllergenType: String, CaseIterable {
    case dairy
    case eggs
    case peanuts
    case treeNuts
    case wheat
    case gluten
    case soy
    case fish
    case shellfish
    case sesame
    
    public var displayName: String {
        switch self {
        case .dairy: return "Dairy"
        case .eggs: return "Eggs"
        case .peanuts: return "Peanuts"
        case .treeNuts: return "Tree Nuts"
        case .wheat: return "Wheat"
        case .gluten: return "Gluten"
        case .soy: return "Soy"
        case .fish: return "Fish"
        case .shellfish: return "Shellfish"
        case .sesame: return "Sesame"
        }
    }
}

public enum SubstitutionCategory {
    case dairy
    case eggs
    case wheat
    case nuts
    case soy
    case protein
    case sweetener
    case spice
    case liquid
}

public enum DietaryPreference {
    case vegetarian
    case vegan
    case keto
    case paleo
    case lowCarb
    case dairyFree
    case glutenFree
}

public enum SubstitutionDifficulty {
    case easy      // Direct replacement
    case medium    // May need preparation or technique adjustment
    case hard      // Significant recipe modification required
}

public enum TasteImpact {
    case minimal   // Little to no taste difference
    case noticeable // Some taste difference but still good
    case significant // Major taste change, different dish character
}

// MARK: - Allergen Warning System

public struct AllergenWarningSystem {
    
    /// Generate allergen warnings for a recipe
    public static func generateWarnings(
        for recipe: Recipe,
        userAllergens: [AllergenType]
    ) -> [AllergenWarning] {
        
        var warnings: [AllergenWarning] = []
        
        for ingredient in recipe.ingredients {
            let foundAllergens = IngredientSubstitutions.containsAllergens(
                ingredient.name,
                allergens: userAllergens
            )
            
            if !foundAllergens.isEmpty {
                let substitutions = IngredientSubstitutions.findSubstitutions(
                    for: ingredient.name,
                    avoiding: foundAllergens
                )
                
                warnings.append(AllergenWarning(
                    ingredient: ingredient.name,
                    allergens: foundAllergens,
                    severity: determineSeverity(allergens: foundAllergens),
                    suggestedSubstitutions: substitutions,
                    message: generateWarningMessage(ingredient: ingredient.name, allergens: foundAllergens)
                ))
            }
        }
        
        return warnings
    }
    
    private static func determineSeverity(allergens: [AllergenType]) -> AllergenSeverity {
        // In a real app, this could be personalized based on user's allergy severity
        if allergens.contains(.peanuts) || allergens.contains(.shellfish) {
            return .critical // These are often severe allergies
        } else if allergens.count > 1 {
            return .high
        } else {
            return .medium
        }
    }
    
    private static func generateWarningMessage(ingredient: String, allergens: [AllergenType]) -> String {
        let allergenNames = allergens.map { $0.displayName }.joined(separator: ", ")
        return "⚠️ Warning: '\(ingredient)' contains \(allergenNames). This ingredient should be avoided or substituted."
    }
}

public struct AllergenWarning {
    public let ingredient: String
    public let allergens: [AllergenType]
    public let severity: AllergenSeverity
    public let suggestedSubstitutions: [IngredientSubstitution]
    public let message: String
}

public enum AllergenSeverity {
    case low
    case medium
    case high
    case critical
    
    public var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}