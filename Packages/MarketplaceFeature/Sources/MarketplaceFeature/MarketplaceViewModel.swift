import Foundation
import SwiftUI
import Combine
import MarketplaceService

/// Main view model for Marketplace feature
@MainActor
public final class MarketplaceViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var discoveryListings: [Listing] = []
    @Published var myListings: [Listing] = []
    @Published var conversations: [Conversation] = []
    @Published var alerts: [MarketplaceService.Alert] = []
    @Published var currentUser: MarketplaceUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Stats for profile
    @Published var totalViews = 0
    @Published var totalSaves = 0
    @Published var totalMessages = 0
    
    // Badge counts
    @Published var unreadMessageCount = 0
    @Published var activeAlertCount = 0
    
    // MARK: - Private Properties
    
    private let service: MarketplaceServicing
    private let searchClient = SearchIndexClient()
    private let pricingEngine = PricingSuggestionEngine()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(service: MarketplaceServicing) {
        self.service = service
        setupSubscriptions()
    }
    
    // MARK: - Setup
    
    private func setupSubscriptions() {
        // Subscribe to listing updates
        service.listingUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] listing in
                self?.handleListingUpdate(listing)
            }
            .store(in: &cancellables)
        
        // Subscribe to message updates
        service.conversationUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleMessageUpdate(message)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods - Discovery
    
    public func startListening(cityId: String) {
        Task {
            await loadDiscoveryListings(cityId: cityId)
            await loadMyListings()
            await loadAlerts()
            await loadConversations()
        }
    }
    
    public func loadDiscoveryListings(cityId: String, neighborhood: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Use search client for personalized discovery
            let filters = SearchFilters(
                cityId: cityId,
                neighborhoods: neighborhood.map { [$0] }
            )
            
            if let user = currentUser {
                // Get personalized recommendations
                let userTraits = UserTraits(
                    userId: user.id ?? "",
                    traits: UserTraits.Traits(
                        carModel: nil,
                        clothingSizes: nil,
                        stylePreferences: user.preferences?.categories,
                        diySkillLevel: nil
                    ),
                    updatedAt: Date(),
                    provenance: UserTraits.Provenance(
                        app: "marketplace",
                        scope: "discovery",
                        consentId: ""
                    )
                )
                
                let recommendations = try await searchClient.getRecommendations(
                    userId: user.id ?? "",
                    cityId: cityId,
                    userTraits: userTraits,
                    limit: 50
                )
                
                discoveryListings = recommendations.map { $0.listing }
            } else {
                // Default discovery
                let center = getDefaultCityCenter(cityId: cityId)
                discoveryListings = try await service.listNearby(
                    in: cityId,
                    center: center,
                    radiusKm: 10
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func searchListings(
        query: String,
        cityId: String,
        category: ListingCategory? = nil,
        neighborhood: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let filters = SearchFilters(
                cityId: cityId,
                neighborhoods: neighborhood.map { [$0] },
                categories: category.map { [$0] }
            )
            
            discoveryListings = try await service.search(query: query, filters: filters)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func performAISearch(query: String, cityId: String) async {
        // This would call the AI search endpoint
        // For now, perform regular search
        await searchListings(query: query, cityId: cityId)
    }
    
    // MARK: - Public Methods - Listings
    
    public func loadMyListings() async {
        // Implementation would load user's own listings
        // For demo, using mock data
    }
    
    public func createListing(_ draft: ListingDraft) async throws -> Listing {
        isLoading = true
        defer { isLoading = false }
        
        let listing = try await service.createListing(draft: draft)
        myListings.append(listing)
        return listing
    }
    
    public func updateListing(_ id: String, updates: ListingUpdate) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let updated = try await service.updateListing(id: id, updates: updates)
        
        if let index = myListings.firstIndex(where: { $0.id == id }) {
            myListings[index] = updated
        }
    }
    
    public func markListingReserved(_ id: String, buyerId: String?) async throws {
        try await service.markReserved(id: id, buyerId: buyerId)
    }
    
    public func markListingSold(_ id: String) async throws {
        try await service.markSold(id: id)
    }
    
    // MARK: - Public Methods - Chat & Offers
    
    public func loadConversations() async {
        // Implementation would load user's conversations
        // Updates come through real-time subscriptions
    }
    
    public func openConversation(with userId: String, listingId: String) async throws -> Conversation {
        let conversation = try await service.openConversation(with: userId, listingId: listingId)
        
        if !conversations.contains(where: { $0.id == conversation.id }) {
            conversations.append(conversation)
        }
        
        return conversation
    }
    
    public func sendMessage(conversationId: String, text: String) async throws {
        let draft = MessageDraft(type: .text, content: text)
        try await service.sendMessage(conversationId: conversationId, message: draft)
    }
    
    public func makeOffer(listingId: String, amount: Money) async throws -> Offer {
        return try await service.makeOffer(listingId: listingId, amount: amount)
    }
    
    public func respondToOffer(_ offerId: String, action: OfferAction) async throws {
        try await service.respondToOffer(offerId: offerId, action: action)
    }
    
    // MARK: - Public Methods - Reservations
    
    public func createReservation(listingId: String, details: ReservationDetails) async throws -> Reservation {
        return try await service.createReservation(listingId: listingId, details: details)
    }
    
    public func completeReservation(_ reservationId: String) async throws {
        try await service.completeReservation(reservationId: reservationId)
    }
    
    // MARK: - Public Methods - Alerts
    
    public func loadAlerts() async {
        do {
            alerts = try await service.listMyAlerts()
            activeAlertCount = alerts.filter { $0.isActive }.count
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func createAlert(_ criteria: AlertCriteria) async throws {
        let alert = try await service.createAlert(criteria: criteria)
        alerts.append(alert)
        activeAlertCount = alerts.filter { $0.isActive }.count
    }
    
    public func deleteAlert(_ alert: MarketplaceService.Alert) async {
        // Implementation would delete alert
        alerts.removeAll { $0.id == alert.id }
        activeAlertCount = alerts.filter { $0.isActive }.count
    }
    
    // MARK: - Public Methods - Pricing
    
    public func suggestPrice(
        for category: ListingCategory,
        condition: ItemCondition,
        title: String,
        description: String,
        cityId: String
    ) async throws -> PricingSuggestion {
        return try await pricingEngine.suggestPrice(
            for: category,
            condition: condition,
            title: title,
            description: description,
            attributes: [:],
            cityId: cityId
        )
    }
    
    // MARK: - Private Methods
    
    private func handleListingUpdate(_ listing: Listing) {
        // Update listing in appropriate array
        if let index = myListings.firstIndex(where: { $0.id == listing.id }) {
            myListings[index] = listing
        }
        
        if let index = discoveryListings.firstIndex(where: { $0.id == listing.id }) {
            discoveryListings[index] = listing
        }
    }
    
    private func handleMessageUpdate(_ message: Message) {
        // Update unread count
        unreadMessageCount += 1
        totalMessages += 1
    }
    
    private func getDefaultCityCenter(cityId: String) -> Coordinates {
        switch cityId {
        case "casablanca":
            return Coordinates(latitude: 33.5731, longitude: -7.5898)
        case "rabat":
            return Coordinates(latitude: 34.0209, longitude: -6.8416)
        default:
            return Coordinates(latitude: 33.5731, longitude: -7.5898)
        }
    }
}