import Foundation
import RideSharingFeature

@main
struct RideSharingFeatureFlowCheck {
    @MainActor
    static func main() async throws {
        let suiteName = "RideSharingFeatureFlowCheck-\(UUID().uuidString)"
        guard let storage = UserDefaults(suiteName: suiteName) else {
            throw FlowCheckError.failed("Could not create isolated UserDefaults suite.")
        }
        storage.removePersistentDomain(forName: suiteName)
        defer { storage.removePersistentDomain(forName: suiteName) }

        let destination = RideDestination(
            id: "union-square",
            systemImage: "clock",
            color: "neutral",
            title: "Union Square",
            subtitle: "Geary & Powell"
        )

        let recordingService = RecordingRideService()
        _ = RideMapContainerView(mode: .service(recordingService), preferredColorScheme: nil)

        let viewModel = RideSharingViewModel(service: recordingService, storage: storage)
        viewModel.handle(.selectDestination(destination))
        try require(viewModel.state.phase == .options, "Destination selection should open ride options.")
        try require(viewModel.state.config.destinationName == "Union Square", "Destination name should persist into config.")

        viewModel.handle(.selectTier(.pool))
        viewModel.handle(.setFemaleOnly(true))
        try require(viewModel.state.config.isMultiLeg, "Pool tier should represent a multi-leg journey.")
        try require(viewModel.state.tripSummary.transferStatus != nil, "Pool tier should include transfer status.")

        let restoredOptions = RideSharingViewModel(service: MockRideSharingService(), storage: storage)
        try require(restoredOptions.state.phase == .options, "Options phase should restore from storage.")
        try require(restoredOptions.state.config.tier == .pool, "Selected tier should restore from storage.")
        try require(restoredOptions.state.config.femaleOnly, "Safety-pool preference should restore from storage.")

        viewModel.handle(.confirmPickup)
        try require(viewModel.state.phase == .matching, "Confirm pickup should enter matching.")
        try await waitUntil(
            recordingService.requestedDestinationName == "Union Square",
            message: "Injected service should receive ride requests."
        )
        try require(
            viewModel.state.activeSession?.voiceRoomName == "ride_mock_001",
            "Ride session should persist in UI state for restored service actions."
        )

        viewModel.handle(.matchingComplete)
        try require(viewModel.state.phase == .enroute, "Matching completion should enter live ride.")

        viewModel.handle(.locate)
        try require(viewModel.state.actionNotice?.title == "Location centered", "Locate action should expose an explicit standalone notice.")
        viewModel.handle(.callDriver)
        try require(viewModel.state.actionNotice?.title == "Phone integration required", "Call action should not be a silent no-op.")
        viewModel.handle(.messageDriver)
        try require(viewModel.state.actionNotice?.title == "Chat service required", "Message action should not be a silent no-op.")
        viewModel.handle(.dismissActionNotice)
        try require(viewModel.state.actionNotice == nil, "Dismiss notice should clear transient action copy.")

        viewModel.handle(.finishRide)
        try require(viewModel.state.phase == .complete, "Finishing ride should enter payment.")
        try require(viewModel.state.carProgress == 1, "Finished ride should place the car at route end.")

        viewModel.handle(.rate(8))
        try require(viewModel.state.rating == 5, "Rating should clamp to five stars.")

        viewModel.handle(.pay)
        try await waitUntil(viewModel.state.paid, message: "Payment should mark the ride paid.")
        try require(
            recordingService.capturedDestinationName == "Union Square",
            "Injected service should receive payment capture requests."
        )

        let failingViewModel = RideSharingViewModel(
            service: FailingRideService(),
            storage: storage,
            initialState: RideUIState()
        )
        failingViewModel.handle(.selectDestination(destination))
        failingViewModel.handle(.confirmPickup)
        try require(failingViewModel.state.phase == .matching, "Failed request should first enter matching.")
        try await waitUntil(
            failingViewModel.state.phase == .options,
            message: "Failed request should return to options instead of entering a live ride."
        )

        var paymentFailureState = RideUIState()
        paymentFailureState.phase = .complete
        paymentFailureState.config.destinationName = "Union Square"
        let paymentFailingService = PaymentFailingRideService()
        let paymentFailureViewModel = RideSharingViewModel(
            service: paymentFailingService,
            storage: storage,
            initialState: paymentFailureState
        )
        paymentFailureViewModel.handle(.pay)
        try await waitUntil(
            paymentFailingService.didAttemptPayment,
            message: "Failed payment service should still be invoked."
        )
        try require(!paymentFailureViewModel.state.paid, "Failed payment should not mark the ride paid.")

        let restoredConfiguration = RideConfiguration(destinationName: "Union Square")
        let restoredSession = RideSession(
            id: "restored_ride",
            voiceRoomName: "ride_restored",
            driverName: "John Driver",
            driverRating: 4.8,
            vehicle: "Toyota Camry · Blue",
            plate: "ABC 123",
            tripSummary: RideTripSummary(configuration: restoredConfiguration)
        )
        var restoredRideState = RideUIState()
        restoredRideState.phase = .enroute
        restoredRideState.activeSession = restoredSession
        let restoredRideService = RecordingRideService()
        let restoredRideViewModel = RideSharingViewModel(
            service: restoredRideService,
            storage: storage,
            initialState: restoredRideState
        )
        restoredRideViewModel.handle(.cancelRide)
        try require(
            restoredRideService.cancelledSessionId == restoredSession.id,
            "Restored active rides should cancel with their persisted service session."
        )

        var restoredMatchingState = RideUIState()
        restoredMatchingState.phase = .matching
        restoredMatchingState.activeSession = restoredSession
        let restoredMatchingSuiteName = "RideSharingFeatureFlowCheck-Matching-\(UUID().uuidString)"
        guard let restoredMatchingStorage = UserDefaults(suiteName: restoredMatchingSuiteName) else {
            throw FlowCheckError.failed("Could not create matching restore UserDefaults suite.")
        }
        restoredMatchingStorage.removePersistentDomain(forName: restoredMatchingSuiteName)
        defer { restoredMatchingStorage.removePersistentDomain(forName: restoredMatchingSuiteName) }
        restoredMatchingStorage.set(
            try JSONEncoder().encode(restoredMatchingState),
            forKey: "liive-ride-state"
        )
        let restoredMatchingService = RecordingRideService()
        let restoredMatchingViewModel = RideSharingViewModel(
            service: restoredMatchingService,
            storage: restoredMatchingStorage
        )
        await Task.yield()
        try require(
            restoredMatchingService.requestCount == 0,
            "Restored matching sessions should resume without requesting a replacement ride."
        )
        restoredMatchingViewModel.handle(.cancelMatching)
        try require(
            restoredMatchingService.cancelledSessionId == restoredSession.id,
            "Restored matching sessions should cancel with their persisted service session."
        )
        try require(
            restoredMatchingViewModel.state.activeSession == nil,
            "Cancelled matching sessions should clear persisted active session state."
        )
    }

    @MainActor
    private static func waitUntil(
        _ condition: @autoclosure @escaping () -> Bool,
        timeout: TimeInterval = 1,
        message: String
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try require(condition(), message)
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw FlowCheckError.failed(message)
        }
    }
}

private final class RecordingRideService: RideSharingServicing {
    private(set) var requestCount = 0
    private(set) var requestedDestinationName: String?
    private(set) var capturedDestinationName: String?
    private(set) var cancelledSessionId: String?

    func requestRide(with config: RideConfiguration) async throws -> RideSession {
        requestCount += 1
        requestedDestinationName = config.destinationName
        return try await MockRideSharingService().requestRide(with: config)
    }

    func cancelRide(_ session: RideSession?) {
        cancelledSessionId = session?.id
    }

    func setMicrophoneEnabled(_ enabled: Bool) async {}

    func capturePayment(amount: Double, destinationName: String) async throws -> RidePaymentReceipt {
        capturedDestinationName = destinationName
        return try await MockRideSharingService().capturePayment(amount: amount, destinationName: destinationName)
    }

    func submitRating(_ rating: Int, session: RideSession?) async {}
}

private struct FailingRideService: RideSharingServicing {
    func requestRide(with config: RideConfiguration) async throws -> RideSession {
        throw FlowCheckError.failed("Synthetic ride request failure.")
    }

    func cancelRide(_ session: RideSession?) {}

    func setMicrophoneEnabled(_ enabled: Bool) async {}

    func capturePayment(amount: Double, destinationName: String) async throws -> RidePaymentReceipt {
        throw FlowCheckError.failed("Synthetic payment failure.")
    }

    func submitRating(_ rating: Int, session: RideSession?) async {}
}

private final class PaymentFailingRideService: RideSharingServicing {
    private(set) var didAttemptPayment = false

    func requestRide(with config: RideConfiguration) async throws -> RideSession {
        try await MockRideSharingService().requestRide(with: config)
    }

    func cancelRide(_ session: RideSession?) {}

    func setMicrophoneEnabled(_ enabled: Bool) async {}

    func capturePayment(amount: Double, destinationName: String) async throws -> RidePaymentReceipt {
        didAttemptPayment = true
        throw FlowCheckError.failed("Synthetic payment failure.")
    }

    func submitRating(_ rating: Int, session: RideSession?) async {}
}

private enum FlowCheckError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}
