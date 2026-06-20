import SwiftUI
import FoodDeliveryService

/// Cash on Delivery checkout view with payment validation and instructions
public struct CODCheckoutView: View {
    let orderTotal: Double
    let onConfirm: (Double) -> Void
    let onCancel: () -> Void
    
    @State private var customerPayment: String = ""
    @State private var paymentValidation: PaymentValidation?
    @State private var isValidating = false
    @State private var showingInfo = false
    
    private let codProcessor = CODPaymentProcessor.shared
    
    public init(
        orderTotal: Double,
        onConfirm: @escaping (Double) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.orderTotal = orderTotal
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    CODHeaderSection(total: orderTotal)
                    
                    // Payment amount input
                    PaymentInputSection(
                        payment: $customerPayment,
                        validation: paymentValidation,
                        onValidate: validatePayment
                    )
                    
                    // Quick amount buttons
                    QuickAmountSection(
                        orderTotal: orderTotal,
                        onAmountSelected: { amount in
                            customerPayment = String(format: "%.0f", amount)
                            validatePayment()
                        }
                    )
                    
                    // COD information
                    CODInformationCard()
                    
                    // Terms and conditions
                    CODTermsSection()
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Cash on Delivery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Info", systemImage: "info.circle") {
                        showingInfo = true
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                ConfirmButton(
                    isEnabled: paymentValidation?.isValid == true,
                    onConfirm: {
                        if let amount = Double(customerPayment) {
                            onConfirm(amount)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingInfo) {
            CODInfoSheet()
        }
        .onAppear {
            // Pre-fill with suggested optimal payment
            let suggested = suggestOptimalPayment(for: orderTotal)
            customerPayment = String(format: "%.0f", suggested)
            validatePayment()
        }
    }
    
    private func validatePayment() {
        guard let amount = Double(customerPayment), amount > 0 else {
            paymentValidation = PaymentValidation(
                isValid: false,
                message: "Please enter a valid amount"
            )
            return
        }
        
        paymentValidation = codProcessor.validateCustomerPayment(
            orderTotal: orderTotal,
            customerPayment: amount
        )
    }
    
    private func suggestOptimalPayment(for total: Double) -> Double {
        let commonDenominations = [20.0, 50.0, 100.0, 200.0]
        
        for denomination in commonDenominations {
            if total <= denomination && (denomination - total) <= 20.0 {
                return denomination
            }
        }
        
        return ceil(total / 10.0) * 10.0
    }
}

// MARK: - COD Header Section
struct CODHeaderSection: View {
    let total: Double
    
    var body: some View {
        VStack(spacing: 16) {
            // COD Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "banknote.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
            }
            
            // Order total
            VStack(spacing: 4) {
                Text("Order Total")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("MAD \(total, specifier: "%.2f")")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            // COD badge
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Cash on Delivery Available")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1))
            .cornerRadius(20)
        }
    }
}

// MARK: - Payment Input Section
struct PaymentInputSection: View {
    @Binding var payment: String
    let validation: PaymentValidation?
    let onValidate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How much will you pay?")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Enter the amount you'll give to the courier")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Payment input
            HStack {
                Text("MAD")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("Amount", text: $payment)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .keyboardType(.decimalPad)
                    .onChange(of: payment) { _ in
                        onValidate()
                    }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Validation feedback
            if let validation = validation {
                HStack {
                    Image(systemName: validation.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(validation.isValid ? .green : .orange)
                    
                    Text(validation.message)
                        .font(.subheadline)
                        .foregroundColor(validation.isValid ? .green : .orange)
                        .fontWeight(.medium)
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Quick Amount Section
struct QuickAmountSection: View {
    let orderTotal: Double
    let onAmountSelected: (Double) -> Void
    
    private var suggestedAmounts: [Double] {
        let base = orderTotal
        let suggestions = [
            base, // Exact amount
            ceil(base / 10) * 10, // Round to nearest 10
            ceil(base / 20) * 20, // Round to nearest 20
            ceil(base / 50) * 50  // Round to nearest 50
        ].compactMap { $0 }
        
        // Remove duplicates and sort
        return Array(Set(suggestions)).sorted().filter { $0 >= base }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Select")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(suggestedAmounts.prefix(4), id: \.self) { amount in
                    QuickAmountButton(
                        amount: amount,
                        orderTotal: orderTotal,
                        onTap: { onAmountSelected(amount) }
                    )
                }
            }
        }
    }
}

// MARK: - Quick Amount Button
struct QuickAmountButton: View {
    let amount: Double
    let orderTotal: Double
    let onTap: () -> Void
    
    private var changeAmount: Double {
        amount - orderTotal
    }
    
    private var isExactAmount: Bool {
        changeAmount < 0.01
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text("MAD \(amount, specifier: "%.0f")")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if isExactAmount {
                    Text("Exact Amount")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                } else {
                    Text("Change: MAD \(changeAmount, specifier: "%.0f")")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isExactAmount ? Color.green.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isExactAmount ? Color.green : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - COD Information Card
struct CODInformationCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What to Expect")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                CODInfoRow(
                    icon: "1.circle.fill",
                    title: "Courier arrives",
                    description: "The courier will arrive at your location with your order",
                    color: .blue
                )
                
                CODInfoRow(
                    icon: "2.circle.fill",
                    title: "Verify your order",
                    description: "Check that all items are correct before payment",
                    color: .orange
                )
                
                CODInfoRow(
                    icon: "3.circle.fill",
                    title: "Pay with cash",
                    description: "Give the exact amount or receive change",
                    color: .green
                )
                
                CODInfoRow(
                    icon: "4.circle.fill",
                    title: "Enjoy your meal",
                    description: "Order complete! Rate your experience",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Info Row
struct CODInfoRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - COD Terms Section
struct CODTermsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Important Notes")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 6) {
                BulletPoint("Payment is due upon delivery")
                BulletPoint("Have exact change or close to it ready")
                BulletPoint("Maximum change provided: MAD 50")
                BulletPoint("You can request a receipt from the courier")
                BulletPoint("Refunds are processed according to our refund policy")
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Bullet Point
struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.orange)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Confirm Button
struct ConfirmButton: View {
    let isEnabled: Bool
    let onConfirm: () -> Void
    
    var body: some View {
        Button(action: onConfirm) {
            Text("Confirm Cash Payment")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isEnabled ? Color.green : Color.gray)
                .cornerRadius(12)
        }
        .disabled(!isEnabled)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - COD Info Sheet
struct CODInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Cash on Delivery")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Everything you need to know about paying with cash")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Availability
                    CODInfoSection(
                        title: "Availability",
                        icon: "location.circle.fill",
                        color: .blue,
                        content: [
                            "Available in major Moroccan cities",
                            "Minimum order: MAD 30",
                            "Maximum order: MAD 500",
                            "Service hours: 9 AM - 11 PM"
                        ]
                    )
                    
                    // How it works
                    CODInfoSection(
                        title: "How It Works",
                        icon: "gear.circle.fill",
                        color: .green,
                        content: [
                            "Place your order and select 'Cash on Delivery'",
                            "A courier will be assigned to your order",
                            "Pay the courier when they arrive",
                            "Get a receipt and enjoy your meal"
                        ]
                    )
                    
                    // Tips for smooth delivery
                    CODInfoSection(
                        title: "Tips for Smooth Delivery",
                        icon: "lightbulb.circle.fill",
                        color: .orange,
                        content: [
                            "Have the exact amount or close to it ready",
                            "Ensure someone is available to receive the order",
                            "Keep your phone nearby for courier contact",
                            "Check your order before making payment"
                        ]
                    )
                    
                    // Safety
                    CODInfoSection(
                        title: "Safety & Security",
                        icon: "shield.circle.fill",
                        color: .purple,
                        content: [
                            "All couriers are verified and trained",
                            "Contactless delivery options available",
                            "Report any issues through the app",
                            "24/7 customer support available"
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("COD Information")
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

// MARK: - Info Section
struct CODInfoSection: View {
    let title: String
    let icon: String
    let color: Color
    let content: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(content, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(color.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        
                        Text(item)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    CODCheckoutView(
        orderTotal: 85.50,
        onConfirm: { amount in
            print("Confirmed payment amount: MAD \(amount)")
        },
        onCancel: {
            print("COD checkout cancelled")
        }
    )
}