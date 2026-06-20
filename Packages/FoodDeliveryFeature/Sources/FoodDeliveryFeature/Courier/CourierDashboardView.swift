import SwiftUI
import FoodDeliveryService

/// Main dashboard for couriers to manage their delivery operations
public struct CourierDashboardView: View {
    @StateObject private var viewModel: CourierViewModel
    @State private var showingSettings = false
    @State private var showingEarnings = false
    
    public init(service: FoodDeliveryServicing) {
        self._viewModel = StateObject(wrappedValue: CourierViewModel(service: service))
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with online status
                    CourierHeaderSection(
                        isOnline: viewModel.isOnline,
                        currentOrder: viewModel.currentOrder,
                        toggleOnlineStatus: { await viewModel.toggleOnlineStatus() }
                    )
                    
                    // Current order card (if any)
                    if let currentOrder = viewModel.currentOrder {
                        CurrentOrderCard(order: currentOrder) {
                            await viewModel.loadOrderDetails(orderId: currentOrder.id!)
                        }
                    }
                    
                    // Available orders
                    if viewModel.isOnline && viewModel.currentOrder == nil {
                        CourierDashboardAvailableOrdersSection(
                            orders: viewModel.availableOrders,
                            isLoading: viewModel.isLoading,
                            onAcceptOrder: { orderId in
                                await viewModel.acceptOrder(orderId: orderId)
                            },
                            onDeclineOrder: { orderId, reason in
                                await viewModel.declineOrder(orderId: orderId, reason: reason)
                            }
                        )
                    }
                    
                    // Quick stats
                    if viewModel.isOnline {
                        QuickStatsSection(
                            todayDeliveries: viewModel.todayDeliveries,
                            todayEarnings: viewModel.todayEarnings,
                            rating: viewModel.courierRating
                        )
                    }
                    
                    // Offline message
                    if !viewModel.isOnline {
                        OfflineMessageCard {
                            await viewModel.goOnline()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Courier Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("View Earnings", systemImage: "dollarsign.circle") {
                            showingEarnings = true
                        }
                        
                        Button("Settings", systemImage: "gear") {
                            showingSettings = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                await viewModel.initialize()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    await viewModel.refreshData()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            CourierSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingEarnings) {
            CourierEarningsView(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .alert("Info", isPresented: Binding(
            get: { viewModel.infoMessage != nil },
            set: { if !$0 { viewModel.infoMessage = nil } }
        )) {
            Button("OK") { viewModel.infoMessage = nil }
        } message: {
            if let msg = viewModel.infoMessage { Text(msg) }
        }
    }
}

// MARK: - Header Section
struct CourierHeaderSection: View {
    let isOnline: Bool
    let currentOrder: Order?
    let toggleOnlineStatus: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good \(timeOfDay)!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                CourierOnlineToggleButton(isOnline: isOnline, onToggle: toggleOnlineStatus)
            }
            
            if let order = currentOrder {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text("Active delivery in progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Morning"
        case 12..<17: return "Afternoon"
        default: return "Evening"
        }
    }
    
    private var statusMessage: String {
        if currentOrder != nil {
            return "Completing delivery"
        } else if isOnline {
            return "Ready for orders"
        } else {
            return "You're offline"
        }
    }
}

// MARK: - Online Toggle Button
struct CourierOnlineToggleButton: View {
    let isOnline: Bool
    let onToggle: () async -> Void
    @State private var isToggling = false
    
    var body: some View {
        Button(action: {
            Task {
                isToggling = true
                await onToggle()
                isToggling = false
            }
        }) {
            HStack(spacing: 8) {
                if isToggling {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Circle()
                        .fill(isOnline ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                }
                
                Text(isOnline ? "Online" : "Offline")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isOnline ? .green : .gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isOnline ? Color.green : Color.gray, lineWidth: 1.5)
            )
        }
        .disabled(isToggling)
    }
}

// MARK: - Current Order Card
struct CurrentOrderCard: View {
    let order: Order
    let onTap: () async -> Void
    
    var body: some View {
        Button(action: { Task { await onTap() } }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Current Delivery")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(order.status.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusFillColor(order.status).opacity(0.2))
                        .foregroundColor(statusFillColor(order.status))
                        .cornerRadius(6)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(order.addresses.pickup.street, systemImage: "location")
                            .font(.subheadline)
                        Label(order.addresses.dropoff.addressLine, systemImage: "location.fill")
                            .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("MAD \(order.total, specifier: "%.2f")")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Order #\(order.id?.suffix(6) ?? "---")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Tap to view details")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Available Orders Section
struct CourierDashboardAvailableOrdersSection: View {
    let orders: [Order]
    let isLoading: Bool
    let onAcceptOrder: (String) async -> Void
    let onDeclineOrder: (String, String) async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Orders")
                Spacer()
                if let bestEta = orders.compactMap({ $0.timings.etaSeconds }).min() {
                    Text("Best ETA ~\(Int(ceil(Double(bestEta)/60.0))) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
                .font(.headline)
                .fontWeight(.semibold)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading orders...")
                    Spacer()
                }
                .padding()
            } else if orders.isEmpty {
                EmptyOrdersCard()
            } else {
                ForEach(orders) { order in
                    CourierDashboardAvailableOrderCard(
                        order: order,
                        onAccept: { if let id = order.id { await onAcceptOrder(id) } },
                        onDecline: { reason in if let id = order.id { await onDeclineOrder(id, reason) } }
                    )
                }
            }
        }
    }
}

// MARK: - Available Order Card
struct CourierDashboardAvailableOrderCard: View {
    let order: Order
    let onAccept: () async -> Void
    let onDecline: (String) async -> Void
    
    @State private var showingDeclineOptions = false
    @State private var isAccepting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Order info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order #\(order.id?.suffix(6) ?? "---")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("MAD \(order.total, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(estimatedEarnings)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    if let eta = order.timings.etaSeconds {
                        Text("ETA ~\(Int(ceil(Double(eta)/60.0))) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(estimatedDistance)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Pickup and dropoff
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.orange)
                        .frame(width: 16)
                    Text(order.addresses.pickup.street)
                        .font(.subheadline)
                }
                
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .frame(width: 16)
                    Text(order.addresses.dropoff.addressLine)
                        .font(.subheadline)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Decline") {
                    showingDeclineOptions = true
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                
                Button(action: {
                    Task {
                        isAccepting = true
                        await onAccept()
                        isAccepting = false
                    }
                }) {
                    HStack {
                        if isAccepting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Accept")
                    }
                }
                .disabled(isAccepting)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .actionSheet(isPresented: $showingDeclineOptions) {
            ActionSheet(
                title: Text("Decline Order"),
                message: Text("Why are you declining this order?"),
                buttons: [
                    .default(Text("Too far")) {
                        Task { await onDecline("Too far") }
                    },
                    .default(Text("Going in wrong direction")) {
                        Task { await onDecline("Going in wrong direction") }
                    },
                    .default(Text("Taking a break")) {
                        Task { await onDecline("Taking a break") }
                    },
                    .default(Text("Other reason")) {
                        Task { await onDecline("Other") }
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private var estimatedEarnings: String {
        let fee = order.total * 0.15 // Estimated 15% commission for courier
        return "~MAD " + String(format: "%.0f", fee)
    }
    
    private var estimatedDistance: String {
        // Would calculate from coordinates in real implementation
        return "~3.2 km"
    }
}

// MARK: - Empty Orders Card
struct EmptyOrdersCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No orders available")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("New delivery opportunities will appear here when they become available.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Quick Stats Section
struct QuickStatsSection: View {
    let todayDeliveries: Int
    let todayEarnings: Double
    let rating: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                StatCard(title: "Deliveries", value: "\(todayDeliveries)", icon: "shippingbox")
                StatCard(title: "Earnings", value: "MAD " + String(format: "%.0f", todayEarnings), icon: "dollarsign.circle")
                StatCard(title: "Rating", value: String(format: "%.1f", rating), icon: "star.fill")
            }
        }
    }
}

// MARK: - Stat Card
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
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Offline Message Card
struct OfflineMessageCard: View {
    let action: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("You're Offline")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Go online to start receiving delivery requests and earn money.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Go Online") {
                Task { await action() }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Extensions
// Removed duplicate OrderStatus extension to avoid collisions; using the shared extension elsewhere in module.

// Local helper
private func statusFillColor(_ status: Order.OrderStatus) -> Color {
    switch status {
    case .created, .restaurantAccepted, .preparing, .readyForPickup: return .blue
    case .pickedUp, .onRoute: return .orange
    case .delivered: return .green
    case .cancelledByCustomer, .cancelledByMerchant, .cancelledNoCourier: return .red
    }
}

#Preview {
    CourierDashboardView(service: MockFoodDeliveryService())
}