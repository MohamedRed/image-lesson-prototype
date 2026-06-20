import SwiftUI
import FoodDeliveryService
import StripePaymentSheet
import UIKit

/// Checkout view for finalizing orders
public struct CheckoutView: View {
    @ObservedObject var viewModel: FoodDeliveryViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPaymentMethod: Order.PaymentInfo.PaymentMethod = .card
    @State private var deliveryAddress = ""
    @State private var deliveryInstructions = ""
    @State private var tipAmount: Double = 0
    @State private var isProcessingOrder = false
    @State private var showingAddressForm = false
    @State private var showingCODCheckout = false
    // PaymentSheet state
    @StateObject private var paymentService = FoodDeliveryStripePaymentService()
    @State private var showingPaymentSheet = false

    @State private var codPaymentAmount: Double = 0
    @State private var showingCouponInput = false
    @State private var appliedCoupon: String?
    @State private var couponDiscount: Double = 0
    
    private let tipOptions = [0.0, 5.0, 10.0, 15.0, 20.0]
    
    public init(viewModel: FoodDeliveryViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Delivery address section
                    deliveryAddressSection
                    
                    // Payment method section
                    paymentMethodSection
                    
                    // Tip section
                    tipSection
                    
                    // Coupon section
                    couponSection
                    
                    // Order summary
                    orderSummarySection
                }
                .padding()
            }
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                checkoutButton
            }
            .sheet(isPresented: $showingAddressForm) {
                AddressFormView(
                    address: $deliveryAddress,
                    instructions: $deliveryInstructions
                )
            }
            .sheet(isPresented: $showingCODCheckout) {
                CODCheckoutView(
                    orderTotal: totalAmount,
                    onConfirm: { amount in
                        codPaymentAmount = amount
                        showingCODCheckout = false
                        processOrder()
                    },
                    onCancel: {
                        showingCODCheckout = false
                    }
                )
            }
            .sheet(isPresented: $showingCouponInput) {
                CouponInputView(
                    couponCode: .constant(""),
                    onValidate: { code in
                        // Mock validation for now
                        return PromotionValidationResult(
                            isValid: true,
                            discountAmount: 15.0,
                            message: "Coupon applied successfully!"
                        )
                    },
                    onApply: { code in
                        appliedCoupon = code
                        couponDiscount = 15.0
                        showingCouponInput = false
                    }
                )
            }
        }
        // Presentation handled imperatively via presentPaymentSheet()
    }
    
    private var deliveryAddressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delivery Address")
                .font(.headline)
            
            Button(action: { showingAddressForm = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if deliveryAddress.isEmpty {
                            Text("Add delivery address")
                                .foregroundColor(.blue)
                        } else {
                            Text(deliveryAddress)
                                .foregroundColor(.primary)
                            
                            if !deliveryInstructions.isEmpty {
                                Text(deliveryInstructions)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
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
    
    private var paymentMethodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Method")
                .font(.headline)
            
            VStack(spacing: 8) {
                PaymentMethodRow(
                    method: .card,
                    icon: "creditcard",
                    title: "Credit/Debit Card",
                    subtitle: "Visa, Mastercard",
                    isSelected: selectedPaymentMethod == .card
                ) {
                    selectedPaymentMethod = .card
                }
                
                PaymentMethodRow(
                    method: .cashOnDelivery,
                    icon: "banknote",
                    title: "Cash on Delivery",
                    subtitle: "Pay with cash upon delivery",
                    isSelected: selectedPaymentMethod == .cashOnDelivery
                ) {
                    selectedPaymentMethod = .cashOnDelivery
                }
            }
        }
    }
    
    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a tip")
                .font(.headline)
            
            Text("Support your delivery driver")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach(tipOptions, id: \.self) { tip in
                    Button(action: { tipAmount = tip }) {
                        Text(tip == 0 ? "No tip" : "\(Int(tip)) MAD")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(tipAmount == tip ? Color.blue : Color(.systemGray5))
                            .foregroundColor(tipAmount == tip ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
        }
    }
    
    private var orderSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(viewModel.cartItems, id: \.id) { item in
                    HStack {
                        Text("\(item.quantity)x")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)
                        
                        Text(item.title)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(item.totalPrice, specifier: "%.0f") MAD")
                            .font(.subheadline)
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Subtotal")
                    Spacer()
                    Text("\(viewModel.cartTotal, specifier: "%.0f") MAD")
                }
                .font(.subheadline)
                
                HStack {
                    Text("Delivery fee")
                    Spacer()
                    Text("\(viewModel.deliveryFee, specifier: "%.0f") MAD")
                }
                .font(.subheadline)
                
                HStack {
                    Text("Service fee")
                    Spacer()
                    Text("\(viewModel.serviceFee, specifier: "%.2f") MAD")
                }
                .font(.subheadline)
                
                if tipAmount > 0 {
                    HStack {
                        Text("Tip")
                        Spacer()
                        Text("\(tipAmount, specifier: "%.0f") MAD")
                    }
                    .font(.subheadline)
                }
                
                if couponDiscount > 0 {
                    HStack {
                        Text("Promo discount")
                        Spacer()
                        Text("-\(couponDiscount, specifier: "%.2f") MAD")
                            .foregroundColor(.green)
                    }
                    .font(.subheadline)
                }
                
                Divider()
                
                HStack {
                    Text("Total")
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(totalAmount, specifier: "%.2f") MAD")
                        .fontWeight(.bold)
                }
                .font(.headline)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    private var checkoutButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button(action: placeOrder) {
                HStack {
                    if isProcessingOrder {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(isProcessingOrder ? "Processing..." : "Place Order")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(canPlaceOrder ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(25)
            }
            .disabled(!canPlaceOrder || isProcessingOrder)
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    private var couponSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Promo Code")
                .font(.headline)
            
            if let appliedCoupon = appliedCoupon {
                AppliedCouponView(
                    code: appliedCoupon,
                    discount: couponDiscount,
                    onRemove: {
                        self.appliedCoupon = nil
                        self.couponDiscount = 0
                    }
                )
            } else {
                Button(action: { showingCouponInput = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                        
                        Text("Add promo code")
                            .foregroundColor(.blue)
                        
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
    }
    
    private var totalAmount: Double {
        max(0, viewModel.cartTotal + viewModel.deliveryFee + viewModel.serviceFee + tipAmount - couponDiscount)
    }
    
    private var canPlaceOrder: Bool {
        !deliveryAddress.isEmpty && !viewModel.cartItems.isEmpty
    }
    
    private func placeOrder() {
        guard canPlaceOrder else { return }
        
        // If COD is selected, show COD checkout first
        if selectedPaymentMethod == .cashOnDelivery {
            showingCODCheckout = true
            return
        }
        
        // For card payments, ensure PaymentSheet is prepared then present
        processOrder()
    }
    
    private func processOrder() {
        isProcessingOrder = true
        
        let address = Order.OrderAddresses.DeliveryAddress(
            latitude: 33.5731, // Default coordinates for demo
            longitude: -7.5898,
            addressLine: deliveryAddress,
            city: "Casablanca",
            instructions: deliveryInstructions.isEmpty ? nil : deliveryInstructions
        )
        
        Task {
            let success = await viewModel.checkout(
                deliveryAddress: address,
                paymentMethod: selectedPaymentMethod,
                tip: tipAmount
            )
            
            await MainActor.run {
                if success, selectedPaymentMethod == .card, let order = viewModel.currentOrder {
                    Task { @MainActor in
                        await paymentService.preparePaymentSheet(orderId: order.id ?? "", amountMAD: order.total)
                        isProcessingOrder = false
                        presentPaymentSheet()
                    }
                } else {
                    isProcessingOrder = false
                    if success {
                        dismiss()
                    }
                }
            }
        }
    }

    private func presentPaymentSheet() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        paymentService.presentPaymentSheet(from: rootVC) { result in
            handlePaymentResult(result)
        }
    }

    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            dismiss()
        case .canceled:
            break
        case .failed:
            break
        }
    }
}

// MARK: - Supporting Views

struct PaymentMethodRow: View {
    let method: Order.PaymentInfo.PaymentMethod
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct AddressFormView: View {
    @Binding var address: String
    @Binding var instructions: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Delivery Address") {
                    TextField("Street address", text: $address)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Special Instructions") {
                    TextField("Apartment, floor, building details...", text: $instructions, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .navigationTitle("Delivery Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                    .disabled(address.isEmpty)
                }
            }
        }
    }
}

// MARK: - Applied Coupon View
struct AppliedCouponView: View {
    let code: String
    let discount: Double
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "ticket.fill")
                        .foregroundColor(.green)
                    
                    Text("Code: \(code)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text("You save MAD \(discount, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Button("Remove") {
                onRemove()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    CheckoutView(viewModel: FoodDeliveryViewModel(service: MockFoodDeliveryService()))
}