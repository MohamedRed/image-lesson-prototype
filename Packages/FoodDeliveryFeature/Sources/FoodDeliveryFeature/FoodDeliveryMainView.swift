import SwiftUI
import FoodDeliveryService

/// Main view for the food delivery feature
public struct FoodDeliveryMainView: View {
    @StateObject private var viewModel: FoodDeliveryViewModel
    @StateObject private var courierViewModel: CourierViewModel
    @State private var selectedTab = 0
    @State private var showingModeSelector = false
    
    public init(service: FoodDeliveryServicing? = nil) {
        let mockService = MockFoodDeliveryService()
        let actualService = service ?? mockService
        _viewModel = StateObject(wrappedValue: FoodDeliveryViewModel(service: actualService))
        _courierViewModel = StateObject(wrappedValue: CourierViewModel(service: actualService))
    }
    
    public var body: some View {
        Group {
            if viewModel.userMode == .courier {
                courierModeView
            } else {
                customerModeView
            }
        }
        .onAppear {
            setupTabBarAppearance()
        }
        .sheet(isPresented: $showingModeSelector) {
            UserModeSelector(currentMode: viewModel.userMode) { mode in
                viewModel.userMode = mode
                selectedTab = 0
                showingModeSelector = false
            }
        }
    }
    
    private var customerModeView: some View {
        TabView(selection: $selectedTab) {
            // Discovery Tab
            FoodDiscoveryView(service: viewModel.service)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Discover")
                }
                .tag(0)
            
            // AI Recommendations Tab
            AIRecommendationsView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI Picks")
                }
                .tag(1)
            
            // Orders Tab
            OrdersView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Orders")
                }
                .tag(2)
            
            // Profile Tab
            ProfileView(viewModel: viewModel, onModeSwitch: { showingModeSelector = true })
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(3)
        }
    }
    
    private var courierModeView: some View {
        TabView(selection: $selectedTab) {
            // Courier Dashboard
            CourierDashboardView(service: viewModel.service)
                .tabItem {
                    Image(systemName: "car.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            // Active Orders (if any)
            if let currentOrder = courierViewModel.currentOrder {
                ActiveOrderView(viewModel: courierViewModel, order: currentOrder)
                    .tabItem {
                        Image(systemName: "location.fill")
                        Text("Active Order")
                    }
                    .tag(1)
            } else {
                CourierOrdersView(viewModel: courierViewModel)
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Orders")
                    }
                    .tag(1)
            }
            
            // Courier Profile
            CourierProfileView(viewModel: courierViewModel, onModeSwitch: { showingModeSelector = true })
                .tabItem {
                    Image(systemName: "person.circle")
                    .foregroundColor(.secondary)
                }
                .tag(2)
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Orders View

struct OrdersView: View {
    @ObservedObject var viewModel: FoodDeliveryViewModel
    @State private var selectedOrder: Order?
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.orderHistory.isEmpty && !viewModel.isLoading {
                    emptyOrdersView
                } else {
                    ordersList
                }
            }
            .navigationTitle("Your Orders")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadOrderHistory()
            }
            .refreshable {
                await viewModel.loadOrderHistory()
            }
            .sheet(item: $selectedOrder) { order in
                OrderTrackingView(orderId: order.id!, viewModel: viewModel)
            }
        }
    }
    
    private var emptyOrdersView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No orders yet")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("When you place orders, they'll appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
    }
    
    private var ordersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.isLoading && viewModel.orderHistory.isEmpty {
                    ForEach(0..<3) { _ in
                        CustomerOrderCardSkeleton()
                            .padding(.horizontal)
                    }
                } else {
                    ForEach(viewModel.orderHistory) { order in
                        CustomerOrderCard(order: order) {
                            selectedOrder = order
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @ObservedObject var viewModel: FoodDeliveryViewModel
    let onModeSwitch: () -> Void
    @State private var showingAddressManager = false
    @State private var showingPaymentMethods = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Guest User")
                                .font(.headline)
                            Text("Sign in to save preferences")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Sign In") {
                            // Handle sign in
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Delivery") {
                    NavigationLink(destination: AddressManagerView()) {
                        Label("Delivery Addresses", systemImage: "location")
                    }
                    
                    NavigationLink(destination: PaymentMethodsView()) {
                        Label("Payment Methods", systemImage: "creditcard")
                    }
                }
                
                Section("Preferences") {
                    NavigationLink(destination: TastePreferencesView()) {
                        Label("Food Preferences", systemImage: "heart")
                    }
                    
                    NavigationLink(destination: FoodProfileNotificationSettingsView()) {
                        Label("Notifications", systemImage: "bell")
                    }
                }
                
                Section("Support") {
                    NavigationLink(destination: HelpCenterView()) {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink(destination: ContactSupportView()) {
                        Label("Contact Us", systemImage: "phone")
                    }
                }
                
                Section("App Mode") {
                    Button(action: onModeSwitch) {
                        HStack {
                            Label("Switch to Courier Mode", systemImage: "car.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Order Card

struct CustomerOrderCard: View {
    let order: Order
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Restaurant Name") // Would get from restaurant data
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(orderItemsSummary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        StatusBadge(status: order.status)
                        
                        Text("\(order.total, specifier: "%.0f") MAD")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                
                HStack {
                    if let createdAt = order.createdAt {
                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("\(order.items.count) item\(order.items.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if canTrackOrder {
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text("Track order")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    private var orderItemsSummary: String {
        let itemNames = order.items.map { item in
            item.quantity > 1 ? "\(item.quantity)x \(item.title)" : item.title
        }
        return itemNames.prefix(2).joined(separator: ", ") + 
               (itemNames.count > 2 ? " +\(itemNames.count - 2) more" : "")
    }
    
    private var canTrackOrder: Bool {
        switch order.status {
        case .created, .restaurantAccepted, .preparing, .readyForPickup, .pickedUp, .onRoute:
            return true
        case .delivered, .cancelledByCustomer, .cancelledByMerchant, .cancelledNoCourier:
            return false
        }
    }
}

struct CustomerOrderCardSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 16)
                        .frame(maxWidth: 120)
                        .redacted(reason: .placeholder)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 14)
                        .redacted(reason: .placeholder)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 16)
                        .redacted(reason: .placeholder)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 16)
                        .redacted(reason: .placeholder)
                }
            }
            
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 12)
                    .redacted(reason: .placeholder)
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 12)
                    .redacted(reason: .placeholder)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct StatusBadge: View {
    let status: Order.OrderStatus
    
    var body: some View {
        Text(displayText)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundColor(backgroundColor)
            .cornerRadius(6)
    }
    
    private var displayText: String {
        switch status {
        case .created:
            return "Placed"
        case .restaurantAccepted:
            return "Confirmed"
        case .preparing:
            return "Preparing"
        case .readyForPickup:
            return "Ready"
        case .pickedUp:
            return "Picked Up"
        case .onRoute:
            return "On Route"
        case .delivered:
            return "Delivered"
        case .cancelledByCustomer:
            return "Cancelled"
        case .cancelledByMerchant:
            return "Cancelled"
        case .cancelledNoCourier:
            return "Cancelled"
        }
    }
    
    private var backgroundColor: Color {
        switch status {
        case .created, .restaurantAccepted, .preparing, .readyForPickup, .pickedUp, .onRoute:
            return .blue
        case .delivered:
            return .green
        case .cancelledByCustomer, .cancelledByMerchant, .cancelledNoCourier:
            return .red
        }
    }
}

// MARK: - Placeholder Views for Profile Section

struct AddressManagerView: View {
    var body: some View {
        Text("Address Manager")
            .navigationTitle("Delivery Addresses")
    }
}

struct PaymentMethodsView: View {
    var body: some View {
        Text("Payment Methods")
            .navigationTitle("Payment Methods")
    }
}

struct TastePreferencesView: View {
    var body: some View {
        Text("Taste Preferences")
            .navigationTitle("Food Preferences")
    }
}

struct FoodProfileNotificationSettingsView: View {
    var body: some View {
        Text("Notification Settings")
            .navigationTitle("Notifications")
    }
}

struct HelpCenterView: View {
    var body: some View {
        Text("Help Center")
            .navigationTitle("Help Center")
    }
}

struct ContactSupportView: View {
    var body: some View {
        Text("Contact Support")
            .navigationTitle("Contact Us")
    }
}

// MARK: - Mode Selector

struct UserModeSelector: View {
    let currentMode: FoodDeliveryViewModel.UserMode
    let onModeSelected: (FoodDeliveryViewModel.UserMode) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Choose Your Mode")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Switch between customer and courier modes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    ModeCard(
                        mode: .customer,
                        title: "Customer",
                        description: "Order food from restaurants",
                        icon: "person.fill",
                        color: .blue,
                        isSelected: currentMode == .customer
                    ) {
                        onModeSelected(.customer)
                    }
                    
                    ModeCard(
                        mode: .courier,
                        title: "Courier",
                        description: "Deliver food and earn money",
                        icon: "car.fill",
                        color: .green,
                        isSelected: currentMode == .courier
                    ) {
                        onModeSelected(.courier)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Select Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ModeCard: View {
    let mode: FoodDeliveryViewModel.UserMode
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(isSelected ? color : .secondary)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? color : .primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(color)
                } else {
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding()
            .background(isSelected ? color.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Courier Views

struct CourierOrdersView: View {
    @ObservedObject var viewModel: CourierViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.availableOrders.isEmpty && !viewModel.isLoading {
                    emptyOrdersView
                } else {
                    ordersList
                }
            }
            .navigationTitle("Available Orders")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.refreshData()
            }
            .refreshable {
                await viewModel.refreshData()
            }
        }
    }
    
    private var emptyOrdersView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "clock")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No orders available")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("New delivery opportunities will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
    }
    
    private var ordersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.isLoading && viewModel.availableOrders.isEmpty {
                    ForEach(0..<3) { _ in
                        CustomerOrderCardSkeleton()
                            .padding(.horizontal)
                    }
                } else {
                    ForEach(viewModel.availableOrders) { order in
                        CourierAvailableOrderCard(
                            order: order,
                            onAccept: {
                                if let id = order.id {
                                    Task { await viewModel.acceptOrder(orderId: id) }
                                }
                            }
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

struct CourierProfileView: View {
    @ObservedObject var viewModel: CourierViewModel
    let onModeSwitch: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProfileRow(viewModel: viewModel) {
                        // Edit profile
                    }
                }
                
                Section("Earnings") {
                    NavigationLink("View Earnings") {
                        CourierEarningsView(viewModel: viewModel)
                    }
                    
                    NavigationLink("Payout Settings") {
                        Text("Payout Settings")
                    }
                }
                
                Section("Settings") {
                    NavigationLink("Courier Settings") {
                        CourierSettingsView(viewModel: viewModel)
                    }
                    
                    NavigationLink("Vehicle Information") {
                        Text("Vehicle Information")
                    }
                }
                
                Section("App Mode") {
                    Button(action: onModeSwitch) {
                        HStack {
                            Label("Switch to Customer Mode", systemImage: "person.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section("Support") {
                    NavigationLink("Help Center") {
                        HelpCenterView()
                    }
                    
                    NavigationLink("Contact Support") {
                        ContactSupportView()
                    }
                }
            }
            .navigationTitle("Courier Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    FoodDeliveryMainView()
}