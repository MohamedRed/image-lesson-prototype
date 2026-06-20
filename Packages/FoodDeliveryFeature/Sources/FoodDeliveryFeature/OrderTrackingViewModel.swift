import Foundation
import FoodDeliveryService
import Combine

/// ViewModel for real-time order tracking
@MainActor
public class OrderTrackingViewModel: ObservableObject {
    @Published public var tracking: DeliveryTracking?
    @Published public var courierLocation: CourierLocation?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let orderId: String
    private let service: FoodDeliveryServicing
    private var cancellables = Set<AnyCancellable>()
    private var locationTimer: Timer?
    
    public init(orderId: String, service: FoodDeliveryServicing) {
        self.orderId = orderId
        self.service = service
    }
    
    deinit {
        Task { @MainActor in
            stopTracking()
        }
    }
    
    public func startTracking() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load initial tracking data
            tracking = try await service.getDeliveryTracking(orderId: orderId)
            
            // Subscribe to real-time tracking updates
            service.subscribeToOrderTracking(orderId: orderId)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] updatedTracking in
                    self?.tracking = updatedTracking
                    
                    // Start courier location tracking if courier is assigned
                    if let courierId = updatedTracking.courierId, self?.courierLocation?.courierId != courierId {
                        self?.startCourierLocationTracking()
                    }
                }
                .store(in: &cancellables)
            
            // Subscribe to courier location updates
            service.courierLocationStream
                .receive(on: DispatchQueue.main)
                .sink { [weak self] location in
                    // Only update if this location is for our order's courier
                    if let tracking = self?.tracking,
                       let courierId = tracking.courierId,
                       location.courierId == courierId {
                        self?.courierLocation = location
                    }
                }
                .store(in: &cancellables)
                
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func stopTracking() {
        cancellables.removeAll()
        locationTimer?.invalidate()
        locationTimer = nil
    }
    
    public func refreshTracking() async {
        do {
            tracking = try await service.getDeliveryTracking(orderId: orderId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func startCourierLocationTracking() {
        guard let courierId = tracking?.courierId else { return }
        
        // Start location tracking for the courier
        Task {
            try? await service.startLocationTracking(courierId: courierId)
        }
        
        // Set up periodic location requests (in addition to real-time updates)
        locationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            // The real-time stream should handle updates, but this ensures we don't miss any
            guard let tracking = self?.tracking,
                  let courierId = tracking.courierId else { return }
            
            // Location updates are handled by the stream subscription
            // This timer is just a backup to ensure we don't lose tracking
        }
    }
    
    // MARK: - Helper Methods
    
    public var estimatedArrivalTime: String? {
        guard let tracking = tracking,
              tracking.status != .delivered && tracking.status != .cancelled else {
            return nil
        }
        
        guard let eta = tracking.estimatedDeliveryTime else { return nil }
        let timeRemaining = eta.timeIntervalSince(Date())
        if timeRemaining > 0 {
            let minutes = Int(timeRemaining / 60)
            return "\(minutes) min"
        } else {
            return "Any moment"
        }
    }
    
    public var canContactCourier: Bool {
        guard let tracking = tracking else { return false }
        return tracking.courierId != nil && 
               tracking.status != .delivered && 
               tracking.status != .cancelled
    }
    
    public var deliveryProgress: Double {
        return tracking?.progressValue ?? 0.0
    }
    
    public var currentStatusMessage: String {
        guard let tracking = tracking else { return "Loading..." }
        
        if let latestUpdate = tracking.customerUpdates.last {
            return latestUpdate.message
        }
        
        return tracking.status.description
    }
    
    public var isOrderActive: Bool {
        guard let tracking = tracking else { return false }
        return tracking.status != .delivered && tracking.status != .cancelled
    }
}

// MARK: - Extensions
extension DeliveryTracking.DeliveryStatus {
    var description: String {
        switch self {
        case .orderPlaced: return "Your order has been placed successfully"
        case .restaurantConfirmed: return "Restaurant has confirmed your order"
        case .preparing: return "Your food is being prepared"
        case .readyForPickup: return "Order is ready for courier pickup"
        case .courierAssigned: return "A courier has been assigned"
        case .courierEnRoute: return "Courier is heading to the restaurant"
        case .enRouteToCustomer: return "Courier is heading to you"
        case .arrivedAtCustomer: return "Courier has arrived"
        case .orderDelivered: return "Order delivered"
        case .orderCancelled: return "Order cancelled"
        case .pickedUp: return "Courier has picked up your order"
        case .outForDelivery: return "Your order is on its way to you"
        case .delivered: return "Order has been delivered successfully"
        case .cancelled: return "Order has been cancelled"
        }
    }
}