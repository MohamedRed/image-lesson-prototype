import SwiftUI
import FoodDeliveryService

/// View for entering and validating coupon codes
public struct CouponInputView: View {
    @Binding var couponCode: String
    let onValidate: (String) async -> PromotionValidationResult
    let onApply: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var isValidating = false
    @State private var validationResult: PromotionValidationResult?
    @State private var showingValidation = false
    
    public init(
        couponCode: Binding<String>,
        onValidate: @escaping (String) async -> PromotionValidationResult,
        onApply: @escaping (String) -> Void
    ) {
        self._couponCode = couponCode
        self.onValidate = onValidate
        self.onApply = onApply
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    CouponInputHeader()
                    
                    // Input section
                    CouponCodeInputSection(
                        couponCode: $couponCode,
                        isValidating: isValidating,
                        onValidate: validateCoupon
                    )
                    
                    // Validation result
                    if let result = validationResult {
                        CouponValidationResult(result: result)
                    }
                    
                    // Quick access to popular codes
                    PopularCodesSection(onCodeSelected: { code in
                        couponCode = code
                        validateCoupon()
                    })
                    
                    // How to get coupons
                    HowToGetCouponsSection()
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Enter Coupon Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply(couponCode)
                    }
                    .disabled(!canApplyCoupon)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var canApplyCoupon: Bool {
        validationResult?.isValid == true && !couponCode.isEmpty
    }
    
    private func validateCoupon() {
        guard !couponCode.isEmpty else {
            validationResult = nil
            return
        }
        
        isValidating = true
        
        Task {
            let result = await onValidate(couponCode.uppercased())
            await MainActor.run {
                self.validationResult = result
                self.isValidating = false
                self.showingValidation = true
            }
        }
    }
}

// MARK: - Coupon Input Header
struct CouponInputHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "ticket.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text("Got a Coupon Code?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Enter your coupon code to unlock exclusive discounts and free delivery offers")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Coupon Code Input Section
struct CouponCodeInputSection: View {
    @Binding var couponCode: String
    let isValidating: Bool
    let onValidate: () -> Void
    
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coupon Code")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                TextField("Enter code (e.g., WELCOME2024)", text: $couponCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.headline)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .focused($isInputFocused)
                    .onChange(of: couponCode) { newValue in
                        // Auto-validate after user stops typing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if couponCode == newValue && !newValue.isEmpty {
                                onValidate()
                            }
                        }
                    }
                
                Button(action: onValidate) {
                    if isValidating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Check")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(couponCode.isEmpty || isValidating)
                .frame(width: 80, height: 44)
                .background(couponCode.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Input hints
            VStack(alignment: .leading, spacing: 4) {
                InputHint(
                    icon: "lightbulb.fill",
                    text: "Codes are case-insensitive",
                    color: .blue
                )
                
                InputHint(
                    icon: "clock.fill",
                    text: "Check expiration dates",
                    color: .orange
                )
                
                InputHint(
                    icon: "person.fill",
                    text: "Some codes are personalized",
                    color: .purple
                )
            }
            .padding(.top, 8)
        }
        .onAppear {
            isInputFocused = true
        }
    }
}

// MARK: - Input Hint
struct InputHint: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Coupon Validation Result
struct CouponValidationResult: View {
    let result: PromotionValidationResult
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(result.isValid ? .green : .red)
                
                Text(result.message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(result.isValid ? .green : .red)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
            if result.isValid, let promotion = result.appliedPromotion {
                PromotionSummaryCard(promotion: promotion, discountAmount: result.discountAmount)
            }
            
            if !result.isValid && !result.errors.isEmpty {
                ErrorDetailsView(errors: result.errors)
            }
        }
        .padding()
        .background(result.isValid ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Promotion Summary Card
struct PromotionSummaryCard: View {
    let promotion: Promotion
    let discountAmount: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Promotion Details")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("MAD \(discountAmount, specifier: "%.2f") OFF")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(promotion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(promotion.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if promotion.discount.freeDelivery {
                    HStack {
                        Image(systemName: "truck.box.fill")
                            .foregroundColor(.blue)
                        Text("Includes free delivery")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Error Details View
struct ErrorDetailsView: View {
    let errors: [PromotionValidationResult.PromotionError]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Issues Found:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.red)
            
            ForEach(errors, id: \.self) { error in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 4, height: 4)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Popular Codes Section
struct PopularCodesSection: View {
    let onCodeSelected: (String) -> Void
    
    private let popularCodes = [
        ("WELCOME2024", "New customer discount"),
        ("FREEDEL", "Free delivery offer"),
        ("WEEKEND20", "Weekend special"),
        ("LOYAL10", "Loyalty reward")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular Codes")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Try these popular coupon codes that might work for you")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                ForEach(popularCodes, id: \.0) { code, description in
                    PopularCodeRow(
                        code: code,
                        description: description,
                        onTap: { onCodeSelected(code) }
                    )
                }
            }
        }
    }
}

// MARK: - Popular Code Row
struct PopularCodeRow: View {
    let code: String
    let description: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(code)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - How to Get Coupons Section
struct HowToGetCouponsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Get More Coupons")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                CouponTipRow(
                    icon: "star.fill",
                    title: "Complete your first order",
                    description: "Get a welcome coupon after your first successful order",
                    color: .yellow
                )
                
                CouponTipRow(
                    icon: "heart.fill",
                    title: "Be a loyal customer",
                    description: "Regular customers receive personalized discount codes",
                    color: .red
                )
                
                CouponTipRow(
                    icon: "envelope.fill",
                    title: "Enable notifications",
                    description: "Get notified about exclusive promotions and flash sales",
                    color: .blue
                )
                
                CouponTipRow(
                    icon: "person.2.fill",
                    title: "Refer friends",
                    description: "Both you and your friend get coupons when they order",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Coupon Tip Row
struct CouponTipRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            
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

// MARK: - Extensions
extension PromotionValidationResult.PromotionError {
    var localizedDescription: String {
        switch self {
        case .promotionNotFound:
            return "Coupon code not found"
        case .promotionExpired:
            return "This coupon has expired"
        case .promotionInactive:
            return "This coupon is no longer active"
        case .usageLimitExceeded:
            return "This coupon has already been used"
        case .minimumOrderNotMet:
            return "Minimum order value not met"
        case .restaurantNotEligible:
            return "Not valid for this restaurant"
        case .customerNotEligible:
            return "You are not eligible for this coupon"
        case .paymentMethodNotEligible:
            return "Not valid for selected payment method"
        case .timeNotEligible:
            return "Not valid at this time"
        case .alreadyApplied:
            return "This coupon has already been applied"
        }
    }
}

#Preview {
    CouponInputView(
        couponCode: .constant(""),
        onValidate: { code in
            // Mock validation
            return PromotionValidationResult(
                isValid: true,
                discountAmount: 25.0,
                message: "Coupon applied successfully!"
            )
        },
        onApply: { code in
            print("Applying coupon: \(code)")
        }
    )
}