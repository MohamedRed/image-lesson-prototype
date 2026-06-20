import Foundation
import SwiftUI
import Combine
import FoodDeliveryService

/// Main view model for the food delivery feature
@MainActor
public class FoodDeliveryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var restaurants: [Restaurant] = []
    @Published public var featuredRestaurants: [Restaurant] = []
    @Published public var cartItems: [Order.OrderItem] = []
    @Published public var selectedRestaurant: Restaurant?
    @Published public var menuItems: [MenuItem] = []
    @Published public var currentOrder: Order?
    @Published public var orderHistory: [Order] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var searchQuery = ""
    @Published public var selectedCuisine: String?
    @Published public var deliveryAddress: Order.OrderAddresses.DeliveryAddress?
    @Published public var currentLocation: Coordinates?
    
    // Cart state
    @Published public var cartTotal: Double = 0
    @Published public var cartItemCount: Int = 0
    @Published public var deliveryFee: Double = 0
    @Published public var serviceFee: Double = 0
    @Published public var estimatedDeliveryTime: Int = 30
    
    // Order tracking
    @Published public var trackingOrder: Order?
    @Published public var courierLocation: Courier.CourierLocation?
    
    // User mode
    @Published public var userMode: UserMode = .customer
    
    public enum UserMode {
        case customer
        case merchant
        case courier
    }
    
    // MARK: - Private Properties
    public let service: FoodDeliveryServicing // Made public for access in views
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(service: FoodDeliveryServicing) {
        self.service = service
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    /// Load nearby restaurants
    public func loadNearbyRestaurants(location: Coordinates? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let searchLocation = location ?? currentLocation ?? Coordinates(latitude: 33.5731, longitude: -7.5898) // Default to Casablanca
            let restaurants = try await service.listRestaurants(near: searchLocation, radiusKm: 10.0)
            
            await MainActor.run {
                self.restaurants = restaurants.filter { $0.isOpen }
                self.featuredRestaurants = Array(restaurants.prefix(5))
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Search restaurants
    public func searchRestaurants(_ query: String) async {
        guard !query.isEmpty else {
            await loadNearbyRestaurants()
            return
        }
        
        isLoading = true
        
        do {
            let searchLocation = currentLocation ?? Coordinates(latitude: 33.5731, longitude: -7.5898)
            let results = try await service.searchRestaurants(query: query, near: searchLocation, radiusKm: 15.0)
            
            await MainActor.run {
                self.restaurants = results
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Load restaurants by cuisine
    public func loadRestaurantsByCuisine(_ cuisine: String) async {
        isLoading = true
        
        do {
            let searchLocation = currentLocation ?? Coordinates(latitude: 33.5731, longitude: -7.5898)
            let results = try await service.getRestaurantsByCuisine(cuisine, near: searchLocation, radiusKm: 15.0)
            
            await MainActor.run {
                self.restaurants = results
                self.selectedCuisine = cuisine
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Load menu for selected restaurant
    public func loadMenu(for restaurant: Restaurant) async {
        selectedRestaurant = restaurant
        isLoading = true
        
        do {
            let menu = try await service.getMenu(restaurantId: restaurant.id!)
            
            await MainActor.run {
                self.menuItems = menu.filter { $0.isAvailable }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Add item to cart
    public func addToCart(item: MenuItem, selectedOptions: [Order.OrderItem.SelectedOption] = [], quantity: Int = 1, specialInstructions: String? = nil) {
        let totalOptionsPrice = selectedOptions.reduce(0) { $0 + $1.priceDelta }
        let totalPrice = (item.price + totalOptionsPrice) * Double(quantity)
        
        let orderItem = Order.OrderItem(
            menuItemId: item.id!,
            title: item.title,
            basePrice: item.price,
            quantity: quantity,
            selectedOptions: selectedOptions,
            totalPrice: totalPrice,
            specialInstructions: specialInstructions
        )
        
        // Check if item with same options already exists
        if let existingIndex = cartItems.firstIndex(where: { 
            $0.menuItemId == orderItem.menuItemId && 
            $0.selectedOptions == orderItem.selectedOptions 
        }) {
            cartItems[existingIndex].quantity += quantity
            cartItems[existingIndex].totalPrice += totalPrice
        } else {
            cartItems.append(orderItem)
        }
        
        updateCartTotals()
    }
    
    /// Remove item from cart
    public func removeFromCart(itemId: String) {
        cartItems.removeAll { $0.id == itemId }
        updateCartTotals()
    }
    
    /// Update cart item quantity
    public func updateCartItemQuantity(itemId: String, quantity: Int) {
        guard let index = cartItems.firstIndex(where: { $0.id == itemId }) else { return }
        
        if quantity <= 0 {
            cartItems.remove(at: index)
        } else {
            let item = cartItems[index]
            let pricePerUnit = item.totalPrice / Double(item.quantity)
            cartItems[index].quantity = quantity
            cartItems[index].totalPrice = pricePerUnit * Double(quantity)
        }
        
        updateCartTotals()
    }
    
    /// Clear cart
    public func clearCart() {
        cartItems.removeAll()
        updateCartTotals()
    }
    
    /// Checkout - create order
    public func checkout(deliveryAddress: Order.OrderAddresses.DeliveryAddress, paymentMethod: Order.PaymentInfo.PaymentMethod, tip: Double = 0) async -> Bool {
        guard let restaurant = selectedRestaurant,
              !cartItems.isEmpty else {
            errorMessage = "No items in cart"
            return false
        }
        
        isLoading = true
        
        do {
            // Create order draft
            let orderDraft = OrderDraft(
                restaurantId: restaurant.id!,
                items: cartItems,
                deliveryAddress: deliveryAddress,
                paymentMethod: paymentMethod,
                tip: tip
            )
            
            // Price the order
            let pricedOrder = try await service.priceOrder(draft: orderDraft)
            
            // Create the order
            let order = try await service.createOrder(pricedOrder, paymentMethod: paymentMethod)
            
            await MainActor.run {
                self.currentOrder = order
                self.clearCart()
                self.isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
    
    /// Load order history
    public func loadOrderHistory() async {
        isLoading = true
        
        do {
            let orders = try await service.listMyOrders()
            
            await MainActor.run {
                self.orderHistory = orders.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Start tracking an order
    public func startTracking(orderId: String) async {
        do {
            let order = try await service.getOrder(id: orderId)
            
            await MainActor.run {
                self.trackingOrder = order
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Cancel an order
    public func cancelOrder(orderId: String, reason: String) async -> Bool {
        isLoading = true
        
        do {
            try await service.cancelOrder(id: orderId, reason: reason)
            
            // Refresh order history
            await loadOrderHistory()
            
            await MainActor.run {
                self.isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
    
    /// Reorder from previous order
    public func reorder(orderId: String) async -> Bool {
        isLoading = true
        
        do {
            let orderDraft = try await service.reorder(orderId: orderId)
            
            // Load the restaurant for this order
            if let restaurant = try await service.getRestaurant(id: orderDraft.restaurantId) {
                await MainActor.run {
                    self.selectedRestaurant = restaurant
                    self.cartItems = orderDraft.items
                    self.updateCartTotals()
                    self.isLoading = false
                }
                
                return true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
        
        return false
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Listen for real-time order updates
        service.orderUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] order in
                if self?.trackingOrder?.id == order.id {
                    self?.trackingOrder = order
                }
                
                if self?.currentOrder?.id == order.id {
                    self?.currentOrder = order
                }
            }
            .store(in: &cancellables)
        
        // Listen for courier location updates
        service.courierLocationUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.courierLocation = location
            }
            .store(in: &cancellables)
        
        // Auto-update cart totals when cart changes
        $cartItems
            .sink { [weak self] _ in
                self?.updateCartTotals()
            }
            .store(in: &cancellables)
    }
    
    private func updateCartTotals() {
        cartTotal = cartItems.reduce(0) { $0 + $1.totalPrice }
        cartItemCount = cartItems.reduce(0) { $0 + $1.quantity }
        
        // Estimate delivery fee and service fee
        if let restaurant = selectedRestaurant {
            deliveryFee = restaurant.deliveryFeePolicy.baseMAD + (restaurant.deliveryFeePolicy.perKmMAD * 2.0) // Assuming 2km distance
            serviceFee = cartTotal * 0.03 // 3% service fee
        }
    }
}