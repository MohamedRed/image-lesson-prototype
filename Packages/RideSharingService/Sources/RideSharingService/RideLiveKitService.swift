import Combine
import Foundation
import LiveKitCore

@MainActor
public final class RideLiveKitService: RideSharingServicing {
    // MARK: Public publishers
    public var connectionState: AnyPublisher<ConnectionState, Never> { _conn.eraseToAnyPublisher() }
    public var rideEvents: AnyPublisher<RideEvent, Never> { _events.eraseToAnyPublisher() }
    public var driverAudioTrack: AnyPublisher<Track?, Never> {
        core.agentAudioTrack
            .map { $0 as Any? }
            .eraseToAnyPublisher()
    }
    public var audioTrack: AnyPublisher<Track?, Never> {
        core.audioTrack
            .map { $0 as Any? }
            .eraseToAnyPublisher()
    }
    public var isMicrophoneEnabled: AnyPublisher<Bool, Never> { core.isMicrophoneEnabled }

    // MARK: Private
    private let core: LiveKitCoreServicing
    private let _conn = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let _events = PassthroughSubject<RideEvent, Never>()
    private var cancellables = Set<AnyCancellable>()

    public init(apiBaseURL: URL = URL(string: "https://api.example.com")!) {
        self.core = LiveKitCoreService(apiBaseURL: apiBaseURL, feature: "ride-sharing")
        bridge()
    }

    // MARK: RideSharingServicing
    public func start() async throws {
        _conn.send(.connecting)
        do {
            try await core.start() // internally fetches token & joins room
            _conn.send(.connected)
            // For now emit simple matched event; in real app use Firestore data
            _events.send(.matched(driverName: "Driver", etaSeconds: 180))
        } catch {
            _conn.send(.failed(error.localizedDescription))
            throw error
        }
    }

    public func stop() {
        core.stop()
        _conn.send(.disconnected)
    }

    public func toggleMicrophone() async {
        await core.toggleMicrophone()
    }

    public func acceptRide() async throws {
        // No-op: Firestore listener already sets state; core remains connected
    }

    // MARK: Helpers
    private func bridge() {
        core.connectionState
            .map { state -> ConnectionState in
                switch state {
                case .connecting: return .connecting
                case .connected: return .connected
                case .connectedNoAgent: return .connectedNoCounterpart
                case .reconnecting: return .reconnecting
                case .disconnected: return .disconnected
                case .failed(let msg): return .failed(msg)
                }
            }
            .sink { [weak self] state in
                self?._conn.send(state)
            }
            .store(in: &cancellables)
        // Additional event bridging can be added later.
    }
} 