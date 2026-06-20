import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import FirebaseCore
import FirebaseStorage
import FirebaseFirestoreSwift

/// Firestore implementation of MarketplaceServicing
/// Per client_server_responsibility_plan.md - all writes go through backend callables
public final class FirestoreMarketplaceService: MarketplaceServicing {
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private lazy var functions: Functions = {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return Functions.functions()
    }()
    private let storage = Storage.storage()
    
    // Publishers for real-time updates
    private let listingSubject = PassthroughSubject<Listing, Never>()
    private let messageSubject = PassthroughSubject<Message, Never>()
    
    private var listingListeners: [String: ListenerRegistration] = [:]
    private var conversationListeners: [String: ListenerRegistration] = [:]
    
    public var listingUpdates: AnyPublisher<Listing, Never> {
        listingSubject.eraseToAnyPublisher()
    }
    
    public var conversationUpdates: AnyPublisher<Message, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init() {
        setupRealtimeListeners()
    }
    
    deinit {
        // Clean up listeners
        listingListeners.values.forEach { $0.remove() }
        conversationListeners.values.forEach { $0.remove() }
    }
    
    // MARK: - Discovery & Search
    
    public func listNearby(in cityId: String, center: Coordinates, radiusKm: Double?) async throws -> [Listing] {
        // Call backend function for search with geo filtering
        let data: [String: Any] = [
            "cityId": cityId,
            "center": [
                "latitude": center.latitude,
                "longitude": center.longitude
            ],
            "radiusKm": radiusKm ?? 10.0
        ]
        
        let result = try await functions.httpsCallable("marketplace.listNearby").call(data)
        
        guard let listingsData = result.data as? [[String: Any]] else {
            throw MarketplaceError.invalidResponse
        }
        
        return try listingsData.compactMap { dict in
            let jsonData = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(Listing.self, from: jsonData)
        }
    }
    
    public func search(query: String, filters: SearchFilters) async throws -> [Listing] {
        // Call backend search function with filters
        var data: [String: Any] = [
            "query": query,
            "cityId": filters.cityId
        ]
        
        if let neighborhoods = filters.neighborhoods {
            data["neighborhoods"] = neighborhoods
        }
        
        if let categories = filters.categories {
            data["categories"] = categories.map { $0.rawValue }
        }
        
        if let priceRange = filters.priceRange {
            data["priceRange"] = [
                "min": priceRange.min as Any,
                "max": priceRange.max as Any
            ]
        }
        
        if let condition = filters.condition {
            data["condition"] = condition.rawValue
        }
        
        let result = try await functions.httpsCallable("marketplace.search").call(data)
        
        guard let listingsData = result.data as? [[String: Any]] else {
            throw MarketplaceError.invalidResponse
        }
        
        return try listingsData.compactMap { dict in
            let jsonData = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(Listing.self, from: jsonData)
        }
    }
    
    public func getListing(id: String) async throws -> Listing? {
        let doc = try await db.collection("listings").document(id).getDocument()
        return try doc.data(as: Listing.self)
    }
    
    // MARK: - Listing Management
    
    public func createListing(draft: ListingDraft) async throws -> Listing {
        // Upload images first
        let imageUrls = try await uploadImages(draft.images)
        
        // Call backend function to create listing with AI assistance
        let data: [String: Any] = [
            "title": draft.title,
            "description": draft.description,
            "category": draft.category.rawValue,
            "condition": draft.condition.rawValue,
            "price": [
                "amount": draft.price.amount,
                "currency": draft.price.currency
            ],
            "images": imageUrls,
            "location": [
                "lat": draft.location.lat,
                "lng": draft.location.lng,
                "addressLine": draft.location.addressLine as Any,
                "arrondissement": draft.location.arrondissement as Any
            ],
            "deliveryOptions": [
                "meetup": draft.deliveryOptions.meetup,
                "courier": draft.deliveryOptions.courier
            ],
            "attributes": draft.attributes
        ]
        
        let result = try await functions.httpsCallable("marketplace.createListing").call(data)
        
        guard let listingData = result.data as? [String: Any] else {
            throw MarketplaceError.invalidResponse
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: listingData)
        return try JSONDecoder().decode(Listing.self, from: jsonData)
    }
    
    public func updateListing(id: String, updates: ListingUpdate) async throws -> Listing {
        var data: [String: Any] = ["listingId": id]
        
        if let title = updates.title {
            data["title"] = title
        }
        
        if let description = updates.description {
            data["description"] = description
        }
        
        if let price = updates.price {
            data["price"] = [
                "amount": price.amount,
                "currency": price.currency
            ]
        }
        
        if let status = updates.status {
            data["status"] = status.rawValue
        }
        
        if let deliveryOptions = updates.deliveryOptions {
            data["deliveryOptions"] = [
                "meetup": deliveryOptions.meetup,
                "courier": deliveryOptions.courier
            ]
        }
        
        let result = try await functions.httpsCallable("marketplace.updateListing").call(data)
        
        guard let listingData = result.data as? [String: Any] else {
            throw MarketplaceError.invalidResponse
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: listingData)
        return try JSONDecoder().decode(Listing.self, from: jsonData)
    }
    
    public func markReserved(id: String, buyerId: String?) async throws {
        let data: [String: Any] = [
            "listingId": id,
            "buyerId": buyerId as Any
        ]
        
        _ = try await functions.httpsCallable("marketplace.markReserved").call(data)
    }
    
    public func markSold(id: String) async throws {
        let data = ["listingId": id]
        _ = try await functions.httpsCallable("marketplace.markSold").call(data)
    }
    
    // MARK: - Chat & Offers
    
    public func openConversation(with userId: String, listingId: String) async throws -> Conversation {
        let data: [String: Any] = [
            "userId": userId,
            "listingId": listingId
        ]
        
        let result = try await functions.httpsCallable("marketplace.openConversation").call(data)
        
        guard let conversationData = result.data as? [String: Any] else {
            throw MarketplaceError.invalidResponse
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: conversationData)
        let conversation = try JSONDecoder().decode(Conversation.self, from: jsonData)
        
        // Set up listener for this conversation
        setupConversationListener(conversationId: conversation.id ?? "")
        
        return conversation
    }
    
    public func sendMessage(conversationId: String, message: MessageDraft) async throws {
        var data: [String: Any] = [
            "conversationId": conversationId,
            "type": message.type.rawValue,
            "content": message.content
        ]
        
        // Upload image if present
        if let imageData = message.imageData {
            let imageUrl = try await uploadImage(imageData)
            data["imageUrl"] = imageUrl
        }
        
        _ = try await functions.httpsCallable("marketplace.sendMessage").call(data)
    }
    
    public func makeOffer(listingId: String, amount: Money) async throws -> Offer {
        let data: [String: Any] = [
            "listingId": listingId,
            "amount": [
                "amount": amount.amount,
                "currency": amount.currency
            ]
        ]
        
        let result = try await functions.httpsCallable("marketplace.makeOffer").call(data)
        
        guard let offerData = result.data as? [String: Any] else {
            throw MarketplaceError.invalidResponse
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: offerData)
        return try JSONDecoder().decode(Offer.self, from: jsonData)
    }
    
    public func respondToOffer(offerId: String, action: OfferAction) async throws {
        let data: [String: Any] = [
            "offerId": offerId,
            "action": action.rawValue
        ]
        
        _ = try await functions.httpsCallable("marketplace.respondToOffer").call(data)
    }
    
    // MARK: - Reservations & Delivery
    
    public func createReservation(listingId: String, details: ReservationDetails) async throws -> Reservation {
        var data: [String: Any] = [
            "listingId": listingId,
            "paymentMethod": details.paymentMethod.rawValue
        ]
        
        if let meetup = details.meetup {
            data["meetup"] = [
                "when": ISO8601DateFormatter().string(from: meetup.when),
                "where": meetup.locationName,
                "coordinates": meetup.coordinates.map { [
                    "latitude": $0.latitude,
                    "longitude": $0.longitude
                ] }
            ]
        }
        
        if let delivery = details.delivery {
            data["delivery"] = [
                "courierJobId": delivery.courierJobId as Any,
                "estimatedDelivery": delivery.estimatedDelivery.map { ISO8601DateFormatter().string(from: $0) } as Any
            ]
        }
        
        let result = try await functions.httpsCallable("marketplace.createReservation").call(data)
        
        guard let reservationData = result.data as? [String: Any] else {
            throw MarketplaceError.invalidResponse
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: reservationData)
        return try JSONDecoder().decode(Reservation.self, from: jsonData)
    }
    
    public func completeReservation(reservationId: String) async throws {
        let data = ["reservationId": reservationId]
        _ = try await functions.httpsCallable("marketplace.completeReservation").call(data)
    }
    
    // MARK: - Alerts
    
    public func createAlert(criteria: AlertCriteria) async throws -> Alert {
        let data: [String: Any] = [
            "query": criteria.query,
            "cityId": criteria.cityId,
            "neighborhoods": criteria.neighborhoods,
            "categories": criteria.categories.map { $0.rawValue },
            "priceRange": criteria.priceRange.map { [
                "min": $0.min,
                "max": $0.max
            ] } as Any
        ]
        
        let result = try await functions.httpsCallable("marketplace.ai.createWatcher").call(data)
        
        guard let alertData = result.data as? [String: Any] else {
            throw MarketplaceError.invalidResponse
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: alertData)
        return try JSONDecoder().decode(Alert.self, from: jsonData)
    }
    
    public func listMyAlerts() async throws -> [Alert] {
        guard let userId = auth.currentUser?.uid else {
            throw MarketplaceError.notAuthenticated
        }
        
        let snapshot = try await db.collection("alerts")
            .whereField("userId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: Alert.self)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupRealtimeListeners() {
        // Set up general listeners for the user's data
        guard let userId = auth.currentUser?.uid else { return }
        
        // Listen for user's listings
        let listingListener = db.collection("listings")
            .whereField("sellerId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                for doc in documents {
                    if let listing = try? doc.data(as: Listing.self) {
                        self?.listingSubject.send(listing)
                    }
                }
            }
        
        listingListeners["user_listings"] = listingListener
    }
    
    private func setupConversationListener(conversationId: String) {
        guard !conversationId.isEmpty else { return }
        
        // Remove existing listener if any
        conversationListeners[conversationId]?.remove()
        
        // Set up new listener
        let listener = db.collection("messages")
            .document(conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documentChanges else { return }
                
                for change in documents {
                    if change.type == .added {
                        if let message = try? change.document.data(as: Message.self) {
                            self?.messageSubject.send(message)
                        }
                    }
                }
            }
        
        conversationListeners[conversationId] = listener
    }
    
    private func uploadImages(_ images: [Data]) async throws -> [String] {
        var urls: [String] = []
        
        for (index, imageData) in images.enumerated() {
            let url = try await uploadImage(imageData, index: index)
            urls.append(url)
        }
        
        return urls
    }
    
    private func uploadImage(_ imageData: Data, index: Int = 0) async throws -> String {
        guard let userId = auth.currentUser?.uid else {
            throw MarketplaceError.notAuthenticated
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(userId)_\(timestamp)_\(index).jpg"
        let storageRef = storage.reference().child("marketplace/images/\(filename)")
        
        _ = try await storageRef.putDataAsync(imageData)
        let url = try await storageRef.downloadURL()
        
        return url.absoluteString
    }
}

// Error types are declared in MockMarketplaceService.swift for shared use