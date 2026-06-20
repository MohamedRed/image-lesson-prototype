import SwiftUI
import FoodDeliveryService
import MapKit

private func statusFillColor(_ status: Order.OrderStatus) -> Color {
	switch status {
	case .created, .restaurantAccepted, .preparing, .readyForPickup: return .blue
	case .pickedUp, .onRoute: return .orange
	case .delivered: return .green
	case .cancelledByCustomer, .cancelledByMerchant, .cancelledNoCourier: return .red
	}
}

/// View for managing an active delivery order
public struct ActiveOrderView: View {
	@ObservedObject var viewModel: CourierViewModel
	let order: Order
	@Environment(\.dismiss) private var dismiss
	
	@State private var region = MKCoordinateRegion(
		center: CLLocationCoordinate2D(latitude: 33.5731, longitude: -7.5898),
		span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
	)
	@State private var showingCustomerContact = false
	@State private var showingDeliveryProof = false
	@State private var showingCODCollection = false
	@State private var orderRestaurantCoordinates: Coordinates = Coordinates(latitude: 0, longitude: 0)
	
	public var body: some View {
		NavigationView {
			ScrollView {
				VStack(spacing: 20) {
					// Order status card
					OrderStatusCard(order: order, viewModel: viewModel)
					
					// Map view
					MapSection(order: order, restaurantCoordinates: orderRestaurantCoordinates, region: $region)
					
					// Order details
					OrderDetailsSection(order: order)
					
					// Customer contact
					CustomerContactSection(order: order) {
						showingCustomerContact = true
					}
					
					// Action buttons
					ActionButtonsSection(
						order: order,
						viewModel: viewModel,
						onDeliveryProof: { showingDeliveryProof = true },
						onCODCollection: { showingCODCollection = true }
					)
				}
				.padding()
			}
			.navigationTitle("Active Delivery")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button("← Dashboard") {
						dismiss()
					}
				}
				
				ToolbarItem(placement: .navigationBarTrailing) {
					Button("Help", systemImage: "questionmark.circle") {
						// Show help/support
					}
				}
			}
		}
		.sheet(isPresented: $showingCustomerContact) {
			CustomerContactSheet(order: order)
		}
		.sheet(isPresented: $showingDeliveryProof) {
			ActiveDeliveryProofSheet(order: order, viewModel: viewModel)
		}
		.sheet(isPresented: $showingCODCollection) {
			CODCollectionView(order: order, viewModel: viewModel)
		}
		.onAppear {
			Task {
				if let coords = await viewModel.fetchRestaurantCoordinates(restaurantId: order.restaurantId) {
					orderRestaurantCoordinates = coords
				}
				setupMapRegion()
			}
		}
	}
	
	private func setupMapRegion() {
		let dropoff = order.addresses.dropoff
		
		// Center map between pickup and dropoff
		let centerLat = (orderRestaurantCoordinates.latitude + dropoff.latitude) / 2
		let centerLon = (orderRestaurantCoordinates.longitude + dropoff.longitude) / 2
		
		// Calculate span to show both locations
		let latDelta = abs(orderRestaurantCoordinates.latitude - dropoff.latitude) * 1.5
		let lonDelta = abs(orderRestaurantCoordinates.longitude - dropoff.longitude) * 1.5
		
		region = MKCoordinateRegion(
			center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
			span: MKCoordinateSpan(
				latitudeDelta: max(latDelta, 0.005),
				longitudeDelta: max(lonDelta, 0.005)
			)
		)
	}
}

// MARK: - Order Status Card
struct OrderStatusCard: View {
	let order: Order
	@ObservedObject var viewModel: CourierViewModel
	
	var body: some View {
		VStack(spacing: 16) {
			// Status indicator
			HStack {
				CourierStatusIndicator(status: order.status)
				
				Spacer()
				
				VStack(alignment: .trailing, spacing: 4) {
					Text("Order #\(order.id?.suffix(6) ?? "---")")
						.font(.subheadline)
						.fontWeight(.medium)
					
					Text("MAD \(order.total, specifier: "%.2f")")
						.font(.title2)
						.fontWeight(.bold)
				}
			}
			
			// Timeline
			OrderTimeline(order: order)
			
			// Next action
			if let statusInfo = viewModel.currentOrderStatusInfo {
				NextActionCard(
					title: statusInfo.title,
					subtitle: statusInfo.subtitle,
					actionNeeded: statusInfo.actionNeeded
				)
			}
		}
		.padding()
		.background(Color(.systemBackground))
		.cornerRadius(12)
		.shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
	}
}

// MARK: - Status Indicator
struct CourierStatusIndicator: View {
	let status: Order.OrderStatus
	
	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Circle()
					.fill(statusFillColor(status))
					.frame(width: 12, height: 12)
				
				Text(status.displayName)
					.font(.headline)
					.fontWeight(.semibold)
			}
			
			Text(statusDescription)
				.font(.subheadline)
				.foregroundColor(.secondary)
		}
	}
	
	private var statusDescription: String {
		switch status {
		case .restaurantAccepted:
			return "Restaurant has accepted the order"
		case .preparing:
			return "Food is being prepared"
		case .readyForPickup:
			return "Ready for pickup at restaurant"
		case .pickedUp:
			return "Order picked up, heading to customer"
		case .delivered:
			return "Order successfully delivered"
		default:
			return "Order status updated"
		}
	}
}

// MARK: - Order Timeline
struct OrderTimeline: View {
	let order: Order
	
	var body: some View {
		VStack(spacing: 8) {
			CourierTimelineStep(
				title: "Order Placed",
				time: order.createdAt,
				isCompleted: true,
				isActive: false
			)
			
			CourierTimelineStep(
				title: "Preparing",
				time: order.timings.acceptedAt,
				isCompleted: order.status.rawValue >= Order.OrderStatus.preparing.rawValue,
				isActive: order.status == .preparing
			)
			
			CourierTimelineStep(
				title: "Ready for Pickup",
				time: order.timings.readyAt,
				isCompleted: order.status.rawValue >= Order.OrderStatus.readyForPickup.rawValue,
				isActive: order.status == .readyForPickup
			)
			
			CourierTimelineStep(
				title: "Picked Up",
				time: order.timings.pickedUpAt,
				isCompleted: order.status.rawValue >= Order.OrderStatus.pickedUp.rawValue,
				isActive: order.status == .pickedUp
			)
			
			CourierTimelineStep(
				title: "Delivered",
				time: order.timings.deliveredAt,
				isCompleted: order.status == .delivered,
				isActive: false
			)
		}
	}
}

// MARK: - Timeline Step
struct CourierTimelineStep: View {
	let title: String
	let time: Date?
	let isCompleted: Bool
	let isActive: Bool
	
	var body: some View {
		HStack {
			// Status circle
			ZStack {
				Circle()
					.fill(isCompleted ? Color.green : (isActive ? Color.blue : Color.gray.opacity(0.3)))
					.frame(width: 16, height: 16)
				
				if isCompleted {
					Image(systemName: "checkmark")
						.font(.system(size: 10, weight: .bold))
						.foregroundColor(.white)
				} else if isActive {
					Circle()
						.fill(Color.white)
						.frame(width: 6, height: 6)
				}
			}
			
			// Title and time
			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.subheadline)
					.fontWeight(isActive ? .semibold : .regular)
					.foregroundColor(isCompleted || isActive ? .primary : .secondary)
				
				if let time = time {
					Text(timeString(time))
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
			
			Spacer()
		}
	}
	
	private func timeString(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.timeStyle = .short
		return formatter.string(from: date)
	}
}

// MARK: - Next Action Card
struct NextActionCard: View {
	let title: String
	let subtitle: String
	let actionNeeded: Bool
	
	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.headline)
					.fontWeight(.semibold)
				
				Text(subtitle)
					.font(.subheadline)
					.foregroundColor(.secondary)
			}
			
			Spacer()
			
			if actionNeeded {
				Image(systemName: "arrow.right.circle.fill")
					.font(.title2)
					.foregroundColor(.blue)
			}
		}
		.padding()
		.background(actionNeeded ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
		.cornerRadius(8)
	}
}

// MARK: - Map Section
struct MapSection: View {
	let order: Order
	let restaurantCoordinates: Coordinates
	@Binding var region: MKCoordinateRegion
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Route")
				.font(.headline)
				.fontWeight(.semibold)
			
			Map(coordinateRegion: $region, annotationItems: locations) { location in
				MapAnnotation(coordinate: location.coordinate) {
					LocationPin(
						type: location.type,
						title: location.title
					)
				}
			}
			.frame(height: 200)
			.cornerRadius(12)
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(Color(.systemGray4), lineWidth: 1)
			)
		}
	}
	
	private var locations: [MapLocation] {
		[
			MapLocation(
				coordinate: CLLocationCoordinate2D(
					latitude: restaurantCoordinates.latitude,
					longitude: restaurantCoordinates.longitude
				),
				title: "Pickup",
				type: .pickup
			),
			MapLocation(
				coordinate: CLLocationCoordinate2D(
					latitude: order.addresses.dropoff.latitude,
					longitude: order.addresses.dropoff.longitude
				),
				title: "Delivery",
				type: .dropoff
			)
		]
	}
}

// MARK: - Map Location
struct MapLocation: Identifiable {
	let id = UUID()
	let coordinate: CLLocationCoordinate2D
	let title: String
	let type: LocationType
	
	enum LocationType {
		case pickup, dropoff
	}
}

// MARK: - Location Pin
struct LocationPin: View {
	let type: MapLocation.LocationType
	let title: String
	
	var body: some View {
		VStack(spacing: 4) {
			ZStack {
				Circle()
					.fill(type == .pickup ? Color.orange : Color.blue)
					.frame(width: 24, height: 24)
				
				Image(systemName: type == .pickup ? "location" : "location.fill")
					.font(.system(size: 12, weight: .bold))
					.foregroundColor(.white)
			}
			
			Text(title)
				.font(.caption2)
				.fontWeight(.medium)
				.padding(.horizontal, 6)
				.padding(.vertical, 2)
				.background(Color(.systemBackground))
				.cornerRadius(4)
				.shadow(radius: 2)
		}
	}
}

// MARK: - Order Details Section
struct OrderDetailsSection: View {
	let order: Order
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Order Details")
				.font(.headline)
				.fontWeight(.semibold)
			
			VStack(spacing: 8) {
				ForEach(order.items, id: \.id) { item in
					CourierOrderItemRow(item: item)
				}
			}
		}
		.padding()
		.background(Color(.systemBackground))
		.cornerRadius(12)
		.shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
	}
}

// MARK: - Order Item Row
struct CourierOrderItemRow: View {
	let item: Order.OrderItem
	
	var body: some View {
		HStack {
			Text("\(item.quantity)x")
				.font(.subheadline)
				.fontWeight(.medium)
				.foregroundColor(.secondary)
				.frame(width: 30, alignment: .leading)
			
			VStack(alignment: .leading, spacing: 2) {
				Text(item.title)
					.font(.subheadline)
				
				if !item.selectedOptions.isEmpty {
					Text(item.selectedOptions.map { $0.title ?? $0.choiceName }.joined(separator: ", "))
						.font(.caption)
						.foregroundColor(.secondary)
				}
				
				if let instructions = item.specialInstructions, !instructions.isEmpty {
					Text("Note: \(instructions)")
						.font(.caption)
						.foregroundColor(.orange)
						.italic()
				}
			}
			
			Spacer()
			
			Text("MAD \(item.totalPrice, specifier: "%.2f")")
				.font(.subheadline)
				.fontWeight(.medium)
		}
		.padding(.vertical, 4)
	}
}

// MARK: - Customer Contact Section
struct CustomerContactSection: View {
	let order: Order
	let onContact: () -> Void
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Delivery Address")
				.font(.headline)
				.fontWeight(.semibold)
			
			Button(action: onContact) {
				HStack {
					VStack(alignment: .leading, spacing: 4) {
						Text(order.addresses.dropoff.addressLine)
							.font(.subheadline)
							.fontWeight(.medium)
						
						Text(order.addresses.dropoff.city)
							.font(.caption)
							.foregroundColor(.secondary)
						
						if let instructions = order.addresses.dropoff.instructions {
							Text("Instructions: \(instructions)")
								.font(.caption)
								.foregroundColor(.orange)
								.italic()
						}
					}
					
					Spacer()
					
					Image(systemName: "phone.circle.fill")
						.font(.title2)
						.foregroundColor(.blue)
				}
				.padding()
				.background(Color(.systemBackground))
				.cornerRadius(8)
				.overlay(
					RoundedRectangle(cornerRadius: 8)
						.stroke(Color.blue.opacity(0.3), lineWidth: 1)
				)
			}
			.buttonStyle(PlainButtonStyle())
		}
	}
}

// MARK: - Action Buttons Section
struct ActionButtonsSection: View {
	let order: Order
	@ObservedObject var viewModel: CourierViewModel
	let onDeliveryProof: () -> Void
	let onCODCollection: () -> Void
	
	var body: some View {
		VStack(spacing: 12) {
			if viewModel.canConfirmPickup {
				Button("Confirm Pickup") {
					Task {
						await viewModel.confirmPickup()
					}
				}
				.font(.headline)
				.foregroundColor(.white)
				.frame(maxWidth: .infinity)
				.padding()
				.background(Color.green)
				.cornerRadius(12)
			}
			
			if viewModel.canConfirmDelivery {
				// For COD orders, show collection button first
				if order.payment.method == .cashOnDelivery && order.status == .pickedUp {
					Button("Collect Payment") {
						onCODCollection()
					}
					.font(.headline)
					.foregroundColor(.white)
					.frame(maxWidth: .infinity)
					.padding()
					.background(Color.orange)
					.cornerRadius(12)
				} else {
					Button("Confirm Delivery") {
						onDeliveryProof()
					}
					.font(.headline)
					.foregroundColor(.white)
					.frame(maxWidth: .infinity)
					.padding()
					.background(Color.blue)
					.cornerRadius(12)
				}
			}
			
			// Emergency contact
			Button("Contact Support") {
				// Show support contact
			}
			.font(.subheadline)
			.foregroundColor(.orange)
			.frame(maxWidth: .infinity)
			.padding()
			.background(Color.orange.opacity(0.1))
			.cornerRadius(8)
		}
	}
}

// MARK: - Customer Contact Sheet
struct CustomerContactSheet: View {
	let order: Order
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		NavigationView {
			VStack(spacing: 24) {
				// Customer info
				VStack(spacing: 16) {
					Image(systemName: "person.circle.fill")
						.font(.system(size: 60))
						.foregroundColor(.blue)
					
					Text("Customer Contact")
						.font(.title2)
						.fontWeight(.semibold)
					
					Text("Order #\(order.id?.suffix(6) ?? "---")")
						.font(.subheadline)
						.foregroundColor(.secondary)
				}
				
				// Contact options
				VStack(spacing: 16) {
					ContactButton(
						icon: "phone.fill",
						title: "Call Customer",
						subtitle: "Direct call for delivery coordination",
						color: .green
					) {
						// Make phone call
						dismiss()
					}
					
					ContactButton(
						icon: "message.fill",
						title: "Send Message",
						subtitle: "Quick text message to customer",
						color: .blue
					) {
						// Send message
						dismiss()
					}
				}
				
				Spacer()
			}
			.padding()
			.navigationTitle("Contact Customer")
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

// MARK: - Contact Button
struct ContactButton: View {
	let icon: String
	let title: String
	let subtitle: String
	let color: Color
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			HStack(spacing: 16) {
				Image(systemName: icon)
					.font(.title2)
					.foregroundColor(color)
					.frame(width: 32)
				
				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.headline)
						.fontWeight(.medium)
					
					Text(subtitle)
						.font(.subheadline)
						.foregroundColor(.secondary)
				}
				
				Spacer()
				
				Image(systemName: "chevron.right")
					.font(.subheadline)
					.foregroundColor(.secondary)
			}
			.padding()
			.background(Color(.systemBackground))
			.cornerRadius(12)
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(color.opacity(0.3), lineWidth: 1)
			)
		}
		.buttonStyle(PlainButtonStyle())
	}
}

// MARK: - Delivery Proof Sheet
struct ActiveDeliveryProofSheet: View {
	let order: Order
	@ObservedObject var viewModel: CourierViewModel
	@Environment(\.dismiss) private var dismiss
	
	@State private var selectedProofMethod: ProofMethod = .photo
	@State private var isConfirming = false
	
	enum ProofMethod: CaseIterable {
		case photo, signature, handoff
		
		var title: String {
			switch self {
			case .photo: return "Take Photo"
			case .signature: return "Get Signature"
			case .handoff: return "Direct Handoff"
			}
		}
		
		var icon: String {
			switch self {
			case .photo: return "camera.fill"
			case .signature: return "signature"
			case .handoff: return "hand.raised.fill"
			}
		}
	}
	
	var body: some View {
		NavigationView {
			VStack(spacing: 24) {
				// Header
				VStack(spacing: 8) {
					Text("Confirm Delivery")
						.font(.title2)
						.fontWeight(.semibold)
					
					Text("Select how you'd like to confirm this delivery")
						.font(.subheadline)
						.foregroundColor(.secondary)
						.multilineTextAlignment(.center)
				}
				
				// Proof method selection
				VStack(spacing: 12) {
					ForEach(ProofMethod.allCases, id: \.self) { method in
						ProofMethodButton(
							method: method,
							isSelected: selectedProofMethod == method
						) {
							selectedProofMethod = method
						}
					}
				}
				
				Spacer()
				
				// Confirm button
				Button(action: confirmDelivery) {
					HStack {
						if isConfirming {
							ProgressView()
								.scaleEffect(0.8)
						}
						Text("Confirm Delivery")
					}
				}
				.disabled(isConfirming)
				.font(.headline)
				.foregroundColor(.white)
				.frame(maxWidth: .infinity)
				.padding()
				.background(Color.blue)
				.cornerRadius(12)
			}
			.padding()
			.navigationTitle("Delivery Proof")
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
	
	private func confirmDelivery() {
		Task {
			isConfirming = true
			await viewModel.confirmDelivery()
			isConfirming = false
			dismiss()
		}
	}
}

// MARK: - Proof Method Button
struct ProofMethodButton: View {
	let method: ActiveDeliveryProofSheet.ProofMethod
	let isSelected: Bool
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			HStack(spacing: 16) {
				Image(systemName: method.icon)
					.font(.title2)
					.foregroundColor(isSelected ? .blue : .secondary)
					.frame(width: 32)
				
				Text(method.title)
					.font(.headline)
					.fontWeight(.medium)
					.foregroundColor(isSelected ? .blue : .primary)
				
				Spacer()
				
				if isSelected {
					Image(systemName: "checkmark.circle.fill")
						.font(.title2)
						.foregroundColor(.blue)
				} else {
					Circle()
						.stroke(Color(.systemGray4), lineWidth: 2)
						.frame(width: 24, height: 24)
				}
			}
			.padding()
			.background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
			.cornerRadius(12)
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 1)
			)
		}
		.buttonStyle(PlainButtonStyle())
	}
}

#Preview {
	let mockService = MockFoodDeliveryService()
	let viewModel = CourierViewModel(service: mockService)
	
	// Create mock order
	let mockOrder = Order(
		customerId: "customer123",
		restaurantId: "restaurant123",
		status: .readyForPickup,
		items: [
			Order.OrderItem(
				menuItemId: "item1",
				title: "Chicken Tagine",
				basePrice: 75.0,
				quantity: 1,
				selectedOptions: [],
				totalPrice: 75.0,
				specialInstructions: "Extra sauce please"
			)
		],
		subtotal: 75.0,
		deliveryFee: 15.0,
		serviceFee: 5.0,
		tip: 10.0,
		total: 105.0,
		coupon: nil,
		payment: Order.PaymentInfo(method: .cashOnDelivery, status: .pending),
		addresses: Order.OrderAddresses(
			pickup: Restaurant.Address(city: "Casablanca", arrondissement: nil, street: "123 Hassan II Boulevard"),
			dropoff: Order.OrderAddresses.DeliveryAddress(
				latitude: 33.5831,
				longitude: -7.5798,
				addressLine: "456 Mohammed V Avenue",
				city: "Casablanca",
				arrondissement: nil,
				instructions: "Ring the doorbell twice"
			)
		)
	)
	
	ActiveOrderView(viewModel: viewModel, order: mockOrder)
}