import Foundation

/// Errors that can occur in meal planning operations
public enum MealPlanningError: LocalizedError {
    case featureNotEnabled(String)
    case recipeNotFound(String)
    case mealPlanNotFound(String)
    case shoppingListNotFound(String)
    case orderNotFound(String)
    case invalidURL(String)
    case importFailed(String)
    case networkError(Error)
    case invalidData(String)
    case unauthorized
    case rateLimited
    case nutritionDataUnavailable
    case allergenViolation([String])
    case backendServiceUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .featureNotEnabled(let feature):
            return "Feature '\(feature)' is not enabled in current configuration"
        case .recipeNotFound(let id):
            return "Recipe with ID '\(id)' not found"
        case .mealPlanNotFound(let id):
            return "Meal plan with ID '\(id)' not found"
        case .shoppingListNotFound(let id):
            return "Shopping list with ID '\(id)' not found"
        case .orderNotFound(let id):
            return "Order with ID '\(id)' not found"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .importFailed(let reason):
            return "Recipe import failed: \(reason)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .unauthorized:
            return "User not authorized to perform this action"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .nutritionDataUnavailable:
            return "Nutrition data is currently unavailable"
        case .allergenViolation(let allergens):
            return "This recipe contains allergens: \(allergens.joined(separator: ", "))"
        case .backendServiceUnavailable:
            return "Meal planning service is temporarily unavailable"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .featureNotEnabled:
            return "This feature may be available in a future update"
        case .recipeNotFound, .mealPlanNotFound, .shoppingListNotFound, .orderNotFound:
            return "Try refreshing your data or check your internet connection"
        case .invalidURL:
            return "Please check the URL and try again"
        case .importFailed:
            return "Try importing from a different source or check the URL"
        case .networkError:
            return "Check your internet connection and try again"
        case .invalidData:
            return "Please try again or contact support if the problem persists"
        case .unauthorized:
            return "Please sign in to your account"
        case .rateLimited:
            return "Wait a few minutes before trying again"
        case .nutritionDataUnavailable:
            return "Try again later or contact support"
        case .allergenViolation:
            return "Please review the recipe ingredients and modify your preferences if needed"
        case .backendServiceUnavailable:
            return "Please try again in a few minutes"
        }
    }
}