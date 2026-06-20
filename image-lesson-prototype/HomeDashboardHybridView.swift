import SwiftUI

struct HomeDashboardHybridView: View {
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
    
    var availableFeatures: [AppFeature] {
        features.filter { $0.isAvailable }
    }
    
    var comingSoonFeatures: [AppFeature] {
        features.filter { !$0.isAvailable }
    }
    
    // Quick Access - Most frequently used features
    var quickAccessFeatures: [AppFeature] {
        features.filter { feature in
            ["ride-sharing", "food-delivery", "news-perspectives", "image-lesson"].contains(feature.id)
        }
    }
    
    // Health features
    var healthFeatures: [AppFeature] {
        [
            AppFeature(
                id: "meal-planning",
                name: "Meal Planning",
                description: "Plan and cook healthy meals",
                icon: "fork.knife",
                color: .green,
                category: .health,
                isAvailable: false
            ),
            AppFeature(
                id: "health-tracker",
                name: "Health Tracker",
                description: "Monitor your fitness and wellness",
                icon: "heart.fill",
                color: .red,
                category: .health,
                isAvailable: false
            )
        ]
    }
    
    // Tourism features
    var tourismFeatures: [AppFeature] {
        [
            AppFeature(
                id: "trip-planner",
                name: "Trip Planner",
                description: "Organize your entire trip from A to Z",
                icon: "map.fill",
                color: .blue,
                category: .travel,
                isAvailable: false
            ),
            AppFeature(
                id: "accommodation",
                name: "Accommodation",
                description: "Rent apartments, rooms and stays",
                icon: "house.fill",
                color: .orange,
                category: .travel,
                isAvailable: false
            )
        ]
    }
    
    // Life Planning features
    var lifePlanningFeatures: [AppFeature] {
        [
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
                id: "jobs",
                name: "Smart Jobs",
                description: "AI-powered job matching and career guidance",
                icon: "briefcase.fill",
                color: .mint,
                category: .services,
                isAvailable: false
            )
        ]
    }
    
    // Social features
    var socialFeatures: [AppFeature] {
        [
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
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
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
                    
                    // Fixed Segmented Control - All visible, no horizontal scrolling
                    VStack(spacing: 8) {
                        // First row - Main categories
                        HStack(spacing: 8) {
                            CategoryPill(title: "Quick", icon: "star.fill", isSelected: selectedCategory == "quick") {
                                withAnimation {
                                    proxy.scrollTo("quick", anchor: .top)
                                    selectedCategory = "quick"
                                }
                            }
                            CategoryPill(title: "Social", icon: "person.2.fill", isSelected: selectedCategory == "social") {
                                withAnimation {
                                    proxy.scrollTo("social", anchor: .top)
                                    selectedCategory = "social"
                                }
                            }
                            CategoryPill(title: "Learning", icon: "book.fill", isSelected: selectedCategory == "learning") {
                                withAnimation {
                                    proxy.scrollTo("learning", anchor: .top)
                                    selectedCategory = "learning"
                                }
                            }
                            CategoryPill(title: "Daily", icon: "house.fill", isSelected: selectedCategory == "daily") {
                                withAnimation {
                                    proxy.scrollTo("daily", anchor: .top)
                                    selectedCategory = "daily"
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Second row - Less frequent categories
                        HStack(spacing: 8) {
                            CategoryPill(title: "Health", icon: "heart.fill", isSelected: selectedCategory == "health") {
                                withAnimation {
                                    proxy.scrollTo("health", anchor: .top)
                                    selectedCategory = "health"
                                }
                            }
                            CategoryPill(title: "Planning", icon: "target", isSelected: selectedCategory == "planning") {
                                withAnimation {
                                    proxy.scrollTo("planning", anchor: .top)
                                    selectedCategory = "planning"
                                }
                            }
                            CategoryPill(title: "Tourism", icon: "airplane", isSelected: selectedCategory == "tourism") {
                                withAnimation {
                                    proxy.scrollTo("tourism", anchor: .top)
                                    selectedCategory = "tourism"
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground).shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2))
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Quick Access Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Quick Access")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                    .id("quick")
                                
                                Text("Your most used features")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(quickAccessFeatures) { feature in
                                        FeatureCard(feature: feature, isDisabled: !feature.isAvailable) {
                                            if feature.isAvailable {
                                                selectedFeature = feature
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top, 16)
                            
                            // Social Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Social")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                    .id("social")
                                
                                Text("Connect with friends and community")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(socialFeatures) { feature in
                                        FeatureCard(feature: feature, isDisabled: true) {
                                            // Coming soon - no action
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Learning Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Learning")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                    .id("learning")
                                
                                Text("Education and skill development")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(features.filter { feature in
                                        ["news-perspectives", "debate", "image-lesson"].contains(feature.id)
                                    }.sorted { first, second in
                                        let order = ["news-perspectives": 0, "debate": 1, "image-lesson": 2]
                                        return (order[first.id] ?? 99) < (order[second.id] ?? 99)
                                    }) { feature in
                                        FeatureCard(feature: feature, isDisabled: !feature.isAvailable) {
                                            if feature.isAvailable {
                                                selectedFeature = feature
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Daily Life Services
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Daily Life")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                    .id("daily")
                                
                                Text("Essential services for everyday needs")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(features.filter { feature in
                                        ["ride-sharing", "food-delivery", "marketplace", "home-services", "banking"].contains(feature.id)
                                    }.sorted { first, second in
                                        let order = ["ride-sharing": 0, "food-delivery": 1, "marketplace": 2, "home-services": 3, "banking": 4]
                                        return (order[first.id] ?? 99) < (order[second.id] ?? 99)
                                    }) { feature in
                                        FeatureCard(feature: feature, isDisabled: !feature.isAvailable) {
                                            if feature.isAvailable {
                                                selectedFeature = feature
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Health
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Health")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                    .id("health")
                                
                                Text("Wellness and nutrition tracking")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(healthFeatures) { feature in
                                        FeatureCard(feature: feature, isDisabled: true) {
                                            // Coming soon - no action
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Life Planning
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Life Planning")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                    .id("planning")
                                
                                Text("Major life decisions and milestones")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(lifePlanningFeatures) { feature in
                                        FeatureCard(feature: feature, isDisabled: true) {
                                            // Coming soon - no action
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Tourism
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Tourism")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                    .id("tourism")
                                
                                Text("Travel planning and accommodation")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(tourismFeatures) { feature in
                                        FeatureCard(feature: feature, isDisabled: true) {
                                            // Coming soon - no action
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Footer
                            VStack(spacing: 8) {
                                Text("Liive Super App")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 12) {
                                    // User Mode Badge
                                    HStack(spacing: 4) {
                                        Image(systemName: userMode == "driver" ? "car.fill" : "figure.walk")
                                            .font(.caption2)
                                        Text(userMode.capitalized)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(userMode == "driver" ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                                    )
                                    .foregroundColor(userMode == "driver" ? .blue : .green)
                                    
                                    // Service Mode Badge
                                    Text(useRealService ? "Live Mode" : "Demo Mode")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule().fill(useRealService ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                        )
                                        .foregroundColor(useRealService ? .green : .orange)
                                }
                            }
                            .padding(.top, 32)
                            .padding(.bottom, 16)
                        }
                    }
                }
                .navigationBarHidden(true)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(item: $selectedFeature) { feature in
            FeatureNavigationView(feature: feature, useRealService: useRealService, userMode: userMode)
        }
    }
}

#Preview("Hybrid Dashboard") {
    HomeDashboardHybridView()
}