import Foundation
import FoodDeliveryService
import Combine
import CoreLocation
import UIKit

/// Updated ViewModel for courier tracking using Radar SDK
@MainActor
public class CourierTrackingViewModel: ObservableObject {
    @Published public var isOnline = false
    @Published public var activeOrders: [Order] = []
    @Published public var availableOrders: [Order] = []
    @Published public var todaysDeliveries = 0
    @Published public var todaysEarnings: Double = 0
    @Published public var rating: Double = 4.8
    @Published public var hoursOnline: Double = 0
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let service: FoodDeliveryServicing
    private let radarService: FoodDeliveryService.FoodDeliveryRadarLocationService
    private var cancellables = Set<AnyCancellable>()
    private var onlineStartTime: Date?
    private var hoursTimer: Timer?
    private var courierId: String = ""
    
    public init(service: FoodDeliveryServicing) {
        self.service = service
        self.radarService = FoodDeliveryService.FoodDeliveryRadarLocationService()
        setupRadarService()
    }
    
    deinit {
        hoursTimer?.invalidate()
    }
    
    public func initialize() async {
        await loadCourierProfile()
        await refreshData()
        setupSubscriptions()
    }
    
    public func refreshData() async {
        isLoading = true
        
        do {
            // Load available orders
            availableOrders = try await service.getAvailableOrders()
            
            // Update daily stats (mock data for now)
            updateDailyStats()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func goOnline() async {
        do {
            try await service.goOnline()
            isOnline = true
            onlineStartTime = Date()
            
            // Start Radar tracking for courier
            radarService.setupCourierTracking(
                courierId: courierId,
                metadata: [
                    "isOnline": true,
                    "rating": rating,
                    "todayDeliveries": todaysDeliveries
                ]
            )
            
            // Start hours tracking
            startHoursTracking()
            
            // Refresh available orders
            await refreshData()
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func goOffline() async {
        do {
            try await service.goOffline()
            isOnline = false
            onlineStartTime = nil
            
            // Stop Radar tracking
            radarService.stopLocationTracking()
            
            // Stop hours tracking
            stopHoursTracking()
            
            // Clear available orders
            availableOrders = []
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func acceptOrder(_ orderId: String) async {
        do {
            try await service.acceptCourierOrder(id: orderId)
            
            // Move order from available to active
            if let orderIndex = availableOrders.firstIndex(where: { $0.id == orderId }) {
                let order = availableOrders.remove(at: orderIndex)
                activeOrders.append(order)
                
                // Start delivery tracking with Radar
                let dropoff = order.addresses.dropoff
                if let restaurant = try? await service.getRestaurant(id: order.restaurantId) {
                    let pickupCoord = CLLocationCoordinate2D(
                        latitude: restaurant.coordinates.latitude,
                        longitude: restaurant.coordinates.longitude
                    )
                    radarService.startDeliveryTracking(
                        orderId: orderId,
                        pickupLocation: pickupCoord,
                        deliveryLocation: CLLocationCoordinate2D(
                            latitude: dropoff.latitude,
                            longitude: dropoff.longitude
                        )
                    )
                }
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func confirmPickup(_ orderId: String) async {
        do {
            try await service.confirmPickup(orderId: orderId)
            
            // Update order status in active orders
            if let index = activeOrders.firstIndex(where: { $0.id == orderId }) {
                activeOrders[index].status = .pickedUp
                
                // Update tracking status with current Radar location
                let location = radarService.currentLocation?.coordinate
                let coordinates = location.map { Coordinates(latitude: $0.latitude, longitude: $0.longitude) }
                
                try await service.updateDeliveryStatus(
                    orderId: orderId,
                    status: .pickedUp,
                    location: coordinates,
                    proof: nil
                )
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func confirmDelivery(_ orderId: String, proofImage: UIImage?, notes: String) async {
        do {
            // Get current location from Radar
            let location = radarService.currentLocation?.coordinate
            let coordinates = location.map { Coordinates(latitude: $0.latitude, longitude: $0.longitude) }
            
            // Create delivery proof
            let proof = coordinates.map { coords in
                DeliveryProof(
                    photoUrl: nil,
                    signatureData: nil,
                    timestamp: Date(),
                    location: coords,
                    verificationMethod: .handoff,
                    notes: notes.isEmpty ? nil : notes
                )
            }
            
            try await service.confirmDelivery(orderId: orderId, proofImageUrl: proof?.photoUrl)
            
            // Update tracking status
            try await service.updateDeliveryStatus(
                orderId: orderId,
                status: .delivered,
                location: coordinates,
                proof: proof
            )
            
            // Complete Radar delivery tracking
            radarService.completeDeliveryTracking(orderId: orderId)
            
            // Remove from active orders
            if let index = activeOrders.firstIndex(where: { $0.id == orderId }) {
                let order = activeOrders.remove(at: index)
                
                // Update daily stats
                todaysDeliveries += 1
                todaysEarnings += calculateDeliveryEarnings(order)
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Private Methods
    
    private func setupRadarService() {
        // Subscribe to Radar location updates
        radarService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                // Handle location updates if needed
                // The Radar service handles automatic tracking
            }
            .store(in: &cancellables)
    }
    
    private func loadCourierProfile() async {
        do {
            if let profile = try await service.getCourierProfile() {
                // Load courier-specific data
                courierId = profile.id ?? ""
                rating = profile.rating
                
                // Request location permission through Radar
                radarService.requestLocationPermission()
            }
        } catch {
            // Handle error silently or show user
            print("Failed to load courier profile: \(error)")
        }
    }
    
    private func startHoursTracking() {
        hoursTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateHoursOnline()
        }
    }
    
    private func stopHoursTracking() {
        hoursTimer?.invalidate()
        hoursTimer = nil
    }
    
    private func updateHoursOnline() {
        guard let startTime = onlineStartTime else { return }
        hoursOnline = Date().timeIntervalSince(startTime) / 3600.0
    }
    
    private func calculateDeliveryEarnings(_ order: Order) -> Double {
        // Mock earnings calculation
        let baseEarning = order.deliveryFee * 0.8 // 80% of delivery fee
        let tipEarning = order.tip
        let bonusEarning = order.total > 200 ? 5.0 : 0.0 // Bonus for large orders
        
        return baseEarning + tipEarning + bonusEarning
    }
    
    private func updateDailyStats() {
        // Mock daily stats - would come from backend
        todaysDeliveries = Int.random(in: 8...15)
        todaysEarnings = Double.random(in: 150...350)
        rating = Double.random(in: 4.6...4.9)
    }
    
    private func setupSubscriptions() {
        // Subscribe to order updates
        service.orderUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] order in
                self?.handleOrderUpdate(order)
            }
            .store(in: &cancellables)
            
        // Subscribe to Radar delivery zone events
        radarService.$deliveryZones
            .sink { [weak self] zones in
                // Handle delivery zone updates
                print("Updated delivery zones: \(zones.count)")
            }
            .store(in: &cancellables)
    }
    
    private func handleOrderUpdate(_ order: Order) {
        // Update active orders list when orders change status
        if let index = activeOrders.firstIndex(where: { $0.id == order.id }) {
            activeOrders[index] = order
            
            // Remove completed orders
            if order.status == .delivered || order.status.rawValue >= Order.OrderStatus.cancelledByCustomer.rawValue {
                activeOrders.remove(at: index)
                
                if order.status == .delivered {
                    todaysDeliveries += 1
                    todaysEarnings += calculateDeliveryEarnings(order)
                    
                    // Complete Radar tracking for this order
                    radarService.completeDeliveryTracking(orderId: order.id ?? "")
                }
            }
        }
    }
}

// MARK: - Mock Data Extension
extension CourierTrackingViewModel {
    func loadMockData() {
        // Mock active orders
        activeOrders = []
        
        // Mock available orders
        availableOrders = []
        
        // Mock stats
        todaysDeliveries = 12
        todaysEarnings = 245.50
        rating = 4.7
        hoursOnline = 6.5
    }
}