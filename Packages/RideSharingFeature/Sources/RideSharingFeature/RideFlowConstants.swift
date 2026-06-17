import Foundation

enum RideFlowTiming {
    static let matchingDelayNanoseconds: UInt64 = 2_600_000_000
    static let rideDuration: TimeInterval = 11
    static let progressTickNanoseconds: UInt64 = 80_000_000
}

enum RidePersistence {
    static let stateStorageKey = "liive-ride-state"
}
