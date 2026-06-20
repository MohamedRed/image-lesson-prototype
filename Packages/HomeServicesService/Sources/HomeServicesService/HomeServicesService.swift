import Foundation
import Combine

/// Protocol defining the Home Services feature functionality
public protocol HomeServicesServicing {
    // Categories
    func listCategories() async throws -> [ServiceCategory]
    func getCategory(id: String) async throws -> ServiceCategory?
    
    // RFQs (Request for Quotes)
    func createRFQ(_ rfq: RFQDraft) async throws -> RFQ
    func updateRFQ(id: String, rfq: RFQDraft) async throws -> RFQ
    func getRFQ(id: String) async throws -> RFQ?
    func listMyRFQs() async throws -> [RFQ]
    func listAvailableRFQs(proId: String) async throws -> [RFQ]
    func cancelRFQ(id: String) async throws
    
    // Bids
    func submitBid(_ bid: NewBid) async throws -> Bid
    func counterBid(_ counter: Counter) async throws -> Bid
    func withdrawBid(id: String) async throws
    func listBids(rfqId: String) async throws -> [Bid]
    func getBid(id: String) async throws -> Bid?
    func acceptBid(_ bidId: String, depositPercent: Int?) async throws -> Contract
    
    // Contracts
    func getContract(id: String) async throws -> Contract?
    func listMyContracts(asPro: Bool) async throws -> [Contract]
    func completeContract(_ contractId: String) async throws
    func cancelContract(_ contractId: String, reason: String) async throws
    
    // Payments & Escrow
    func createEscrow(_ req: EscrowRequest) async throws -> Escrow
    func getEscrow(contractId: String) async throws -> Escrow?
    func releaseMilestone(escrowId: String, milestoneId: String) async throws
    
    // Reviews
    func createReview(_ review: NewReview) async throws -> Review
    func getReviews(userId: String) async throws -> [Review]
    
    // Messaging
    func sendMessage(threadId: String, text: String, attachments: [String]) async throws -> Message
    func getMessages(threadId: String) async throws -> [Message]
    func markMessageRead(threadId: String, messageId: String) async throws
    
    // Pro Profile
    func getProProfile(userId: String) async throws -> ProProfile?
    func updateProProfile(_ profile: ProProfile) async throws -> ProProfile
    func searchPros(categoryId: String, city: String) async throws -> [ProProfile]
    
    // Disputes
    func createDispute(contractId: String, reason: String, evidence: [String]) async throws -> Dispute
    func getDispute(id: String) async throws -> Dispute?
    
    // AI Features
    func aiDescribeScope(photoUrls: [String], categoryId: String?, userNotes: String?) async throws -> AIScopeDescription
    func aiEstimateJob(description: String, categoryId: String?, location: RFQ.Location?, urgency: String?, photoUrls: [String]?) async throws -> AIJobEstimate
    
    // Real-time subscriptions
    var rfqUpdates: AnyPublisher<RFQ, Never> { get }
    var bidUpdates: AnyPublisher<Bid, Never> { get }
    var messageUpdates: AnyPublisher<Message, Never> { get }
    var contractUpdates: AnyPublisher<Contract, Never> { get }
}

// MARK: - AI Response Models

public struct AIScopeDescription: Codable {
    public let title: String
    public let description: String
    public let estimatedBudget: BudgetEstimate
    public let scope: ScopeDetails
    public let suggestedSkills: [String]
    public let materials: Materials
    public let estimatedDuration: DurationEstimate
    public let clarifyingQuestions: [String]
    
    public struct BudgetEstimate: Codable {
        public let min: Double
        public let max: Double
        public let confidence: String
    }
    
    public struct ScopeDetails: Codable {
        public let roomCount: Int?
        public let squareMeters: Double?
        public let urgency: String
        public let complexity: String
    }
    
    public struct Materials: Codable {
        public let required: [String]
        public let optional: [String]
    }
    
    public struct DurationEstimate: Codable {
        public let days: Int
        public let confidence: String
    }
}

public struct AIJobEstimate: Codable {
    public let priceRange: PriceEstimate
    public let duration: DurationEstimate
    public let factors: Factors
    public let recommendations: [String]
    public let alternativeOptions: [AlternativeOption]
    
    public struct PriceEstimate: Codable {
        public let min: Double
        public let max: Double
        public let confidence: String
        public let breakdown: PriceBreakdown?
    }
    
    public struct PriceBreakdown: Codable {
        public let labor: Double
        public let materials: Double
        public let margin: Double
    }
    
    public struct DurationEstimate: Codable {
        public let minDays: Int
        public let maxDays: Int
        public let confidence: String
        public let phases: [Phase]
    }
    
    public struct Phase: Codable {
        public let name: String
        public let days: Int
    }
    
    public struct Factors: Codable {
        public let increasing: [String]
        public let decreasing: [String]
        public let assumptions: [String]
    }
    
    public struct AlternativeOption: Codable {
        public let description: String
        public let priceImpact: String
        public let qualityImpact: String
    }
}

/// Configuration for Home Services
public struct HomeServicesConfig {
    public var environment: Environment
    public var locale: Locale
    public var currency: String
    
    public enum Environment {
        case production
        case staging
        case local
    }
    
    public enum Locale: String {
        case enUS = "en-US"
        case frMA = "fr-MA"  // French (Morocco)
        case arMA = "ar-MA"  // Arabic/Darija (Morocco)
    }
    
    public init(environment: Environment = .local, 
                locale: Locale = .frMA, 
                currency: String = "MAD") {
        self.environment = environment
        self.locale = locale
        self.currency = currency
    }
    
    public static let moroccoDefault = HomeServicesConfig(
        environment: .production,
        locale: .frMA,
        currency: "MAD"
    )
    
    public static let localDev = HomeServicesConfig(
        environment: .local,
        locale: .enUS,
        currency: "MAD"
    )
}

/// Error types for Home Services
public enum HomeServicesError: LocalizedError {
    case invalidCategory
    case rfqNotFound
    case bidNotFound
    case contractNotFound
    case unauthorized
    case bidExpired
    case maxCountersReached
    case insufficientFunds
    case networkError(String)
    case serverError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCategory:
            return "Invalid service category"
        case .rfqNotFound:
            return "Request for quote not found"
        case .bidNotFound:
            return "Bid not found"
        case .contractNotFound:
            return "Contract not found"
        case .unauthorized:
            return "You are not authorized to perform this action"
        case .bidExpired:
            return "This bid has expired"
        case .maxCountersReached:
            return "Maximum number of counter offers reached (3 per side)"
        case .insufficientFunds:
            return "Insufficient funds for this transaction"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}