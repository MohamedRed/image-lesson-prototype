import Foundation
import Combine

/// Mock implementation of HomeServicesServicing for testing and development
public class MockHomeServicesService: HomeServicesServicing {
    
    // MARK: - Published Data
    private let rfqSubject = PassthroughSubject<RFQ, Never>()
    private let bidSubject = PassthroughSubject<Bid, Never>()
    private let messageSubject = PassthroughSubject<Message, Never>()
    private let contractSubject = PassthroughSubject<Contract, Never>()
    
    public var rfqUpdates: AnyPublisher<RFQ, Never> { rfqSubject.eraseToAnyPublisher() }
    public var bidUpdates: AnyPublisher<Bid, Never> { bidSubject.eraseToAnyPublisher() }
    public var messageUpdates: AnyPublisher<Message, Never> { messageSubject.eraseToAnyPublisher() }
    public var contractUpdates: AnyPublisher<Contract, Never> { contractSubject.eraseToAnyPublisher() }
    
    // MARK: - Mock Data Storage
    private var categories: [ServiceCategory] = []
    private var rfqs: [RFQ] = []
    private var bids: [Bid] = []
    private var contracts: [Contract] = []
    private var reviews: [Review] = []
    private var messages: [Message] = []
    private var proProfiles: [ProProfile] = []
    private var escrows: [Escrow] = []
    private var disputes: [Dispute] = []
    
    public init() {
        setupMockData()
    }
    
    private func setupMockData() {
        // Mock Categories
        categories = [
            ServiceCategory(
                id: "plumbing",
                name: "Plumbing",
                nameAr: "السباكة",
                nameFr: "Plomberie",
                icon: "wrench.fill",
                isActive: true,
                displayOrder: 1
            ),
            ServiceCategory(
                id: "electrical",
                name: "Electrical",
                nameAr: "الكهرباء",
                nameFr: "Électricité",
                icon: "bolt.fill",
                isActive: true,
                displayOrder: 2
            ),
            ServiceCategory(
                id: "cleaning",
                name: "House Cleaning",
                nameAr: "تنظيف المنزل",
                nameFr: "Ménage",
                icon: "sparkles",
                isActive: true,
                displayOrder: 3
            ),
            ServiceCategory(
                id: "gardening",
                name: "Gardening",
                nameAr: "البستنة",
                nameFr: "Jardinage",
                icon: "leaf.fill",
                isActive: true,
                displayOrder: 4
            ),
            ServiceCategory(
                id: "painting",
                name: "Painting",
                nameAr: "الطلاء",
                nameFr: "Peinture",
                icon: "paintbrush.fill",
                isActive: true,
                displayOrder: 5
            ),
            ServiceCategory(
                id: "carpentry",
                name: "Carpentry",
                nameAr: "النجارة",
                nameFr: "Menuiserie",
                icon: "hammer.fill",
                isActive: true,
                displayOrder: 6
            )
        ]
        
        // Mock RFQs
        rfqs = [
            RFQ(
                id: "rfq1",
                customerId: "customer1",
                categoryId: "plumbing",
                scope: RFQ.RFQScope(
                    title: "Kitchen Sink Repair",
                    description: "My kitchen sink is leaking and needs urgent repair. The faucet is also loose."
                ),
                location: RFQ.Location(
                    lat: 33.5731,
                    lng: -7.5898,
                    city: "Casablanca",
                    address: "123 Avenue Mohammed V"
                ),
                media: [],
                budgetRange: RFQ.BudgetRange(min: 200, max: 500),
                siteVisitRequested: true,
                status: .open,
                createdAt: Date().addingTimeInterval(-86400), // 1 day ago
                expiresAt: Date().addingTimeInterval(604800) // 7 days from now
            ),
            RFQ(
                id: "rfq2",
                customerId: "customer1",
                categoryId: "cleaning",
                scope: RFQ.RFQScope(
                    title: "Deep House Cleaning",
                    description: "Need thorough cleaning for a 3-bedroom apartment. Including windows and balcony."
                ),
                location: RFQ.Location(
                    lat: 34.0209,
                    lng: -6.8416,
                    city: "Rabat",
                    address: "456 Rue de la Paix"
                ),
                media: [],
                budgetRange: RFQ.BudgetRange(min: 300, max: 600),
                siteVisitRequested: false,
                status: .open,
                createdAt: Date().addingTimeInterval(-172800), // 2 days ago
                expiresAt: Date().addingTimeInterval(518400) // 6 days from now
            )
        ]
        
        // Mock Professional Profiles
        proProfiles = [
            ProProfile(
                id: "pro1",
                userId: "user-pro1",
                name: "Ahmed's Plumbing Services",
                skills: ["plumbing", "electrical"],
                serviceArea: ProProfile.ServiceArea(city: "Casablanca", address: "Ain Sebaa"),
                verificationTier: .professional,
                rating: 4.8,
                jobsCount: 89,
                badges: ["TopRated", "Verified"],
                availability: ProProfile.Availability(daysOfWeek: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]),
                languages: ["Arabic", "French"],
                phoneNumber: "+212 6XX XXX XXX",
                experienceYears: 8,
                emergencyAvailable: true,
                reviewsCount: 127,
                isVerified: true,
                tier: .gold,
                portfolio: [],
                businessName: "Ahmed's Plumbing Services",
                createdAt: Date().addingTimeInterval(-2592000) // 30 days ago
            )
        ]
        
        // Mock Bids
        bids = [
            Bid(
                id: "bid1",
                rfqId: "rfq1",
                proId: "pro1",
                amountMAD: 350,
                timelineDays: 1,
                includesMaterials: true,
                visitRequired: false,
                message: "Hello! I'm Ahmed, a licensed plumber with 8 years experience. I can fix your kitchen sink leak and tighten the faucet.",
                status: .active,
                counters: Bid.CounterInfo(customerCount: 0, proCount: 0),
                autoAcceptAbove: nil,
                createdAt: Date().addingTimeInterval(-43200), // 12 hours ago
                expiresAt: Date().addingTimeInterval(259200) // 3 days
            )
        ]
        
        // Mock Contracts
        contracts = [
            Contract(
                id: "contract1",
                rfqId: "rfq1",
                customerId: "customer1",
                proId: "pro1",
                agreedScope: RFQ.RFQScope(
                    title: "Kitchen Sink Repair - Confirmed",
                    description: "Fix kitchen sink leak, tighten faucet, and inspect all connections."
                ),
                priceMAD: 350,
                milestones: [
                    Contract.Milestone(
                        id: "m1",
                        description: "Diagnosis and Parts",
                        amountMAD: 100,
                        status: .completed
                    ),
                    Contract.Milestone(
                        id: "m2",
                        description: "Repair Work",
                        amountMAD: 250,
                        status: .pending
                    )
                ],
                startAt: Date().addingTimeInterval(-7200), // 2 hours ago
                status: .active,
                createdAt: Date().addingTimeInterval(-10800) // 3 hours ago
            )
        ]
    }
    
    // MARK: - Categories
    public func listCategories() async throws -> [ServiceCategory] {
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
        return categories.filter { $0.isActive }.sorted { $0.displayOrder < $1.displayOrder }
    }
    
    public func getCategory(id: String) async throws -> ServiceCategory? {
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 second delay
        return categories.first { $0.id == id }
    }
    
    // MARK: - RFQs
    public func createRFQ(_ rfq: RFQDraft) async throws -> RFQ {
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 second delay
        
        let newRFQ = RFQ(
            id: "rfq_\(UUID().uuidString.prefix(8))",
            customerId: "current-user-id",
            categoryId: rfq.categoryId,
            scope: rfq.scope,
            location: rfq.location,
            media: rfq.media,
            budgetRange: rfq.budgetRange,
            siteVisitRequested: rfq.siteVisitRequested,
            status: .open,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(604800) // 7 days
        )
        
        rfqs.append(newRFQ)
        rfqSubject.send(newRFQ)
        return newRFQ
    }
    
    public func updateRFQ(id: String, rfq: RFQDraft) async throws -> RFQ {
        guard let index = rfqs.firstIndex(where: { $0.id == id }) else {
            throw HomeServicesError.rfqNotFound
        }
        
        var updatedRFQ = rfqs[index]
        updatedRFQ.scope = rfq.scope
        updatedRFQ.location = rfq.location
        updatedRFQ.budgetRange = rfq.budgetRange
        
        rfqs[index] = updatedRFQ
        rfqSubject.send(updatedRFQ)
        return updatedRFQ
    }
    
    public func getRFQ(id: String) async throws -> RFQ? {
        return rfqs.first { $0.id == id }
    }
    
    public func listMyRFQs() async throws -> [RFQ] {
        return rfqs.filter { $0.customerId == "customer1" }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    public func listAvailableRFQs(proId: String) async throws -> [RFQ] {
        return rfqs.filter { $0.status == .open }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    public func cancelRFQ(id: String) async throws {
        if let index = rfqs.firstIndex(where: { $0.id == id }) {
            rfqs[index].status = .cancelled
            rfqSubject.send(rfqs[index])
        }
    }
    
    // MARK: - Bids
    public func submitBid(_ bid: NewBid) async throws -> Bid {
        let newBid = Bid(
            id: "bid_\(UUID().uuidString.prefix(8))",
            rfqId: bid.rfqId,
            proId: "current-pro-id",
            amountMAD: bid.amountMAD,
            timelineDays: bid.timelineDays,
            includesMaterials: bid.includesMaterials,
            visitRequired: bid.visitRequired,
            message: bid.message,
            status: .active,
            counters: Bid.CounterInfo(customerCount: 0, proCount: 0),
            autoAcceptAbove: bid.autoAcceptAbove,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(259200)
        )
        
        bids.append(newBid)
        bidSubject.send(newBid)
        return newBid
    }
    
    public func counterBid(_ counter: Counter) async throws -> Bid {
        guard let index = bids.firstIndex(where: { $0.id == counter.bidId }) else {
            throw HomeServicesError.bidNotFound
        }
        
        var updatedBid = bids[index]
        updatedBid.counters.customerCount += 1
        
        if let newAmount = counter.newAmountMAD {
            updatedBid.amountMAD = newAmount
        }
        if let newTimeline = counter.newTimelineDays {
            updatedBid.timelineDays = newTimeline
        }
        
        bids[index] = updatedBid
        bidSubject.send(updatedBid)
        return updatedBid
    }
    
    public func withdrawBid(id: String) async throws {
        if let index = bids.firstIndex(where: { $0.id == id }) {
            bids[index].status = .withdrawn
            bidSubject.send(bids[index])
        }
    }
    
    public func listBids(rfqId: String) async throws -> [Bid] {
        return bids.filter { $0.rfqId == rfqId && $0.status == .active }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    public func getBid(id: String) async throws -> Bid? {
        return bids.first { $0.id == id }
    }
    
    public func acceptBid(_ bidId: String, depositPercent: Int?) async throws -> Contract {
        guard let bid = bids.first(where: { $0.id == bidId }),
              let rfq = rfqs.first(where: { $0.id == bid.rfqId }) else {
            throw HomeServicesError.bidNotFound
        }
        
        let contract = Contract(
            id: "contract_\(UUID().uuidString.prefix(8))",
            rfqId: rfq.id!,
            customerId: rfq.customerId,
            proId: bid.proId,
            agreedScope: rfq.scope,
            priceMAD: bid.amountMAD,
            milestones: [
                Contract.Milestone(
                    id: "m1",
                    description: "Initial Payment",
                    amountMAD: bid.amountMAD * 0.3,
                    status: .pending
                ),
                Contract.Milestone(
                    id: "m2",
                    description: "Completion Payment",
                    amountMAD: bid.amountMAD * 0.7,
                    status: .pending
                )
            ],
            startAt: Date().addingTimeInterval(3600),
            status: .pending,
            createdAt: Date()
        )
        
        contracts.append(contract)
        contractSubject.send(contract)
        return contract
    }
    
    // MARK: - Contracts
    public func getContract(id: String) async throws -> Contract? {
        return contracts.first { $0.id == id }
    }
    
    public func listMyContracts(asPro: Bool) async throws -> [Contract] {
        let userId = asPro ? "pro1" : "customer1"
        let fieldToMatch = asPro ? \Contract.proId : \Contract.customerId
        
        return contracts.filter { $0[keyPath: fieldToMatch] == userId }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    public func completeContract(_ contractId: String) async throws {
        if let index = contracts.firstIndex(where: { $0.id == contractId }) {
            contracts[index].status = .completed
            contractSubject.send(contracts[index])
        }
    }
    
    public func cancelContract(_ contractId: String, reason: String) async throws {
        if let index = contracts.firstIndex(where: { $0.id == contractId }) {
            contracts[index].status = .cancelled
            contractSubject.send(contracts[index])
        }
    }
    
    // MARK: - Payments & Escrow
    public func createEscrow(_ req: EscrowRequest) async throws -> Escrow {
        let escrow = Escrow(
            id: "escrow_\(UUID().uuidString.prefix(8))",
            contractId: req.contractId,
            amounts: req.milestones?.map { milestone in
                Escrow.EscrowAmount(
                    milestoneId: milestone.id,
                    amount: milestone.amountMAD,
                    status: .pending
                )
            } ?? [],
            paymentMethod: req.method
        )
        
        escrows.append(escrow)
        return escrow
    }
    
    public func getEscrow(contractId: String) async throws -> Escrow? {
        return escrows.first { $0.contractId == contractId }
    }
    
    public func releaseMilestone(escrowId: String, milestoneId: String) async throws {
        if let escrowIndex = escrows.firstIndex(where: { $0.id == escrowId }),
           let amountIndex = escrows[escrowIndex].amounts.firstIndex(where: { $0.milestoneId == milestoneId }) {
            escrows[escrowIndex].amounts[amountIndex].status = .released
        }
    }
    
    // MARK: - Reviews
    public func createReview(_ review: NewReview) async throws -> Review {
        let newReview = Review(
            id: "review_\(UUID().uuidString.prefix(8))",
            contractId: review.contractId,
            fromUserId: "current-user-id",
            toUserId: "reviewed-pro-id",
            rating: review.rating,
            text: review.text,
            categoryId: "general",
            createdAt: Date()
        )
        
        reviews.append(newReview)
        return newReview
    }
    
    public func getReviews(userId: String) async throws -> [Review] {
        return reviews.filter { $0.toUserId == userId }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    // MARK: - Messaging
    public func sendMessage(threadId: String, text: String, attachments: [String]) async throws -> Message {
        let message = Message(
            id: "msg_\(UUID().uuidString.prefix(8))",
            threadId: threadId,
            fromUserId: "current-user-id",
            text: text,
            attachments: attachments,
            type: .chat,
            createdAt: Date()
        )
        
        messages.append(message)
        messageSubject.send(message)
        return message
    }
    
    public func getMessages(threadId: String) async throws -> [Message] {
        return messages.filter { $0.threadId == threadId }
            .sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
    }
    
    public func markMessageRead(threadId: String, messageId: String) async throws {
        // Mock implementation - would mark message as read
    }
    
    // MARK: - Pro Profile
    public func getProProfile(userId: String) async throws -> ProProfile? {
        return proProfiles.first { $0.userId == userId }
    }
    
    public func updateProProfile(_ profile: ProProfile) async throws -> ProProfile {
        if let index = proProfiles.firstIndex(where: { $0.userId == profile.userId }) {
            proProfiles[index] = profile
            return profile
        } else {
            proProfiles.append(profile)
            return profile
        }
    }
    
    public func searchPros(categoryId: String, city: String) async throws -> [ProProfile] {
        return proProfiles.filter { pro in
            pro.skills.contains(categoryId) && 
            pro.serviceArea.city.lowercased().contains(city.lowercased())
        }
        .sorted { $0.rating > $1.rating }
    }
    
    // MARK: - Disputes
    public func createDispute(contractId: String, reason: String, evidence: [String]) async throws -> Dispute {
        let dispute = Dispute(
            id: "dispute_\(UUID().uuidString.prefix(8))",
            contractId: contractId,
            side: .customer,
            reason: reason,
            evidence: evidence,
            status: .open,
            resolution: nil,
            createdAt: Date()
        )
        
        disputes.append(dispute)
        return dispute
    }
    
    public func getDispute(id: String) async throws -> Dispute? {
        return disputes.first { $0.id == id }
    }
    
    // MARK: - AI Features
    
    public func aiDescribeScope(photoUrls: [String], categoryId: String?, userNotes: String?) async throws -> AIScopeDescription {
        // Simulate AI processing delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return AIScopeDescription(
            title: "Paint 2-bedroom apartment",
            description: "Complete interior painting of a 2-bedroom apartment including walls, ceilings, and trim. Preparation work includes patching holes and sanding surfaces.",
            estimatedBudget: AIScopeDescription.BudgetEstimate(
                min: 3000,
                max: 5000,
                confidence: "medium"
            ),
            scope: AIScopeDescription.ScopeDetails(
                roomCount: 4,
                squareMeters: 85,
                urgency: "flexible",
                complexity: "moderate"
            ),
            suggestedSkills: ["Painting", "Interior Design", "Surface Preparation"],
            materials: AIScopeDescription.Materials(
                required: ["Paint", "Primer", "Brushes", "Rollers"],
                optional: ["Drop cloths", "Painter's tape"]
            ),
            estimatedDuration: AIScopeDescription.DurationEstimate(
                days: 3,
                confidence: "high"
            ),
            clarifyingQuestions: [
                "What colors do you prefer?",
                "Do you need furniture moved?",
                "Any specific paint brand preference?"
            ]
        )
    }
    
    public func aiEstimateJob(description: String, categoryId: String?, location: RFQ.Location?, urgency: String?, photoUrls: [String]?) async throws -> AIJobEstimate {
        // Simulate AI processing delay
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        return AIJobEstimate(
            priceRange: AIJobEstimate.PriceEstimate(
                min: 2500,
                max: 4500,
                confidence: "medium",
                breakdown: AIJobEstimate.PriceBreakdown(
                    labor: 2000,
                    materials: 1000,
                    margin: 500
                )
            ),
            duration: AIJobEstimate.DurationEstimate(
                minDays: 2,
                maxDays: 4,
                confidence: "high",
                phases: [
                    AIJobEstimate.Phase(name: "Preparation", days: 1),
                    AIJobEstimate.Phase(name: "Painting", days: 2),
                    AIJobEstimate.Phase(name: "Finishing", days: 1)
                ]
            ),
            factors: AIJobEstimate.Factors(
                increasing: ["High ceilings", "Multiple colors", "Premium paint"],
                decreasing: ["Empty apartment", "Good wall condition"],
                assumptions: ["Standard paint quality", "Normal working hours", "No major repairs needed"]
            ),
            recommendations: [
                "Schedule during weekdays for better availability",
                "Consider using washable paint for high-traffic areas",
                "Group multiple rooms for better pricing"
            ],
            alternativeOptions: [
                AIJobEstimate.AlternativeOption(
                    description: "Use budget paint brand",
                    priceImpact: "-20%",
                    qualityImpact: "Shorter lifespan, may need repainting sooner"
                ),
                AIJobEstimate.AlternativeOption(
                    description: "Paint walls only (skip ceilings)",
                    priceImpact: "-30%",
                    qualityImpact: "Less complete look but still refreshes the space"
                )
            ]
        )
    }
}