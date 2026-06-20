import SwiftUI
import ActivitiesService

public struct ActivitiesFeatureView: View {
    @StateObject private var viewModel: ActivitiesViewModel
    @State private var selectedTab: ActivitiesTab = .discover
    
    public init(service: ActivitiesServiceProtocol? = nil) {
        _viewModel = StateObject(wrappedValue: ActivitiesViewModel(activitiesService: service ?? FirestoreActivitiesService()))
    }
    
    public var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                DiscoverView(viewModel: viewModel)
                    .tabItem {
                        Label("Discover", systemImage: "compass")
                    }
                    .tag(ActivitiesTab.discover)
                
                MyGroupsView(viewModel: viewModel)
                    .tabItem {
                        Label("My Groups", systemImage: "person.3")
                    }
                    .tag(ActivitiesTab.groups)
                
                BookingsView(viewModel: viewModel)
                    .tabItem {
                        Label("Bookings", systemImage: "calendar")
                    }
                    .tag(ActivitiesTab.bookings)
                
                PartnerMatchingView(viewModel: viewModel)
                    .tabItem {
                        Label("Find Partners", systemImage: "person.2")
                    }
                    .tag(ActivitiesTab.partners)
            }
            .navigationTitle(selectedTab.title)
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            viewModel.loadInitialData()
        }
    }
}

enum ActivitiesTab: CaseIterable {
    case discover
    case groups
    case bookings
    case partners
    
    var title: String {
        switch self {
        case .discover: return "Discover Activities"
        case .groups: return "My Groups"
        case .bookings: return "My Bookings"
        case .partners: return "Find Partners"
        }
    }
}

#Preview {
    ActivitiesFeatureView()
}