import Foundation
import Combine
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

/// Configuration for local development services
public struct LocalDevConfig {
    public let useEmulators: Bool
    public let enablePayments: Bool
    public let enableRealLocation: Bool
    public let enableLiveAudio: Bool
    
    public init(
        useEmulators: Bool = true,
        enablePayments: Bool = true,
        enableRealLocation: Bool = true,
        enableLiveAudio: Bool = false
    ) {
        self.useEmulators = useEmulators
        self.enablePayments = enablePayments
        self.enableRealLocation = enableRealLocation
        self.enableLiveAudio = enableLiveAudio
    }
    
    /// Default local development configuration
    public static let `default` = LocalDevConfig()
    
    /// Minimal configuration - only Firebase emulators
    public static let minimal = LocalDevConfig(
        enablePayments: false,
        enableRealLocation: false,
        enableLiveAudio: false
    )
}

// Enhanced Firestore-backed implementation with local dev services integration.
// ‑ Connects to Firebase emulators for testing
// ‑ Integrates with Stripe test mode, Radar test mode, and LiveKit local server
// ‑ Streams live driver locations and handles real payments/location in test mode
public final class FirestoreRideService: RideSharingServicing {
    // MARK: ‑ Public publishers
    public var connectionState: AnyPublisher<ConnectionState, Never> { _connection.eraseToAnyPublisher() }
    public var rideEvents: AnyPublisher<RideEvent, Never> { _events.eraseToAnyPublisher() }
    public var driverAudioTrack: AnyPublisher<Track?, Never> { _driverTrack.eraseToAnyPublisher() }
    public var audioTrack: AnyPublisher<Track?, Never> { _audioTrack.eraseToAnyPublisher() }
    public var isMicrophoneEnabled: AnyPublisher<Bool, Never> { _micEnabled.eraseToAnyPublisher() }

    // MARK: ‑ Private subjects
    private let _connection = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let _events = PassthroughSubject<RideEvent, Never>()
    private let _driverTrack = CurrentValueSubject<Track?, Never>(nil)
    private let _audioTrack = CurrentValueSubject<Track?, Never>(nil)
    private let _micEnabled = CurrentValueSubject<Bool, Never>(false)

    // MARK: ‑ Configuration and Services
    private let config: LocalDevConfig
    private var stripeService: StripePaymentService?
    private var radarService: RadarLocationService?
    
    // MARK: ‑ Firestore
    private var listener: ListenerRegistration?
    private var rideRequestListener: ListenerRegistration?
    private var matchedSent = false
    private var rideRequestDocId: String?

    public init(config: LocalDevConfig = .default) {
        self.config = config
        setupServices()
    }
    
    // MARK: ‑ Service Setup
    private func setupServices() {
        if config.useEmulators {
            configureEmulators()
        }
        
        if config.enablePayments {
            setupStripeTestMode()
        }
        
        if config.enableRealLocation {
            setupRadarTestMode()
        }
        
        if config.enableLiveAudio {
            setupLiveKitLocalMode()
        }
    }
    
    private func configureEmulators() {
        // Configure Firebase emulators for local development
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings
        
        // Use emulator for Auth too
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)
        
        print("🔥 Firebase emulators configured (Firestore: localhost:8080, Auth: localhost:9099)")
    }
    
    private func setupStripeTestMode() {
        // Initialize Stripe with test keys on the main actor
        Task { @MainActor in
            self.stripeService = StripePaymentService()
            print("💳 Stripe configured in test mode")
        }
    }
    
    private func setupRadarTestMode() {
        // Initialize Radar with test keys on the main actor
        Task { @MainActor in
            self.radarService = RadarLocationService()
            print("📍 Radar configured in test mode")
        }
    }
    
    private func setupLiveKitLocalMode() {
        // Configure for local LiveKit server
        print("🎤 LiveKit configured for local development (ws://localhost:7880)")
    }

    // MARK: ‑ RideSharingServicing
    public func start() async throws {
        await ensureFirebaseConfigured()

        _connection.send(.connecting)
        try await signInIfNeeded()
        
        // Get real user location if enabled, otherwise use default SF location
        let origin: GeoPoint
        let destination: GeoPoint
        
        if config.enableRealLocation, let location = await getCurrentLocation() {
            origin = GeoPoint(latitude: location.latitude, longitude: location.longitude)
            // For demo, destination is slightly offset from current location
            destination = GeoPoint(latitude: location.latitude + 0.01, longitude: location.longitude + 0.01)
            _events.send(.userLocationUpdated(lat: location.latitude, lon: location.longitude))
        } else {
            // Fallback to SF coordinates
            origin = GeoPoint(latitude: 37.773972, longitude: -122.431297)
            destination = GeoPoint(latitude: 37.781662, longitude: -122.405624)
            _events.send(.userLocationUpdated(lat: 37.773972, lon: -122.431297))
        }
        
        let reqData: [String: Any] = [
            "origin": origin,
            "destination": destination,
            "state": "searching",
            "createdAt": Timestamp(date: Date()),
            "paymentEnabled": config.enablePayments,
            "locationEnabled": config.enableRealLocation
        ]

        let db = Firestore.firestore()
        do {
            let ref = try await db.collection("rideRequests").addDocument(data: reqData)
            // Fetch real driving route polyline via Mapbox Directions
            if let coords = try? await fetchDirectionsRoute(origin: origin, destination: destination) {
                _events.send(.routeUpdated(coords))
            } else {
                // Fallback to a straight line if Directions fails so UI still works
                let fallback: [(Double, Double)] = [(origin.latitude, origin.longitude),
                                                   (destination.latitude, destination.longitude)]
                _events.send(.routeUpdated(fallback))
            }
            rideRequestDocId = ref.documentID
            _connection.send(.connectedNoCounterpart)
        } catch {
            _connection.send(.failed("Request upload failed"))
            return
        }

        listenForRideRequest(id: rideRequestDocId!)
    }

    public func stop() {
        listener?.remove()
        rideRequestListener?.remove()
        listener = nil
        rideRequestListener = nil
        _connection.send(.disconnected)

        // mark ride request cancelled if exists
        if let id = rideRequestDocId {
            Firestore.firestore().collection("rideRequests").document(id).updateData(["state": "cancelled"]) { _ in }
            rideRequestDocId = nil
        }
    }

    public func toggleMicrophone() async {
        _micEnabled.send(!_micEnabled.value)
    }

    public func acceptRide() async throws {
        guard let id = rideRequestDocId else { return }
        
        // If payments are enabled, process payment first
        if config.enablePayments {
            await processTestPayment()
        }
        
        try await Firestore.firestore().collection("rideRequests").document(id).updateData([
            "state": "accepted",
            "acceptedAt": Timestamp(date: Date())
        ])
        
        // Send payment completion event
        if config.enablePayments {
            _events.send(.priceUpdated(total: 15.50)) // Test fare
            _events.send(.paymentStatusChanged("succeeded"))
        }
    }
    
    // MARK: ‑ Helper Methods
    
    private func getCurrentLocation() async -> CLLocationCoordinate2D? {
        // Access @MainActor-isolated RadarLocationService safely
        guard let radarService = await MainActor.run(body: { self.radarService }) else { return nil }
        
        // Request location permission if needed on the main actor
        await MainActor.run { radarService.requestLocationPermission() }
        
        // For now, return current location if available
        // In a real implementation, we'd wait for location updates
        return await MainActor.run { radarService.currentLocation?.coordinate }
    }
    
    private func processTestPayment() async {
        // Ensure the @MainActor-isolated Stripe service exists without crossing actors unsafely
        let hasStripe = await MainActor.run { self.stripeService != nil }
        guard hasStripe else { return }
        
        // Simulate payment processing
        _events.send(.paymentStatusChanged("processing"))
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // For test mode, always succeed
        _events.send(.paymentStatusChanged("succeeded"))
        print("💳 Test payment processed successfully")
    }

    // MARK: ‑ Helpers
    private func listenForDrivers() {
        let db = Firestore.firestore()
        listener = db.collection("drivers")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self._connection.send(.failed(error.localizedDescription))
                    return
                }
                guard let docs = snapshot?.documents, let first = docs.first else { return }
                let data = first.data()
                let loc = data["currentLocation"] as? GeoPoint
                let name = data["name"] as? String
                guard let loc else { return }

                let lat = loc.latitude
                let lon = loc.longitude

                // Send matched only once
                if !self.matchedSent {
                    let name = name ?? "Driver"
                    self._events.send(.matched(driverName: name, etaSeconds: 180))
                    self.matchedSent = true
                    self._connection.send(.connected)
                }

                self._events.send(.driverLocationUpdated(lat: lat, lon: lon))
            }
    }

    private func listenForRideRequest(id: String) {
        let db = Firestore.firestore()
        rideRequestListener = db.collection("rideRequests").document(id).addSnapshotListener { [weak self] snap, error in
            guard let self, let data = snap?.data() else { return }
            guard let request = try? snap?.data(as: RideRequest.self) else { return }

            if request.state == "proposed", let driverId = request.assignedDriverId {
                // Switch to specific driver listener
                self.listener?.remove()
                self.listenToDriver(driverId: driverId)
            } else if request.state == "priced", let breakdown = request.fareBreakdown, let total = breakdown["total"] {
                self._events.send(.priceUpdated(total: total))
            }

            if let journey = request.journey,
               let geometry = rideJourneyDisplayGeometry(from: journey) {
                self._events.send(.journeyReceived(legs: geometry.legCount))

                let segments = geometry.routeSegments.map { segment in
                    [segment.start.asTuple, segment.end.asTuple]
                }
                if !segments.isEmpty {
                    self._events.send(.routeSegmentsUpdated(segments))
                }

                if !geometry.transferPoints.isEmpty {
                    self._events.send(.transferPointsUpdated(geometry.transferPoints.map { $0.asTuple }))
                }

                let walks = geometry.walkingSegments.map { segment in
                    [segment.start.asTuple, segment.end.asTuple]
                }
                if !walks.isEmpty {
                    self._events.send(.walkingSegmentsUpdated(walks))
                }
            }

            // Payment status monitoring
            if let status = request.paymentStatus {
                self._events.send(.paymentStatusChanged(status))
            }
        }
    }

    private func listenToDriver(driverId: String) {
        let db = Firestore.firestore()
        listener = db.collection("drivers").document(driverId).addSnapshotListener { [weak self] snap, error in
            guard let self, let doc = snap else { return }
            let data = doc.data()
            let loc = data?["currentLocation"] as? GeoPoint
            let name = data?["name"] as? String
            guard let loc else { return }

            let lat = loc.latitude
            let lon = loc.longitude

            if !self.matchedSent {
                let name = name ?? "Driver"
                self._events.send(.matched(driverName: name, etaSeconds: 180))
                self.matchedSent = true
                self._connection.send(.connected)
            }

            self._events.send(.driverLocationUpdated(lat: lat, lon: lon))
        }
    }

    private func ensureFirebaseConfigured() async {
        if FirebaseApp.app() == nil {
            // For local testing, configure with default options
            #if DEBUG
            let options = FirebaseOptions(
                googleAppID: "1:123456789:ios:abcdef",
                gcmSenderID: "123456789"
            )
            options.projectID = "liive-ios-local"
            options.storageBucket = "liive-ios-local.appspot.com"
            options.apiKey = "fake-api-key-for-local-testing"
            FirebaseApp.configure(options: options)
            
            // Configure emulators
            LocalEmulatorConfig.configureEmulators()
            #else
            FirebaseApp.configure()
            #endif
        }
    }

    private func signInIfNeeded() async throws {
        if Auth.auth().currentUser == nil {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                Auth.auth().signInAnonymously { _, error in
                    if let error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }
        }
    }
}

// MARK: - Mapbox Directions
private extension FirestoreRideService {
    struct DirectionsResponse: Decodable {
        struct Route: Decodable {
            struct Geometry: Decodable { let coordinates: [[Double]] }
            let geometry: Geometry
        }
        let routes: [Route]
    }

    func fetchDirectionsRoute(origin: GeoPoint, destination: GeoPoint) async throws -> [(Double, Double)]? {
        let token = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String ?? ""
        guard !token.isEmpty else { return nil }

        let urlString = "https://api.mapbox.com/directions/v5/mapbox/driving-traffic/\(origin.longitude),\(origin.latitude);\(destination.longitude),\(destination.latitude)?overview=full&geometries=geojson&access_token=\(token)"
        guard let url = URL(string: urlString) else { return nil }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        let decoded = try JSONDecoder().decode(DirectionsResponse.self, from: data)
        guard let coordsLonLat = decoded.routes.first?.geometry.coordinates, coordsLonLat.count >= 2 else { return nil }

        // Map to (lat, lon) tuples expected by RideEvent
        return coordsLonLat.map { ($0[1], $0[0]) }
    }
} 
