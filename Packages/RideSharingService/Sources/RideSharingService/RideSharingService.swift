import Combine
import Foundation
// CoreLocation not required here; we encode coordinates as tuple of Doubles to keep Equatable
// Placeholder; replace with actual LiveKit import when integrating media layer

public typealias Track = Any

// MARK: - Public API

public protocol RideSharingServicing: Sendable {
    // Exposed publishers
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
    var rideEvents: AnyPublisher<RideEvent, Never> { get }
    var driverAudioTrack: AnyPublisher<Track?, Never> { get }
    var audioTrack: AnyPublisher<Track?, Never> { get }
    var isMicrophoneEnabled: AnyPublisher<Bool, Never> { get }

    // Lifecycle
    func start() async throws
    func stop()
    func toggleMicrophone() async
    func acceptRide() async throws
}

// MARK: - Data Models

public enum ConnectionState: Equatable {
    case connecting, connected, connectedNoCounterpart, reconnecting, disconnected, failed(String)

    public var description: String {
        switch self {
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .connectedNoCounterpart: return "Waiting for counterpart…"
        case .reconnecting: return "Reconnecting…"
        case .disconnected: return "Disconnected"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }
}

public enum RideEvent: Equatable {
    // Lifecycle
    case matched(driverName: String, etaSeconds: Int)
    case driverLocationUpdated(lat: Double, lon: Double)
    case userLocationUpdated(lat: Double, lon: Double)
    case riderPickupSoon(seconds: Int)
    case legCompleted(index: Int)
    case tripCompleted

    // Messaging
    case driverSaid(String, isFinal: Bool)
    case riderSaid(String, isFinal: Bool)

    // Pricing
    case priceUpdated(total: Double)
    case routeUpdated([(Double, Double)])
    case paymentStatusChanged(String)
    case journeyReceived(legs: Int)
    case routeSegmentsUpdated([[(Double, Double)]])
    case transferPointsUpdated([(Double, Double)])
    case walkingSegmentsUpdated([[(Double, Double)]])

    // Error
    case error(String)
}

extension RideEvent {
    public static func == (lhs: RideEvent, rhs: RideEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.matched(a, b), .matched(c, d)): return a == c && b == d
        case let (.driverLocationUpdated(la, lo), .driverLocationUpdated(lb, lp)): return la == lb && lo == lp
        case let (.userLocationUpdated(la, lo), .userLocationUpdated(lb, lp)): return la == lb && lo == lp
        case let (.riderPickupSoon(a), .riderPickupSoon(b)): return a == b
        case let (.legCompleted(a), .legCompleted(b)): return a == b
        case (.tripCompleted, .tripCompleted): return true
        case let (.driverSaid(a1, a2), .driverSaid(b1, b2)): return a1 == b1 && a2 == b2
        case let (.riderSaid(a1, a2), .riderSaid(b1, b2)): return a1 == b1 && a2 == b2
        case let (.priceUpdated(a), .priceUpdated(b)): return a == b
        case let (.routeUpdated(a), .routeUpdated(b)): return arraysEqual2D(a, b)
        case let (.paymentStatusChanged(a), .paymentStatusChanged(b)): return a == b
        case let (.journeyReceived(a), .journeyReceived(b)): return a == b
        case let (.routeSegmentsUpdated(a), .routeSegmentsUpdated(b)): return arraysEqual3D(a, b)
        case let (.transferPointsUpdated(a), .transferPointsUpdated(b)): return arraysEqual2D(a, b)
        case let (.walkingSegmentsUpdated(a), .walkingSegmentsUpdated(b)): return arraysEqual3D(a, b)
        case let (.error(a), .error(b)): return a == b
        default: return false
        }
    }
}

@inline(__always)
private func arraysEqual2D(_ lhs: [(Double, Double)], _ rhs: [(Double, Double)]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for (l, r) in zip(lhs, rhs) { if l.0 != r.0 || l.1 != r.1 { return false } }
    return true
}

@inline(__always)
private func arraysEqual3D(_ lhs: [[(Double, Double)]], _ rhs: [[(Double, Double)]]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for (la, ra) in zip(lhs, rhs) { if !arraysEqual2D(la, ra) { return false } }
    return true
}

// MARK: - Mock implementation (placeholder)

public final class MockRideSharingService: RideSharingServicing {
    public var connectionState: AnyPublisher<ConnectionState, Never> { _connection.eraseToAnyPublisher() }
    public var rideEvents: AnyPublisher<RideEvent, Never> { _events.eraseToAnyPublisher() }
    public var driverAudioTrack: AnyPublisher<Track?, Never> { _driverTrack.eraseToAnyPublisher() }
    public var audioTrack: AnyPublisher<Track?, Never> { _audioTrack.eraseToAnyPublisher() }
    public var isMicrophoneEnabled: AnyPublisher<Bool, Never> { _micEnabled.eraseToAnyPublisher() }

    private let _connection = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let _events = PassthroughSubject<RideEvent, Never>()
    private let _driverTrack = CurrentValueSubject<Track?, Never>(nil)
    private let _audioTrack = CurrentValueSubject<Track?, Never>(nil)
    private let _micEnabled = CurrentValueSubject<Bool, Never>(false)

    // Timer to simulate driver movement
    private var locationTimer: AnyCancellable?

    public init() {}

    public func start() async throws {
        _connection.send(.connected)
        
        // Immediately send user location (simulating SF location)
        let userLat = 37.7749
        let userLon = -122.4194
        _events.send(.userLocationUpdated(lat: userLat, lon: userLon))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self._events.send(.matched(driverName: "Alice", etaSeconds: 120))

            // Start emitting fake driver locations (simple line animation)
            var step = 0
            let baseLat = 37.773972
            let baseLon = -122.431297
            self.locationTimer = Timer.publish(every: 2.0, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    step += 1
                    let lat = baseLat + Double(step) * 0.0005
                    let lon = baseLon + Double(step) * 0.0005
                    self._events.send(.driverLocationUpdated(lat: lat, lon: lon))
                }
        }
    }

    public func stop() {
        _connection.send(.disconnected)
        locationTimer?.cancel()
        locationTimer = nil
    }

    public func toggleMicrophone() async {
        _micEnabled.send(!_micEnabled.value)
    }

    public func acceptRide() async throws {
        // Immediately simulate pickup soon
        _events.send(.riderPickupSoon(seconds: 120))
    }
}
 