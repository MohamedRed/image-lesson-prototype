import Foundation
import Combine

public final class MockMealPlanningService: MealPlanningServicing {
    
    public var currentUserId: String? { "current_user" }
    
    // MARK: - Feature Flags
    
    private let featureFlags: MealPlanningFeatureFlags
    
    // MARK: - Publishers
    
    private let mealPlanSubject = PassthroughSubject<MealPlan, Never>()
    private let shoppingListSubject = PassthroughSubject<ShoppingList, Never>()
    private let importProgressSubject = PassthroughSubject<ImportProgress, Never>()
    private let planProgressSubject = PassthroughSubject<PlanGenerationProgress, Never>()
    
    public var mealPlanUpdates: AnyPublisher<MealPlan, Never> { mealPlanSubject.eraseToAnyPublisher() }
    public var shoppingListUpdates: AnyPublisher<ShoppingList, Never> { shoppingListSubject.eraseToAnyPublisher() }
    public var recipeImportProgress: AnyPublisher<ImportProgress, Never> { importProgressSubject.eraseToAnyPublisher() }
    public var planGenerationProgress: AnyPublisher<PlanGenerationProgress, Never> { planProgressSubject.eraseToAnyPublisher() }
    
    // MARK: - Mock Data Storage
    
    private var mockRecipes: [Recipe] = []
    private var mockMealPlans: [MealPlan] = []
    private var mockShoppingLists: [ShoppingList] = []
    private var mockUserPreferences: MealPlanPreferences?
    private var mockHealthProfile: HealthProfile?
    
    public init(featureFlags: MealPlanningFeatureFlags = .allEnabled) {
        self.featureFlags = featureFlags
        seedMockData()
    }
    
    // MARK: - Feature Flag Validation
    
    private func validateFeature(_ flag: Bool, feature: String) throws {
        if !flag {
            throw MealPlanningError.featureNotEnabled(feature)
        }
    }
    
    private func seedMockData() {
        // Seed some sample recipes
        mockRecipes = [
            Recipe(
                id: "recipe_1",
                title: "Moroccan Tagine",
                description: "Traditional slow-cooked stew with tender lamb and vegetables",
                images: ["https://example.com/tagine.jpg"],
                videoUrl: "https://youtube.com/watch?v=tagine123",
                sourcePlatform: .youtube,
                sourceAuthor: "Chef Amina",
                sourceAttribution: "@chef_amina",
                tags: ["traditional", "comfort"],
                cuisines: ["Moroccan", "North African"],
                steps: [
                    RecipeStep(
                        stepNumber: 1,
                        startTime: 0,
                        endTime: 120,
                        instruction: "Heat olive oil in a large tagine or heavy pot over medium heat",
                        shortInstruction: "Heat oil",
                        utensilRefs: ["tagine", "wooden_spoon"],
                        timerSeconds: nil
                    ),
                    RecipeStep(
                        stepNumber: 2,
                        startTime: 120,
                        endTime: 300,
                        instruction: "Brown the lamb pieces on all sides, about 3 minutes per side",
                        shortInstruction: "Brown lamb",
                        utensilRefs: ["tagine"],
                        timerSeconds: 180
                    )
                ],
                ingredients: [
                    Ingredient(
                        name: "Lamb shoulder",
                        quantity: 1.5,
                        unit: "kg",
                        category: .meat
                    ),
                    Ingredient(
                        name: "Olive oil",
                        quantity: 3,
                        unit: "tbsp",
                        category: .pantry
                    ),
                    Ingredient(
                        name: "Onions",
                        quantity: 2,
                        unit: "medium",
                        category: .produce
                    )
                ],
                utensils: [
                    Utensil(name: "Tagine pot", category: .cookware),
                    Utensil(name: "Wooden spoon", category: .handTools)
                ],
                nutrition: NutrientProfile(
                    calories: 425,
                    macros: Macronutrients(protein: 35, carbs: 15, fat: 28, fiber: 4)
                ),
                servings: 4,
                prepTimeMinutes: 20,
                cookTimeMinutes: 120,
                totalTimeMinutes: 140,
                difficultyLevel: .intermediate
            ),
            
            Recipe(
                id: "recipe_2",
                title: "Avocado Toast",
                description: "Simple and nutritious breakfast with smashed avocado",
                images: ["https://example.com/avocado_toast.jpg"],
                sourcePlatform: .web,
                sourceAuthor: "Healthy Kitchen",
                tags: ["quick", "healthy", "vegetarian"],
                cuisines: ["International"],
                steps: [
                    RecipeStep(
                        stepNumber: 1,
                        instruction: "Toast the bread slices until golden brown",
                        shortInstruction: "Toast bread",
                        utensilRefs: ["toaster"],
                        timerSeconds: 120
                    ),
                    RecipeStep(
                        stepNumber: 2,
                        instruction: "Mash the avocado with a fork and season with salt and pepper",
                        shortInstruction: "Mash avocado",
                        utensilRefs: ["fork", "bowl"]
                    )
                ],
                ingredients: [
                    Ingredient(name: "Bread slices", quantity: 2, unit: "slices", category: .pantry),
                    Ingredient(name: "Avocado", quantity: 1, unit: "medium", category: .produce),
                    Ingredient(name: "Salt", quantity: 0.25, unit: "tsp", category: .spices),
                    Ingredient(name: "Black pepper", quantity: 0.125, unit: "tsp", category: .spices)
                ],
                utensils: [
                    Utensil(name: "Toaster", category: .smallAppliances),
                    Utensil(name: "Fork", category: .handTools),
                    Utensil(name: "Small bowl", category: .cookware)
                ],
                nutrition: NutrientProfile(
                    calories: 280,
                    macros: Macronutrients(protein: 8, carbs: 30, fat: 18, fiber: 12)
                ),
                servings: 1,
                prepTimeMinutes: 5,
                cookTimeMinutes: 2,
                totalTimeMinutes: 7,
                difficultyLevel: .beginner
            ),
            
            Recipe(
                id: "recipe_3",
                title: "Mediterranean Quinoa Bowl",
                description: "Nutritious bowl with quinoa, vegetables, and tahini dressing",
                images: ["https://example.com/quinoa_bowl.jpg"],
                sourcePlatform: .instagram,
                sourceAuthor: "Mediterranean Eats",
                sourceAttribution: "@med_eats",
                tags: ["healthy", "vegetarian", "protein"],
                cuisines: ["Mediterranean"],
                steps: [
                    RecipeStep(
                        stepNumber: 1,
                        instruction: "Cook quinoa according to package directions",
                        shortInstruction: "Cook quinoa",
                        timerSeconds: 900
                    )
                ],
                ingredients: [
                    Ingredient(name: "Quinoa", quantity: 1, unit: "cup", category: .pantry),
                    Ingredient(name: "Cucumber", quantity: 1, unit: "medium", category: .produce),
                    Ingredient(name: "Cherry tomatoes", quantity: 1, unit: "cup", category: .produce),
                    Ingredient(name: "Tahini", quantity: 2, unit: "tbsp", category: .condiments)
                ],
                utensils: [
                    Utensil(name: "Medium saucepan", category: .cookware),
                    Utensil(name: "Serving bowl", category: .cookware)
                ],
                nutrition: NutrientProfile(
                    calories: 385,
                    macros: Macronutrients(protein: 14, carbs: 52, fat: 16, fiber: 8)
                ),
                servings: 2,
                prepTimeMinutes: 15,
                cookTimeMinutes: 15,
                totalTimeMinutes: 30,
                difficultyLevel: .beginner
            )
        ]
        
        // Create sample preferences
        mockUserPreferences = MealPlanPreferences(
            dietary: [.vegetarian],
            allergies: [.nuts],
            macroTargets: MacroTargets(dailyCalories: 2000, proteinGrams: 100),
            timeBudgetMinutes: 45,
            costBudgetRange: MoneyRange(min: 200, max: 400),
            cuisines: ["Moroccan", "Mediterranean", "International"],
            weekendComplexityHigh: true,
            leftoversPolicy: .moderate
        )
        
        // Create sample health profile
        mockHealthProfile = HealthProfile(
            userId: currentUserId ?? "",
            trackedNutrients: ["protein", "fiber", "vitamin_d"],
            goals: [
                HealthGoal(type: .weightLoss, target: 0.5, unit: "kg", timeframe: .weekly),
                HealthGoal(type: .energyBoost, target: 1, unit: "level", timeframe: .daily)
            ],
            bodyRegionConcerns: [
                BodyRegion(
                    name: "Digestive System",
                    anatomicalId: "digestive",
                    concernLevel: .medium,
                    relatedNutrients: ["fiber", "probiotics"]
                )
            ],
            medicalDisclaimer: true
        )
    }
    
    // MARK: - Recipe Management
    
    public func importRecipe(from url: String) async throws -> String {
        try validateFeature(featureFlags.recipeImport, feature: "Recipe Import")
        try await simulateNetworkDelay()
        
        let recipeId = "imported_\(UUID().uuidString)"
        
        // Simulate import progress
        let stages: [ImportStage] = [.fetching, .extracting, .transcribing, .segmenting, .analyzing, .completed]
        
        for (index, stage) in stages.enumerated() {
            let progress = Double(index) / Double(stages.count - 1)
            let progressUpdate = ImportProgress(
                recipeId: recipeId,
                stage: stage,
                progress: progress,
                message: "Processing \(stage.rawValue)..."
            )
            importProgressSubject.send(progressUpdate)
            
            if stage != .completed {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }
        }
        
        // Create mock imported recipe
        let importedRecipe = Recipe(
            id: recipeId,
            title: "Imported Recipe from \(url)",
            description: "A delicious recipe imported from social media",
            images: ["https://example.com/imported.jpg"],
            videoUrl: url,
            sourcePlatform: url.contains("instagram") ? .instagram :
                           url.contains("tiktok") ? .tiktok :
                           url.contains("youtube") ? .youtube : .web,
            sourceAuthor: "Content Creator",
            tags: ["imported", "trendy"],
            cuisines: ["International"],
            steps: [
                RecipeStep(
                    stepNumber: 1,
                    instruction: "Follow the video instructions",
                    shortInstruction: "Follow video"
                )
            ],
            ingredients: [
                Ingredient(name: "Main ingredient", quantity: 1, unit: "piece")
            ],
            utensils: [
                Utensil(name: "Basic utensil", category: .handTools)
            ],
            nutrition: NutrientProfile(
                calories: 300,
                macros: Macronutrients(protein: 15, carbs: 30, fat: 15)
            ),
            servings: 2,
            prepTimeMinutes: 10,
            cookTimeMinutes: 20,
            totalTimeMinutes: 30,
            difficultyLevel: .intermediate
        )
        
        mockRecipes.append(importedRecipe)
        return recipeId
    }
    
    public func getRecipe(id: String) async throws -> Recipe {
        try await simulateNetworkDelay()
        
        guard let recipe = mockRecipes.first(where: { $0.id == id }) else {
            throw MealPlanningError.recipeNotFound(id)
        }
        return recipe
    }
    
    public func searchRecipes(query: String, filters: RecipeFilters?) async throws -> [Recipe] {
        try await simulateNetworkDelay()
        
        let lowercaseQuery = query.lowercased()
        return mockRecipes.filter { recipe in
            recipe.title.lowercased().contains(lowercaseQuery) ||
            recipe.description.lowercased().contains(lowercaseQuery) ||
            recipe.tags.contains { $0.lowercased().contains(lowercaseQuery) } ||
            recipe.cuisines.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    public func getMyRecipes() async throws -> [Recipe] {
        try await simulateNetworkDelay()
        return mockRecipes
    }
    
    public func saveRecipe(_ recipe: Recipe) async throws {
        try await simulateNetworkDelay()
        
        if let index = mockRecipes.firstIndex(where: { $0.id == recipe.id }) {
            mockRecipes[index] = recipe
        } else {
            mockRecipes.append(recipe)
        }
    }
    
    public func removeRecipe(id: String) async throws {
        try await simulateNetworkDelay()
        mockRecipes.removeAll { $0.id == id }
    }
    
    public func getRecipeSuggestions(criteria: SuggestionCriteria) async throws -> [Recipe] {
        try await simulateNetworkDelay()
        
        // Filter by dietary restrictions and other criteria
        return mockRecipes.filter { recipe in
            // Simple filtering logic for mock
            if let maxTime = criteria.maxTimeMinutes {
                return recipe.totalTimeMinutes <= maxTime
            }
            return true
        }.prefix(5).map { $0 }
    }
    
    // MARK: - Meal Planning
    
    public func generateMealPlan(criteria: PlanCriteria) async throws -> String {
        try validateFeature(featureFlags.mealPlanGeneration, feature: "Meal Plan Generation")
        try await simulateNetworkDelay()
        
        let planId = "plan_\(UUID().uuidString)"
        
        // Simulate plan generation progress
        let stages: [PlanGenerationStage] = [.analyzing, .searching, .optimizing, .validating, .finalizing, .completed]
        
        for (index, stage) in stages.enumerated() {
            let progress = Double(index) / Double(stages.count - 1)
            let progressUpdate = PlanGenerationProgress(
                planId: planId,
                stage: stage,
                progress: progress,
                message: "Working on \(stage.rawValue)..."
            )
            planProgressSubject.send(progressUpdate)
            
            if stage != .completed {
                try await Task.sleep(nanoseconds: 750_000_000) // 0.75s
            }
        }
        
        // Create mock meal plan
        let startDate = criteria.weekStartDate
        var days: [DayPlan] = []
        
        for dayOffset in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: startDate)!
            let dayOfWeek = Calendar.current.component(.weekday, from: date) - 1 // 0 = Sunday
            
            let meals = [
                MealSlot(
                    type: .breakfast,
                    recipeId: "recipe_2",
                    recipe: mockRecipes.first { $0.id == "recipe_2" },
                    plannedTime: "08:00"
                ),
                MealSlot(
                    type: .lunch,
                    recipeId: "recipe_3",
                    recipe: mockRecipes.first { $0.id == "recipe_3" },
                    plannedTime: "13:00"
                ),
                MealSlot(
                    type: .dinner,
                    recipeId: "recipe_1",
                    recipe: mockRecipes.first { $0.id == "recipe_1" },
                    plannedTime: "19:00"
                )
            ]
            
            days.append(DayPlan(
                dayOfWeek: dayOfWeek,
                date: date,
                meals: meals,
                dailyNutrition: NutrientProfile(
                    calories: 1090,
                    macros: Macronutrients(protein: 57, carbs: 97, fat: 62, fiber: 24)
                )
            ))
        }
        
        let mealPlan = MealPlan(
            id: planId,
            userId: currentUserId ?? "",
            weekStartDate: startDate,
            preferences: criteria.preferences,
            days: days,
            optimizationMetadata: OptimizationMetadata(
                totalScore: 0.85,
                costScore: 0.8,
                timeScore: 0.9,
                varietyScore: 0.85,
                constraintsSatisfied: ["dietary", "time_budget", "allergies"],
                alternativeCount: 3,
                generationTimeSeconds: 3.75
            ),
            status: .active
        )
        
        mockMealPlans.append(mealPlan)
        mealPlanSubject.send(mealPlan)
        
        return planId
    }
    
    public func getMealPlan(id: String) async throws -> MealPlan {
        try await simulateNetworkDelay()
        
        guard let plan = mockMealPlans.first(where: { $0.id == id }) else {
            throw MealPlanningError.mealPlanNotFound(id)
        }
        return plan
    }
    
    public func getMyMealPlans() async throws -> [MealPlan] {
        try await simulateNetworkDelay()
        return mockMealPlans
    }
    
    public func replaceMeal(planId: String, day: Int, slot: MealSlotType, recipeId: String) async throws -> MealPlan {
        try await simulateNetworkDelay()
        
        guard let planIndex = mockMealPlans.firstIndex(where: { $0.id == planId }) else {
            throw MealPlanningError.mealPlanNotFound(planId)
        }
        
        var plan = mockMealPlans[planIndex]
        
        if let dayIndex = plan.days.firstIndex(where: { $0.dayOfWeek == day }),
           let mealIndex = plan.days[dayIndex].meals.firstIndex(where: { $0.type == slot }),
           let recipe = mockRecipes.first(where: { $0.id == recipeId }) {
            
            var updatedDay = plan.days[dayIndex]
            var updatedMeals = updatedDay.meals
            updatedMeals[mealIndex] = MealSlot(
                type: slot,
                recipeId: recipeId,
                recipe: recipe,
                servingSize: updatedMeals[mealIndex].servingSize,
                plannedTime: updatedMeals[mealIndex].plannedTime
            )
            
            updatedDay = DayPlan(
                id: updatedDay.id,
                dayOfWeek: updatedDay.dayOfWeek,
                date: updatedDay.date,
                meals: updatedMeals,
                dailyNutrition: updatedDay.dailyNutrition
            )
            
            var updatedDays = plan.days
            updatedDays[dayIndex] = updatedDay
            
            plan = MealPlan(
                id: plan.id,
                userId: plan.userId,
                weekStartDate: plan.weekStartDate,
                preferences: plan.preferences,
                days: updatedDays,
                optimizationMetadata: plan.optimizationMetadata,
                shoppingListId: plan.shoppingListId,
                status: plan.status,
                createdAt: plan.createdAt,
                updatedAt: Date()
            )
        }
        
        mockMealPlans[planIndex] = plan
        mealPlanSubject.send(plan)
        return plan
    }
    
    public func updateMealServing(planId: String, mealSlotId: String, servingSize: Double) async throws -> MealPlan {
        try await simulateNetworkDelay()
        
        guard let planIndex = mockMealPlans.firstIndex(where: { $0.id == planId }) else {
            throw MealPlanningError.mealPlanNotFound(planId)
        }
        
        var plan = mockMealPlans[planIndex]
        // Implementation would update the specific meal slot serving size
        // For mock, just return the plan
        mockMealPlans[planIndex] = plan
        return plan
    }
    
    public func getMealRecommendations(planId: String, day: Int, slot: MealSlotType) async throws -> [Recipe] {
        try await simulateNetworkDelay()
        return Array(mockRecipes.prefix(3))
    }
    
    public func deleteMealPlan(id: String) async throws {
        try await simulateNetworkDelay()
        mockMealPlans.removeAll { $0.id == id }
    }
    
    // MARK: - Shopping Lists
    
    public func getShoppingList(planId: String) async throws -> ShoppingList {
        try await simulateNetworkDelay()
        
        // Create mock shopping list based on meal plan
        let groceryItems = [
            GroceryItem(
                ingredientKey: "lamb_shoulder",
                displayName: "Lamb Shoulder",
                totalQuantity: 1.5,
                unit: "kg",
                category: .meat,
                priceEstimates: [
                    StorePrice(storeId: "marjane", storeName: "Marjane", price: Money(amount: 180.0)),
                    StorePrice(storeId: "carrefour", storeName: "Carrefour", price: Money(amount: 175.0))
                ]
            ),
            GroceryItem(
                ingredientKey: "avocado",
                displayName: "Avocados",
                totalQuantity: 3,
                unit: "pieces",
                category: .produce,
                priceEstimates: [
                    StorePrice(storeId: "marjane", storeName: "Marjane", price: Money(amount: 15.0)),
                    StorePrice(storeId: "carrefour", storeName: "Carrefour", price: Money(amount: 12.0))
                ]
            )
        ]
        
        let shoppingList = ShoppingList(
            id: "list_\(planId)",
            mealPlanId: planId,
            userId: currentUserId ?? "",
            normalizedItems: groceryItems,
            estimatedTotal: Money(amount: 187.0),
            stores: [
                StoreInfo(
                    id: "marjane",
                    name: "Marjane",
                    address: "Hay Riad, Rabat",
                    coordinates: Coordinates(latitude: 34.0105, longitude: -6.8326),
                    pickupAvailable: true,
                    deliveryAvailable: true,
                    estimatedTotal: Money(amount: 195.0),
                    estimatedPickupTime: "2 hours",
                    estimatedDeliveryTime: "3-5 hours"
                ),
                StoreInfo(
                    id: "carrefour",
                    name: "Carrefour",
                    address: "Agdal, Rabat",
                    coordinates: Coordinates(latitude: 34.0081, longitude: -6.8498),
                    pickupAvailable: true,
                    deliveryAvailable: false,
                    estimatedTotal: Money(amount: 187.0),
                    estimatedPickupTime: "1.5 hours"
                )
            ]
        )
        
        if !mockShoppingLists.contains(where: { $0.id == shoppingList.id }) {
            mockShoppingLists.append(shoppingList)
        }
        
        return shoppingList
    }
    
    public func priceCompare(listId: String, stores: [String]) async throws -> ShoppingList {
        try validateFeature(featureFlags.priceComparison, feature: "Price Comparison")
        try await simulateNetworkDelay(0.75)
        
        guard let listIndex = mockShoppingLists.firstIndex(where: { $0.id == listId }) else {
            throw MealPlanningError.shoppingListNotFound(listId)
        }
        
        var list = mockShoppingLists[listIndex]
        // Mock implementation would update prices
        mockShoppingLists[listIndex] = list
        shoppingListSubject.send(list)
        return list
    }
    
    public func updateItemPurchased(listId: String, itemId: String, purchased: Bool) async throws {
        try await simulateNetworkDelay(0.25)
        
        if let listIndex = mockShoppingLists.firstIndex(where: { $0.id == listId }),
           let itemIndex = mockShoppingLists[listIndex].normalizedItems.firstIndex(where: { $0.id == itemId }) {
            
            var list = mockShoppingLists[listIndex]
            var items = list.normalizedItems
            let item = items[itemIndex]
            
            items[itemIndex] = GroceryItem(
                id: item.id,
                ingredientKey: item.ingredientKey,
                displayName: item.displayName,
                totalQuantity: item.totalQuantity,
                unit: item.unit,
                category: item.category,
                preferredBrands: item.preferredBrands,
                substitutions: item.substitutions,
                storeMappings: item.storeMappings,
                priceEstimates: item.priceEstimates,
                recipeReferences: item.recipeReferences,
                isPurchased: purchased,
                notes: item.notes
            )
            
            list = ShoppingList(
                id: list.id,
                mealPlanId: list.mealPlanId,
                userId: list.userId,
                normalizedItems: items,
                estimatedTotal: list.estimatedTotal,
                stores: list.stores,
                status: list.status,
                createdAt: list.createdAt,
                updatedAt: Date()
            )
            
            mockShoppingLists[listIndex] = list
            shoppingListSubject.send(list)
        }
    }
    
    public func createShoppingOrder(listId: String, storeId: String, fulfillmentType: FulfillmentType) async throws -> ShoppingOrder {
        try await simulateNetworkDelay()
        
        guard let list = mockShoppingLists.first(where: { $0.id == listId }),
              let store = list.stores.first(where: { $0.id == storeId }) else {
            throw MealPlanningError.shoppingListNotFound(listId)
        }
        
        let orderItems = list.normalizedItems.map { item in
            OrderItem(
                sku: "sku_\(item.id)",
                productName: item.displayName,
                quantity: Int(item.totalQuantity),
                unitPrice: item.priceEstimates.first(where: { $0.storeId == storeId })?.price ?? Money(amount: 10.0),
                totalPrice: Money(amount: (item.priceEstimates.first(where: { $0.storeId == storeId })?.price.amount ?? 10.0) * item.totalQuantity)
            )
        }
        
        return ShoppingOrder(
            id: "order_\(UUID().uuidString)",
            shoppingListId: listId,
            storeId: storeId,
            items: orderItems,
            total: store.estimatedTotal ?? Money(amount: 200.0),
            fulfillmentType: fulfillmentType,
            status: .confirmed,
            estimatedReadyAt: Date().addingTimeInterval(fulfillmentType == .delivery ? 10800 : 7200) // 3h delivery, 2h pickup
        )
    }
    
    public func getShoppingOrder(id: String) async throws -> ShoppingOrder {
        try await simulateNetworkDelay()
        // Mock implementation - would fetch from storage
        throw MealPlanningError.orderNotFound(id)
    }
    
    // MARK: - AI Assistant
    
    public func aiChat(messages: [AIMessage], context: [String: Any]) async throws -> AIReply {
        try validateFeature(featureFlags.aiAssistant, feature: "AI Assistant")
        try await simulateNetworkDelay(1.0)
        
        let lastMessage = messages.last?.content ?? ""
        let lowercaseMessage = lastMessage.lowercased()
        
        var suggestedRecipes: [Recipe] = []
        var suggestedEdits: [MealPlanEdit] = []
        var response = ""
        
        if lowercaseMessage.contains("swap") || lowercaseMessage.contains("replace") {
            response = "I can help you swap meals in your plan. Which day and meal would you like to replace?"
            suggestedEdits = [
                MealPlanEdit(
                    type: .replace,
                    day: 2,
                    mealSlot: .dinner,
                    newRecipeId: "recipe_2",
                    reason: "Based on your request"
                )
            ]
        } else if lowercaseMessage.contains("recipe") || lowercaseMessage.contains("suggest") {
            response = "Here are some recipe suggestions based on your preferences:"
            suggestedRecipes = Array(mockRecipes.prefix(2))
        } else if lowercaseMessage.contains("price") || lowercaseMessage.contains("cost") {
            response = "I can help you compare prices across different stores. Would you like me to check current prices for your shopping list?"
        } else {
            response = "I'm here to help with your meal planning! You can ask me to suggest recipes, swap meals, compare prices, or adjust your meal plan."
        }
        
        return AIReply(
            content: response,
            suggestedRecipes: suggestedRecipes,
            suggestedEdits: suggestedEdits,
            followUpQuestions: [
                "Would you like to see more recipe options?",
                "Should I update your meal plan with these changes?"
            ],
            confidence: 0.8
        )
    }
    
    public func getNutritionAdvice(bodyRegions: [BodyRegion], symptoms: [String], preferences: MealPlanPreferences) async throws -> NutritionAdvice {
        try await simulateNetworkDelay(1.5)
        
        // Mock nutrition advice based on body regions
        let recommendedNutrients = bodyRegions.contains { $0.anatomicalId == "digestive" } ?
            ["fiber", "probiotics", "omega_3"] :
            ["vitamin_d", "vitamin_c", "magnesium"]
        
        let suggestedRecipes = mockRecipes.filter { recipe in
            recipe.tags.contains("healthy") || recipe.nutrition?.macros.fiber ?? 0 > 5
        }
        
        return NutritionAdvice(
            bodyRegions: bodyRegions,
            recommendedNutrients: recommendedNutrients,
            avoidedIngredients: ["processed_sugar", "artificial_additives"],
            suggestedRecipes: Array(suggestedRecipes.prefix(3)),
            planCriteria: PlanCriteria(preferences: preferences, weekStartDate: Date()),
            disclaimer: "This advice is for wellness purposes only and not a substitute for professional medical advice."
        )
    }
    
    // MARK: - Health Integration
    
    public func getHealthProfile() async throws -> HealthProfile? {
        try await simulateNetworkDelay()
        return mockHealthProfile
    }
    
    public func updateHealthProfile(_ profile: HealthProfile) async throws {
        try await simulateNetworkDelay()
        mockHealthProfile = profile
    }
    
    public func syncNutritionToHealth(planId: String) async throws {
        try await simulateNetworkDelay()
        // Mock implementation - would sync to Health app or service
    }
    
    // MARK: - User Preferences
    
    public func getUserPreferences() async throws -> MealPlanPreferences? {
        try await simulateNetworkDelay()
        return mockUserPreferences
    }
    
    public func updateUserPreferences(_ preferences: MealPlanPreferences) async throws {
        try await simulateNetworkDelay()
        mockUserPreferences = preferences
    }
    
    // MARK: - Integrations
    
    public func requestGroceryRide(orderId: String, pickupWindow: TimeRange) async throws -> String {
        try await simulateNetworkDelay()
        // Mock ride request - would integrate with RideSharingService
        return "ride_\(UUID().uuidString)"
    }
    
    public func shareMealContent(contentType: ShareContentType, contentId: String, recipientIds: [String], message: String?) async throws {
        try await simulateNetworkDelay()
        // Mock sharing - would integrate with FriendsService
    }
    
    // MARK: - Helper
    
    private func simulateNetworkDelay(_ seconds: Double = 0.5) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - Errors
// Use MealPlanningError from Models