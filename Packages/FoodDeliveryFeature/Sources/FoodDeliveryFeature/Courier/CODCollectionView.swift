import SwiftUI
import FoodDeliveryService

/// View for couriers to collect cash on delivery payments
public struct CODCollectionView: View {
    let order: Order
    @ObservedObject var viewModel: CourierViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var collectedAmount: String = ""
    @State private var isCollecting = false
    @State private var showingCamera = false
    @State private var proofImageUrl: String?
    @State private var paymentValidation: PaymentValidation?
    
    private let codProcessor = CODPaymentProcessor.shared
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Order header
                    CODOrderHeader(order: order)
                    
                    // Collection amount input
                    CollectionAmountSection(
                        expectedAmount: order.total,
                        collectedAmount: $collectedAmount,
                        validation: paymentValidation,
                        onValidate: validateCollection
                    )
                    
                    // Quick amount buttons
                    QuickCollectionButtons(
                        expectedAmount: order.total,
                        onAmountSelected: { amount in
                            collectedAmount = String(format: "%.2f", amount)
                            validateCollection()
                        }
                    )
                    
                    // Collection proof section
                    CollectionProofSection(
                        proofImageUrl: proofImageUrl,
                        onTakePhoto: { showingCamera = true }
                    )
                    
                    // Customer instructions
                    CustomerInstructionsCard(order: order)
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Collect Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                CollectionConfirmButton(
                    isEnabled: canConfirmCollection,
                    isLoading: isCollecting,
                    onConfirm: confirmCollection
                )
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(onImageCaptured: { url in
                proofImageUrl = url
                showingCamera = false
            })
        }
        .onAppear {
            // Pre-fill with exact amount
            collectedAmount = String(format: "%.2f", order.total)
            validateCollection()
        }
    }
    
    private var canConfirmCollection: Bool {
        paymentValidation?.isValid == true && !collectedAmount.isEmpty
    }
    
    private func validateCollection() {
        guard let amount = Double(collectedAmount), amount > 0 else {
            paymentValidation = PaymentValidation(
                isValid: false,
                message: "Please enter a valid amount"
            )
            return
        }
        
        paymentValidation = codProcessor.validateCustomerPayment(
            orderTotal: order.total,
            customerPayment: amount
        )
    }
    
    private func confirmCollection() {
        guard let amount = Double(collectedAmount),
              let courierId = viewModel.courierProfile?.userId else { return }
        
        isCollecting = true
        
        Task {
            do {
                let proof = CODCollectionProof(
                    photoUrl: proofImageUrl,
                    timestamp: Date(),
                    location: viewModel.currentLocation.map { 
                        Coordinates(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                    },
                    customerSignature: nil // Could be added later
                )
                
                let _ = try await codProcessor.collectCashOnDelivery(
                    orderId: order.id!,
                    collectedAmount: amount,
                    courierId: courierId,
                    collectionProof: proof
                )
                
                // Confirm delivery in the main system
                await viewModel.confirmDelivery(proofImageUrl: proofImageUrl)
                
                await MainActor.run {
                    isCollecting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCollecting = false
                    // Handle error - could show alert
                }
            }
        }
    }
}

// MARK: - COD Order Header
struct CODOrderHeader: View {
    let order: Order
    
    var body: some View {
        VStack(spacing: 16) {
            // COD icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "banknote.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }
            
            // Order details
            VStack(spacing: 8) {
                Text("Cash on Delivery")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Order #\(order.id?.suffix(6) ?? "---")")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Amount to collect
                VStack(spacing: 4) {
                    Text("Amount to Collect")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("MAD \(order.total, specifier: "%.2f")")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Collection Amount Section
struct CollectionAmountSection: View {
    let expectedAmount: Double
    @Binding var collectedAmount: String
    let validation: PaymentValidation?
    let onValidate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Amount Collected")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Enter the amount the customer gave you")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Amount input
            HStack {
                Text("MAD")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                TextField("0.00", text: $collectedAmount)
                    .font(.title)
                    .fontWeight(.bold)
                    .keyboardType(.decimalPad)
                    .onChange(of: collectedAmount) { _ in
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
            }
        }
    }
}

// MARK: - Quick Collection Buttons
struct QuickCollectionButtons: View {
    let expectedAmount: Double
    let onAmountSelected: (Double) -> Void
    
    private var quickAmounts: [Double] {
        [
            expectedAmount, // Exact amount
            ceil(expectedAmount / 10) * 10, // Round to 10
            ceil(expectedAmount / 20) * 20, // Round to 20
            ceil(expectedAmount / 50) * 50  // Round to 50
        ].removingDuplicates().sorted()
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
                ForEach(quickAmounts.prefix(4), id: \.self) { amount in
                    QuickCollectionButton(
                        amount: amount,
                        expectedAmount: expectedAmount,
                        onTap: { onAmountSelected(amount) }
                    )
                }
            }
        }
    }
}

// MARK: - Quick Collection Button
struct QuickCollectionButton: View {
    let amount: Double
    let expectedAmount: Double
    let onTap: () -> Void
    
    private var changeAmount: Double {
        amount - expectedAmount
    }
    
    private var isExactAmount: Bool {
        abs(changeAmount) < 0.01
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text("MAD \(amount, specifier: "%.2f")")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if isExactAmount {
                    Text("Exact Amount")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                } else {
                    Text("Change: MAD \(changeAmount, specifier: "%.2f")")
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

// MARK: - Collection Proof Section
struct CollectionProofSection: View {
    let proofImageUrl: String?
    let onTakePhoto: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Collection Proof")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Take a photo as proof of payment collection")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: onTakePhoto) {
                HStack {
                    if let _ = proofImageUrl {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Photo Taken")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.blue)
                        Text("Take Photo")
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Customer Instructions Card
struct CustomerInstructionsCard: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Collection Guidelines")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                GuidelineRow(
                    icon: "1.circle.fill",
                    text: "Verify order contents with customer",
                    color: .blue
                )
                
                GuidelineRow(
                    icon: "2.circle.fill",
                    text: "Accept payment before handing over food",
                    color: .orange
                )
                
                GuidelineRow(
                    icon: "3.circle.fill",
                    text: "Provide change if needed (max MAD 50)",
                    color: .green
                )
                
                GuidelineRow(
                    icon: "4.circle.fill",
                    text: "Take photo as proof of collection",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Guideline Row
struct GuidelineRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Collection Confirm Button
struct CollectionConfirmButton: View {
    let isEnabled: Bool
    let isLoading: Bool
    let onConfirm: () -> Void
    
    var body: some View {
        Button(action: onConfirm) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(isLoading ? "Processing..." : "Confirm Collection")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isEnabled ? Color.orange : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!isEnabled || isLoading)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Camera View (Placeholder)
struct CameraView: View {
    let onImageCaptured: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Camera View")
                .font(.title)
            
            Text("In a real implementation, this would be a camera interface")
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Simulate Photo Taken") {
                onImageCaptured("mock_photo_url")
            }
            .buttonStyle(.borderedProminent)
            
            Button("Cancel") {
                dismiss()
            }
            .padding(.top)
        }
    }
}

// MARK: - Array Extension
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        return Array(Set(self))
    }
}

#Preview {
    let mockService = MockFoodDeliveryService()
    let viewModel = CourierViewModel(service: mockService)
    
    let mockOrder = Order(
        customerId: "customer123",
        restaurantId: "restaurant123",
        status: .pickedUp,
        items: [],
        subtotal: 75.0,
        deliveryFee: 15.0,
        serviceFee: 5.0,
        tip: 10.0,
        total: 105.0,
        payment: Order.PaymentInfo(method: .cashOnDelivery),
        addresses: Order.OrderAddresses(
            pickup: Restaurant.Address(
                city: "Casablanca",
                street: "123 Test St"
            ),
            dropoff: Order.OrderAddresses.DeliveryAddress(
                latitude: 33.5831,
                longitude: -7.5798,
                addressLine: "456 Customer St",
                city: "Casablanca"
            )
        )
    )
    
    return CODCollectionView(order: mockOrder, viewModel: viewModel)
}