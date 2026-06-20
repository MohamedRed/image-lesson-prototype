import SwiftUI
import FoodDeliveryService
import Charts

/// Analytics dashboard for restaurant performance
public struct MerchantAnalyticsView: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    @State private var selectedPeriod: AnalyticsPeriod = .week
    @State private var selectedMetric: AnalyticsMetric = .revenue
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period selector
                PeriodSelector(selectedPeriod: $selectedPeriod)
                
                // Key metrics overview
                KeyMetricsSection(viewModel: viewModel, period: selectedPeriod)
                
                // Revenue chart
                RevenueChartSection(viewModel: viewModel, period: selectedPeriod)
                
                // Order trends chart
                OrderTrendsSection(viewModel: viewModel)
                
                // Popular items
                PopularItemsSection(viewModel: viewModel)
                
                // Performance insights
                PerformanceInsightsSection(viewModel: viewModel)
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshDashboard()
        }
    }
}

// MARK: - Analytics Period
enum AnalyticsPeriod: String, CaseIterable {
    case day = "Today"
    case week = "This Week"
    case month = "This Month"
    case quarter = "This Quarter"
    
    var icon: String {
        switch self {
        case .day: return "calendar"
        case .week: return "calendar.badge.clock"
        case .month: return "calendar.badge.plus"
        case .quarter: return "calendar.badge.exclamationmark"
        }
    }
}

// MARK: - Analytics Metric
enum AnalyticsMetric: String, CaseIterable {
    case revenue = "Revenue"
    case orders = "Orders"
    case avgOrder = "Avg Order"
    case rating = "Rating"
}

// MARK: - Period Selector
struct PeriodSelector: View {
    @Binding var selectedPeriod: AnalyticsPeriod
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: period.icon)
                            .font(.subheadline)
                        
                        Text(period.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(selectedPeriod == period ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedPeriod == period ? Color.blue : Color.clear)
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Key Metrics Section
struct KeyMetricsSection: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    let period: AnalyticsPeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MerchantMetricCard(
                    title: "Total Revenue",
                    value: String(format: "%.0f MAD", viewModel.todaysStats.revenue),
                    change: "+" + String(format: "%.1f%%", viewModel.todaysStats.revenueGrowth),
                    changeColor: viewModel.todaysStats.revenueGrowth > 0 ? .green : .red,
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                MerchantMetricCard(
                    title: "Total Orders",
                    value: "\(viewModel.todaysStats.totalOrders)",
                    change: "+\(viewModel.todaysStats.newOrders) new",
                    changeColor: .blue,
                    icon: "bag.fill",
                    color: .blue
                )
                
                MerchantMetricCard(
                    title: "Average Order",
                    value: String(format: "%.0f MAD", calculateAverageOrder()),
                    change: "+5.2%",
                    changeColor: .green,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                )
                
                MerchantMetricCard(
                    title: "Customer Rating",
                    value: String(format: "%.1f ★", viewModel.todaysStats.avgRating),
                    change: "\(viewModel.todaysStats.totalReviews) reviews",
                    changeColor: .secondary,
                    icon: "star.fill",
                    color: .yellow
                )
            }
        }
    }
    
    private func calculateAverageOrder() -> Double {
        guard viewModel.todaysStats.totalOrders > 0 else { return 0 }
        return viewModel.todaysStats.revenue / Double(viewModel.todaysStats.totalOrders)
    }
}

// MARK: - Metric Card
struct MerchantMetricCard: View {
    let title: String
    let value: String
    let change: String
    let changeColor: Color
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(change)
                    .font(.caption)
                    .foregroundColor(changeColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Revenue Chart Section
struct RevenueChartSection: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    let period: AnalyticsPeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Revenue Trend")
                .font(.headline)
                .fontWeight(.semibold)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(viewModel.weeklyRevenue, id: \.date) { data in
                        BarMark(
                            x: .value("Day", data.date, unit: .day),
                            y: .value("Revenue", data.revenue)
                        )
                        .foregroundStyle(Color.green.gradient)
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
            } else {
                // Fallback for iOS 15
                RevenueChartFallback(data: viewModel.weeklyRevenue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Revenue Chart Fallback
struct RevenueChartFallback: View {
    let data: [DailyRevenue]
    
    var body: some View {
        VStack {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.date) { item in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: 30, height: max(20, item.revenue / 50))
                        
                        Text(item.date, format: .dateTime.weekday(.abbreviated))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 200)
        }
    }
}

// MARK: - Order Trends Section
struct OrderTrendsSection: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Order Trends (24 Hours)")
                .font(.headline)
                .fontWeight(.semibold)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(viewModel.orderTrends, id: \.hour) { trend in
                        LineMark(
                            x: .value("Hour", trend.hour),
                            y: .value("Orders", trend.orderCount)
                        )
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Hour", trend.hour),
                            y: .value("Orders", trend.orderCount)
                        )
                        .foregroundStyle(Color.blue.opacity(0.3))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            } else {
                // Fallback for iOS 15
                OrderTrendsChartFallback(data: viewModel.orderTrends)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Order Trends Chart Fallback
struct OrderTrendsChartFallback: View {
    let data: [OrderTrend]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(data, id: \.hour) { trend in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 12, height: max(4, CGFloat(trend.orderCount) * 4))
            }
        }
        .frame(height: 150)
    }
}

// MARK: - Popular Items Section
struct PopularItemsSection: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Popular Items")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(viewModel.popularItems.prefix(5), id: \.rank) { item in
                    PopularItemRow(item: item)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Popular Item Row
struct PopularItemRow: View {
    let item: PopularItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 32, height: 32)
                
                Text("\(item.rank)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.menuItem.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(item.menuItem.category.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.orderCount) orders")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(String(format: "%.0f MAD", item.revenue))
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var rankColor: Color {
        switch item.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

// MARK: - Performance Insights Section
struct PerformanceInsightsSection: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                MerchantInsightCard(
                    icon: "arrow.up.circle.fill",
                    color: .green,
                    title: "Revenue Growth",
                    description: "Your revenue increased by " + String(format: "%.1f%%", viewModel.todaysStats.revenueGrowth) + " compared to last week.",
                    actionTitle: "View Details"
                )
                
                MerchantInsightCard(
                    icon: "clock.arrow.circlepath",
                    color: .orange,
                    title: "Prep Time Optimization",
                    description: "Consider optimizing preparation for your most popular items to reduce wait times.",
                    actionTitle: "Optimize"
                )
                
                MerchantInsightCard(
                    icon: "star.fill",
                    color: .yellow,
                    title: "Customer Satisfaction",
                    description: "Your rating of " + String(format: "%.1f", viewModel.todaysStats.avgRating) + " is above average. Keep up the great work!",
                    actionTitle: "View Reviews"
                )
                
                MerchantInsightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue,
                    title: "Peak Hours",
                    description: "Your busiest hours are 12-2 PM and 7-9 PM. Consider special promotions during slow periods.",
                    actionTitle: "Create Promotion"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Insight Card
struct MerchantInsightCard: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let actionTitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            Spacer()
            
            Button(actionTitle) {
                // Handle insight action
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    MerchantAnalyticsView(viewModel: MerchantConsoleViewModel(restaurantId: "rest1", service: MockFoodDeliveryService()))
}