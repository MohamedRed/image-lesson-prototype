import SwiftUI

public enum LiiveRideFeature {
    public static func appView(
        service: RideSharingServicing,
        preferredColorScheme: ColorScheme? = .dark
    ) -> some View {
        RideSharingView(service: service, preferredColorScheme: preferredColorScheme)
    }

    public static func mockAppView(preferredColorScheme: ColorScheme? = .dark) -> some View {
        RideSharingView(service: MockRideSharingService(), preferredColorScheme: preferredColorScheme)
    }

    @available(*, deprecated, renamed: "mockAppView(preferredColorScheme:)")
    public static func demoView(preferredColorScheme: ColorScheme? = .dark) -> some View {
        mockAppView(preferredColorScheme: preferredColorScheme)
    }
}
