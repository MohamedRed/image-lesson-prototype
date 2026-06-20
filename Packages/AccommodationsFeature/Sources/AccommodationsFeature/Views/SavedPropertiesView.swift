import SwiftUI
import AccommodationsService

struct SavedPropertiesView: View {
    @EnvironmentObject private var viewModel: AccommodationsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: SavedTab = .favorites
    @State private var showingPropertyDetails = false
    @State private var selectedProperty: AccommodationProperty?
    @State private var showingSearchFilter = false
    
    enum SavedTab: CaseIterable {
        case favorites
        case shortlists
        case recentlyViewed
        
        var title: String {
            switch self {
            case .favorites: return "Favorites"
            case .shortlists: return "Shortlists"
            case .recentlyViewed: return "Recent"
            }
        }
        
        var icon: String {
            switch self {
            case .favorites: return "heart"
            case .shortlists: return "list.bullet"
            case .recentlyViewed: return "clock"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                customTabBar
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedTab {
                        case .favorites:
                            favoritesSection
                        case .shortlists:
                            shortlistsSection
                        case .recentlyViewed:
                            recentlyViewedSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityLabel("Close saved properties")
                    .accessibilityHint("Returns to main accommodations screen")
                    .accessibilityIdentifier(AccessibilityIdentifiers.SavedProperties.closeButton)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSearchFilter = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filter saved properties")
                    .accessibilityHint("Opens filtering options for saved properties")
                    .accessibilityIdentifier(AccessibilityIdentifiers.SavedProperties.filterButton)
                }
            }
            .sheet(isPresented: $showingPropertyDetails) {
                if let property = selectedProperty {
                    PropertyDetailsView(property: property)
                        .environmentObject(viewModel)
                }
            }
            .sheet(isPresented: $showingSearchFilter) {
                SavedPropertiesFilterView()
                    .environmentObject(viewModel)
            }
        }
        .onAppear {
            viewModel.loadSavedProperties()
        }
    }
    
    // MARK: - Custom Tab Bar
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SavedTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab == selectedTab ? "\(tab.icon).fill" : tab.icon)
                            .font(.system(size: 20))
                            .accessibilityHidden(true)
                        
                        Text(tab.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(tab == selectedTab ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(tab.title)
                .accessibilityValue(tab == selectedTab ? "Selected" : "Not selected")
                .accessibilityHint("Double tap to view \(tab.title.lowercased())")
                .accessibilityAddTraits(tab == selectedTab ? [.isSelected] : [])
            }
        }
        .padding(.horizontal)
        .background(Color(.systemGray6))
        .overlay(
            Divider(),
            alignment: .bottom
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.SavedProperties.tabBar)
    }
    
    // MARK: - Favorites Section
    
    private var favoritesSection: some View {
        Group {
            if viewModel.favoriteProperties.isEmpty && !viewModel.isLoading {
                emptyStateView(
                    icon: "heart",
                    title: "No Favorites Yet",
                    subtitle: "Tap the heart icon on properties you'd like to save for later",
                    actionTitle: "Explore Properties",
                    action: {
                        dismiss()
                    }
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.favoriteProperties) { property in
                        SavedPropertyCard(
                            property: property,
                            showRemoveButton: true,
                            onTap: {
                                selectedProperty = property
                                showingPropertyDetails = true
                            },
                            onRemove: {
                                viewModel.removeFromFavorites(property.id)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Shortlists Section
    
    private var shortlistsSection: some View {
        Group {
            if viewModel.shortlists.isEmpty && !viewModel.isLoading {
                emptyStateView(
                    icon: "list.bullet",
                    title: "No Shortlists Yet",
                    subtitle: "Create shortlists to organize your saved properties by trip or category",
                    actionTitle: "Create Shortlist",
                    action: {
                        viewModel.createShortlist(name: "My Trip", description: "")
                    }
                )
            } else {
                LazyVStack(spacing: 16) {
                    createShortlistCard
                    
                    ForEach(viewModel.shortlists) { shortlist in
                        ShortlistCard(
                            shortlist: shortlist,
                            onTap: {
                                // Navigate to shortlist details
                            },
                            onEdit: {
                                // Edit shortlist
                            },
                            onDelete: {
                                viewModel.deleteShortlist(shortlist.id)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Recently Viewed Section
    
    private var recentlyViewedSection: some View {
        Group {
            if viewModel.recentlyViewedProperties.isEmpty && !viewModel.isLoading {
                emptyStateView(
                    icon: "clock",
                    title: "No Recent Views",
                    subtitle: "Properties you've recently viewed will appear here",
                    actionTitle: "Start Browsing",
                    action: {
                        dismiss()
                    }
                )
            } else {
                LazyVStack(spacing: 12) {
                    HStack {
                        Text("Last 30 days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Clear All") {
                            viewModel.clearRecentlyViewed()
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                    
                    ForEach(viewModel.recentlyViewedProperties) { property in
                        SavedPropertyCard(
                            property: property,
                            showRemoveButton: false,
                            onTap: {
                                selectedProperty = property
                                showingPropertyDetails = true
                            },
                            onRemove: nil
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Create Shortlist Card
    
    private var createShortlistCard: some View {
        Button {
            viewModel.createShortlist(name: "New Shortlist", description: "")
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Create New Shortlist")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Empty State View
    
    private func emptyStateView(
        icon: String,
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

// MARK: - Supporting Views

struct SavedPropertyCard: View {
    let property: AccommodationProperty
    let showRemoveButton: Bool
    let onTap: () -> Void
    let onRemove: (() -> Void)?
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: property.photos.first?.url ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(property.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(property.address.formattedAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack {
                        if let rating = property.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                
                                Text(String(format: "%.1f", rating))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Spacer()
                        
                        if let priceRange = property.priceRange {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("from $\(NSDecimalNumber(decimal: priceRange.min).intValue)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Text("per night")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                if showRemoveButton, let removeAction = onRemove {
                    Button {
                        removeAction()
                    } label: {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ShortlistCard: View {
    let shortlist: Shortlist
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingActionSheet = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shortlist.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if !shortlist.description.isEmpty {
                            Text(shortlist.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        showingActionSheet = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                HStack {
                    Label("\(shortlist.propertyIds.count) properties", systemImage: "building.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Updated \(shortlist.updatedAt, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Preview of first few properties
                if !shortlist.propertyIds.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(shortlist.propertyIds.prefix(3), id: \.self) { propertyId in
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 60, height: 40)
                                    .cornerRadius(4)
                            }
                            
                            if shortlist.propertyIds.count > 3 {
                                ZStack {
                                    Rectangle()
                                        .fill(Color(.systemGray4))
                                        .frame(width: 60, height: 40)
                                        .cornerRadius(4)
                                    
                                    Text("+\(shortlist.propertyIds.count - 3)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .confirmationDialog("Shortlist Options", isPresented: $showingActionSheet) {
            Button("Edit") {
                onEdit()
            }
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
            
            Button("Cancel", role: .cancel) { }
        }
    }
}

struct SavedPropertiesFilterView: View {
    @EnvironmentObject private var viewModel: AccommodationsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPriceRange: ClosedRange<Double> = 50...500
    @State private var selectedPropertyTypes: Set<AccommodationType> = []
    @State private var selectedRating: Double = 0
    @State private var sortBy: SortOption = .dateAdded
    
    enum SortOption: CaseIterable {
        case dateAdded
        case priceAscending
        case priceDescending
        case rating
        case alphabetical
        
        var title: String {
            switch self {
            case .dateAdded: return "Date Added"
            case .priceAscending: return "Price: Low to High"
            case .priceDescending: return "Price: High to Low"
            case .rating: return "Rating"
            case .alphabetical: return "Alphabetical"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Sort options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sort By")
                            .font(.headline)
                        
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                sortBy = option
                            } label: {
                                HStack {
                                    Text(option.title)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if sortBy == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Divider()
                    
                    // Price range
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Price Range")
                            .font(.headline)
                        
                        HStack {
                            Text("$\(Int(selectedPriceRange.lowerBound))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("$\(Int(selectedPriceRange.upperBound))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        RangeSlider(
                            range: $selectedPriceRange,
                            bounds: 0...1000,
                            step: 25
                        )
                    }
                    
                    Divider()
                    
                    // Property types
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Property Type")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(AccommodationType.allCases, id: \.self) { type in
                                Button {
                                    if selectedPropertyTypes.contains(type) {
                                        selectedPropertyTypes.remove(type)
                                    } else {
                                        selectedPropertyTypes.insert(type)
                                    }
                                } label: {
                                    HStack {
                                        Text(type.displayName)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if selectedPropertyTypes.contains(type) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.accentColor)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding()
                                    .background(selectedPropertyTypes.contains(type) ? 
                                              Color.accentColor.opacity(0.1) : Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Minimum rating
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Minimum Rating")
                            .font(.headline)
                        
                        HStack {
                            ForEach(1...5, id: \.self) { rating in
                                Button {
                                    selectedRating = Double(rating)
                                } label: {
                                    Image(systemName: selectedRating >= Double(rating) ? "star.fill" : "star")
                                        .font(.title2)
                                        .foregroundColor(selectedRating >= Double(rating) ? .yellow : .secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Spacer()
                            
                            if selectedRating > 0 {
                                Button("Clear") {
                                    selectedRating = 0
                                }
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applySortAndFilter()
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
    
    private func applySortAndFilter() {
        let mappedSort: SavedPropertiesFilter.SortOption
        switch sortBy {
        case .dateAdded: mappedSort = .dateAdded
        case .priceAscending: mappedSort = .priceAscending
        case .priceDescending: mappedSort = .priceDescending
        case .rating: mappedSort = .rating
        case .alphabetical: mappedSort = .alphabetical
        }
        let filter = SavedPropertiesFilter(
            priceRange: selectedPriceRange,
            propertyTypes: selectedPropertyTypes,
            minimumRating: selectedRating,
            sortBy: mappedSort
        )
        viewModel.applySavedPropertiesFilter(filter)
    }
}

// MARK: - Range Slider Component

struct RangeSlider: View {
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        VStack {
            HStack {
                Slider(
                    value: .init(
                        get: { range.lowerBound },
                        set: { newValue in
                            range = newValue...min(range.upperBound, bounds.upperBound)
                        }
                    ),
                    in: bounds,
                    step: step
                ) {
                    Text("Min Price")
                }
                
                Slider(
                    value: .init(
                        get: { range.upperBound },
                        set: { newValue in
                            range = max(range.lowerBound, bounds.lowerBound)...newValue
                        }
                    ),
                    in: bounds,
                    step: step
                ) {
                    Text("Max Price")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SavedPropertiesView()
            .environmentObject(AccommodationsViewModel())
    }
}