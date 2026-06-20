import Foundation
import Combine
import FirebaseFunctions
import FirebaseAuth
import Stripe
import StripePaymentSheet
import UIKit

/// Service for handling Stripe PaymentSheet for Food Delivery
@MainActor
public final class FoodDeliveryStripePaymentService: ObservableObject {
    @Published public var paymentSheet: PaymentSheet?
    @Published public var paymentResult: PaymentSheetResult?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    private let functions: Functions

    public init(functions: Functions = .functions()) {
        self.functions = functions
        setupStripe()
    }

    private func setupStripe() {
        if StripeAPI.defaultPublishableKey == nil || StripeAPI.defaultPublishableKey?.isEmpty == true {
            if let key = Bundle.main.object(forInfoDictionaryKey: "STRIPE_PUBLISHABLE_KEY") as? String, !key.isEmpty {
                StripeAPI.defaultPublishableKey = key
            } else {
                // Fallback test key for development
                StripeAPI.defaultPublishableKey = "pk_test_51Hu3kiBGCAaEMeUIf9HA6e8ILoNzLo1gJ5AclslZiLJmPJ2ZJwBzr8ygocd5ijT6YSKHa82Qa9WiueNPRVmJXb6d00CklkVKy5"
            }
        }
    }

    /// Creates a PaymentIntent via backend callable and configures PaymentSheet
    /// - Parameters:
    ///   - orderId: The order identifier
    ///   - amountMAD: The amount in MAD (major units)
    public func preparePaymentSheet(orderId: String, amountMAD: Double) async {
        isLoading = true
        errorMessage = nil

        do {
            guard Auth.auth().currentUser != nil else {
                throw NSError(domain: "Payment", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }

            let response = try await functions.httpsCallable("createPaymentIntent").call([
                "orderId": orderId,
                "amount": amountMAD,
                "currency": "mad",
                "idempotencyKey": UUID().uuidString
            ])

            guard let dict = response.data as? [String: Any],
                  let clientSecret = dict["clientSecret"] as? String else {
                throw NSError(domain: "Payment", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
            }

            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Liive Food Delivery"

            // Apple Pay configuration (optional)
            if StripeAPI.deviceSupportsApplePay() {
                configuration.applePay = .init(merchantId: "merchant.com.liive.fooddelivery", merchantCountryCode: "MA")
            }

            // Appearance
            configuration.appearance = PaymentSheet.Appearance.default

            self.paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func presentPaymentSheet(from presentingViewController: UIViewController, completion: @escaping (PaymentSheetResult) -> Void) {
        guard let paymentSheet = paymentSheet else {
            completion(.failed(error: NSError(domain: "Payment", code: -3, userInfo: [NSLocalizedDescriptionKey: "PaymentSheet not prepared"])) )
            return
        }

        paymentSheet.present(from: presentingViewController) { [weak self] result in
            Task { @MainActor in
                self?.paymentResult = result
                completion(result)
            }
        }
    }
}


