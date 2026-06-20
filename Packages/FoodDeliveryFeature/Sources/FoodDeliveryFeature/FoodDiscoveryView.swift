import SwiftUI
import FoodDeliveryService

/// Main food discovery view showing restaurants and cuisines
public struct FoodDiscoveryView: View {
    @StateObject private var viewModel: FoodDeliveryViewModel
    @State private var showingSearch = false
    @State private var selectedRestaurant: Restaurant?
    
    private let cuisines = [
        ("🍕", "Pizza", "pizza"),
        ("🍔", "Burgers", "burgers"),
        ("🍱", "Japanese", "japanese"),
        ("🌯", "Mediterranean", "mediterranean"),
        ("🍛", "Moroccan", "moroccan"),
        ("🍗", "Fast Food", "fastfood"),
        ("🥗", "Healthy", "healthy"),
        ("🍰", "Desserts", "desserts")
    ]
    
    public init(service: FoodDeliveryServicing) {
        _viewModel = StateObject(wrappedValue: FoodDeliveryViewModel(service: service))
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with location and search
                    headerSection
                    
                    // Cuisines grid
                    cuisinesSection
                    
                    // Featured restaurants
                    if !viewModel.featuredRestaurants.isEmpty {
                        featuredRestaurantsSection
                    }
                    
                    // All restaurants
                    allRestaurantsSection
                }
                .padding(.vertical)
            }
            .refreshable {
                await viewModel.loadNearbyRestaurants()
            }
            .navigationTitle("Food Delivery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: CartView(viewModel: viewModel)) {
                        CartButtonView(itemCount: viewModel.cartItemCount)
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                SearchView(viewModel: viewModel)
            }
            .sheet(item: $selectedRestaurant) { restaurant in
                RestaurantDetailView(restaurant: restaurant, viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadNearbyRestaurants()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deliver to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("Current Location")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                Button(action: { showingSearch = true }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var cuisinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cuisines")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(Array(cuisines.enumerated()), id: \.offset) { index, cuisine in
                    CuisineCard(
                        emoji: cuisine.0,
                        name: cuisine.1,
                        tag: cuisine.2
                    ) {
                        Task {
                            await viewModel.loadRestaurantsByCuisine(cuisine.2)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var featuredRestaurantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.featuredRestaurants) { restaurant in
                        FeaturedRestaurantCard(restaurant: restaurant) {
                            selectedRestaurant = restaurant
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var allRestaurantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.selectedCuisine?.capitalized ?? "All Restaurants")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.selectedCuisine != nil {
                    Button("Show All") {
                        viewModel.selectedCuisine = nil
                        Task {
                            await viewModel.loadNearbyRestaurants()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            if viewModel.isLoading && viewModel.restaurants.isEmpty {
                ForEach(0..<5) { _ in
                    RestaurantCardSkeleton()
                        .padding(.horizontal)
                }
            } else {
                ForEach(viewModel.restaurants) { restaurant in
                    RestaurantCard(restaurant: restaurant) {
                        selectedRestaurant = restaurant
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct CuisineCard: View {
    let emoji: String
    let name: String
    let tag: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.title2)
                
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .foregroundColor(.primary)
    }
}

struct FeaturedRestaurantCard: View {
    let restaurant: Restaurant
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: restaurant.logoUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 120, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("\(restaurant.rating, specifier: "%.1f")")
                                .font(.caption)
                        }
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(restaurant.avgPrepMinutes)-\(restaurant.avgPrepMinutes + 10) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(restaurant.cuisineTags.prefix(2).joined(separator: " • "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 120)
        }
        .foregroundColor(.primary)
    }
}

struct RestaurantCard: View {
    let restaurant: Restaurant
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: restaurant.logoUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(restaurant.name)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if !restaurant.isOpen {
                            Text("Closed")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(restaurant.cuisineTags.prefix(3).joined(separator: " • "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("\(restaurant.rating, specifier: "%.1f")")
                                .font(.subheadline)
                        }
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(restaurant.avgPrepMinutes)-\(restaurant.avgPrepMinutes + 10) min")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(restaurant.deliveryFeePolicy.baseMAD)) MAD delivery")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .foregroundColor(.primary)
        .disabled(!restaurant.isOpen)
        .opacity(restaurant.isOpen ? 1.0 : 0.6)
    }
}

struct RestaurantCardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
                .redacted(reason: .placeholder)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .redacted(reason: .placeholder)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)
                    .redacted(reason: .placeholder)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 12)
                    .frame(maxWidth: 100)
                    .redacted(reason: .placeholder)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct CartButtonView: View {
    let itemCount: Int
    
    var body: some View {
        ZStack {
            Image(systemName: "cart")
                .font(.title2)
                .foregroundColor(.blue)
            
            if itemCount > 0 {
                Text("\(itemCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.red)
                    .clipShape(Circle())
                    .offset(x: 8, y: -8)
            }
        }
    }
}

#Preview {
    FoodDiscoveryView(service: MockFoodDeliveryService())
}