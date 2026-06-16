import SwiftUI

public enum LiiveRideFeature {
    public static func demoView(preferredColorScheme: ColorScheme? = .dark) -> some View {
        RideMapContainerView(mode: .demo, preferredColorScheme: preferredColorScheme)
    }
}
