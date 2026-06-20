import SwiftUI
import NewsService

public struct NewsRootView: View {
    @StateObject private var viewModel: NewsViewModel
    @State private var selectedTab: NewsSection = .good
    private let service: NewsServicing
    
    public init(service: NewsServicing? = nil) {
        let svc = service ?? FirestoreNewsService()
        self.service = svc
        self._viewModel = StateObject(wrappedValue: NewsViewModel(service: svc))
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sectionPicker
                
                TabView(selection: $selectedTab) {
                    EventListView(
                        events: viewModel.goodNews,
                        isLoading: viewModel.isLoadingGood,
                        section: .good,
                        onRefresh: { await viewModel.loadGoodNews() },
                        onLoadMore: { await viewModel.loadMoreGoodNews() }
                    )
                    .tag(NewsSection.good)
                    
                    EventListView(
                        events: viewModel.challengingNews,
                        isLoading: viewModel.isLoadingChallenging,
                        section: .challenging,
                        onRefresh: { await viewModel.loadChallengingNews() },
                        onLoadMore: { await viewModel.loadMoreChallengingNews() }
                    )
                    .tag(NewsSection.challenging)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("News & Perspectives")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showingSettings = true }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .navigationDestination(for: NewsEventSummary.self) { event in
                EventDetailView(eventId: event.id, service: service)
            }
            .sheet(isPresented: $viewModel.showingSettings) {
                NewsSettingsView(viewModel: viewModel)
            }
            .onAppear {
                Task {
                    await viewModel.loadInitialData()
                }
            }
        }
    }
    
    private var sectionPicker: some View {
        Picker("Section", selection: $selectedTab) {
            Label("Good News", systemImage: "sun.max.fill")
                .tag(NewsSection.good)
            Label("Challenging News", systemImage: "exclamationmark.triangle")
                .tag(NewsSection.challenging)
        }
        .pickerStyle(.segmented)
        .padding()
        .background(Color(.systemBackground))
    }
}

enum NewsSection: String, CaseIterable {
    case good = "good"
    case challenging = "challenging"
    
    var title: String {
        switch self {
        case .good: return "Good News"
        case .challenging: return "Challenging News"
        }
    }
    
    var icon: String {
        switch self {
        case .good: return "sun.max.fill"
        case .challenging: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .good: return .green
        case .challenging: return .orange
        }
    }
}