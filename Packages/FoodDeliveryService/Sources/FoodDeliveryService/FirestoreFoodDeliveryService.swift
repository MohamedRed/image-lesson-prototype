import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import FirebaseStorage

/// Firestore implementation of FoodDeliveryServicing
public class FirestoreFoodDeliveryService: FoodDeliveryServicing {
    
    // MARK: - Published Data
    private let orderSubject = PassthroughSubject<Order, Never>()
    private let courierLocationSubject = PassthroughSubject<Courier.CourierLocation, Never>()
    private let restaurantStatusSubject = PassthroughSubject<Restaurant, Never>()
    private let trackingSubject = PassthroughSubject<DeliveryTracking, Never>()
    private let courierLocationStreamSubject = PassthroughSubject<CourierLocation, Never>()
    
    public var orderUpdates: AnyPublisher<Order, Never> { orderSubject.eraseToAnyPublisher() }
    public var courierLocationUpdates: AnyPublisher<Courier.CourierLocation, Never> { courierLocationSubject.eraseToAnyPublisher() }
    public var restaurantStatusUpdates: AnyPublisher<Restaurant, Never> { restaurantStatusSubject.eraseToAnyPublisher() }
    public var trackingUpdates: AnyPublisher<DeliveryTracking, Never> { trackingSubject.eraseToAnyPublisher() }
    public var courierLocationStream: AnyPublisher<CourierLocation, Never> { courierLocationStreamSubject.eraseToAnyPublisher() }
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let functions = Functions.functions()
    private let storage = Storage.storage()
    private let pricingEngine = PricingEngine()
    private let aiRecommendationEngine = AIRecommendationEngine()
    private let promotionService = PromotionService()
    private let dispatchAlgorithm: DispatchAlgorithmProtocol = AdvancedDispatchAlgorithm()
    
    private var orderListeners: [String: ListenerRegistration] = [:]
    private var courierListeners: [String: ListenerRegistration] = [:]
    private var trackingListeners: [String: ListenerRegistration] = [:]
    
    public init() {
        setupRealtimeListeners()
    }
    
    deinit {
        // Clean up listeners
        orderListeners.values.forEach { $0.remove() }
        courierListeners.values.forEach { $0.remove() }
    }
    
    // MARK: - Discovery
    public func listRestaurants(near: Coordinates, radiusKm: Double?) async throws -> [Restaurant] {
        let radiusToUse = radiusKm ?? 10.0
        
        // For simplicity, we'll fetch all restaurants and filter by distance
        // In production, use GeoFirestore for efficient geospatial queries
        let snapshot = try await db.collection("restaurants")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        
        let restaurants = try snapshot.documents.compactMap { doc -> Restaurant? in
            try doc.data(as: Restaurant.self)
        }
        
        // Filter by distance
        return restaurants.filter { restaurant in
            let distance = calculateDistance(
                from: near,
                to: restaurant.coordinates
            )
            return distance <= radiusToUse
        }.sorted { $0.rating > $1.rating }
    }
    
    public func getRestaurant(id: String) async throws -> Restaurant? {
        let doc = try await db.collection("restaurants").document(id).getDocument()
        return try doc.data(as: Restaurant.self)
    }
    
    public func getMenu(restaurantId: String) async throws -> [MenuItem] {
        let snapshot = try await db.collection("restaurants")
            .document(restaurantId)
            .collection("menuItems")
            .whereField("isAvailable", isEqualTo: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: MenuItem.self)
        }.sorted { $0.category < $1.category }
    }
    
    public func searchRestaurants(query: String, near: Coordinates, radiusKm: Double?) async throws -> [Restaurant] {
        // Firestore doesn't have full-text search, so we'll use a simple approach
        // In production, consider using Algolia or Elasticsearch
        let allRestaurants = try await listRestaurants(near: near, radiusKm: radiusKm)
        
        let lowercaseQuery = query.lowercased()
        return allRestaurants.filter { restaurant in
            restaurant.name.lowercased().contains(lowercaseQuery) ||
            restaurant.cuisineTags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    public func getRestaurantsByCuisine(_ cuisine: String, near: Coordinates, radiusKm: Double?) async throws -> [Restaurant] {
        let allRestaurants = try await listRestaurants(near: near, radiusKm: radiusKm)
        return allRestaurants.filter { restaurant in
            restaurant.cuisineTags.contains { $0.lowercased() == cuisine.lowercased() }
        }
    }
    
    // MARK: - Cart & Pricing
    public func priceOrder(draft: OrderDraft) async throws -> PricedOrder {
        // Use server-authoritative pricing (with optional promo)
        let payload: [String: Any] = [
            "restaurantId": draft.restaurantId,
            "items": try Firestore.Encoder().encode(draft.items),
            "deliveryAddress": try Firestore.Encoder().encode(draft.deliveryAddress),
            "promoCode": draft.couponCode ?? NSNull()
        ]
        let result = try await functions.httpsCallable("calculatePricing").call(payload)
        guard
            let resultDict = result.data as? [String: Any],
            let pricing = resultDict["pricing"] as? [String: Any],
            let subtotal = pricing["subtotal"] as? Double,
            let deliveryFee = pricing["deliveryFee"] as? Double,
            let serviceFee = pricing["serviceFee"] as? Double,
            let smallOrderFee = pricing["smallOrderFee"] as? Double,
            let total = pricing["total"] as? Double,
            let etaSeconds = pricing["etaSeconds"] as? Int
        else {
            throw FoodDeliveryError.networkError("Invalid pricing response")
        }
        return PricedOrder(
            draft: draft,
            subtotal: subtotal,
            deliveryFee: deliveryFee,
            serviceFee: serviceFee,
            smallOrderFee: smallOrderFee,
            discount: 0,
            total: total,
            etaMinutes: Int(etaSeconds / 60)
        )
    }
    
    public func applyPromotion(code: String, to draft: OrderDraft) async throws -> PricedOrder {
        // Reuse server-authoritative pricing with promoCode
        var draftWithPromo = draft
        draftWithPromo.couponCode = code
        return try await priceOrder(draft: draftWithPromo)
    }
    
    public func validateDeliveryAddress(_ address: Order.OrderAddresses.DeliveryAddress, for restaurantId: String) async throws -> Bool {
        guard let restaurant = try await getRestaurant(id: restaurantId) else {
            throw FoodDeliveryError.restaurantNotFound
        }
        
        let distance = calculateDistance(
            from: restaurant.coordinates,
            to: Coordinates(latitude: address.latitude, longitude: address.longitude)
        )
        
        // Check if address is within delivery zones and reasonable distance (15km max)
        return distance <= 15.0 && (restaurant.deliveryZones.isEmpty || 
                                   restaurant.deliveryZones.contains(address.city))
    }
    
    public func estimateDeliveryTime(from restaurant: Restaurant, to address: Order.OrderAddresses.DeliveryAddress) async throws -> Int {
        let distance = calculateDistance(
            from: restaurant.coordinates,
            to: Coordinates(latitude: address.latitude, longitude: address.longitude)
        )
        
        // Base time + travel time + buffer
        return restaurant.avgPrepMinutes + Int(distance * 3) + 5
    }
    
    // MARK: - Orders
    public func createOrder(_ order: PricedOrder, paymentMethod: Order.PaymentInfo.PaymentMethod) async throws -> Order {
        guard let currentUser = auth.currentUser else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        
        guard let restaurant = try await getRestaurant(id: order.draft.restaurantId) else {
            throw FoodDeliveryError.restaurantNotFound
        }
        
        // Create order object
        let newOrder = Order(
            customerId: currentUser.uid,
            restaurantId: restaurant.id!,
            status: .created,
            items: order.draft.items,
            subtotal: order.subtotal,
            deliveryFee: order.deliveryFee,
            serviceFee: order.serviceFee,
            tip: order.draft.tip,
            total: order.total,
            coupon: nil, // Will be set if promotion was applied
            payment: Order.PaymentInfo(method: paymentMethod, status: .pending),
            addresses: Order.OrderAddresses(
                pickup: restaurant.address,
                dropoff: order.draft.deliveryAddress
            )
        )
        
        // Use Cloud Function for order creation to ensure atomicity and idempotency
        let idempotencyKey = UUID().uuidString
        let data: [String: Any] = [
            "order": try Firestore.Encoder().encode(newOrder),
            "paymentMethod": paymentMethod.rawValue,
            "idempotencyKey": idempotencyKey
        ]

        let result = try await functions.httpsCallable("createOrder").call(data)
        guard let resultData = result.data as? [String: Any],
              let orderDict = resultData["order"] as? [String: Any],
              let orderId = orderDict["id"] as? String else {
            throw FoodDeliveryError.networkError("Invalid response from server")
        }

        // Fetch full order document to ensure latest server state
        guard let createdOrder = try await getOrder(id: orderId) else {
            throw FoodDeliveryError.networkError("Order not found after creation")
        }
        
        // Start listening for updates on this order
        startOrderListener(orderId: createdOrder.id!)
        
        return createdOrder
    }
    
    public func getOrder(id: String) async throws -> Order? {
        let doc = try await db.collection("orders").document(id).getDocument()
        return try doc.data(as: Order.self)
    }
    
    public func listMyOrders() async throws -> [Order] {
        guard let currentUser = auth.currentUser else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        
        let snapshot = try await db.collection("orders")
            .whereField("customerId", isEqualTo: currentUser.uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: Order.self)
        }
    }
    
    public func cancelOrder(id: String, reason: String) async throws {
        let data: [String: Any] = [
            "orderId": id,
            "reason": reason
        ]
        
        try await functions.httpsCallable("cancelOrder").call(data)
    }
    
    public func reorder(orderId: String) async throws -> OrderDraft {
        guard let order = try await getOrder(id: orderId) else {
            throw FoodDeliveryError.orderNotFound
        }
        
        return OrderDraft(
            restaurantId: order.restaurantId,
            items: order.items,
            deliveryAddress: order.addresses.dropoff,
            paymentMethod: order.payment.method,
            tip: order.tip
        )
    }
    
    // MARK: - Customer
    public func getCustomerProfile() async throws -> Customer? {
        guard let currentUser = auth.currentUser else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        
        let doc = try await db.collection("customers").document(currentUser.uid).getDocument()
        return try doc.data(as: Customer.self)
    }
    
    public func updateCustomerProfile(_ customer: Customer) async throws -> Customer {
        guard let currentUser = auth.currentUser else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        
        var updatedCustomer = customer
        updatedCustomer.userId = currentUser.uid
        
        try db.collection("customers").document(currentUser.uid).setData(from: updatedCustomer)
        return updatedCustomer
    }
    
    public func addSavedAddress(_ address: Customer.SavedAddress) async throws {
        guard let currentUser = auth.currentUser else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        
        try await db.collection("customers").document(currentUser.uid).updateData([
            "defaultAddresses": FieldValue.arrayUnion([try Firestore.Encoder().encode(address)])
        ])
    }
    
    public func removeSavedAddress(id: String) async throws {
        guard let currentUser = auth.currentUser else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        
        // This would require a Cloud Function for atomic array manipulation
        let data: [String: Any] = [
            "userId": currentUser.uid,
            "addressId": id
        ]
        
        try await functions.httpsCallable("removeSavedAddress").call(data)
    }
    
    public func updateTasteProfile(_ profile: Customer.TasteProfile) async throws {
        guard let currentUser = auth.currentUser else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        
        try await db.collection("customers").document(currentUser.uid).updateData([
            "tasteProfile": try Firestore.Encoder().encode(profile)
        ])
    }
    
    // MARK: - Merchant Operations
    public func getMerchantOrders(restaurantId: String) async throws -> [Order] {
        let snapshot = try await db.collection("orders")
            .whereField("restaurantId", isEqualTo: restaurantId)
            .whereField("status", in: ["created", "restaurant_accepted", "preparing", "ready_for_pickup"])
            .order(by: "createdAt", descending: false)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: Order.self)
        }
    }
    
    public func acceptOrder(id: String, prepTimeMinutes: Int) async throws {
        let data: [String: Any] = [
            "orderId": id,
            "prepTimeMinutes": prepTimeMinutes
        ]
        
        try await functions.httpsCallable("acceptOrder").call(data)
    }
    
    public func markOrderReady(id: String) async throws {
        let data: [String: Any] = [
            "orderId": id
        ]
        try await functions.httpsCallable("markOrderReady").call(data)
    }
    
    public func updateMenuItemAvailability(itemId: String, isAvailable: Bool) async throws {
        // This would require knowing the restaurant ID, typically passed in or derived from context
        // For now, we'll use a Cloud Function that can handle this
        let data: [String: Any] = [
            "itemId": itemId,
            "isAvailable": isAvailable
        ]
        
        try await functions.httpsCallable("updateMenuItemAvailability").call(data)
    }
    
    public func pauseRestaurant(restaurantId: String, pauseMinutes: Int?) async throws {
        let data: [String: Any] = [
            "pauseMinutes": pauseMinutes ?? NSNull()
        ]
        _ = restaurantId // restaurant inferred from auth on server
        try await functions.httpsCallable("pauseRestaurant").call(data)
    }
    
    public func resumeRestaurant(restaurantId: String) async throws {
        _ = restaurantId
        try await functions.httpsCallable("resumeRestaurant").call([:])
    }
    
    // MARK: - Courier Operations
    public func getCourierProfile() async throws -> Courier? {
        guard let currentUser = auth.currentUser else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        
        let doc = try await db.collection("couriers").document(currentUser.uid).getDocument()
        return try doc.data(as: Courier.self)
    }
    
    public func updateCourierProfile(_ courier: Courier) async throws -> Courier {
        guard let currentUser = auth.currentUser else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        
        var updatedCourier = courier
        updatedCourier.userId = currentUser.uid
        
        try db.collection("couriers").document(currentUser.uid).setData(from: updatedCourier)
        return updatedCourier
    }
    
    public func goOnline() async throws {
        _ = try await Functions.functions().httpsCallable("goOnline").call([:])
    }
    
    public func goOffline() async throws {
        _ = try await Functions.functions().httpsCallable("goOffline").call([:])
    }
    
    public func getAvailableOrders() async throws -> [Order] {
        let result = try await functions.httpsCallable("getAvailableOrders").call([:])
        guard let data = result.data as? [String: Any], let ordersArray = data["orders"] as? [[String: Any]] else {
            return []
        }
        return try ordersArray.map { dict in
            var order = try Firestore.Decoder().decode(Order.self, from: dict)
            if let eta = dict["etaSeconds"] as? Int {
                order.timings.etaSeconds = eta
            } else if let timings = dict["timings"] as? [String: Any], let eta = timings["dispatchEtaSeconds"] as? Int {
                order.timings.etaSeconds = eta
            }
            return order
        }
    }
    
    public func acceptCourierOrder(id: String) async throws {
        guard let currentUser = auth.currentUser else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        
        let data: [String: Any] = [
            "orderId": id,
            "courierId": currentUser.uid
        ]
        
        let result = try await functions.httpsCallable("assignCourier").call(data)
        if let dict = result.data as? [String: Any], let eta = dict["etaSeconds"] as? Int {
            if var order = try await getOrder(id: id) {
                order.timings.etaSeconds = eta
                orderSubject.send(order)
            }
        }
    }
    
    public func declineCourierOrder(id: String, reason: String) async throws {
        // Log the decline for dispatch optimization
        let data: [String: Any] = [
            "orderId": id,
            "reason": reason
        ]
        
        try await functions.httpsCallable("declineCourierOrder").call(data)
    }
    
    public func confirmPickup(orderId: String) async throws {
        let data: [String: Any] = [
            "orderId": orderId
        ]
        try await functions.httpsCallable("confirmPickup").call(data)
    }
    
    public func confirmDelivery(orderId: String, proofImageUrl: String?) async throws {
        let data: [String: Any] = [
            "orderId": orderId,
            "proofImageUrl": proofImageUrl ?? NSNull()
        ]
        try await functions.httpsCallable("confirmDelivery").call(data)
    }
    
    public func updateLocation(_ location: Courier.CourierLocation) async throws {
        guard auth.currentUser != nil else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        let data: [String: Any] = [
            "latitude": location.latitude,
            "longitude": location.longitude
        ]
        try await functions.httpsCallable("updateCourierLocation").call(data)
        // Emit location update for any listening views
        courierLocationSubject.send(location)
    }

    // MARK: - KYC
    public func submitCourierKyc(documents: [String]) async throws {
        guard auth.currentUser != nil else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        _ = try await functions.httpsCallable("submitCourierKyc").call(["documents": documents])
    }

    public func getCourierOnboardingLink() async throws -> URL {
        let result = try await functions.httpsCallable("getCourierOnboardingLink").call([:])
        guard let dict = result.data as? [String: Any], let urlStr = dict["url"] as? String, let url = URL(string: urlStr) else {
            throw FoodDeliveryError.networkError("Invalid response from server")
        }
        return url
    }

    public func refreshCourierConnectStatus() async throws -> String {
        let result = try await functions.httpsCallable("refreshConnectStatus").call(["role": "courier"]) 
        guard let dict = result.data as? [String: Any], let status = dict["status"] as? String else {
            throw FoodDeliveryError.networkError("Invalid response from server")
        }
        return status
    }

    public func submitRestaurantKyc(restaurantId: String, documents: [String]) async throws {
        guard auth.currentUser != nil else {
            throw FoodDeliveryError.networkError("User not authenticated")
        }
        _ = try await functions.httpsCallable("submitRestaurantKyc").call([
            "restaurantId": restaurantId,
            "documents": documents
        ])
    }

    public func getMerchantOnboardingLink(restaurantId: String) async throws -> URL {
        let result = try await functions.httpsCallable("getMerchantOnboardingLink").call(["restaurantId": restaurantId])
        guard let dict = result.data as? [String: Any], let urlStr = dict["url"] as? String, let url = URL(string: urlStr) else {
            throw FoodDeliveryError.networkError("Invalid response from server")
        }
        return url
    }

    public func refreshMerchantConnectStatus(restaurantId: String) async throws -> String {
        let result = try await functions.httpsCallable("refreshConnectStatus").call(["role": "merchant", "restaurantId": restaurantId])
        guard let dict = result.data as? [String: Any], let status = dict["status"] as? String else {
            throw FoodDeliveryError.networkError("Invalid response from server")
        }
        return status
    }
    
    // MARK: - Recommendations
    public func getPersonalizedFeed(context: RecContext) async throws -> [Restaurant] {
        if auth.currentUser == nil {
            let restaurants = try await listRestaurants(near: context.location, radiusKm: 15.0)
            return restaurants.sorted { $0.rating > $1.rating }
        }
        let payload: [String: Any] = [
            "latitude": context.location.latitude,
            "longitude": context.location.longitude,
            "timeOfDay": context.timeOfDay?.rawValue ?? NSNull(),
            "limit": 20
        ]
        let result = try await Functions.functions().httpsCallable("getPersonalizedRecommendations").call(payload)
        guard let dict = result.data as? [String: Any], let recs = dict["recommendations"] as? [[String: Any]] else { return [] }
        return try recs.map { try Firestore.Decoder().decode(Restaurant.self, from: $0) }
    }
    
    public func getRecommendedItems(restaurantId: String, context: RecContext) async throws -> [MenuItem] {
        // For now, reuse trending endpoint filtered by restaurant
        let result = try await Functions.functions().httpsCallable("getTrendingItems").call([
            "restaurantId": restaurantId,
            "timeWindow": "24",
            "limit": 10
        ])
        guard let dict = result.data as? [String: Any], let items = dict["trendingItems"] as? [[String: Any]] else { return [] }
        return try items.map { try Firestore.Decoder().decode(MenuItem.self, from: $0) }
    }
    
    public func logInteraction(type: InteractionType, entityId: String, entityType: EntityType, context: RecContext?) async throws {
        guard auth.currentUser != nil else { return }
        let payload: [String: Any] = [
            "type": type.rawValue,
            "entityId": entityId,
            "entityType": entityType.rawValue,
            "context": context != nil ? (try Firestore.Encoder().encode(context)) : [:]
        ]
        _ = try await Functions.functions().httpsCallable("trackUserInteraction").call(payload)
    }

    // MARK: - Promotions
    public func getActivePromotions() async throws -> [Promotion] {
        try await promotionService.getActivePromotions()
    }
    
    public func validateCoupon(code: String, customerId: String) async throws -> PromotionValidationResult {
        try await promotionService.validateCoupon(code: code, customerId: customerId)
    }

    // MARK: - Dispatch
    public func dispatchOrder(_ request: DispatchRequest) async throws -> DispatchResult {
        try await dispatchAlgorithm.dispatchOrder(request)
    }
    
    public func getZonePerformance() async throws -> [ZonePerformance] {
        try await dispatchAlgorithm.updateZonePerformance()
    }
    
    public func getDispatchMetrics() async throws -> DispatchMetrics {
        try await dispatchAlgorithm.getDispatchMetrics()
    }
    
    /// Get trending menu items across all restaurants
    public func getTrendingItems(context: RecContext) async throws -> [MenuItem] {
        let result = try await Functions.functions().httpsCallable("getTrendingItems").call([
            "timeWindow": "24",
            "limit": 20
        ])
        guard let dict = result.data as? [String: Any], let items = dict["trendingItems"] as? [[String: Any]] else { return [] }
        return try items.map { try Firestore.Decoder().decode(MenuItem.self, from: $0) }
    }
    
    /// Get restaurants similar to the given one
    public func getSimilarRestaurants(to restaurantId: String, context: RecContext) async throws -> [Restaurant] {
        // Placeholder: use personalized feed and filter; real impl would have dedicated endpoint
        return try await getPersonalizedFeed(context: context).filter { $0.id != restaurantId }
    }
    
    /// Get smart suggestions based on user's order history and preferences
    public func getSmartSuggestions(context: RecContext) async throws -> SmartSuggestions {
        if auth.currentUser == nil {
            let restaurants = try await listRestaurants(near: context.location, radiusKm: 10.0)
            let popularRestaurants = Array(restaurants.sorted { $0.rating > $1.rating }.prefix(5))
            return SmartSuggestions(suggestedRestaurants: popularRestaurants, reorderSuggestions: [], newCuisineSuggestions: popularRestaurants, trending: try await getTrendingItems(context: context))
        }
        let result = try await Functions.functions().httpsCallable("getSmartSuggestions").call([:])
        // Minimal mapping: for now return empty SmartSuggestions if shape differs
        if let dict = result.data as? [String: Any], let suggestions = dict["suggestions"] as? [String: Any] {
            // These would require matching models; using a simple fallback for now
            _ = suggestions
        }
        return SmartSuggestions(suggestedRestaurants: [], reorderSuggestions: [], newCuisineSuggestions: [], trending: [])
    }
    
    // MARK: - Admin/Operations
    public func reportIssue(orderId: String, issue: OrderIssue) async throws {
        let issueData: [String: Any] = [
            "orderId": orderId,
            "issue": try Firestore.Encoder().encode(issue),
            "reportedAt": FieldValue.serverTimestamp(),
            "status": "open"
        ]
        
        try await db.collection("issues").addDocument(data: issueData)
    }
    
    public func requestRefund(orderId: String, reason: String, amount: Double?) async throws {
        let data: [String: Any] = [
            "orderId": orderId,
            "reason": reason,
            "amount": amount ?? NSNull()
        ]
        
        try await functions.httpsCallable("requestRefund").call(data)
    }
    
    // MARK: - Private Helper Methods
    
    private func setupRealtimeListeners() {
        // Set up global listeners for real-time updates
        guard let currentUser = auth.currentUser else { return }
        
        // Listen for user's order updates
        db.collection("orders")
            .whereField("customerId", isEqualTo: currentUser.uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documentChanges else { return }
                
                for change in documents {
                    if change.type == .modified {
                        do {
                            let order = try change.document.data(as: Order.self)
                            self?.orderSubject.send(order)
                        } catch {
                            print("Error decoding order update: \(error)")
                        }
                    }
                }
            }
    }
    
    private func startOrderListener(orderId: String) {
        let listener = db.collection("orders").document(orderId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let document = snapshot, document.exists else { return }
                
                do {
                    let order = try document.data(as: Order.self)
                    self?.orderSubject.send(order)
                } catch {
                    print("Error decoding order: \(error)")
                }
            }
        
        orderListeners[orderId] = listener
    }
    
    private func calculateDistance(from: Coordinates, to: Coordinates) -> Double {
        let earthRadius = 6371.0 // Earth's radius in kilometers
        
        let lat1Rad = from.latitude * .pi / 180
        let lat2Rad = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadius * c
    }
    
    private func getCurrentSurgeMultiplier(location: Coordinates, time: Date) async throws -> Double {
        // Query active surge windows
        let snapshot = try await db.collection("surgeWindows")
            .whereField("isActive", isEqualTo: true)
            .whereField("startTime", isLessThanOrEqualTo: time)
            .whereField("endTime", isGreaterThan: time)
            .getDocuments()
        
        // For simplicity, return the highest multiplier found
        var maxMultiplier = 1.0
        for doc in snapshot.documents {
            if let multiplier = doc.data()["multiplier"] as? Double {
                maxMultiplier = max(maxMultiplier, multiplier)
            }
        }
        
        return maxMultiplier
    }
    
    private func personalizeRestaurants(_ restaurants: [Restaurant], tasteProfile: Customer.TasteProfile, context: RecContext) -> [Restaurant] {
        // Simple personalization based on cuisine preferences
        let sortedRestaurants = restaurants.sorted { restaurant1, restaurant2 in
            let score1 = calculateRestaurantScore(restaurant1, tasteProfile: tasteProfile, context: context)
            let score2 = calculateRestaurantScore(restaurant2, tasteProfile: tasteProfile, context: context)
            return score1 > score2
        }
        
        return sortedRestaurants
    }
    
    private func personalizeMenuItems(_ items: [MenuItem], tasteProfile: Customer.TasteProfile, context: RecContext) -> [MenuItem] {
        let sortedItems = items.sorted { item1, item2 in
            let score1 = calculateItemScore(item1, tasteProfile: tasteProfile, context: context)
            let score2 = calculateItemScore(item2, tasteProfile: tasteProfile, context: context)
            return score1 > score2
        }
        
        return Array(sortedItems.prefix(10))
    }
    
    private func calculateRestaurantScore(_ restaurant: Restaurant, tasteProfile: Customer.TasteProfile, context: RecContext) -> Double {
        var score = restaurant.rating / 5.0 // Base score from rating
        
        // Cuisine preference boost
        for cuisine in restaurant.cuisineTags {
            if tasteProfile.likedCuisines.contains(cuisine) {
                score += 0.3
            }
        }
        
        // Price band match
        let avgPrice = 50.0 // Would calculate from menu in real implementation
        let isPriceBandMatch = matchesPriceBand(price: avgPrice, priceBand: tasteProfile.priceBand)
        if isPriceBandMatch {
            score += 0.2
        }
        
        return score
    }
    
    private func calculateItemScore(_ item: MenuItem, tasteProfile: Customer.TasteProfile, context: RecContext) -> Double {
        var score = 0.5 // Base score
        
        // Ingredient preferences
        for ingredient in item.primaryIngredients {
            if tasteProfile.likedIngredients.contains(ingredient) {
                score += 0.3
            }
            if tasteProfile.blockedIngredients.contains(ingredient) {
                score -= 0.5
            }
        }
        
        // Dietary tags match
        for tag in item.dietaryTags {
            if tasteProfile.dietaryTags.contains(tag) {
                score += 0.2
            }
        }
        
        // Price consideration
        let isPriceBandMatch = matchesPriceBand(price: item.price, priceBand: tasteProfile.priceBand)
        if isPriceBandMatch {
            score += 0.1
        }
        
        return score
    }
    
    private func matchesPriceBand(price: Double, priceBand: Customer.TasteProfile.PriceBand) -> Bool {
        switch priceBand {
        case .low:
            return price <= 50
        case .mid:
            return price > 50 && price <= 100
        case .high:
            return price > 100
        }
    }
    
    // MARK: - Real-time Tracking
    public func startLocationTracking(courierId: String) async throws {
        let trackingData: [String: Any] = [
            "courierId": courierId,
            "isTracking": true,
            "startedAt": Timestamp(),
            "lastUpdated": Timestamp()
        ]
        
        try await db.collection("courierTracking").document(courierId).setData(trackingData)
    }
    
    public func stopLocationTracking(courierId: String) async throws {
        let trackingData: [String: Any] = [
            "isTracking": false,
            "stoppedAt": Timestamp(),
            "lastUpdated": Timestamp()
        ]
        
        try await db.collection("courierTracking").document(courierId).updateData(trackingData)
    }
    
    public func updateCourierLocation(_ location: CourierLocation) async throws {
        let data: [String: Any] = [
            "latitude": location.location.latitude,
            "longitude": location.location.longitude
        ]
        try await functions.httpsCallable("updateCourierLocation").call(data)
        // Emit location update
        courierLocationStreamSubject.send(location)
    }
    
    public func getDeliveryTracking(orderId: String) async throws -> DeliveryTracking? {
        let doc = try await db.collection("deliveryTracking").document(orderId).getDocument()
        
        guard let data = doc.data() else { return nil }
        
        return try parseDeliveryTracking(from: data, orderId: orderId)
    }
    
    public func updateDeliveryStatus(orderId: String, status: DeliveryTracking.DeliveryStatus, location: Coordinates?, proof: DeliveryProof?) async throws {
        var body: [String: Any] = ["orderId": orderId, "status": status.rawValue]
        if let location = location { body["location"] = ["latitude": location.latitude, "longitude": location.longitude] }
        if let proof = proof {
            var proofDict: [String: Any] = [
                "verificationMethod": proof.verificationMethod.rawValue
            ]
            if let photoUrl = proof.photoUrl { proofDict["photoUrl"] = photoUrl }
            if let signatureData = proof.signatureData { proofDict["signatureData"] = signatureData }
            if let notes = proof.notes { proofDict["notes"] = notes }
            body["proof"] = proofDict
        }
        _ = try await Functions.functions().httpsCallable("updateDeliveryStatus").call(body)
    }
    
    public func subscribeToOrderTracking(orderId: String) -> AnyPublisher<DeliveryTracking, Never> {
        let subject = PassthroughSubject<DeliveryTracking, Never>()
        
        // Set up Firestore listener
        let listener = db.collection("deliveryTracking").document(orderId)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data(), error == nil else { return }
                
                do {
                    let tracking = try self.parseDeliveryTracking(from: data, orderId: orderId)
                    subject.send(tracking)
                } catch {
                    print("Error parsing tracking update: \(error)")
                }
            }
        
        // Store listener for cleanup
        trackingListeners[orderId] = listener
        
        return subject.eraseToAnyPublisher()
    }
    
    public func addCustomerUpdate(orderId: String, update: CustomerUpdate) async throws {
        let body: [String: Any] = [
            "orderId": orderId,
            "update": [
                "id": update.id,
                "message": update.message,
                "type": update.type.rawValue,
                "estimatedTime": update.estimatedTime?.timeIntervalSince1970 ?? NSNull()
            ]
        ]
        _ = try await Functions.functions().httpsCallable("addCustomerUpdate").call(body)
    }
    
    public func createGeofenceEvent(orderId: String, event: GeofenceEvent) async throws {
        let body: [String: Any] = [
            "orderId": orderId,
            "event": [
                "courierId": event.courierId,
                "eventType": event.eventType.rawValue,
                "location": ["latitude": event.location.latitude, "longitude": event.location.longitude]
            ]
        ]
        _ = try await Functions.functions().httpsCallable("createGeofenceEvent").call(body)
        let update = CustomerUpdate(id: UUID().uuidString, orderId: orderId, message: getGeofenceMessage(for: event), timestamp: Date(), type: .locationUpdate, estimatedTime: nil)
        try await addCustomerUpdate(orderId: orderId, update: update)
    }
    
    // MARK: - Tracking Helper Methods
    private func parseDeliveryTracking(from data: [String: Any], orderId: String) throws -> DeliveryTracking {
        let customerId = data["customerId"] as? String ?? ""
        let courierId = data["courierId"] as? String
        let statusRaw = data["status"] as? String ?? ""
        let status = DeliveryTracking.DeliveryStatus(rawValue: statusRaw) ?? .orderPlaced
        let progressValue = data["progressValue"] as? Double ?? 0.0
        let estimatedDeliveryTime = (data["estimatedDeliveryTime"] as? Timestamp)?.dateValue() ?? Date()
        let lastUpdated = (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
        
        var currentLocation: Coordinates?
        if let locationData = data["currentLocation"] as? [String: Any],
           let lat = locationData["latitude"] as? Double,
           let lng = locationData["longitude"] as? Double {
            currentLocation = Coordinates(latitude: lat, longitude: lng)
        }
        
        // Parse customer updates (would fetch from subcollection in real implementation)
        let customerUpdates: [CustomerUpdate] = []
        
        // Parse delivery proof if available
        var deliveryProof: DeliveryProof?
        if let proofData = data["deliveryProof"] as? [String: Any] {
            deliveryProof = try parseDeliveryProof(from: proofData)
        }
        
        // Create mock metrics
        let metrics = TrackingMetrics(
            totalActiveDeliveries: 0,
            averageDeliveryTime: 1800,
            onTimeDeliveryRate: 0.9,
            customerSatisfactionScore: 4.5,
            averageDistanceAccuracy: 0.95,
            routeEfficiencyScore: 0.8,
            lastUpdated: Date()
        )
        
        return DeliveryTracking(
            orderId: orderId,
            customerId: customerId,
            courierId: courierId,
            status: status,
            progressValue: progressValue,
            currentLocation: currentLocation,
            route: nil,
            estimatedDeliveryTime: estimatedDeliveryTime,
            deliveryProof: deliveryProof,
            customerUpdates: customerUpdates,
            metrics: metrics,
            lastUpdated: lastUpdated
        )
    }
    
    private func parseDeliveryProof(from data: [String: Any]) throws -> DeliveryProof {
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let locationData = data["location"] as? [String: Any] ?? [:]
        let lat = locationData["latitude"] as? Double ?? 0
        let lng = locationData["longitude"] as? Double ?? 0
        let location = Coordinates(latitude: lat, longitude: lng)
        let photoUrl = data["photoUrl"] as? String
        let signatureData = data["signatureData"] as? String
        let notes = data["notes"] as? String
        let methodRaw = data["verificationMethod"] as? String ?? DeliveryProof.VerificationMethod.photo.rawValue
        let method = DeliveryProof.VerificationMethod(rawValue: methodRaw) ?? .photo
        
        return DeliveryProof(
            photoUrl: photoUrl,
            signatureData: signatureData,
            timestamp: timestamp,
            location: location,
            verificationMethod: method,
            notes: notes
        )
    }
    
    private func getProgressValue(for status: DeliveryTracking.DeliveryStatus) -> Double {
        switch status {
        case .orderPlaced: return 0.1
        case .restaurantConfirmed: return 0.2
        case .preparing: return 0.4
        case .readyForPickup: return 0.5
        case .courierAssigned: return 0.6
        case .courierEnRoute, .enRouteToCustomer: return 0.7
        case .pickedUp: return 0.8
        case .outForDelivery, .arrivedAtCustomer: return 0.9
        case .delivered, .orderDelivered: return 1.0
        case .cancelled, .orderCancelled: return 0.0
        }
    }
    
    private func getStatusMessage(for status: DeliveryTracking.DeliveryStatus) -> String {
        switch status {
        case .orderPlaced: return "Order placed successfully"
        case .restaurantConfirmed: return "Restaurant confirmed your order"
        case .preparing: return "Your food is being prepared"
        case .readyForPickup: return "Order is ready for pickup"
        case .courierAssigned: return "Courier assigned to your order"
        case .courierEnRoute: return "Courier is on the way to restaurant"
        case .enRouteToCustomer: return "Courier en route to you"
        case .pickedUp: return "Courier picked up your order"
        case .outForDelivery: return "Your order is on the way"
        case .arrivedAtCustomer: return "Courier arrived at your location"
        case .delivered, .orderDelivered: return "Order delivered successfully"
        case .cancelled, .orderCancelled: return "Order has been cancelled"
        }
    }
    
    private func getGeofenceMessage(for event: GeofenceEvent) -> String {
        switch event.eventType {
        case .restaurantApproaching:
            return "Courier is approaching the restaurant"
        case .restaurantArrived:
            return "Courier has arrived at the restaurant"
        case .restaurantDeparted:
            return "Courier has left the restaurant with your order"
        case .customerApproaching:
            return "Courier is approaching your location"
        case .customerArrived:
            return "Courier has arrived at your location"
        case .deliveryCompleted:
            return "Delivery completed successfully"
        case .enter:
            return "Courier entered geofence"
        case .exit:
            return "Courier exited geofence"
        case .dwell:
            return "Courier dwelling in geofence"
        }
    }
}