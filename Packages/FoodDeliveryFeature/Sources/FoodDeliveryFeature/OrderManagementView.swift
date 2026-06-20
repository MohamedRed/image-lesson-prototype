import SwiftUI
import FoodDeliveryService

/// Order management interface for restaurants
public struct OrderManagementView: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    @State private var selectedFilter: OrderFilter = .active
    @State private var showingOrderDetails = false
    @State private var selectedOrder: Order?
    
    public var body: some View {
        VStack(spacing: 0) {
            // Order filters
            OrderFilterBar(selectedFilter: $selectedFilter)
            
            // Orders list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredOrders, id: \.id) { order in
                        OrderCard(
                            order: order,
                            onAction: { action in
                                handleOrderAction(order, action: action)
                            },
                            onTap: {
                                selectedOrder = order
                                showingOrderDetails = true
                            }
                        )
                    }
                }
                .padding()
            }
            .refreshable {
                await viewModel.refreshDashboard()
            }
        }
        .sheet(isPresented: $showingOrderDetails) {
            if let order = selectedOrder {
                OrderDetailsSheet(order: order, viewModel: viewModel)
            }
        }
    }
    
    private var filteredOrders: [Order] {
        switch selectedFilter {
        case .active:
            return viewModel.recentOrders.filter { order in
                [.created, .restaurantAccepted, .preparing, .readyForPickup].contains(order.status)
            }
        case .pending:
            return viewModel.recentOrders.filter { $0.status == .created }
        case .preparing:
            return viewModel.recentOrders.filter { $0.status == .preparing }
        case .ready:
            return viewModel.recentOrders.filter { $0.status == .readyForPickup }
        case .completed:
            return viewModel.recentOrders.filter { 
                [.delivered, .pickedUp, .onRoute].contains($0.status) 
            }
        case .cancelled:
            return viewModel.recentOrders.filter { 
                [.cancelledByCustomer, .cancelledByMerchant, .cancelledNoCourier].contains($0.status) 
            }
        }
    }
    
    private func handleOrderAction(_ order: Order, action: OrderCardAction) {
        Task {
            switch action {
            case .accept:
                if let id = order.id { await viewModel.handleOrderAction(id, action: .accept(prepTimeMinutes: 25)) }
            case .markReady:
                if let id = order.id { await viewModel.handleOrderAction(id, action: .markReady) }
            case .cancel:
                if let id = order.id { await viewModel.handleOrderAction(id, action: .cancel(reason: "Unable to prepare")) }
            }
        }
    }
}

// MARK: - Order Filter
enum OrderFilter: String, CaseIterable {
    case active = "Active"
    case pending = "Pending"
    case preparing = "Preparing"
    case ready = "Ready"
    case completed = "Completed"
    case cancelled = "Cancelled"
    
    var icon: String {
        switch self {
        case .active: return "clock.fill"
        case .pending: return "hourglass"
        case .preparing: return "flame.fill"
        case .ready: return "bag.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .blue
        case .pending: return .orange
        case .preparing: return .red
        case .ready: return .green
        case .completed: return .green
        case .cancelled: return .gray
        }
    }
}

// MARK: - Order Filter Bar
struct OrderFilterBar: View {
    @Binding var selectedFilter: OrderFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(OrderFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter,
                        color: filter.color
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Order Card
struct OrderCard: View {
    let order: Order
    let onAction: (OrderCardAction) -> Void
    let onTap: () -> Void
    
    private var timeRemaining: String? {
        guard let acceptedAt = order.timings.acceptedAt,
              let etaSeconds = order.timings.etaSeconds else { return nil }
        
        let estimatedReady = acceptedAt.addingTimeInterval(TimeInterval(etaSeconds))
        let remaining = estimatedReady.timeIntervalSince(Date())
        
        if remaining > 0 {
            let minutes = Int(remaining / 60)
            return "\(minutes) min remaining"
        } else {
            return "Overdue"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Order header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Order #\((order.id ?? "").suffix(6))")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        OrderStatusBadge(status: order.status)
                    }
                    
                    HStack(spacing: 16) {
                        if let createdAt = order.timings.createdAt {
                            Label(createdAt.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Label("\(order.items.count) items", systemImage: "bag")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("\(order.total, specifier: "%.0f") MAD", systemImage: "dollarsign.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let timeRemaining = timeRemaining {
                        Text(timeRemaining)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(timeRemaining.contains("Overdue") ? .red : .orange)
                    }
                    
                    Button("Details") {
                        onTap()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Order items preview
            VStack(alignment: .leading, spacing: 6) {
                Text("Items:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(order.items, id: \.id) { item in
                        OrderItemRow(item: item, isLast: item.id == order.items.last?.id)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Delivery address
            VStack(alignment: .leading, spacing: 4) {
                Text("Delivery Address:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(order.addresses.dropoff.addressLine)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Action buttons
            OrderActionButtons(
                status: order.status,
                onAction: onAction
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusBorderColor(for: order.status).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Order Status Badge
struct OrderStatusBadge: View {
    let status: Order.OrderStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusFillColor(for: status))
            .cornerRadius(8)
    }
}

// MARK: - Order Action Buttons
struct OrderActionButtons: View {
    let status: Order.OrderStatus
    let onAction: (OrderCardAction) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            switch status {
            case .created:
                Button("Accept Order") {
                    onAction(.accept)
                }
                .buttonStyle(PrimaryActionButtonStyle(color: .green))
                
                Button("Decline") {
                    onAction(.cancel)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                
            case .restaurantAccepted, .preparing:
                Button("Mark Ready") {
                    onAction(.markReady)
                }
                .buttonStyle(PrimaryActionButtonStyle(color: .blue))
                
                Button("Cancel") {
                    onAction(.cancel)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                
            case .readyForPickup:
                Text("Waiting for courier pickup")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Button Styles
struct PrimaryActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(color)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Order Card Actions
enum OrderCardAction {
    case accept
    case markReady
    case cancel
}

// MARK: - Order Details Sheet
struct OrderDetailsSheet: View {
    let order: Order
    @ObservedObject var viewModel: MerchantConsoleViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Order header
                    OrderDetailsHeader(order: order)
                    
                    // Customer information
                    CustomerInformationSection(order: order)
                    
                    // Order items
                    OrderItemsSection(order: order)
                    
                    // Delivery information
                    DeliveryInformationSection(order: order)
                    
                    // Order timeline
                    OrderTimelineSection(order: order)
                    
                    // Payment information
                    PaymentInformationSection(order: order)
                    
                    // Action buttons
                    if [.created, .restaurantAccepted, .preparing].contains(order.status) {
                        OrderDetailsActionButtons(
                            order: order,
                            viewModel: viewModel,
                            onDismiss: { dismiss() }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Order Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Order Details Header
struct OrderDetailsHeader: View {
    let order: Order
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Order #\((order.id ?? "").suffix(8))")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                OrderStatusBadge(status: order.status)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let createdAt = order.timings.createdAt {
                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(order.total, specifier: "%.2f") MAD")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Customer Information Section
struct CustomerInformationSection: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Customer Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                DetailRow(icon: "person", title: "Customer ID", value: order.customerId, color: .blue)
                DetailRow(icon: "phone", title: "Phone", value: "+212 6XX XXX XXX", color: .green) // Mock phone
                
                if let instructions = order.addresses.dropoff.instructions {
                    DetailRow(icon: "info.circle", title: "Special Instructions", value: instructions, color: .gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Order Items Section
struct OrderItemsSection: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Items (\(order.items.count))")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(order.items, id: \.id) { item in
                    OrderItemRow(item: item, isLast: item.id == order.items.last?.id)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Order Item Row
struct OrderItemRow: View {
    let item: Order.OrderItem
    let isLast: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(item.quantity)x")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if !item.selectedOptions.isEmpty {
                        Text(item.selectedOptions.map { $0.choiceName }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(item.totalPrice, specifier: "%.0f") MAD")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            if !isLast {
                Divider()
            }
        }
    }
}

// MARK: - Delivery Information Section
struct DeliveryInformationSection: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delivery Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                DetailRow(icon: "mappin.and.ellipse", title: "Address", value: order.addresses.dropoff.addressLine, color: .blue)
                DetailRow(icon: "building.2", title: "City", value: order.addresses.dropoff.city, color: .teal)
                
                if let arrondissement = order.addresses.dropoff.arrondissement {
                    DetailRow(icon: "map", title: "Area", value: arrondissement, color: .teal)
                }
                
                if let instructions = order.addresses.dropoff.instructions {
                    DetailRow(icon: "info.circle", title: "Instructions", value: instructions, color: .gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Order Timeline Section
struct OrderTimelineSection: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Timeline")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                if let createdAt = order.timings.createdAt {
                    TimelineItem(
                        title: "Order Placed",
                        time: createdAt,
                        isCompleted: true
                    )
                }
                
                if let acceptedAt = order.timings.acceptedAt {
                    TimelineItem(
                        title: "Restaurant Accepted",
                        time: acceptedAt,
                        isCompleted: true
                    )
                } else if order.status.rawValue >= Order.OrderStatus.restaurantAccepted.rawValue {
                    TimelineItem(
                        title: "Restaurant Accepted",
                        time: Date(),
                        isCompleted: true
                    )
                }
                
                if let readyAt = order.timings.readyAt {
                    TimelineItem(
                        title: "Order Ready",
                        time: readyAt,
                        isCompleted: true
                    )
                }
                
                if let pickedUpAt = order.timings.pickedUpAt {
                    TimelineItem(
                        title: "Picked Up",
                        time: pickedUpAt,
                        isCompleted: true
                    )
                }
                
                if let deliveredAt = order.timings.deliveredAt {
                    TimelineItem(
                        title: "Delivered",
                        time: deliveredAt,
                        isCompleted: true
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Timeline Item
struct TimelineItem: View {
    let title: String
    let time: Date
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isCompleted ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(time.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Payment Information Section
struct PaymentInformationSection: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                DetailRow(icon: "creditcard", title: "Payment Method", value: order.payment.method.displayName, color: .blue)
                DetailRow(icon: "cart", title: "Subtotal", value: String(format: "%.2f MAD", order.subtotal), color: .primary)
                DetailRow(icon: "truck.box", title: "Delivery Fee", value: String(format: "%.2f MAD", order.deliveryFee), color: .orange)
                DetailRow(icon: "gearshape", title: "Service Fee", value: String(format: "%.2f MAD", order.serviceFee), color: .gray)
                
                if order.tip > 0 {
                    DetailRow(icon: "banknote", title: "Tip", value: String(format: "%.2f MAD", order.tip), color: .green)
                }
                
                Divider()
                
                HStack {
                    Text("Total")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("\(order.total, specifier: "%.2f") MAD")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Order Details Action Buttons
struct OrderDetailsActionButtons: View {
    let order: Order
    @ObservedObject var viewModel: MerchantConsoleViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            switch order.status {
            case .created:
                Button("Accept Order") {
                    Task {
                        if let id = order.id { await viewModel.handleOrderAction(id, action: .accept(prepTimeMinutes: 25)) }
                        onDismiss()
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle(color: .green))
                
                Button("Decline Order") {
                    Task {
                        if let id = order.id { await viewModel.handleOrderAction(id, action: .cancel(reason: "Unable to prepare")) }
                        onDismiss()
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                
            case .restaurantAccepted, .preparing:
                Button("Mark as Ready") {
                    Task {
                        if let id = order.id { await viewModel.handleOrderAction(id, action: .markReady) }
                        onDismiss()
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle(color: .blue))
                
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Extensions
extension Order.PaymentInfo.PaymentMethod {
    var displayName: String {
        switch self {
        case .card: return "Credit Card"
        case .cashOnDelivery: return "Cash on Delivery"
        }
    }
}

// MARK: - Local status colors
private func statusFillColor(for status: Order.OrderStatus) -> Color {
    switch status {
    case .created, .restaurantAccepted, .preparing, .readyForPickup: return .blue
    case .pickedUp, .onRoute: return .orange
    case .delivered: return .green
    case .cancelledByCustomer, .cancelledByMerchant, .cancelledNoCourier: return .red
    }
}

private func statusBorderColor(for status: Order.OrderStatus) -> Color {
    switch status {
    case .created, .restaurantAccepted, .preparing, .readyForPickup: return .blue
    case .pickedUp, .onRoute: return .orange
    case .delivered: return .green
    case .cancelledByCustomer, .cancelledByMerchant, .cancelledNoCourier: return .red
    }
}

#Preview {
    OrderManagementView(viewModel: MerchantConsoleViewModel(restaurantId: "rest1", service: MockFoodDeliveryService()))
}