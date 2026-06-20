import Foundation
import Combine

/// Mock implementation of FoodDeliveryServicing for testing and development
public class MockFoodDeliveryService: FoodDeliveryServicing {
    
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
    
    // MARK: - Mock Data Storage
    private var restaurants: [Restaurant] = []
    private var menuItems: [MenuItem] = []
    private var orders: [Order] = []
    private var customers: [Customer] = []
    private var couriers: [Courier] = []
    private var deliveryTrackings: [String: DeliveryTracking] = [:]
    private var courierLocations: [String: CourierLocation] = [:]
    private var trackingSubscriptions: [String: PassthroughSubject<DeliveryTracking, Never>] = [:]
    
    // Notification service
    private let notificationService = NotificationService()
    
    public init() {
        setupMockData()
    }
    
    private func setupMockData() {
        // Mock Restaurants
        restaurants = [
            Restaurant(
                id: "rest1",
                name: "Pizza Palace",
                logoUrl: nil,
                cuisineTags: ["Italian", "Pizza"],
                rating: 4.5,
                isOpen: true,
                phone: "+212 522 123 456",
                address: Restaurant.Address(city: "Casablanca", arrondissement: "Maarif", street: "Boulevard Zerktouni 123"),
                coordinates: Coordinates(latitude: 33.5731, longitude: -7.5898),
                openingHours: [
                    "monday": [Restaurant.TimeRange(start: "11:00", end: "23:00")],
                    "tuesday": [Restaurant.TimeRange(start: "11:00", end: "23:00")],
                    "wednesday": [Restaurant.TimeRange(start: "11:00", end: "23:00")],
                    "thursday": [Restaurant.TimeRange(start: "11:00", end: "23:00")],
                    "friday": [Restaurant.TimeRange(start: "11:00", end: "24:00")],
                    "saturday": [Restaurant.TimeRange(start: "11:00", end: "24:00")],
                    "sunday": [Restaurant.TimeRange(start: "12:00", end: "23:00")]
                ],
                avgPrepMinutes: 25,
                deliveryZones: ["Maarif", "Centre Ville", "Ain Sebaa"],
                deliveryFeePolicy: Restaurant.DeliveryFeePolicy(baseMAD: 12, perKmMAD: 3, minimumOrderMAD: 50, smallOrderFeeMAD: 5)
            ),
            
            Restaurant(
                id: "rest2",
                name: "Burger Station",
                logoUrl: nil,
                cuisineTags: ["American", "Burgers", "Fast Food"],
                rating: 4.2,
                isOpen: true,
                phone: "+212 522 789 012",
                address: Restaurant.Address(city: "Casablanca", arrondissement: "Centre Ville", street: "Rue Mohammed V 45"),
                coordinates: Coordinates(latitude: 33.5925, longitude: -7.6206),
                avgPrepMinutes: 15,
                deliveryZones: ["Centre Ville", "Maarif", "Racine"],
                deliveryFeePolicy: Restaurant.DeliveryFeePolicy(baseMAD: 10, perKmMAD: 2.5, minimumOrderMAD: 40, smallOrderFeeMAD: 4)
            ),
            
            Restaurant(
                id: "rest3",
                name: "Sushi Zen",
                logoUrl: nil,
                cuisineTags: ["Japanese", "Sushi", "Asian"],
                rating: 4.7,
                isOpen: false,
                phone: "+212 522 345 678",
                address: Restaurant.Address(city: "Casablanca", arrondissement: "Anfa", street: "Boulevard de la Corniche 78"),
                coordinates: Coordinates(latitude: 33.5859, longitude: -7.6302),
                avgPrepMinutes: 35,
                deliveryZones: ["Anfa", "Centre Ville", "Maarif"],
                deliveryFeePolicy: Restaurant.DeliveryFeePolicy(baseMAD: 15, perKmMAD: 4, minimumOrderMAD: 80, smallOrderFeeMAD: 8)
            ),
            
            Restaurant(
                id: "rest4",
                name: "Tagine Traditionnel",
                logoUrl: nil,
                cuisineTags: ["Moroccan", "Traditional", "Halal"],
                rating: 4.3,
                isOpen: true,
                phone: "+212 522 901 234",
                address: Restaurant.Address(city: "Casablanca", arrondissement: "Medina", street: "Derb Ghallef 12"),
                coordinates: Coordinates(latitude: 33.5939, longitude: -7.6151),
                avgPrepMinutes: 30,
                deliveryZones: ["Medina", "Centre Ville", "Habous"],
                deliveryFeePolicy: Restaurant.DeliveryFeePolicy(baseMAD: 8, perKmMAD: 2, minimumOrderMAD: 60, smallOrderFeeMAD: 6)
            ),
            
            Restaurant(
                id: "rest5",
                name: "Healthy Bowls",
                logoUrl: nil,
                cuisineTags: ["Healthy", "Vegetarian", "Salads"],
                rating: 4.4,
                isOpen: true,
                phone: "+212 522 567 890",
                address: Restaurant.Address(city: "Casablanca", arrondissement: "Ain Diab", street: "Boulevard de l'Océan 90"),
                coordinates: Coordinates(latitude: 33.5764, longitude: -7.6807),
                avgPrepMinutes: 20,
                deliveryZones: ["Ain Diab", "Anfa", "Centre Ville"],
                deliveryFeePolicy: Restaurant.DeliveryFeePolicy(baseMAD: 11, perKmMAD: 3.5, minimumOrderMAD: 45, smallOrderFeeMAD: 5)
            )
        ]
        
        // Mock Menu Items for Pizza Palace
        menuItems = [
            MenuItem(
                id: "item1",
                restaurantId: "rest1",
                category: "pizzas",
                title: "Margherita Pizza",
                description: "Fresh tomatoes, mozzarella, basil, and olive oil on our signature dough",
                price: 85,
                options: [
                    MenuItem.MenuItemOption(
                        name: "Size",
                        type: .single,
                        choices: [
                            MenuItem.OptionChoice(name: "Small", priceDelta: 0, isDefault: true),
                            MenuItem.OptionChoice(name: "Medium", priceDelta: 15),
                            MenuItem.OptionChoice(name: "Large", priceDelta: 25)
                        ],
                        isRequired: true
                    ),
                    MenuItem.MenuItemOption(
                        name: "Extra Toppings",
                        type: .multiple,
                        choices: [
                            MenuItem.OptionChoice(name: "Extra Cheese", priceDelta: 10),
                            MenuItem.OptionChoice(name: "Olives", priceDelta: 8),
                            MenuItem.OptionChoice(name: "Mushrooms", priceDelta: 8)
                        ],
                        maxSelections: 3
                    )
                ],
                calories: 250,
                primaryIngredients: ["tomatoes", "mozzarella", "basil"],
                dietaryTags: ["vegetarian"]
            ),
            
            MenuItem(
                id: "item2",
                restaurantId: "rest1",
                category: "pizzas",
                title: "Pepperoni Pizza",
                description: "Spicy pepperoni, mozzarella cheese, and tomato sauce",
                price: 95,
                options: [
                    MenuItem.MenuItemOption(
                        name: "Size",
                        type: .single,
                        choices: [
                            MenuItem.OptionChoice(name: "Small", priceDelta: 0, isDefault: true),
                            MenuItem.OptionChoice(name: "Medium", priceDelta: 15),
                            MenuItem.OptionChoice(name: "Large", priceDelta: 25)
                        ],
                        isRequired: true
                    )
                ],
                calories: 320,
                primaryIngredients: ["pepperoni", "mozzarella", "tomato sauce"]
            ),
            
            MenuItem(
                id: "item3",
                restaurantId: "rest1",
                category: "appetizers",
                title: "Garlic Bread",
                description: "Crispy bread with garlic butter and herbs",
                price: 35,
                calories: 180,
                primaryIngredients: ["bread", "garlic", "butter"],
                dietaryTags: ["vegetarian"]
            ),
            
            MenuItem(
                id: "item4",
                restaurantId: "rest1",
                category: "desserts",
                title: "Tiramisu",
                description: "Classic Italian dessert with coffee and mascarpone",
                price: 45,
                calories: 240,
                primaryIngredients: ["mascarpone", "coffee", "cocoa"],
                dietaryTags: ["vegetarian"]
            )
        ]
    }
    
    // MARK: - Discovery
    public func listRestaurants(near: Coordinates, radiusKm: Double?) async throws -> [Restaurant] {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        return restaurants
    }
    
    public func getRestaurant(id: String) async throws -> Restaurant? {
        return restaurants.first { $0.id == id }
    }
    
    public func getMenu(restaurantId: String) async throws -> [MenuItem] {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
        return menuItems.filter { $0.restaurantId == restaurantId }
    }
    
    public func searchRestaurants(query: String, near: Coordinates, radiusKm: Double?) async throws -> [Restaurant] {
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 second delay
        return restaurants.filter { restaurant in
            restaurant.name.lowercased().contains(query.lowercased()) ||
            restaurant.cuisineTags.contains { $0.lowercased().contains(query.lowercased()) }
        }
    }
    
    public func getRestaurantsByCuisine(_ cuisine: String, near: Coordinates, radiusKm: Double?) async throws -> [Restaurant] {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
        return restaurants.filter { $0.cuisineTags.contains { $0.lowercased() == cuisine.lowercased() } }
    }
    
    // MARK: - Cart & Pricing
    public func priceOrder(draft: OrderDraft) async throws -> PricedOrder {
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 second delay
        
        guard let restaurant = restaurants.first(where: { $0.id == draft.restaurantId }) else {
            throw FoodDeliveryError.restaurantNotFound
        }
        
        let subtotal = draft.items.reduce(0) { $0 + $1.totalPrice }
        let deliveryFee = restaurant.deliveryFeePolicy.baseMAD + (restaurant.deliveryFeePolicy.perKmMAD * 2.0)
        let serviceFee = subtotal * 0.03 // 3%
        let smallOrderFee = subtotal < (restaurant.deliveryFeePolicy.minimumOrderMAD ?? 0) ? 
            (restaurant.deliveryFeePolicy.smallOrderFeeMAD ?? 0) : 0
        let total = subtotal + deliveryFee + serviceFee + smallOrderFee + draft.tip
        
        return PricedOrder(
            draft: draft,
            subtotal: subtotal,
            deliveryFee: deliveryFee,
            serviceFee: serviceFee,
            smallOrderFee: smallOrderFee,
            total: total,
            etaMinutes: restaurant.avgPrepMinutes + 15
        )
    }
    
    public func applyPromotion(code: String, to draft: OrderDraft) async throws -> PricedOrder {
        let pricedOrder = try await priceOrder(draft: draft)
        // Mock promotion logic - 10% off for "SAVE10"
        if code.uppercased() == "SAVE10" {
            let discount = pricedOrder.subtotal * 0.1
            var updated = pricedOrder
            updated.discount = discount
            updated.total = pricedOrder.total - discount
            return updated
        }
        return pricedOrder
    }
    
    public func validateDeliveryAddress(_ address: Order.OrderAddresses.DeliveryAddress, for restaurantId: String) async throws -> Bool {
        return true // Mock: always valid
    }
    
    public func estimateDeliveryTime(from restaurant: Restaurant, to address: Order.OrderAddresses.DeliveryAddress) async throws -> Int {
        return restaurant.avgPrepMinutes + 15
    }
    
    // MARK: - Orders
    public func createOrder(_ order: PricedOrder, paymentMethod: Order.PaymentInfo.PaymentMethod) async throws -> Order {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        guard let restaurant = restaurants.first(where: { $0.id == order.draft.restaurantId }) else {
            throw FoodDeliveryError.restaurantNotFound
        }
        
        let newOrder = Order(
            id: "order_\(UUID().uuidString.prefix(8))",
            customerId: "customer1",
            restaurantId: restaurant.id!,
            status: .created,
            items: order.draft.items,
            subtotal: order.subtotal,
            deliveryFee: order.deliveryFee,
            serviceFee: order.serviceFee,
            tip: order.draft.tip,
            total: order.total,
            payment: Order.PaymentInfo(method: paymentMethod, status: .authorized),
            addresses: Order.OrderAddresses(
                pickup: restaurant.address,
                dropoff: order.draft.deliveryAddress
            )
        )
        
        orders.append(newOrder)
        
        // Create initial delivery tracking
        let initialTracking = DeliveryTracking(
            orderId: newOrder.id ?? UUID().uuidString,
            customerId: newOrder.customerId,
            courierId: nil,
            status: .orderPlaced,
            progressValue: 0.1,
            currentLocation: nil,
            route: nil,
            estimatedArrival: nil,
            estimatedDeliveryTime: Date().addingTimeInterval(TimeInterval(order.etaMinutes * 60)),
            actualPickupTime: nil,
            actualDeliveryTime: nil,
            deliveryProof: nil,
            customerUpdates: [
                CustomerUpdate(
                    id: UUID().uuidString,
                    orderId: (newOrder.id ?? "order_tmp"),
                    message: "Order placed successfully",
                    timestamp: Date(),
                    type: .statusUpdate,
                    estimatedTime: Date().addingTimeInterval(TimeInterval(order.etaMinutes * 60))
                )
            ],
            metrics: TrackingMetrics(
                totalActiveDeliveries: 0,
                averageDeliveryTime: TimeInterval(order.etaMinutes * 60),
                onTimeDeliveryRate: 0.9,
                customerSatisfactionScore: 4.5,
                averageDistanceAccuracy: 0.95,
                routeEfficiencyScore: 0.8,
                lastUpdated: Date()
            ),
            lastUpdated: Date()
        )
        
        deliveryTrackings[(newOrder.id ?? initialTracking.orderId)] = initialTracking
        trackingSubject.send(initialTracking)
        
        // Send order placed notification to customer
        Task {
            try await notificationService.sendNotification(
                to: newOrder.customerId,
                event: .orderPlaced,
                data: [
                    "orderId": newOrder.id,
                    "total": String(format: "%.0f", newOrder.total),
                    "estimatedTime": "\(order.etaMinutes) minutes"
                ],
                priority: .normal
            )
        }
        
        // Send new order notification to merchant
        Task {
            try await notificationService.sendNotification(
                to: "merchant_\(restaurant.id!)",
                event: .merchantNewOrder,
                data: [
                    "orderId": newOrder.id,
                    "total": String(format: "%.0f", newOrder.total),
                    "itemCount": String(newOrder.items.count)
                ],
                priority: .high
            )
        }
        
        // Simulate order status progression
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if let index = orders.firstIndex(where: { $0.id == newOrder.id }) {
                orders[index].status = .restaurantAccepted
                orderSubject.send(orders[index])
                
                // Send order accepted notification
                try await notificationService.sendNotification(
                    to: newOrder.customerId,
                    event: .orderAccepted,
                    data: [
                        "orderId": newOrder.id ?? "order_tmp",
                        "prepTime": "25"
                    ],
                    priority: .normal
                )
                
                // Update tracking
                try await updateDeliveryStatus(
                    orderId: newOrder.id ?? "order_tmp",
                    status: .restaurantConfirmed,
                    location: restaurant.coordinates,
                    proof: nil
                )
            }
        }
        
        return newOrder
    }
    
    public func getOrder(id: String) async throws -> Order? {
        return orders.first { $0.id == id }
    }
    
    public func listMyOrders() async throws -> [Order] {
        return orders.filter { $0.customerId == "customer1" }
    }
    
    public func cancelOrder(id: String, reason: String) async throws {
        if let index = orders.firstIndex(where: { $0.id == id }) {
            orders[index].status = .cancelledByCustomer
            orders[index].cancellation = Order.OrderCancellation(by: .customer, reasonCode: reason)
            orderSubject.send(orders[index])
        }
    }
    
    public func reorder(orderId: String) async throws -> OrderDraft {
        guard let order = orders.first(where: { $0.id == orderId }) else {
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
        return nil // Mock: no profile initially
    }
    
    public func updateCustomerProfile(_ customer: Customer) async throws -> Customer {
        return customer
    }
    
    public func addSavedAddress(_ address: Customer.SavedAddress) async throws {
        // Mock implementation
    }
    
    public func removeSavedAddress(id: String) async throws {
        // Mock implementation
    }
    
    public func updateTasteProfile(_ profile: Customer.TasteProfile) async throws {
        // Mock implementation
    }
    
    // MARK: - Merchant Operations
    public func getMerchantOrders(restaurantId: String) async throws -> [Order] {
        return orders.filter { $0.restaurantId == restaurantId }
    }
    
    public func acceptOrder(id: String, prepTimeMinutes: Int) async throws {
        if let index = orders.firstIndex(where: { $0.id == id }) {
            orders[index].status = .restaurantAccepted
            orderSubject.send(orders[index])
        }
    }
    
    public func markOrderReady(id: String) async throws {
        if let index = orders.firstIndex(where: { $0.id == id }) {
            orders[index].status = .readyForPickup
            orderSubject.send(orders[index])
            
            // Send order ready notification
            Task {
                try await notificationService.sendNotification(
                    to: orders[index].customerId,
                    event: .orderReady,
                    data: [
                        "orderId": id
                    ],
                    priority: .normal
                )
            }
        }
    }
    
    public func updateMenuItemAvailability(itemId: String, isAvailable: Bool) async throws {
        if let index = menuItems.firstIndex(where: { $0.id == itemId }) {
            menuItems[index].isAvailable = isAvailable
        }
    }
    
    public func pauseRestaurant(restaurantId: String, pauseMinutes: Int?) async throws {
        if let index = restaurants.firstIndex(where: { $0.id == restaurantId }) {
            restaurants[index].isOpen = false
            restaurantStatusSubject.send(restaurants[index])
        }
    }
    
    public func resumeRestaurant(restaurantId: String) async throws {
        if let index = restaurants.firstIndex(where: { $0.id == restaurantId }) {
            restaurants[index].isOpen = true
            restaurantStatusSubject.send(restaurants[index])
        }
    }
    
    // MARK: - Courier Operations
    public func getCourierProfile() async throws -> Courier? {
        return nil
    }
    
    public func updateCourierProfile(_ courier: Courier) async throws -> Courier {
        return courier
    }
    
    public func goOnline() async throws {
        // Mock implementation
    }
    
    public func goOffline() async throws {
        // Mock implementation
    }
    
    public func getAvailableOrders() async throws -> [Order] {
        return orders.filter { $0.status == .readyForPickup && $0.courierId == nil }
    }
    
    public func acceptCourierOrder(id: String) async throws {
        if let index = orders.firstIndex(where: { $0.id == id }) {
            orders[index].courierId = "courier1"
            orders[index].status = .pickedUp
            orderSubject.send(orders[index])
            
            // Send courier assigned notification
            Task {
                try await notificationService.sendNotification(
                    to: orders[index].customerId,
                    event: .courierAssigned,
                    data: [
                        "orderId": id,
                        "courierName": "Courier 1"
                    ],
                    priority: .normal
                )
            }
        }
    }
    
    public func declineCourierOrder(id: String, reason: String) async throws {
        // Mock implementation
    }
    
    public func confirmPickup(orderId: String) async throws {
        if let index = orders.firstIndex(where: { $0.id == orderId }) {
            orders[index].status = .pickedUp
            orderSubject.send(orders[index])
        }
    }
    
    public func confirmDelivery(orderId: String, proofImageUrl: String?) async throws {
        if let index = orders.firstIndex(where: { $0.id == orderId }) {
            orders[index].status = .delivered
            if let proofUrl = proofImageUrl {
                orders[index].tracking?.handoffProofUrl = proofUrl
            }
            orderSubject.send(orders[index])
            
            // Send delivery confirmation notification
            Task {
                try await notificationService.sendNotification(
                    to: orders[index].customerId,
                    event: .orderDelivered,
                    data: [
                        "orderId": orderId,
                        "total": String(format: "%.0f", orders[index].total)
                    ],
                    priority: .normal
                )
            }
        }
    }
    
    public func updateLocation(_ location: Courier.CourierLocation) async throws {
        courierLocationSubject.send(location)
    }
    
    // MARK: - Recommendations
    public func getPersonalizedFeed(context: RecContext) async throws -> [Restaurant] {
        return Array(restaurants.prefix(3))
    }
    
    public func getRecommendedItems(restaurantId: String, context: RecContext) async throws -> [MenuItem] {
        return Array(menuItems.filter { $0.restaurantId == restaurantId }.prefix(3))
    }
    
    public func getTrendingItems(context: RecContext) async throws -> [MenuItem] {
        // Return random popular items across all restaurants
        return Array(menuItems.shuffled().prefix(8))
    }
    
    public func getSimilarRestaurants(to restaurantId: String, context: RecContext) async throws -> [Restaurant] {
        // Return restaurants with similar cuisines
        guard let targetRestaurant = restaurants.first(where: { $0.id == restaurantId }) else {
            return []
        }
        
        return restaurants.filter { restaurant in
            restaurant.id != restaurantId &&
            !Set(restaurant.cuisineTags).isDisjoint(with: Set(targetRestaurant.cuisineTags))
        }
    }
    
    public func getSmartSuggestions(context: RecContext) async throws -> SmartSuggestions {
        return SmartSuggestions(
            suggestedRestaurants: Array(restaurants.prefix(6)),
            reorderSuggestions: Array(restaurants.suffix(3)),
            newCuisineSuggestions: Array(restaurants.filter { $0.cuisineTags.contains("international") }),
            trending: Array(menuItems.shuffled().prefix(8))
        )
    }
    
    public func logInteraction(type: InteractionType, entityId: String, entityType: EntityType, context: RecContext?) async throws {
        // Mock implementation
    }
    
    // MARK: - Promotions
    public func getActivePromotions() async throws -> [Promotion] {
        return [
            Promotion(
                id: "promo1",
                title: "Weekend Special",
                description: "20% off all orders this weekend",
                type: .discount,
                discount: Promotion.DiscountInfo(type: .percentage, value: 20, maxDiscount: 50),
                validity: Promotion.PromotionValidity(
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                )
            ),
            Promotion(
                id: "promo2",
                title: "Free Delivery Friday",
                description: "Free delivery on orders over MAD 100",
                type: .freeDelivery,
                discount: Promotion.DiscountInfo(type: .fixedAmount, value: 15, freeDelivery: true, applyTo: .deliveryFee),
                conditions: Promotion.PromotionConditions(minimumOrderValue: 100),
                validity: Promotion.PromotionValidity(
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
                )
            )
        ]
    }
    
    public func validateCoupon(code: String, customerId: String) async throws -> PromotionValidationResult {
        let validCodes = ["WELCOME2024", "FREEDEL", "SAVE20"]
        
        if validCodes.contains(code.uppercased()) {
            return PromotionValidationResult(
                isValid: true,
                discountAmount: 15.0,
                message: "Coupon applied successfully!"
            )
        } else {
            return PromotionValidationResult(
                isValid: false,
                message: "Invalid coupon code",
                errors: [.promotionNotFound]
            )
        }
    }
    
    // MARK: - Dispatch Operations
    public func dispatchOrder(_ request: DispatchRequest) async throws -> DispatchResult {
        // Simulate dispatch algorithm processing
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        return DispatchResult(
            orderId: request.orderId,
            assignedCourierId: "courier\(Int.random(in: 1...10))",
            confidence: Double.random(in: 0.7...0.95),
            estimatedPickupTime: Date().addingTimeInterval(TimeInterval.random(in: 300...1200)),
            estimatedDeliveryTime: Date().addingTimeInterval(TimeInterval.random(in: 1800...3600)),
            routeDistance: Double.random(in: 2.0...12.0),
            routeDuration: TimeInterval.random(in: 600...2400),
            reason: "Optimally assigned based on proximity and availability",
            alternatives: [
                DispatchResult.CourierAlternative(
                    courierId: "courier\(Int.random(in: 11...20))",
                    score: Double.random(in: 0.5...0.8),
                    estimatedDeliveryTime: Date().addingTimeInterval(TimeInterval.random(in: 2400...4200)),
                    reason: "Alternative with slightly longer delivery time"
                )
            ]
        )
    }
    
    public func getZonePerformance() async throws -> [ZonePerformance] {
        return [
            ZonePerformance(
                zoneId: "casa_center",
                zoneName: "Casablanca Center",
                activeCouriers: Int.random(in: 8...15),
                pendingOrders: Int.random(in: 5...25),
                averageWaitTime: TimeInterval.random(in: 180...600),
                demandLevel: .normal,
                surgeMultiplier: 1.0
            ),
            ZonePerformance(
                zoneId: "casa_maarif",
                zoneName: "Maarif",
                activeCouriers: Int.random(in: 12...20),
                pendingOrders: Int.random(in: 15...35),
                averageWaitTime: TimeInterval.random(in: 300...900),
                demandLevel: .high,
                surgeMultiplier: 1.3
            ),
            ZonePerformance(
                zoneId: "casa_anfa",
                zoneName: "Anfa",
                activeCouriers: Int.random(in: 6...12),
                pendingOrders: Int.random(in: 2...12),
                averageWaitTime: TimeInterval.random(in: 120...300),
                demandLevel: .low,
                surgeMultiplier: 1.0
            ),
            ZonePerformance(
                zoneId: "casa_hay_hassani",
                zoneName: "Hay Hassani",
                activeCouriers: Int.random(in: 4...8),
                pendingOrders: Int.random(in: 8...20),
                averageWaitTime: TimeInterval.random(in: 600...1200),
                demandLevel: .critical,
                surgeMultiplier: 1.6
            )
        ]
    }
    
    public func getDispatchMetrics() async throws -> DispatchMetrics {
        return DispatchMetrics(
            averageAssignmentTime: TimeInterval.random(in: 120...300),
            courierUtilization: Double.random(in: 0.6...0.9),
            averageDeliveryTime: TimeInterval.random(in: 1500...2400),
            customerSatisfactionScore: Double.random(in: 4.2...4.8),
            peakHourEfficiency: Double.random(in: 0.75...0.95),
            geographicCoverage: Double.random(in: 0.85...0.95),
            orderAcceptanceRate: Double.random(in: 0.85...0.95),
            multiOrderOptimization: Double.random(in: 0.65...0.85)
        )
    }
    
    // MARK: - Admin/Operations
    public func reportIssue(orderId: String, issue: OrderIssue) async throws {
        // Mock implementation
    }
    
    public func requestRefund(orderId: String, reason: String, amount: Double?) async throws {
        // Mock implementation
    }

    // MARK: - KYC
    public func submitCourierKyc(documents: [String]) async throws {
        // Accept and no-op in mock
    }
    public func submitRestaurantKyc(restaurantId: String, documents: [String]) async throws {
        // Update restaurant mock
        if let index = restaurants.firstIndex(where: { $0.id == restaurantId }) {
            var r = restaurants[index]
            r.kyc.status = .pending
            r.kyc.documents = documents
            restaurants[index] = r
        }
    }

    public func getMerchantOnboardingLink(restaurantId: String) async throws -> URL {
        return URL(string: "https://onboarding.example/merchant/")!
    }

    public func refreshMerchantConnectStatus(restaurantId: String) async throws -> String {
        return "pending"
    }

    public func getCourierOnboardingLink() async throws -> URL {
        return URL(string: "https://onboarding.example/courier/")!
    }

    public func refreshCourierConnectStatus() async throws -> String {
        return "pending"
    }
    
    // MARK: - Real-time Tracking
    public func startLocationTracking(courierId: String) async throws {
        // Create initial courier location
        let location = CourierLocation(
            courierId: courierId,
            location: Coordinates(latitude: 33.5731, longitude: -7.5898),
            heading: 0,
            speed: 0,
            accuracy: 5.0,
            timestamp: Date(),
            batteryLevel: 85.0,
            isOnline: true,
            currentOrderIds: []
        )
        
        courierLocations[courierId] = location
        courierLocationStreamSubject.send(location)
        
        // Start simulating location updates
        simulateLocationUpdates(for: courierId)
    }
    
    public func stopLocationTracking(courierId: String) async throws {
        if var location = courierLocations[courierId] {
            location.isOnline = false
            location.timestamp = Date()
            courierLocations[courierId] = location
            courierLocationStreamSubject.send(location)
        }
    }
    
    public func updateCourierLocation(_ location: CourierLocation) async throws {
        courierLocations[location.courierId] = location
        courierLocationStreamSubject.send(location)
    }
    
    public func getDeliveryTracking(orderId: String) async throws -> DeliveryTracking? {
        return deliveryTrackings[orderId]
    }
    
    public func updateDeliveryStatus(orderId: String, status: DeliveryTracking.DeliveryStatus, location: Coordinates?, proof: DeliveryProof?) async throws {
        if var tracking = deliveryTrackings[orderId] {
            tracking.status = status
            tracking.lastUpdated = Date()
            tracking.progressValue = getProgressValue(for: status)
            tracking.currentLocation = location
            
            if let proof = proof {
                tracking.deliveryProof = proof
            }
            
            // Add customer update
            let update = CustomerUpdate(
                id: UUID().uuidString,
                orderId: orderId,
                message: getStatusMessage(for: status),
                timestamp: Date(),
                type: .statusUpdate,
                estimatedTime: tracking.estimatedDeliveryTime
            )
            tracking.customerUpdates.append(update)
            
            deliveryTrackings[orderId] = tracking
            trackingSubject.send(tracking)
            
            // Notify specific order subscribers
            trackingSubscriptions[orderId]?.send(tracking)
        }
    }
    
    public func subscribeToOrderTracking(orderId: String) -> AnyPublisher<DeliveryTracking, Never> {
        if let existingSubject = trackingSubscriptions[orderId] {
            return existingSubject.eraseToAnyPublisher()
        }
        
        let subject = PassthroughSubject<DeliveryTracking, Never>()
        trackingSubscriptions[orderId] = subject
        
        // Send initial tracking if available
        if let tracking = deliveryTrackings[orderId] {
            subject.send(tracking)
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    public func addCustomerUpdate(orderId: String, update: CustomerUpdate) async throws {
        if var tracking = deliveryTrackings[orderId] {
            tracking.customerUpdates.append(update)
            tracking.lastUpdated = Date()
            deliveryTrackings[orderId] = tracking
            trackingSubject.send(tracking)
            trackingSubscriptions[orderId]?.send(tracking)
        }
    }
    
    public func createGeofenceEvent(orderId: String, event: GeofenceEvent) async throws {
        // Handle geofence events (e.g., courier approaching, arrived at restaurant/customer)
        guard let tracking = deliveryTrackings[orderId] else { return }
        
        let update = CustomerUpdate(
            id: UUID().uuidString,
            orderId: orderId,
            message: getGeofenceMessage(for: event),
            timestamp: Date(),
            type: .locationUpdate,
            estimatedTime: tracking.estimatedDeliveryTime
        )
        
        try await addCustomerUpdate(orderId: orderId, update: update)
    }
    
    // MARK: - Private Tracking Helpers
    private func simulateLocationUpdates(for courierId: String) {
        Task {
            while courierLocations[courierId]?.isOnline == true {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                guard var location = courierLocations[courierId], location.isOnline else { break }
                
                // Simulate movement
                location.location.latitude += Double.random(in: -0.001...0.001)
                location.location.longitude += Double.random(in: -0.001...0.001)
                location.heading = Double.random(in: 0...360)
                location.speed = Double.random(in: 20...50) // km/h
                location.timestamp = Date()
                location.batteryLevel = max(10, location.batteryLevel! - 0.1)
                
                courierLocations[courierId] = location
                courierLocationStreamSubject.send(location)
            }
        }
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
        case .orderDelivered, .delivered: return 1.0
        case .orderCancelled, .cancelled: return 0.0
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
        case .enRouteToCustomer: return "Courier is en route to you"
        case .pickedUp: return "Courier picked up your order"
        case .outForDelivery: return "Your order is on the way"
        case .arrivedAtCustomer: return "Courier has arrived"
        case .orderDelivered, .delivered: return "Order delivered successfully"
        case .orderCancelled, .cancelled: return "Order has been cancelled"
        }
    }
    
    private func getGeofenceMessage(for event: GeofenceEvent) -> String {
        switch event.eventType {
        case .enter:
            return "Entered geofence"
        case .exit:
            return "Exited geofence"
        case .dwell:
            return "Dwelling in geofence"
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
        }
    }
}