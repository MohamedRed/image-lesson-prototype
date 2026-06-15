import Foundation

@MainActor
public final class RideSharingViewModel: ObservableObject {
    public enum Event {
        case selectDestination(RideDestination)
        case backToDestination
        case selectTier(RideTier)
        case setPassengers(Int)
        case setBags(Int)
        case setFemaleOnly(Bool)
        case setChildSeat(Bool)
        case confirmPickup
        case cancelMatching
        case cancelRide
        case matchingComplete
        case setCarProgress(Double)
        case finishRide
        case toggleMic
        case presentSOS(Bool)
        case pay
        case rate(Int)
        case reset
    }

    @Published public private(set) var state: RideUIState

    private let service: RideSharingServicing
    private let storage: UserDefaults
    private let storageKey = "liive-ride-state"
    private var matchingTask: Task<Void, Never>?
    private var rideTask: Task<Void, Never>?

    public init(service: RideSharingServicing = MockRideSharingService(), storage: UserDefaults = .standard) {
        self.service = service
        self.storage = storage
        self.state = Self.restoreState(from: storage, key: storageKey)
        resumeTimelineIfNeeded()
    }

    deinit {
        matchingTask?.cancel()
        rideTask?.cancel()
    }

    public func handle(_ event: Event) {
        switch event {
        case .selectDestination(let destination):
            mutate {
                $0.destination = destination
                $0.config.destinationName = destination.title
                $0.phase = .options
            }
        case .backToDestination:
            mutate { $0.phase = .destination }
        case .selectTier(let tier):
            mutate { $0.config.tier = tier }
        case .setPassengers(let count):
            mutate { $0.config.passengers = min(max(count, 1), 4) }
        case .setBags(let count):
            mutate { $0.config.bags = min(max(count, 0), 4) }
        case .setFemaleOnly(let enabled):
            mutate { $0.config.femaleOnly = enabled }
        case .setChildSeat(let enabled):
            mutate { $0.config.childSeat = enabled }
        case .confirmPickup:
            startMatching()
        case .cancelMatching:
            stopActiveRide()
            mutate { $0.phase = .options }
        case .cancelRide:
            resetRide()
        case .matchingComplete:
            startEnroute()
        case .setCarProgress(let progress):
            mutate { $0.carProgress = min(max(progress, 0), 1) }
        case .finishRide:
            stopActiveRide()
            mutate {
                $0.carProgress = 1
                $0.phase = .complete
            }
        case .toggleMic:
            mutate { $0.micEnabled.toggle() }
            Task { await service.toggleMicrophone() }
        case .presentSOS(let presented):
            mutate { $0.isSOSPresented = presented }
        case .pay:
            mutate { $0.paid = true }
        case .rate(let rating):
            mutate { $0.rating = min(max(rating, 0), 5) }
        case .reset:
            resetRide()
        }
    }

    public func send(_ event: Event) {
        handle(event)
    }

    private func startMatching() {
        matchingTask?.cancel()
        rideTask?.cancel()
        mutate {
            $0.phase = .matching
            $0.carProgress = 0
            $0.paid = false
            $0.rating = 0
        }
        Task { try? await service.start() }
        matchingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.handle(.matchingComplete)
            }
        }
    }

    private func startEnroute() {
        matchingTask?.cancel()
        mutate {
            $0.phase = .enroute
            $0.carProgress = 0
        }
        startRideTimeline(from: 0)
    }

    private func startRideTimeline(from initialProgress: Double) {
        rideTask?.cancel()
        rideTask = Task { [weak self] in
            let start = Date()
            let duration = 11.0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 80_000_000)
                let elapsed = Date().timeIntervalSince(start)
                let progress = min(1, initialProgress + elapsed / duration)
                await MainActor.run {
                    self?.handle(.setCarProgress(progress))
                }
                if progress >= 1 { break }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.handle(.finishRide)
            }
        }
    }

    private func resetRide() {
        stopActiveRide()
        mutate { $0 = RideUIState() }
    }

    private func stopActiveRide() {
        matchingTask?.cancel()
        rideTask?.cancel()
        matchingTask = nil
        rideTask = nil
        service.stop()
    }

    private func resumeTimelineIfNeeded() {
        switch state.phase {
        case .matching:
            startMatching()
        case .enroute:
            startRideTimeline(from: state.carProgress)
        case .destination, .options, .complete:
            break
        }
    }

    private func mutate(_ update: (inout RideUIState) -> Void) {
        update(&state)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        storage.set(data, forKey: storageKey)
    }

    private static func restoreState(from storage: UserDefaults, key: String) -> RideUIState {
        guard
            let data = storage.data(forKey: key),
            let state = try? JSONDecoder().decode(RideUIState.self, from: data)
        else {
            return RideUIState()
        }
        return state
    }
}
