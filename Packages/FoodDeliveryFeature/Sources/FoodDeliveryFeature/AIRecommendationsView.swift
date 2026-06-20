import SwiftUI
import FoodDeliveryService

/// Enhanced discovery view featuring AI-powered recommendations
public struct AIRecommendationsView: View {
    @ObservedObject private var viewModel: FoodDeliveryViewModel
    @State private var smartSuggestions: SmartSuggestions?
    @State private var trendingItems: [MenuItem] = []
    @State private var isLoading = true
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantDetail = false
    
    private let context = RecContext(
        location: Coordinates(latitude: 33.5731, longitude: -7.5898), // Casablanca
        timestamp: Date()
    )
    
    public init(viewModel: FoodDeliveryViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header
                    AIHeaderSection()
                    
                    if isLoading {
                        LoadingSection()
                    } else {
                        // Smart suggestions sections
                        if let suggestions = smartSuggestions {
                            // Personalized for you
                            if !suggestions.suggestedRestaurants.isEmpty {
                                RecommendationSection(
                                    title: "🎯 Personalized for You",
                                    subtitle: "Based on your preferences and habits",
                                    restaurants: suggestions.suggestedRestaurants,
                                    onRestaurantTap: { restaurant in
                                        selectedRestaurant = restaurant
                                        showingRestaurantDetail = true
                                    }
                                )
                            }
                            
                            // Reorder favorites
                            if !suggestions.reorderSuggestions.isEmpty {
                                RecommendationSection(
                                    title: "🔄 Reorder Favorites",
                                    subtitle: "Quick access to your go-to places",
                                    restaurants: suggestions.reorderSuggestions,
                                    onRestaurantTap: { restaurant in
                                        selectedRestaurant = restaurant
                                        showingRestaurantDetail = true
                                    }
                                )
                            }
                            
                            // Trending items
                            if !suggestions.trending.isEmpty {
                                TrendingItemsSection(
                                    items: suggestions.trending,
                                    onItemTap: { item in
                                        // Log interaction
                                        Task {
                                            try? await viewModel.service.logInteraction(
                                                type: .click,
                                                entityId: item.id!,
                                                entityType: .menuItem,
                                                context: context
                                            )
                                        }
                                    }
                                )
                            }
                            
                            // Try something new
                            if !suggestions.newCuisineSuggestions.isEmpty {
                                RecommendationSection(
                                    title: "🌟 Try Something New",
                                    subtitle: "Discover new cuisines and flavors",
                                    restaurants: suggestions.newCuisineSuggestions,
                                    onRestaurantTap: { restaurant in
                                        selectedRestaurant = restaurant
                                        showingRestaurantDetail = true
                                    }
                                )
                            }
                        }
                        
                        // AI insights
                        AIInsightsSection()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100) // Space for tab bar
            }
            .navigationTitle("AI Recommendations")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadRecommendations()
            }
        }
        .sheet(isPresented: $showingRestaurantDetail) {
            if let restaurant = selectedRestaurant {
                RestaurantDetailView(restaurant: restaurant, viewModel: viewModel)
            }
        }
        .task {
            await loadRecommendations()
        }
    }
    
    private func loadRecommendations() async {
        isLoading = true
        
        do {
            // Load smart suggestions
            let suggestions = try await viewModel.service.getSmartSuggestions(context: context)
            let trending = try await viewModel.service.getTrendingItems(context: context)
            
            await MainActor.run {
                self.smartSuggestions = suggestions
                self.trendingItems = trending
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                // Handle error appropriately
            }
        }
    }
}

// MARK: - Header Section
struct AIHeaderSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI-Powered Recommendations")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Discover your perfect meal with smart suggestions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundColor(.purple)
            }
            
            // AI status indicator
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text("AI Learning Active")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Loading Section
struct LoadingSection: View {
    var body: some View {
        VStack(spacing: 20) {
            ForEach(0..<3) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    // Section title skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 20)
                        .frame(maxWidth: 200)
                        .redacted(reason: .placeholder)
                    
                    // Restaurant cards skeleton
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<3) { _ in
                                AIRecommendedRestaurantSkeleton()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

// MARK: - Recommendation Section
struct RecommendationSection: View {
    let title: String
    let subtitle: String
    let restaurants: [Restaurant]
    let onRestaurantTap: (Restaurant) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Restaurant cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(restaurants) { restaurant in
                        RecommendedRestaurantCard(restaurant: restaurant) {
                            onRestaurantTap(restaurant)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Recommended Restaurant Card
struct RecommendedRestaurantCard: View {
    let restaurant: Restaurant
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Restaurant image placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 160, height: 120)
                    .overlay(
                        VStack {
                            Image(systemName: "fork.knife")
                                .font(.title)
                                .foregroundColor(.white)
                            Text(restaurant.name.prefix(1))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    )
                
                // Restaurant info
                VStack(alignment: .leading, spacing: 6) {
                    Text(restaurant.name)
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    // Cuisine tags
                    Text(restaurant.cuisineTags.prefix(2).joined(separator: " • "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Rating and delivery time
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("\(restaurant.rating, specifier: "%.1f")")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Text("\(restaurant.avgPrepMinutes + 15) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // AI recommendation reason
                    AIRecommendationBadge(restaurant: restaurant)
                }
            }
            .frame(width: 160)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - AI Recommendation Badge
struct AIRecommendationBadge: View {
    let restaurant: Restaurant
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain")
                .font(.caption2)
                .foregroundColor(.purple)
            
            Text(recommendationReason)
                .font(.caption2)
                .foregroundColor(.purple)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(4)
    }
    
    private var recommendationReason: String {
        let reasons = ["Matches your taste", "Popular choice", "New for you", "Highly rated", "Quick delivery"]
        return reasons.randomElement() ?? "Recommended"
    }
}

// MARK: - Trending Items Section
struct TrendingItemsSection: View {
    let items: [MenuItem]
    let onItemTap: (MenuItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            VStack(alignment: .leading, spacing: 4) {
                Text("🔥 Trending Now")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("What everyone's ordering right now")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Trending items grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(items.prefix(6), id: \.id) { item in
                    TrendingItemCard(item: item) {
                        onItemTap(item)
                    }
                }
            }
        }
    }
}

// MARK: - Trending Item Card
struct TrendingItemCard: View {
    let item: MenuItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Item image placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [Color.orange.opacity(0.3), Color.red.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 80)
                    .overlay(
                        VStack {
                            Image(systemName: "flame.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    )
                
                // Item info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    HStack {
                        Text("MAD \(item.price, specifier: "%.0f")")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("Hot")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - AI Insights Section
struct AIInsightsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🧠 AI Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                AIInsightCard(
                    icon: "chart.bar.fill",
                    title: "Your Food Patterns",
                    description: "You order Mediterranean food 40% more on weekends",
                    color: .blue
                )
                
                AIInsightCard(
                    icon: "clock.fill",
                    title: "Optimal Order Time",
                    description: "Best delivery time for you: 7:00 PM (15 min faster)",
                    color: .green
                )
                
                AIInsightCard(
                    icon: "star.fill",
                    title: "Taste Match",
                    description: "97% match with spicy and vegetarian options",
                    color: .orange
                )
            }
        }
    }
}

// MARK: - Insight Card
struct AIInsightCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Restaurant Card Skeleton
struct AIRecommendedRestaurantSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 160, height: 120)
                .redacted(reason: .placeholder)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .redacted(reason: .placeholder)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 12)
                    .frame(maxWidth: 100)
                    .redacted(reason: .placeholder)
                
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 12)
                        .redacted(reason: .placeholder)
                    
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 12)
                        .redacted(reason: .placeholder)
                }
            }
        }
        .frame(width: 160)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    let mockService = MockFoodDeliveryService()
    let viewModel = FoodDeliveryViewModel(service: mockService)
    
    return AIRecommendationsView(viewModel: viewModel)
}