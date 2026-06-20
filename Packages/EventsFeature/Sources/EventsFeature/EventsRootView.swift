import SwiftUI
import EventsService

/// Root view for the Events feature with discovery, search, and AI assistant
public struct EventsRootView: View {
    @StateObject private var viewModel = EventsViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            TabView {
                // Discovery Tab
                DiscoveryView(viewModel: viewModel)
                    .tabItem {
                        Label("Discover", systemImage: "calendar.badge.plus")
                    }
                
                // My Events Tab
                MyEventsView(viewModel: viewModel)
                    .tabItem {
                        Label("My Events", systemImage: "calendar")
                    }
                
                // Groups Tab
                MyGroupsView(viewModel: viewModel)
                    .tabItem {
                        Label("Groups", systemImage: "person.3")
                    }
                
                // AI Assistant Tab
                AIAssistantView(viewModel: viewModel)
                    .tabItem {
                        Label("AI", systemImage: "brain.head.profile")
                    }
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Search") {
                        viewModel.showSearch = true
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSearch) {
                EventSearchView(viewModel: viewModel)
            }
            .sheet(item: $viewModel.selectedEvent) { event in
                EventDetailView(
                    event: event,
                    viewModel: viewModel
                )
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
}

#if DEBUG
#Preview {
    EventsRootView()
}
#endif