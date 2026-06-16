import SwiftUI

/// Different service modes for the ride-sharing feature
public enum ServiceMode {
    case demo
    case localDev(RideLocalDevConfig)
    case production

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
        switch mode {
        case .demo:
            self.service = MockRideSharingService()

        case .localDev:
            self.service = MockRideSharingService()

        case .production:
            self.service = MockRideSharingService()
        }
    }

    /// Legacy initializer for backward compatibility
    @available(*, deprecated, message: "Use init(mode:) instead")
    public init(service: RideSharingServicing) {
        self.service = service
        self.preferredColorScheme = .dark
    }

    /// Legacy initializer for backward compatibility
    @available(*, deprecated, message: "Use init(mode:) instead")
    public init(useRealService: Bool) {
        self.preferredColorScheme = .dark
        if useRealService {
            self.service = MockRideSharingService()
        } else {
            self.service = MockRideSharingService()
        }
    }

    public var body: some View {
        RideSharingView(service: service, preferredColorScheme: preferredColorScheme)
    }
}
