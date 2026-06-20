import Foundation
import Combine

/// Core service protocol for meal planning functionality
public protocol MealPlanningServicing {
    
    // MARK: - User Session
    
    /// Current authenticated user ID
    var currentUserId: String? { get }
    
    // MARK: - Recipe Management
    
    /// Import recipe from URL (initiates async pipeline)
    func importRecipe(from url: String) async throws -> String
    
    /// Get recipe by ID
    func getRecipe(id: String) async throws -> Recipe
    
    /// Search recipes in user's collection and global index
    func searchRecipes(query: String, filters: RecipeFilters?) async throws -> [Recipe]
    
    /// Get user's saved recipes
    func getMyRecipes() async throws -> [Recipe]
    
    /// Save recipe to user's collection
    func saveRecipe(_ recipe: Recipe) async throws
    
    /// Remove recipe from user's collection
    func removeRecipe(id: String) async throws
    
    /// Get recipe suggestions based on preferences
    func getRecipeSuggestions(criteria: SuggestionCriteria) async throws -> [Recipe]
    
    // MARK: - Meal Planning
    
    /// Generate meal plan (async job with progress updates)
    func generateMealPlan(criteria: PlanCriteria) async throws -> String // returns mealPlanId
    
    /// Get meal plan by ID
    func getMealPlan(id: String) async throws -> MealPlan
    
    /// Get user's meal plans
    func getMyMealPlans() async throws -> [MealPlan]
    
    /// Replace meal in plan
    func replaceMeal(
        planId: String,
        day: Int,
        slot: MealSlotType,
        recipeId: String
    ) async throws -> MealPlan
    
    /// Update meal serving size
    func updateMealServing(
        planId: String,
        mealSlotId: String,
        servingSize: Double
    ) async throws -> MealPlan
    
    /// Get meal recommendations for specific slot
    func getMealRecommendations(
        planId: String,
        day: Int,
        slot: MealSlotType
    ) async throws -> [Recipe]
    
    /// Delete meal plan
    func deleteMealPlan(id: String) async throws
    
    // MARK: - Shopping Lists
    
    /// Get shopping list for meal plan
    func getShoppingList(planId: String) async throws -> ShoppingList
    
    /// Compare prices across stores
    func priceCompare(listId: String, stores: [String]) async throws -> ShoppingList
    
    /// Update item purchased status
    func updateItemPurchased(listId: String, itemId: String, purchased: Bool) async throws
    
    /// Create shopping order
    func createShoppingOrder(
        listId: String,
        storeId: String,
        fulfillmentType: FulfillmentType
    ) async throws -> ShoppingOrder
    
    /// Get shopping order status
    func getShoppingOrder(id: String) async throws -> ShoppingOrder
    
    // MARK: - AI Assistant
    
    /// Chat with AI assistant
    func aiChat(
        messages: [AIMessage],
        context: [String: Any]
    ) async throws -> AIReply
    
    /// Get nutrition advice for body regions/symptoms
    func getNutritionAdvice(
        bodyRegions: [BodyRegion],
        symptoms: [String],
        preferences: MealPlanPreferences
    ) async throws -> NutritionAdvice
    
    // MARK: - Health Integration
    
    /// Get/update user's health profile
    func getHealthProfile() async throws -> HealthProfile?
    func updateHealthProfile(_ profile: HealthProfile) async throws
    
    /// Sync meal plan nutrition to health tracking
    func syncNutritionToHealth(planId: String) async throws
    
    // MARK: - User Preferences
    
    /// Get user's meal planning preferences
    func getUserPreferences() async throws -> MealPlanPreferences?
    
    /// Update user's meal planning preferences
    func updateUserPreferences(_ preferences: MealPlanPreferences) async throws
    
    // MARK: - Integrations
    
    /// Request ride for grocery pickup/delivery
    func requestGroceryRide(
        orderId: String,
        pickupWindow: TimeRange
    ) async throws -> String // returns rideId
    
    /// Share meal plan or recipe with friends
    func shareMealContent(
        contentType: ShareContentType,
        contentId: String,
        recipientIds: [String],
        message: String?
    ) async throws
    
    // MARK: - Real-time Updates
    
    /// Publisher for meal plan updates
    var mealPlanUpdates: AnyPublisher<MealPlan, Never> { get }
    
    /// Publisher for shopping list updates
    var shoppingListUpdates: AnyPublisher<ShoppingList, Never> { get }
    
    /// Publisher for recipe import progress
    var recipeImportProgress: AnyPublisher<ImportProgress, Never> { get }
    
    /// Publisher for meal plan generation progress
    var planGenerationProgress: AnyPublisher<PlanGenerationProgress, Never> { get }
}

// MARK: - Supporting Types

public struct RecipeFilters: Codable, Hashable {
    public let cuisines: [String]?
    public let dietary: [DietaryRestriction]?
    public let maxPrepTime: Int?
    public let maxCookTime: Int?
    public let difficulty: DifficultyLevel?
    public let tags: [String]?
    
    public init(
        cuisines: [String]? = nil,
        dietary: [DietaryRestriction]? = nil,
        maxPrepTime: Int? = nil,
        maxCookTime: Int? = nil,
        difficulty: DifficultyLevel? = nil,
        tags: [String]? = nil
    ) {
        self.cuisines = cuisines
        self.dietary = dietary
        self.maxPrepTime = maxPrepTime
        self.maxCookTime = maxCookTime
        self.difficulty = difficulty
        self.tags = tags
    }
}

public struct SuggestionCriteria: Codable, Hashable {
    public let mealSlot: MealSlotType?
    public let dietary: [DietaryRestriction]
    public let allergies: [Allergen]
    public let cuisines: [String]
    public let maxTimeMinutes: Int?
    public let nutritionFocus: [String]
    public let excludeRecipeIds: [String]
    
    public init(
        mealSlot: MealSlotType? = nil,
        dietary: [DietaryRestriction] = [],
        allergies: [Allergen] = [],
        cuisines: [String] = [],
        maxTimeMinutes: Int? = nil,
        nutritionFocus: [String] = [],
        excludeRecipeIds: [String] = []
    ) {
        self.mealSlot = mealSlot
        self.dietary = dietary
        self.allergies = allergies
        self.cuisines = cuisines
        self.maxTimeMinutes = maxTimeMinutes
        self.nutritionFocus = nutritionFocus
        self.excludeRecipeIds = excludeRecipeIds
    }
}

public enum ShareContentType: String, Codable, CaseIterable {
    case recipe
    case mealPlan
    case shoppingList
}

public struct ImportProgress: Codable, Hashable {
    public let recipeId: String
    public let stage: ImportStage
    public let progress: Double // 0.0 to 1.0
    public let message: String
    public let error: String?
    
    public init(
        recipeId: String,
        stage: ImportStage,
        progress: Double,
        message: String,
        error: String? = nil
    ) {
        self.recipeId = recipeId
        self.stage = stage
        self.progress = progress
        self.message = message
        self.error = error
    }
}

public enum ImportStage: String, Codable, CaseIterable {
    case fetching = "fetching"
    case extracting = "extracting"
    case transcribing = "transcribing"
    case segmenting = "segmenting"
    case analyzing = "analyzing"
    case completed = "completed"
    case failed = "failed"
}

public struct PlanGenerationProgress: Codable, Hashable {
    public let planId: String
    public let stage: PlanGenerationStage
    public let progress: Double // 0.0 to 1.0
    public let message: String
    public let error: String?
    
    public init(
        planId: String,
        stage: PlanGenerationStage,
        progress: Double,
        message: String,
        error: String? = nil
    ) {
        self.planId = planId
        self.stage = stage
        self.progress = progress
        self.message = message
        self.error = error
    }
}

public enum PlanGenerationStage: String, Codable, CaseIterable {
    case analyzing = "analyzing"
    case searching = "searching"
    case optimizing = "optimizing"
    case validating = "validating"
    case finalizing = "finalizing"
    case completed = "completed"
    case failed = "failed"
}