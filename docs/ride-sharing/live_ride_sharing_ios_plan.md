# 🚗 Live Ride Sharing iOS Feature - Complete Implementation Plan

> Canonical matching source: [`canonical_algorithm.md`](./canonical_algorithm.md). Use that file for the latest intended matching algorithm; this document is supporting implementation context.

## 📋 **Executive Summary**

This plan follows your existing **modular SPM architecture** (Feature + Service packages) and **MVVM patterns** to implement a sophisticated live ride sharing system with:
- **Real-time geospatial matching** using route buffers & isochron polygons
- **Gender-based safety pools** with multi-constraint filtering  
- **Anti-congestion pickup zones** with legal curb-side stops
- **Multi-hop journey planning** (1-3 legs) with seamless transfers
- **Premium options** + **live audio communication** via LiveKit
- **Firebase backend** with Firestore + Cloud Functions + Stripe integration

---

## 🏗️ **Architecture Overview**

Following your existing patterns, we'll create **two new SPM packages**:

```
Packages/
├── GliteRideSharingService/     # Service Layer (Maps, Firebase, LiveKit)
└── GliteRideSharingFeature/     # UI Layer (SwiftUI, ViewModels)
```

**Key Dependencies**:
- **Mapbox Navigator SDK** (route planning, navigation)
- **Radar SDK** (isochron polygons, geofencing)  
- **Firebase SDK** (Auth, Firestore, Functions)
- **Stripe SDK** (payments, identity verification)
- **LiveKit** (real-time audio communication)
- **CoreLocation** (background location tracking)

---

## 📦 **Package 1: GliteRideSharingService**

### **Service Protocol Contract**

```swift
@MainActor
public protocol GliteRideSharingServicing: Sendable {
    // MARK: - Connection States
    var connectionState: AnyPublisher<RideConnectionState, Never> { get }
    var userProfile: AnyPublisher<UserProfile?, Never> { get }
    
    // MARK: - Driver Mode
    var driverState: AnyPublisher<DriverState, Never> { get }
    var activeRideRequests: AnyPublisher<[RideRequest], Never> { get }
    var routeBuffer: AnyPublisher<RouteBuffer?, Never> { get }
    
    // MARK: - Rider Mode  
    var riderState: AnyPublisher<RiderState, Never> { get }
    var matchedDrivers: AnyPublisher<[DriverMatch], Never> { get }
    var currentJourney: AnyPublisher<Journey?, Never> { get }
    
    // MARK: - Real-time Communication
    var audioConnectionState: AnyPublisher<AudioConnectionState, Never> { get }
    var isMicrophoneEnabled: AnyPublisher<Bool, Never> { get }
    var participants: AnyPublisher<[RideParticipant], Never> { get }
    
    // MARK: - Location & Maps
    var currentLocation: AnyPublisher<CLLocation?, Never> { get }
    var isLocationAuthorized: AnyPublisher<Bool, Never> { get }
    
    // MARK: - Service Methods
    func initialize() async throws
    func switchToDriverMode(route: PlannedRoute) async throws
    func switchToRiderMode() async throws
    func requestRide(_ request: RideRequest) async throws
    func acceptRideRequest(_ requestId: String) async throws
    func cancelRide(_ rideId: String) async throws
    func startAudioCommunication(roomId: String) async throws
    func toggleMicrophone() async
    func updateLocation(_ location: CLLocation) async
}
```

### **Core Data Models**

```swift
// MARK: - User & Authentication
public struct UserProfile: Codable, Identifiable {
    public let id: String
    public let name: String
    public let gender: Gender
    public let phoneNumber: String
    public let verificationStatus: VerificationStatus
    public let driverProfile: DriverProfile?
    public let preferences: UserPreferences
}

public enum Gender: String, Codable, CaseIterable {
    case female, male, nonBinary
}

public struct DriverProfile: Codable {
    public let vehicleInfo: VehicleInfo
    public let licenseVerified: Bool
    public let capacityLimits: CapacityLimits
    public let premiumFeatures: [PremiumFeature]
}

// MARK: - Geospatial Models
public struct RouteBuffer: Codable {
    public let polyline: String
    public let bufferPolygon: GeoJSONPolygon
    public let widthMeters: Double
    public let estimatedDuration: TimeInterval
}

public struct IsochronPolygon: Codable {
    public let center: CLLocationCoordinate2D
    public let radiusMeters: Double
    public let walkingTimeSeconds: TimeInterval
    public let polygon: GeoJSONPolygon
    public let type: IsochronType
}

public enum IsochronType: String, Codable {
    case walkingPickup, walkingDropoff, drivingApproach
}

// MARK: - Matching & Journey Models
public struct RideRequest: Codable, Identifiable {
    public let id: String
    public let riderId: String
    public let origin: LocationPoint
    public let destination: LocationPoint
    public let passengers: [PassengerInfo]
    public let constraints: RideConstraints
    public let premiumOptions: PremiumOptions
    public let maxWalkingDistance: Double
    public let createdAt: Date
}

public struct Journey: Codable, Identifiable {
    public let id: String
    public let legs: [JourneyLeg]
    public let totalEstimatedTime: TimeInterval
    public let totalFare: Decimal
    public let status: JourneyStatus
}

public struct JourneyLeg: Codable, Identifiable {
    public let id: String
    public let driverId: String
    public let pickupZone: PickupZone
    public let dropoffZone: PickupZone
    public let estimatedDuration: TimeInterval
    public let fare: Decimal
    public let status: LegStatus
}
```

### **Service Implementation Classes**

1. **`FirebaseRideService`** - Main service implementation
2. **`MapboxNavigationService`** - Route planning & navigation
3. **`RadarGeofencingService`** - Isochron calculations & geofencing
4. **`StripePaymentService`** - Payment processing
5. **`LiveKitAudioService`** - Real-time audio communication
6. **`LocationTrackingService`** - Background location updates
7. **`MockRideSharingService`** - Testing & previews

---

## 🎨 **Package 2: GliteRideSharingFeature**

### **View Architecture (MVVM)**

Following your existing patterns:

```swift
// MARK: - Factory (Single Entry Point)
public enum RideSharingViewFactory {
    @MainActor public static func make(service: GliteRideSharingServicing) -> AnyView {
        let viewModel = RideSharingViewModel(service: service)
        return AnyView(RideSharingRootView(viewModel: viewModel))
    }
}

// MARK: - Root View Model
@MainActor
public final class RideSharingViewModel: ObservableObject {
    public enum State {
        // User Mode Selection
        case selectingMode
        case driverOnboarding
        case driverActive(DriverActiveState)
        case riderSearching(RiderSearchState)
        case journeyInProgress(JourneyProgressState)
        case audioCall(AudioCallState)
        case error(Error)
    }
    
    public enum Event {
        case selectDriverMode
        case selectRiderMode
        case startDriving(PlannedRoute)
        case requestRide(RideRequest)
        case acceptRide(String)
        case cancelRide(String)
        case startAudioCall
        case toggleMicrophone
        case dismissError
    }
    
    @Published public var state: State
    // ... implementation following your ViewModel patterns
}
```

### **View Hierarchy**

```
RideSharingRootView
├── ModeSelectionView
├── DriverViews/
│   ├── DriverOnboardingView
│   ├── RouteSetupView
│   ├── DriverActiveView
│   └── IncomingRequestView
├── RiderViews/
│   ├── RideRequestView
│   ├── DriverMatchingView
│   ├── JourneyProgressView
│   └── MultiHopTransferView
├── SharedViews/
│   ├── LiveMapView (Mapbox)
│   ├── AudioCallView (LiveKit)
│   ├── PaymentSummaryView
│   └── SafetyFeaturesView
└── SupportingViews/
    ├── LocationPermissionView
    ├── VerificationStatusView
    └── PremiumOptionsView
```

### **Key UI Components**

1. **`LiveMapView`** - Real-time map with route buffers, isochron polygons, pickup zones
2. **`RouteBufferOverlay`** - Visual representation of driver's route buffer
3. **`IsochronPolygonOverlay`** - Walking/driving zones for riders
4. **`PickupZoneAnnotation`** - Legal, congestion-aware pickup locations
5. **`AudioCallControls`** - LiveKit integration for driver-rider communication
6. **`JourneyProgressIndicator`** - Multi-leg journey tracking
7. **`SafetyIndicators`** - Gender pool status, verification badges
8. **`PremiumOptionsSelector`** - Advanced ride preferences

---

## 🔄 **Key Algorithms & Features**

### **1. Real-time Matching Algorithm**

```swift
// In GliteRideSharingService
class RideMatchingEngine {
    func findMatches(for request: RideRequest) async -> [DriverMatch] {
        // Step 1: Gender-based filtering
        let genderCompatibleDrivers = await filterByGender(request.gender)
        
        // Step 2: Route buffer intersection
        let routeMatches = await findRouteBufferIntersections(
            drivers: genderCompatibleDrivers,
            riderOrigin: request.origin,
            riderDestination: request.destination
        )
        
        // Step 3: Capacity constraints (seats, luggage, pets, child seats)
        let capacityFiltered = routeMatches.filter { driver in
            canAccommodate(driver: driver, passengers: request.passengers)
        }
        
        // Step 4: Anti-congestion pickup zone availability
        let availablePickupZones = await findAvailablePickupZones(
            near: request.origin,
            walkingDistance: request.maxWalkingDistance
        )
        
        // Step 5: Score and rank matches
        return await scoreAndRankMatches(drivers: capacityFiltered, zones: availablePickupZones)
    }
}
```

### **2. Multi-hop Journey Planning**

```swift
class MultiHopPlanner {
    func planJourney(from origin: LocationPoint, to destination: LocationPoint) async -> Journey? {
        // Try single-hop first
        if let singleHop = await planSingleHop(origin, destination) {
            return singleHop
        }
        
        // Fall back to multi-hop (2-3 legs max)
        return await planMultiHop(origin, destination, maxLegs: 3)
    }
    
    private func planMultiHop(_ origin: LocationPoint, _ destination: LocationPoint, maxLegs: Int) async -> Journey? {
        // Use time-expanded graph algorithm for optimal transfer points
        // Ensure ≤15 second walking between transfers
        // Prioritize same-gender driver pools across legs
    }
}
```

### **3. Anti-Congestion System**

```swift
class CongestionManager {
    func selectOptimalPickupZone(
        near location: LocationPoint,
        within walkingDistance: Double
    ) async -> PickupZone? {
        
        let candidateZones = await findLegalPickupZones(near: location, radius: walkingDistance)
        
        // Filter by current capacity
        let availableZones = candidateZones.filter { zone in
            zone.activePickups < zone.maxCapacity
        }
        
        // Score by: legal compliance, capacity load, walking distance
        return availableZones.min { zone1, zone2 in
            congestionScore(zone1) < congestionScore(zone2)
        }
    }
}
```

---

## 🛡️ **Safety & Security Features**

### **Gender-Based Safety Pools**
- **Driver Registration**: Gender verification during onboarding
- **Strict Matching**: Only same-gender pools (women-only, men-only cars)
- **Real-time Enforcement**: Continuous validation during journey legs

### **Identity Verification**
- **Stripe Identity Integration**: Government ID verification
- **Driver Background Checks**: Enhanced verification for drivers
- **Real-time Badges**: Verification status display in UI

### **Emergency Features**
- **SOS Button**: Immediate emergency contact
- **Live Audio Recording**: Optional trip recording via LiveKit
- **Location Sharing**: Real-time tracking for emergency contacts

---

## 💰 **Payment Integration**

### **Stripe Integration**
```swift
class StripePaymentService {
    func calculateFare(for journey: Journey) async -> FareBreakdown {
        let baseFare = journey.legs.reduce(0) { total, leg in
            total + (leg.distanceKm * 0.50) // Cost-sharing, not taxi rates
        }
        
        let surcharges = calculateSurcharges(journey.constraints)
        let premiumMultiplier = journey.premiumOptions.multiplier
        
        return FareBreakdown(
            baseFare: baseFare,
            surcharges: surcharges,
            premiumMultiplier: premiumMultiplier,
            total: (baseFare + surcharges) * premiumMultiplier
        )
    }
}
```

---

## 📱 **iOS-Specific Features**

### **Background Location Tracking**
```swift
class LocationTrackingService: NSObject, CLLocationManagerDelegate {
    func startBackgroundTracking() {
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        // Implement battery-optimized tracking for drivers
    }
}
```

### **Push Notifications**
- **Driver**: Incoming ride requests, route updates
- **Rider**: Driver matches, pickup ETA, journey updates
- **Both**: Emergency alerts, payment confirmations

### **Privacy Compliance**
- **Location Data**: 30-day auto-purge policy
- **Audio Recordings**: Opt-in only, encrypted storage
- **GDPR Compliance**: Data export/deletion capabilities

---

## 🧪 **Testing Strategy**

### **Unit Tests (≥80% Coverage)**
- **Matching Algorithm**: Edge cases, gender filtering, capacity constraints
- **Geospatial Calculations**: Route buffers, isochron polygons, intersections
- **Payment Logic**: Fare calculations, surge pricing, cost-sharing validation
- **Safety Features**: Gender pool enforcement, verification status

### **Integration Tests**
- **Firebase Integration**: Real-time data sync, offline scenarios
- **Mapbox Navigation**: Route planning, real-time traffic updates
- **Stripe Payments**: End-to-end payment flows, webhook handling
- **LiveKit Audio**: Multi-participant calls, connection recovery

### **MockServices for Development**
```swift
public class MockRideSharingService: GliteRideSharingServicing {
    // Simulate realistic scenarios:
    // - Available drivers in different areas
    // - Multi-hop journey planning
    // - Network connectivity issues
    // - Payment processing delays
}
```

---

## 📈 **Implementation Timeline**

### **Phase 1: Foundation (Weeks 1-3)**
- ✅ Create SPM packages structure
- ✅ Implement core service protocols
- ✅ Set up Firebase integration
- ✅ Basic location tracking & map display
- ✅ User authentication & profile management

### **Phase 2: Core Matching (Weeks 4-6)**
- ✅ Mapbox route planning integration
- ✅ Radar isochron polygon calculations
- ✅ Single-hop matching algorithm
- ✅ Gender-based filtering system
- ✅ Basic driver/rider UI flows

### **Phase 3: Advanced Features (Weeks 7-9)**
- ✅ Multi-hop journey planning
- ✅ Anti-congestion pickup zones
- ✅ Capacity constraints (seats, luggage, pets)
- ✅ Premium options system
- ✅ LiveKit audio integration

### **Phase 4: Safety & Payments (Weeks 10-12)**
- ✅ Stripe payment integration
- ✅ Identity verification system
- ✅ Emergency features (SOS, recording)
- ✅ Background location tracking
- ✅ Push notifications

### **Phase 5: Polish & Launch (Weeks 13-15)**
- ✅ Comprehensive testing suite
- ✅ Performance optimization
- ✅ UI/UX refinements
- ✅ Beta testing with real users
- ✅ App Store submission preparation

---

## 🎯 **Success Metrics**

### **Technical Performance**
- **Matching Speed**: <2 seconds for single-hop, <5 seconds for multi-hop
- **Location Accuracy**: ±3 meters for pickup zones
- **Audio Quality**: <100ms latency for LiveKit calls
- **Battery Efficiency**: <10% drain per hour for active drivers

### **User Experience**
- **Match Success Rate**: ≥80% of ride requests matched
- **Pickup ETA Accuracy**: ±2 minutes actual vs. estimated
- **Safety Incidents**: Zero gender pool violations
- **User Satisfaction**: ≥4.7/5 rating

### **Business Metrics**
- **Legal Compliance**: Zero curb violation fines
- **Cost-sharing Model**: Average 60% cost reduction vs. traditional taxis
- **Driver Utilization**: ≥40% of route capacity utilized
- **Platform Growth**: 10K+ active users within 6 months

---

## 📋 **Deliverables Checklist**

### **iOS Packages**
- [ ] **GliteRideSharingService** - Complete service layer
- [ ] **GliteRideSharingFeature** - Full UI implementation
- [ ] **Integration Tests** - Comprehensive test coverage
- [ ] **MockServices** - Development & preview support

### **External Integrations**
- [ ] **Firebase Setup** - Auth, Firestore, Cloud Functions
- [ ] **Mapbox Integration** - Maps, navigation, curb data
- [ ] **Radar Integration** - Geofencing, isochron calculations
- [ ] **Stripe Setup** - Payments, identity verification
- [ ] **LiveKit Configuration** - Real-time audio infrastructure

### **Documentation**
- [ ] **API Documentation** - Service protocols & models
- [ ] **Architecture Guide** - System design & data flow
- [ ] **Integration Guide** - External service setup
- [ ] **User Manual** - Feature usage & safety guidelines

---

## 🔍 **Detailed Algorithm Specifications**

### **Route Buffer Generation**
```swift
class RouteBufferGenerator {
    func createBuffer(for route: Route, width: Double) -> RouteBuffer {
        // 1. Convert route polyline to coordinate array
        // 2. Apply Douglas-Peucker algorithm for simplification
        // 3. Generate perpendicular offset lines at buffer distance
        // 4. Create convex hull polygon from offset points
        // 5. Validate buffer doesn't exceed legal road boundaries
        // 6. Return GeoJSON polygon with metadata
    }
}
```

### **Isochron Polygon Calculation**
```swift
class IsochronCalculator {
    func calculateWalkingIsochron(
        from center: CLLocationCoordinate2D,
        maxWalkingTime: TimeInterval
    ) async -> IsochronPolygon {
        // Use Radar API for precise pedestrian routing
        // Account for elevation changes, sidewalk availability
        // Generate time-based accessibility polygon
        // Cache results for performance optimization
    }
    
    func calculateDrivingIsochron(
        from center: CLLocationCoordinate2D,
        arrivalTime: TimeInterval,
        trafficConditions: TrafficConditions
    ) async -> IsochronPolygon {
        // Real-time traffic-aware driving time calculation
        // Account for traffic lights, congestion patterns
        // Generate arrival time boundary polygon
    }
}
```

### **Geofencing Implementation**
```swift
class GeofenceManager {
    func setupGeofences(for rider: RideRequest) async {
        // Create geofence around walking isochron
        // Monitor for driver entries within driving isochron
        // Trigger matching algorithm when conditions met
        // Handle geofence exit events for missed pickups
    }
    
    func monitorDriverApproach(
        driver: Driver,
        toward pickupZone: PickupZone
    ) async {
        // Track driver's approach to pickup zone
        // Estimate arrival time based on current traffic
        // Notify rider when driver is within walking time
        // Handle route deviations and recalculation
    }
}
```

---

## 🚀 **Advanced Features**

### **Predictive Matching**
```swift
class PredictiveMatchingEngine {
    func predictDemand(
        for location: CLLocationCoordinate2D,
        at time: Date
    ) async -> DemandPrediction {
        // Use historical data and ML models
        // Predict ride demand 10-15 minutes ahead
        // Suggest optimal driver positioning
        // Account for events, weather, time patterns
    }
    
    func suggestMultiHopRoutes(
        for request: RideRequest
    ) async -> [PredictedJourney] {
        // Proactively plan multi-hop journeys
        // Use historical success rates for route segments
        // Optimize for minimal transfer walking distance
        // Predict driver availability for each leg
    }
}
```

### **Dynamic Pricing**
```swift
class DynamicPricingEngine {
    func calculateDynamicFare(
        for journey: Journey,
        currentConditions: MarketConditions
    ) async -> FareBreakdown {
        // Base cost-sharing fare calculation
        // Apply supply/demand multipliers (max 2x)
        // Account for distance, time, complexity
        // Include premium feature surcharges
        // Ensure legal compliance (not taxi rates)
    }
}
```

### **Real-time Optimization**
```swift
class RealTimeOptimizer {
    func optimizePickupSequence(
        for driver: Driver,
        requests: [RideRequest]
    ) async -> OptimizedSequence {
        // Traveling salesman optimization
        // Minimize total detour distance
        // Respect passenger pickup time windows
        // Account for vehicle capacity constraints
        // Ensure gender pool consistency
    }
    
    func rebalanceSupply(
        in region: GeographicRegion
    ) async -> [DriverSuggestion] {
        // Identify supply/demand imbalances
        // Suggest driver repositioning
        // Predict hotspots before demand peaks
        // Optimize network-wide efficiency
    }
}
```

---

## 🌟 **Premium Features Implementation**

### **Vehicle Preferences**
```swift
struct PremiumOptions {
    let vehicleType: VehicleType? // luxury, electric, spacious
    let amenities: [Amenity] // AC, heating, WiFi, chargers
    let restrictions: [Restriction] // non-smoking, no pets, quiet
    let exclusivity: Bool // solo ride, no other passengers
    let maxWalkingDistance: Double // premium users can request shorter walks
}
```

### **Luggage & Cargo Management**
```swift
class CargoManager {
    func assessCargoCompatibility(
        vehicle: Vehicle,
        cargoRequests: [CargoRequest]
    ) -> CargoCompatibility {
        // Check trunk space availability
        // Validate item size constraints
        // Account for passenger luggage
        // Consider fragile/valuable items
        // Ensure security for premium cargo
    }
}
```

### **Child Safety Features**
```swift
class ChildSafetyManager {
    func validateChildSeatRequirements(
        children: [Child],
        availableSeats: [ChildSeat]
    ) -> SafetyValidation {
        // Check age/weight compatibility
        // Ensure proper installation
        // Validate safety certifications
        // Account for multiple children
        // Handle infant carrier requirements
    }
}
```

---

## 📊 **Analytics & Monitoring**

### **Real-time Metrics**
- **Match Success Rate**: By time of day, location, gender
- **Pickup Time Accuracy**: Actual vs. estimated arrival times
- **Route Efficiency**: Detour distance vs. direct route
- **User Satisfaction**: Rating correlation with features
- **Safety Incidents**: Tracking and prevention metrics

### **Performance Dashboards**
```swift
class AnalyticsService {
    func trackMatchingPerformance(
        request: RideRequest,
        result: MatchingResult,
        timestamp: Date
    ) {
        // Log matching algorithm performance
        // Track user behavior patterns
        // Monitor system bottlenecks
        // Measure feature adoption rates
    }
    
    func generateSupplyDemandReport(
        for region: GeographicRegion,
        timeWindow: TimeInterval
    ) -> SupplyDemandReport {
        // Real-time supply/demand analysis
        // Identify optimization opportunities
        // Predict capacity requirements
        // Support dynamic pricing decisions
    }
}
```

---

This comprehensive plan provides a complete roadmap for implementing your live ride sharing iOS feature while maintaining consistency with your existing architecture patterns and ensuring all safety, legal, and technical requirements are met. 