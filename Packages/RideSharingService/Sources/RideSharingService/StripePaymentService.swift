import Foundation
import Stripe
import StripePaymentSheet
import UIKit
import Combine
import FirebaseAuth

/// Service for handling Stripe payments with PaymentSheet integration
@MainActor
public class StripePaymentService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var paymentSheet: PaymentSheet?
    @Published public var paymentResult: PaymentSheetResult?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    // MARK: - Private Properties
    private let apiClient: APIClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
        setupStripe()
    }
    
    // MARK: - Public Methods
    
    /// Creates a payment intent for the given ride
    /// - Parameters:
    ///   - rideId: The ride ID
    ///   - amount: Amount in cents
    ///   - currency: Currency code (default: USD)
    ///   - completion: Completion handler with PaymentSheet
    public func createPaymentIntent(
        for rideId: String,
        amount: Int,
        currency: String = "usd",
        completion: @escaping (Result<PaymentSheet, StripePaymentError>) -> Void
    ) {
        isLoading = true
        errorMessage = nil
        
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(.notAuthenticated))
            isLoading = false
            return
        }
        
        let paymentIntentRequest = CreatePaymentIntentRequest(
            amount: amount,
            currency: currency,
            rideId: rideId,
            userId: currentUser.uid
        )
        
        apiClient.createPaymentIntent(request: paymentIntentRequest)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] comp in
                    self?.isLoading = false
                    switch comp {
                    case .finished:
                        break
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                        completion(.failure(.apiError(error)))
                    }
                },
                receiveValue: { [weak self] response in
                    self?.setupPaymentSheet(
                        paymentIntentClientSecret: response.clientSecret,
                        customerId: response.customerId,
                        customerEphemeralKeySecret: response.ephemeralKey,
                        completion: completion
                    )
                }
            )
            .store(in: &cancellables)
    }
    
    /// Presents the payment sheet
    /// - Parameters:
    ///   - presentingViewController: The view controller to present from
    ///   - completion: Completion handler with payment result
    public func presentPaymentSheet(
        from presentingViewController: UIViewController,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        guard let paymentSheet = paymentSheet else {
            completion(.failed(error: StripePaymentError.paymentSheetNotReady))
            return
        }
        
        paymentSheet.present(from: presentingViewController) { [weak self] result in
            DispatchQueue.main.async {
                self?.paymentResult = result
                completion(result)
            }
        }
    }
    
    /// Confirms payment for server-side confirmation
    /// - Parameters:
    ///   - paymentIntentId: Payment intent ID
    ///   - completion: Completion handler
    public func confirmPayment(
        paymentIntentId: String,
        completion: @escaping (Result<PaymentConfirmationResponse, Error>) -> Void
    ) {
        isLoading = true
        
        let confirmRequest = ConfirmPaymentRequest(paymentIntentId: paymentIntentId)
        
        apiClient.confirmPayment(request: confirmRequest)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] comp in
                    self?.isLoading = false
                    switch comp {
                    case .finished:
                        break
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                        completion(.failure(error))
                    }
                },
                receiveValue: { response in
                    completion(.success(response))
                }
            )
            .store(in: &cancellables)
    }
    
    /// Handles 3D Secure authentication if required
    /// - Parameters:
    ///   - clientSecret: Payment intent client secret
    ///   - presentingViewController: View controller to present from
    ///   - completion: Completion handler
    public func handle3DSecure(
        clientSecret: String,
        from presentingViewController: UIViewController,
        completion: @escaping (Result<STPPaymentIntent, Error>) -> Void
    ) {
        let paymentHandler = STPPaymentHandler.shared()
        
        paymentHandler.confirmPayment(
            withParams: STPPaymentIntentParams(clientSecret: clientSecret),
            authenticationContext: AuthenticationContext(presentingViewController: presentingViewController)
        ) { (status, paymentIntent, error) in
            DispatchQueue.main.async {
                switch status {
                case .succeeded:
                    if let paymentIntent = paymentIntent {
                        completion(.success(paymentIntent))
                    } else {
                        completion(.failure(StripePaymentError.unknown))
                    }
                case .failed:
                    completion(.failure(error ?? StripePaymentError.unknown))
                case .canceled:
                    completion(.failure(StripePaymentError.userCanceled))
                @unknown default:
                    completion(.failure(StripePaymentError.unknown))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupStripe() {
        // Initialize Stripe SDK with key from backend configuration
        Task {
            do {
                let config = try await fetchConfig()
                await MainActor.run {
                    StripeAPI.defaultPublishableKey = config.stripePublishableKey
                    print("✅ Stripe SDK initialized with backend configuration")
                }
            } catch {
                print("❌ Failed to initialize Stripe SDK: \(error)")
                // Fallback to test key for development
                StripeAPI.defaultPublishableKey = "pk_test_51Hu3kiBGCAaEMeUIf9HA6e8ILoNzLo1gJ5AclslZiLJmPJ2ZJwBzr8ygocd5ijT6YSKHa82Qa9WiueNPRVmJXb6d00CklkVKy5"
                print("⚠️ Using fallback Stripe test key")
            }
        }
    }
    
    private func fetchConfig() async throws -> ConfigResponse {
        guard let apiBaseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: "\(apiBaseURL)/config") else {
            throw StripePaymentError.configurationError
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ConfigResponse.self, from: data)
    }
    
    private func setupPaymentSheet(
        paymentIntentClientSecret: String,
        customerId: String,
        customerEphemeralKeySecret: String,
        completion: @escaping (Result<PaymentSheet, StripePaymentError>) -> Void
    ) {
        // Configure PaymentSheet
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Liive Ride Sharing"
        configuration.customer = .init(id: customerId, ephemeralKeySecret: customerEphemeralKeySecret)
        configuration.allowsDelayedPaymentMethods = true
        configuration.returnURL = "liive://payment-return"
        
        // Customize appearance
        configuration.appearance = createPaymentSheetAppearance()
        
        // Payment method types are inferred by PaymentSheet and merchant settings
        
        // Apple Pay configuration
        if StripeAPI.deviceSupportsApplePay() {
            configuration.applePay = .init(
                merchantId: "merchant.com.liive.ridesharing",
                merchantCountryCode: "US"
            )
        }
        
        // Create PaymentSheet
        let paymentSheet = PaymentSheet(
            paymentIntentClientSecret: paymentIntentClientSecret,
            configuration: configuration
        )
        
        DispatchQueue.main.async {
            self.paymentSheet = paymentSheet
            completion(.success(paymentSheet))
        }
    }
    
    private func createPaymentSheetAppearance() -> PaymentSheet.Appearance {
        var appearance = PaymentSheet.Appearance.default
        
        // Colors
        appearance.colors.primary = UIColor.systemBlue
        appearance.colors.background = UIColor.systemBackground
        appearance.colors.componentBackground = UIColor.secondarySystemBackground
        appearance.colors.componentBorder = UIColor.separator
        appearance.colors.componentDivider = UIColor.separator
        appearance.colors.text = UIColor.label
        appearance.colors.textSecondary = UIColor.secondaryLabel
        appearance.colors.componentText = UIColor.label
        // placeholderText is not configurable in this SDK version
        appearance.colors.icon = UIColor.label
        appearance.colors.danger = UIColor.systemRed
        
        // Typography
        appearance.font.base = UIFont.systemFont(ofSize: 16)
        appearance.font.sizeScaleFactor = 1.0
        
        // Shapes
        appearance.cornerRadius = 12.0
        appearance.borderWidth = 1.0
        
        return appearance
    }
}

// MARK: - Supporting Types

public struct CreatePaymentIntentRequest: Codable {
    let amount: Int
    let currency: String
    let rideId: String
    let userId: String
}

// Configuration response from backend
private struct ConfigResponse: Codable {
    let radarPublishableKey: String
    let mapboxAccessToken: String
    let stripePublishableKey: String
    let livekitWsUrl: String
}

public struct PaymentIntentResponse: Codable {
    let clientSecret: String
    let customerId: String
    let ephemeralKey: String
    let paymentIntentId: String
}

public struct ConfirmPaymentRequest: Codable {
    let paymentIntentId: String
}

public struct PaymentConfirmationResponse: Codable {
    let status: String
    let paymentIntentId: String
    let receiptUrl: String?
}

// MARK: - Error Types

public enum StripePaymentError: LocalizedError {
    case notAuthenticated
    case paymentSheetNotReady
    case apiError(Error)
    case userCanceled
    case configurationError
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .paymentSheetNotReady:
            return "Payment sheet not ready"
        case .apiError(let error):
            return "API Error: \(error.localizedDescription)"
        case .userCanceled:
            return "Payment canceled by user"
        case .configurationError:
            return "Failed to fetch configuration from backend"
        case .unknown:
            return "Unknown payment error"
        }
    }
}

// MARK: - Authentication Context

private class AuthenticationContext: NSObject, STPAuthenticationContext {
    private weak var presentingViewController: UIViewController?
    
    init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
        super.init()
    }
    
    func authenticationPresentingViewController() -> UIViewController {
        return presentingViewController ?? UIViewController()
    }
}

// MARK: - API Client

public class APIClient {
    public init() {}
    private let baseURL = "https://us-central1-liive-ride-sharing.cloudfunctions.net"
    private let session = URLSession.shared
    
    public func createPaymentIntent(request: CreatePaymentIntentRequest) -> AnyPublisher<PaymentIntentResponse, Error> {
        guard let url = URL(string: "\(baseURL)/createPaymentIntent") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: urlRequest)
            .map(\.data)
            .decode(type: PaymentIntentResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    public func confirmPayment(request: ConfirmPaymentRequest) -> AnyPublisher<PaymentConfirmationResponse, Error> {
        guard let url = URL(string: "\(baseURL)/confirmPayment") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: urlRequest)
            .map(\.data)
            .decode(type: PaymentConfirmationResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
} 