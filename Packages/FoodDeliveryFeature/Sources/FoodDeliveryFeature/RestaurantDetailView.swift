import SwiftUI
import FoodDeliveryService

/// Detailed view of a restaurant showing menu items
public struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @ObservedObject var viewModel: FoodDeliveryViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: String?
    @State private var selectedMenuItem: MenuItem?
    
    // Group menu items by category
    private var menuCategories: [String] {
        let categories = Array(Set(viewModel.menuItems.map { $0.category }))
        return categories.sorted()
    }
    
    public init(restaurant: Restaurant, viewModel: FoodDeliveryViewModel) {
        self.restaurant = restaurant
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Restaurant header
                    restaurantHeader
                    
                    // Category selector
                    if !menuCategories.isEmpty {
                        categorySelector
                    }
                    
                    // Menu items
                    menuSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: CartView(viewModel: viewModel)) {
                        CartButtonView(itemCount: viewModel.cartItemCount)
                    }
                }
            }
            .sheet(item: $selectedMenuItem) { menuItem in
                MenuItemCustomizationView(
                    menuItem: menuItem,
                    viewModel: viewModel
                )
            }
        }
        .task {
            await viewModel.loadMenu(for: restaurant)
        }
    }
    
    private var restaurantHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Restaurant image
            AsyncImage(url: URL(string: restaurant.logoUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.gray)
                    )
            }
            .frame(height: 200)
            .clipShape(Rectangle())
            
            VStack(alignment: .leading, spacing: 12) {
                // Restaurant name and status
                HStack {
                    Text(restaurant.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if restaurant.isOpen {
                        Text("Open")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    } else {
                        Text("Closed")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
                
                // Cuisine tags
                Text(restaurant.cuisineTags.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Rating and delivery info
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(restaurant.rating, specifier: "%.1f")")
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundColor(.gray)
                        Text("\(restaurant.avgPrepMinutes)-\(restaurant.avgPrepMinutes + 10) min")
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "car")
                            .foregroundColor(.gray)
                        Text("\(Int(restaurant.deliveryFeePolicy.baseMAD)) MAD")
                    }
                    
                    Spacer()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                // Contact info
                if let phone = restaurant.phone {
                    Button(action: {
                        if let url = URL(string: "tel:\(phone)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "phone")
                            Text("Call Restaurant")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button("All") {
                    selectedCategory = nil
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedCategory == nil ? Color.blue : Color(.systemGray5))
                .foregroundColor(selectedCategory == nil ? .white : .primary)
                .cornerRadius(20)
                
                ForEach(menuCategories, id: \.self) { category in
                    Button(category.capitalized) {
                        selectedCategory = category
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedCategory == category ? Color.blue : Color(.systemGray5))
                    .foregroundColor(selectedCategory == category ? .white : .primary)
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private var menuSection: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoading && viewModel.menuItems.isEmpty {
                ForEach(0..<8) { _ in
                    MenuItemCardSkeleton()
                        .padding(.horizontal)
                }
            } else {
                let filteredItems = selectedCategory == nil 
                    ? viewModel.menuItems 
                    : viewModel.menuItems.filter { $0.category == selectedCategory }
                
                if filteredItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        
                        Text("No items in this category")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(filteredItems) { menuItem in
                        RestaurantMenuItemCard(menuItem: menuItem) {
                            selectedMenuItem = menuItem
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Supporting Views

struct RestaurantMenuItemCard: View {
    let menuItem: MenuItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(menuItem.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    Text(menuItem.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    
                    // Price and dietary info
                    HStack {
                        Text("\(Int(menuItem.price)) MAD")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        // Dietary tags
                        if !menuItem.dietaryTags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(menuItem.dietaryTags.prefix(2), id: \.self) { tag in
                                    Text(tag.uppercased())
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.1))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    // Calories and availability
                    HStack {
                        if let calories = menuItem.calories {
                            Text("\(calories) cal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !menuItem.isAvailable {
                            Text("Out of stock")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }
                }
                
                // Menu item image
                AsyncImage(url: URL(string: menuItem.imageUrl ?? "")) { image in
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
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .foregroundColor(.primary)
        .disabled(!menuItem.isAvailable)
        .opacity(menuItem.isAvailable ? 1.0 : 0.6)
    }
}

struct MenuItemCardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 20)
                    .redacted(reason: .placeholder)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .redacted(reason: .placeholder)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .frame(maxWidth: 120)
                    .redacted(reason: .placeholder)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .frame(maxWidth: 80)
                    .redacted(reason: .placeholder)
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 80)
                .redacted(reason: .placeholder)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    RestaurantDetailView(
        restaurant: Restaurant(
            id: "1",
            name: "Pizza Palace",
            cuisineTags: ["Italian", "Pizza"],
            rating: 4.5,
            isOpen: true,
            address: Restaurant.Address(city: "Casablanca", street: "123 Main St"),
            coordinates: Coordinates(latitude: 33.5731, longitude: -7.5898),
            deliveryFeePolicy: Restaurant.DeliveryFeePolicy(baseMAD: 10, perKmMAD: 2)
        ),
        viewModel: FoodDeliveryViewModel(service: MockFoodDeliveryService())
    )
}