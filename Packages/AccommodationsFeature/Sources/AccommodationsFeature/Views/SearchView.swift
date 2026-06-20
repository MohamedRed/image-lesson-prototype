import SwiftUI
import AccommodationsService
import MapboxMaps

struct SearchView: View {
    @EnvironmentObject private var viewModel: AccommodationsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilters = false
    @State private var showingMap = false
    @State private var showingDatePicker = false
    @State private var showingGuestPicker = false
    @State private var selectedProperty: AccommodationProperty?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchHeader
                
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.searchResults.isEmpty {
                    emptyStateView
                } else {
                    searchResults
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingMap.toggle()
                    } label: {
                        Image(systemName: showingMap ? "list.bullet" : "map")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FiltersView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showingGuestPicker) {
                GuestPickerView()
                    .environmentObject(viewModel)
            }
            .sheet(item: $selectedProperty) { property in
                PropertyDetailsView(property: property)
                    .environmentObject(viewModel)
            }
        }
        .onAppear {
            if viewModel.searchResults.isEmpty {
                viewModel.search()
            }
        }
    }
    
    private var searchHeader: some View {
        VStack(spacing: 16) {
            // Location search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Where to?", text: $viewModel.searchText)
                    .onSubmit {
                        viewModel.searchByText(viewModel.searchText)
                    }
                
                Button {
                    viewModel.useCurrentLocation()
                } label: {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Search criteria chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    SearchChip(
                        title: dateRangeText,
                        icon: "calendar"
                    ) {
                        showingDatePicker = true
                    }
                    
                    SearchChip(
                        title: guestText,
                        icon: "person.2"
                    ) {
                        showingGuestPicker = true
                    }
                    
                    SearchChip(
                        title: "Filters",
                        icon: "slider.horizontal.3",
                        hasValue: hasActiveFilters
                    ) {
                        showingFilters = true
                    }
                    
                    if viewModel.sortOption != .relevance {
                        SearchChip(
                            title: viewModel.sortOption.displayName,
                            icon: "arrow.up.arrow.down",
                            hasValue: true
                        ) {
                            // Show sort options
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
    
    private var searchResults: some View {
        Group {
            if showingMap {
                SearchMapView(properties: viewModel.searchResults) { property in
                    selectedProperty = property
                }
            } else {
                SearchListView(properties: viewModel.searchResults) { property in
                    selectedProperty = property
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching for accommodations...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bed.double")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No results found")
                .font(.headline)
            
            Text("Try adjusting your search criteria or location")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Clear Filters") {
                viewModel.selectedFilters = SearchFilters()
                viewModel.search()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        let checkIn = formatter.string(from: viewModel.searchRequest.dateRange.startDate)
        let checkOut = formatter.string(from: viewModel.searchRequest.dateRange.endDate)
        
        return "\(checkIn) - \(checkOut)"
    }
    
    private var guestText: String {
        let guests = viewModel.searchRequest.guests
        let adults = guests.adults
        let children = guests.children
        let rooms = guests.rooms
        
        var text = "\(adults) adult\(adults == 1 ? "" : "s")"
        if children > 0 {
            text += ", \(children) child\(children == 1 ? "" : "ren")"
        }
        if rooms > 1 {
            text += ", \(rooms) rooms"
        }
        
        return text
    }
    
    private var hasActiveFilters: Bool {
        let filters = viewModel.selectedFilters
        return filters.budgetMin != nil ||
               filters.budgetMax != nil ||
               filters.rating != nil ||
               filters.amenities?.isEmpty == false ||
               filters.types?.isEmpty == false
    }
}

// MARK: - Search Chip

struct SearchChip: View {
    let title: String
    let icon: String
    let hasValue: Bool
    let action: () -> Void
    
    init(title: String, icon: String, hasValue: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.hasValue = hasValue
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(hasValue ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(hasValue ? .accentColor : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search List View

struct SearchListView: View {
    let properties: [AccommodationProperty]
    let onPropertyTap: (AccommodationProperty) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(properties, id: \.id) { property in
                    PropertyRow(property: property) {
                        onPropertyTap(property)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Property Row

struct PropertyRow: View {
    let property: AccommodationProperty
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Property image
                AsyncImage(url: URL(string: property.photos.first?.url ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(property.name)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(property.address.formattedAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        if let rating = property.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                
                                Text(String(format: "%.1f", rating))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            if let priceRange = property.priceRange {
                                let minInt = NSDecimalNumber(decimal: priceRange.min).intValue
                                Text("$\(minInt)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("per night")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Amenities
                    HStack {
                        ForEach(Array(property.amenities.prefix(3)), id: \.self) { amenity in
                            Text(amenity)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                        }
                        
                        if property.amenities.count > 3 {
                            Text("+\(property.amenities.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SearchView()
        .environmentObject(AccommodationsViewModel())
}