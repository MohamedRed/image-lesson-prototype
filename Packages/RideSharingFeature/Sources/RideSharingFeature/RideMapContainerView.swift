import SwiftUI

/// Different service modes for the ride-sharing feature
public enum ServiceMode {
    case demo
    case localDev(RideLocalDevConfig)

    /// Quick access to common configurations
    public static let localDefault = ServiceMode.localDev(.default)
    public static let localMinimal = ServiceMode.localDev(.minimal)
}

/// Root view that shows a full-screen live map with an overlay HUD.
public struct RideMapContainerView: View {
    private let service: RideSharingServicing
    private let preferredColorScheme: ColorScheme?

    // MARK: - Initializers

    /// Initialize with a specific service mode
    public init(mode: ServiceMode = .demo, preferredColorScheme: ColorScheme? = .dark) {
        self.preferredColorScheme = preferredColorScheme
        self.service = MockRideSharingService()
    }

    /// Initialize with an explicit service implementation for production wiring.
    public init(service: RideSharingServicing, preferredColorScheme: ColorScheme? = .dark) {
        self.service = service
        self.preferredColorScheme = preferredColorScheme
    }

    public var body: some View {
        RideSharingView(service: service, preferredColorScheme: preferredColorScheme)
    }
}
