import SwiftUI
import RideSharingFeature
import GliteImageLessonFeature
import AITutorFeature
import HomeServicesFeature
import HomeServicesService
import FoodDeliveryFeature
import FoodDeliveryService
import MarketplaceFeature
import MarketplaceService
import FriendsFeature
import FriendsService
import NewsFeature
import NewsService
import EventsFeature
import EventsService
import MealPlanningFeature
import MealPlanningService
import TripsFeature
import TripsService
import AccommodationsFeature
import AccommodationsService
#if canImport(ActivitiesFeature)
import ActivitiesFeature
#endif
#if canImport(ActivitiesService)
import ActivitiesService
#endif

struct FeatureNavigationView: View {
    let feature: AppFeature
    let useRealService: Bool
    let userMode: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            switch feature.id {
            case "ride-sharing":
                RideMapContainerView(mode: useRealService ? .localDev(.default) : .demo)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
                
            case "image-lesson":
                AITutorContainerView(useRealService: useRealService)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
                
            case "debate":
                DebateContainerView(useRealService: useRealService)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
                
            case "home-services":
                HomeServicesContainerView(useRealService: useRealService, userMode: userMode)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
                
            case "food-delivery":
                FoodDeliveryContainerView(useRealService: useRealService)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
                
            case "marketplace":
                MarketplaceContainerView(useRealService: useRealService)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
            
            case "friends":
                FriendsContainerView(useRealService: useRealService)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
            
            case "news-perspectives":
                NewsContainerView(useRealService: useRealService)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
            
            case "events":
                EventsContainerView(useRealService: useRealService)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
            
            case "activities":
#if canImport(ActivitiesFeature) && canImport(ActivitiesService)
                ActivitiesContainerView(useRealService: useRealService)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
#else
                ComingSoonView(feature: feature)
#endif

            case "meal-planning":
                MealPlanningContainerView(useRealService: useRealService)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
            
            case "trips":
                TripsContainerView(useRealService: useRealService)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
            
            case "accommodations":
                AccommodationsContainerView(useRealService: useRealService)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("← Dashboard") {
                                dismiss()
                            }
                        }
                    }
                
            default:
                ComingSoonView(feature: feature)
            }
        }
    }
}

// Container for Image Lesson feature
struct ImageLessonContainerView: View {
    let useRealService: Bool
    @State private var state: ContentState = .loading
    
    enum ContentState {
        case loading
        case ready(AnyView)
        case error(String)
    }
    
    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Loading AI Tutor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { initialize() }
                
            case .ready(let view):
                view
                
            case .error(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(message)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        state = .loading
                        initialize()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }
    
    private func initialize() {
        if useRealService {
            // Initialize with real service
            guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
                  URL(string: urlString) != nil else {
                state = .error("Missing or invalid API_BASE_URL in Info.plist")
                return
            }
            // Would create real ImageLessonView here
            state = .error("Real service not yet implemented")
        } else {
            // Use demo mode
            let demoView = Text("Image Lesson Demo View\n\nThis would show the AI tutor interface with:\n• Visual learning content\n• Interactive lessons\n• Progress tracking")
                .multilineTextAlignment(.center)
                .padding()
            state = .ready(AnyView(demoView))
        }
    }
}

// Container for Home Services feature
struct HomeServicesContainerView: View {
    let useRealService: Bool
    let userMode: String
    
    var body: some View {
        // Use the actual HomeServicesMainView from the package
        if useRealService {
            // Use real Firestore service
            HomeServicesMainView(service: FirestoreHomeServicesService())
        } else {
            // Use mock service for demo
            HomeServicesMainView(service: MockHomeServicesService())
        }
    }
}

// Container for Debate feature
struct DebateContainerView: View {
    let useRealService: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live Debates")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Real-time debates with fact-checking")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                }
                .padding()
                
                // Current Debates
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Debates")
                        .font(.headline)
                    
                    ForEach(0..<3) { index in
                        DebateCard(
                            topic: ["Climate Change Solutions", "AI in Education", "Future of Transportation"][index],
                            participants: [24, 18, 31][index],
                            status: ["Live", "Starting Soon", "Live"][index]
                        )
                    }
                }
                .padding()
                
                // Join Options
                VStack(spacing: 12) {
                    Button(action: {}) {
                        Label("Create New Debate", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {}) {
                        Label("Join Random Debate", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct DebateCard: View {
    let topic: String
    let participants: Int
    let status: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(topic)
                    .font(.headline)
                
                HStack {
                    Label("\(participants) participants", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(status)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(status == "Live" ? Color.red.opacity(0.2) : Color.orange.opacity(0.2))
                        )
                        .foregroundColor(status == "Live" ? .red : .orange)
                }
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ComingSoonView: View {
    let feature: AppFeature
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(feature.color.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 48))
                    .foregroundColor(feature.color)
            }
            
            VStack(spacing: 8) {
                Text(feature.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Coming Soon")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            Text(feature.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

// Container for Food Delivery feature
struct FoodDeliveryContainerView: View {
    let useRealService: Bool
    
    var body: some View {
        // Use the actual FoodDeliveryMainView from the package
        if useRealService {
            // Use real Firestore service
            FoodDeliveryMainView(service: FirestoreFoodDeliveryService())
        } else {
            // Use mock service for demo
            FoodDeliveryMainView(service: MockFoodDeliveryService())
        }
    }
}

// Container for Marketplace feature
struct MarketplaceContainerView: View {
    let useRealService: Bool
    
    var body: some View {
        // Use the actual MarketplaceRootView from the package
        if useRealService {
            // Use real Firestore service (when backend is deployed)
            MarketplaceRootView(service: MockMarketplaceService()) // Using mock until backend is ready
        } else {
            // Use mock service for demo
            MarketplaceRootView(service: MockMarketplaceService())
        }
    }
}

// Container for Friends feature (switches between real and mock services)
struct FriendsContainerView: View {
    let useRealService: Bool
    
    var body: some View {
        if useRealService {
            FriendsView() // defaults to real FriendsService
        } else {
            FriendsView(service: MockFriendsService())
        }
    }
}

// Container for News feature
struct NewsContainerView: View {
    let useRealService: Bool
    
    var body: some View {
        if useRealService {
            // Use real Firestore service
            NewsRootView(service: FirestoreNewsService())
        } else {
            // Use mock service for demo
            NewsRootView(service: MockNewsService())
        }
    }
}

// Container for Events feature
struct EventsContainerView: View {
    let useRealService: Bool
    
    var body: some View {
        // Use the actual EventsRootView from the package
        EventsRootView()
    }
}

#if canImport(ActivitiesFeature) && canImport(ActivitiesService)
// Container for Activities feature
struct ActivitiesContainerView: View {
    let useRealService: Bool
    
    var body: some View {
        // Use the actual ActivitiesFeatureView from the package
        if useRealService {
            // Use real Firestore service - connects to deployed backend
            ActivitiesFeatureView(service: FirestoreActivitiesService())
        } else {
            // Use mock service for offline demo mode
            ActivitiesFeatureView(service: MockActivitiesService())
        }
    }
}
#endif

// Container for Meal Planning feature
struct MealPlanningContainerView: View {
    let useRealService: Bool
    
    var body: some View {
        // Configure meal planning service based on environment
        let _ = MealPlanningServiceFactory.configure(
            environment: useRealService ? .development : .mock,
            featureFlags: .allEnabled
        )
        
        // Use the actual MealPlanningRootView from the package
        MealPlanningRootView()
    }
}

// Container for Accommodations feature
struct AccommodationsContainerView: View {
    let useRealService: Bool
    
    var body: some View {
        if useRealService {
            // Use real service with API endpoints
            AccommodationsFeature()
        } else {
            // Use mock service for demo
            AccommodationsFeature()
        }
    }
}
