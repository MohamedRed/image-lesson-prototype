import Foundation
import Combine

/// Error boundary service for handling Events feature errors gracefully
public final class EventsErrorBoundaryService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var isOffline: Bool = false
    @Published public private(set) var networkError: NetworkError?
    @Published public private(set) var retryAttempts: Int = 0
    
    // MARK: - Private Properties
    
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 2.0
    private let networkMonitor = NetworkConnectivityMonitor()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Execute operation with error boundary protection
    public func execute<T>(
        operation: @escaping () async throws -> T,
        fallback: (() async -> T)? = nil,
        retryPolicy: RetryPolicy = .exponentialBackoff
    ) async -> Result<T, EventsError> {
        do {
            let result = try await executeWithRetry(
                operation: operation,
                retryPolicy: retryPolicy
            )
            
            // Reset retry counter on success
            await MainActor.run {
                self.retryAttempts = 0
                self.networkError = nil
            }
            
            return .success(result)
        } catch {
            // Update error state
            await MainActor.run {
                if let networkError = error as? NetworkError {
                    self.networkError = networkError
                }
            }
            
            // Try fallback if available
            if let fallback = fallback {
                let fallbackResult = await fallback()
                return .success(fallbackResult)
            }
            
            return .failure(mapToEventsError(error))
        }
    }
    
    /// Execute operation with automatic retry logic
    private func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        retryPolicy: RetryPolicy,
        currentAttempt: Int = 0
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            // Check if we should retry
            if shouldRetry(error: error, attempt: currentAttempt) {
                await MainActor.run {
                    self.retryAttempts = currentAttempt + 1
                }
                
                // Wait before retrying
                let delay = calculateDelay(
                    attempt: currentAttempt,
                    policy: retryPolicy
                )
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // Recursive retry
                return try await executeWithRetry(
                    operation: operation,
                    retryPolicy: retryPolicy,
                    currentAttempt: currentAttempt + 1
                )
            } else {
                throw error
            }
        }
    }
    
    /// Reset error state
    public func resetErrorState() {
        networkError = nil
        retryAttempts = 0
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.isConnectedPublisher
            .assign(to: \.isOffline, on: self)
            .store(in: &cancellables)
    }
    
    private func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxRetryAttempts else { return false }
        
        // Retry on specific network errors
        if let networkError = error as? NetworkError {
            switch networkError {
            case .timeout, .connectionLost, .serverError:
                return true
            case .unauthorized, .forbidden, .notFound:
                return false
            case .rateLimited:
                return attempt < 1 // Only retry once for rate limiting
            case .unknown:
                return true
            }
        }
        
        // Retry on URLError cases
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    private func calculateDelay(attempt: Int, policy: RetryPolicy) -> TimeInterval {
        switch policy {
        case .fixed(let delay):
            return delay
        case .exponentialBackoff:
            return retryDelay * pow(2.0, Double(attempt))
        case .linear:
            return retryDelay * Double(attempt + 1)
        }
    }
    
    private func mapToEventsError(_ error: Error) -> EventsError {
        if let eventsError = error as? EventsError {
            return eventsError
        }
        
        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return .unauthorized
            case .notFound:
                return .eventNotFound
            case .serverError:
                return .serverError(networkError.localizedDescription)
            default:
                return .networkError
            }
        }
        
        if error is URLError {
            return .networkError
        }
        
        return .serverError(error.localizedDescription)
    }
}

// MARK: - Supporting Types

public enum RetryPolicy {
    case fixed(TimeInterval)
    case exponentialBackoff
    case linear
}

public enum NetworkError: LocalizedError, Equatable {
    case timeout
    case connectionLost
    case unauthorized
    case forbidden
    case notFound
    case serverError(String)
    case rateLimited
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Request timed out"
        case .connectionLost:
            return "Network connection lost"
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .serverError(let message):
            return "Server error: \(message)"
        case .rateLimited:
            return "Too many requests, please wait"
        case .unknown:
            return "Unknown network error"
        }
    }
}

// MARK: - Network Connectivity Monitor

private final class NetworkConnectivityMonitor: ObservableObject {
    
    @Published var isConnected: Bool = true
    
    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        $isConnected
            .map { !$0 } // Invert for isOffline
            .eraseToAnyPublisher()
    }
    
    init() {
        // In a real implementation, this would use Network framework
        // For now, simulate connectivity monitoring
        setupConnectivityMonitoring()
    }
    
    private func setupConnectivityMonitoring() {
        // Mock implementation - in reality would use NWPathMonitor
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // Simulate network checks
                self?.checkConnectivity()
            }
            .store(in: &cancellables)
    }
    
    private func checkConnectivity() {
        // Mock connectivity check
        // In real implementation: use NWPathMonitor or URLSession connectivity tests
        Task {
            do {
                let url = URL(string: "https://www.google.com")!
                let (_, response) = try await URLSession.shared.data(from: url)
                let httpResponse = response as? HTTPURLResponse
                
                await MainActor.run {
                    self.isConnected = httpResponse?.statusCode == 200
                }
            } catch {
                await MainActor.run {
                    self.isConnected = false
                }
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
}