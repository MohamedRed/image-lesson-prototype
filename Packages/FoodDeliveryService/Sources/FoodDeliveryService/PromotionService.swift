import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseFunctions
import Combine

/// Service for managing promotions and coupons
public protocol PromotionServiceProtocol {
    // Promotion management
    func getActivePromotions() async throws -> [Promotion]
    func getPromotionsForCustomer(_ customerId: String) async throws -> [Promotion]
    func getPromotionByCode(_ code: String) async throws -> Promotion?
    func validatePromotion(code: String, for order: OrderDraft, customerId: String) async throws -> PromotionValidationResult
    func applyPromotion(_ promotion: Promotion, to order: OrderDraft) -> PricedOrder
    
    // Coupon management
    func getCustomerCoupons(_ customerId: String) async throws -> [Coupon]
    func validateCoupon(code: String, customerId: String) async throws -> PromotionValidationResult
    func useCoupon(code: String, orderId: String, customerId: String) async throws
    func generatePersonalizedCoupons(for customerId: String) async throws -> [Coupon]
    
    // Customer eligibility
    func getCustomerEligibility(_ customerId: String) async throws -> CustomerPromotionEligibility
    func updateCustomerPromotionUsage(customerId: String, promotionId: String, discountAmount: Double) async throws
    
    // Publisher for real-time updates
    var promotionsPublisher: AnyPublisher<[Promotion], Never> { get }
    var customerCouponsPublisher: AnyPublisher<[Coupon], Never> { get }
}

public class PromotionService: PromotionServiceProtocol {
    private let firestore = Firestore.firestore()
    private let functions = Functions.functions()
    private let promotionsCollection: CollectionReference
    private let couponsCollection: CollectionReference
    private let customerEligibilityCollection: CollectionReference
    
    private let promotionsSubject = CurrentValueSubject<[Promotion], Never>([])
    private let customerCouponsSubject = CurrentValueSubject<[Coupon], Never>([])
    
    public var promotionsPublisher: AnyPublisher<[Promotion], Never> {
        promotionsSubject.eraseToAnyPublisher()
    }
    
    public var customerCouponsPublisher: AnyPublisher<[Coupon], Never> {
        customerCouponsSubject.eraseToAnyPublisher()
    }
    
    public init() {
        self.promotionsCollection = firestore.collection("promotions")
        self.couponsCollection = firestore.collection("coupons")
        self.customerEligibilityCollection = firestore.collection("customerPromotionEligibility")
    }
    
    // MARK: - Promotion Management
    
    public func getActivePromotions() async throws -> [Promotion] {
        let result = try await functions.httpsCallable("getActivePromotions").call([:])
        guard let data = result.data as? [String: Any], let arr = data["promotions"] as? [[String: Any]] else { return [] }
        let promos = try arr.map { try Firestore.Decoder().decode(Promotion.self, from: $0) }
        promotionsSubject.send(promos)
        return promos
    }
    
    public func getPromotionsForCustomer(_ customerId: String) async throws -> [Promotion] {
        let eligibility = try await getCustomerEligibility(customerId)
        let activePromotions = try await getActivePromotions()
        
        // Filter promotions based on customer eligibility
        let eligiblePromotions = activePromotions.filter { promotion in
            // Check if customer is eligible
            if let specificCustomers = promotion.targets.specificCustomers {
                if !specificCustomers.contains(customerId) {
                    return false
                }
            }
            
            if let excludedCustomers = promotion.targets.excludedCustomers {
                if excludedCustomers.contains(customerId) {
                    return false
                }
            }
            
            // Check new customer restrictions
            if promotion.conditions.newCustomersOnly {
                return eligibility.totalOrderCount == 0
            }
            
            // Check first order restrictions
            if promotion.conditions.firstOrderOnly {
                return eligibility.totalOrderCount == 0
            }
            
            // Check loyalty tier requirements
            if let requiredTiers = promotion.targets.loyaltyTiers {
                guard let customerTier = eligibility.currentLoyaltyTier else {
                    return false
                }
                return requiredTiers.contains(customerTier)
            }
            
            // Check usage limits
            if let perCustomerLimit = promotion.usage.perCustomerLimit {
                let customerUsage = eligibility.usedPromotions[promotion.id ?? ""] ?? 0
                if customerUsage >= perCustomerLimit {
                    return false
                }
            }
            
            return true
        }
        
        return eligiblePromotions
    }
    
    public func getPromotionByCode(_ code: String) async throws -> Promotion? {
        // First try to find a coupon with this code
        let couponQuery = couponsCollection.whereField("code", isEqualTo: code.uppercased())
        let couponSnapshot = try await couponQuery.getDocuments()
        
        if let couponDoc = couponSnapshot.documents.first {
            let coupon = try couponDoc.data(as: Coupon.self)
            
            // Get the associated promotion
            let promotionDoc = try await promotionsCollection.document(coupon.promotionId).getDocument()
            return try promotionDoc.data(as: Promotion.self)
        }
        
        // If no coupon found, look for public promotion codes (if implemented)
        return nil
    }
    
    public func validatePromotion(code: String, for order: OrderDraft, customerId: String) async throws -> PromotionValidationResult {
        let body: [String: Any] = [
            "code": code,
            "restaurantId": order.restaurantId,
            "orderValue": order.items.reduce(0) { $0 + $1.totalPrice }
        ]
        let result = try await functions.httpsCallable("validatePromotion").call(body)
        guard let data = result.data as? [String: Any] else {
            return PromotionValidationResult(isValid: false, message: "Invalid response")
        }
        if (data["success"] as? Bool) == true {
            let discount = (data["discount"] as? Double) ?? 0.0
            return PromotionValidationResult(isValid: true, discountAmount: discount, message: "Promotion applied successfully!")
        } else {
            return PromotionValidationResult(isValid: false, message: data["error"] as? String ?? "Promotion invalid")
        }
    }
    
    public func applyPromotion(_ promotion: Promotion, to order: OrderDraft) -> PricedOrder {
        let subtotal = order.items.reduce(0) { $0 + $1.totalPrice }
        let deliveryFee = 15.0 // Base delivery fee
        let serviceFee = subtotal * 0.05 // 5% service fee
        
        var finalDeliveryFee = deliveryFee
        var discount = calculateDiscount(promotion: promotion, orderSubtotal: subtotal)
        
        // Apply free delivery if specified
        if promotion.discount.freeDelivery {
            finalDeliveryFee = 0
        }
        
        // Apply discount based on target
        switch promotion.discount.applyTo {
        case .deliveryFee:
            finalDeliveryFee = max(0, deliveryFee - discount)
            discount = deliveryFee - finalDeliveryFee
        case .serviceFee:
            let serviceDiscount = min(discount, serviceFee)
            discount = serviceDiscount
        case .subtotal, .total:
            // Discount is applied to subtotal
            break
        case .specificItems:
            // Would need item-level discount logic
            break
        }
        
        let total = max(0, subtotal + finalDeliveryFee + serviceFee - discount + order.tip)
        
        return PricedOrder(
            draft: order,
            subtotal: subtotal,
            deliveryFee: finalDeliveryFee,
            serviceFee: serviceFee,
            discount: discount,
            total: total,
            etaMinutes: 35
        )
    }
    
    // MARK: - Coupon Management
    
    public func getCustomerCoupons(_ customerId: String) async throws -> [Coupon] {
        let query = couponsCollection
            .whereField("assignedToCustomer", isEqualTo: customerId)
            .whereField("status", isEqualTo: Coupon.CouponStatus.active.rawValue)
        
        let snapshot = try await query.getDocuments()
        let coupons = try snapshot.documents.compactMap { document in
            try document.data(as: Coupon.self)
        }
        
        customerCouponsSubject.send(coupons)
        return coupons
    }
    
    public func validateCoupon(code: String, customerId: String) async throws -> PromotionValidationResult {
        let query = couponsCollection
            .whereField("code", isEqualTo: code.uppercased())
            .whereField("assignedToCustomer", isEqualTo: customerId)
        
        let snapshot = try await query.getDocuments()
        
        guard let couponDoc = snapshot.documents.first else {
            return PromotionValidationResult(
                isValid: false,
                message: "Coupon not found or not assigned to you",
                errors: [.promotionNotFound]
            )
        }
        
        let coupon = try couponDoc.data(as: Coupon.self)
        
        if coupon.status != .active {
            return PromotionValidationResult(
                isValid: false,
                message: "This coupon has already been used or expired",
                errors: [.usageLimitExceeded]
            )
        }
        
        // Get and validate the associated promotion
        let promotionDoc = try await promotionsCollection.document(coupon.promotionId).getDocument()
        let promotion = try promotionDoc.data(as: Promotion.self)
        
        if promotion.status != .active {
            return PromotionValidationResult(
                isValid: false,
                message: "The associated promotion is no longer active",
                errors: [.promotionInactive]
            )
        }
        
        return PromotionValidationResult(
            isValid: true,
            message: "Coupon is valid",
            appliedPromotion: promotion
        )
    }
    
    public func useCoupon(code: String, orderId: String, customerId: String) async throws {
        let query = couponsCollection
            .whereField("code", isEqualTo: code.uppercased())
            .whereField("assignedToCustomer", isEqualTo: customerId)
        
        let snapshot = try await query.getDocuments()
        
        guard let couponDoc = snapshot.documents.first else {
            throw FoodDeliveryError.networkError("Coupon not found")
        }
        
        var coupon = try couponDoc.data(as: Coupon.self)
        
        // Mark coupon as used
        coupon.status = .used
        coupon.usageHistory.append(Coupon.CouponUsage(
            orderId: orderId,
            customerId: customerId,
            discountApplied: 0 // Would be calculated during order processing
        ))
        
        try couponDoc.reference.setData(from: coupon)
    }
    
    public func generatePersonalizedCoupons(for customerId: String) async throws -> [Coupon] {
        let eligibility = try await getCustomerEligibility(customerId)
        var newCoupons: [Coupon] = []
        
        // Generate first-order coupon for new customers
        if eligibility.totalOrderCount == 0 {
            let firstOrderPromotion = createFirstOrderPromotion()
            let coupon = Coupon(
                code: generateCouponCode(prefix: "WELCOME"),
                title: "Welcome to Liive Food!",
                description: "Get 20% off your first order",
                promotionId: "first_order_promo",
                assignedToCustomer: customerId
            )
            newCoupons.append(coupon)
        }
        
        // Generate loyalty coupons based on order history
        if eligibility.totalOrderCount >= 5 {
            let loyaltyCoupon = Coupon(
                code: generateCouponCode(prefix: "LOYAL"),
                title: "Loyal Customer Reward",
                description: "Free delivery on your next order",
                promotionId: "loyalty_promo",
                assignedToCustomer: customerId
            )
            newCoupons.append(loyaltyCoupon)
        }
        
        // Save coupons to Firestore
        for coupon in newCoupons {
            try couponsCollection.addDocument(from: coupon)
        }
        
        return newCoupons
    }
    
    // MARK: - Customer Eligibility
    
    public func getCustomerEligibility(_ customerId: String) async throws -> CustomerPromotionEligibility {
        let doc = customerEligibilityCollection.document(customerId)
        let snapshot = try await doc.getDocument()
        
        if snapshot.exists {
            return try snapshot.data(as: CustomerPromotionEligibility.self)
        } else {
            // Create new eligibility record
            let eligibility = CustomerPromotionEligibility(customerId: customerId)
            try doc.setData(from: eligibility)
            return eligibility
        }
    }
    
    public func updateCustomerPromotionUsage(customerId: String, promotionId: String, discountAmount: Double) async throws {
        let doc = customerEligibilityCollection.document(customerId)
        
        try await firestore.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(doc)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            var eligibility: CustomerPromotionEligibility
            if snapshot.exists {
                do {
                    eligibility = try snapshot.data(as: CustomerPromotionEligibility.self)
                } catch let decodeError as NSError {
                    errorPointer?.pointee = decodeError
                    return nil
                }
            } else {
                eligibility = CustomerPromotionEligibility(customerId: customerId)
            }
            
            // Update usage count
            let currentUsage = eligibility.usedPromotions[promotionId] ?? 0
            eligibility.usedPromotions[promotionId] = currentUsage + 1
            
            do {
                try transaction.setData(from: eligibility, forDocument: doc)
            } catch let updateError as NSError {
                errorPointer?.pointee = updateError
                return nil
            }
            
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateDiscount(promotion: Promotion, orderSubtotal: Double) -> Double {
        switch promotion.discount.type {
        case .percentage:
            let discount = orderSubtotal * (promotion.discount.value / 100)
            if let maxDiscount = promotion.discount.maxDiscount {
                return min(discount, maxDiscount)
            }
            return discount
            
        case .fixedAmount:
            return min(promotion.discount.value, orderSubtotal)
            
        case .freeItem:
            // Would require item-specific logic
            return 0
        }
    }
    
    private func generateCouponCode(prefix: String) -> String {
        let suffix = String(Int.random(in: 1000...9999))
        return "\(prefix)\(suffix)"
    }
    
    private func createFirstOrderPromotion() -> Promotion {
        return Promotion(
            title: "First Order Discount",
            description: "20% off your first order",
            type: .firstOrder,
            discount: Promotion.DiscountInfo(
                type: .percentage,
                value: 20,
                maxDiscount: 50
            ),
            validity: Promotion.PromotionValidity(
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
            )
        )
    }
}

// MARK: - Mock Implementation
public class MockPromotionService: PromotionServiceProtocol {
    private let promotionsSubject = CurrentValueSubject<[Promotion], Never>([])
    private let customerCouponsSubject = CurrentValueSubject<[Coupon], Never>([])
    
    public var promotionsPublisher: AnyPublisher<[Promotion], Never> {
        promotionsSubject.eraseToAnyPublisher()
    }
    
    public var customerCouponsPublisher: AnyPublisher<[Coupon], Never> {
        customerCouponsSubject.eraseToAnyPublisher()
    }
    
    private var mockPromotions: [Promotion] = []
    private var mockCoupons: [Coupon] = []
    
    public init() {
        setupMockData()
    }
    
    private func setupMockData() {
        // Create mock promotions
        mockPromotions = [
            Promotion(
                id: "promo1",
                title: "Weekend Special",
                description: "20% off all orders this weekend",
                imageUrl: "https://example.com/weekend.jpg",
                type: .discount,
                discount: Promotion.DiscountInfo(type: .percentage, value: 20, maxDiscount: 50),
                validity: Promotion.PromotionValidity(
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                )
            ),
            Promotion(
                id: "promo2",
                title: "Free Delivery Friday",
                description: "Free delivery on all orders over MAD 100",
                type: .freeDelivery,
                discount: Promotion.DiscountInfo(type: .fixedAmount, value: 15, freeDelivery: true, applyTo: .deliveryFee),
                conditions: Promotion.PromotionConditions(minimumOrderValue: 100),
                validity: Promotion.PromotionValidity(
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
                )
            ),
            Promotion(
                id: "promo3",
                title: "First Order Welcome",
                description: "25% off your first order with us",
                type: .firstOrder,
                discount: Promotion.DiscountInfo(type: .percentage, value: 25, maxDiscount: 75),
                conditions: Promotion.PromotionConditions(firstOrderOnly: true),
                validity: Promotion.PromotionValidity(
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
                )
            )
        ]
        
        // Create mock coupons
        mockCoupons = [
            Coupon(
                id: "coupon1",
                code: "WELCOME2024",
                title: "Welcome Discount",
                description: "25% off your first order",
                promotionId: "promo3",
                assignedToCustomer: "customer123"
            ),
            Coupon(
                id: "coupon2",
                code: "FREEDEL123",
                title: "Free Delivery",
                description: "Free delivery on your next order",
                promotionId: "promo2",
                assignedToCustomer: "customer123"
            )
        ]
        
        promotionsSubject.send(mockPromotions)
        customerCouponsSubject.send(mockCoupons)
    }
    
    public func getActivePromotions() async throws -> [Promotion] {
        return mockPromotions
    }
    
    public func getPromotionsForCustomer(_ customerId: String) async throws -> [Promotion] {
        return mockPromotions
    }
    
    public func getPromotionByCode(_ code: String) async throws -> Promotion? {
        let coupon = mockCoupons.first { $0.code == code.uppercased() }
        return mockPromotions.first { $0.id == coupon?.promotionId }
    }
    
    public func validatePromotion(code: String, for order: OrderDraft, customerId: String) async throws -> PromotionValidationResult {
        guard let promotion = try await getPromotionByCode(code) else {
            return PromotionValidationResult(
                isValid: false,
                message: "Promotion code not found",
                errors: [.promotionNotFound]
            )
        }
        
        let orderSubtotal = order.items.reduce(0) { $0 + $1.totalPrice }
        let discountAmount = calculateMockDiscount(promotion: promotion, orderSubtotal: orderSubtotal)
        
        return PromotionValidationResult(
            isValid: true,
            discountAmount: discountAmount,
            message: "Promotion applied successfully!",
            appliedPromotion: promotion
        )
    }
    
    public func applyPromotion(_ promotion: Promotion, to order: OrderDraft) -> PricedOrder {
        let subtotal = order.items.reduce(0) { $0 + $1.totalPrice }
        let deliveryFee = promotion.discount.freeDelivery ? 0 : 15.0
        let serviceFee = subtotal * 0.05
        let discount = calculateMockDiscount(promotion: promotion, orderSubtotal: subtotal)
        let total = subtotal + deliveryFee + serviceFee - discount + order.tip
        
        return PricedOrder(
            draft: order,
            subtotal: subtotal,
            deliveryFee: deliveryFee,
            serviceFee: serviceFee,
            discount: discount,
            total: total,
            etaMinutes: 35
        )
    }
    
    public func getCustomerCoupons(_ customerId: String) async throws -> [Coupon] {
        return mockCoupons.filter { $0.assignedToCustomer == customerId }
    }
    
    public func validateCoupon(code: String, customerId: String) async throws -> PromotionValidationResult {
        guard let coupon = mockCoupons.first(where: { $0.code == code.uppercased() && $0.assignedToCustomer == customerId }) else {
            return PromotionValidationResult(
                isValid: false,
                message: "Coupon not found",
                errors: [.promotionNotFound]
            )
        }
        
        return PromotionValidationResult(
            isValid: true,
            message: "Coupon is valid"
        )
    }
    
    public func useCoupon(code: String, orderId: String, customerId: String) async throws {
        // Mock implementation - in real app would update database
    }
    
    public func generatePersonalizedCoupons(for customerId: String) async throws -> [Coupon] {
        return []
    }
    
    public func getCustomerEligibility(_ customerId: String) async throws -> CustomerPromotionEligibility {
        return CustomerPromotionEligibility(customerId: customerId)
    }
    
    public func updateCustomerPromotionUsage(customerId: String, promotionId: String, discountAmount: Double) async throws {
        // Mock implementation
    }
    
    private func calculateMockDiscount(promotion: Promotion, orderSubtotal: Double) -> Double {
        switch promotion.discount.type {
        case .percentage:
            let discount = orderSubtotal * (promotion.discount.value / 100)
            if let maxDiscount = promotion.discount.maxDiscount {
                return min(discount, maxDiscount)
            }
            return discount
        case .fixedAmount:
            return min(promotion.discount.value, orderSubtotal)
        case .freeItem:
            return 0
        }
    }
}