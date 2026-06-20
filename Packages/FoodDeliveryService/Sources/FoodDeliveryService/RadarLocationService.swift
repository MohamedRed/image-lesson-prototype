import Foundation
import CoreLocation
import RadarSDK
import Combine

/// Service for handling location services for food delivery using Radar SDK
@MainActor
public class FoodDeliveryRadarLocationService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var currentLocation: CLLocation?
    @Published public var isTrackingEnabled: Bool = false
    @Published public var deliveryZones: [RadarGeofence] = []
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public override init() {
        super.init()
        setupLocationManager()
        setupRadar()
    }
    
    // MARK: - Public Methods
    
    /// Requests location permission from the user
    public func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Guide user to settings
            print("Location permission denied. Please enable in Settings.")
        case .authorizedWhenInUse:
            // For food delivery, when-in-use is sufficient for customers
            // Couriers may need always authorization
            startLocationTracking()
        case .authorizedAlways:
            startLocationTracking()
        @unknown default:
            break
        }
    }
    
    /// Starts location tracking with appropriate settings for food delivery
    public func startLocationTracking(userType: FoodDeliveryUserType = .customer) {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestLocationPermission()
            return
        }
        
        locationManager.startUpdatingLocation()
        
        // Configure Radar tracking based on user type
        let trackingOptions: RadarTrackingOptions
        switch userType {
        case .customer:
            // Less frequent tracking for customers
            trackingOptions = RadarTrackingOptions.presetEfficient
        case .courier:
            // High-frequency tracking for couriers
            trackingOptions = RadarTrackingOptions.presetResponsive
        case .restaurant:
            // Minimal tracking for restaurants (mainly for geofence detection)
            trackingOptions = RadarTrackingOptions.presetContinuous
        }
        
        Radar.startTracking(trackingOptions: trackingOptions)
        isTrackingEnabled = true
        
        print("✅ Food delivery location tracking started for \(userType)")
    }
    
    /// Stops location tracking
    public func stopLocationTracking() {
        locationManager.stopUpdatingLocation()
        Radar.stopTracking()
        isTrackingEnabled = false
        
        print("🛑 Food delivery location tracking stopped")
    }
    
    /// Sets up courier for delivery tracking
    /// - Parameters:
    ///   - courierId: Unique courier identifier
    ///   - metadata: Additional courier metadata
    public func setupCourierTracking(courierId: String, metadata: [String: Any] = [:]) {
        let courierMetadata = [
            "type": "food_delivery_courier",
            "courierId": courierId,
            "isActive": true
        ].merging(metadata) { _, new in new }
        
        Radar.setUserId("courier_\(courierId)")
        Radar.setMetadata(courierMetadata)
        
        startLocationTracking(userType: .courier)
        
        print("✅ Courier tracking setup for: \(courierId)")
    }
    
    /// Sets up customer tracking for order tracking
    /// - Parameters:
    ///   - customerId: Unique customer identifier
    ///   - orderId: Current order identifier (optional)
    public func setupCustomerTracking(customerId: String, orderId: String? = nil) {
        var customerMetadata: [String: Any] = [
            "type": "food_delivery_customer",
            "customerId": customerId,
        ]
        
        if let orderId = orderId {
            customerMetadata["currentOrderId"] = orderId
        }
        
        Radar.setUserId("customer_\(customerId)")
        Radar.setMetadata(customerMetadata)
        
        startLocationTracking(userType: .customer)
        
        print("✅ Customer tracking setup for: \(customerId)")
    }
    
    /// Sets up restaurant location tracking
    /// - Parameters:
    ///   - restaurantId: Unique restaurant identifier
    ///   - location: Fixed restaurant location
    public func setupRestaurantTracking(restaurantId: String, location: CLLocationCoordinate2D) {
        let restaurantMetadata: [String: Any] = [
            "type": "food_delivery_restaurant",
            "restaurantId": restaurantId,
            "isOperating": true,
            "latitude": location.latitude,
            "longitude": location.longitude
        ]
        
        Radar.setUserId("restaurant_\(restaurantId)")
        Radar.setMetadata(restaurantMetadata)
        
        // Track location once to establish restaurant position
        Radar.trackOnce { [weak self] (status, location, events, user) in
            if status == .success {
                print("✅ Restaurant location established: \(restaurantId)")
            } else {
                print("❌ Failed to establish restaurant location: \(status)")
            }
        }
        
        print("✅ Restaurant tracking setup for: \(restaurantId)")
    }
    
    /// Finds nearby delivery zones for a location
    /// - Parameters:
    ///   - location: Location to search around
    ///   - completion: Completion handler with delivery zones
    public func findNearbyDeliveryZones(
        around location: CLLocationCoordinate2D,
        completion: @escaping (Result<[RadarGeofence], Error>) -> Void
    ) {
        let searchLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        Radar.searchGeofences(
            near: searchLocation,
            radius: 5000,
            tags: ["delivery_zone"],
            metadata: nil,
            limit: 20,
            includeGeometry: false,
            completionHandler: { status, location, geofences in
            DispatchQueue.main.async {
                if status == .success {
                    let deliveryGeofences = geofences ?? []
                    self.deliveryZones = deliveryGeofences
                    completion(.success(deliveryGeofences))
                    print("✅ Found \(deliveryGeofences.count) delivery zones")
                } else {
                    completion(.failure(RadarLocationError.noGeofencesFound))
                    print("❌ Failed to find delivery zones: \(status)")
                }
            }
        })
    }
    
    /// Checks if a location is within any delivery zone
    /// - Parameters:
    ///   - location: Location to check
    ///   - completion: Completion handler with result
    public func isLocationInDeliveryZone(
        location: CLLocationCoordinate2D,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        findNearbyDeliveryZones(around: location) { result in
            switch result {
            case .success(let zones):
                // For simplicity, if any zones are found, consider it deliverable
                // In a real app, you'd check if the location is actually inside the zone
                completion(.success(!zones.isEmpty))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Tracks delivery progress for courier
    /// - Parameters:
    ///   - orderId: Order being delivered
    ///   - pickupLocation: Restaurant pickup location
    ///   - deliveryLocation: Customer delivery location
    public func startDeliveryTracking(
        orderId: String,
        pickupLocation: CLLocationCoordinate2D,
        deliveryLocation: CLLocationCoordinate2D
    ) {
        // Create trip for delivery tracking
        let tripOptions = RadarTripOptions()
        tripOptions.externalId = "delivery_\(orderId)"
        tripOptions.metadata = [
            "orderId": orderId,
            "type": "food_delivery",
            "pickupLat": pickupLocation.latitude,
            "pickupLng": pickupLocation.longitude,
            "deliveryLat": deliveryLocation.latitude,
            "deliveryLng": deliveryLocation.longitude
        ]
        
        Radar.startTrip(options: tripOptions, completionHandler: { status, trip, events in
            if status == .success {
                print("✅ Delivery tracking started for order: \(orderId)")
            } else {
                print("❌ Failed to start delivery tracking: \(status)")
            }
        })
    }
    
    /// Completes delivery tracking
    /// - Parameter orderId: Order that was completed
    public func completeDeliveryTracking(orderId: String) {
        Radar.completeTrip(completionHandler: { status, trip, events in
            if status == .success {
                print("✅ Delivery tracking completed for order: \(orderId)")
            } else {
                print("❌ Failed to complete delivery tracking: \(status)")
            }
        })
    }
    
    // MARK: - Private Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        
        authorizationStatus = locationManager.authorizationStatus
    }
    
    private func setupRadar() {
        // Initialize Radar SDK with key from backend
        Task {
            do {
                let config = try await fetchConfig()
                await MainActor.run {
                    Radar.initialize(publishableKey: config.radarPublishableKey)
                    
                    // Set up event listener for geofence events
                    setupRadarEventHandling()
                    
                    // Enable debug logging
                    Radar.setLogLevel(.debug)
                    
                    print("✅ Radar SDK initialized for food delivery")
                }
            } catch {
                print("❌ Failed to initialize Radar SDK: \(error)")
            }
        }
    }
    
    private func setupRadarEventHandling() {
        // This would typically be set up in the app delegate or main app
        // to handle geofence enter/exit events for delivery zones
        NotificationCenter.default.publisher(for: .radarDidReceiveEvents)
            .sink { [weak self] notification in
                if let events = notification.object as? [RadarEvent] {
                    self?.handleRadarEvents(events)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleRadarEvents(_ events: [RadarEvent]) {
        for event in events {
            switch event.type {
            case .userEnteredGeofence:
                if event.geofence?.tag == "delivery_zone" {
                    print("✅ Entered delivery zone: \(event.geofence?.description ?? "Unknown")")
                }
            case .userExitedGeofence:
                if event.geofence?.tag == "delivery_zone" {
                    print("🚪 Exited delivery zone: \(event.geofence?.description ?? "Unknown")")
                }
            // Case not available in current Radar SDK; handled via trip/events callbacks
            default:
                break
            }
        }
    }
    
    private func fetchConfig() async throws -> ConfigResponse {
        guard let apiBaseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: "\(apiBaseURL)/config") else {
            throw RadarLocationError.configurationError
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ConfigResponse.self, from: data)
    }
}

// MARK: - CLLocationManagerDelegate

extension FoodDeliveryRadarLocationService: CLLocationManagerDelegate {
    
    public func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Optionally send location update to Radar
        // This is handled automatically by Radar.startTracking()
    }
    
    public func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        authorizationStatus = status
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            // Don't auto-start tracking, wait for explicit setup call
            break
        case .denied, .restricted:
            stopLocationTracking()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    public func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        print("❌ Food delivery location manager failed: \(error)")
    }
}

// MARK: - Supporting Types

public enum FoodDeliveryUserType {
    case customer
    case courier
    case restaurant
}

// MARK: - Configuration Types

private struct ConfigResponse: Codable {
    let radarPublishableKey: String
    let mapboxAccessToken: String
    let livekitWsUrl: String
}

// MARK: - Error Types

public enum RadarLocationError: LocalizedError {
    case noCurrentLocation
    case noGeofencesFound
    case permissionDenied
    case configurationError
    case deliveryZoneNotFound
    
    public var errorDescription: String? {
        switch self {
        case .noCurrentLocation:
            return "Current location not available"
        case .noGeofencesFound:
            return "No delivery zones found in this area"
        case .permissionDenied:
            return "Location permission denied"
        case .configurationError:
            return "Failed to load configuration from backend"
        case .deliveryZoneNotFound:
            return "This location is outside our delivery zones"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let radarDidReceiveEvents = Notification.Name("RadarDidReceiveEvents")
}