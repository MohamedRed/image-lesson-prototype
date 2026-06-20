import SwiftUI
import FoodDeliveryService

/// View for tracking order status and delivery progress
public struct OrderTrackingView: View {
    @ObservedObject var viewModel: FoodDeliveryViewModel
    let orderId: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCancelConfirmation = false
    @State private var showingContactOptions = false
    
    public init(orderId: String, viewModel: FoodDeliveryViewModel) {
        self.orderId = orderId
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let order = viewModel.trackingOrder {
                        // Order status header
                        orderStatusHeader(order)
                        
                        // Progress timeline
                        orderProgressTimeline(order)
                        
                        // Restaurant info
                        restaurantInfoSection(order)
                        
                        // Delivery address
                        deliveryAddressSection(order)
                        
                        // Order items
                        orderItemsSection(order)
                        
                        // Order summary
                        orderSummarySection(order)
                        
                        // Action buttons
                        actionButtonsSection(order)
                    } else if viewModel.isLoading {
                        loadingView
                    } else {
                        errorView
                    }
                }
                .padding()
            }
            .navigationTitle("Order Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.startTracking(orderId: orderId)
            }
            .confirmationDialog("Cancel Order", isPresented: $showingCancelConfirmation) {
                Button("Cancel Order", role: .destructive) {
                    Task {
                        _ = await viewModel.cancelOrder(orderId: orderId, reason: "Customer requested")
                    }
                }
                Button("Keep Order", role: .cancel) { }
            } message: {
                Text("Are you sure you want to cancel this order?")
            }
            .sheet(isPresented: $showingContactOptions) {
                ContactOptionsView(order: viewModel.trackingOrder)
            }
        }
    }
    
    private func orderStatusHeader(_ order: Order) -> some View {
        VStack(spacing: 16) {
            // Status icon and title
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(statusColor(order.status).opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: statusIcon(order.status))
                        .font(.title)
                        .foregroundColor(statusColor(order.status))
                }
                
                Text(statusTitle(order.status))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(statusSubtitle(order.status))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // ETA display
            if let eta = estimatedDeliveryTime(order) {
                VStack(spacing: 4) {
                    Text("Estimated Delivery")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(eta)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    private func orderProgressTimeline(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Order Progress")
                .font(.headline)
                .padding(.bottom, 16)
            
            VStack(spacing: 20) {
                TrackingTimelineStep(
                    title: "Order Placed",
                    subtitle: order.timings.createdAt?.formatted(date: .omitted, time: .shortened) ?? "",
                    isCompleted: true,
                    isCurrent: false
                )
                
                TrackingTimelineStep(
                    title: "Restaurant Confirmed",
                    subtitle: order.timings.acceptedAt?.formatted(date: .omitted, time: .shortened) ?? "Waiting...",
                    isCompleted: order.status.rawValue >= Order.OrderStatus.restaurantAccepted.rawValue,
                    isCurrent: order.status == .restaurantAccepted
                )
                
                TrackingTimelineStep(
                    title: "Preparing Food",
                    subtitle: order.status == .preparing ? "In progress..." : "",
                    isCompleted: order.status.rawValue >= Order.OrderStatus.preparing.rawValue,
                    isCurrent: order.status == .preparing
                )
                
                TrackingTimelineStep(
                    title: "Ready for Pickup",
                    subtitle: order.timings.readyAt?.formatted(date: .omitted, time: .shortened) ?? "",
                    isCompleted: order.status.rawValue >= Order.OrderStatus.readyForPickup.rawValue,
                    isCurrent: order.status == .readyForPickup
                )
                
                TrackingTimelineStep(
                    title: "Out for Delivery",
                    subtitle: order.timings.pickedUpAt?.formatted(date: .omitted, time: .shortened) ?? "",
                    isCompleted: order.status.rawValue >= Order.OrderStatus.onRoute.rawValue,
                    isCurrent: order.status == .onRoute
                )
                
                TrackingTimelineStep(
                    title: "Delivered",
                    subtitle: order.timings.deliveredAt?.formatted(date: .omitted, time: .shortened) ?? "",
                    isCompleted: order.status == .delivered,
                    isCurrent: false,
                    isLast: true
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func restaurantInfoSection(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restaurant")
                .font(.headline)
            
            HStack(spacing: 12) {
                // Restaurant logo placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "building.2")
                            .foregroundColor(.gray)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Restaurant Name") // Would be from restaurant data
                        .font(.headline)
                    
                    Text(order.addresses.pickup.street)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Contact") {
                    showingContactOptions = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func deliveryAddressSection(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delivery Address")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(order.addresses.dropoff.addressLine)
                    .font(.subheadline)
                
                Text("\(order.addresses.dropoff.city)\(order.addresses.dropoff.arrondissement.map { ", " + $0 } ?? "")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let instructions = order.addresses.dropoff.instructions {
                    Text("Instructions: \(instructions)")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .italic()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func orderItemsSection(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Items")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(order.items, id: \.id) { item in
                    HStack {
                        Text("\(item.quantity)x")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline)
                            
                            if !item.selectedOptions.isEmpty {
                                Text(item.selectedOptions.map { $0.choiceName }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text("\(item.totalPrice, specifier: "%.0f") MAD")
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func orderSummarySection(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary")
                .font(.headline)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Subtotal")
                    Spacer()
                    Text("\(order.subtotal, specifier: "%.0f") MAD")
                }
                .font(.subheadline)
                
                HStack {
                    Text("Delivery fee")
                    Spacer()
                    Text("\(order.deliveryFee, specifier: "%.0f") MAD")
                }
                .font(.subheadline)
                
                HStack {
                    Text("Service fee")
                    Spacer()
                    Text("\(order.serviceFee, specifier: "%.2f") MAD")
                }
                .font(.subheadline)
                
                if order.tip > 0 {
                    HStack {
                        Text("Tip")
                        Spacer()
                        Text("\(order.tip, specifier: "%.0f") MAD")
                    }
                    .font(.subheadline)
                }
                
                if let coupon = order.coupon {
                    HStack {
                        Text("Discount (\(coupon.code))")
                        Spacer()
                        Text("-\(coupon.discountAmount, specifier: "%.0f") MAD")
                            .foregroundColor(.green)
                    }
                    .font(.subheadline)
                }
                
                Divider()
                
                HStack {
                    Text("Total")
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(order.total, specifier: "%.2f") MAD")
                        .fontWeight(.bold)
                }
                .font(.headline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func actionButtonsSection(_ order: Order) -> some View {
        VStack(spacing: 12) {
            if canCancelOrder(order) {
                Button("Cancel Order") {
                    showingCancelConfirmation = true
                }
                .font(.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.red.opacity(0.1))
                .cornerRadius(25)
            }
            
            Button("Contact Support") {
                // Handle contact support
            }
            .font(.headline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(25)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading order details...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Unable to load order")
                .font(.headline)
            
            Text("Please try again or contact support")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Retry") {
                Task {
                    await viewModel.startTracking(orderId: orderId)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Helper Methods
    
    private func statusIcon(_ status: Order.OrderStatus) -> String {
        switch status {
        case .created:
            return "clock"
        case .restaurantAccepted, .preparing:
            return "chef.hat"
        case .readyForPickup:
            return "bag"
        case .pickedUp, .onRoute:
            return "car"
        case .delivered:
            return "checkmark.circle"
        case .cancelledByCustomer, .cancelledByMerchant, .cancelledNoCourier:
            return "xmark.circle"
        }
    }
    
    private func statusColor(_ status: Order.OrderStatus) -> Color {
        switch status {
        case .created, .restaurantAccepted, .preparing, .readyForPickup, .pickedUp, .onRoute:
            return .blue
        case .delivered:
            return .green
        case .cancelledByCustomer, .cancelledByMerchant, .cancelledNoCourier:
            return .red
        }
    }
    
    private func statusTitle(_ status: Order.OrderStatus) -> String {
        switch status {
        case .created:
            return "Order Placed"
        case .restaurantAccepted:
            return "Order Confirmed"
        case .preparing:
            return "Preparing Food"
        case .readyForPickup:
            return "Ready for Pickup"
        case .pickedUp:
            return "Picked Up"
        case .onRoute:
            return "On the Way"
        case .delivered:
            return "Delivered"
        case .cancelledByCustomer:
            return "Cancelled"
        case .cancelledByMerchant:
            return "Cancelled by Restaurant"
        case .cancelledNoCourier:
            return "Cancelled - No Courier"
        }
    }
    
    private func statusSubtitle(_ status: Order.OrderStatus) -> String {
        switch status {
        case .created:
            return "Waiting for restaurant confirmation"
        case .restaurantAccepted:
            return "Restaurant has accepted your order"
        case .preparing:
            return "Your food is being prepared"
        case .readyForPickup:
            return "Food is ready, waiting for courier"
        case .pickedUp:
            return "Courier has picked up your order"
        case .onRoute:
            return "Your order is on its way to you"
        case .delivered:
            return "Your order has been delivered"
        case .cancelledByCustomer:
            return "You cancelled this order"
        case .cancelledByMerchant:
            return "The restaurant cancelled this order"
        case .cancelledNoCourier:
            return "No courier was available"
        }
    }
    
    private func estimatedDeliveryTime(_ order: Order) -> String? {
        guard let eta = order.timings.etaSeconds else { return nil }
        
        let date = Date().addingTimeInterval(TimeInterval(eta))
        return date.formatted(date: .omitted, time: .shortened)
    }
    
    private func canCancelOrder(_ order: Order) -> Bool {
        switch order.status {
        case .created, .restaurantAccepted, .preparing:
            return true
        default:
            return false
        }
    }
}

// MARK: - Timeline Step View

struct TrackingTimelineStep: View {
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let isCurrent: Bool
    var isLast: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 0) {
                // Status circle
                ZStack {
                    Circle()
                        .fill(circleColor)
                        .frame(width: 20, height: 20)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                // Connecting line
                if !isLast {
                    Rectangle()
                        .fill(isCompleted ? Color.green : Color(.systemGray4))
                        .frame(width: 2, height: 30)
                        .padding(.top, 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isCurrent ? .semibold : .medium)
                    .foregroundColor(isCurrent ? .primary : (isCompleted ? .primary : .secondary))
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var circleColor: Color {
        if isCompleted {
            return .green
        } else if isCurrent {
            return .blue
        } else {
            return Color(.systemGray4)
        }
    }
}

// MARK: - Contact Options View

struct ContactOptionsView: View {
    let order: Order?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Contact Options")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 12) {
                    ContactOptionRow(
                        icon: "phone",
                        title: "Call Restaurant",
                        subtitle: "Speak directly with the restaurant"
                    ) {
                        // Handle restaurant call
                        dismiss()
                    }
                    
                    if order?.courierId != nil {
                        ContactOptionRow(
                            icon: "car",
                            title: "Call Courier",
                            subtitle: "Speak with your delivery driver"
                        ) {
                            // Handle courier call
                            dismiss()
                        }
                    }
                    
                    ContactOptionRow(
                        icon: "message",
                        title: "Chat Support",
                        subtitle: "Get help from customer support"
                    ) {
                        // Handle chat support
                        dismiss()
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ContactOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

#Preview {
    OrderTrackingView(
        orderId: "order1",
        viewModel: FoodDeliveryViewModel(service: MockFoodDeliveryService())
    )
}