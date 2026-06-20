import SwiftUI
import Combine
import MealPlanningService

@MainActor
public final class MealPlanningViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var myRecipes: [Recipe] = []
    @Published var myMealPlans: [MealPlan] = []
    @Published var currentMealPlan: MealPlan?
    @Published var currentShoppingList: ShoppingList?
    @Published var searchResults: [Recipe] = []
    @Published var recipeSuggestions: [Recipe] = []
    @Published var aiMessages: [AIMessage] = []
    @Published var aiResponse: AIReply?
    @Published var healthProfile: HealthProfile?
    @Published var userPreferences: MealPlanPreferences?
    
    // MARK: - UI State
    
    @Published var isLoading = false
    @Published var isImporting = false
    @Published var isGeneratingPlan = false
    @Published var isSearching = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var searchQuery = ""
    @Published var showRecipeDetail = false
    @Published var showPlanDetail = false
    @Published var showShoppingList = false
    @Published var showAIAssistant = false
    @Published var showHealthProfile = false
    @Published var selectedRecipe: Recipe?
    
    // Progress tracking
    @Published var importProgress: ImportProgress?
    @Published var planGenerationProgress: PlanGenerationProgress?
    
    // MARK: - Services
    
    private let mealPlanningService: MealPlanningServicing
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(mealPlanningService: MealPlanningServicing? = nil) {
        self.mealPlanningService = mealPlanningService ?? MealPlanningServiceFactory.createService()
        setupSubscriptions()
    }
    
    // MARK: - Accessors
    
    public var currentUserId: String? {
        mealPlanningService.currentUserId
    }
    
    // MARK: - Setup
    
    private func setupSubscriptions() {
        // Real-time updates
        mealPlanningService.mealPlanUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedPlan in
                self?.handleMealPlanUpdate(updatedPlan)
            }
            .store(in: &cancellables)
        
        mealPlanningService.shoppingListUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedList in
                self?.handleShoppingListUpdate(updatedList)
            }
            .store(in: &cancellables)
        
        mealPlanningService.recipeImportProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.importProgress = progress
                if progress.stage == .completed {
                    self?.isImporting = false
                    Task { await self?.loadMyRecipes() }
                } else if progress.stage == .failed {
                    self?.isImporting = false
                    self?.showError(progress.error ?? "Import failed")
                }
            }
            .store(in: &cancellables)
        
        mealPlanningService.planGenerationProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.planGenerationProgress = progress
                if progress.stage == .completed {
                    self?.isGeneratingPlan = false
                    Task { await self?.loadMyMealPlans() }
                } else if progress.stage == .failed {
                    self?.isGeneratingPlan = false
                    self?.showError(progress.error ?? "Plan generation failed")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMyRecipes() }
            group.addTask { await self.loadMyMealPlans() }
            group.addTask { await self.loadUserPreferences() }
            group.addTask { await self.loadHealthProfile() }
        }
    }
    
    func loadMyRecipes() async {
        do {
            let recipes = try await mealPlanningService.getMyRecipes()
            myRecipes = recipes
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func loadMyMealPlans() async {
        do {
            let plans = try await mealPlanningService.getMyMealPlans()
            myMealPlans = plans
            
            // Set current plan to the most recent active one
            currentMealPlan = plans.first { $0.status == .active } ?? plans.first
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func loadUserPreferences() async {
        do {
            userPreferences = try await mealPlanningService.getUserPreferences()
        } catch {
            // Create default preferences if none exist
            userPreferences = MealPlanPreferences()
        }
    }
    
    func loadHealthProfile() async {
        do {
            healthProfile = try await mealPlanningService.getHealthProfile()
        } catch {
            // Health profile is optional
        }
    }
    
    // MARK: - Recipe Management
    
    func importRecipe(from url: String) async {
        isImporting = true
        importProgress = nil
        
        do {
            let recipeId = try await mealPlanningService.importRecipe(from: url)
            // Progress updates will come via publisher
        } catch {
            isImporting = false
            showError(error.localizedDescription)
        }
    }
    
    func searchRecipes(_ query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchQuery = query
        
        do {
            let results = try await mealPlanningService.searchRecipes(query: query, filters: nil)
            searchResults = results
        } catch {
            showError(error.localizedDescription)
        }
        
        isSearching = false
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }
    
    func selectRecipe(_ recipe: Recipe) {
        selectedRecipe = recipe
        showRecipeDetail = true
    }
    
    func saveRecipe(_ recipe: Recipe) async {
        do {
            try await mealPlanningService.saveRecipe(recipe)
            await loadMyRecipes()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func removeRecipe(_ recipe: Recipe) async {
        guard let recipeId = recipe.id else { return }
        
        do {
            try await mealPlanningService.removeRecipe(id: recipeId)
            myRecipes.removeAll { $0.id == recipeId }
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    // MARK: - Meal Planning
    
    func generateMealPlan(preferences: MealPlanPreferences, theme: String? = nil) async {
        isGeneratingPlan = true
        planGenerationProgress = nil
        
        let criteria = PlanCriteria(
            preferences: preferences,
            weekStartDate: Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date(),
            theme: theme
        )
        
        do {
            let planId = try await mealPlanningService.generateMealPlan(criteria: criteria)
            // Progress updates will come via publisher
        } catch {
            isGeneratingPlan = false
            showError(error.localizedDescription)
        }
    }
    
    func replaceMeal(day: Int, slot: MealSlotType, with recipe: Recipe) async {
        guard let planId = currentMealPlan?.id, let recipeId = recipe.id else { return }
        
        do {
            let updatedPlan = try await mealPlanningService.replaceMeal(
                planId: planId,
                day: day,
                slot: slot,
                recipeId: recipeId
            )
            currentMealPlan = updatedPlan
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func getMealRecommendations(for day: Int, slot: MealSlotType) async {
        guard let planId = currentMealPlan?.id else { return }
        
        do {
            let recommendations = try await mealPlanningService.getMealRecommendations(
                planId: planId,
                day: day,
                slot: slot
            )
            recipeSuggestions = recommendations
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func deleteMealPlan(_ plan: MealPlan) async {
        guard let planId = plan.id else { return }
        
        do {
            try await mealPlanningService.deleteMealPlan(id: planId)
            myMealPlans.removeAll { $0.id == planId }
            
            if currentMealPlan?.id == planId {
                currentMealPlan = myMealPlans.first
            }
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    // MARK: - Shopping Lists
    
    func loadShoppingList() async {
        guard let planId = currentMealPlan?.id else { return }
        
        do {
            let shoppingList = try await mealPlanningService.getShoppingList(planId: planId)
            currentShoppingList = shoppingList
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func comparePrices(stores: [String]) async {
        guard let listId = currentShoppingList?.id else { return }
        
        isLoading = true
        
        do {
            let updatedList = try await mealPlanningService.priceCompare(listId: listId, stores: stores)
            currentShoppingList = updatedList
        } catch {
            showError(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func toggleItemPurchased(_ item: GroceryItem) async {
        guard let listId = currentShoppingList?.id else { return }
        
        do {
            try await mealPlanningService.updateItemPurchased(
                listId: listId,
                itemId: item.id,
                purchased: !item.isPurchased
            )
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func createShoppingOrder(storeId: String, fulfillmentType: FulfillmentType) async -> ShoppingOrder? {
        guard let listId = currentShoppingList?.id else { return nil }
        
        do {
            return try await mealPlanningService.createShoppingOrder(
                listId: listId,
                storeId: storeId,
                fulfillmentType: fulfillmentType
            )
        } catch {
            showError(error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - AI Assistant
    
    func sendAIMessage(_ message: String) async {
        let userMessage = AIMessage(content: message, isUser: true)
        aiMessages.append(userMessage)
        
        let context = buildAIContext()
        
        do {
            let reply = try await mealPlanningService.aiChat(messages: aiMessages, context: context)
            
            let assistantMessage = AIMessage(
                content: reply.content,
                isUser: false,
                suggestedActions: reply.suggestedEdits.map { edit in
                    AIAction(
                        type: .replaceMeal,
                        title: "Replace \(edit.mealSlot.rawValue) on day \(edit.day + 1)",
                        description: edit.reason,
                        parameters: [
                            "day": AnyCodable(edit.day),
                            "slot": AnyCodable(edit.mealSlot.rawValue),
                            "recipeId": AnyCodable(edit.newRecipeId ?? "")
                        ]
                    )
                }
            )
            
            aiMessages.append(assistantMessage)
            aiResponse = reply
            
            // Update suggestions if provided
            if !reply.suggestedRecipes.isEmpty {
                recipeSuggestions = reply.suggestedRecipes
            }
            
        } catch {
            let errorMessage = AIMessage(
                content: "I'm sorry, I couldn't process your request right now. Please try again.",
                isUser: false
            )
            aiMessages.append(errorMessage)
            showError(error.localizedDescription)
        }
    }
    
    func executeAIAction(_ action: AIAction) async {
        switch action.type {
        case .replaceMeal:
            if let dayValue = action.parameters["day"],
               let slotValue = action.parameters["slot"],
               let recipeIdValue = action.parameters["recipeId"],
               let day = dayValue as? Int,
               let slotString = slotValue as? String,
               let recipeId = recipeIdValue as? String,
               let slot = MealSlotType(rawValue: slotString),
               let recipe = myRecipes.first(where: { $0.id == recipeId }) {
                await replaceMeal(day: day, slot: slot, with: recipe)
            }
        case .regeneratePlan:
            if let preferences = userPreferences {
                await generateMealPlan(preferences: preferences)
            }
        case .priceCompare:
            await comparePrices(stores: ["marjane", "carrefour"])
        default:
            break
        }
    }
    
    // MARK: - Health Integration
    
    func getNutritionAdvice(bodyRegions: [BodyRegion], symptoms: [String]) async {
        guard let preferences = userPreferences else { return }
        
        do {
            let advice = try await mealPlanningService.getNutritionAdvice(
                bodyRegions: bodyRegions,
                symptoms: symptoms,
                preferences: preferences
            )
            
            // Update suggestions and preferences based on advice
            recipeSuggestions = advice.suggestedRecipes
            
            let assistantMessage = AIMessage(
                content: "Based on your health concerns, I recommend focusing on \(advice.recommendedNutrients.joined(separator: ", ")). Here are some suitable recipes:",
                isUser: false
            )
            aiMessages.append(assistantMessage)
            
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func syncNutritionToHealth() async {
        guard let planId = currentMealPlan?.id else { return }
        
        do {
            try await mealPlanningService.syncNutritionToHealth(planId: planId)
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    // MARK: - User Preferences
    
    func updatePreferences(_ preferences: MealPlanPreferences) async {
        do {
            try await mealPlanningService.updateUserPreferences(preferences)
            userPreferences = preferences
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func updateHealthProfile(_ profile: HealthProfile) async {
        do {
            try await mealPlanningService.updateHealthProfile(profile)
            healthProfile = profile
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    // MARK: - Integrations
    
    func requestGroceryPickup(orderId: String, pickupWindow: TimeRange) async -> String? {
        do {
            return try await mealPlanningService.requestGroceryRide(orderId: orderId, pickupWindow: pickupWindow)
        } catch {
            showError(error.localizedDescription)
            return nil
        }
    }
    
    func shareMealPlan(_ plan: MealPlan, with friendIds: [String], message: String?) async {
        guard let planId = plan.id else { return }
        
        do {
            try await mealPlanningService.shareMealContent(
                contentType: .mealPlan,
                contentId: planId,
                recipientIds: friendIds,
                message: message
            )
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func shareRecipe(_ recipe: Recipe, with friendIds: [String], message: String?) async {
        guard let recipeId = recipe.id else { return }
        
        do {
            try await mealPlanningService.shareMealContent(
                contentType: .recipe,
                contentId: recipeId,
                recipientIds: friendIds,
                message: message
            )
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleMealPlanUpdate(_ plan: MealPlan) {
        if let index = myMealPlans.firstIndex(where: { $0.id == plan.id }) {
            myMealPlans[index] = plan
        } else {
            myMealPlans.append(plan)
        }
        
        if currentMealPlan?.id == plan.id {
            currentMealPlan = plan
        }
    }
    
    private func handleShoppingListUpdate(_ list: ShoppingList) {
        if currentShoppingList?.id == list.id {
            currentShoppingList = list
        }
    }
    
    private func buildAIContext() -> [String: Any] {
        var context: [String: Any] = [:]
        
        context["recipesCount"] = myRecipes.count
        context["currentPlanExists"] = currentMealPlan != nil
        context["hasPreferences"] = userPreferences != nil
        context["hasHealthProfile"] = healthProfile != nil
        
        if let plan = currentMealPlan {
            context["currentWeek"] = Calendar.current.component(.weekOfYear, from: plan.weekStartDate)
            context["planDays"] = plan.days.count
        }
        
        return context
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    func clearError() {
        showError = false
        errorMessage = ""
    }
}