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
    private var activeSession: RideSession?

    public init(
        service: RideSharingServicing = MockRideSharingService(),
        storage: UserDefaults = .standard,
        initialState: RideUIState? = nil
    ) {
        self.service = service
        self.storage = storage
        self.state = initialState ?? Self.restoreState(from: storage, key: storageKey)
        if initialState == nil {
            resumeTimelineIfNeeded()
        }
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
            mutate {
                $0.config.tier = tier
                $0.tripSummary = RideTripSummary(configuration: $0.config)
            }
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
            cancelActiveRide()
            mutate { $0.phase = .options }
        case .cancelRide:
            cancelRideAndReset()
        case .matchingComplete:
            startEnroute()
        case .setCarProgress(let progress):
            mutate { $0.carProgress = min(max(progress, 0), 1) }
        case .finishRide:
            cancelTimeline()
            mutate {
                $0.carProgress = 1
                $0.phase = .complete
            }
        case .toggleMic:
            mutate { $0.micEnabled.toggle() }
            let enabled = state.micEnabled
            Task { await service.setMicrophoneEnabled(enabled) }
        case .presentSOS(let presented):
            mutate { $0.isSOSPresented = presented }
        case .pay:
            capturePayment()
        case .rate(let rating):
            mutate { $0.rating = min(max(rating, 0), 5) }
            let boundedRating = state.rating
            let session = activeSession
            Task { await service.submitRating(boundedRating, session: session) }
        case .reset:
            resetRide()
        }
    }

    public func send(_ event: Event) {
        handle(event)
    }

    private func startMatching() {
        cancelActiveRide()
        let config = state.config
        mutate {
            $0.phase = .matching
            $0.carProgress = 0
            $0.paid = false
            $0.rating = 0
            $0.tripSummary = RideTripSummary(configuration: config)
        }
        matchingTask = Task { [weak self] in
            guard let self else { return }
            let session = try? await service.requestRide(with: config)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.activeSession = session
                if let session {
                    self.mutate {
                        $0.driver = session.driver
                        $0.tripSummary = session.tripSummary
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.handle(.matchingComplete)
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
        cancelTimeline()
        activeSession = nil
        mutate { $0 = RideUIState() }
    }

    private func cancelRideAndReset() {
        cancelActiveRide()
        mutate { $0 = RideUIState() }
    }

    private func cancelTimeline() {
        matchingTask?.cancel()
        rideTask?.cancel()
        matchingTask = nil
        rideTask = nil
    }

    private func cancelActiveRide() {
        cancelTimeline()
        service.cancelRide(activeSession)
        activeSession = nil
    }

    private func capturePayment() {
        let amount = state.config.price
        let destinationName = state.config.destinationName
        Task { [weak self] in
            guard let self else { return }
            _ = try? await service.capturePayment(amount: amount, destinationName: destinationName)
            await MainActor.run {
                self.mutate { $0.paid = true }
            }
        }
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
