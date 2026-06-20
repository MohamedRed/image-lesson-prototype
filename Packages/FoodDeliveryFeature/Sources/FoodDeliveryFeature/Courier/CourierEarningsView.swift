import SwiftUI
import FoodDeliveryService

/// View for courier earnings tracking and analytics
public struct CourierEarningsView: View {
    @ObservedObject var viewModel: CourierViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPeriod: TimePeriod = .week
    @State private var showingPayoutDetails = false
    
    enum TimePeriod: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Period selector
                    CourierEarningsPeriodSelector(selectedPeriod: $selectedPeriod)
                    
                    // Main earnings card
                    MainEarningsCard(
                        period: selectedPeriod,
                        earnings: currentEarnings,
                        deliveries: currentDeliveries,
                        hours: currentHours
                    )
                    
                    // Earnings breakdown
                    EarningsBreakdownCard(period: selectedPeriod)
                    
                    // Weekly chart (if week is selected)
                    if selectedPeriod == .week {
                        WeeklyEarningsChart(data: viewModel.weeklyEarnings)
                    }
                    
                    // Recent payouts
                    RecentPayoutsCard {
                        showingPayoutDetails = true
                    }
                    
                    // Performance metrics
                    PerformanceMetricsCard(
                        rating: viewModel.courierRating,
                        onTimeRate: 94,
                        acceptanceRate: 87
                    )
                }
                .padding()
            }
            .navigationTitle("Earnings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPayoutDetails) {
            PayoutDetailsView()
        }
    }
    
    // MARK: - Computed Properties
    private var currentEarnings: Double {
        switch selectedPeriod {
        case .day: return viewModel.todayEarnings
        case .week: return viewModel.weeklyEarnings.reduce(0, +)
        case .month: return 5420.0 // Mock data
        case .year: return 48500.0 // Mock data
        }
    }
    
    private var currentDeliveries: Int {
        switch selectedPeriod {
        case .day: return viewModel.todayDeliveries
        case .week: return 47 // Mock data
        case .month: return 203 // Mock data
        case .year: return 2100 // Mock data
        }
    }
    
    private var currentHours: Double {
        switch selectedPeriod {
        case .day: return 7.5 // Mock data
        case .week: return 42.0 // Mock data
        case .month: return 180.0 // Mock data
        case .year: return 1850.0 // Mock data
        }
    }
}

// MARK: - Period Selector
struct CourierEarningsPeriodSelector: View {
    @Binding var selectedPeriod: CourierEarningsView.TimePeriod
    
    var body: some View {
        Picker("Time Period", selection: $selectedPeriod) {
            ForEach(CourierEarningsView.TimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
}

// MARK: - Main Earnings Card
struct MainEarningsCard: View {
    let period: CourierEarningsView.TimePeriod
    let earnings: Double
    let deliveries: Int
    let hours: Double
    
    var body: some View {
        VStack(spacing: 16) {
            // Total earnings
            VStack(spacing: 4) {
                Text("Total Earnings")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("MAD " + String(format: "%.2f", earnings))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
            }
            
            // Stats row
            HStack(spacing: 24) {
                StatItem(
                    title: "Deliveries",
                    value: "\(deliveries)",
                    icon: "shippingbox.fill",
                    color: .blue
                )
                
                StatItem(
                    title: "Hours",
                    value: String(format: "%.1f", hours),
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatItem(
                    title: "Per Hour",
                    value: "MAD " + String(format: "%.0f", earnings/hours),
                    icon: "timer",
                    color: .purple
                )
            }
            
            // Growth indicator
            GrowthIndicator(period: period)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Growth Indicator
struct GrowthIndicator: View {
    let period: CourierEarningsView.TimePeriod
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundColor(.green)
            
            Text("+12% from last \(period.rawValue.lowercased())")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Earnings Breakdown Card
struct EarningsBreakdownCard: View {
    let period: CourierEarningsView.TimePeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Earnings Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                BreakdownRow(
                    title: "Delivery Fees",
                    amount: 1840.0,
                    color: .blue,
                    percentage: 68
                )
                
                BreakdownRow(
                    title: "Tips",
                    amount: 520.0,
                    color: .green,
                    percentage: 19
                )
                
                BreakdownRow(
                    title: "Bonuses",
                    amount: 280.0,
                    color: .orange,
                    percentage: 10
                )
                
                BreakdownRow(
                    title: "Surge Earnings",
                    amount: 75.0,
                    color: .purple,
                    percentage: 3
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Breakdown Row
struct BreakdownRow: View {
    let title: String
    let amount: Double
    let color: Color
    let percentage: Int
    
    var body: some View {
        HStack {
            // Color indicator
            Rectangle()
                .fill(color)
                .frame(width: 4, height: 20)
                .cornerRadius(2)
            
            // Title
            Text(title)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Percentage
            Text("\(percentage)%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
            
            // Amount
            Text("MAD " + String(format: "%.0f", amount))
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .trailing)
        }
    }
}

// MARK: - Weekly Earnings Chart
struct WeeklyEarningsChart: View {
    let data: [Double]
    
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Earnings")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(zip(days, data)), id: \.0) { day, amount in
                    VStack(spacing: 8) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(width: 32, height: max(4, CGFloat(amount / maxAmount) * 100))
                            .animation(.easeInOut(duration: 0.6), value: amount)
                        
                        // Day label
                        Text(day)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Amount
                        Text("MAD" + String(Int(amount)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var maxAmount: Double {
        data.max() ?? 1
    }
}

// MARK: - Recent Payouts Card
struct RecentPayoutsCard: View {
    let onViewDetails: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Payouts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All", action: onViewDetails)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                PayoutRow(
                    date: "Today",
                    amount: 340.0,
                    status: .pending,
                    method: "Bank Transfer"
                )
                
                PayoutRow(
                    date: "Yesterday",
                    amount: 280.0,
                    status: .completed,
                    method: "Bank Transfer"
                )
                
                PayoutRow(
                    date: "Nov 15",
                    amount: 520.0,
                    status: .completed,
                    method: "Bank Transfer"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Payout Row
struct PayoutRow: View {
    let date: String
    let amount: Double
    let status: PayoutStatus
    let method: String
    
    enum PayoutStatus {
        case pending, completed, failed
        
        var color: Color {
            switch self {
            case .pending: return .orange
            case .completed: return .green
            case .failed: return .red
            }
        }
        
        var text: String {
            switch self {
            case .pending: return "Pending"
            case .completed: return "Completed"
            case .failed: return "Failed"
            }
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(method)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("MAD " + String(format: "%.2f", amount))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(status.text)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(status.color.opacity(0.2))
                    .foregroundColor(status.color)
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Performance Metrics Card
struct PerformanceMetricsCard: View {
    let rating: Double
    let onTimeRate: Int
    let acceptanceRate: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 24) {
                MetricItem(
                    title: "Rating",
                    value: String(format: "%.1f", rating),
                    icon: "star.fill",
                    color: .yellow
                )
                
                MetricItem(
                    title: "On-Time",
                    value: "\(onTimeRate)%",
                    icon: "clock.fill",
                    color: .green
                )
                
                MetricItem(
                    title: "Acceptance",
                    value: "\(acceptanceRate)%",
                    icon: "checkmark.circle.fill",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Metric Item
struct MetricItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Payout Details View
struct PayoutDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Recent Payouts") {
                    ForEach(0..<10) { index in
                        PayoutDetailRow(
                            date: dateString(daysAgo: index),
                            amount: Double.random(in: 200...600),
                            status: index < 2 ? .pending : .completed
                        )
                    }
                }
                
                Section("Payout Settings") {
                    NavigationLink("Bank Account") {
                        Text("Bank Account Settings")
                    }
                    
                    NavigationLink("Payout Schedule") {
                        Text("Payout Schedule Settings")
                    }
                    
                    NavigationLink("Tax Information") {
                        Text("Tax Information")
                    }
                }
            }
            .navigationTitle("Payout Details")
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
    
    private func dateString(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Payout Detail Row
struct PayoutDetailRow: View {
    let date: String
    let amount: Double
    let status: PayoutRow.PayoutStatus
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Bank Transfer")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("MAD " + String(format: "%.2f", amount))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(status.text)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(status.color.opacity(0.2))
                    .foregroundColor(status.color)
                    .cornerRadius(4)
            }
        }
    }
}

#Preview {
    let mockService = MockFoodDeliveryService()
    let viewModel = CourierViewModel(service: mockService)
    
    return CourierEarningsView(viewModel: viewModel)
}