import SwiftUI
import FoodDeliveryService

/// Search view for finding restaurants and menu items
public struct SearchView: View {
    @ObservedObject var viewModel: FoodDeliveryViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedRestaurant: Restaurant?
    @State private var isSearching = false
    
    private let recentSearches = ["Pizza", "Burger", "Sushi", "Moroccan", "Healthy"]
    private let popularCuisines = ["Italian", "American", "Japanese", "Moroccan", "French", "Indian", "Chinese", "Lebanese"]
    
    public init(viewModel: FoodDeliveryViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Search results or suggestions
                ScrollView {
                    if searchText.isEmpty {
                        searchSuggestions
                    } else {
                        searchResults
                    }
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
            }
            .sheet(item: $selectedRestaurant) { restaurant in
                RestaurantDetailView(restaurant: restaurant, viewModel: viewModel)
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search restaurants, cuisines, dishes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(20)
            
            if !searchText.isEmpty {
                Button("Search", action: performSearch)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var searchSuggestions: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Recent searches
            if !recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Searches")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recentSearches, id: \.self) { search in
                                SearchChip(text: search, icon: "clock") {
                                    searchText = search
                                    performSearch()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // Popular cuisines
            VStack(alignment: .leading, spacing: 12) {
                Text("Popular Cuisines")
                    .font(.headline)
                    .padding(.horizontal)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(popularCuisines, id: \.self) { cuisine in
                        CuisineSearchCard(cuisine: cuisine) {
                            searchText = cuisine
                            performSearch()
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Trending near you
            VStack(alignment: .leading, spacing: 12) {
                Text("Trending Near You")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 8) {
                    TrendingItem(title: "Pizza Margherita", subtitle: "From Pizza Palace", trend: "+15%")
                    TrendingItem(title: "Chicken Tagine", subtitle: "From Tagine Traditionnel", trend: "+12%")
                    TrendingItem(title: "California Roll", subtitle: "From Sushi Zen", trend: "+8%")
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isSearching {
                ForEach(0..<3) { _ in
                    RestaurantCardSkeleton()
                        .padding(.horizontal)
                }
            } else if viewModel.restaurants.isEmpty && !searchText.isEmpty {
                // No results
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        Text("No results found")
                            .font(.headline)
                        
                        Text("Try searching for something else")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Search results
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.restaurants) { restaurant in
                        RestaurantCard(restaurant: restaurant) {
                            selectedRestaurant = restaurant
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        
        Task {
            await viewModel.searchRestaurants(searchText)
            
            await MainActor.run {
                isSearching = false
            }
        }
    }
    
    private func clearSearch() {
        searchText = ""
        viewModel.restaurants = []
    }
}

// MARK: - Supporting Views

struct SearchChip: View {
    let text: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(text)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(16)
        }
    }
}

struct CuisineSearchCard: View {
    let cuisine: String
    let action: () -> Void
    
    private var cuisineEmoji: String {
        switch cuisine.lowercased() {
        case "italian": return "🍕"
        case "american": return "🍔"
        case "japanese": return "🍱"
        case "moroccan": return "🍛"
        case "french": return "🥐"
        case "indian": return "🍛"
        case "chinese": return "🥢"
        case "lebanese": return "🥙"
        default: return "🍽️"
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(cuisineEmoji)
                    .font(.title2)
                
                Text(cuisine)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .foregroundColor(.primary)
    }
}

struct TrendingItem: View {
    let title: String
    let subtitle: String
    let trend: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Text(trend)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    SearchView(viewModel: FoodDeliveryViewModel(service: MockFoodDeliveryService()))
}