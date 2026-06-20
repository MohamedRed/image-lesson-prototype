import SwiftUI

struct HomeDashboardSegmentedView: View {
    @State private var showingSettings = false
    @AppStorage("useRealService") private var useRealService = false
    @AppStorage("userMode") private var userMode = "rider"
    @State private var selectedFeature: AppFeature?
    @State private var selectedCategory = "quick"
    
    let features: [AppFeature] = [
        AppFeature(
            id: "news-perspectives",
            name: "News Perspectives",
            description: "Multi-perspective news with fact-checking & history",
            icon: "newspaper.fill",
            color: .teal,
            category: .education,
            isAvailable: false
        ),
        AppFeature(
            id: "ride-sharing",
            name: "Ride Sharing",
            description: "Request rides and share journeys",
            icon: "car.fill",
            color: .blue,
            category: .transport,
            isAvailable: true
        ),
        AppFeature(
            id: "image-lesson",
            name: "AI Tutor",
            description: "Learn with AI-powered visual lessons",
            icon: "brain.head.profile",
            color: .purple,
            category: .education,
            isAvailable: true
        ),
        AppFeature(
            id: "debate",
            name: "Live Debates",
            description: "Join real-time debates with fact-checking",
            icon: "bubble.left.and.bubble.right",
            color: .orange,
            category: .social,
            isAvailable: true
        ),
        AppFeature(
            id: "home-services",
            name: "Home Services",
            description: "Find professionals for home repairs and services",
            icon: "hammer.fill",
            color: .indigo,
            category: .services,
            isAvailable: true
        ),
        AppFeature(
            id: "jobs",
            name: "Smart Jobs",
            description: "AI-powered job matching and career guidance",
            icon: "briefcase.fill",
            color: .mint,
            category: .services,
            isAvailable: false
        ),
        AppFeature(
            id: "marriage",
            name: "Soulmate Match",
            description: "AI-guided matchmaking for serious relationships",
            icon: "heart.circle.fill",
            color: .pink,
            category: .social,
            isAvailable: false
        ),
        AppFeature(
            id: "food-delivery",
            name: "Food Delivery",
            description: "Order food from local restaurants",
            icon: "fork.knife",
            color: .red,
            category: .delivery,
            isAvailable: true
        ),
        AppFeature(
            id: "marketplace",
            name: "Marketplace",
            description: "Buy and sell secondhand items in your city",
            icon: "cart.fill",
            color: .green,
            category: .shopping,
            isAvailable: true
        ),
        AppFeature(
            id: "banking",
            name: "Banking",
            description: "Manage your finances and payments",
            icon: "creditcard.fill",
            color: .indigo,
            category: .finance,
            isAvailable: false
        )
    ]
    
    // Quick Access - Most frequently used features
    var quickAccessFeatures: [AppFeature] {
        features.filter { feature in
            ["ride-sharing", "food-delivery", "news-perspectives", "image-lesson"].contains(feature.id)
        }
    }
    
    // Social features
    var socialFeatures: [AppFeature] {
        [
            features.first { $0.id == "debate" }!,
            AppFeature(
                id: "friends",
                name: "Friends",
                description: "Connect and chat with friends",
                icon: "person.2.fill",
                color: .cyan,
                category: .social,
                isAvailable: false
            ),
            AppFeature(
                id: "activities",
                name: "Activities",
                description: "Join fun activities and meetups",
                icon: "figure.run",
                color: .purple,
                category: .social,
                isAvailable: false
            ),
            AppFeature(
                id: "events",
                name: "Events",
                description: "Discover and join local events",
                icon: "calendar.badge.plus",
                color: .pink,
                category: .social,
                isAvailable: false
            )
        ]
    }
    
    // Learning features
    var learningFeatures: [AppFeature] {
        features.filter { feature in
            ["news-perspectives", "debate", "image-lesson"].contains(feature.id)
        }.sorted { first, second in
            let order = ["news-perspectives": 0, "debate": 1, "image-lesson": 2]
            return (order[first.id] ?? 99) < (order[second.id] ?? 99)
        }
    }
    
    // Daily Life features
    var dailyLifeFeatures: [AppFeature] {
        features.filter { feature in
            ["ride-sharing", "food-delivery", "marketplace", "home-services", "banking"].contains(feature.id)
        }.sorted { first, second in
            let order = ["ride-sharing": 0, "food-delivery": 1, "marketplace": 2, "home-services": 3, "banking": 4]
            return (order[first.id] ?? 99) < (order[second.id] ?? 99)
        }
    }
    
    // Life Planning features
    var lifePlanningFeatures: [AppFeature] {
        [
            features.first { $0.id == "marriage" }!,
            features.first { $0.id == "jobs" }!
        ]
    }
    
    var currentFeatures: [AppFeature] {
        switch selectedCategory {
        case "quick":
            return quickAccessFeatures
        case "social":
            return socialFeatures
        case "learning":
            return learningFeatures
        case "daily":
            return dailyLifeFeatures
        case "planning":
            return lifePlanningFeatures
        default:
            return quickAccessFeatures
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Liive")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 8) {
                            Image(systemName: userMode == "driver" ? "car.fill" : "figure.walk")
                                .foregroundColor(userMode == "driver" ? .blue : .green)
                            Text("Testing as \(userMode)")
                                .font(.subheadline)
                                .foregroundColor(userMode == "driver" ? .blue : .green)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                
                // Segmented Control
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryPill(title: "Quick Access", icon: "star.fill", isSelected: selectedCategory == "quick") {
                            selectedCategory = "quick"
                        }
                        CategoryPill(title: "Social", icon: "person.2.fill", isSelected: selectedCategory == "social") {
                            selectedCategory = "social"
                        }
                        CategoryPill(title: "Learning", icon: "book.fill", isSelected: selectedCategory == "learning") {
                            selectedCategory = "learning"
                        }
                        CategoryPill(title: "Daily Life", icon: "house.fill", isSelected: selectedCategory == "daily") {
                            selectedCategory = "daily"
                        }
                        CategoryPill(title: "Life Planning", icon: "target", isSelected: selectedCategory == "planning") {
                            selectedCategory = "planning"
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Category Title and Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(categoryTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(categoryDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Features Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(currentFeatures) { feature in
                            FeatureCard(feature: feature, isDisabled: !feature.isAvailable) {
                                if feature.isAvailable {
                                    selectedFeature = feature
                                }
                            }
                        }
                    }
                    .padding()
                    .animation(.easeInOut(duration: 0.2), value: selectedCategory)
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(item: $selectedFeature) { feature in
            FeatureNavigationView(feature: feature, useRealService: useRealService, userMode: userMode)
        }
    }
    
    var categoryTitle: String {
        switch selectedCategory {
        case "quick": return "Quick Access"
        case "social": return "Social"
        case "learning": return "Learning"
        case "daily": return "Daily Life"
        case "planning": return "Life Planning"
        default: return "Quick Access"
        }
    }
    
    var categoryDescription: String {
        switch selectedCategory {
        case "quick": return "Your most used features"
        case "social": return "Connect with friends and community"
        case "learning": return "Education and skill development"
        case "daily": return "Essential services for everyday needs"
        case "planning": return "Major life decisions and milestones"
        default: return "Your most used features"
        }
    }
}

struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview("Segmented View") {
    HomeDashboardSegmentedView()
}

#Preview("Quick Access") {
    HomeDashboardSegmentedView()
}

#Preview("Social Category") {
    struct PreviewWrapper: View {
        var body: some View {
            HomeDashboardSegmentedView()
                .onAppear {
                    // Would set selectedCategory to "social" if it were bindable
                }
        }
    }
    return PreviewWrapper()
}