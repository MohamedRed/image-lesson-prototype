import Foundation
import Combine

/// Cash on Delivery payment processor for food delivery orders
public class CODPaymentProcessor {
    
    // MARK: - Public Properties
    public static let shared = CODPaymentProcessor()
    
    // MARK: - Private Properties
    private let cashValidationService: CashValidationService
    private let courierPayoutService: CourierPayoutService
    private let orderStatusTracker: OrderStatusTracker
    
    // MARK: - Initialization
    private init() {
        self.cashValidationService = CashValidationService()
        self.courierPayoutService = CourierPayoutService()
        self.orderStatusTracker = OrderStatusTracker()
    }
    
    // MARK: - Public Methods
    
    /// Process COD payment when order is created
    public func processCODOrder(_ order: Order) async throws -> CODPaymentResult {
        // Validate order for COD eligibility
        try validateCODEligibility(order)
        
        // Create COD payment record
        let codPayment = CODPayment(
            orderId: order.id!,
            amount: order.total,
            currency: "MAD",
            status: .pending,
            customerInstructions: generateCustomerInstructions(for: order),
            courierInstructions: generateCourierInstructions(for: order),
            expectedDeliveryTime: order.estimatedDeliveryTime,
            createdAt: Date()
        )
        
        // Store COD payment details
        try await storeCODPayment(codPayment)
        
        // Update order with COD specific information
        try await updateOrderForCOD(order, codPayment: codPayment)
        
        return CODPaymentResult(
            success: true,
            codPayment: codPayment,
            message: "COD order processed successfully"
        )
    }
    
    /// Handle cash collection when courier delivers order
    public func collectCashOnDelivery(
        orderId: String,
        collectedAmount: Double,
        courierId: String,
        collectionProof: CODCollectionProof
    ) async throws -> CODCollectionResult {
        
        guard let codPayment = try await getCODPayment(orderId: orderId) else {
            throw CODError.paymentNotFound
        }
        
        // Validate collected amount
        try validateCollectedAmount(
            collected: collectedAmount,
            expected: codPayment.amount
        )
        
        // Process the collection
        let collection = CODCollection(
            codPaymentId: codPayment.id,
            orderId: orderId,
            courierId: courierId,
            collectedAmount: collectedAmount,
            expectedAmount: codPayment.amount,
            collectionProof: collectionProof,
            collectedAt: Date(),
            status: .collected
        )
        
        // Store collection record
        try await storeCODCollection(collection)
        
        // Update COD payment status
        try await updateCODPaymentStatus(codPayment.id, status: .collected)
        
        // Calculate courier payout (deduct COD amount from earnings)
        let courierPayout = try await calculateCourierPayout(
            orderId: orderId,
            courierId: courierId,
            codAmount: collectedAmount
        )
        
        // Process restaurant payment
        try await processRestaurantPayment(orderId: orderId, amount: codPayment.amount)
        
        return CODCollectionResult(
            success: true,
            collection: collection,
            courierPayout: courierPayout,
            message: "Cash collected successfully"
        )
    }
    
    /// Handle COD payment disputes or issues
    public func reportCODIssue(
        orderId: String,
        issueType: CODIssueType,
        description: String,
        reportedBy: String,
        evidence: [String] = []
    ) async throws -> CODIssueReport {
        
        let issueReport = CODIssueReport(
            orderId: orderId,
            issueType: issueType,
            description: description,
            reportedBy: reportedBy,
            evidence: evidence,
            status: .open,
            createdAt: Date()
        )
        
        // Store issue report
        try await storeCODIssueReport(issueReport)
        
        // Notify support team
        try await notifySupportTeam(issueReport)
        
        // If it's a payment dispute, freeze related payouts
        if issueType == .paymentDispute || issueType == .incorrectAmount {
            try await freezeRelatedPayouts(orderId: orderId)
        }
        
        return issueReport
    }
    
    /// Get COD payment details for an order
    public func getCODPaymentDetails(orderId: String) async throws -> CODPaymentDetails? {
        guard let codPayment = try await getCODPayment(orderId: orderId) else {
            return nil
        }
        
        let collections = try await getCODCollections(for: codPayment.id)
        let issues = try await getCODIssues(orderId: orderId)
        
        return CODPaymentDetails(
            payment: codPayment,
            collections: collections,
            issues: issues,
            currentStatus: determineCurrentStatus(codPayment, collections, issues)
        )
    }
    
    /// Calculate change required for customer
    public func calculateChange(orderTotal: Double, customerPayment: Double) -> Double {
        return max(0, customerPayment - orderTotal)
    }
    
    /// Validate if customer has exact change or close to it
    public func validateCustomerPayment(orderTotal: Double, customerPayment: Double) -> PaymentValidation {
        let change = calculateChange(orderTotal: orderTotal, customerPayment: customerPayment)
        
        if customerPayment < orderTotal {
            let needText = String(format: "%.2f", orderTotal - customerPayment)
            return PaymentValidation(
                isValid: false,
                message: "Insufficient payment. Need MAD \(needText) more."
            )
        }
        
        if change > 50.0 { // Maximum reasonable change
            return PaymentValidation(
                isValid: false,
                message: "Payment too large. Please provide closer to exact amount."
            )
        }
        
        if change > 0 {
            let changeText = String(format: "%.2f", change)
            return PaymentValidation(
                isValid: true,
                message: "Change required: MAD \(changeText)"
            )
        }
        
        return PaymentValidation(
            isValid: true,
            message: "Exact payment - no change required"
        )
    }
    
    // MARK: - Private Methods
    
    private func validateCODEligibility(_ order: Order) throws {
        // Check order minimum for COD
        let codMinimum = 30.0 // MAD 30 minimum for COD
        if order.total < codMinimum {
            throw CODError.belowMinimum(required: codMinimum)
        }
        
        // Check maximum COD amount
        let codMaximum = 500.0 // MAD 500 maximum for COD
        if order.total > codMaximum {
            throw CODError.aboveMaximum(maximum: codMaximum)
        }
        
        // Check delivery address eligibility
        if !isCODEligibleArea(order.addresses.dropoff) {
            throw CODError.ineligibleArea
        }
    }
    
    private func isCODEligibleArea(_ address: Order.OrderAddresses.DeliveryAddress) -> Bool {
        // COD available in major Moroccan cities
        let codEligibleCities = [
            "Casablanca", "Rabat", "Marrakech", "Fes", "Tangier",
            "Agadir", "Meknes", "Oujda", "Kenitra", "Tetouan"
        ]
        
        return codEligibleCities.contains { city in
            address.city.lowercased().contains(city.lowercased())
        }
    }
    
    private func generateCustomerInstructions(for order: Order) -> String {
        let total = order.total
        let suggested = suggestOptimalPayment(for: total)
        let totalText = String(format: "%.2f", total)
        let suggestedText = String(format: "%.0f", suggested)
        
        return """
        Cash on Delivery - MAD \(totalText)
        
        Please have exact change or close to it ready.
        Suggested: MAD \(suggestedText)
        
        The courier will collect payment upon delivery.
        Large bills may require change - please prepare accordingly.
        """
    }
    
    private func generateCourierInstructions(for order: Order) -> String {
        let total = order.total
        let totalText = String(format: "%.2f", total)
        
        return """
        COD Collection Required - MAD \(totalText)
        
        1. Confirm order contents before collecting payment
        2. Accept exact amount or provide change if needed
        3. Take photo of payment collection as proof
        4. Mark payment as collected in the app
        
        Maximum change you should provide: MAD 50
        If customer cannot pay exact amount, contact support.
        """
    }
    
    private func suggestOptimalPayment(for total: Double) -> Double {
        // Suggest payment that minimizes change
        let commonDenominations = [20.0, 50.0, 100.0, 200.0]
        
        for denomination in commonDenominations {
            if total <= denomination && (denomination - total) <= 20.0 {
                return denomination
            }
        }
        
        // Round up to nearest 10 for larger amounts
        return ceil(total / 10.0) * 10.0
    }
    
    private func storeCODPayment(_ payment: CODPayment) async throws {
        // In real implementation, store in Firestore
        // For now, simulate storage
    }
    
    private func updateOrderForCOD(_ order: Order, codPayment: CODPayment) async throws {
        // Update order with COD-specific information
        // Add special instructions for courier and customer
    }
    
    private func getCODPayment(orderId: String) async throws -> CODPayment? {
        // In real implementation, fetch from Firestore
        // For now, return mock data
        return nil
    }
    
    private func validateCollectedAmount(collected: Double, expected: Double) throws {
        if abs(collected - expected) > 0.01 { // Allow for small rounding differences
            throw CODError.amountMismatch(expected: expected, collected: collected)
        }
    }
    
    private func storeCODCollection(_ collection: CODCollection) async throws {
        // Store collection record in database
    }
    
    private func updateCODPaymentStatus(_ paymentId: String, status: CODPaymentStatus) async throws {
        // Update payment status in database
    }
    
    private func calculateCourierPayout(orderId: String, courierId: String, codAmount: Double) async throws -> CourierPayout {
        // Calculate courier earnings and deduct COD amount they need to remit
        return CourierPayout(
            courierId: courierId,
            orderId: orderId,
            deliveryFee: 15.0, // Example delivery fee
            codDeduction: codAmount,
            netPayout: 15.0 - codAmount, // Will be negative, meaning courier owes money
            payoutDate: Date()
        )
    }
    
    private func processRestaurantPayment(orderId: String, amount: Double) async throws {
        // Process payment to restaurant (minus platform commission)
    }
    
    private func storeCODIssueReport(_ report: CODIssueReport) async throws {
        // Store issue report in database
    }
    
    private func notifySupportTeam(_ report: CODIssueReport) async throws {
        // Send notification to support team
    }
    
    private func freezeRelatedPayouts(orderId: String) async throws {
        // Freeze courier and restaurant payouts until issue is resolved
    }
    
    private func getCODCollections(for paymentId: String) async throws -> [CODCollection] {
        // Fetch collection records from database
        return []
    }
    
    private func getCODIssues(orderId: String) async throws -> [CODIssueReport] {
        // Fetch issue reports from database
        return []
    }
    
    private func determineCurrentStatus(
        _ payment: CODPayment,
        _ collections: [CODCollection],
        _ issues: [CODIssueReport]
    ) -> CODCurrentStatus {
        
        if !issues.filter({ $0.status == .open }).isEmpty {
            return .disputed
        }
        
        if !collections.isEmpty {
            return .collected
        }
        
        return .pending
    }
}

// MARK: - Supporting Services

private class CashValidationService {
    func validateCashAmount(_ amount: Double) -> Bool {
        return amount > 0 && amount.truncatingRemainder(dividingBy: 0.01) == 0
    }
}

private class CourierPayoutService {
    func calculatePayout(for order: Order, codAmount: Double) -> Double {
        // Calculate courier payout considering COD collection
        return 0.0
    }
}

private class OrderStatusTracker {
    func updateOrderStatus(_ orderId: String, status: Order.OrderStatus) async throws {
        // Update order status in database
    }
}

// MARK: - Data Models

public struct CODPayment: Codable, Identifiable {
    public let id: String
    public let orderId: String
    public let amount: Double
    public let currency: String
    public let status: CODPaymentStatus
    public let customerInstructions: String
    public let courierInstructions: String
    public let expectedDeliveryTime: Date?
    public let createdAt: Date
    
    public init(
        orderId: String,
        amount: Double,
        currency: String,
        status: CODPaymentStatus,
        customerInstructions: String,
        courierInstructions: String,
        expectedDeliveryTime: Date?,
        createdAt: Date
    ) {
        self.id = UUID().uuidString
        self.orderId = orderId
        self.amount = amount
        self.currency = currency
        self.status = status
        self.customerInstructions = customerInstructions
        self.courierInstructions = courierInstructions
        self.expectedDeliveryTime = expectedDeliveryTime
        self.createdAt = createdAt
    }
}

public enum CODPaymentStatus: String, Codable {
    case pending = "pending"
    case collected = "collected"
    case disputed = "disputed"
    case refunded = "refunded"
    case cancelled = "cancelled"
}

public struct CODCollection: Codable, Identifiable {
    public let id: String
    public let codPaymentId: String
    public let orderId: String
    public let courierId: String
    public let collectedAmount: Double
    public let expectedAmount: Double
    public let collectionProof: CODCollectionProof
    public let collectedAt: Date
    public let status: CODCollectionStatus
    
    public init(
        codPaymentId: String,
        orderId: String,
        courierId: String,
        collectedAmount: Double,
        expectedAmount: Double,
        collectionProof: CODCollectionProof,
        collectedAt: Date,
        status: CODCollectionStatus
    ) {
        self.id = UUID().uuidString
        self.codPaymentId = codPaymentId
        self.orderId = orderId
        self.courierId = courierId
        self.collectedAmount = collectedAmount
        self.expectedAmount = expectedAmount
        self.collectionProof = collectionProof
        self.collectedAt = collectedAt
        self.status = status
    }
}

public enum CODCollectionStatus: String, Codable {
    case collected = "collected"
    case disputed = "disputed"
    case verified = "verified"
}

public struct CODCollectionProof: Codable {
    public let photoUrl: String?
    public let timestamp: Date
    public let location: Coordinates?
    public let customerSignature: String? // Base64 encoded signature
    
    public init(photoUrl: String?, timestamp: Date, location: Coordinates?, customerSignature: String?) {
        self.photoUrl = photoUrl
        self.timestamp = timestamp
        self.location = location
        self.customerSignature = customerSignature
    }
}

public struct CODIssueReport: Codable, Identifiable {
    public let id: String
    public let orderId: String
    public let issueType: CODIssueType
    public let description: String
    public let reportedBy: String
    public let evidence: [String] // URLs to evidence files
    public let status: CODIssueStatus
    public let createdAt: Date
    
    public init(
        orderId: String,
        issueType: CODIssueType,
        description: String,
        reportedBy: String,
        evidence: [String],
        status: CODIssueStatus,
        createdAt: Date
    ) {
        self.id = UUID().uuidString
        self.orderId = orderId
        self.issueType = issueType
        self.description = description
        self.reportedBy = reportedBy
        self.evidence = evidence
        self.status = status
        self.createdAt = createdAt
    }
}

public enum CODIssueType: String, Codable, CaseIterable {
    case paymentDispute = "payment_dispute"
    case incorrectAmount = "incorrect_amount"
    case customerRefusal = "customer_refusal"
    case courierIssue = "courier_issue"
    case counterfeitMoney = "counterfeit_money"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .paymentDispute: return "Payment Dispute"
        case .incorrectAmount: return "Incorrect Amount"
        case .customerRefusal: return "Customer Refusal to Pay"
        case .courierIssue: return "Courier Issue"
        case .counterfeitMoney: return "Counterfeit Money"
        case .other: return "Other Issue"
        }
    }
}

public enum CODIssueStatus: String, Codable {
    case open = "open"
    case investigating = "investigating"
    case resolved = "resolved"
    case escalated = "escalated"
}

public struct CODPaymentResult: Codable {
    public let success: Bool
    public let codPayment: CODPayment?
    public let message: String
    
    public init(success: Bool, codPayment: CODPayment?, message: String) {
        self.success = success
        self.codPayment = codPayment
        self.message = message
    }
}

public struct CODCollectionResult: Codable {
    public let success: Bool
    public let collection: CODCollection?
    public let courierPayout: CourierPayout?
    public let message: String
    
    public init(success: Bool, collection: CODCollection?, courierPayout: CourierPayout?, message: String) {
        self.success = success
        self.collection = collection
        self.courierPayout = courierPayout
        self.message = message
    }
}

public struct CODPaymentDetails: Codable {
    public let payment: CODPayment
    public let collections: [CODCollection]
    public let issues: [CODIssueReport]
    public let currentStatus: CODCurrentStatus
    
    public init(payment: CODPayment, collections: [CODCollection], issues: [CODIssueReport], currentStatus: CODCurrentStatus) {
        self.payment = payment
        self.collections = collections
        self.issues = issues
        self.currentStatus = currentStatus
    }
}

public enum CODCurrentStatus: String, Codable {
    case pending = "pending"
    case collected = "collected"
    case disputed = "disputed"
    case resolved = "resolved"
}

public struct PaymentValidation: Codable {
    public let isValid: Bool
    public let message: String
    
    public init(isValid: Bool, message: String) {
        self.isValid = isValid
        self.message = message
    }
}

public struct CourierPayout: Codable {
    public let courierId: String
    public let orderId: String
    public let deliveryFee: Double
    public let codDeduction: Double
    public let netPayout: Double
    public let payoutDate: Date
    
    public init(courierId: String, orderId: String, deliveryFee: Double, codDeduction: Double, netPayout: Double, payoutDate: Date) {
        self.courierId = courierId
        self.orderId = orderId
        self.deliveryFee = deliveryFee
        self.codDeduction = codDeduction
        self.netPayout = netPayout
        self.payoutDate = payoutDate
    }
}

// MARK: - Errors

public enum CODError: LocalizedError {
    case belowMinimum(required: Double)
    case aboveMaximum(maximum: Double)
    case ineligibleArea
    case paymentNotFound
    case amountMismatch(expected: Double, collected: Double)
    case customerRefusal
    case invalidCurrency
    case systemError(String)
    
    public var errorDescription: String? {
        switch self {
        case .belowMinimum(let required):
            let t = String(format: "%.2f", required)
            return "Order must be at least MAD \(t) for cash on delivery"
        case .aboveMaximum(let maximum):
            let t = String(format: "%.2f", maximum)
            return "Cash on delivery not available for orders above MAD \(t)"
        case .ineligibleArea:
            return "Cash on delivery is not available in this area"
        case .paymentNotFound:
            return "COD payment record not found"
        case .amountMismatch(let expected, let collected):
            let e = String(format: "%.2f", expected)
            let c = String(format: "%.2f", collected)
            return "Amount mismatch: expected MAD \(e), collected MAD \(c)"
        case .customerRefusal:
            return "Customer refused to pay the required amount"
        case .invalidCurrency:
            return "Invalid currency for cash on delivery"
        case .systemError(let message):
            return "System error: \(message)"
        }
    }
}