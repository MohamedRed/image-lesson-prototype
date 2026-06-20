import Foundation

/// Factory for creating MarketplaceService instances
/// Provides mock implementations for development and testing
public final class MarketplaceServiceFactory {
    
    /// Environment configuration
    public enum Environment {
        case mock          // For UI testing without backend
        case development   // For local development with backend
        case production    // For production release
    }
    
    private static var currentEnvironment: Environment = .mock
    
    /// Set the environment for service creation
    public static func configure(environment: Environment) {
        currentEnvironment = environment
    }
    
    /// Create a marketplace service instance based on environment
    public static func createService() -> MarketplaceServicing {
        switch currentEnvironment {
        case .mock:
            return MockMarketplaceService()
        case .development, .production:
            // Return Firebase implementation when backend is ready
            // For now, return mock for UI testing
            return MockMarketplaceService()
            // TODO: Uncomment when backend is deployed
            // return FirestoreMarketplaceService()
        }
    }
    
    /// Create a marketplace AI service instance
    public static func createAIService() -> MarketplaceAI {
        switch currentEnvironment {
        case .mock:
            return MockMarketplaceAI()
        case .development, .production:
            // Return Firebase AI implementation when backend is ready
            return MockMarketplaceAI()
            // TODO: Uncomment when backend is deployed
            // return FirebaseMarketplaceAI()
        }
    }
    
    /// Create a parent AI client instance
    public static func createParentAIClient() -> ParentAIClient? {
        switch currentEnvironment {
        case .mock:
            return MockParentAIClient()
        case .development, .production:
            return nil // TODO: Implement when parent AI is available
        }
    }
    
    // UI types (e.g., MarketplaceViewModel) must not be referenced from the Service package.
}

// MARK: - Mock Parent AI Client

private class MockParentAIClient: ParentAIClient {
    
    func requestUserTraits(scopes: [TraitScope]) async throws -> (traits: UserTraits, consentId: String) {
        // Simulate consent flow and trait retrieval
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let mockTraits = UserTraits(
            userId: "current_user",
            traits: UserTraits.Traits(
                carModel: scopes.contains(.carProfileRead) ? "Toyota Camry 2019" : nil,
                clothingSizes: scopes.contains(.clothingSizesRead) ? .init(tops: "M", bottoms: "32", shoes: nil) : nil,
                stylePreferences: scopes.contains(.stylePreferencesRead) ? ["casual", "business"] : nil,
                diySkillLevel: scopes.contains(.diySkillRead) ? "intermediate" : nil
            ),
            updatedAt: Date(),
            provenance: UserTraits.Provenance(
                app: "parent_ai",
                scope: scopes.map { $0.rawValue }.joined(separator: ","),
                consentId: UUID().uuidString
            )
        )
        
        return (traits: mockTraits, consentId: UUID().uuidString)
    }
}

// MARK: - Development Configuration

#if DEBUG
extension MarketplaceServiceFactory {
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