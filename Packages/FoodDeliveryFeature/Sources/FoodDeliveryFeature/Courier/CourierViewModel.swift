import Foundation
import SwiftUI
import Combine
import FoodDeliveryService
import CoreLocation
import UIKit

/// Updated ViewModel for courier operations using Radar SDK
@MainActor
public class CourierViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isOnline = false
    @Published public var currentOrder: Order?
    @Published public var availableOrders: [Order] = []
    @Published public var courierProfile: Courier?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var infoMessage: String?
    
    // Stats
    @Published public var todayDeliveries = 0
    @Published public var todayEarnings: Double = 0
    @Published public var courierRating: Double = 4.8
    @Published public var weeklyEarnings: [Double] = Array(repeating: 0, count: 7)
    
    // Current location from Radar
    @Published public var currentLocation: CLLocation?
    
    // MARK: - Private Properties
    private let service: FoodDeliveryServicing
    private let radarService: FoodDeliveryService.FoodDeliveryRadarLocationService
    private var cancellables = Set<AnyCancellable>()
    private var locationUpdateTimer: Timer?
    private var courierId: String = ""
    
    // MARK: - Initialization
    public init(service: FoodDeliveryServicing) {
        self.service = service
        self.radarService = FoodDeliveryService.FoodDeliveryRadarLocationService()
        setupRadar()
        setupSubscriptions()
    }
    
    deinit {
        locationUpdateTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Initialize the courier dashboard
    public func initialize() async {
        await loadCourierProfile()
        await refreshData()
        
        // Request location permission through Radar
        radarService.requestLocationPermission()
    }
    
    /// Refresh all data
    public func refreshData() async {
        await loadAvailableOrders()
        await loadTodayStats()
    }
    
    /// Toggle online/offline status
    public func toggleOnlineStatus() async {
        isLoading = true
        
        do {
            if isOnline {
                try await service.goOffline()
                isOnline = false
                radarService.stopLocationTracking()
                stopLocationUpdateTimer()
            } else {
                try await service.goOnline()
                isOnline = true
                await loadAvailableOrders()
                
                // Start Radar tracking with courier metadata
                radarService.setupCourierTracking(
                    courierId: courierId,
                    metadata: [
                        "rating": courierRating,
                        "todayDeliveries": todayDeliveries,
                        "vehicleType": courierProfile?.vehicleType.rawValue ?? "bike"
                    ]
                )
                
                // Start location update timer (30 seconds for general tracking)
                startLocationUpdateTimer()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Go online
    public func goOnline() async {
        guard !isOnline else { return }
        await toggleOnlineStatus()
    }
    
    /// Go offline
    public func goOffline() async {
        guard isOnline else { return }
        await toggleOnlineStatus()
    }
    
    /// Accept an order
    public func acceptOrder(orderId: String) async {
        isLoading = true
        
        do {
            try await service.acceptCourierOrder(id: orderId)
            await loadOrderDetails(orderId: orderId)
            await loadAvailableOrders() // Refresh available orders
            // Show ETA toast if available
            if let eta = currentOrder?.timings.etaSeconds {
                let minutes = Int(ceil(Double(eta) / 60.0))
                infoMessage = "Assignment ETA ~\(minutes) min"
            }
            
            // Start delivery tracking with Radar if we have the order details
            if let order = currentOrder {
                let dropoff = order.addresses.dropoff
                var pickupCoord: CLLocationCoordinate2D?
                if let restaurant = try? await service.getRestaurant(id: order.restaurantId) {
                    pickupCoord = CLLocationCoordinate2D(
                        latitude: restaurant.coordinates.latitude,
                        longitude: restaurant.coordinates.longitude
                    )
                }
                if let pickupCoord = pickupCoord {
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
        
        isLoading = false
    }
    
    /// Decline an order
    public func declineOrder(orderId: String, reason: String) async {
        do {
            try await service.declineCourierOrder(id: orderId, reason: reason)
            await loadAvailableOrders() // Refresh available orders
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Load order details
    public func loadOrderDetails(orderId: String) async {
        do {
            let order = try await service.getOrder(id: orderId)
            currentOrder = order
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Confirm pickup
    public func confirmPickup() async {
        guard let orderId = currentOrder?.id else { return }
        
        isLoading = true
        
        do {
            try await service.confirmPickup(orderId: orderId)
            await loadOrderDetails(orderId: orderId)
            
            // Update location tracking status through service
            if let location = radarService.currentLocation?.coordinate {
                let coordinates = Coordinates(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
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
        
        isLoading = false
    }
    
    /// Confirm delivery
    public func confirmDelivery(proofImageUrl: String? = nil) async {
        guard let orderId = currentOrder?.id else { return }
        
        isLoading = true
        
        do {
            // Get current location from Radar for proof
            let location = radarService.currentLocation?.coordinate
            let coordinates = location.map { 
                Coordinates(latitude: $0.latitude, longitude: $0.longitude) 
            }
            
            // Confirm delivery with proof
            try await service.confirmDelivery(orderId: orderId, proofImageUrl: proofImageUrl)
            
            // Update delivery status with location
            if let coords = coordinates {
                try await service.updateDeliveryStatus(
                    orderId: orderId,
                    status: .delivered,
                    location: coords,
                    proof: DeliveryProof(
                        photoUrl: proofImageUrl,
                        signatureData: nil,
                        timestamp: Date(),
                        location: coords,
                        verificationMethod: .handoff,
                        notes: nil
                    )
                )
            }
            
            // Complete Radar tracking
            radarService.completeDeliveryTracking(orderId: orderId)
            
            currentOrder = nil
            todayDeliveries += 1
            await loadTodayStats()
            await loadAvailableOrders()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Update courier profile
    public func updateProfile(_ profile: Courier) async {
        isLoading = true
        
        do {
            let updated = try await service.updateCourierProfile(profile)
            courierProfile = updated
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Clear error message
    public func clearError() {
        errorMessage = nil
    }

    /// Submit KYC documents
    public func submitKyc(documents: [String]) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.submitCourierKyc(documents: documents)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func refreshKycStatus() async {
        do {
            _ = try await service.refreshCourierConnectStatus()
            await loadCourierProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Private Methods
    
    private func setupRadar() {
        // Subscribe to Radar location updates
        radarService.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.currentLocation = location
                
                // Auto-update location if online and has active order (more frequent for active orders)
                if self?.isOnline == true && self?.currentOrder != nil {
                    Task {
                        await self?.updateLocationIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
            
        // Subscribe to delivery zone updates
        radarService.$deliveryZones
            .receive(on: DispatchQueue.main)
            .sink { [weak self] zones in
                // Filter available orders by delivery zones if needed
                print("Available delivery zones: \(zones.count)")
            }
            .store(in: &cancellables)
            
        // Subscribe to location permission status
        radarService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleLocationPermissionChange(status)
            }
            .store(in: &cancellables)
    }
    
    private func handleLocationPermissionChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted:
            errorMessage = "Location access is required for courier operations"
            if isOnline {
                Task {
                    await goOffline()
                }
            }
        case .authorizedWhenInUse, .authorizedAlways:
            // Clear any permission-related errors
            if errorMessage == "Location access is required for courier operations" {
                errorMessage = nil
            }
        case .notDetermined:
            // Permission will be requested when needed
            break
        @unknown default:
            break
        }
    }
    
    private func setupSubscriptions() {
        // Listen for order updates
        service.orderUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] order in
                if self?.currentOrder?.id == order.id {
                    self?.currentOrder = order
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadCourierProfile() async {
        do {
            let profile = try await service.getCourierProfile()
            courierProfile = profile
            courierId = profile?.id ?? ""
            isOnline = profile?.isOnline ?? false
            
            // Setup Radar tracking if already online
            if isOnline, let profile = profile {
                radarService.setupCourierTracking(
                    courierId: profile.id ?? "",
                    metadata: [
                        "vehicleType": profile.vehicleType.rawValue,
                        "rating": courierRating
                    ]
                )
            }
        } catch {
            // Profile might not exist yet - that's ok for new couriers
            print("Could not load courier profile: \(error)")
        }
    }
    
    private func loadAvailableOrders() async {
        guard isOnline else {
            availableOrders = []
            return
        }
        
        do {
            let orders = try await service.getAvailableOrders()
            
            // Filter by delivery zones if available
            if !radarService.deliveryZones.isEmpty {
                // In production, you'd filter orders by checking if they're within delivery zones
                availableOrders = orders
            } else {
                availableOrders = orders
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadTodayStats() async {
        // In a real implementation, this would call a service method
        // For now, we'll use mock data
        todayDeliveries = Int.random(in: 5...15)
        todayEarnings = Double.random(in: 200...800)
        
        // Generate weekly earnings data
        weeklyEarnings = (0..<7).map { _ in Double.random(in: 150...900) }
    }
    
    private func updateLocationIfNeeded() async {
        guard let location = currentLocation,
              isOnline else { return }
        
        let courierLocation = Courier.CourierLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            lastUpdatedAt: Date()
        )
        
        do {
            try await service.updateLocation(courierLocation)
        } catch {
            print("Failed to update location: \(error)")
        }
    }
    
    private func startLocationUpdateTimer() {
        guard isOnline else { return }
        
        // Regular location updates every 30 seconds while online
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateLocationIfNeeded()
            }
        }
    }
    
    private func stopLocationUpdateTimer() {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }

    // MARK: - View Helpers
    public func fetchRestaurantCoordinates(restaurantId: String) async -> Coordinates? {
        if let restaurant = try? await service.getRestaurant(id: restaurantId) {
            return restaurant.coordinates
        }
        return nil
    }
}

// MARK: - Public Methods for checking delivery zones
extension CourierViewModel {
    /// Check if an order is within deliverable zones
    public func isOrderDeliverable(_ order: Order) async -> Bool {
        let location = CLLocationCoordinate2D(
            latitude: order.addresses.dropoff.latitude,
            longitude: order.addresses.dropoff.longitude
        )
        
        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                radarService.isLocationInDeliveryZone(location: location) { result in
                    continuation.resume(with: result)
                }
            }
            return result
        } catch {
            return false // Assume not deliverable if check fails
        }
    }
    
    /// Find nearby delivery zones
    public func findNearbyDeliveryZones() async {
        guard let location = currentLocation?.coordinate else { return }
        
        await withCheckedContinuation { continuation in
            radarService.findNearbyDeliveryZones(around: location) { _ in
                continuation.resume()
            }
        }
    }
}

// MARK: - Helper Extensions (Missing from Legacy Migration)
extension CourierViewModel {
    /// Get current order status display info
    public var currentOrderStatusInfo: (title: String, subtitle: String, actionNeeded: Bool)? {
        guard let order = currentOrder else { return nil }
        
        switch order.status {
        case .restaurantAccepted, .preparing:
            return ("Head to Restaurant", "Order is being prepared", false)
        case .readyForPickup:
            return ("Pickup Ready", "Tap to confirm pickup", true)
        case .pickedUp:
            return ("Delivering Order", "Head to customer location", false)
        default:
            return nil
        }
    }
    
    /// Check if courier can confirm pickup
    public var canConfirmPickup: Bool {
        currentOrder?.status == .readyForPickup
    }
    
    /// Check if courier can confirm delivery
    public var canConfirmDelivery: Bool {
        currentOrder?.status == .pickedUp
    }
    
    /// Get bearing from current location
    public var bearing: Double? {
        guard let location = currentLocation else { return nil }
        return location.course >= 0 ? location.course : nil
    }
}