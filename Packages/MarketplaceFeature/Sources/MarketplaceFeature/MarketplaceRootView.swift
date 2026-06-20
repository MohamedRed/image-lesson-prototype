import SwiftUI
import MarketplaceService
import Combine

/// Main entry point for Marketplace feature
/// Per Section 16 UX Flows and Section 3 MVP Scope
public struct MarketplaceRootView: View {
    @StateObject private var viewModel: MarketplaceViewModel
    @State private var selectedTab = 0
    @State private var showingCreateListing = false
    @State private var showingAIAssistant = false
    @State private var showingFilters = false
    @State private var selectedCity = "casablanca" // Default to Casablanca per MVP
    
    // Localization per Section 13
    @Environment(\.locale) private var locale
    
    public init(service: MarketplaceServicing? = nil) {
        // Configure factory for development/testing
        #if DEBUG
        MarketplaceServiceFactory.configureDevelopment()
        #else
        MarketplaceServiceFactory.configure(environment: .production)
        #endif
        
        // Use provided service or create from factory
        let marketplaceService = service ?? MarketplaceServiceFactory.createService()
        _viewModel = StateObject(wrappedValue: MarketplaceViewModel(service: marketplaceService))
    }
    
    public var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Discovery Tab - City-first discovery per Section 1
                DiscoveryView(viewModel: viewModel, selectedCity: $selectedCity)
                    .tabItem {
                        Label(localizedString("discover"), systemImage: "magnifyingglass")
                    }
                    .tag(0)
                
                // My Listings Tab
                MyListingsView(viewModel: viewModel)
                    .tabItem {
                        Label(localizedString("my_listings"), systemImage: "list.bullet.rectangle")
                    }
                    .tag(1)
                
                // Messages Tab
                MessagesListView(viewModel: viewModel)
                    .tabItem {
                        Label(localizedString("messages"), systemImage: "bubble.left.and.bubble.right")
                    }
                    .badge(viewModel.unreadMessageCount)
                    .tag(2)
                
                // Alerts Tab - AI Watchers per Section 7
                AlertsView(viewModel: viewModel)
                    .tabItem {
                        Label(localizedString("alerts"), systemImage: "bell")
                    }
                    .badge(viewModel.activeAlertCount)
                    .tag(3)
                
                // Profile Tab
                ProfileView(viewModel: viewModel)
                    .tabItem {
                        Label(localizedString("profile"), systemImage: "person.circle")
                    }
                    .tag(4)
            }
            .navigationTitle(marketplaceTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // City selector for city-first approach
                    Menu {
                        Button(action: { selectedCity = "casablanca" }) {
                            Label("Casablanca", systemImage: selectedCity == "casablanca" ? "checkmark" : "")
                        }
                        Button(action: { selectedCity = "rabat" }) {
                            Label("Rabat", systemImage: selectedCity == "rabat" ? "checkmark" : "")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(cityDisplayName)
                                .font(.headline)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // AI Assistant button per Section 7
                        Button(action: { showingAIAssistant = true }) {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.purple)
                        }
                        
                        // Create listing button
                        Button(action: { showingCreateListing = true }) {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateListing) {
            CreateListingFlow(viewModel: viewModel, cityId: selectedCity)
        }
        .sheet(isPresented: $showingAIAssistant) {
            AIAssistantView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.startListening(cityId: selectedCity)
        }
        .onChange(of: selectedCity) { newCity in
            viewModel.startListening(cityId: newCity)
        }
    }
    
    private var marketplaceTitle: String {
        switch locale.language.languageCode?.identifier {
        case "ar":
            return "السوق" // "The Market" in Arabic
        case "fr":
            return "Marché"
        default:
            return "Marketplace"
        }
    }
    
    private var cityDisplayName: String {
        switch selectedCity {
        case "casablanca":
            return locale.language.languageCode?.identifier == "ar" ? "الدار البيضاء" : "Casablanca"
        case "rabat":
            return locale.language.languageCode?.identifier == "ar" ? "الرباط" : "Rabat"
        default:
            return selectedCity.capitalized
        }
    }
    
    private func localizedString(_ key: String) -> String {
        // Simplified localization - would use proper localization files in production
        let translations: [String: [String: String]] = [
            "discover": ["en": "Discover", "fr": "Découvrir", "ar": "اكتشف"],
            "my_listings": ["en": "My Listings", "fr": "Mes Annonces", "ar": "إعلاناتي"],
            "messages": ["en": "Messages", "fr": "Messages", "ar": "الرسائل"],
            "alerts": ["en": "Alerts", "fr": "Alertes", "ar": "التنبيهات"],
            "profile": ["en": "Profile", "fr": "Profil", "ar": "الملف الشخصي"]
        ]
        
        let langCode = locale.language.languageCode?.identifier ?? "en"
        return translations[key]?[langCode] ?? translations[key]?["en"] ?? key
    }
}

// MARK: - My Listings View

struct MyListingsView: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    @State private var selectedStatus: ListingStatus = .active
    
    var body: some View {
        VStack(spacing: 0) {
            // Status filter
            Picker("Status", selection: $selectedStatus) {
                Text("Active").tag(ListingStatus.active)
                Text("Reserved").tag(ListingStatus.reserved)
                Text("Sold").tag(ListingStatus.sold)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Listings list
            if filteredListings.isEmpty {
                if #available(iOS 17.0, *) {
                    ContentUnavailableView(
                        "No Listings",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("Tap + to create your first listing")
                    )
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No Listings")
                            .font(.headline)
                        Text("Tap + to create your first listing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                List(filteredListings) { listing in
                    NavigationLink(destination: ListingDetailView(listing: listing, viewModel: viewModel)) {
                        ListingRowView(listing: listing)
                    }
                }
            }
        }
    }
    
    private var filteredListings: [Listing] {
        viewModel.myListings.filter { $0.status == selectedStatus }
    }
}

// MARK: - Messages List View

struct MessagesListView: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    
    var body: some View {
        if viewModel.conversations.isEmpty {
            if #available(iOS 17.0, *) {
                ContentUnavailableView(
                    "No Messages",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Messages from buyers and sellers will appear here")
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No Messages")
                        .font(.headline)
                    Text("Messages from buyers and sellers will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            List(viewModel.conversations) { conversation in
                NavigationLink(destination: ConversationView(
                    conversation: conversation,
                    viewModel: viewModel
                )) {
                    ConversationRowView(conversation: conversation)
                }
            }
        }
    }
}

// MARK: - Alerts View

struct AlertsView: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    @State private var showingCreateAlert = false
    
    var body: some View {
        VStack {
            if viewModel.alerts.isEmpty {
                if #available(iOS 17.0, *) {
                    ContentUnavailableView(
                        "No Alerts",
                        systemImage: "bell.slash",
                        description: Text("Set up alerts to get notified when matching items are listed")
                    )
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No Alerts")
                            .font(.headline)
                        Text("Set up alerts to get notified when matching items are listed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                List {
                    ForEach(viewModel.alerts) { alert in
                        AlertRowView(alert: alert)
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                await viewModel.deleteAlert(viewModel.alerts[index])
                            }
                        }
                    }
                }
            }
            
            Button(action: { showingCreateAlert = true }) {
                Label("Create Alert", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .sheet(isPresented: $showingCreateAlert) {
            CreateAlertView(viewModel: viewModel)
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    @State private var showingSettings = false
    @State private var showingKYC = false
    
    var body: some View {
        List {
            // User info section
            Section {
                HStack {
                    AsyncImage(url: URL(string: viewModel.currentUser?.photoUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text(viewModel.currentUser?.displayName ?? "User")
                            .font(.headline)
                        
                        if let seller = viewModel.currentUser?.seller {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text(String(format: "%.1f", seller.rating))
                                    .font(.caption)
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text("\(seller.stats.soldCount) sold")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // Stats section
            Section("Statistics") {
                HStack {
                    StatCard(title: "Views", value: "\(viewModel.totalViews)", icon: "eye")
                    StatCard(title: "Saves", value: "\(viewModel.totalSaves)", icon: "bookmark")
                    StatCard(title: "Messages", value: "\(viewModel.totalMessages)", icon: "bubble.left")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Seller verification
            Section("Trust & Safety") {
                HStack {
                    Label("Verification Status", systemImage: "checkmark.shield")
                    Spacer()
                    Text(viewModel.currentUser?.seller?.kycStatus.rawValue.capitalized ?? "Not Verified")
                        .foregroundColor(viewModel.currentUser?.seller?.kycStatus == .verified ? .green : .orange)
                }
                .onTapGesture {
                    if viewModel.currentUser?.seller?.kycStatus != .verified {
                        showingKYC = true
                    }
                }
            }
            
            // Settings
            Section {
                Button(action: { showingSettings = true }) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            MarketplaceSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingKYC) {
            KYCVerificationView(viewModel: viewModel)
        }
    }
}

// MARK: - Helper Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ListingRowView: View {
    let listing: Listing
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: listing.thumbnails.first ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.2))
            }
            .frame(width: 80, height: 80)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(listing.price.displayAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                HStack {
                    Image(systemName: "location")
                        .font(.caption2)
                    Text(listing.location.arrondissement ?? "")
                        .font(.caption)
                    
                    Spacer()
                    
                    Text(listing.status.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor(listing.status).opacity(0.2))
                        .foregroundColor(statusColor(listing.status))
                        .cornerRadius(4)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func statusColor(_ status: ListingStatus) -> Color {
        switch status {
        case .active: return .green
        case .reserved: return .orange
        case .sold: return .blue
        case .removed: return .red
        }
    }
}

struct ConversationRowView: View {
    let conversation: Conversation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Listing #\(conversation.listingId.prefix(8))")
                    .font(.headline)
                
                Text("Last message")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let unread = conversation.unreadCount.first?.value, unread > 0 {
                Text("\(unread)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
    }
}

struct AlertRowView: View {
    let alert: MarketplaceService.Alert
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(alert.queryDSL)
                .font(.headline)
                .lineLimit(1)
            
            HStack {
                if !alert.neighborhoods.isEmpty {
                    Label(alert.neighborhoods.joined(separator: ", "), systemImage: "location")
                        .font(.caption)
                }
                
                if let priceRange = alert.priceRange {
                    Label("MAD \(priceRange.min)-\(priceRange.max)", systemImage: "tag")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// Placeholder views for features to be implemented
struct CreateAlertView: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Create Alert - To Be Implemented")
                .navigationTitle("Create Alert")
                .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

struct MarketplaceSettingsView: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Settings - To Be Implemented")
                .navigationTitle("Settings")
                .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct KYCVerificationView: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("KYC Verification - To Be Implemented")
                .navigationTitle("Verification")
                .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

struct AIAssistantView: View {
    @ObservedObject var viewModel: MarketplaceViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("AI Assistant - To Be Implemented")
                .navigationTitle("AI Assistant")
                .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

#Preview {
    MarketplaceRootView()
}