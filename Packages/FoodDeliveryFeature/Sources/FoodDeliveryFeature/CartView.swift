import SwiftUI
import FoodDeliveryService

/// Shopping cart view showing selected items and checkout
public struct CartView: View {
    @ObservedObject var viewModel: FoodDeliveryViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCheckout = false
    @State private var showingAddressSelection = false
    
    public init(viewModel: FoodDeliveryViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            if viewModel.cartItems.isEmpty {
                emptyCartView
            } else {
                cartContentView
            }
        }
        .navigationTitle("Your Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingCheckout) {
            CheckoutView(viewModel: viewModel)
        }
    }
    
    private var emptyCartView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "cart")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("Your cart is empty")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Add some delicious items to get started!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Browse Restaurants") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .cornerRadius(25)
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var cartContentView: some View {
        VStack(spacing: 0) {
            // Restaurant info
            if let restaurant = viewModel.selectedRestaurant {
                restaurantInfoView(restaurant)
            }
            
            // Cart items list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.cartItems, id: \.id) { item in
                        CartItemRow(
                            item: item,
                            onQuantityChanged: { newQuantity in
                                viewModel.updateCartItemQuantity(itemId: item.id, quantity: newQuantity)
                            },
                            onRemove: {
                                viewModel.removeFromCart(itemId: item.id)
                            }
                        )
                    }
                }
                .padding()
            }
            
            Spacer()
            
            // Order summary and checkout
            orderSummaryView
        }
    }
    
    private func restaurantInfoView(_ restaurant: Restaurant) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: restaurant.logoUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.headline)
                
                HStack {
                    Text("\(restaurant.avgPrepMinutes)-\(restaurant.avgPrepMinutes + 10) min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(restaurant.deliveryFeePolicy.baseMAD)) MAD delivery")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    private var orderSummaryView: some View {
        VStack(spacing: 16) {
            // Order summary
            VStack(spacing: 8) {
                HStack {
                    Text("Subtotal")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(viewModel.cartTotal)) MAD")
                        .font(.subheadline)
                }
                
                HStack {
                    Text("Delivery fee")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(viewModel.deliveryFee)) MAD")
                        .font(.subheadline)
                }
                
                HStack {
                    Text("Service fee")
                        .font(.subheadline)
                    Spacer()
                    Text("\(viewModel.serviceFee, specifier: "%.2f") MAD")
                        .font(.subheadline)
                }
                
                Divider()
                
                HStack {
                    Text("Total")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(viewModel.cartTotal + viewModel.deliveryFee + viewModel.serviceFee, specifier: "%.2f") MAD")
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
            .padding(.horizontal)
            
            // Checkout button
            Button("Proceed to Checkout") {
                showingCheckout = true
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .cornerRadius(25)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
    }
}

// MARK: - Cart Item Row

struct CartItemRow: View {
    let item: Order.OrderItem
    let onQuantityChanged: (Int) -> Void
    let onRemove: () -> Void
    
    @State private var quantity: Int
    
    init(
        item: Order.OrderItem,
        onQuantityChanged: @escaping (Int) -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.item = item
        self.onQuantityChanged = onQuantityChanged
        self.onRemove = onRemove
        self._quantity = State(initialValue: item.quantity)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    // Selected options
                    if !item.selectedOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(item.selectedOptions, id: \.choiceId) { option in
                                HStack {
                                    Text("• \(option.choiceName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if option.priceDelta > 0 {
                                        Text("+\(option.priceDelta, specifier: "%.0f") MAD")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Special instructions
                    if let instructions = item.specialInstructions, !instructions.isEmpty {
                        Text("Note: \(instructions)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .italic()
                    }
                }
                
                Spacer()
                
                Text("\(item.totalPrice, specifier: "%.0f") MAD")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            HStack {
                // Quantity controls
                HStack(spacing: 12) {
                    Button {
                        if quantity > 1 {
                            quantity -= 1
                            onQuantityChanged(quantity)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(quantity > 1 ? .blue : .gray)
                            .font(.title2)
                    }
                    .disabled(quantity <= 1)
                    
                    Text("\(quantity)")
                        .font(.headline)
                        .frame(minWidth: 30)
                    
                    Button {
                        quantity += 1
                        onQuantityChanged(quantity)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
                
                Spacer()
                
                // Remove button
                Button("Remove") {
                    onRemove()
                }
                .font(.subheadline)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onChange(of: item.quantity) { newValue in
            quantity = newValue
        }
    }
}

#Preview {
    CartView(viewModel: FoodDeliveryViewModel(service: MockFoodDeliveryService()))
}