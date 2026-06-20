import SwiftUI
import RideSharingFeature

/// Root container for Liive Super App with Home Dashboard
struct AppRootView: View {
    @AppStorage("dashboardStyle") private var dashboardStyle = "list"
    
    var body: some View {
        switch dashboardStyle {
        case "segmented":
            HomeDashboardSegmentedView()
        case "hybrid":
            HomeDashboardHybridView()
        default:
            HomeDashboardView()
        }
    }
}

#Preview {
    AppRootView()
} 