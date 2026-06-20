import Foundation
import FoodDeliveryService
import Combine

/// ViewModel for managing promotions and coupons
@MainActor
public class PromotionsViewModel: ObservableObject {
    @Published public var activePromotions: [Promotion] = []
    @Published public var customerCoupons: [Coupon] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var validationResult: PromotionValidationResult?
    
    private let service: PromotionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let customerId = "current_customer" // Would come from user session
    
    public init(service: PromotionServiceProtocol) {
        self.service = service
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Subscribe to promotion updates
        service.promotionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] promotions in
                self?.activePromotions = promotions
            }
            .store(in: &cancellables)
        
        // Subscribe to coupon updates
        service.customerCouponsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coupons in
                self?.customerCoupons = coupons
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    public func loadPromotions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let promotions = try await service.getPromotionsForCustomer(customerId)
            await MainActor.run {
                self.activePromotions = promotions
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    public func loadCoupons() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let coupons = try await service.getCustomerCoupons(customerId)
            await MainActor.run {
                self.customerCoupons = coupons
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    public func validateCouponCode(_ code: String) async -> PromotionValidationResult {
        do {
            let result = try await service.validateCoupon(code: code, customerId: customerId)
            await MainActor.run {
                self.validationResult = result
            }
            return result
        } catch {
            let errorResult = PromotionValidationResult(
                isValid: false,
                message: error.localizedDescription,
                errors: [.promotionNotFound]
            )
            await MainActor.run {
                self.validationResult = errorResult
            }
            return errorResult
        }
    }
    
    public func validatePromotionForOrder(_ code: String, order: OrderDraft) async -> PromotionValidationResult {
        do {
            let result = try await service.validatePromotion(
                code: code,
                for: order,
                customerId: customerId
            )
            await MainActor.run {
                self.validationResult = result
            }
            return result
        } catch {
            let errorResult = PromotionValidationResult(
                isValid: false,
                message: error.localizedDescription,
                errors: [.promotionNotFound]
            )
            await MainActor.run {
                self.validationResult = errorResult
            }
            return errorResult
        }
    }
    
    public func applyPromotionToOrder(_ promotion: Promotion, order: OrderDraft) -> PricedOrder {
        return service.applyPromotion(promotion, to: order)
    }
    
    public func useCoupon(_ coupon: Coupon, orderId: String) async {
        do {
            try await service.useCoupon(
                code: coupon.code,
                orderId: orderId,
                customerId: customerId
            )
            // Reload coupons to reflect changes
            await loadCoupons()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to use coupon: \(error.localizedDescription)"
            }
        }
    }
    
    public func generatePersonalizedCoupons() async {
        do {
            let newCoupons = try await service.generatePersonalizedCoupons(for: customerId)
            if !newCoupons.isEmpty {
                await loadCoupons()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to generate coupons: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Helper Methods
    
    public func clearValidationResult() {
        validationResult = nil
    }
    
    public func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Computed Properties
    
    public var hasActiveCoupons: Bool {
        !customerCoupons.filter { $0.status == .active }.isEmpty
    }
    
    public var activeCouponsCount: Int {
        customerCoupons.filter { $0.status == .active }.count
    }
    
    public var expiringSoonPromotions: [Promotion] {
        let twoDaysFromNow = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        return activePromotions.filter { $0.validity.endDate <= twoDaysFromNow }
    }
    
    public var newCustomerPromotions: [Promotion] {
        return activePromotions.filter { $0.conditions.newCustomersOnly || $0.conditions.firstOrderOnly }
    }
    
    public var flashSalePromotions: [Promotion] {
        return activePromotions.filter { $0.type == .flashSale }
    }
}

// MARK: - Promotion Application Helper
public extension PromotionsViewModel {
    
    /// Calculate the best available promotion for a given order
    func findBestPromotionForOrder(_ order: OrderDraft) async -> Promotion? {
        var bestPromotion: Promotion?
        var maxDiscount: Double = 0
        
        for promotion in activePromotions {
            let validation = await validatePromotionForOrder("", order: order)
            if validation.isValid && validation.discountAmount > maxDiscount {
                maxDiscount = validation.discountAmount
                bestPromotion = promotion
            }
        }
        
        return bestPromotion
    }
    
    /// Get promotions applicable to a specific restaurant
    func getPromotionsForRestaurant(_ restaurantId: String) -> [Promotion] {
        return activePromotions.filter { promotion in
            // Check if promotion is eligible for this restaurant
            if let eligibleRestaurants = promotion.conditions.eligibleRestaurants {
                return eligibleRestaurants.contains(restaurantId)
            }
            
            if let excludedRestaurants = promotion.conditions.excludedRestaurants {
                return !excludedRestaurants.contains(restaurantId)
            }
            
            // If no restaurant restrictions, promotion is applicable
            return true
        }
    }
    
    /// Get promotions by type
    func getPromotionsByType(_ type: Promotion.PromotionType) -> [Promotion] {
        return activePromotions.filter { $0.type == type }
    }
}