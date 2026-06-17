import SwiftUI
import RideSharingFeature

/// Standalone Liive Ride entry point for preview/testing.
struct RideSharingDemoView: View {
    var body: some View {
        LiiveRideFeature.mockAppView()
    }
}

struct RideSharingDemoView_Previews: PreviewProvider {
    static var previews: some View {
        RideSharingDemoView()
    }
}
