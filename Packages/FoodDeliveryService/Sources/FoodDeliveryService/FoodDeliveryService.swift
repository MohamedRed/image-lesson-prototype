import Foundation
import Combine

/// Protocol defining the food delivery service interface
public protocol FoodDeliveryServicing {
    // MARK: - Discovery
    func listRestaurants(near: Coordinates, radiusKm: Double?) async throws -> [Restaurant]
    func getRestaurant(id: String) async throws -> Restaurant?
    func getMenu(restaurantId: String) async throws -> [MenuItem]
    func searchRestaurants(query: String, near: Coordinates, radiusKm: Double?) async throws -> [Restaurant]
    func getRestaurantsByCuisine(_ cuisine: String, near: Coordinates, radiusKm: Double?) async throws -> [Restaurant]
    
    // MARK: - Cart & Pricing
    func priceOrder(draft: OrderDraft) async throws -> PricedOrder
    func applyPromotion(code: String, to draft: OrderDraft) async throws -> PricedOrder
    func validateDeliveryAddress(_ address: Order.OrderAddresses.DeliveryAddress, for restaurantId: String) async throws -> Bool
    func estimateDeliveryTime(from restaurant: Restaurant, to address: Order.OrderAddresses.DeliveryAddress) async throws -> Int
    
    // MARK: - Orders
    func createOrder(_ order: PricedOrder, paymentMethod: Order.PaymentInfo.PaymentMethod) async throws -> Order
    func getOrder(id: String) async throws -> Order?
    func listMyOrders() async throws -> [Order]
    func cancelOrder(id: String, reason: String) async throws
    func reorder(orderId: String) async throws -> OrderDraft
    
    // MARK: - Customer
    func getCustomerProfile() async throws -> Customer?
    func updateCustomerProfile(_ customer: Customer) async throws -> Customer
    func addSavedAddress(_ address: Customer.SavedAddress) async throws
    func removeSavedAddress(id: String) async throws
    func updateTasteProfile(_ profile: Customer.TasteProfile) async throws
    
    // MARK: - Merchant Operations
    func getMerchantOrders(restaurantId: String) async throws -> [Order]
    func acceptOrder(id: String, prepTimeMinutes: Int) async throws
    func markOrderReady(id: String) async throws
    func updateMenuItemAvailability(itemId: String, isAvailable: Bool) async throws
    func pauseRestaurant(restaurantId: String, pauseMinutes: Int?) async throws
    func resumeRestaurant(restaurantId: String) async throws
    // KYC
    func submitRestaurantKyc(restaurantId: String, documents: [String]) async throws
    func getMerchantOnboardingLink(restaurantId: String) async throws -> URL
    func refreshMerchantConnectStatus(restaurantId: String) async throws -> String
    
    // MARK: - Courier Operations
    func getCourierProfile() async throws -> Courier?
    func updateCourierProfile(_ courier: Courier) async throws -> Courier
    func goOnline() async throws
    func goOffline() async throws
    func getAvailableOrders() async throws -> [Order]
    func acceptCourierOrder(id: String) async throws
    func declineCourierOrder(id: String, reason: String) async throws
    func confirmPickup(orderId: String) async throws
    func confirmDelivery(orderId: String, proofImageUrl: String?) async throws
    func updateLocation(_ location: Courier.CourierLocation) async throws
    // KYC
    func submitCourierKyc(documents: [String]) async throws
    func getCourierOnboardingLink() async throws -> URL
    func refreshCourierConnectStatus() async throws -> String
    
    // MARK: - Real-time Updates
    var orderUpdates: AnyPublisher<Order, Never> { get }
    var courierLocationUpdates: AnyPublisher<Courier.CourierLocation, Never> { get }
    var restaurantStatusUpdates: AnyPublisher<Restaurant, Never> { get }
    
    // MARK: - Recommendations (AI-Powered)
    func getPersonalizedFeed(context: RecContext) async throws -> [Restaurant]
    func getRecommendedItems(restaurantId: String, context: RecContext) async throws -> [MenuItem]
    func getTrendingItems(context: RecContext) async throws -> [MenuItem]
    func getSimilarRestaurants(to restaurantId: String, context: RecContext) async throws -> [Restaurant]
    func getSmartSuggestions(context: RecContext) async throws -> SmartSuggestions
    func logInteraction(type: InteractionType, entityId: String, entityType: EntityType, context: RecContext?) async throws
    
    // MARK: - Promotions
    func getActivePromotions() async throws -> [Promotion]
    func validateCoupon(code: String, customerId: String) async throws -> PromotionValidationResult
    
    // MARK: - Dispatch Operations
    func dispatchOrder(_ request: DispatchRequest) async throws -> DispatchResult
    func getZonePerformance() async throws -> [ZonePerformance]
    func getDispatchMetrics() async throws -> DispatchMetrics
    
    // MARK: - Real-time Tracking
    func startLocationTracking(courierId: String) async throws
    func stopLocationTracking(courierId: String) async throws
    func updateCourierLocation(_ location: CourierLocation) async throws
    func getDeliveryTracking(orderId: String) async throws -> DeliveryTracking?
    func updateDeliveryStatus(orderId: String, status: DeliveryTracking.DeliveryStatus, location: Coordinates?, proof: DeliveryProof?) async throws
    func subscribeToOrderTracking(orderId: String) -> AnyPublisher<DeliveryTracking, Never>
    func addCustomerUpdate(orderId: String, update: CustomerUpdate) async throws
    func createGeofenceEvent(orderId: String, event: GeofenceEvent) async throws
    
    // MARK: - Tracking Updates
    var trackingUpdates: AnyPublisher<DeliveryTracking, Never> { get }
    var courierLocationStream: AnyPublisher<CourierLocation, Never> { get }
    
    // MARK: - Admin/Operations
    func reportIssue(orderId: String, issue: OrderIssue) async throws
    func requestRefund(orderId: String, reason: String, amount: Double?) async throws
}

// MARK: - Supporting Types
public enum InteractionType: String, Codable {
    case view
    case click
    case order
    case favorite
    case share
}

public enum EntityType: String, Codable {
    case restaurant
    case menuItem
    case cuisine
}

public struct OrderIssue: Codable {
    public var type: IssueType
    public var description: String
    public var imageUrls: [String]
    
    public enum IssueType: String, Codable {
        case foodQuality
        case lateDelivery
        case wrongOrder
        case missingItems
        case courierBehavior
        case other
    }
    
    public init(type: IssueType, description: String, imageUrls: [String] = []) {
        self.type = type
        self.description = description
        self.imageUrls = imageUrls
    }
}

/// Smart suggestions powered by AI recommendations
public struct SmartSuggestions: Codable {
    public let suggestedRestaurants: [Restaurant]
    public let reorderSuggestions: [Restaurant]
    public let newCuisineSuggestions: [Restaurant]
    public let trending: [MenuItem]
    
    public init(
        suggestedRestaurants: [Restaurant],
        reorderSuggestions: [Restaurant],
        newCuisineSuggestions: [Restaurant],
        trending: [MenuItem]
    ) {
        self.suggestedRestaurants = suggestedRestaurants
        self.reorderSuggestions = reorderSuggestions
        self.newCuisineSuggestions = newCuisineSuggestions
        self.trending = trending
    }
}

// MARK: - Configuration
public struct FoodDeliveryConfig {
    public var environment: Environment
    public var locale: String
    public var currency: String
    public var mapboxAccessToken: String
    public var stripePublishableKey: String
    
    public enum Environment {
        case development
        case staging
        case production
    }
    
    public init(
        environment: Environment,
        locale: String = "fr-MA",
        currency: String = "MAD",
        mapboxAccessToken: String,
        stripePublishableKey: String
    ) {
        self.environment = environment
        self.locale = locale
        self.currency = currency
        self.mapboxAccessToken = mapboxAccessToken
        self.stripePublishableKey = stripePublishableKey
    }
}