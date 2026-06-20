import SwiftUI
import EventsService

struct EventSearchView: View {
    @ObservedObject var viewModel: EventsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedFilters = EventFilters()
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                HStack {
                    TextField("Search events...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            performSearch()
                        }
                    
                    Button("Search") {
                        performSearch()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(title: "Categories", isActive: !(selectedFilters.categories?.isEmpty ?? true)) {
                            // Show category picker
                        }
                        
                        FilterChip(title: "Price Range", isActive: selectedFilters.priceRange != nil) {
                            // Show price picker
                        }
                        
                        FilterChip(title: "Date Range", isActive: selectedFilters.dateRange != nil) {
                            // Show date picker
                        }
                        
                        FilterChip(title: "Indoor Only", isActive: selectedFilters.indoor == true) {
                            let toggledIndoor: Bool? = (selectedFilters.indoor == true) ? nil : true
                            selectedFilters = EventFilters(
                                categories: selectedFilters.categories,
                                priceRange: selectedFilters.priceRange,
                                dateRange: selectedFilters.dateRange,
                                cityId: selectedFilters.cityId,
                                neighborhood: selectedFilters.neighborhood,
                                indoor: toggledIndoor,
                                tags: selectedFilters.tags,
                                searchRadius: selectedFilters.searchRadius
                            )
                            performSearch()
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Results
                if viewModel.isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                    Spacer()
                    Text("No events found")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.searchResults) { event in
                                EventListItem(event: event) {
                                    viewModel.selectEvent(event)
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Search Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        searchText = ""
                        selectedFilters = EventFilters()
                        viewModel.clearSearch()
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        viewModel.searchQuery = searchText
        viewModel.currentFilters = selectedFilters
        Task {
            await viewModel.performSearch()
        }
    }
}

struct FilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isActive ? Color.accentColor : Color.gray.opacity(0.2)
                )
                .foregroundColor(
                    isActive ? .white : .primary
                )
                .cornerRadius(16)
        }
    }
}