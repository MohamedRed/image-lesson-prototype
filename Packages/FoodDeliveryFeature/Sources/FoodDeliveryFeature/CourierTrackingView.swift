import SwiftUI
import FoodDeliveryService
import Combine

/// Real-time tracking interface for couriers
public struct CourierTrackingView: View {
    @StateObject private var viewModel: CourierTrackingViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeliveryProof = false
    @State private var showingNavigation = false
    @State private var selectedOrder: Order?
    
    public init(service: FoodDeliveryServicing) {
        self._viewModel = StateObject(wrappedValue: CourierTrackingViewModel(service: service))
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isOnline {
                    onlineInterface
                } else {
                    offlineInterface
                }
                
                // Floating action button for status toggle
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        statusToggleButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Courier Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task { await viewModel.refreshData() }
                        }
                        
                        Button("View Earnings", systemImage: "dollarsign.circle") {
                            // Show earnings view
                        }
                        
                        Button("Support", systemImage: "questionmark.circle") {
                            // Show support view
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.initialize()
        }
        .sheet(isPresented: $showingDeliveryProof) {
            if let order = selectedOrder {
                CourierDeliveryProofSheet(
                    order: order,
                    viewModel: viewModel
                )
            }
        }
    }
    
    private var onlineInterface: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status header
                OnlineStatusHeader(viewModel: viewModel)
                
                // Current deliveries
                if !viewModel.activeOrders.isEmpty {
                    ActiveDeliveriesSection(
                        orders: viewModel.activeOrders,
                        onOrderAction: { order, action in
                            handleOrderAction(order: order, action: action)
                        }
                    )
                }
                
                // Available orders
                if !viewModel.availableOrders.isEmpty {
                    CourierAvailableOrdersSection(
                        orders: viewModel.availableOrders,
                        onAcceptOrder: { order in
                            if let id = order.id { Task { await viewModel.acceptOrder(id) } }
                        }
                    )
                } else if viewModel.activeOrders.isEmpty {
                    NoOrdersView()
                }
                
                // Today's summary
                DailySummaryCard(viewModel: viewModel)
            }
            .padding()
        }
    }
    
    private var offlineInterface: some View {
        VStack(spacing: 32) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 16) {
                Text("You're Offline")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Go online to start receiving delivery requests and earning money")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button("Go Online") {
                Task { await viewModel.goOnline() }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.green)
            .cornerRadius(28)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var statusToggleButton: some View {
        Button(action: {
            Task {
                if viewModel.isOnline {
                    await viewModel.goOffline()
                } else {
                    await viewModel.goOnline()
                }
            }
        }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isOnline ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                
                Text(viewModel.isOnline ? "Online" : "Offline")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    private func handleOrderAction(order: Order, action: CourierOrderAction) {
        switch action {
        case .navigate:
            showingNavigation = true
            selectedOrder = order
        case .pickupConfirm:
            if let id = order.id { Task { await viewModel.confirmPickup(id) } }
        case .deliveryConfirm:
            selectedOrder = order
            showingDeliveryProof = true
        case .reportIssue:
            // Handle issue reporting
            break
        }
    }
}

// MARK: - Online Status Header
struct OnlineStatusHeader: View {
    @ObservedObject var viewModel: CourierTrackingViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You're Online")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Ready to deliver")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Active Orders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(viewModel.activeOrders.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            
            // Quick stats
            HStack(spacing: 20) {
                QuickStat(
                    title: "Today's Deliveries",
                    value: "\(viewModel.todaysDeliveries)",
                    color: .blue
                )
                
                QuickStat(
                    title: "Earnings",
                    value: String(format: "%.0f MAD", viewModel.todaysEarnings),
                    color: .green
                )
                
                QuickStat(
                    title: "Rating",
                    value: String(format: "%.1f", viewModel.rating),
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Quick Stat
struct QuickStat: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Active Deliveries Section
struct ActiveDeliveriesSection: View {
    let orders: [Order]
    let onOrderAction: (Order, CourierOrderAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Deliveries")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(orders, id: \.id) { order in
                    ActiveOrderCard(
                        order: order,
                        onAction: { action in
                            onOrderAction(order, action)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Active Order Card
struct ActiveOrderCard: View {
    let order: Order
    let onAction: (CourierOrderAction) -> Void
    
    private var nextAction: (String, CourierOrderAction, Color) {
        switch order.status {
        case .readyForPickup:
            return ("Navigate to Restaurant", .navigate, .blue)
        case .pickedUp:
            return ("Confirm Pickup", .pickupConfirm, .orange)
        case .onRoute:
            return ("Navigate to Customer", .navigate, .blue)
        default:
            return ("Confirm Delivery", .deliveryConfirm, .green)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Order header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order #\((order.id ?? "").suffix(6))")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(order.status.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(order.total, specifier: "%.0f") MAD")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("\(order.items.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Location info
            VStack(spacing: 8) {
                LocationRow(
                    icon: "building.2",
                    title: "Pickup",
                    address: order.addresses.pickup.street,
                    isCompleted: order.status.rawValue > Order.OrderStatus.readyForPickup.rawValue
                )
                
                LocationRow(
                    icon: "house",
                    title: "Delivery",
                    address: order.addresses.dropoff.addressLine,
                    isCompleted: order.status == .delivered
                )
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(nextAction.0) {
                    onAction(nextAction.1)
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(nextAction.2)
                .cornerRadius(8)
                
                Button("Issue") {
                    onAction(.reportIssue)
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.red)
                .frame(width: 80, height: 44)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Location Row
struct LocationRow: View {
    let icon: String
    let title: String
    let address: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(isCompleted ? .green : .blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(address)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Available Orders Section
struct CourierAvailableOrdersSection: View {
    let orders: [Order]
    let onAcceptOrder: (Order) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Orders")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(orders, id: \.id) { order in
                    CourierAvailableOrderCard(
                        order: order,
                        onAccept: { onAcceptOrder(order) }
                    )
                }
            }
        }
    }
}

// MARK: - Available Order Card
struct CourierAvailableOrderCard: View {
    let order: Order
    let onAccept: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(order.total, specifier: "%.0f") MAD")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("\(order.items.count) items • 2.3 km")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("15 min")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Est. time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "building.2")
                        .foregroundColor(.blue)
                        .frame(width: 16)
                    
                    Text(order.addresses.pickup.street)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "house")
                        .foregroundColor(.green)
                        .frame(width: 16)
                    
                    Text(order.addresses.dropoff.addressLine)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
            
            Button("Accept Order") {
                onAccept()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.blue)
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - No Orders View
struct NoOrdersView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No orders available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("New delivery requests will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Daily Summary Card
struct DailySummaryCard: View {
    @ObservedObject var viewModel: CourierTrackingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                SummaryItem(
                    title: "Deliveries",
                    value: "\(viewModel.todaysDeliveries)",
                    subtitle: "completed"
                )
                
                SummaryItem(
                    title: "Earnings",
                    value: String(format: "%.0f MAD", viewModel.todaysEarnings),
                    subtitle: "total"
                )
                
                SummaryItem(
                    title: "Hours",
                    value: String(format: "%.1f", viewModel.hoursOnline),
                    subtitle: "online"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Summary Item
struct SummaryItem: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Order Actions
enum CourierOrderAction {
    case navigate
    case pickupConfirm
    case deliveryConfirm
    case reportIssue
}

// MARK: - Delivery Proof Sheet
struct CourierDeliveryProofSheet: View {
    let order: Order
    @ObservedObject var viewModel: CourierTrackingViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var proofImage: UIImage?
    @State private var showingCamera = false
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Delivery Confirmation")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Order #\((order.id ?? "").suffix(6))")
                        .font(.headline)
                    
                    Text("Delivered to: \(order.addresses.dropoff.addressLine)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Photo section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Delivery Photo")
                        .font(.headline)
                    
                    if let image = proofImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(12)
                    } else {
                        Button("Take Photo") {
                            showingCamera = true
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            VStack {
                                Image(systemName: "camera")
                                    .font(.title)
                                    .foregroundColor(.gray)
                                Text("Tap to take photo")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        )
                    }
                }
                
                // Notes section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes (Optional)")
                        .font(.headline)
                    
                    TextField("Add delivery notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Spacer()
                
                Button("Confirm Delivery") {
                    Task {
                        if let id = order.id {
                            await viewModel.confirmDelivery(
                                id,
                                proofImage: proofImage,
                                notes: notes
                            )
                        }
                        dismiss()
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(proofImage != nil ? Color.green : Color.gray)
                .cornerRadius(28)
                .disabled(proofImage == nil)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            // Camera view would go here
            Text("Camera View")
        }
    }
}

// MARK: - Extensions
extension Order.OrderStatus {
    var displayName: String {
        switch self {
        case .created: return "Created"
        case .restaurantAccepted: return "Accepted"
        case .preparing: return "Preparing"
        case .readyForPickup: return "Ready for Pickup"
        case .pickedUp: return "Picked Up"
        case .onRoute: return "On Route"
        case .delivered: return "Delivered"
        case .cancelledByCustomer: return "Cancelled"
        case .cancelledByMerchant: return "Cancelled"
        case .cancelledNoCourier: return "Cancelled"
        }
    }
}

#Preview {
    CourierTrackingView(service: MockFoodDeliveryService())
}