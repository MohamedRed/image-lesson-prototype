import Foundation

/// Factory for creating EventsService instances
/// Provides mock implementations for development and testing
public final class EventsServiceFactory {
    
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
    
    /// Create an events service instance based on environment
    public static func createService() -> EventsServicing {
        switch currentEnvironment {
        case .mock:
            return MockEventsService()
        case .development, .production:
            // Return Firebase implementation when backend is ready
            // For now, return mock for UI testing
            return MockEventsService()
            // TODO: Uncomment when backend is deployed
            // let baseService = FirestoreEventsService()
            // return ResilientEventsService(baseService: baseService)
        }
    }
}

