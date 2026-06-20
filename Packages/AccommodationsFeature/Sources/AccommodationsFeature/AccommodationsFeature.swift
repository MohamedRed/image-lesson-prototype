import SwiftUI
import AccommodationsService

public struct AccommodationsFeature: View {
    @StateObject private var viewModel: AccommodationsViewModel
    
    public init(service: AccommodationsServiceProtocol = AccommodationsService()) {
        _viewModel = StateObject(wrappedValue: AccommodationsViewModel(service: service))
    }
    
    public var body: some View {
        NavigationStack {
            AccommodationsLandingView()
                .environmentObject(viewModel)
        }
    }
}

#Preview {
    AccommodationsFeature()
}