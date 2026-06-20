import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Backend DTOs (matching exact Firestore structure)

struct BidDTO: Codable {
    @DocumentID var id: String?
    var rfqId: String
    var proId: String
    var customerId: String
    var proposal: ProposalDTO?
    var priceMAD: Double
    var milestones: [MilestoneDTO]?
    var timeline: TimelineDTO?
    var status: String
    var negotiationRound: Int?
    var maxNegotiationRounds: Int?
    var autoAcceptAbove: Double?
    var counterOffers: [CounterOfferDTO]?
    var lastCounterOffer: CounterOfferDTO?
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    var expiresAt: Date?
    
    struct ProposalDTO: Codable {
        var description: String?
        var includesMaterials: Bool?
        var visitRequired: Bool?
    }
    
    struct TimelineDTO: Codable {
        var estimatedDays: Int?
        var startDate: Date?
        var details: String?
    }
    
    struct CounterOfferDTO: Codable {
        var priceMAD: Double
        var milestones: [MilestoneDTO]?
        var message: String?
        @ServerTimestamp var timestamp: Date?
        var round: Int?
        var from: String?
        var timelineDays: Int?
    }
    
    struct MilestoneDTO: Codable {
        var id: String?
        var description: String?
        var amountMAD: Double?
        var dueDate: Date?
        var status: String?
    }
}

struct ContractDTO: Codable {
    @DocumentID var id: String?
    var rfqId: String
    var bidId: String?
    var customerId: String
    var proId: String
    var agreedScope: ScopeDTO
    var priceMAD: Double
    var milestones: [Contract.Milestone]?
    var status: String // 'pending_payment', 'active', 'completed', 'cancelled'
    var depositAmount: Double?
    var depositPercent: Double?
    var paymentMethod: String?
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    var startAt: Date?
    var completedAt: Date?
    
    struct ScopeDTO: Codable {
        var title: String
        var description: String
        var urgency: String?
        var serviceDate: Date?
        var timeWindow: String?
        var requirements: [String]?
        var photos: [String]?
    }
}

struct EscrowDTO: Codable {
    @DocumentID var id: String?
    var contractId: String
    var customerId: String?
    var proId: String?
    var totalAmount: Double?
    var depositAmount: Double?
    var remainingAmount: Double?
    var currency: String?
    var paymentMethod: PaymentMethodDTO?
    var status: String
    var milestonePayments: [MilestonePaymentDTO]?
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    var paymentIntentId: String?
    var transactionId: String?
    var clientSecret: String?
    var redirectUrl: String?
    
    struct PaymentMethodDTO: Codable {
        var type: String
        var provider: String?
        var last4: String?
    }
    
    struct MilestonePaymentDTO: Codable {
        var milestoneId: String
        var amount: Double
        var releasedAt: Date?
        var transactionId: String?
    }
}

struct ReviewDTO: Codable {
    @DocumentID var id: String?
    var contractId: String
    var rfqId: String?
    var reviewerId: String
    var revieweeId: String
    var reviewerRole: String?
    var revieweeRole: String?
    var rating: Int
    var text: String?
    var categoryId: String?
    @ServerTimestamp var createdAt: Date?
}

struct MessageDTO: Codable {
    @DocumentID var id: String?
    var conversationId: String
    var conversationType: String
    var senderId: String
    var text: String
    var originalText: String?
    var attachments: [String]?
    var type: String
    var piiRedacted: Bool?
    @ServerTimestamp var createdAt: Date?
    var readBy: [String]?
}

struct DisputeDTO: Codable {
    @DocumentID var id: String?
    var contractId: String
    var rfqId: String?
    var customerId: String?
    var proId: String?
    var reporterId: String
    var reporterRole: String?
    var respondentId: String?
    var respondentRole: String?
    var reason: String
    var description: String?
    var evidence: [String]?
    var requestedResolution: String?
    var status: String
    var priority: String?
    var escalationLevel: Int?
    var assignedTo: String?
    var internalNotes: [String]?
    var timeline: [TimelineEventDTO]?
    var responses: [ResponseDTO]?
    var resolution: String?
    var resolutionType: String?
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    var dueDate: Date?
    
    struct TimelineEventDTO: Codable {
        var action: String
        @ServerTimestamp var timestamp: Date?
        var userId: String?
        var role: String?
        var details: String?
    }
    
    struct ResponseDTO: Codable {
        var userId: String
        var role: String
        var text: String
        @ServerTimestamp var timestamp: Date?
    }
}

struct RFQDTO: Codable {
    @DocumentID var id: String?
    var customerId: String
    var categoryId: String
    var scope: ScopeDTO
    var location: LocationDTO
    var budgetRange: BudgetDTO?
    var siteVisitRequested: Bool
    var status: String
    var bidCount: Int?
    var viewCount: Int?
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    var expiresAt: Date?
    var awardedBidId: String?
    
    struct ScopeDTO: Codable {
        var title: String
        var description: String
        var urgency: String?
        var serviceDate: Date?
        var timeWindow: String?
        var requirements: [String]?
        var photos: [String]?
        var attributes: [String: JSONValue]?
    }
    
    struct LocationDTO: Codable {
        var address: String?
        var coordinates: GeoPoint?
        var city: String
        var region: String?
    }
    
    struct BudgetDTO: Codable {
        var minMAD: Double
        var maxMAD: Double
        var currency: String?
    }
}

// MARK: - Mapping Extensions

extension Bid {
    init(from dto: BidDTO) {
        self.init(
            id: dto.id,
            rfqId: dto.rfqId,
            proId: dto.proId,
            proName: nil, // Will be fetched separately if needed
            amountMAD: dto.priceMAD,
            timelineDays: dto.timeline?.estimatedDays ?? 0,
            includesMaterials: dto.proposal?.includesMaterials ?? false,
            visitRequired: dto.proposal?.visitRequired ?? false,
            message: dto.proposal?.description,
            status: Bid.BidStatus(rawValue: dto.status) ?? .active,
            counters: Bid.CounterInfo(
                customerCount: dto.counterOffers?.filter { $0.from == "customer" }.count ?? 0,
                proCount: dto.counterOffers?.filter { $0.from == "professional" }.count ?? 0
            ),
            autoAcceptAbove: dto.autoAcceptAbove,
            createdAt: dto.createdAt,
            expiresAt: dto.expiresAt
        )
    }
    
    func toDTO() -> BidDTO {
        BidDTO(
            id: id,
            rfqId: rfqId,
            proId: proId,
            customerId: "", // Will be set by backend
            proposal: BidDTO.ProposalDTO(
                description: message,
                includesMaterials: includesMaterials,
                visitRequired: visitRequired
            ),
            priceMAD: amountMAD,
            milestones: nil,
            timeline: timelineDays > 0 ? BidDTO.TimelineDTO(
                estimatedDays: timelineDays,
                startDate: nil,
                details: nil
            ) : nil,
            status: status.rawValue,
            negotiationRound: 0,
            maxNegotiationRounds: 3,
            autoAcceptAbove: autoAcceptAbove,
            counterOffers: nil,
            lastCounterOffer: nil,
            createdAt: createdAt,
            updatedAt: nil,
            expiresAt: expiresAt
        )
    }
}

extension Contract {
    init(from dto: ContractDTO) {
        self.init(
            id: dto.id,
            rfqId: dto.rfqId,
            customerId: dto.customerId,
            proId: dto.proId,
            agreedScope: RFQ.RFQScope(
                title: dto.agreedScope.title,
                description: dto.agreedScope.description,
                attributes: nil,
                urgency: RFQ.RFQScope.Urgency(rawValue: dto.agreedScope.urgency ?? "flexible") ?? .flexible
            ),
            priceMAD: dto.priceMAD,
            milestones: dto.milestones ?? [],
            startAt: dto.startAt,
            cancellationPolicy: nil,
            status: Contract.ContractStatus(rawValue: dto.status.replacingOccurrences(of: "_payment", with: "")) ?? .pending,
            createdAt: dto.createdAt
        )
    }
}

extension Escrow {
    init(from dto: EscrowDTO) {
        var amounts: [EscrowAmount] = []
        if let milestonePayments = dto.milestonePayments {
            amounts = milestonePayments.map { payment in
                EscrowAmount(
                    milestoneId: payment.milestoneId,
                    amount: payment.amount,
                    status: payment.releasedAt != nil ? .released : .held
                )
            }
        }
        
        self.init(
            id: dto.id,
            contractId: dto.contractId,
            amounts: amounts,
            paymentMethod: PaymentMethod(rawValue: dto.paymentMethod?.type ?? "card") ?? .card,
            holdbacks: nil,
            pspRefs: nil
        )
    }
}

extension Review {
    init(from dto: ReviewDTO) {
        self.init(
            id: dto.id,
            contractId: dto.contractId,
            fromUserId: dto.reviewerId,
            toUserId: dto.revieweeId,
            rating: dto.rating,
            text: dto.text,
            categoryId: dto.categoryId ?? "",
            createdAt: dto.createdAt
        )
    }
    
    func toDTO(categoryId: String) -> ReviewDTO {
        ReviewDTO(
            id: id,
            contractId: contractId,
            rfqId: nil,
            reviewerId: fromUserId,
            revieweeId: toUserId,
            reviewerRole: nil,
            revieweeRole: nil,
            rating: rating,
            text: text,
            categoryId: categoryId,
            createdAt: createdAt
        )
    }
}

extension Message {
    init(from dto: MessageDTO) {
        self.init(
            id: dto.id,
            threadId: dto.conversationId,
            fromUserId: dto.senderId,
            text: dto.text,
            attachments: dto.attachments ?? [],
            type: MessageType(rawValue: dto.type) ?? .chat,
            piiRedactionState: dto.piiRedacted == true ? "redacted" : nil,
            createdAt: dto.createdAt
        )
    }
    
    func toDTO(conversationType: String) -> MessageDTO {
        MessageDTO(
            id: id,
            conversationId: threadId,
            conversationType: conversationType,
            senderId: fromUserId,
            text: text,
            originalText: nil,
            attachments: attachments.isEmpty ? nil : attachments,
            type: type.rawValue,
            piiRedacted: piiRedactionState == "redacted",
            createdAt: createdAt,
            readBy: nil
        )
    }
}

extension Dispute {
    init(from dto: DisputeDTO) {
        self.init(
            id: dto.id,
            contractId: dto.contractId,
            side: dto.reporterRole == "customer" ? .customer : .pro,
            reason: dto.reason,
            evidence: dto.evidence ?? [],
            status: DisputeStatus(rawValue: dto.status) ?? .open,
            resolution: dto.resolution,
            createdAt: dto.createdAt
        )
    }
}

extension RFQ {
    init(from dto: RFQDTO) {
        // Convert coordinates
        var location = RFQ.Location(
            lat: dto.location.coordinates?.latitude ?? 0,
            lng: dto.location.coordinates?.longitude ?? 0,
            city: dto.location.city,
            arrondissement: dto.location.region,
            address: dto.location.address
        )
        
        // Convert budget
        var budgetRange: RFQ.BudgetRange? = nil
        if let budget = dto.budgetRange {
            budgetRange = RFQ.BudgetRange(
                min: budget.minMAD,
                max: budget.maxMAD,
                currency: budget.currency ?? "MAD"
            )
        }
        
        self.init(
            id: dto.id,
            customerId: dto.customerId,
            categoryId: dto.categoryId,
            scope: RFQ.RFQScope(
                title: dto.scope.title,
                description: dto.scope.description,
                attributes: dto.scope.attributes,
                urgency: RFQ.RFQScope.Urgency(rawValue: dto.scope.urgency ?? "flexible") ?? .flexible
            ),
            location: location,
            media: dto.scope.photos ?? [],
            budgetRange: budgetRange,
            siteVisitRequested: dto.siteVisitRequested,
            status: RFQ.RFQStatus(rawValue: dto.status) ?? .open,
            createdAt: dto.createdAt,
            expiresAt: dto.expiresAt
        )
    }
    
    func toDTO() -> RFQDTO {
        RFQDTO(
            id: id,
            customerId: customerId,
            categoryId: categoryId,
            scope: RFQDTO.ScopeDTO(
                title: scope.title,
                description: scope.description,
                urgency: scope.urgency.rawValue,
                serviceDate: nil,
                timeWindow: nil,
                requirements: nil,
                photos: media.isEmpty ? nil : media,
                attributes: scope.attributes
            ),
            location: RFQDTO.LocationDTO(
                address: location.address,
                coordinates: location.lat != 0 ? GeoPoint(latitude: location.lat, longitude: location.lng) : nil,
                city: location.city,
                region: location.arrondissement
            ),
            budgetRange: budgetRange.map { budget in
                RFQDTO.BudgetDTO(
                    minMAD: budget.min,
                    maxMAD: budget.max,
                    currency: budget.currency
                )
            },
            siteVisitRequested: siteVisitRequested,
            status: status.rawValue,
            bidCount: 0,
            viewCount: 0,
            createdAt: createdAt,
            updatedAt: nil,
            expiresAt: expiresAt,
            awardedBidId: nil
        )
    }
}