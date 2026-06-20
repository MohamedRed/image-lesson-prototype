import Foundation
import Combine

/// Main service protocol for Marketplace feature per Appendix A of implementation-plan.md
public protocol MarketplaceServicing {
    // MARK: - Discovery & Search
    
    /// List listings nearby in a city
    func listNearby(in cityId: String, center: Coordinates, radiusKm: Double?) async throws -> [Listing]
    
    /// Search listings with query and filters
    func search(query: String, filters: SearchFilters) async throws -> [Listing]
    
    /// Get a specific listing by ID
    func getListing(id: String) async throws -> Listing?
    
    // MARK: - Listing Management
    
    /// Create a new listing with AI assistance
    func createListing(draft: ListingDraft) async throws -> Listing
    
    /// Update an existing listing
    func updateListing(id: String, updates: ListingUpdate) async throws -> Listing
    
    /// Mark a listing as reserved
    func markReserved(id: String, buyerId: String?) async throws
    
    /// Mark a listing as sold
    func markSold(id: String) async throws
    
    // MARK: - Chat & Offers
    
    /// Open a conversation with a user about a listing
    func openConversation(with userId: String, listingId: String) async throws -> Conversation
    
    /// Send a message in a conversation
    func sendMessage(conversationId: String, message: MessageDraft) async throws
    
    /// Make an offer on a listing
    func makeOffer(listingId: String, amount: Money) async throws -> Offer
    
    /// Respond to an offer (accept/decline/withdraw)
    func respondToOffer(offerId: String, action: OfferAction) async throws
    
    // MARK: - Reservations & Delivery
    
    /// Create a reservation for a listing
    func createReservation(listingId: String, details: ReservationDetails) async throws -> Reservation
    
    /// Complete a reservation
    func completeReservation(reservationId: String) async throws
    
    // MARK: - Alerts (AI Watchers)
    
    /// Create an alert for matching listings
    func createAlert(criteria: AlertCriteria) async throws -> Alert
    
    /// List user's active alerts
    func listMyAlerts() async throws -> [Alert]
    
    // MARK: - Real-time Updates
    
    /// Publisher for listing updates
    var listingUpdates: AnyPublisher<Listing, Never> { get }
    
    /// Publisher for conversation/message updates
    var conversationUpdates: AnyPublisher<Message, Never> { get }
}

// MARK: - AI Service Protocols per Appendix B

/// Marketplace AI assistant protocol
public protocol MarketplaceAI {
    /// Answer a natural language query with context
    func answer(_ query: String, context: RecContext) async throws -> AIResponse
    
    /// Create a watcher/alert for specific criteria
    func createWatcher(criteria: AlertCriteria) async throws -> Alert
    
    /// Get negotiation suggestions for a listing
    func suggestNegotiation(listingId: String, targetPrice: Money?) async throws -> NegotiationSuggestion
    
    /// Invoke a category-specific plugin (Try Lab)
    func invokePlugin(category: String, action: String, input: PluginInput) async throws -> PluginOutput
}

/// Parent AI client for cross-app trait access
public protocol ParentAIClient {
    /// Request user traits with specific scopes (requires consent)
    func requestUserTraits(scopes: [TraitScope]) async throws -> (traits: UserTraits, consentId: String)
}