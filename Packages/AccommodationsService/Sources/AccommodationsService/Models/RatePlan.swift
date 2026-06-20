import Foundation

public struct RatePlan: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let mealPlan: MealPlan
    public let cancellationPolicy: CancellationPolicy
    public let inclusions: [String]
    public let exclusions: [String]
    public let paymentType: PaymentType
    public let prepaymentRequired: Bool
    public let depositRequired: Bool
    public let depositAmount: Decimal?
    
    public init(
        id: String,
        name: String,
        mealPlan: MealPlan,
        cancellationPolicy: CancellationPolicy,
        inclusions: [String] = [],
        exclusions: [String] = [],
        paymentType: PaymentType,
        prepaymentRequired: Bool = false,
        depositRequired: Bool = false,
        depositAmount: Decimal? = nil
    ) {
        self.id = id
        self.name = name
        self.mealPlan = mealPlan
        self.cancellationPolicy = cancellationPolicy
        self.inclusions = inclusions
        self.exclusions = exclusions
        self.paymentType = paymentType
        self.prepaymentRequired = prepaymentRequired
        self.depositRequired = depositRequired
        self.depositAmount = depositAmount
    }
}

public enum MealPlan: String, Codable, CaseIterable {
    case roomOnly = "ROOM_ONLY"
    case bedAndBreakfast = "BED_AND_BREAKFAST"
    case halfBoard = "HALF_BOARD"
    case fullBoard = "FULL_BOARD"
    case allInclusive = "ALL_INCLUSIVE"
    
    public var displayName: String {
        switch self {
        case .roomOnly: return "Room Only"
        case .bedAndBreakfast: return "Bed & Breakfast"
        case .halfBoard: return "Half Board"
        case .fullBoard: return "Full Board"
        case .allInclusive: return "All Inclusive"
        }
    }
}

public enum PaymentType: String, Codable {
    case payNow = "PAY_NOW"
    case payLater = "PAY_LATER"
    case payAtProperty = "PAY_AT_PROPERTY"
}