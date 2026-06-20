import Foundation

/// Factory for creating AccommodationsService instances based on environment
public class AccommodationsServiceFactory {
    
    public enum Environment {
        case production
        case development  
        case testing
        case mock
    }
    
    private static var currentEnvironment: Environment = .mock
    private static var customService: AccommodationsServiceProtocol?
    
    /// Configure the factory environment
    public static func configure(environment: Environment) {
        currentEnvironment = environment
    }
    
    /// Set a custom service implementation
    public static func setCustomService(_ service: AccommodationsServiceProtocol) {
        customService = service
    }
    
    /// Create a service instance based on current configuration
    public static func makeService() -> AccommodationsServiceProtocol {
        if let customService = customService {
            return customService
        }
        
        switch currentEnvironment {
        case .production:
            return AccommodationsService(baseURL: "https://api.liive.app")
        case .development, .testing:
            return AccommodationsService(baseURL: "https://dev-api.liive.app")
        case .mock:
            return MockAccommodationsService.shared
        }
    }
    
    /// Reset factory to default state
    public static func reset() {
        currentEnvironment = .mock
        customService = nil
    }
}