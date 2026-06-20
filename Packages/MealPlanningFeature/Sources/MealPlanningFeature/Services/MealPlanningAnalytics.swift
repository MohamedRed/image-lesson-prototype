import Foundation
import Dispatch
import MealPlanningService
import os
import SwiftUI

// Lightweight wrapper to provide closure-based async without relying on Dispatch overlay overloads
struct AnalyticsQueue {
    let underlying: DispatchQueue
    
    init(queue: DispatchQueue) {
        self.underlying = queue
    }
    
    func async(_ work: @escaping () -> Void) {
        underlying.async(execute: DispatchWorkItem(block: work))
    }
}

/// Analytics tracking for meal planning feature
public final class MealPlanningAnalytics {
    
    // MARK: - Shared Instance
    
    public static let shared = MealPlanningAnalytics()
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.liive.meal-planning", category: "analytics")
    private let queue = AnalyticsQueue(queue: DispatchQueue(label: "meal-planning-analytics", qos: .utility))
    
    private init() {}
    
    // MARK: - Recipe Events
    
    /// Track recipe import started
    public func trackRecipeImportStarted(url: String, platform: String) {
        queue.async {
            self.logEvent("recipe_import_started", parameters: [
                "url_domain": self.extractDomain(from: url),
                "platform": platform,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track recipe import completed
    public func trackRecipeImportCompleted(recipeId: String, duration: TimeInterval, platform: String) {
        queue.async {
            self.logEvent("recipe_import_completed", parameters: [
                "recipe_id": recipeId,
                "duration_seconds": String(Int(duration)),
                "platform": platform,
                "success": "true",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track recipe import failed
    public func trackRecipeImportFailed(url: String, error: String, duration: TimeInterval) {
        queue.async {
            self.logEvent("recipe_import_failed", parameters: [
                "url_domain": self.extractDomain(from: url),
                "error": error,
                "duration_seconds": String(Int(duration)),
                "success": "false",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track recipe viewed
    public func trackRecipeViewed(recipe: Recipe, source: String) {
        queue.async {
            self.logEvent("recipe_viewed", parameters: [
                "recipe_id": recipe.id ?? "unknown",
                "recipe_title": recipe.title,
                "source": source, // "search", "suggestion", "meal_plan", etc.
                "cuisine": recipe.cuisines.first ?? "unknown",
                "cooking_time": String(recipe.totalTimeMinutes),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track recipe saved
    public func trackRecipeSaved(recipeId: String, source: String) {
        queue.async {
            self.logEvent("recipe_saved", parameters: [
                "recipe_id": recipeId,
                "source": source,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    // MARK: - Meal Planning Events
    
    /// Track meal plan generation started
    public func trackMealPlanGenerationStarted(criteria: PlanCriteria) {
        queue.async {
            let prefs = criteria.preferences
            let maxCost = prefs.costBudgetRange?.max
            let cuisines = prefs.cuisines
            let dietary = prefs.dietary.map { $0.rawValue }
            let timeBudget = prefs.timeBudgetMinutes
            self.logEvent("meal_plan_generation_started", parameters: [
                "dietary_preferences": dietary.joined(separator: ","),
                "max_cost": maxCost != nil ? String(maxCost!) : "-1",
                "max_time_minutes": String(timeBudget),
                "cuisine_preferences": cuisines.joined(separator: ","),
                "theme": criteria.theme ?? "",
                "prioritize_variety": String(criteria.prioritizeVariety),
                "allow_incomplete_nutrition": String(criteria.allowIncompleteNutrition),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track meal plan generation completed
    public func trackMealPlanGenerationCompleted(planId: String, duration: TimeInterval, mealsCount: Int) {
        queue.async {
            self.logEvent("meal_plan_generation_completed", parameters: [
                "plan_id": planId,
                "duration_seconds": String(Int(duration)),
                "meals_count": String(mealsCount),
                "success": "true",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track meal replaced in plan
    public func trackMealReplaced(planId: String, day: Int, slot: String, oldRecipeId: String?, newRecipeId: String, reason: String) {
        queue.async {
            self.logEvent("meal_replaced", parameters: [
                "plan_id": planId,
                "day": String(day),
                "meal_slot": slot,
                "old_recipe_id": oldRecipeId ?? "empty",
                "new_recipe_id": newRecipeId,
                "reason": reason, // "user_request", "ai_suggestion", "dietary_change", etc.
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track meal plan acceptance
    public func trackMealPlanAccepted(planId: String, acceptanceRate: Double) {
        queue.async {
            self.logEvent("meal_plan_accepted", parameters: [
                "plan_id": planId,
                "acceptance_rate": String(acceptanceRate),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    // MARK: - Shopping Events
    
    /// Track shopping list generated
    public func trackShoppingListGenerated(planId: String, itemsCount: Int, estimatedCost: Double) {
        queue.async {
            self.logEvent("shopping_list_generated", parameters: [
                "plan_id": planId,
                "items_count": String(itemsCount),
                "estimated_cost": String(estimatedCost),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track price comparison performed
    public func trackPriceComparisonPerformed(listId: String, storesCount: Int, savingsAmount: Double) {
        queue.async {
            self.logEvent("price_comparison_performed", parameters: [
                "list_id": listId,
                "stores_count": String(storesCount),
                "potential_savings": String(savingsAmount),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track shopping item purchased
    public func trackShoppingItemPurchased(listId: String, itemId: String, price: Double, store: String) {
        queue.async {
            self.logEvent("shopping_item_purchased", parameters: [
                "list_id": listId,
                "item_id": itemId,
                "price": String(price),
                "store": store,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track shopping order created
    public func trackShoppingOrderCreated(orderId: String, totalAmount: Double, itemsCount: Int, fulfillmentType: String) {
        queue.async {
            self.logEvent("shopping_order_created", parameters: [
                "order_id": orderId,
                "total_amount": String(totalAmount),
                "items_count": String(itemsCount),
                "fulfillment_type": fulfillmentType,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    // MARK: - Cooking Events
    
    /// Track cooking session started
    public func trackCookingSessionStarted(recipeId: String, estimatedTime: Int) {
        queue.async {
            self.logEvent("cooking_session_started", parameters: [
                "recipe_id": recipeId,
                "estimated_time_minutes": String(estimatedTime),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track cooking step completed
    public func trackCookingStepCompleted(recipeId: String, stepIndex: Int, actualTime: TimeInterval) {
        queue.async {
            self.logEvent("cooking_step_completed", parameters: [
                "recipe_id": recipeId,
                "step_index": String(stepIndex),
                "actual_time_seconds": String(Int(actualTime)),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track cooking timer used
    public func trackCookingTimerUsed(recipeId: String, stepIndex: Int, timerDuration: Int, accuracy: Double) {
        queue.async {
            self.logEvent("cooking_timer_used", parameters: [
                "recipe_id": recipeId,
                "step_index": String(stepIndex),
                "timer_duration_seconds": String(timerDuration),
                "accuracy": String(accuracy), // How close to expected time
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track cooking session completed
    public func trackCookingSessionCompleted(recipeId: String, totalTime: TimeInterval, stepsCompleted: Int, totalSteps: Int) {
        queue.async {
            self.logEvent("cooking_session_completed", parameters: [
                "recipe_id": recipeId,
                "total_time_minutes": String(Int(totalTime / 60)),
                "steps_completed": String(stepsCompleted),
                "total_steps": String(totalSteps),
                "completion_rate": String(Double(stepsCompleted) / Double(totalSteps)),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    // MARK: - AI Assistant Events
    
    /// Track AI chat message sent
    public func trackAIChatMessageSent(messageLength: Int, context: String) {
        queue.async {
            self.logEvent("ai_chat_message_sent", parameters: [
                "message_length": String(messageLength),
                "context": context, // "meal_planning", "nutrition", "cooking", etc.
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track AI response received
    public func trackAIResponseReceived(responseTime: TimeInterval, responseLength: Int, helpful: Bool?) {
        queue.async {
            var parameters: [String: String] = [
                "response_time_seconds": String(Int(responseTime)),
                "response_length": String(responseLength),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
            
            if let helpful = helpful {
                parameters["helpful"] = String(helpful)
            }
            
            self.logEvent("ai_response_received", parameters: parameters)
        }
    }
    
    /// Track nutrition advice requested
    public func trackNutritionAdviceRequested(bodyRegions: [String], symptoms: [String]) {
        queue.async {
            self.logEvent("nutrition_advice_requested", parameters: [
                "body_regions": bodyRegions.joined(separator: ","),
                "symptoms": symptoms.joined(separator: ","),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    // MARK: - Voice Commands
    
    /// Track voice command used
    public func trackVoiceCommandUsed(command: String, success: Bool, confidence: Float) {
        queue.async {
            self.logEvent("voice_command_used", parameters: [
                "command": command,
                "success": String(success),
                "confidence": String(confidence),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track voice command recognition error
    public func trackVoiceCommandError(error: String, originalText: String) {
        queue.async {
            self.logEvent("voice_command_error", parameters: [
                "error": error,
                "original_text": originalText,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    // MARK: - Search and Discovery
    
    /// Track recipe search performed
    public func trackRecipeSearchPerformed(query: String, resultsCount: Int, filters: [String]) {
        queue.async {
            self.logEvent("recipe_search_performed", parameters: [
                "query": query.isEmpty ? "empty" : "provided",
                "query_length": String(query.count),
                "results_count": String(resultsCount),
                "filters": filters.joined(separator: ","),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track recipe suggestion clicked
    public func trackRecipeSuggestionClicked(recipeId: String, suggestionSource: String, position: Int) {
        queue.async {
            self.logEvent("recipe_suggestion_clicked", parameters: [
                "recipe_id": recipeId,
                "suggestion_source": suggestionSource,
                "position": String(position),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    // MARK: - Performance Metrics
    
    /// Track app launch time for meal planning
    public func trackMealPlanningLaunchTime(duration: TimeInterval) {
        queue.async {
            self.logEvent("meal_planning_launch_time", parameters: [
                "duration_milliseconds": String(Int(duration * 1000)),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track network request performance
    public func trackNetworkRequest(endpoint: String, duration: TimeInterval, success: Bool, errorCode: String?) {
        queue.async {
            var parameters: [String: String] = [
                "endpoint": endpoint,
                "duration_milliseconds": String(Int(duration * 1000)),
                "success": String(success),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
            
            if let errorCode = errorCode {
                parameters["error_code"] = errorCode
            }
            
            self.logEvent("network_request", parameters: parameters)
        }
    }
    
    // MARK: - Error Tracking
    
    /// Track general error
    public func trackError(error: Error, context: String, severity: String = "medium") {
        queue.async {
            self.logEvent("error_occurred", parameters: [
                "error": error.localizedDescription,
                "context": context,
                "severity": severity,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    /// Track feature usage
    public func trackFeatureUsage(feature: String, usage: String) {
        queue.async {
            self.logEvent("feature_usage", parameters: [
                "feature": feature,
                "usage": usage,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    // MARK: - Private Helpers
    
    func logEvent(_ eventName: String, parameters: [String: String]) {
        logger.info("Analytics: \(eventName) - \(parameters)")
        
        // In a production app, this would send to analytics service
        // Examples: Firebase Analytics, Mixpanel, Segment, etc.
        
        #if DEBUG
        print("📊 Analytics Event: \(eventName)")
        for (key, value) in parameters {
            print("   \(key): \(value)")
        }
        #endif
    }
    
    private func extractDomain(from url: String) -> String {
        guard let url = URL(string: url),
              let host = url.host else {
            return "unknown"
        }
        return host
    }
}

// MARK: - Session Management

public final class MealPlanningSession {
    public static let shared = MealPlanningSession()
    
    private var sessionStartTime: Date?
    private var currentRecipeId: String?
    private var currentPlanId: String?
    
    private init() {}
    
    public func startSession() {
        sessionStartTime = Date()
        MealPlanningAnalytics.shared.trackFeatureUsage(feature: "meal_planning", usage: "session_start")
    }
    
    public func endSession() {
        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            MealPlanningAnalytics.shared.logEvent("session_ended", parameters: [
                "session_duration_minutes": String(Int(duration / 60)),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
        sessionStartTime = nil
        currentRecipeId = nil
        currentPlanId = nil
    }
    
    public func setCurrentRecipe(_ recipeId: String) {
        currentRecipeId = recipeId
    }
    
    public func setCurrentPlan(_ planId: String) {
        currentPlanId = planId
    }
    
    public var getCurrentRecipeId: String? { currentRecipeId }
    public var getCurrentPlanId: String? { currentPlanId }
}

// MARK: - Performance Monitor

public final class MealPlanningPerformanceMonitor {
    public static let shared = MealPlanningPerformanceMonitor()
    
    private var timers: [String: Date] = [:]
    private let queue = AnalyticsQueue(queue: DispatchQueue(label: "performance-monitor", qos: .utility))
    
    private init() {}
    
    public func startTimer(for operation: String) {
        queue.async {
            self.timers[operation] = Date()
        }
    }
    
    public func endTimer(for operation: String) {
        queue.async {
            guard let startTime = self.timers[operation] else { return }
            let duration = Date().timeIntervalSince(startTime)
            
            MealPlanningAnalytics.shared.logEvent("performance_metric", parameters: [
                "operation": operation,
                "duration_milliseconds": String(Int(duration * 1000)),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
            
            self.timers.removeValue(forKey: operation)
        }
    }
}

// MARK: - SwiftUI Integration

extension View {
    /// Track view appearance for analytics
    public func trackViewAppearance(_ viewName: String) -> some View {
        self.onAppear {
            MealPlanningAnalytics.shared.trackFeatureUsage(feature: "view_appeared", usage: viewName)
        }
    }
    
    /// Track button taps for analytics
    public func trackButtonTap(_ buttonName: String, action: @escaping () -> Void) -> some View {
        self.onTapGesture {
            MealPlanningAnalytics.shared.trackFeatureUsage(feature: "button_tap", usage: buttonName)
            action()
        }
    }
}