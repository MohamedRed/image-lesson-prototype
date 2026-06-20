import Foundation
import FirebaseFunctions
import FirebaseCore

/// AI-powered pricing suggestion engine
/// Per Section 9 and AI requirements in implementation-plan.md
public final class PricingSuggestionEngine {
    
    // MARK: - Properties
    
    private lazy var functions: Functions = {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return Functions.functions()
    }()
    private let cache = NSCache<NSString, PricingSuggestion>()
    
    // MARK: - Init
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Get AI-powered price suggestion for a listing
    public func suggestPrice(
        for category: ListingCategory,
        condition: ItemCondition,
        title: String,
        description: String,
        attributes: [String: String],
        cityId: String
    ) async throws -> PricingSuggestion {
        
        // Check cache first
        let cacheKey = "\(category.rawValue)_\(condition.rawValue)_\(cityId)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        // Call backend AI pricing function
        let data: [String: Any] = [
            "category": category.rawValue,
            "condition": condition.rawValue,
            "title": title,
            "description": description,
            "attributes": attributes,
            "cityId": cityId
        ]
        
        let result = try await functions.httpsCallable("marketplace.pricing.suggest").call(data)
        
        guard let responseData = result.data as? [String: Any],
              let suggestedAmount = responseData["suggestedPrice"] as? Int,
              let currency = responseData["currency"] as? String else {
            throw PricingError.invalidResponse
        }
        
        let suggestion = PricingSuggestion(
            suggestedPrice: Money(amount: suggestedAmount, currency: currency),
            priceRange: PricingSuggestion.PriceRange(
                min: Money(
                    amount: responseData["minPrice"] as? Int ?? (suggestedAmount * 80 / 100),
                    currency: currency
                ),
                max: Money(
                    amount: responseData["maxPrice"] as? Int ?? (suggestedAmount * 120 / 100),
                    currency: currency
                )
            ),
            confidence: responseData["confidence"] as? Double ?? 0.7,
            comparables: (responseData["comparables"] as? [[String: Any]])?.compactMap { dict in
                ComparableListing(
                    id: dict["id"] as? String ?? "",
                    title: dict["title"] as? String ?? "",
                    price: Money(
                        amount: dict["price"] as? Int ?? 0,
                        currency: currency
                    ),
                    soldAt: (dict["soldAt"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
                )
            } ?? [],
            reasoning: responseData["reasoning"] as? String
        )
        
        // Cache the result
        cache.setObject(suggestion, forKey: cacheKey)
        
        return suggestion
    }
    
    /// Analyze price competitiveness
    public func analyzePriceCompetitiveness(
        price: Money,
        category: ListingCategory,
        condition: ItemCondition,
        cityId: String
    ) async throws -> PriceAnalysis {
        
        let data: [String: Any] = [
            "price": [
                "amount": price.amount,
                "currency": price.currency
            ],
            "category": category.rawValue,
            "condition": condition.rawValue,
            "cityId": cityId
        ]
        
        let result = try await functions.httpsCallable("marketplace.pricing.analyze").call(data)
        
        guard let responseData = result.data as? [String: Any] else {
            throw PricingError.invalidResponse
        }
        
        return PriceAnalysis(
            competitiveness: CompetitivenessLevel(
                rawValue: responseData["competitiveness"] as? String ?? "fair"
            ) ?? .fair,
            percentile: responseData["percentile"] as? Int ?? 50,
            averagePrice: Money(
                amount: responseData["averagePrice"] as? Int ?? price.amount,
                currency: price.currency
            ),
            suggestion: responseData["suggestion"] as? String,
            expectedDaysToSell: responseData["expectedDaysToSell"] as? Int
        )
    }
    
    /// Get dynamic pricing recommendations based on market conditions
    public func getDynamicPricingRecommendation(
        listingId: String,
        currentPrice: Money,
        daysSinceListing: Int,
        viewCount: Int,
        offerCount: Int
    ) async throws -> DynamicPricingRecommendation {
        
        let data: [String: Any] = [
            "listingId": listingId,
            "currentPrice": [
                "amount": currentPrice.amount,
                "currency": currentPrice.currency
            ],
            "daysSinceListing": daysSinceListing,
            "viewCount": viewCount,
            "offerCount": offerCount
        ]
        
        let result = try await functions.httpsCallable("marketplace.pricing.dynamic").call(data)
        
        guard let responseData = result.data as? [String: Any] else {
            throw PricingError.invalidResponse
        }
        
        let action = PricingAction(rawValue: responseData["action"] as? String ?? "hold") ?? .hold
        
        return DynamicPricingRecommendation(
            action: action,
            newPrice: action == .reduce ? Money(
                amount: responseData["newPrice"] as? Int ?? currentPrice.amount,
                currency: currentPrice.currency
            ) : nil,
            reasoning: responseData["reasoning"] as? String ?? "",
            expectedImpact: responseData["expectedImpact"] as? String
        )
    }
}

// MARK: - Pricing Models

public final class PricingSuggestion {
    public let suggestedPrice: Money
    public let priceRange: PriceRange
    public let confidence: Double // 0.0 to 1.0
    public let comparables: [ComparableListing]
    public let reasoning: String?
    
    public struct PriceRange {
        public let min: Money
        public let max: Money
    }

    public init(
        suggestedPrice: Money,
        priceRange: PriceRange,
        confidence: Double,
        comparables: [ComparableListing],
        reasoning: String?
    ) {
        self.suggestedPrice = suggestedPrice
        self.priceRange = priceRange
        self.confidence = confidence
        self.comparables = comparables
        self.reasoning = reasoning
    }
}

public struct ComparableListing {
    public let id: String
    public let title: String
    public let price: Money
    public let soldAt: Date?
}

public struct PriceAnalysis {
    public let competitiveness: CompetitivenessLevel
    public let percentile: Int // 0-100, where 50 is median
    public let averagePrice: Money
    public let suggestion: String?
    public let expectedDaysToSell: Int?
}

public enum CompetitivenessLevel: String {
    case veryLow = "very_low"
    case low = "low"
    case fair = "fair"
    case high = "high"
    case veryHigh = "very_high"
    
    public var displayName: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .fair: return "Fair"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
    
    public var color: String {
        switch self {
        case .veryLow: return "green"
        case .low: return "lightGreen"
        case .fair: return "blue"
        case .high: return "orange"
        case .veryHigh: return "red"
        }
    }
}

public struct DynamicPricingRecommendation {
    public let action: PricingAction
    public let newPrice: Money?
    public let reasoning: String
    public let expectedImpact: String?
}

public enum PricingAction: String {
    case reduce = "reduce"
    case hold = "hold"
    case increase = "increase"
    case promote = "promote" // Suggest promotion instead of price change
}

// MARK: - Errors

public enum PricingError: LocalizedError {
    case invalidResponse
    case insufficientData
    case serviceUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid pricing response from server"
        case .insufficientData:
            return "Not enough market data for pricing suggestion"
        case .serviceUnavailable:
            return "Pricing service temporarily unavailable"
        }
    }
}