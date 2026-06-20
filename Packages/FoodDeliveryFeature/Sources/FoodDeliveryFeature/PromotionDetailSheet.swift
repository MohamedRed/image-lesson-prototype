import SwiftUI
import FoodDeliveryService

/// Detailed view for a specific promotion
public struct PromotionDetailSheet: View {
    let promotion: Promotion
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingShareSheet = false
    
    public init(promotion: Promotion) {
        self.promotion = promotion
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with promotion image/icon
                    PromotionDetailHeader(promotion: promotion)
                    
                    // Main promotion info
                    PromotionMainInfo(promotion: promotion)
                    
                    // Discount details
                    PromotionDiscountDetails(discount: promotion.discount)
                    
                    // Validity information
                    PromotionValidityDetails(validity: promotion.validity)
                    
                    // Conditions and restrictions
                    if hasConditions {
                        PromotionConditionsDetails(conditions: promotion.conditions)
                    }
                    
                    // Usage information
                    if hasUsageInfo {
                        PromotionUsageDetails(usage: promotion.usage)
                    }
                    
                    // Target audience
                    if hasTargetInfo {
                        PromotionTargetDetails(targets: promotion.targets)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Promotion Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share", systemImage: "square.and.arrow.up") {
                        showingShareSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [shareText])
        }
    }
    
    private var hasConditions: Bool {
        let hasRestaurants = !(promotion.conditions.eligibleRestaurants?.isEmpty ?? true)
        let hasCuisines = !(promotion.conditions.eligibleCuisineTypes?.isEmpty ?? true)
        let hasDays = !(promotion.conditions.eligibleDays?.isEmpty ?? true)
        let hasCities = !(promotion.conditions.eligibleCities?.isEmpty ?? true)
        return promotion.conditions.minimumOrderValue != nil ||
               promotion.conditions.maximumOrderValue != nil ||
               hasRestaurants || hasCuisines ||
               promotion.conditions.firstOrderOnly ||
               promotion.conditions.newCustomersOnly ||
               hasDays || hasCities
    }
    
    private var hasUsageInfo: Bool {
        promotion.usage.totalUsageLimit != nil ||
        promotion.usage.perCustomerLimit != nil
    }
    
    private var hasTargetInfo: Bool {
        let hasSegments = !(promotion.targets.customerSegments?.isEmpty ?? true)
        let hasTiers = !(promotion.targets.loyaltyTiers?.isEmpty ?? true)
        return hasSegments || hasTiers
    }
    
    private var shareText: String {
        """
        🎉 Check out this amazing offer from Liive Food!
        
        \(promotion.title)
        \(promotion.description)
        
        Valid until: \(promotion.validity.endDate.formatted(date: .abbreviated, time: .omitted))
        
        Download Liive Food app to claim this offer!
        """
    }
}

// MARK: - Promotion Detail Header
struct PromotionDetailHeader: View {
    let promotion: Promotion
    
    var body: some View {
        VStack(spacing: 16) {
            // Promotion type badge
            PromotionTypeBadge(type: promotion.type)
            
            // Promotion image or icon
            AsyncImage(url: URL(string: promotion.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Rectangle()
                        .fill(promotion.type.color.opacity(0.2))
                    
                    Image(systemName: promotion.type.iconName)
                        .font(.system(size: 48))
                        .foregroundColor(promotion.type.color)
                }
            }
            .frame(height: 120)
            .cornerRadius(16)
            .clipped()
            
            // Title and description
            VStack(spacing: 8) {
                Text(promotion.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(promotion.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Promotion Main Info
struct PromotionMainInfo: View {
    let promotion: Promotion
    
    var body: some View {
        VStack(spacing: 16) {
            // Status indicator
            HStack {
                StatusIndicator(
                    status: promotion.status,
                    isActive: promotion.validity.isActive && promotion.validity.endDate > Date()
                )
                
                Spacer()
                
                CreatedDateView(date: promotion.createdAt)
            }
            
            // Quick stats
            HStack(spacing: 20) {
                QuickStatView(
                    icon: "calendar",
                    title: "Duration",
                    value: durationText,
                    color: .blue
                )
                
                if let totalLimit = promotion.usage.totalUsageLimit {
                    QuickStatView(
                        icon: "person.2",
                        title: "Usage",
                        value: "\(promotion.usage.currentUsageCount)/\(totalLimit)",
                        color: .orange
                    )
                }
                
                QuickStatView(
                    icon: "tag",
                    title: "Type",
                    value: promotion.type.displayName,
                    color: promotion.type.color
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var durationText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        let start = formatter.string(from: promotion.validity.startDate)
        let end = formatter.string(from: promotion.validity.endDate)
        
        return "\(start) - \(end)"
    }
}

// MARK: - Quick Stat View
struct QuickStatView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let status: Promotion.PromotionStatus
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
            
            Text(displayText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(indicatorColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(indicatorColor.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var indicatorColor: Color {
        if !isActive {
            return .gray
        }
        
        switch status {
        case .active: return .green
        case .paused: return .orange
        case .expired: return .red
        case .cancelled: return .red
        case .draft: return .blue
        }
    }
    
    private var displayText: String {
        if !isActive {
            return "Expired"
        }
        
        switch status {
        case .active: return "Active"
        case .paused: return "Paused"
        case .expired: return "Expired"
        case .cancelled: return "Cancelled"
        case .draft: return "Draft"
        }
    }
}

// MARK: - Created Date View
struct CreatedDateView: View {
    let date: Date?
    
    var body: some View {
        if let date = date {
            VStack(alignment: .trailing, spacing: 2) {
                Text("Created")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(date, style: .date)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Promotion Discount Details
struct PromotionDiscountDetails: View {
    let discount: Promotion.DiscountInfo
    
    var body: some View {
        DetailSection(title: "Discount Details", icon: "percent") {
            VStack(spacing: 12) {
                DiscountValueRow(discount: discount)
                
                if let maxDiscount = discount.maxDiscount {
                    let maxText = String(format: "%.0f", maxDiscount)
                    DetailRow(
                        icon: "exclamationmark.triangle",
                        title: "Maximum Discount",
                        value: "MAD \(maxText)",
                        color: .orange
                    )
                }
                
                if discount.freeDelivery {
                    DetailRow(
                        icon: "truck.box",
                        title: "Free Delivery",
                        value: "Included",
                        color: .blue
                    )
                }
                
                DetailRow(
                    icon: "target",
                    title: "Applied To",
                    value: discount.applyTo.displayName,
                    color: .purple
                )
            }
        }
    }
}

// MARK: - Discount Value Row
struct DiscountValueRow: View {
    let discount: Promotion.DiscountInfo
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: discount.type.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Discount Value")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(discount.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(discount.displayValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Promotion Validity Details
struct PromotionValidityDetails: View {
    let validity: Promotion.PromotionValidity
    
    var body: some View {
        DetailSection(title: "Validity Period", icon: "calendar") {
            VStack(spacing: 12) {
                DetailRow(
                    icon: "calendar.badge.plus",
                    title: "Start Date",
                    value: validity.startDate.formatted(date: .abbreviated, time: .shortened),
                    color: .green
                )
                
                DetailRow(
                    icon: "calendar.badge.minus",
                    title: "End Date",
                    value: validity.endDate.formatted(date: .abbreviated, time: .shortened),
                    color: .red
                )
                
                DetailRow(
                    icon: "globe",
                    title: "Timezone",
                    value: validity.timezone,
                    color: .blue
                )
                
                // Time remaining
                TimeRemainingView(endDate: validity.endDate)
            }
        }
    }
}

// MARK: - Time Remaining View
struct TimeRemainingView: View {
    let endDate: Date
    
    private var timeRemaining: String {
        let now = Date()
        let timeInterval = endDate.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            return "Expired"
        }
        
        let days = Int(timeInterval) / (24 * 3600)
        let hours = (Int(timeInterval) % (24 * 3600)) / 3600
        
        if days > 0 {
            return "\(days) days, \(hours) hours remaining"
        } else if hours > 0 {
            return "\(hours) hours remaining"
        } else {
            let minutes = (Int(timeInterval) % 3600) / 60
            return "\(minutes) minutes remaining"
        }
    }
    
    private var urgencyColor: Color {
        let now = Date()
        let timeInterval = endDate.timeIntervalSince(now)
        let hoursRemaining = timeInterval / 3600
        
        if hoursRemaining <= 0 {
            return .red
        } else if hoursRemaining <= 24 {
            return .orange
        } else if hoursRemaining <= 48 {
            return .yellow
        } else {
            return .green
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(urgencyColor)
            
            Text(timeRemaining)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(urgencyColor)
            
            Spacer()
        }
        .padding()
        .background(urgencyColor.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Promotion Conditions Details
struct PromotionConditionsDetails: View {
    let conditions: Promotion.PromotionConditions
    
    var body: some View {
        DetailSection(title: "Terms & Conditions", icon: "doc.text") {
            VStack(spacing: 8) {
                if let minOrder = conditions.minimumOrderValue {
                    let minText = String(format: "%.0f", minOrder)
                    DetailRow(
                        icon: "cart",
                        title: "Minimum Order",
                        value: "MAD \(minText)",
                        color: .blue
                    )
                }
                
                if let maxOrder = conditions.maximumOrderValue {
                    let maxText = String(format: "%.0f", maxOrder)
                    DetailRow(
                        icon: "cart.badge.minus",
                        title: "Maximum Order",
                        value: "MAD \(maxText)",
                        color: .orange
                    )
                }
                
                if conditions.firstOrderOnly {
                    DetailRow(
                        icon: "star",
                        title: "Eligibility",
                        value: "First order only",
                        color: .yellow
                    )
                }
                
                if conditions.newCustomersOnly {
                    DetailRow(
                        icon: "person.badge.plus",
                        title: "Customer Type",
                        value: "New customers only",
                        color: .purple
                    )
                }
                
                if let cuisines = conditions.eligibleCuisineTypes, !cuisines.isEmpty {
                    DetailRow(
                        icon: "fork.knife",
                        title: "Cuisine Types",
                        value: cuisines.joined(separator: ", "),
                        color: .brown
                    )
                }
                
                if let cities = conditions.eligibleCities, !cities.isEmpty {
                    DetailRow(
                        icon: "location",
                        title: "Available Cities",
                        value: cities.joined(separator: ", "),
                        color: .teal
                    )
                }
                
                if let days = conditions.eligibleDays, !days.isEmpty {
                    DetailRow(
                        icon: "calendar.day.timeline.left",
                        title: "Valid Days",
                        value: days.map { dayName(for: $0) }.joined(separator: ", "),
                        color: .indigo
                    )
                }
                
                if let paymentMethods = conditions.requiredPaymentMethods, !paymentMethods.isEmpty {
                    DetailRow(
                        icon: "creditcard",
                        title: "Payment Methods",
                        value: paymentMethods.map { $0.displayName }.joined(separator: ", "),
                        color: .green
                    )
                }
            }
        }
    }
    
    private func dayName(for weekday: Int) -> String {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days[weekday - 1]
    }
}

// MARK: - Promotion Usage Details
struct PromotionUsageDetails: View {
    let usage: Promotion.PromotionUsage
    
    var body: some View {
        DetailSection(title: "Usage Information", icon: "chart.bar") {
            VStack(spacing: 12) {
                if let totalLimit = usage.totalUsageLimit {
                    UsageProgressView(
                        title: "Total Usage",
                        current: usage.currentUsageCount,
                        total: totalLimit
                    )
                }
                
                if let perCustomerLimit = usage.perCustomerLimit {
                    DetailRow(
                        icon: "person",
                        title: "Per Customer Limit",
                        value: "\(perCustomerLimit) uses",
                        color: .blue
                    )
                }
                
                DetailRow(
                    icon: "number",
                    title: "Times Used",
                    value: "\(usage.currentUsageCount)",
                    color: .purple
                )
            }
        }
    }
}

// MARK: - Usage Progress View
struct UsageProgressView: View {
    let title: String
    let current: Int
    let total: Int
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(Double(current) / Double(total), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(current)/\(total)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(progress > 0.8 ? .red : .primary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: progress > 0.8 ? .red : .blue))
            
            if progress > 0.9 {
                Text("Almost fully used!")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Promotion Target Details
struct PromotionTargetDetails: View {
    let targets: Promotion.PromotionTargets
    
    var body: some View {
        DetailSection(title: "Target Audience", icon: "person.2") {
            VStack(spacing: 8) {
                if let segments = targets.customerSegments, !segments.isEmpty {
                    DetailRow(
                        icon: "person.3",
                        title: "Customer Segments",
                        value: segments.joined(separator: ", "),
                        color: .blue
                    )
                }
                
                if let tiers = targets.loyaltyTiers, !tiers.isEmpty {
                    DetailRow(
                        icon: "crown",
                        title: "Loyalty Tiers",
                        value: tiers.joined(separator: ", "),
                        color: .yellow
                    )
                }
                
                if let excluded = targets.excludedCustomers, !excluded.isEmpty {
                    DetailRow(
                        icon: "person.crop.circle.badge.minus",
                        title: "Exclusions",
                        value: "\(excluded.count) customers excluded",
                        color: .red
                    )
                }
                
                if let specific = targets.specificCustomers, !specific.isEmpty {
                    DetailRow(
                        icon: "person.crop.circle.badge.checkmark",
                        title: "Specific Users",
                        value: "\(specific.count) customers targeted",
                        color: .green
                    )
                }
            }
        }
    }
}

// MARK: - Detail Section
struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Extensions
extension Promotion.PromotionType {
    var iconName: String {
        switch self {
        case .discount: return "percent"
        case .freeDelivery: return "truck.box"
        case .buyOneGetOne: return "plus.circle"
        case .firstOrder: return "star"
        case .loyaltyReward: return "crown"
        case .flashSale: return "bolt"
        case .referral: return "person.2"
        case .bundleDeal: return "bag"
        }
    }
}

extension Promotion.DiscountInfo.DiscountType {
    var iconName: String {
        switch self {
        case .percentage: return "percent"
        case .fixedAmount: return "dollarsign.circle"
        case .freeItem: return "gift"
        }
    }
    
    var displayName: String {
        switch self {
        case .percentage: return "Percentage Discount"
        case .fixedAmount: return "Fixed Amount Discount"
        case .freeItem: return "Free Item"
        }
    }
}

extension Promotion.DiscountInfo.DiscountTarget {
    var displayName: String {
        switch self {
        case .subtotal: return "Order Subtotal"
        case .deliveryFee: return "Delivery Fee"
        case .serviceFee: return "Service Fee"
        case .total: return "Order Total"
        case .specificItems: return "Specific Items"
        }
    }
}

#Preview {
    PromotionDetailSheet(
        promotion: Promotion(
            title: "Weekend Special Offer",
            description: "Get 25% off on all orders this weekend. Valid for new and existing customers.",
            type: .discount,
            discount: Promotion.DiscountInfo(
                type: .percentage,
                value: 25,
                maxDiscount: 50,
                freeDelivery: true
            ),
            conditions: Promotion.PromotionConditions(
                minimumOrderValue: 75,
                firstOrderOnly: false,
                newCustomersOnly: false
            ),
            validity: Promotion.PromotionValidity(
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
            ),
            usage: Promotion.PromotionUsage(
                totalUsageLimit: 1000,
                perCustomerLimit: 1,
                currentUsageCount: 650
            )
        )
    )
}