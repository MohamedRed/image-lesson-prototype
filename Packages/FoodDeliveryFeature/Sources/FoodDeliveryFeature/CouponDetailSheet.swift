import SwiftUI
import FoodDeliveryService

/// Detailed view for a specific coupon
public struct CouponDetailSheet: View {
    let coupon: Coupon
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingShareSheet = false
    @State private var copiedToClipboard = false
    
    public init(coupon: Coupon) {
        self.coupon = coupon
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Coupon header with code
                    CouponDetailHeader(coupon: coupon, onCopyCode: copyCodeToClipboard)
                    
                    // Coupon status and info
                    CouponStatusInfo(coupon: coupon)
                    
                    // Usage history if available
                    if !coupon.usageHistory.isEmpty {
                        CouponUsageHistory(history: coupon.usageHistory)
                    }
                    
                    // How to use this coupon
                    HowToUseCouponSection()
                    
                    // Important notes
                    CouponImportantNotes()
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Coupon Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Copy Code", systemImage: "doc.on.clipboard") {
                            copyCodeToClipboard()
                        }
                        
                        Button("Share Coupon", systemImage: "square.and.arrow.up") {
                            showingShareSheet = true
                        }
                        
                        if coupon.status == .active {
                            Button("Use Now", systemImage: "cart.badge.plus") {
                                // Handle use coupon action
                                dismiss()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay(
                // Copy confirmation toast
                Group {
                    if copiedToClipboard {
                        CopyConfirmationToast()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                },
                alignment: .top
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [shareText])
        }
    }
    
    private func copyCodeToClipboard() {
        UIPasteboard.general.string = coupon.code
        
        withAnimation(.spring()) {
            copiedToClipboard = true
        }
        
        // Hide the toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring()) {
                copiedToClipboard = false
            }
        }
    }
    
    private var shareText: String {
        """
        🎁 I got this coupon code for Liive Food!
        
        Code: \(coupon.code)
        \(coupon.title)
        \(coupon.description)
        
        Download Liive Food app and try it!
        """
    }
}

// MARK: - Coupon Detail Header
struct CouponDetailHeader: View {
    let coupon: Coupon
    let onCopyCode: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Coupon visual design
            CouponTicketDesign(coupon: coupon)
            
            // Copy code button
            Button(action: onCopyCode) {
                HStack {
                    Image(systemName: "doc.on.clipboard")
                        .font(.headline)
                    
                    Text("Copy Code")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Coupon Ticket Design
struct CouponTicketDesign: View {
    let coupon: Coupon
    
    var body: some View {
        ZStack {
            // Ticket background with dashed edges
            TicketShape()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            coupon.status.backgroundColor,
                            coupon.status.backgroundColor.opacity(0.7)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    TicketShape()
                        .stroke(
                            coupon.status.textColor.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                )
            
            VStack(spacing: 16) {
                // Coupon icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 24))
                        .foregroundColor(coupon.status.textColor)
                }
                
                // Coupon title
                Text(coupon.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                // Coupon description
                Text(coupon.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Coupon code
                VStack(spacing: 8) {
                    Text("COUPON CODE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text(coupon.code)
                        .font(.title)
                        .fontWeight(.black)
                        .foregroundColor(.primary)
                        .tracking(2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(8)
                }
                
                // Status badge
                CouponStatusBadge(status: coupon.status)
            }
            .padding(24)
        }
        .frame(height: 280)
    }
}

// MARK: - Ticket Shape
struct TicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let notchRadius: CGFloat = 8
        let notchSpacing: CGFloat = 20
        
        // Start from top-left
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Top edge with notches
        var x: CGFloat = 0
        while x < rect.width {
            let nextX = min(x + notchSpacing, rect.width)
            path.addLine(to: CGPoint(x: nextX, y: 0))
            
            if nextX < rect.width {
                // Add small notch
                path.addArc(
                    center: CGPoint(x: nextX, y: notchRadius/2),
                    radius: notchRadius/2,
                    startAngle: .degrees(270),
                    endAngle: .degrees(90),
                    clockwise: false
                )
            }
            x = nextX
        }
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        
        // Bottom edge with notches
        x = rect.width
        while x > 0 {
            let nextX = max(x - notchSpacing, 0)
            path.addLine(to: CGPoint(x: nextX, y: rect.height))
            
            if nextX > 0 {
                // Add small notch
                path.addArc(
                    center: CGPoint(x: nextX, y: rect.height - notchRadius/2),
                    radius: notchRadius/2,
                    startAngle: .degrees(90),
                    endAngle: .degrees(270),
                    clockwise: false
                )
            }
            x = nextX
        }
        
        // Left edge
        path.addLine(to: CGPoint(x: 0, y: 0))
        
        return path
    }
}

// MARK: - Coupon Status Info
struct CouponStatusInfo: View {
    let coupon: Coupon
    
    var body: some View {
        VStack(spacing: 16) {
            // Basic information
            InfoSection(title: "Coupon Information", icon: "info.circle") {
                VStack(spacing: 12) {
                    InfoRow(
                        icon: "calendar.badge.plus",
                        title: "Created",
                        value: coupon.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown"
                    )
                    
                    if let usedAt = coupon.usedAt {
                        InfoRow(
                            icon: "calendar.badge.checkmark",
                            title: "Used",
                            value: usedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                    
                    if let expiredAt = coupon.expiredAt {
                        InfoRow(
                            icon: "calendar.badge.minus",
                            title: "Expired",
                            value: expiredAt.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                    
                    InfoRow(
                        icon: "number.circle",
                        title: "Assignment",
                        value: coupon.assignedToCustomer != nil ? "Personal" : "Public"
                    )
                }
            }
        }
    }
}

// MARK: - Coupon Usage History
struct CouponUsageHistory: View {
    let history: [Coupon.CouponUsage]
    
    var body: some View {
        InfoSection(title: "Usage History", icon: "clock.arrow.circlepath") {
            VStack(spacing: 12) {
                ForEach(history.indices, id: \.self) { index in
                    let usage = history[index]
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Order #\(usage.orderId.suffix(6))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Discount: MAD \(usage.discountApplied, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            if let usedAt = usage.usedAt {
                                Text(usedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(usedAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - How to Use Coupon Section
struct HowToUseCouponSection: View {
    var body: some View {
        InfoSection(title: "How to Use This Coupon", icon: "questionmark.circle") {
            VStack(spacing: 12) {
                UsageStep(
                    number: 1,
                    title: "Add items to cart",
                    description: "Browse restaurants and add items to your cart",
                    color: .blue
                )
                
                UsageStep(
                    number: 2,
                    title: "Go to checkout",
                    description: "Proceed to checkout when ready to order",
                    color: .orange
                )
                
                UsageStep(
                    number: 3,
                    title: "Enter coupon code",
                    description: "Tap 'Add Coupon' and enter this code",
                    color: .green
                )
                
                UsageStep(
                    number: 4,
                    title: "Enjoy your discount",
                    description: "See the discount applied to your order total",
                    color: .purple
                )
            }
        }
    }
}

// MARK: - Usage Step
struct UsageStep: View {
    let number: Int
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Step number
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Step content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Coupon Important Notes
struct CouponImportantNotes: View {
    var body: some View {
        InfoSection(title: "Important Notes", icon: "exclamationmark.triangle") {
            VStack(alignment: .leading, spacing: 8) {
                ImportantNote(
                    icon: "clock",
                    text: "Coupons may have expiration dates"
                )
                
                ImportantNote(
                    icon: "cart",
                    text: "Some coupons have minimum order requirements"
                )
                
                ImportantNote(
                    icon: "person",
                    text: "Personal coupons cannot be shared with others"
                )
                
                ImportantNote(
                    icon: "number",
                    text: "Each coupon can typically only be used once"
                )
                
                ImportantNote(
                    icon: "creditcard",
                    text: "Some coupons may not work with certain payment methods"
                )
            }
        }
    }
}

// MARK: - Important Note
struct ImportantNote: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.orange)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Info Section
struct InfoSection<Content: View>: View {
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

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Copy Confirmation Toast
struct CopyConfirmationToast: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text("Coupon code copied!")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .padding(.top, 8)
    }
}

#Preview {
    CouponDetailSheet(
        coupon: Coupon(
            id: "coupon1",
            code: "WELCOME2024",
            title: "Welcome to Liive Food!",
            description: "Get 25% off your first order with us. Valid for new customers only.",
            promotionId: "promo123",
            assignedToCustomer: "customer123",
            usageHistory: [
                Coupon.CouponUsage(
                    orderId: "order123",
                    customerId: "customer123",
                    discountApplied: 25.0,
                    usedAt: Date()
                )
            ],
            status: .used
        )
    )
}