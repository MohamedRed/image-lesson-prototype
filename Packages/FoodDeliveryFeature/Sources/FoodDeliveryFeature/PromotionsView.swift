import SwiftUI
import FoodDeliveryService

/// View for displaying available promotions and coupons
public struct PromotionsView: View {
    @ObservedObject var viewModel: PromotionsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var showingCouponInput = false
    @State private var couponCode = ""
    
    public init(service: PromotionServiceProtocol) {
        self.viewModel = PromotionsViewModel(service: service)
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                PromotionTabSelector(selectedTab: $selectedTab)
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Active Promotions
                    PromotionsListView(
                        promotions: viewModel.activePromotions,
                        isLoading: viewModel.isLoading,
                        onRefresh: { await viewModel.loadPromotions() }
                    )
                    .tag(0)
                    
                    // My Coupons
                    CouponsListView(
                        coupons: viewModel.customerCoupons,
                        isLoading: viewModel.isLoading,
                        onRefresh: { await viewModel.loadCoupons() },
                        onUseCoupon: { coupon in
                            // Handle coupon usage
                        }
                    )
                    .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Offers & Rewards")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Enter Code", systemImage: "plus.circle") {
                        showingCouponInput = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingCouponInput) {
            CouponInputView(
                couponCode: $couponCode,
                onValidate: { code in
                    await viewModel.validateCouponCode(code)
                },
                onApply: { code in
                    // Apply coupon logic would go here
                    showingCouponInput = false
                }
            )
        }
        .task {
            await viewModel.loadPromotions()
            await viewModel.loadCoupons()
        }
    }
}

// MARK: - Promotion Tab Selector
struct PromotionTabSelector: View {
    @Binding var selectedTab: Int
    
    private let tabs = ["Promotions", "My Coupons"]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: { selectedTab = index }) {
                    VStack(spacing: 8) {
                        Text(tabs[index])
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTab == index ? .blue : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == index ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
    }
}

// MARK: - Promotions List View
struct PromotionsListView: View {
    let promotions: [Promotion]
    let isLoading: Bool
    let onRefresh: () async -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading && promotions.isEmpty {
                    PromotionSkeletonView()
                        .redacted(reason: .placeholder)
                } else if promotions.isEmpty {
                    EmptyPromotionsView()
                } else {
                    ForEach(promotions) { promotion in
                        PromotionCard(promotion: promotion)
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await onRefresh()
        }
    }
}

// MARK: - Coupons List View
struct CouponsListView: View {
    let coupons: [Coupon]
    let isLoading: Bool
    let onRefresh: () async -> Void
    let onUseCoupon: (Coupon) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading && coupons.isEmpty {
                    CouponSkeletonView()
                        .redacted(reason: .placeholder)
                } else if coupons.isEmpty {
                    EmptyCouponsView()
                } else {
                    ForEach(coupons) { coupon in
                        CouponCard(coupon: coupon, onUse: { onUseCoupon(coupon) })
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await onRefresh()
        }
    }
}

// MARK: - Promotion Card
struct PromotionCard: View {
    let promotion: Promotion
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with promotion type badge
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(promotion.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text(promotion.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    PromotionTypeBadge(type: promotion.type)
                }
                
                // Promotion details
                HStack {
                    PromotionDiscountView(discount: promotion.discount)
                    
                    Spacer()
                    
                    PromotionValidityView(validity: promotion.validity)
                }
                
                // Usage information
                if let totalLimit = promotion.usage.totalUsageLimit {
                    PromotionUsageBar(
                        current: promotion.usage.currentUsageCount,
                        total: totalLimit
                    )
                }
                
                // Conditions summary
                if hasConditions {
                    PromotionConditionsView(conditions: promotion.conditions)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetails) {
            PromotionDetailSheet(promotion: promotion)
        }
    }
    
    private var hasConditions: Bool {
        let hasCuisines = !(promotion.conditions.eligibleCuisineTypes?.isEmpty ?? true)
        return promotion.conditions.minimumOrderValue != nil ||
               hasCuisines ||
               promotion.conditions.firstOrderOnly ||
               promotion.conditions.newCustomersOnly
    }
}

// MARK: - Coupon Card
struct CouponCard: View {
    let coupon: Coupon
    let onUse: () -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Coupon icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "ticket.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            // Coupon details
            VStack(alignment: .leading, spacing: 4) {
                Text(coupon.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(coupon.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Coupon code
                HStack {
                    Text("Code: \(coupon.code)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    CouponStatusBadge(status: coupon.status)
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 8) {
                Button("Details") {
                    showingDetails = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                if coupon.status == .active {
                    Button("Use Now") {
                        onUse()
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingDetails) {
            CouponDetailSheet(coupon: coupon)
        }
    }
}

// MARK: - Supporting Views

struct PromotionTypeBadge: View {
    let type: Promotion.PromotionType
    
    var body: some View {
        Text(type.displayName)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(type.color)
            .cornerRadius(8)
    }
}

struct PromotionDiscountView: View {
    let discount: Promotion.DiscountInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Discount")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Text(discount.displayValue)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                if discount.freeDelivery {
                    Text("+ Free Delivery")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct PromotionValidityView: View {
    let validity: Promotion.PromotionValidity
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Valid Until")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(validity.endDate, style: .date)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct PromotionUsageBar: View {
    let current: Int
    let total: Int
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(Double(current) / Double(total), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Usage")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(current)/\(total) used")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: progress > 0.8 ? .orange : .blue))
        }
    }
}

struct PromotionConditionsView: View {
    let conditions: Promotion.PromotionConditions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Conditions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                if let minOrder = conditions.minimumOrderValue {
                    let minText = String(format: "%.0f", minOrder)
                    ConditionRow(
                        icon: "cart.fill",
                        text: "Min order: MAD \(minText)"
                    )
                }
                
                if conditions.firstOrderOnly {
                    ConditionRow(
                        icon: "star.fill",
                        text: "First order only"
                    )
                }
                
                if conditions.newCustomersOnly {
                    ConditionRow(
                        icon: "person.badge.plus",
                        text: "New customers only"
                    )
                }
                
                if let cuisines = conditions.eligibleCuisineTypes, !cuisines.isEmpty {
                    ConditionRow(
                        icon: "fork.knife",
                        text: "Valid for: \(cuisines.joined(separator: ", "))"
                    )
                }
            }
        }
        .padding(.top, 8)
    }
}

struct ConditionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.blue)
                .frame(width: 12)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CouponStatusBadge: View {
    let status: Coupon.CouponStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(status.textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(status.backgroundColor)
            .cornerRadius(6)
    }
}

// MARK: - Empty States

struct EmptyPromotionsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gift.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Active Promotions")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Check back later for exciting offers and discounts!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct EmptyCouponsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Coupons Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Complete orders to earn personalized coupons and rewards!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Skeleton Views

struct PromotionSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray)
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray)
                    .frame(width: 60, height: 24)
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray)
                .frame(height: 16)
                .frame(maxWidth: .infinity)
            
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray)
                    .frame(width: 80, height: 16)
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray)
                    .frame(width: 100, height: 16)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct CouponSkeletonView: View {
    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray)
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray)
                    .frame(width: 80, height: 20)
            }
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray)
                .frame(width: 60, height: 32)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Extensions

extension Promotion.PromotionType {
    var displayName: String {
        switch self {
        case .discount: return "Discount"
        case .freeDelivery: return "Free Delivery"
        case .buyOneGetOne: return "BOGO"
        case .firstOrder: return "First Order"
        case .loyaltyReward: return "Loyalty"
        case .flashSale: return "Flash Sale"
        case .referral: return "Referral"
        case .bundleDeal: return "Bundle"
        }
    }
    
    var color: Color {
        switch self {
        case .discount: return .blue
        case .freeDelivery: return .green
        case .buyOneGetOne: return .orange
        case .firstOrder: return .purple
        case .loyaltyReward: return .pink
        case .flashSale: return .red
        case .referral: return .teal
        case .bundleDeal: return .indigo
        }
    }
}

extension Promotion.DiscountInfo {
    var displayValue: String {
        switch type {
        case .percentage:
            return "\(Int(value))% OFF"
        case .fixedAmount:
            return "MAD \(Int(value)) OFF"
        case .freeItem:
            return "FREE ITEM"
        }
    }
}

extension Coupon.CouponStatus {
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .used: return "Used"
        case .expired: return "Expired"
        case .cancelled: return "Cancelled"
        }
    }
    
    var textColor: Color {
        switch self {
        case .active: return .green
        case .used: return .gray
        case .expired: return .orange
        case .cancelled: return .red
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .active: return .green.opacity(0.1)
        case .used: return .gray.opacity(0.1)
        case .expired: return .orange.opacity(0.1)
        case .cancelled: return .red.opacity(0.1)
        }
    }
}

#Preview {
    PromotionsView(service: MockPromotionService())
}