import SwiftUI
import FriendsFeature

struct HomeDashboardView: View {
    @State private var showingSettings = false
    @AppStorage("useRealService") private var useRealService = false
    @AppStorage("userMode") private var userMode = "rider"
    @State private var selectedFeature: AppFeature?
    
    let features: [AppFeature] = [
        AppFeature(
            id: "news-perspectives",
            name: "News Perspectives",
            description: "Multi-perspective news with fact-checking & history",
            icon: "newspaper.fill",
            color: .teal,
            category: .education,
            isAvailable: true
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
            id: "trips",
            name: "Trip Planner",
            description: "Plan and book complete travel experiences",
            icon: "airplane",
            color: .cyan,
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
            id: "events",
            name: "Events",
            description: "Discover events, create groups, and book tickets together",
            icon: "calendar.badge.plus",
            color: .purple,
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
        // Future features - currently disabled
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
                isAvailable: true
            ),
            AppFeature(
                id: "health",
                name: "Health",
                description: "Monitor your fitness and wellness",
                icon: "heart.fill",
                color: .red,
                category: .health,
                isAvailable: true
            )
        ]
    }
    
    // Tourism features
    var tourismFeatures: [AppFeature] {
        [
            AppFeature(
                id: "trips",
                name: "Trip Planner",
                description: "Organize your entire trip from A to Z",
                icon: "map.fill",
                color: .blue,
                category: .travel,
                isAvailable: true
            ),
            AppFeature(
                id: "accommodations",
                name: "Accommodations",
                description: "Rent apartments, rooms and stays",
                icon: "house.fill",
                color: .orange,
                category: .travel,
                isAvailable: true
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
                isAvailable: true
            ),
            AppFeature(
                id: "activities",
                name: "Activities",
                description: "Join fun activities and meetups",
                icon: "figure.run",
                color: .purple,
                category: .social,
                isAvailable: true
            ),
            AppFeature(
                id: "events",
                name: "Events",
                description: "Discover and join local events",
                icon: "calendar.badge.plus",
                color: .pink,
                category: .social,
                isAvailable: true
            )
        ]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HeaderView(showingSettings: $showingSettings, userMode: userMode)
                    
                    // Available Features - Organized by Engagement Level
                    VStack(alignment: .leading, spacing: 24) {
                        // Social (Highest Engagement)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Social")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            Text("Connect with friends and community")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(socialFeatures) { feature in
                                    FeatureCard(feature: feature, isDisabled: !feature.isAvailable) {
                                        if feature.isAvailable {
                                            selectedFeature = feature
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Learning
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Learning")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
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
                            
                            Text("Wellness and nutrition tracking")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(healthFeatures) { feature in
                                    FeatureCard(feature: feature, isDisabled: !feature.isAvailable) {
                                        if feature.isAvailable {
                                            selectedFeature = feature
                                        }
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
                            
                            Text("Travel planning and accommodation")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(tourismFeatures) { feature in
                                    FeatureCard(feature: feature, isDisabled: !feature.isAvailable) {
                                        if feature.isAvailable {
                                            selectedFeature = feature
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Coming Soon Features
                    if !comingSoonFeatures.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Coming Soon")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(comingSoonFeatures) { feature in
                                    FeatureCard(feature: feature, isDisabled: true) {
                                        // Coming soon - no action
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
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
            .navigationTitle("Liive")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(item: $selectedFeature) { feature in
            FeatureNavigationView(feature: feature, useRealService: useRealService, userMode: userMode)
        }
    }
}

struct HeaderView: View {
    @Binding var showingSettings: Bool
    let userMode: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Liive")
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
    }
}

struct FeatureCard: View {
    let feature: AppFeature
    let isDisabled: Bool
    let action: () -> Void
    
    init(feature: AppFeature, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.feature = feature
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(feature.color.opacity(isDisabled ? 0.3 : 0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: feature.icon)
                        .font(.system(size: 28))
                        .foregroundColor(isDisabled ? .gray : feature.color)
                }
                
                // Content
                VStack(spacing: 4) {
                    Text(feature.name)
                        .font(.headline)
                        .foregroundColor(isDisabled ? .gray : .primary)
                        .multilineTextAlignment(.center)
                    
                    Text(feature.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                // Coming Soon Badge
                if isDisabled {
                    Text("COMING SOON")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.gray))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .disabled(isDisabled)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Data Models

struct AppFeature: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    let category: FeatureCategory
    let isAvailable: Bool
}

enum FeatureCategory: String, CaseIterable {
    case transport = "Transport"
    case education = "Education"
    case social = "Social"
    case services = "Services"
    case delivery = "Delivery"
    case shopping = "Shopping"
    case health = "Health"
    case finance = "Finance"
    case entertainment = "Entertainment"
    case travel = "Travel"
}

#Preview {
    HomeDashboardView()
}