import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseFunctions
import FirebaseStorage

/// Firestore implementation of HomeServicesServicing
public final class FirestoreHomeServicesService: HomeServicesServicing {
    
    private let db: Firestore
    private let auth: Auth
    private let functions: Functions
    private let storage: Storage
    private let config: HomeServicesConfig
    
    // Publishers
    private let _rfqUpdates = PassthroughSubject<RFQ, Never>()
    private let _bidUpdates = PassthroughSubject<Bid, Never>()
    private let _messageUpdates = PassthroughSubject<Message, Never>()
    private let _contractUpdates = PassthroughSubject<Contract, Never>()
    
    private var listeners: [ListenerRegistration] = []
    
    public var rfqUpdates: AnyPublisher<RFQ, Never> {
        _rfqUpdates.eraseToAnyPublisher()
    }
    
    public var bidUpdates: AnyPublisher<Bid, Never> {
        _bidUpdates.eraseToAnyPublisher()
    }
    
    public var messageUpdates: AnyPublisher<Message, Never> {
        _messageUpdates.eraseToAnyPublisher()
    }
    
    public var contractUpdates: AnyPublisher<Contract, Never> {
        _contractUpdates.eraseToAnyPublisher()
    }
    
    public init(config: HomeServicesConfig = .localDev) {
        self.config = config
        
        // Initialize Firebase services
        self.db = Firestore.firestore()
        self.auth = Auth.auth()
        self.functions = Functions.functions()
        self.storage = Storage.storage()
        
        // Configure for local development if needed
        if config.environment == .local {
            configureForLocalDevelopment()
        }
        
        setupRealtimeListeners()
    }
    
    deinit {
        // Clean up listeners
        listeners.forEach { $0.remove() }
    }
    
    private func configureForLocalDevelopment() {
        // Connect to local emulators
        db.useEmulator(withHost: "localhost", port: 8080)
        auth.useEmulator(withHost: "localhost", port: 9099)
        functions.useEmulator(withHost: "localhost", port: 5001)
        storage.useEmulator(withHost: "localhost", port: 9199)
        
        print("🏠 Home Services configured for local development")
    }
    
    private func setupRealtimeListeners() {
        guard let userId = auth.currentUser?.uid else { return }
        
        // Listen to customer RFQs
        let rfqListener = db.collection("rfqs")
            .whereField("customerId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                documents.compactMap { doc -> RFQ? in
                    guard let dto = try? doc.data(as: RFQDTO.self) else { return nil }
                    return RFQ(from: dto)
                }
                .forEach { self?._rfqUpdates.send($0) }
            }
        listeners.append(rfqListener)
        
        // Listen to customer contracts
        let customerContractListener = db.collection("contracts")
            .whereField("customerId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                documents.compactMap { doc -> Contract? in
                    guard let dto = try? doc.data(as: ContractDTO.self) else { return nil }
                    return Contract(from: dto)
                }
                .forEach { self?._contractUpdates.send($0) }
            }
        listeners.append(customerContractListener)
        
        // Listen to pro contracts
        let proContractListener = db.collection("contracts")
            .whereField("proId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                documents.compactMap { doc -> Contract? in
                    guard let dto = try? doc.data(as: ContractDTO.self) else { return nil }
                    return Contract(from: dto)
                }
                .forEach { self?._contractUpdates.send($0) }
            }
        listeners.append(proContractListener)
        
        // Listen to bids for customer's RFQs
        db.collection("rfqs")
            .whereField("customerId", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let rfqIds = snapshot?.documents.map({ $0.documentID }) else { return }
                for rfqId in rfqIds {
                    let bidListener = self?.db.collection("bids")
                        .whereField("rfqId", isEqualTo: rfqId)
                        .addSnapshotListener { snapshot, error in
                            guard let documents = snapshot?.documents else { return }
                            documents.compactMap { doc -> Bid? in
                                guard let dto = try? doc.data(as: BidDTO.self) else { return nil }
                                return Bid(from: dto)
                            }
                            .forEach { self?._bidUpdates.send($0) }
                        }
                    if let bidListener = bidListener {
                        self?.listeners.append(bidListener)
                    }
                }
            }
        
        // Listen to bids where user is the pro
        let proBidListener = db.collection("bids")
            .whereField("proId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                documents.compactMap { doc -> Bid? in
                    guard let dto = try? doc.data(as: BidDTO.self) else { return nil }
                    return Bid(from: dto)
                }
                .forEach { self?._bidUpdates.send($0) }
            }
        listeners.append(proBidListener)
    }
    
    // MARK: - Categories
    
    public func listCategories() async throws -> [ServiceCategory] {
        let snapshot = try await db.collection("serviceCategories")
            .whereField("isActive", isEqualTo: true)
            .order(by: "displayOrder")
            .getDocuments()
        
        return try snapshot.documents.compactMap {
            try $0.data(as: ServiceCategory.self)
        }
    }
    
    public func getCategory(id: String) async throws -> ServiceCategory? {
        let doc = try await db.collection("serviceCategories").document(id).getDocument()
        return try doc.data(as: ServiceCategory.self)
    }
    
    // MARK: - RFQs
    
    public func createRFQ(_ rfq: RFQDraft) async throws -> RFQ {
        guard let userId = auth.currentUser?.uid else {
            throw HomeServicesError.unauthorized
        }
        
        // Call Cloud Function to create RFQ
        let data: [String: Any] = [
            "categoryId": rfq.categoryId,
            "scope": [
                "title": rfq.scope.title,
                "description": rfq.scope.description,
                "urgency": rfq.scope.urgency.rawValue
            ],
            "location": [
                "lat": rfq.location.lat,
                "lng": rfq.location.lng,
                "city": rfq.location.city,
                "arrondissement": rfq.location.arrondissement ?? ""
            ],
            "budgetRange": rfq.budgetRange != nil ? [
                "min": rfq.budgetRange!.min,
                "max": rfq.budgetRange!.max
            ] : nil,
            "siteVisitRequested": rfq.siteVisitRequested,
            "media": rfq.media
        ].compactMapValues { $0 }
        
        let result = try await functions.httpsCallable("createRfq").call(data)
        guard let rfqData = result.data as? [String: Any],
              let rfqId = rfqData["rfqId"] as? String else {
            throw HomeServicesError.serverError("Failed to create RFQ")
        }
        
        return try await getRFQ(id: rfqId)!
    }
    
    public func updateRFQ(id: String, rfq: RFQDraft) async throws -> RFQ {
        // Implementation for updating RFQ
        guard auth.currentUser?.uid != nil else {
            throw HomeServicesError.unauthorized
        }
        
        // Update via Cloud Function
        let data: [String: Any] = [
            "rfqId": id,
            "updates": [
                "scope": [
                    "title": rfq.scope.title,
                    "description": rfq.scope.description,
                    "urgency": rfq.scope.urgency.rawValue
                ],
                "budgetRange": rfq.budgetRange != nil ? [
                    "min": rfq.budgetRange!.min,
                    "max": rfq.budgetRange!.max
                ] : nil,
                "siteVisitRequested": rfq.siteVisitRequested
            ].compactMapValues { $0 }
        ]
        
        _ = try await functions.httpsCallable("updateRfq").call(data)
        return try await getRFQ(id: id)!
    }
    
    public func getRFQ(id: String) async throws -> RFQ? {
        let doc = try await db.collection("rfqs").document(id).getDocument()
        guard doc.exists, let dto = try? doc.data(as: RFQDTO.self) else { return nil }
        return RFQ(from: dto)
    }
    
    public func listMyRFQs() async throws -> [RFQ] {
        guard let userId = auth.currentUser?.uid else {
            throw HomeServicesError.unauthorized
        }
        
        let snapshot = try await db.collection("rfqs")
            .whereField("customerId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> RFQ? in
            guard let dto = try? doc.data(as: RFQDTO.self) else { return nil }
            return RFQ(from: dto)
        }
    }
    
    public func listAvailableRFQs(proId: String, city: String? = nil, limit: Int = 20) async throws -> [RFQ] {
        guard auth.currentUser?.uid == proId else { throw HomeServicesError.unauthorized }
        var req: [String: Any] = [
            "limit": limit
        ]
        if let city { req["city"] = city }
        let result = try await functions.httpsCallable("listAvailableRfqs").call(req)
        guard let obj = result.data as? [String: Any], let arr = obj["rfqs"] as? [[String: Any]] else {
            return []
        }
        let json = try JSONSerialization.data(withJSONObject: arr)
        return try JSONDecoder().decode([RFQ].self, from: json)
    }

    // Protocol conformance wrappers
    public func listAvailableRFQs(proId: String) async throws -> [RFQ] {
        return try await listAvailableRFQs(proId: proId, city: nil, limit: 20)
    }
    
    public func cancelRFQ(id: String, reason: String? = nil) async throws {
        guard auth.currentUser?.uid != nil else { throw HomeServicesError.unauthorized }
        _ = try await functions.httpsCallable("cancelRfq").call([
            "rfqId": id,
            "reason": reason ?? ""
        ])
    }

    public func cancelRFQ(id: String) async throws {
        try await cancelRFQ(id: id, reason: nil)
    }
    
    // MARK: - Bids
    
    public func submitBid(_ bid: NewBid) async throws -> Bid {
        guard let userId = auth.currentUser?.uid else {
            throw HomeServicesError.unauthorized
        }
        
        let data: [String: Any] = [
            "rfqId": bid.rfqId,
            "amountMAD": bid.amountMAD,
            "timelineDays": bid.timelineDays,
            "includesMaterials": bid.includesMaterials,
            "visitRequired": bid.visitRequired,
            "message": bid.message ?? "",
            "autoAcceptAbove": bid.autoAcceptAbove ?? 0
        ]
        let result = try await functions.httpsCallable("submitBid").call(data)
        guard let bidData = result.data as? [String: Any],
              let bidId = bidData["bidId"] as? String else {
            throw HomeServicesError.serverError("Failed to submit bid")
        }
        
        return try await getBid(id: bidId)!
    }
    
    public func counterBid(_ counter: Counter) async throws -> Bid {
        let data: [String: Any] = [
            "bidId": counter.bidId,
            "newAmountMAD": counter.newAmountMAD ?? 0,
            "newTimelineDays": counter.newTimelineDays ?? 0
        ].compactMapValues { $0 }
        
        let result = try await functions.httpsCallable("counterBid").call(data)
        guard let bidData = result.data as? [String: Any],
              let bidId = bidData["bidId"] as? String else {
            throw HomeServicesError.serverError("Failed to counter bid")
        }
        
        return try await getBid(id: bidId)!
    }
    
    public func withdrawBid(id: String) async throws {
        _ = try await functions.httpsCallable("withdrawBid").call(["bidId": id])
    }
    
    public func listBids(rfqId: String) async throws -> [Bid] {
        guard let userId = auth.currentUser?.uid else {
            throw HomeServicesError.unauthorized
        }
        
        // Check if user owns the RFQ
        guard let rfq = try await getRFQ(id: rfqId), rfq.customerId == userId else {
            throw HomeServicesError.unauthorized
        }
        
        let result = try await functions.httpsCallable("listBidsForRfq").call(["rfqId": rfqId])
        guard let obj = result.data as? [String: Any], let arr = obj["bids"] as? [[String: Any]] else {
            return []
        }
        let json = try JSONSerialization.data(withJSONObject: arr)
        return try JSONDecoder().decode([Bid].self, from: json)
    }
    
    public func getBid(id: String) async throws -> Bid? {
        // Bids are subcollections, need to find the parent RFQ first
        // For simplicity, assuming we have the full path or using a callable function
        let result = try await functions.httpsCallable("getBid").call(["bidId": id])
        guard let bidData = result.data as? [String: Any] else {
            return nil
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: bidData)
        return try JSONDecoder().decode(Bid.self, from: jsonData)
    }
    
    public func acceptBid(_ bidId: String, depositPercent: Int?) async throws -> Contract {
        let data: [String: Any] = [
            "bidId": bidId,
            "depositPercent": depositPercent ?? 30
        ]
        
        let result = try await functions.httpsCallable("acceptBid").call(data)
        guard let contractData = result.data as? [String: Any],
              let contractId = contractData["contractId"] as? String else {
            throw HomeServicesError.serverError("Failed to accept bid")
        }
        
        return try await getContract(id: contractId)!
    }
    
    // MARK: - Contracts
    
    public func getContract(id: String) async throws -> Contract? {
        let doc = try await db.collection("contracts").document(id).getDocument()
        guard doc.exists, let dto = try? doc.data(as: ContractDTO.self) else { return nil }
        return Contract(from: dto)
    }
    
    public func listMyContracts(asPro: Bool) async throws -> [Contract] {
        guard let userId = auth.currentUser?.uid else {
            throw HomeServicesError.unauthorized
        }
        
        let field = asPro ? "proId" : "customerId"
        let snapshot = try await db.collection("contracts")
            .whereField(field, isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> Contract? in
            guard let dto = try? doc.data(as: ContractDTO.self) else { return nil }
            return Contract(from: dto)
        }
    }
    
    public func completeContract(_ contractId: String) async throws {
        _ = try await functions.httpsCallable("completeContract").call(["contractId": contractId])
    }
    
    public func cancelContract(_ contractId: String, reason: String) async throws {
        _ = try await functions.httpsCallable("cancelContract").call([
            "contractId": contractId,
            "reason": reason
        ])
    }
    
    // MARK: - Payments & Escrow
    
    public func createEscrow(_ req: EscrowRequest) async throws -> Escrow {
        let data: [String: Any] = [
            "contractId": req.contractId,
            "method": req.method.rawValue,
            "milestones": req.milestones?.map { [
                "id": $0.id,
                "amount": $0.amountMAD
            ] } ?? []
        ]
        
        let result = try await functions.httpsCallable("createEscrow").call(data)
        guard let escrowData = result.data as? [String: Any],
              let escrowId = escrowData["escrowId"] as? String else {
            throw HomeServicesError.serverError("Failed to create escrow")
        }
        
        return try await getEscrow(contractId: req.contractId)!
    }
    
    public func getEscrow(contractId: String) async throws -> Escrow? {
        let snapshot = try await db.collection("escrows")
            .whereField("contractId", isEqualTo: contractId)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first,
              doc.exists,
              let dto = try? doc.data(as: EscrowDTO.self) else { return nil }
        return Escrow(from: dto)
    }
    
    public func releaseMilestone(escrowId: String, milestoneId: String) async throws {
        _ = try await functions.httpsCallable("releaseMilestone").call([
            "escrowId": escrowId,
            "milestoneId": milestoneId
        ])
    }
    
    // MARK: - Reviews
    
    public func createReview(_ review: NewReview) async throws -> Review {
        let data: [String: Any] = [
            "contractId": review.contractId,
            "rating": review.rating,
            "text": review.text ?? ""
        ]
        
        let result = try await functions.httpsCallable("createReview").call(data)
        guard let reviewData = result.data as? [String: Any],
              let reviewId = reviewData["reviewId"] as? String else {
            throw HomeServicesError.serverError("Failed to create review")
        }
        
        let doc = try await db.collection("reviews").document(reviewId).getDocument()
        guard doc.exists, let dto = try? doc.data(as: ReviewDTO.self) else {
            throw HomeServicesError.serverError("Failed to parse review")
        }
        return Review(from: dto)
    }
    
    public func getReviews(userId: String) async throws -> [Review] {
        let snapshot = try await db.collection("reviews")
            .whereField("revieweeId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> Review? in
            guard let dto = try? doc.data(as: ReviewDTO.self) else { return nil }
            return Review(from: dto)
        }
    }
    
    // MARK: - Messaging
    
    public func sendMessage(threadId: String, text: String, attachments: [String]) async throws -> Message {
        guard let userId = auth.currentUser?.uid else {
            throw HomeServicesError.unauthorized
        }
        
        // Route through callable to ensure server-side PII redaction and access controls
        let callData: [String: Any] = [
            "conversationId": threadId,
            "conversationType": "contract", // or "rfq" depending on UI thread type
            "text": text,
            "attachments": attachments
        ]
        let result = try await functions.httpsCallable("sendMessage").call(callData)
        guard let data = result.data as? [String: Any], let messageId = data["messageId"] as? String else {
            throw HomeServicesError.serverError("Failed to send message")
        }
        let doc = try await db.collection("messages").document(messageId).getDocument()
        guard doc.exists, let dto = try? doc.data(as: MessageDTO.self) else {
            throw HomeServicesError.serverError("Failed to parse message")
        }
        return Message(from: dto)
    }
    
    public func getMessages(threadId: String, type: String = "contract", limit: Int = 50, lastMessageId: String? = nil) async throws -> [Message] {
        var req: [String: Any] = [
            "conversationId": threadId,
            "conversationType": type,
            "limit": limit
        ]
        if let lastMessageId { req["lastMessageId"] = lastMessageId }
        let result = try await functions.httpsCallable("getMessages").call(req)
        guard let obj = result.data as? [String: Any], let arr = obj["messages"] as? [[String: Any]] else {
            return []
        }
        let json = try JSONSerialization.data(withJSONObject: arr)
        return try JSONDecoder().decode([Message].self, from: json)
    }

    public func getMessages(threadId: String) async throws -> [Message] {
        return try await getMessages(threadId: threadId, type: "contract", limit: 50, lastMessageId: nil)
    }

    public func markMessagesRead(threadId: String, type: String = "contract", lastMessageId: String? = nil) async throws -> Int {
        var req: [String: Any] = [
            "conversationId": threadId,
            "conversationType": type
        ]
        if let lastMessageId { req["lastMessageId"] = lastMessageId }
        let result = try await functions.httpsCallable("markMessagesRead").call(req)
        let count = (result.data as? [String: Any])?["marked"] as? Int ?? 0
        return count
    }

    public func markMessageRead(threadId: String, messageId: String) async throws {
        _ = try await markMessagesRead(threadId: threadId, type: "contract", lastMessageId: messageId)
    }
    
    // MARK: - Pro Profile
    
    public func getProProfile(userId: String) async throws -> ProProfile? {
        let doc = try await db.collection("proProfiles").document(userId).getDocument()
        return try doc.data(as: ProProfile.self)
    }
    
    public func updateProProfile(_ profile: ProProfile) async throws -> ProProfile {
        guard let userId = auth.currentUser?.uid,
              profile.userId == userId else {
            throw HomeServicesError.unauthorized
        }
        
        try await db.collection("proProfiles").document(userId).setData(from: profile, merge: true)
        return try await getProProfile(userId: userId)!
    }
    
    public func searchPros(categoryId: String, city: String) async throws -> [ProProfile] {
        // Simplified query to avoid composite index issues
        let snapshot = try await db.collection("proProfiles")
            .whereField("skills", arrayContains: categoryId)
            .whereField("serviceArea.city", isEqualTo: city)
            .order(by: "rating", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        // Client-side filter for verification
        return try snapshot.documents.compactMap {
            try $0.data(as: ProProfile.self)
        }.filter { $0.verificationTier != .unverified }
        .prefix(20)
        .map { $0 }
    }
    
    // MARK: - Disputes
    
    public func createDispute(contractId: String, reason: String, evidence: [String]) async throws -> Dispute {
        guard let userId = auth.currentUser?.uid else {
            throw HomeServicesError.unauthorized
        }
        
        // Determine if user is customer or pro
        guard let contract = try await getContract(id: contractId) else {
            throw HomeServicesError.contractNotFound
        }
        
        let side: Dispute.DisputeSide = contract.customerId == userId ? .customer : .pro
        
        let data: [String: Any] = [
            "contractId": contractId,
            "side": side.rawValue,
            "reason": reason,
            "evidence": evidence
        ]
        
        let result = try await functions.httpsCallable("createDispute").call(data)
        guard let disputeData = result.data as? [String: Any],
              let disputeId = disputeData["disputeId"] as? String else {
            throw HomeServicesError.serverError("Failed to create dispute")
        }
        
        return try await getDispute(id: disputeId)!
    }
    
    public func getDispute(id: String) async throws -> Dispute? {
        let doc = try await db.collection("disputes").document(id).getDocument()
        guard doc.exists, let dto = try? doc.data(as: DisputeDTO.self) else { return nil }
        return Dispute(from: dto)
    }
    
    // MARK: - AI Features
    
    public func aiDescribeScope(photoUrls: [String], categoryId: String?, userNotes: String?) async throws -> AIScopeDescription {
        guard auth.currentUser?.uid != nil else {
            throw HomeServicesError.unauthorized
        }
        
        let data: [String: Any] = [
            "photoUrls": photoUrls,
            "categoryId": categoryId ?? "",
            "userNotes": userNotes ?? ""
        ].compactMapValues { $0 }
        
        let result = try await functions.httpsCallable("aiDescribeScope").call(data)
        guard let responseData = result.data as? [String: Any] else {
            throw HomeServicesError.serverError("Invalid AI response")
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: responseData)
        return try JSONDecoder().decode(AIScopeDescription.self, from: jsonData)
    }
    
    public func aiEstimateJob(description: String, categoryId: String?, location: RFQ.Location?, urgency: String?, photoUrls: [String]?) async throws -> AIJobEstimate {
        guard auth.currentUser?.uid != nil else {
            throw HomeServicesError.unauthorized
        }
        
        var data: [String: Any] = [
            "description": description
        ]
        
        if let categoryId = categoryId {
            data["categoryId"] = categoryId
        }
        
        if let location = location {
            data["location"] = [
                "city": location.city,
                "lat": location.lat,
                "lng": location.lng
            ]
        }
        
        if let urgency = urgency {
            data["urgency"] = urgency
        }
        
        if let photoUrls = photoUrls {
            data["photoUrls"] = photoUrls
        }
        
        let result = try await functions.httpsCallable("aiEstimateJob").call(data)
        guard let responseData = result.data as? [String: Any] else {
            throw HomeServicesError.serverError("Invalid AI estimation response")
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: responseData)
        return try JSONDecoder().decode(AIJobEstimate.self, from: jsonData)
    }
}