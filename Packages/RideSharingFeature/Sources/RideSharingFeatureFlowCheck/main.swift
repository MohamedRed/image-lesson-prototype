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

        viewModel.handle(.matchingComplete)
        try require(viewModel.state.phase == .enroute, "Matching completion should enter live ride.")

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
    private(set) var requestedDestinationName: String?
    private(set) var capturedDestinationName: String?

    func requestRide(with config: RideConfiguration) async throws -> RideSession {
        requestedDestinationName = config.destinationName
        return try await MockRideSharingService().requestRide(with: config)
    }

    func cancelRide(_ session: RideSession?) {}

    func setMicrophoneEnabled(_ enabled: Bool) async {}

    func capturePayment(amount: Double, destinationName: String) async throws -> RidePaymentReceipt {
        capturedDestinationName = destinationName
        return try await MockRideSharingService().capturePayment(amount: amount, destinationName: destinationName)
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
