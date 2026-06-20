import Foundation

/// Pricing engine for calculating delivery fees and order totals
public class PricingEngine {
    
    public init() {}
    
    /// Calculate pricing for an order draft
    public func calculatePricing(
        for draft: OrderDraft,
        restaurant: Restaurant,
        distanceKm: Double,
        surgeMultiplier: Double = 1.0
    ) throws -> PricedOrder {
        
        // Calculate subtotal from items
        let subtotal = draft.items.reduce(0) { $0 + $1.totalPrice }
        
        // Calculate delivery fee
        let deliveryFee = calculateDeliveryFee(
            restaurant: restaurant,
            distanceKm: distanceKm,
            surgeMultiplier: surgeMultiplier
        )
        
        // Calculate service fee (typically 2-5% of subtotal)
        let serviceFee = calculateServiceFee(subtotal: subtotal)
        
        // Calculate small order fee if applicable
        let smallOrderFee = calculateSmallOrderFee(
            subtotal: subtotal,
            restaurant: restaurant
        )
        
        // Apply promotion discount if any
        let discount = 0.0 // Will be calculated by applyPromotion method
        
        // Calculate total
        let total = subtotal + deliveryFee + serviceFee + smallOrderFee + draft.tip - discount
        
        // Estimate delivery time
        let etaMinutes = estimateDeliveryTime(
            restaurant: restaurant,
            distanceKm: distanceKm
        )
        
        return PricedOrder(
            draft: draft,
            subtotal: subtotal,
            deliveryFee: deliveryFee,
            serviceFee: serviceFee,
            smallOrderFee: smallOrderFee,
            discount: discount,
            total: total,
            etaMinutes: etaMinutes
        )
    }
    
    /// Apply a promotion to the order
    public func applyPromotion(
        code: String,
        to pricedOrder: PricedOrder,
        promotion: Promotion
    ) -> PricedOrder {
        
        guard isPromotionValid(promotion, now: Date()) else {
            return pricedOrder // Return unchanged if promotion is invalid
        }
        
        let discount = calculatePromotionDiscount(
            promotion: promotion,
            subtotal: pricedOrder.subtotal
        )
        
        let newTotal = max(0, pricedOrder.total - discount)
        
        var updatedOrder = pricedOrder
        updatedOrder.discount = discount
        updatedOrder.total = newTotal
        
        return updatedOrder
    }
    
    // MARK: - Private Methods
    
    private func calculateDeliveryFee(
        restaurant: Restaurant,
        distanceKm: Double,
        surgeMultiplier: Double
    ) -> Double {
        let policy = restaurant.deliveryFeePolicy
        let baseFee = policy.baseMAD + (policy.perKmMAD * distanceKm)
        return baseFee * surgeMultiplier
    }
    
    private func calculateServiceFee(subtotal: Double) -> Double {
        // Service fee: 3% of subtotal, capped at 15 MAD
        let feePercentage = 0.03
        let maxFee = 15.0
        return min(subtotal * feePercentage, maxFee)
    }
    
    private func calculateSmallOrderFee(
        subtotal: Double,
        restaurant: Restaurant
    ) -> Double {
        guard let minimumOrder = restaurant.deliveryFeePolicy.minimumOrderMAD,
              let smallOrderFee = restaurant.deliveryFeePolicy.smallOrderFeeMAD,
              subtotal < minimumOrder else {
            return 0.0
        }
        return smallOrderFee
    }
    
    private func calculatePromotionDiscount(
        promotion: Promotion,
        subtotal: Double
    ) -> Double {
        switch promotion.discount.type {
        case .fixedAmount:
            return min(promotion.discount.value, subtotal)
        case .percentage:
            let discount = subtotal * (promotion.discount.value / 100.0)
            if let maxDiscount = promotion.discount.maxDiscount {
                return min(discount, maxDiscount)
            }
            return discount
        case .freeItem:
            return 0
        }
    }
    
    private func estimateDeliveryTime(
        restaurant: Restaurant,
        distanceKm: Double
    ) -> Int {
        // Base preparation time + travel time
        let prepTime = restaurant.avgPrepMinutes
        let travelTimeMinutes = Int(distanceKm * 3) // ~3 minutes per km
        let bufferTime = 5 // Add buffer for dispatch and handoff
        
        return prepTime + travelTimeMinutes + bufferTime
    }
}

// MARK: - Helpers
private func isPromotionValid(_ promotion: Promotion, now: Date) -> Bool {
    guard promotion.status == .active else { return false }
    return now >= promotion.validity.startDate && now <= promotion.validity.endDate
}

// MARK: - Surge Pricing
public struct SurgePricingCalculator {
    
    public init() {}
    
    /// Calculate surge multiplier based on demand and supply
    public func calculateSurgeMultiplier(
        for location: Coordinates,
        at time: Date,
        availableCouriers: Int,
        pendingOrders: Int
    ) -> Double {
        
        // Base multiplier
        var multiplier = 1.0
        
        // Demand-supply ratio
        if availableCouriers > 0 {
            let demandSupplyRatio = Double(pendingOrders) / Double(availableCouriers)
            
            switch demandSupplyRatio {
            case 0..<1:
                multiplier = 1.0
            case 1..<2:
                multiplier = 1.25
            case 2..<3:
                multiplier = 1.5
            case 3..<5:
                multiplier = 1.75
            default:
                multiplier = 2.0
            }
        } else if pendingOrders > 0 {
            // No couriers available
            multiplier = 2.0
        }
        
        // Time-based surge (peak hours)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let dayOfWeek = calendar.component(.weekday, from: time)
        
        // Weekend evenings get higher surge
        if [6, 7].contains(dayOfWeek) && hour >= 19 && hour <= 22 {
            multiplier += 0.25
        }
        
        // Lunch rush
        if hour >= 12 && hour <= 14 {
            multiplier += 0.15
        }
        
        // Dinner rush
        if hour >= 19 && hour <= 21 {
            multiplier += 0.2
        }
        
        return min(multiplier, 2.5) // Cap at 2.5x
    }
}