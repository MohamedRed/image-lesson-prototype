import Foundation
import FoodDeliveryService
import Combine

/// ViewModel for merchant console management
@MainActor
public class MerchantConsoleViewModel: ObservableObject {
    @Published public var restaurant: Restaurant?
    @Published public var recentOrders: [Order] = []
    @Published public var todaysStats = DailyStats()
    @Published public var menuItems: [MenuItem] = []
    @Published public var unreadNotifications = 0
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    // Analytics data
    @Published public var weeklyRevenue: [DailyRevenue] = []
    @Published public var orderTrends: [OrderTrend] = []
    @Published public var popularItems: [PopularItem] = []
    
    private let restaurantId: String
    private let service: FoodDeliveryServicing
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    public init(restaurantId: String, service: FoodDeliveryServicing) {
        self.restaurantId = restaurantId
        self.service = service
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    public func initialize() async {
        await loadRestaurantData()
        await refreshDashboard()
        setupSubscriptions()
        startAutoRefresh()
    }
    
    public func refreshDashboard() async {
        isLoading = true
        
        do {
            async let ordersTask = loadRecentOrders()
            async let statsTask = loadTodaysStats()
            async let menuTask = loadMenuItems()
            async let analyticsTask = loadAnalyticsData()
            
            await (ordersTask, statsTask, menuTask, analyticsTask)
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func toggleRestaurantStatus() async {
        guard let restaurant = restaurant else { return }
        
        do {
            if restaurant.isOpen {
                try await service.pauseRestaurant(restaurantId: restaurantId, pauseMinutes: nil)
            } else {
                try await service.resumeRestaurant(restaurantId: restaurantId)
            }
            
            // Refresh restaurant data
            await loadRestaurantData()
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func pauseRestaurant(minutes: Int) async {
        do {
            try await service.pauseRestaurant(restaurantId: restaurantId, pauseMinutes: minutes)
            await loadRestaurantData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func handleOrderAction(_ orderId: String, action: OrderAction) async {
        do {
            switch action {
            case .accept(let prepTime):
                try await service.acceptOrder(id: orderId, prepTimeMinutes: prepTime)
            case .markReady:
                try await service.markOrderReady(id: orderId)
            case .viewDetails:
                // Handle view details navigation
                break
            case .cancel(let reason):
                try await service.cancelOrder(id: orderId, reason: reason)
            }
            
            // Refresh orders after action
            await loadRecentOrders()
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func updateMenuItemAvailability(_ itemId: String, isAvailable: Bool) async {
        do {
            try await service.updateMenuItemAvailability(itemId: itemId, isAvailable: isAvailable)
            await loadMenuItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func submitRestaurantKyc(documents: [String]) async {
        guard let restId = restaurant?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.submitRestaurantKyc(restaurantId: restId, documents: documents)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func refreshMerchantKycStatus() async {
        guard let restId = restaurant?.id else { return }
        do {
            _ = try await service.refreshMerchantConnectStatus(restaurantId: restId)
            await loadRestaurantData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func getOnboardingLink() async -> URL? {
        guard let restId = restaurant?.id else { return nil }
        do {
            return try await service.getMerchantOnboardingLink(restaurantId: restId)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func loadRestaurantData() async {
        do {
            restaurant = try await service.getRestaurant(id: restaurantId)
        } catch {
            errorMessage = "Failed to load restaurant data: \(error.localizedDescription)"
        }
    }
    
    private func loadRecentOrders() async {
        do {
            recentOrders = try await service.getMerchantOrders(restaurantId: restaurantId)
                .sorted { $0.timings.createdAt ?? Date.distantPast > $1.timings.createdAt ?? Date.distantPast }
        } catch {
            errorMessage = "Failed to load orders: \(error.localizedDescription)"
        }
    }
    
    private func loadTodaysStats() async {
        // Calculate today's statistics from recent orders
        let today = Calendar.current.startOfDay(for: Date())
        let todaysOrders = recentOrders.filter { order in
            guard let createdAt = order.timings.createdAt else { return false }
            return Calendar.current.isDate(createdAt, inSameDayAs: today)
        }
        
        let totalOrders = todaysOrders.count
        let newOrders = todaysOrders.filter { order in
            guard let createdAt = order.timings.createdAt else { return false }
            return Date().timeIntervalSince(createdAt) < 3600 // Last hour
        }.count
        
        let revenue = todaysOrders.reduce(0) { $0 + $1.total }
        let avgPrepTime = calculateAveragePrepTime(from: todaysOrders)
        let avgRating = calculateAverageRating(from: todaysOrders)
        let acceptanceRate = calculateAcceptanceRate(from: todaysOrders)
        
        todaysStats = DailyStats(
            totalOrders: totalOrders,
            newOrders: newOrders,
            revenue: revenue,
            revenueGrowth: calculateRevenueGrowth(),
            avgPrepTime: avgPrepTime,
            prepTimeChange: 0, // Would calculate from historical data
            avgRating: avgRating,
            totalReviews: todaysOrders.count,
            acceptanceRate: acceptanceRate
        )
    }
    
    private func loadMenuItems() async {
        do {
            menuItems = try await service.getMenu(restaurantId: restaurantId)
        } catch {
            errorMessage = "Failed to load menu: \(error.localizedDescription)"
        }
    }
    
    private func loadAnalyticsData() async {
        // Generate mock analytics data
        // In production, this would come from analytics service
        weeklyRevenue = generateWeeklyRevenue()
        orderTrends = generateOrderTrends()
        popularItems = generatePopularItems()
    }
    
    private func setupSubscriptions() {
        // Subscribe to order updates
        service.orderUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] order in
                guard let self = self else { return }
                
                // Update orders if it's for this restaurant
                if order.restaurantId == self.restaurantId {
                    self.updateOrderInList(order)
                    
                    // Increment notification count for new orders
                    if order.status == .created {
                        self.unreadNotifications += 1
                    }
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to restaurant status updates
        service.restaurantStatusUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] restaurant in
                if restaurant.id == self?.restaurantId {
                    self?.restaurant = restaurant
                }
            }
            .store(in: &cancellables)
    }
    
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshDashboard()
            }
        }
    }
    
    private func updateOrderInList(_ order: Order) {
        if let index = recentOrders.firstIndex(where: { $0.id == order.id }) {
            recentOrders[index] = order
        } else {
            recentOrders.insert(order, at: 0)
        }
        
        // Keep only recent orders (last 50)
        if recentOrders.count > 50 {
            recentOrders = Array(recentOrders.prefix(50))
        }
    }
    
    private func calculateAveragePrepTime(from orders: [Order]) -> Int {
        let prepTimes = orders.compactMap { order -> Int? in
            guard let acceptedAt = order.timings.acceptedAt,
                  let readyAt = order.timings.readyAt else { return nil }
            return Int(readyAt.timeIntervalSince(acceptedAt) / 60)
        }
        
        guard !prepTimes.isEmpty else { return 0 }
        return prepTimes.reduce(0, +) / prepTimes.count
    }
    
    private func calculateAverageRating(from orders: [Order]) -> Double {
        // Mock rating calculation - would come from review system
        return Double.random(in: 4.2...4.8)
    }
    
    private func calculateAcceptanceRate(from orders: [Order]) -> Double {
        let acceptedOrders = orders.filter { $0.status != .cancelledByMerchant }.count
        guard !orders.isEmpty else { return 100.0 }
        return Double(acceptedOrders) / Double(orders.count) * 100.0
    }
    
    private func calculateRevenueGrowth() -> Double {
        // Mock growth calculation - would compare with yesterday
        return Double.random(in: -5.0...15.0)
    }
    
    private func generateWeeklyRevenue() -> [DailyRevenue] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            return DailyRevenue(
                date: date,
                revenue: Double.random(in: 500...2000),
                orders: Int.random(in: 15...50)
            )
        }.reversed()
    }
    
    private func generateOrderTrends() -> [OrderTrend] {
        return (0..<24).map { hour in
            OrderTrend(
                hour: hour,
                orderCount: hour >= 11 && hour <= 14 || hour >= 18 && hour <= 22 
                    ? Int.random(in: 8...25) 
                    : Int.random(in: 0...8)
            )
        }
    }
    
    private func generatePopularItems() -> [PopularItem] {
        return menuItems.prefix(10).enumerated().map { index, item in
            PopularItem(
                menuItem: item,
                orderCount: Int.random(in: 5...30),
                revenue: Double(Int.random(in: 5...30)) * item.price,
                rank: index + 1
            )
        }
    }
}

// MARK: - Supporting Models

public struct DailyStats {
    public var totalOrders: Int = 0
    public var newOrders: Int = 0
    public var revenue: Double = 0
    public var revenueGrowth: Double = 0
    public var avgPrepTime: Int = 0
    public var prepTimeChange: Int = 0
    public var avgRating: Double = 0
    public var totalReviews: Int = 0
    public var acceptanceRate: Double = 100
    
    public init(
        totalOrders: Int = 0,
        newOrders: Int = 0,
        revenue: Double = 0,
        revenueGrowth: Double = 0,
        avgPrepTime: Int = 0,
        prepTimeChange: Int = 0,
        avgRating: Double = 0,
        totalReviews: Int = 0,
        acceptanceRate: Double = 100
    ) {
        self.totalOrders = totalOrders
        self.newOrders = newOrders
        self.revenue = revenue
        self.revenueGrowth = revenueGrowth
        self.avgPrepTime = avgPrepTime
        self.prepTimeChange = prepTimeChange
        self.avgRating = avgRating
        self.totalReviews = totalReviews
        self.acceptanceRate = acceptanceRate
    }
}

public struct DailyRevenue {
    public let date: Date
    public let revenue: Double
    public let orders: Int
    
    public init(date: Date, revenue: Double, orders: Int) {
        self.date = date
        self.revenue = revenue
        self.orders = orders
    }
}

public struct OrderTrend {
    public let hour: Int
    public let orderCount: Int
    
    public init(hour: Int, orderCount: Int) {
        self.hour = hour
        self.orderCount = orderCount
    }
}

public struct PopularItem {
    public let menuItem: MenuItem
    public let orderCount: Int
    public let revenue: Double
    public let rank: Int
    
    public init(menuItem: MenuItem, orderCount: Int, revenue: Double, rank: Int) {
        self.menuItem = menuItem
        self.orderCount = orderCount
        self.revenue = revenue
        self.rank = rank
    }
}

public enum OrderAction {
    case accept(prepTimeMinutes: Int)
    case markReady
    case viewDetails
    case cancel(reason: String)
}