import Foundation
import Combine

/// Mock implementation of MarketplaceServicing for testing and development
/// Provides realistic data for UI testing without backend dependency
public final class MockMarketplaceService: MarketplaceServicing {
    
    // MARK: - Publishers
    
    private let listingUpdatesSubject = PassthroughSubject<Listing, Never>()
    private let conversationUpdatesSubject = PassthroughSubject<Message, Never>()
    
    public var listingUpdates: AnyPublisher<Listing, Never> {
        listingUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var conversationUpdates: AnyPublisher<Message, Never> {
        conversationUpdatesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Mock Data
    
    private var mockListings: [Listing] = []
    private var mockConversations: [Conversation] = []
    private var mockOffers: [Offer] = []
    private var mockReservations: [Reservation] = []
    private var mockAlerts: [Alert] = []
    
    public init() {
        generateMockData()
    }
    
    // MARK: - Discovery & Search
    
    public func listNearby(in cityId: String, center: Coordinates, radiusKm: Double? = 10.0) async throws -> [Listing] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Filter by city and proximity
        let nearbyListings = mockListings.filter { listing in
            listing.cityId == cityId && listing.status == .active
        }
        
        return Array(nearbyListings.prefix(20))
    }
    
    public func search(query: String, filters: SearchFilters) async throws -> [Listing] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        var results = mockListings.filter { $0.status == .active }
        
        // Apply city filter (always provided)
        let cityId = filters.cityId
        results = results.filter { $0.cityId == cityId }
        
        // Apply category filter
        if let categories = filters.categories, !categories.isEmpty {
            results = results.filter { categories.contains($0.category) }
        }
        
        // Apply text search
        if !query.isEmpty {
            results = results.filter { listing in
                listing.title.localizedCaseInsensitiveContains(query) ||
                listing.description.localizedCaseInsensitiveContains(query)
            }
        }
        
        // Apply price range filter
        if let priceRange = filters.priceRange {
            let minCents = priceRange.min ?? Int.min
            let maxCents = priceRange.max ?? Int.max
            results = results.filter { listing in
                let priceCents = listing.price.amount
                return priceCents >= minCents && priceCents <= maxCents
            }
        }
        
        return Array(results.prefix(50))
    }
    
    public func getListing(id: String) async throws -> Listing? {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return mockListings.first { $0.id == id }
    }
    
    // MARK: - Listing Management
    
    public func createListing(draft: ListingDraft) async throws -> Listing {
        // Simulate AI enhancement processing
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let listing = Listing(
            id: UUID().uuidString,
            cityId: "casablanca",
            neighborhoodId: nil,
            title: enhanceTitle(draft.title),
            description: enhanceDescription(draft.description),
            category: draft.category,
            condition: draft.condition,
            price: draft.price,
            images: generateMockImages(),
            thumbnails: generateMockThumbnails(),
            sellerId: "current_user",
            status: .active,
            createdAt: Date(),
            updatedAt: Date(),
            location: draft.location,
            deliveryOptions: draft.deliveryOptions,
            attributes: draft.attributes,
            embedding: nil,
            moderation: Listing.ModerationInfo(status: .approved, reasons: [])
        )
        
        mockListings.append(listing)
        listingUpdatesSubject.send(listing)
        
        return listing
    }
    
    public func updateListing(id: String, updates: ListingUpdate) async throws -> Listing {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard let index = mockListings.firstIndex(where: { $0.id == id }) else {
            throw MarketplaceError.listingNotFound
        }
        
        let old = mockListings[index]
        let newListing = Listing(
            id: old.id,
            cityId: old.cityId,
            neighborhoodId: old.neighborhoodId,
            title: updates.title ?? old.title,
            description: updates.description ?? old.description,
            category: old.category,
            condition: old.condition,
            price: updates.price ?? old.price,
            images: old.images,
            thumbnails: old.thumbnails,
            sellerId: old.sellerId,
            status: updates.status ?? old.status,
            createdAt: old.createdAt,
            updatedAt: Date(),
            location: old.location,
            deliveryOptions: updates.deliveryOptions ?? old.deliveryOptions,
            attributes: old.attributes,
            embedding: old.embedding,
            moderation: old.moderation
        )
        mockListings[index] = newListing
        
        listingUpdatesSubject.send(newListing)
        
        return newListing
    }
    
    public func markReserved(id: String, buyerId: String?) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = mockListings.firstIndex(where: { $0.id == id }) else {
            throw MarketplaceError.listingNotFound
        }
        
        mockListings[index].status = .reserved
        mockListings[index].updatedAt = Date()
        
        listingUpdatesSubject.send(mockListings[index])
    }
    
    public func markSold(id: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = mockListings.firstIndex(where: { $0.id == id }) else {
            throw MarketplaceError.listingNotFound
        }
        
        mockListings[index].status = .sold
        mockListings[index].updatedAt = Date()
        
        listingUpdatesSubject.send(mockListings[index])
    }
    
    // MARK: - Chat & Offers
    
    public func openConversation(with userId: String, listingId: String) async throws -> Conversation {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Check if conversation already exists
        if let existing = mockConversations.first(where: { 
            $0.listingId == listingId && $0.participants.contains(userId) 
        }) {
            return existing
        }
        
        let conversation = Conversation(
            id: UUID().uuidString,
            participants: ["current_user", userId],
            listingId: listingId,
            lastMessageAt: Date(),
            unreadCount: ["current_user": 0, userId: 0]
        )
        
        mockConversations.append(conversation)
        
        return conversation
    }
    
    public func sendMessage(conversationId: String, message: MessageDraft) async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
        
        let newMessage = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: "current_user",
            type: message.type,
            content: message.content,
            createdAt: Date()
        )
        
        conversationUpdatesSubject.send(newMessage)
        
        // Simulate AI auto-response after 2-3 seconds for demo
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int.random(in: 2...3))) {
            let autoResponse = Message(
                id: UUID().uuidString,
                conversationId: conversationId,
                senderId: "seller_user",
                type: .text,
                content: self.generateAutoResponse(to: message.content),
                createdAt: Date()
            )
            
            self.conversationUpdatesSubject.send(autoResponse)
        }
    }
    
    public func makeOffer(listingId: String, amount: Money) async throws -> Offer {
        try await Task.sleep(nanoseconds: 600_000_000)
        
        let offer = Offer(
            id: UUID().uuidString,
            listingId: listingId,
            buyerId: "current_user",
            amount: amount,
            status: .pending,
            createdAt: Date(),
            updatedAt: nil
        )
        
        mockOffers.append(offer)
        
        // Simulate seller response after 5-10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 5...10)) {
            // 70% chance of acceptance, 30% counter-offer
            if Double.random(in: 0...1) < 0.7 {
                // Accept offer
                if let index = self.mockOffers.firstIndex(where: { $0.id == offer.id }) {
                    self.mockOffers[index].status = .accepted
                    self.mockOffers[index].updatedAt = Date()
                }
            } else {
                // Counter-offer
                let counterAmount = Money(
                    amount: Int(Double(amount.amount) * Double.random(in: 1.05...1.15)),
                    currency: amount.currency
                )
                
                let counterOffer = Offer(
                    id: UUID().uuidString,
                    listingId: listingId,
                    buyerId: "seller_user",
                    amount: counterAmount,
                    status: .pending,
                    createdAt: Date(),
                    updatedAt: nil
                )
                
                self.mockOffers.append(counterOffer)
            }
        }
        
        return offer
    }
    
    public func respondToOffer(offerId: String, action: OfferAction) async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
        
        guard let index = mockOffers.firstIndex(where: { $0.id == offerId }) else {
            throw MarketplaceError.offerNotFound
        }
        
        switch action {
        case .accept:
            mockOffers[index].status = .accepted
        case .decline:
            mockOffers[index].status = .declined
        case .withdraw:
            mockOffers[index].status = .withdrawn
        }
        
        mockOffers[index].updatedAt = Date()
    }
    
    // MARK: - Reservations & Delivery
    
    public func createReservation(listingId: String, details: ReservationDetails) async throws -> Reservation {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let reservation = Reservation(
            id: UUID().uuidString,
            listingId: listingId,
            buyerId: "current_user",
            status: .pending,
            meetup: details.meetup,
            delivery: details.delivery,
            createdAt: Date(),
            completedAt: nil
        )
        
        mockReservations.append(reservation)
        
        return reservation
    }
    
    public func completeReservation(reservationId: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = mockReservations.firstIndex(where: { $0.id == reservationId }) else {
            throw MarketplaceError.reservationNotFound
        }
        
        mockReservations[index].status = .completed
        mockReservations[index].completedAt = Date()
    }
    
    // MARK: - Alerts (AI Watchers)
    
    public func createAlert(criteria: AlertCriteria) async throws -> Alert {
        try await Task.sleep(nanoseconds: 400_000_000)
        
        let alert = Alert(
            id: UUID().uuidString,
            userId: "current_user",
            queryDSL: criteria.query,
            cityId: criteria.cityId,
            neighborhoods: criteria.neighborhoods,
            priceRange: criteria.priceRange,
            categories: criteria.categories.map { $0.rawValue },
            createdAt: Date(),
            isActive: true
        )
        
        mockAlerts.append(alert)
        
        return alert
    }
    
    public func listMyAlerts() async throws -> [Alert] {
        try await Task.sleep(nanoseconds: 200_000_000)
        
        return mockAlerts.filter { $0.userId == "current_user" && $0.isActive }
    }
}

// MARK: - Mock Data Generation

private extension MockMarketplaceService {
    
    func generateMockData() {
        generateMockListings()
        generateMockConversations()
    }
    
    func generateMockListings() {
        let categories = ["electronics", "apparel", "furniture", "car_parts", "books", "sports", "toys", "jewelry"]
        let conditions = [ItemCondition.new.rawValue, ItemCondition.likeNew.rawValue, ItemCondition.good.rawValue, ItemCondition.fair.rawValue]
        let arrondissements = ["Maarif", "Gautier", "Racine", "Bourgogne", "Anfa", "Palmier", "Hay Hassani", "Sidi Belyout"]
        
        let listings = [
            ("iPhone 13 Pro Max 128GB", "Excellent condition iPhone 13 Pro Max, barely used. Original box and accessories included.", "electronics", 450000),
            ("Vintage Leather Jacket", "Beautiful vintage leather jacket from the 80s. Size M. Perfect for collectors.", "clothing", 120000),
            ("IKEA Study Desk", "White IKEA study desk in great condition. Perfect for students or home office.", "furniture", 80000),
            ("Canon EOS R5 Camera", "Professional camera with 2 lenses. Used for wedding photography. Excellent condition.", "electronics", 2800000),
            ("Nike Air Jordan 1", "Authentic Nike Air Jordan 1 in original colorway. Size 42. With original box.", "clothing", 180000),
            ("Apartment Sofa Set", "3-piece sofa set in excellent condition. Light gray color, very comfortable.", "furniture", 350000),
            ("MacBook Pro M1", "13-inch MacBook Pro with M1 chip. 512GB storage, 16GB RAM. Like new condition.", "electronics", 1200000),
            ("Vintage Watch Collection", "Collection of 5 vintage watches from various Swiss brands. Great investment.", "jewelry", 650000),
        ]
        
        mockListings = listings.enumerated().map { index, listing in
            Listing(
                id: "listing_\(index + 1)",
                cityId: "casablanca",
                neighborhoodId: nil,
                title: listing.0,
                description: listing.1,
                category: ListingCategory(rawValue: listing.2) ?? .other,
                condition: ItemCondition(rawValue: conditions.randomElement()!) ?? .good,
                price: Money(amount: listing.3, currency: "MAD"),
                images: generateMockImages(),
                thumbnails: generateMockThumbnails(),
                sellerId: "seller_\(index + 1)",
                status: .active,
                createdAt: Date().addingTimeInterval(-TimeInterval.random(in: 0...604800)), // Random within last week
                updatedAt: Date().addingTimeInterval(-TimeInterval.random(in: 0...86400)),   // Random within last day
                location: Listing.Location(
                    lat: 33.5731 + Double.random(in: -0.1...0.1),
                    lng: -7.5898 + Double.random(in: -0.1...0.1),
                    addressLine: nil,
                    arrondissement: arrondissements.randomElement()!
                ),
                deliveryOptions: Listing.DeliveryOptions(
                    meetup: true,
                    courier: Bool.random()
                ),
                attributes: [:],
                embedding: nil,
                moderation: Listing.ModerationInfo(status: .approved, reasons: [])
            )
        }
    }
    
    func generateMockConversations() {
        // Generate a few mock conversations for demo
        for i in 1...3 {
            let conversation = Conversation(
                id: "conversation_\(i)",
                participants: ["current_user", "seller_\(i)"],
                listingId: "listing_\(i)",
                lastMessageAt: Date().addingTimeInterval(-TimeInterval.random(in: 0...86400)),
                unreadCount: ["current_user": Int.random(in: 0...3), "seller_\(i)": 0]
            )
            
            mockConversations.append(conversation)
        }
    }
    
    func generateMockImages() -> [String] {
        let imageUrls = [
            "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400",
            "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400",
            "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400"
        ]
        
        let count = Int.random(in: 1...3)
        return Array(imageUrls.shuffled().prefix(count))
    }
    
    func generateMockThumbnails() -> [String] {
        return generateMockImages().map { $0 + "&h=150&w=150" }
    }
    
    func generateCompletionCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
    
    func enhanceTitle(_ title: String) -> String {
        // Simulate AI enhancement
        let enhancements = [
            "✨ \(title)",
            "\(title) - Excellent Deal!",
            "🔥 \(title) - Must See!",
            title // Sometimes no enhancement
        ]
        
        return enhancements.randomElement()!
    }
    
    func enhanceDescription(_ description: String) -> String {
        // Simulate AI enhancement
        let additions = [
            "\n\n📍 Available for viewing in Casablanca",
            "\n\n💬 Feel free to negotiate - reasonable offers considered",
            "\n\n⚡ Quick sale needed - price negotiable",
            "" // Sometimes no enhancement
        ]
        
        return description + (additions.randomElement()!)
    }
    
    func generateAutoResponse(to message: String) -> String {
        let responses = [
            "Hi! Thanks for your interest. Yes, the item is still available.",
            "Hello! The item is in excellent condition. Would you like to see more photos?",
            "Hi there! I'm available for a meetup this weekend if you're interested.",
            "Thanks for reaching out! The price is negotiable. What did you have in mind?",
            "Hello! Yes, this is still available. When would you like to meet?"
        ]
        
        return responses.randomElement()!
    }
}

// MARK: - Mock Errors

public enum MarketplaceError: Error, LocalizedError {
    case listingNotFound
    case offerNotFound
    case reservationNotFound
    case conversationNotFound
    case unauthorized
    case notAuthenticated
    case invalidResponse
    case uploadFailed
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .listingNotFound:
            return "Listing not found"
        case .offerNotFound:
            return "Offer not found"
        case .reservationNotFound:
            return "Reservation not found"
        case .conversationNotFound:
            return "Conversation not found"
        case .unauthorized:
            return "Not authorized to perform this action"
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidResponse:
            return "Invalid response from server"
        case .uploadFailed:
            return "Failed to upload image"
        case .networkError:
            return "Network connection error"
        }
    }
}