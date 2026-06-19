import Foundation

enum RidePreviewStates {
    static let destination = RideUIState()

    static var options: RideUIState {
        var state = base(destinationIndex: 2, tier: .pool)
        state.phase = .options
        return state
    }

    static var matching: RideUIState {
        var state = base(destinationIndex: 2, tier: .pool)
        state.phase = .matching
        return state
    }

    static var enroute: RideUIState {
        var state = base(destinationIndex: 2, tier: .pool)
        state.phase = .enroute
        state.carProgress = 0.56
        return state
    }

    static var payment: RideUIState {
        var state = base(destinationIndex: 2, tier: .pool)
        state.phase = .complete
        state.carProgress = 1
        state.rating = 4
        return state
    }

    static var receipt: RideUIState {
        var state = payment
        state.paid = true
        state.rating = 5
        return state
    }

    static var sos: RideUIState {
        var state = enroute
        state.isSOSPresented = true
        return state
    }

    private static func base(destinationIndex: Int, tier: RideTier) -> RideUIState {
        var state = RideUIState()
        let destination = RideFixtures.destinations[destinationIndex]
        state.destination = destination
        state.config.destinationName = destination.title
        state.config.tier = tier
        state.config.femaleOnly = tier == .pool
        state.tripSummary = RideTripSummary(configuration: state.config)
        state.driver = RideFixtures.driver
        return state
    }
}
