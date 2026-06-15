import Foundation

public protocol RideSharingServicing {
    func start() async throws
    func stop()
    func toggleMicrophone() async
}

public final class MockRideSharingService: RideSharingServicing {
    public init() {}

    public func start() async throws {}

    public func stop() {}

    public func toggleMicrophone() async {}
}

public struct RideLocalDevConfig: Equatable {
    public let useEmulators: Bool
    public let enablePayments: Bool
    public let enableRealLocation: Bool
    public let enableLiveAudio: Bool

    public init(
        useEmulators: Bool = true,
        enablePayments: Bool = false,
        enableRealLocation: Bool = false,
        enableLiveAudio: Bool = false
    ) {
        self.useEmulators = useEmulators
        self.enablePayments = enablePayments
        self.enableRealLocation = enableRealLocation
        self.enableLiveAudio = enableLiveAudio
    }

    public static let `default` = RideLocalDevConfig()
    public static let minimal = RideLocalDevConfig()
}
