import Foundation
import SwiftUI
import UIKit

public enum AccessibilityNotificationPriority: Int {
    case low = 0
    case medium = 1
    case high = 2
}

/// Accessibility support for meal planning feature
public struct MealPlanningAccessibility {
    
    // MARK: - Labels
    
    public static let recipeCard = "Recipe card"
    public static let mealSlot = "Meal slot"
    public static let shoppingItem = "Shopping list item"
    public static let cookingStep = "Cooking step"
    public static let nutritionInfo = "Nutrition information"
    public static let bodyRegion = "Body region"
    public static let aiMessage = "AI assistant message"
    public static let voiceCommand = "Voice command button"
    public static let timer = "Cooking timer"
    
    // MARK: - Hints
    
    public static let tapToViewRecipe = "Double tap to view recipe details"
    public static let tapToReplaceMeal = "Double tap to replace this meal"
    public static let tapToToggleItem = "Double tap to toggle purchased status"
    public static let tapForNextStep = "Double tap to go to next cooking step"
    public static let tapForNutrition = "Double tap to view detailed nutrition information"
    public static let tapBodyRegion = "Double tap to select this body region for nutrition advice"
    public static let tapToSendMessage = "Double tap to send message to AI assistant"
    public static let holdForVoiceCommand = "Hold to record voice command"
    public static let tapToStartTimer = "Double tap to start cooking timer"
    
    // MARK: - Dynamic Labels
    
    public static func recipeTitle(_ title: String) -> String {
        return "Recipe: \(title)"
    }
    
    public static func mealSlotLabel(day: String, meal: String, recipe: String?) -> String {
        if let recipe = recipe {
            return "\(day), \(meal): \(recipe)"
        } else {
            return "\(day), \(meal): Empty slot"
        }
    }
    
    public static func shoppingItemLabel(name: String, quantity: String, purchased: Bool) -> String {
        let status = purchased ? "purchased" : "not purchased"
        return "\(name), \(quantity), \(status)"
    }
    
    public static func cookingStepLabel(step: Int, total: Int, instruction: String) -> String {
        return "Step \(step) of \(total): \(instruction)"
    }
    
    public static func nutritionLabel(calories: Int, protein: Double, carbs: Double, fat: Double) -> String {
        let proteinStr = String(format: "%.1f", protein)
        let carbsStr = String(format: "%.1f", carbs)
        let fatStr = String(format: "%.1f", fat)
        return "Nutrition: \(calories) calories, \(proteinStr) grams protein, \(carbsStr) grams carbs, \(fatStr) grams fat"
    }
    
    public static func timerLabel(minutes: Int, seconds: Int, isRunning: Bool) -> String {
        let status = isRunning ? "running" : "stopped"
        return "Timer: \(minutes) minutes \(seconds) seconds, \(status)"
    }
    
    public static func bodyRegionLabel(region: String, isSelected: Bool) -> String {
        let status = isSelected ? "selected" : "not selected"
        return "\(region) body region, \(status)"
    }
    
    // MARK: - Voice Over Announcements
    
    public static let recipeImportStarted = "Recipe import started"
    public static let recipeImportComplete = "Recipe import complete"
    public static let mealPlanGenerated = "Meal plan generated successfully"
    public static let mealReplaced = "Meal replaced"
    public static let itemPurchased = "Item marked as purchased"
    public static let itemUnpurchased = "Item marked as not purchased"
    public static let timerStarted = "Cooking timer started"
    public static let timerFinished = "Cooking timer finished"
    public static let stepCompleted = "Cooking step completed"
    public static let voiceCommandReceived = "Voice command received"
    public static let aiResponseReceived = "AI assistant response received"
    
    // MARK: - Error Announcements
    
    public static let importFailed = "Recipe import failed"
    public static let planGenerationFailed = "Meal plan generation failed"
    public static let networkError = "Network error occurred"
    public static let featureNotAvailable = "Feature not available"
    
    // MARK: - Content Descriptions
    
    public static func recipeDescription(_ recipe: String) -> String {
        // This would be enhanced with more recipe details
        return "Recipe for \(recipe)"
    }
    
    public static func mealPlanDescription(days: Int, meals: Int) -> String {
        return "Meal plan with \(days) days and \(meals) meals"
    }
    
    public static func shoppingListDescription(items: Int, stores: Int) -> String {
        let storeText = stores == 1 ? "store" : "stores"
        return "Shopping list with \(items) items from \(stores) \(storeText)"
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    
    /// Add accessibility support for recipe cards
    public func recipeCardAccessibility(_ recipe: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(MealPlanningAccessibility.recipeTitle(recipe))
            .accessibilityHint(MealPlanningAccessibility.tapToViewRecipe)
            .accessibilityAddTraits(.isButton)
    }
    
    /// Add accessibility support for meal slots
    public func mealSlotAccessibility(day: String, meal: String, recipe: String?) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(MealPlanningAccessibility.mealSlotLabel(day: day, meal: meal, recipe: recipe))
            .accessibilityHint(MealPlanningAccessibility.tapToReplaceMeal)
            .accessibilityAddTraits(.isButton)
    }
    
    /// Add accessibility support for shopping list items
    public func shoppingItemAccessibility(name: String, quantity: String, purchased: Bool) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(MealPlanningAccessibility.shoppingItemLabel(name: name, quantity: quantity, purchased: purchased))
            .accessibilityHint(MealPlanningAccessibility.tapToToggleItem)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(purchased ? "Purchased" : "Not purchased")
    }
    
    /// Add accessibility support for cooking steps
    public func cookingStepAccessibility(step: Int, total: Int, instruction: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(MealPlanningAccessibility.cookingStepLabel(step: step, total: total, instruction: instruction))
            .accessibilityHint(MealPlanningAccessibility.tapForNextStep)
            .accessibilityAddTraits(.isButton)
    }
    
    /// Add accessibility support for voice command buttons
    public func voiceCommandAccessibility() -> some View {
        self
            .accessibilityLabel(MealPlanningAccessibility.voiceCommand)
            .accessibilityHint(MealPlanningAccessibility.holdForVoiceCommand)
            .accessibilityAddTraits(.isButton)
    }
    
    /// Add accessibility support for timers
    public func timerAccessibility(minutes: Int, seconds: Int, isRunning: Bool) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(MealPlanningAccessibility.timerLabel(minutes: minutes, seconds: seconds, isRunning: isRunning))
            .accessibilityHint(MealPlanningAccessibility.tapToStartTimer)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isRunning ? "Running" : "Stopped")
    }
    
    /// Add high contrast support for better visibility
    public func highContrastSupport() -> some View {
        self
            .accessibilityShowsLargeContentViewer()
            .dynamicTypeSize(.small ... .accessibility5)
    }
}

// MARK: - Color Contrast Support

extension Color {
    
    /// Accessible colors with proper contrast ratios
    public static let accessiblePrimary = Color.blue
    public static let accessibleSecondary = Color.orange
    public static let accessibleSuccess = Color.green
    public static let accessibleWarning = Color.yellow
    public static let accessibleError = Color.red
    public static let accessibleBackground = Color(.systemBackground)
    public static let accessibleForeground = Color(.label)
    public static let accessibleSecondaryBackground = Color(.secondarySystemBackground)
    public static let accessibleSecondaryForeground = Color(.secondaryLabel)
    
    /// Get accessible color pair with proper contrast
    public func accessibleContrast() -> Color {
        // This would implement proper contrast calculation
        // For now, using system colors that automatically adapt
        return Color(.label)
    }
}

// MARK: - Voice Over Announcements Helper

public struct VoiceOverAnnouncement {
    
    /// Post accessibility announcement
    public static func post(_ message: String, priority: AccessibilityNotificationPriority = .medium) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    /// Post layout change announcement
    public static func postLayoutChange(to element: Any? = nil) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .layoutChanged, argument: element)
        }
    }
    
    /// Post screen change announcement
    public static func postScreenChange(to element: Any? = nil) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .screenChanged, argument: element)
        }
    }
}