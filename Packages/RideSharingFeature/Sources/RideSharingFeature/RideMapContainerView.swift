import SwiftUI

/// Explicit service modes for the ride-sharing feature.
public enum ServiceMode {
    /// Fully offline demo data used by previews and local screenshots.
    case demo
    /// A caller-owned service for production, staging, or local emulator wiring.
    case service(RideSharingServicing)
}

/// Root view that shows a full-screen live map with an overlay HUD.
public struct RideMapContainerView: View {
    private let service: RideSharingServicing
    private let preferredColorScheme: ColorScheme?

    // MARK: - Initializers

    /// Initialize with a specific service mode.
    public init(mode: ServiceMode = .demo, preferredColorScheme: ColorScheme? = .dark) {
        switch mode {
        case .demo:
            self.init(service: MockRideSharingService(), preferredColorScheme: preferredColorScheme)
        case .service(let service):
            self.init(service: service, preferredColorScheme: preferredColorScheme)
        }
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
