import SwiftUI
import MarketplaceService
import MapboxMaps
import CoreLocation

/// Discovery view with city-first approach and neighborhood feeds
/// Per Section 1 differentiators and Section 3 MVP scope
public struct DiscoveryView: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    @Binding var selectedCity: String
    
    @State private var searchText = ""
    @State private var selectedCategory: ListingCategory?
    @State private var selectedNeighborhood: String?
    @State private var showingMap = false
    @State private var showingFilters = false
    @State private var priceRange: ClosedRange<Double> = 0...100000
    @State private var selectedCondition: ItemCondition?
    @State private var showingAISearch = false
    
    // Grid layout
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search bar with AI button
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search marketplace...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // AI Search button
                Button(action: { showingAISearch = true }) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                }
                
                // Filter button
                Button(action: { showingFilters = true }) {
                    Image(systemName: "slider.horizontal.3")
                }
            }
            .padding()
            
            // Neighborhood selector (Casablanca arrondissements)
            if selectedCity == "casablanca" {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        NeighborhoodChip(
                            name: "All",
                            isSelected: selectedNeighborhood == nil,
                            action: { selectedNeighborhood = nil }
                        )
                        
                        ForEach(casablancaNeighborhoods, id: \.self) { neighborhood in
                            NeighborhoodChip(
                                name: neighborhood,
                                isSelected: selectedNeighborhood == neighborhood,
                                action: { selectedNeighborhood = neighborhood }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }
            
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryChip(
                        category: nil,
                        isSelected: selectedCategory == nil,
                        action: { selectedCategory = nil }
                    )
                    
                    ForEach(ListingCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category,
                            action: { selectedCategory = category }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
            
            // View toggle
            HStack {
                Text("\(filteredListings.count) items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { showingMap.toggle() }) {
                    Image(systemName: showingMap ? "square.grid.2x2" : "map")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Content
            if showingMap {
                // Map view
                MapView(listings: filteredListings, selectedCity: selectedCity)
            } else {
                // Grid view
                ScrollView {
                    if filteredListings.isEmpty {
                        if #available(iOS 17.0, *) {
                            ContentUnavailableView(
                                "No items found",
                                systemImage: "magnifyingglass",
                                description: Text("Try adjusting your filters or search in different neighborhoods")
                            )
                            .padding(.top, 100)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("No items found")
                                    .font(.headline)
                                Text("Try adjusting your filters or search in different neighborhoods")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .padding(.top, 100)
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredListings) { listing in
                                NavigationLink(destination: ListingDetailView(listing: listing, viewModel: viewModel)) {
                                    ListingCardView(listing: listing)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            FiltersView(
                selectedCondition: $selectedCondition,
                priceRange: $priceRange,
                selectedCity: selectedCity
            )
        }
        .sheet(isPresented: $showingAISearch) {
            AISearchView(viewModel: viewModel, selectedCity: selectedCity)
        }
        .onAppear {
            loadListings()
        }
        .onChange(of: selectedCity) { _ in
            loadListings()
        }
        .onChange(of: selectedNeighborhood) { _ in
            loadListings()
        }
        .onChange(of: selectedCategory) { _ in
            loadListings()
        }
    }
    
    private var casablancaNeighborhoods: [String] {
        // Main arrondissements in Casablanca
        ["Maarif", "Gauthier", "Racine", "Bourgogne", "Ain Diab", "Anfa", "Sidi Belyout", "Hay Hassani", "Ain Sebaa", "Sidi Bernoussi"]
    }
    
    private var filteredListings: [Listing] {
        viewModel.discoveryListings.filter { listing in
            // Category filter
            if let category = selectedCategory, listing.category != category {
                return false
            }
            
            // Neighborhood filter
            if let neighborhood = selectedNeighborhood,
               listing.location.arrondissement != neighborhood {
                return false
            }
            
            // Condition filter
            if let condition = selectedCondition, listing.condition != condition {
                return false
            }
            
            // Price filter
            let price = Double(listing.price.amount)
            if price < priceRange.lowerBound || price > priceRange.upperBound {
                return false
            }
            
            // Search text filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                return listing.title.lowercased().contains(searchLower) ||
                       listing.description.lowercased().contains(searchLower)
            }
            
            return true
        }
    }
    
    private func loadListings() {
        Task {
            await viewModel.loadDiscoveryListings(
                cityId: selectedCity,
                neighborhood: selectedNeighborhood
            )
        }
    }
    
    private func performSearch() {
        Task {
            await viewModel.searchListings(
                query: searchText,
                cityId: selectedCity,
                category: selectedCategory,
                neighborhood: selectedNeighborhood
            )
        }
    }
}

// MARK: - Listing Card View

struct ListingCardView: View {
    let listing: Listing
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            AsyncImage(url: URL(string: listing.thumbnails.first ?? listing.images.first ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(height: 150)
            .clipped()
            .cornerRadius(8)
            
            // Price
            Text(listing.price.displayAmount)
                .font(.headline)
                .foregroundColor(.blue)
            
            // Title
            Text(listing.title)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            // Location and condition
            HStack {
                if let neighborhood = listing.location.arrondissement {
                    Label(neighborhood, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(listing.condition.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(conditionColor(listing.condition).opacity(0.2))
                    .foregroundColor(conditionColor(listing.condition))
                    .cornerRadius(4)
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
    }
    
    private func conditionColor(_ condition: ItemCondition) -> Color {
        switch condition {
        case .new: return .green
        case .likeNew: return .blue
        case .good: return .orange
        case .fair: return .red
        }
    }
}

// MARK: - Filter Chips

struct NeighborhoodChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct CategoryChip: View {
    let category: ListingCategory?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: categoryIcon)
                    .font(.caption)
                Text(category?.displayName ?? "All")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
    
    private var categoryIcon: String {
        guard let category = category else { return "square.grid.2x2" }
        
        switch category {
        case .electronics: return "tv"
        case .furniture: return "sofa"
        case .apparel: return "tshirt"
        case .carParts: return "car"
        case .books: return "book"
        case .sports: return "sportscourt"
        case .toys: return "teddybear"
        case .appliances: return "washer"
        case .jewelry: return "sparkle"
        case .art: return "paintpalette"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Map View

struct MapView: View {
    let listings: [Listing]
    let selectedCity: String
    
    var body: some View {
        // Simplified map view - would use MapboxMaps in production
        ZStack {
            Color(.systemGray6)
            
            VStack {
                Image(systemName: "map")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("Map View")
                Text("\(listings.count) listings in \(selectedCity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Filters View

struct FiltersView: View {
    @Binding var selectedCondition: ItemCondition?
    @Binding var priceRange: ClosedRange<Double>
    let selectedCity: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Condition") {
                    Picker("Condition", selection: $selectedCondition) {
                        Text("Any").tag(nil as ItemCondition?)
                        ForEach(ItemCondition.allCases, id: \.self) { condition in
                            Text(condition.displayName).tag(condition as ItemCondition?)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Price Range (MAD)") {
                    VStack {
                        HStack {
                            Text("\(Int(priceRange.lowerBound))")
                            Spacer()
                            Text("\(Int(priceRange.upperBound))")
                        }
                        .font(.caption)
                        
                        // Simplified slider - would use RangeSlider in production
                        Slider(value: .constant(50000), in: 0...100000)
                    }
                }
                
                Section("Delivery Options") {
                    Toggle("Meet-up available", isOn: .constant(true))
                    Toggle("Courier delivery", isOn: .constant(false))
                }
            }
            .navigationTitle("Filters")
            .navigationBarItems(
                leading: Button("Reset") {
                    selectedCondition = nil
                    priceRange = 0...100000
                },
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}

// MARK: - AI Search View

struct AISearchView: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    let selectedCity: String
    @State private var query = ""
    @State private var isSearching = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Ask AI to find what you're looking for")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top)
                
                // Example queries
                VStack(alignment: .leading, spacing: 12) {
                    Text("Try asking:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(exampleQueries, id: \.self) { example in
                        Button(action: { query = example }) {
                            Text("• \(example)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Query input
                VStack(alignment: .leading) {
                    Text("Your query:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $query)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Search button
                Button(action: performAISearch) {
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Label("Search with AI", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(query.isEmpty || isSearching)
            }
            .padding()
            .navigationTitle("AI Search")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
    
    private var exampleQueries: [String] {
        switch selectedCity {
        case "casablanca":
            return [
                "Vintage wooden desk under 1500 MAD near Maarif",
                "iPhone 12 or newer in good condition",
                "Baby stroller that's easy to fold",
                "Professional camera for photography beginner"
            ]
        case "rabat":
            return [
                "Office chair with lumbar support",
                "Kids bicycle for 8 year old",
                "Gaming console with controllers",
                "Kitchen appliances in working condition"
            ]
        default:
            return []
        }
    }
    
    private func performAISearch() {
        isSearching = true
        
        Task {
            await viewModel.performAISearch(query: query, cityId: selectedCity)
            isSearching = false
            dismiss()
        }
    }
}