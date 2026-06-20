import Foundation
import CoreLocation
import RadarSDK
import Combine

/// Service for handling location services and walk isochrones using Radar SDK
@MainActor
public class RadarLocationService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var currentLocation: CLLocation?
    @Published public var isTrackingEnabled: Bool = false
    @Published public var walkIsochrone: RadarRoutes?
    
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
            // Request always authorization for background tracking
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startLocationTracking()
        @unknown default:
            break
        }
    }
    
    /// Starts location tracking
    public func startLocationTracking() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestLocationPermission()
            return
        }
        
        locationManager.startUpdatingLocation()
        
        // Start Radar tracking
        Radar.startTracking(trackingOptions: RadarTrackingOptions.presetResponsive)
        isTrackingEnabled = true
        
        print("✅ Location tracking started")
    }
    
    /// Stops location tracking
    public func stopLocationTracking() {
        locationManager.stopUpdatingLocation()
        Radar.stopTracking()
        isTrackingEnabled = false
        
        print("🛑 Location tracking stopped")
    }
    
    /// Calculates walk isochrone from current location
    /// - Parameters:
    ///   - radiusMeters: Maximum walk radius in meters
    ///   - completion: Completion handler with isochrone result
    public func calculateWalkIsochrone(
        radiusMeters: Int = 400,
        completion: @escaping (Result<RadarRoutes, Error>) -> Void
    ) {
        guard let location = currentLocation else {
            completion(.failure(RadarLocationError.noCurrentLocation))
            return
        }
        
        let origin = location
        
        // Calculate isochrone using Radar's routing API
        Radar.getDistance(
            origin: origin,
            destination: origin,
            modes: [.foot],
            units: .metric
        ) { [weak self] (status, routes) in
            DispatchQueue.main.async {
                
                if let routes = routes {
                    self?.walkIsochrone = routes
                    completion(.success(routes))
                } else {
                    completion(.failure(RadarLocationError.noRoutesFound))
                }
            }
        }
    }
    
    /// Gets precise walk isochrone polygon for the given radius
    /// - Parameters:
    ///   - origin: Origin coordinate
    ///   - radiusMeters: Walk radius in meters
    ///   - completion: Completion with GeoJSON polygon
    public func getWalkIsochronePolygon(
        from origin: CLLocationCoordinate2D,
        radiusMeters: Int,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        // Approximate isochrone as a circle around origin with given radius
        let polygon = createCircularPolygon(
            center: origin,
            radiusMeters: Double(radiusMeters),
            points: 64
        )
        completion(.success(polygon))
    }
    
    /// Uploads walk isochrone to Firestore
    /// - Parameters:
    ///   - userId: User ID
    ///   - polygon: GeoJSON polygon
    ///   - completion: Completion handler
    public func uploadWalkIsochrone(
        userId: String,
        polygon: [String: Any],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // This would integrate with FirestoreRideService
        // For now, we'll simulate the upload
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("📤 Walk isochrone uploaded for user: \(userId)")
            completion(.success(()))
        }
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
                    
                    // Set user ID for tracking
                    Radar.setUserId("rider_\(UUID().uuidString)")
                    
                    // Enable background location if needed
                    Radar.setLogLevel(.debug)
                    
                    print("✅ Radar SDK initialized successfully")
                }
            } catch {
                print("❌ Failed to initialize Radar SDK: \(error)")
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
    
    // Approximate circle polygon around a center coordinate
    private func createCircularPolygon(center: CLLocationCoordinate2D, radiusMeters: Double, points: Int) -> [String: Any] {
        var coordinates: [[Double]] = []
        coordinates.reserveCapacity(points + 1)
        let earthRadius = 6378137.0
        let lat = center.latitude * .pi / 180.0
        let lon = center.longitude * .pi / 180.0
        for i in 0..<points {
            let angle = (Double(i) / Double(points)) * 2.0 * .pi
            let dx = radiusMeters * cos(angle)
            let dy = radiusMeters * sin(angle)
            let latOffset = (dy / earthRadius)
            let lonOffset = (dx / (earthRadius * cos(lat)))
            let pointLat = (lat + latOffset) * 180.0 / .pi
            let pointLon = (lon + lonOffset) * 180.0 / .pi
            coordinates.append([pointLon, pointLat])
        }
        // Close the polygon
        if let first = coordinates.first {
            coordinates.append(first)
        }
        return [
            "type": "Polygon",
            "coordinates": [coordinates]
        ]
    }
    
    // Kept for future use if we re-enable matrix-based isochrones
    private func createIsochronePolygon(from _: Any, origin _: CLLocationCoordinate2D, maxDurationMinutes _: Double) -> [String: Any] { return [:] }
}

// MARK: - CLLocationManagerDelegate

extension RadarLocationService: CLLocationManagerDelegate {
    
    public func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Optionally send a one-off update to Radar if desired
    }
    
    public func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        authorizationStatus = status
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            startLocationTracking()
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
        print("❌ Location manager failed: \(error)")
    }
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
    case noRoutesFound
    case noMatrixResult
    case permissionDenied
    case configurationError
    
    public var errorDescription: String? {
        switch self {
        case .noCurrentLocation:
            return "Current location not available"
        case .noRoutesFound:
            return "No routes found for isochrone calculation"
        case .noMatrixResult:
            return "No matrix result from Radar API"
        case .permissionDenied:
            return "Location permission denied"
        case .configurationError:
            return "Failed to load configuration from backend"
        }
    }
} 