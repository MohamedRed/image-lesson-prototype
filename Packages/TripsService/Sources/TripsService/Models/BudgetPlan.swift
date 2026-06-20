import Foundation

// MARK: - Budget Planning Models

/// Budget plan for trip expenses
public struct BudgetPlan: Codable, Hashable {
    public let id: String
    public let tripId: String
    public var target: Money
    public var current: Money
    public var forecast: Money
    public var allocations: [BudgetAllocation]
    public var expenses: [Expense]
    public var alerts: [BudgetAlert]
    public var savingsPlan: SavingsPlan?
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        tripId: String,
        target: Money,
        current: Money = Money(amount: 0.0),
        forecast: Money = Money(amount: 0.0),
        allocations: [BudgetAllocation] = [],
        expenses: [Expense] = [],
        alerts: [BudgetAlert] = [],
        savingsPlan: SavingsPlan? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.tripId = tripId
        self.target = target
        self.current = current
        self.forecast = forecast
        self.allocations = allocations
        self.expenses = expenses
        self.alerts = alerts
        self.savingsPlan = savingsPlan
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Calculate remaining budget
    public var remaining: Money {
        Money(amount: target.amount - current.amount, currency: target.currency)
    }
    
    /// Calculate budget utilization percentage
    public var utilizationPercentage: Double {
        guard target.amount > 0 else { return 0 }
        return (Double(truncating: current.amount as NSNumber) / Double(truncating: target.amount as NSNumber)) * 100
    }
    
    /// Check if over budget
    public var isOverBudget: Bool {
        current.amount > target.amount
    }
}

/// Budget allocation by category
public struct BudgetAllocation: Codable, Hashable, Identifiable {
    public let id: String
    public let category: BudgetCategory
    public var allocated: Money
    public var spent: Money
    public var percentage: Double // Percentage of total budget
    
    public init(
        id: String = UUID().uuidString,
        category: BudgetCategory,
        allocated: Money,
        spent: Money = Money(amount: 0.0),
        percentage: Double
    ) {
        self.id = id
        self.category = category
        self.allocated = allocated
        self.spent = spent
        self.percentage = percentage
    }
    
    /// Calculate remaining allocation
    public var remaining: Money {
        Money(amount: allocated.amount - spent.amount, currency: allocated.currency)
    }
    
    /// Check if allocation is exceeded
    public var isExceeded: Bool {
        spent.amount > allocated.amount
    }
}

/// Individual expense record
public struct Expense: Codable, Hashable, Identifiable {
    public let id: String
    public let category: BudgetCategory
    public let subcategory: String?
    public let amount: Money
    public let description: String
    public let date: Date
    public let bookingRef: String?
    public let segmentId: String?
    public var tags: [String]
    public let addedBy: String
    
    public init(
        id: String = UUID().uuidString,
        category: BudgetCategory,
        subcategory: String? = nil,
        amount: Money,
        description: String,
        date: Date = Date(),
        bookingRef: String? = nil,
        segmentId: String? = nil,
        tags: [String] = [],
        addedBy: String
    ) {
        self.id = id
        self.category = category
        self.subcategory = subcategory
        self.amount = amount
        self.description = description
        self.date = date
        self.bookingRef = bookingRef
        self.segmentId = segmentId
        self.tags = tags
        self.addedBy = addedBy
    }
}

/// Budget alert
public struct BudgetAlert: Codable, Hashable, Identifiable {
    public let id: String
    public let type: AlertType
    public let severity: AlertSeverity
    public let message: String
    public let category: BudgetCategory?
    public let threshold: Double
    public let currentValue: Double
    public let triggeredAt: Date
    public var acknowledged: Bool
    
    public init(
        id: String = UUID().uuidString,
        type: AlertType,
        severity: AlertSeverity,
        message: String,
        category: BudgetCategory? = nil,
        threshold: Double,
        currentValue: Double,
        triggeredAt: Date = Date(),
        acknowledged: Bool = false
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.message = message
        self.category = category
        self.threshold = threshold
        self.currentValue = currentValue
        self.triggeredAt = triggeredAt
        self.acknowledged = acknowledged
    }
}

/// Alert type
public enum AlertType: String, Codable, CaseIterable {
    case budget_exceeded
    case category_exceeded
    case approaching_limit
    case price_increase
    case savings_behind
    case unusual_expense
}

/// Alert severity
public enum AlertSeverity: String, Codable, CaseIterable {
    case info
    case warning
    case critical
}

/// Savings plan for trip funding
public struct SavingsPlan: Codable, Hashable {
    public let id: String
    public let targetAmount: Money
    public let startDate: Date
    public let targetDate: Date
    public var savedAmount: Money
    public let frequency: SavingsFrequency
    public let suggestedAmount: Money
    public var contributions: [SavingsContribution]
    public var milestones: [SavingsMilestone]
    
    public init(
        id: String = UUID().uuidString,
        targetAmount: Money,
        startDate: Date,
        targetDate: Date,
        savedAmount: Money = Money(amount: 0.0),
        frequency: SavingsFrequency,
        suggestedAmount: Money,
        contributions: [SavingsContribution] = [],
        milestones: [SavingsMilestone] = []
    ) {
        self.id = id
        self.targetAmount = targetAmount
        self.startDate = startDate
        self.targetDate = targetDate
        self.savedAmount = savedAmount
        self.frequency = frequency
        self.suggestedAmount = suggestedAmount
        self.contributions = contributions
        self.milestones = milestones
    }
    
    /// Calculate progress percentage
    public var progressPercentage: Double {
        guard targetAmount.amount > 0 else { return 0 }
        return (Double(truncating: savedAmount.amount as NSNumber) / Double(truncating: targetAmount.amount as NSNumber)) * 100
    }
    
    /// Calculate remaining amount to save
    public var remainingAmount: Money {
        Money(amount: targetAmount.amount - savedAmount.amount, currency: targetAmount.currency)
    }
    
    /// Check if on track
    public var isOnTrack: Bool {
        let totalDays = targetDate.timeIntervalSince(startDate) / (24 * 60 * 60)
        let elapsedDays = Date().timeIntervalSince(startDate) / (24 * 60 * 60)
        let expectedProgress = elapsedDays / totalDays
        let actualProgress = progressPercentage / 100
        return actualProgress >= expectedProgress * 0.9 // Allow 10% buffer
    }
}

/// Savings frequency
public enum SavingsFrequency: String, Codable, CaseIterable {
    case daily
    case weekly
    case biweekly
    case monthly
    case custom
}

/// Savings contribution record
public struct SavingsContribution: Codable, Hashable, Identifiable {
    public let id: String
    public let amount: Money
    public let date: Date
    public let method: String
    public let notes: String?
    
    public init(
        id: String = UUID().uuidString,
        amount: Money,
        date: Date = Date(),
        method: String,
        notes: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.method = method
        self.notes = notes
    }
}

/// Savings milestone
public struct SavingsMilestone: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let targetAmount: Money
    public let targetDate: Date
    public var reached: Bool
    public var reachedDate: Date?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        targetAmount: Money,
        targetDate: Date,
        reached: Bool = false,
        reachedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.reached = reached
        self.reachedDate = reachedDate
    }
}

// MARK: - Price Tracking

/// Price tracking for bookable items
public struct PriceTracker: Codable, Hashable {
    public let id: String
    public let itemType: TrackableItemType
    public let itemId: String
    public let itemDescription: String
    public var priceHistory: [PricePoint]
    public let alertThreshold: Money?
    public var currentPrice: Money
    public let startedAt: Date
    public var lastCheckedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        itemType: TrackableItemType,
        itemId: String,
        itemDescription: String,
        priceHistory: [PricePoint] = [],
        alertThreshold: Money? = nil,
        currentPrice: Money,
        startedAt: Date = Date(),
        lastCheckedAt: Date = Date()
    ) {
        self.id = id
        self.itemType = itemType
        self.itemId = itemId
        self.itemDescription = itemDescription
        self.priceHistory = priceHistory
        self.alertThreshold = alertThreshold
        self.currentPrice = currentPrice
        self.startedAt = startedAt
        self.lastCheckedAt = lastCheckedAt
    }
    
    /// Get price trend
    public var trend: PriceTrend {
        guard priceHistory.count >= 2 else { return .stable }
        let recent = priceHistory.suffix(5)
        let firstPrice = recent.first!.price.amount
        let lastPrice = recent.last!.price.amount
        
        if lastPrice > firstPrice {
            return .increasing
        } else if lastPrice < firstPrice {
            return .decreasing
        } else {
            return .stable
        }
    }
}

/// Trackable item type
public enum TrackableItemType: String, Codable, CaseIterable {
    case flight
    case hotel
    case activity
    case package
}

/// Price point in history
public struct PricePoint: Codable, Hashable {
    public let price: Money
    public let date: Date
    public let availability: Bool
    
    public init(price: Money, date: Date, availability: Bool = true) {
        self.price = price
        self.date = date
        self.availability = availability
    }
}

/// Price trend
public enum PriceTrend: String, Codable, CaseIterable {
    case increasing
    case decreasing
    case stable
    case volatile
}