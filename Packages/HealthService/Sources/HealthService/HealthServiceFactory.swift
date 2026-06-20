import Foundation
import Combine

/// Factory for creating HealthService instances based on environment
public class HealthServiceFactory {
    
    public enum Environment {
        case production
        case development
        case testing
        case mock
    }
    
    private static var currentEnvironment: Environment = .mock
    private static var customService: (any ObservableObject)?
    
    /// Configure the factory environment
    public static func configure(environment: Environment) {
        currentEnvironment = environment
    }
    
    /// Set a custom service implementation
    public static func setCustomService(_ service: any ObservableObject) {
        customService = service
    }
    
    /// Create a service instance based on current configuration
    public static func makeService() -> any ObservableObject {
        if let customService = customService {
            return customService
        }
        
        switch currentEnvironment {
        case .production:
            return HealthService(baseURL: URL(string: "https://api.liive.app")!)
        case .development, .testing:
            return HealthService(baseURL: URL(string: "https://dev-api.liive.app")!)
        case .mock:
            return MockHealthService.shared
        }
    }
    
    /// Reset factory to default state
    public static func reset() {
        currentEnvironment = .mock
        customService = nil
    }
}