import Foundation

/// Feature flags for meal planning functionality
public struct MealPlanningFeatureFlags {
    public let recipeImport: Bool
    public let mealPlanGeneration: Bool
    public let aiAssistant: Bool
    public let voiceCommands: Bool
    public let cookingMode: Bool
    public let shoppingIntegration: Bool
    public let nutritionTracking: Bool
    public let bodyAssistant: Bool
    public let shareExtension: Bool
    public let multiCookCoordination: Bool
    public let videoSegments: Bool
    public let priceComparison: Bool
    
    public static let allEnabled = MealPlanningFeatureFlags(
        recipeImport: true,
        mealPlanGeneration: true,
        aiAssistant: true,
        voiceCommands: true,
        cookingMode: true,
        shoppingIntegration: true,
        nutritionTracking: true,
        bodyAssistant: true,
        shareExtension: true,
        multiCookCoordination: true,
        videoSegments: true,
        priceComparison: true
    )
    
    public static let minimal = MealPlanningFeatureFlags(
        recipeImport: true,
        mealPlanGeneration: true,
        aiAssistant: false,
        voiceCommands: false,
        cookingMode: false,
        shoppingIntegration: false,
        nutritionTracking: false,
        bodyAssistant: false,
        shareExtension: true,
        multiCookCoordination: false,
        videoSegments: false,
        priceComparison: false
    )
}

/// Factory for creating MealPlanningService instances
/// Provides mock implementations for development and testing
public final class MealPlanningServiceFactory {
    
    /// Environment configuration
    public enum Environment {
        case mock          // For UI testing without backend
        case development   // For local development with backend
        case production    // For production release
    }
    
    private static var currentEnvironment: Environment = .mock
    private static var featureFlags: MealPlanningFeatureFlags = .allEnabled
    
    /// Set the environment for service creation
    public static func configure(environment: Environment, featureFlags: MealPlanningFeatureFlags = .allEnabled) {
        currentEnvironment = environment
        self.featureFlags = featureFlags
    }
    
    /// Get current feature flags
    public static func currentFeatureFlags() -> MealPlanningFeatureFlags {
        return featureFlags
    }
    
    /// Create a meal planning service instance based on environment
    public static func createService() -> MealPlanningServicing {
        switch currentEnvironment {
        case .mock:
            return MockMealPlanningService(featureFlags: featureFlags)
        case .development, .production:
            // Return Firebase implementation when backend is ready
            // For now, return mock for UI testing with fallback
            if ProcessInfo.processInfo.environment["MEAL_PLANNING_FORCE_BACKEND"] == "true" {
                // TODO: Uncomment when backend is deployed
                // return FirestoreMealPlanningService(featureFlags: featureFlags)
                return MockMealPlanningService(featureFlags: featureFlags)
            } else {
                return MockMealPlanningService(featureFlags: featureFlags)
            }
        }
    }
}

// MARK: - Development Configuration

#if DEBUG
extension MealPlanningServiceFactory {
    /// Helper for development builds
    public static func configureDevelopment() {
        #if targetEnvironment(simulator)
        configure(environment: .mock)
        #else
        configure(environment: .development)
        #endif
    }
}
#endif