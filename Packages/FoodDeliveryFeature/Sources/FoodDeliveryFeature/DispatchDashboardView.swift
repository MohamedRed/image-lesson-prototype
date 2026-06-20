import SwiftUI
import FoodDeliveryService
import MapKit

/// Operations dashboard for monitoring and managing the dispatch system
public struct DispatchDashboardView: View {
    @ObservedObject var viewModel: DispatchDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var showingZoneDetails = false
    @State private var selectedZone: ZonePerformance?
    @State private var showingDispatchSettings = false
    
    public init(algorithm: DispatchAlgorithmProtocol) {
        self.viewModel = DispatchDashboardViewModel(algorithm: algorithm)
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                DispatchTabSelector(selectedTab: $selectedTab)
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Real-time overview
                    OverviewTab(
                        viewModel: viewModel,
                        onZoneSelected: { zone in
                            selectedZone = zone
                            showingZoneDetails = true
                        }
                    )
                    .tag(0)
                    
                    // Zone performance
                    ZonePerformanceTab(
                        zones: viewModel.zonePerformances,
                        isLoading: viewModel.isLoading,
                        onZoneSelected: { zone in
                            selectedZone = zone
                            showingZoneDetails = true
                        },
                        onRebalance: {
                            Task {
                                await viewModel.rebalanceCouriers()
                            }
                        }
                    )
                    .tag(1)
                    
                    // Analytics
                    AnalyticsTab(metrics: viewModel.dispatchMetrics)
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Dispatch Control")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh Data", systemImage: "arrow.clockwise") {
                            Task {
                                await viewModel.refreshAll()
                            }
                        }
                        
                        Button("Dispatch Settings", systemImage: "gear") {
                            showingDispatchSettings = true
                        }
                        
                        Button("Export Analytics", systemImage: "square.and.arrow.up") {
                            // Export functionality
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingZoneDetails) {
            if let zone = selectedZone {
                ZoneDetailSheet(zone: zone, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showingDispatchSettings) {
            DispatchSettingsSheet()
        }
        .task {
            await viewModel.startRealTimeUpdates()
        }
        .onDisappear {
            viewModel.stopRealTimeUpdates()
        }
    }
}

// MARK: - Dispatch Tab Selector
struct DispatchTabSelector: View {
    @Binding var selectedTab: Int
    
    private let tabs = ["Overview", "Zones", "Analytics"]
    
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

// MARK: - Overview Tab
struct OverviewTab: View {
    @ObservedObject var viewModel: DispatchDashboardViewModel
    let onZoneSelected: (ZonePerformance) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Key metrics cards
                MetricsCardsSection(metrics: viewModel.dispatchMetrics)
                
                // Real-time activity
                RealTimeActivitySection(viewModel: viewModel)
                
                // Zone heatmap
                ZoneHeatmapSection(
                    zones: viewModel.zonePerformances,
                    onZoneSelected: onZoneSelected
                )
                
                // Active dispatches
                ActiveDispatchesSection(viewModel: viewModel)
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshAll()
        }
    }
}

// MARK: - Zone Performance Tab
struct ZonePerformanceTab: View {
    let zones: [ZonePerformance]
    let isLoading: Bool
    let onZoneSelected: (ZonePerformance) -> Void
    let onRebalance: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Rebalance button
                RebalanceSection(onRebalance: onRebalance)
                
                // Zone performance cards
                ForEach(zones, id: \.zoneId) { zone in
                    ZonePerformanceCard(
                        zone: zone,
                        onTap: { onZoneSelected(zone) }
                    )
                }
                
                if zones.isEmpty && !isLoading {
                    EmptyZonesView()
                }
            }
            .padding()
        }
        .overlay(
            Group {
                if isLoading {
                    ProgressView("Loading zones...")
                }
            }
        )
    }
}

// MARK: - Analytics Tab
struct AnalyticsTab: View {
    let metrics: DispatchMetrics
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Performance charts
                PerformanceChartsSection(metrics: metrics)
                
                // Efficiency metrics
                EfficiencyMetricsSection(metrics: metrics)
                
                // Trends section
                TrendsSection(metrics: metrics)
            }
            .padding()
        }
    }
}

// MARK: - Metrics Cards Section
struct MetricsCardsSection: View {
    let metrics: DispatchMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                DispatchMetricCard(
                    title: "Avg Assignment",
                    value: formatTime(metrics.averageAssignmentTime),
                    icon: "clock.fill",
                    color: .blue,
                    trend: .stable
                )
                
                DispatchMetricCard(
                    title: "Courier Utilization",
                    value: "\(Int(metrics.courierUtilization * 100))%",
                    icon: "person.3.fill",
                    color: .green,
                    trend: .up
                )
                
                DispatchMetricCard(
                    title: "Avg Delivery",
                    value: formatTime(metrics.averageDeliveryTime),
                    icon: "shippingbox.fill",
                    color: .orange,
                    trend: .down
                )
                
                DispatchMetricCard(
                    title: "Acceptance Rate",
                    value: "\(Int(metrics.orderAcceptanceRate * 100))%",
                    icon: "checkmark.circle.fill",
                    color: .purple,
                    trend: .up
                )
            }
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

// MARK: - Metric Card
struct DispatchMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: TrendDirection
    
    enum TrendDirection {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .gray
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Real Time Activity Section
struct RealTimeActivitySection: View {
    @ObservedObject var viewModel: DispatchDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Real-time Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ActivityIndicator(
                    title: "Orders Being Dispatched",
                    count: viewModel.pendingDispatches,
                    color: .blue,
                    isAnimating: viewModel.pendingDispatches > 0
                )
                
                ActivityIndicator(
                    title: "Active Couriers",
                    count: viewModel.activeCouriers,
                    color: .green,
                    isAnimating: false
                )
                
                ActivityIndicator(
                    title: "Orders in Transit",
                    count: viewModel.ordersInTransit,
                    color: .orange,
                    isAnimating: viewModel.ordersInTransit > 0
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Activity Indicator
struct ActivityIndicator: View {
    let title: String
    let count: Int
    let color: Color
    let isAnimating: Bool
    
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .opacity(isAnimating ? 0.6 : 1.0)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(
                    isAnimating ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                    value: isAnimating
                )
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(count)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Zone Heatmap Section
struct ZoneHeatmapSection: View {
    let zones: [ZonePerformance]
    let onZoneSelected: (ZonePerformance) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zone Performance Heatmap")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(zones, id: \.zoneId) { zone in
                    ZoneHeatmapCell(
                        zone: zone,
                        onTap: { onZoneSelected(zone) }
                    )
                }
            }
        }
    }
}

// MARK: - Zone Heatmap Cell
struct ZoneHeatmapCell: View {
    let zone: ZonePerformance
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(zone.zoneName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("\(zone.activeCouriers)")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("\(zone.pendingOrders) pending")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(zone.demandLevel.backgroundColorSwiftUI)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(zone.demandLevel.borderColorSwiftUI, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Zone Performance Card
struct ZonePerformanceCard: View {
    let zone: ZonePerformance
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(zone.zoneName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Last updated: \(zone.lastUpdated, style: .time)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    DemandLevelBadge(level: zone.demandLevel)
                }
                
                // Metrics
                HStack(spacing: 20) {
                    ZoneMetric(
                        title: "Active Couriers",
                        value: "\(zone.activeCouriers)",
                        icon: "person.fill",
                        color: .blue
                    )
                    
                    ZoneMetric(
                        title: "Pending Orders",
                        value: "\(zone.pendingOrders)",
                        icon: "clock.fill",
                        color: .orange
                    )
                    
                    ZoneMetric(
                        title: "Avg Wait",
                        value: "\(Int(zone.averageWaitTime / 60))m",
                        icon: "timer",
                        color: .purple
                    )
                }
                
                // Surge indicator
                if zone.surgeMultiplier > 1.0 {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                        
                        Text("Surge Active: \(zone.surgeMultiplier, specifier: "%.1f")x")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Zone Metric
struct ZoneMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Demand Level Badge
struct DemandLevelBadge: View {
    let level: ZonePerformance.DemandLevel
    
    var body: some View {
        Text(level.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(level.backgroundColorSwiftUI)
            .cornerRadius(8)
    }
}

// MARK: - Extensions
extension ZonePerformance.DemandLevel {
    var backgroundColorSwiftUI: Color {
        switch self {
        case .low: return Color.green.opacity(0.8)
        case .normal: return Color.blue.opacity(0.8)
        case .high: return Color.orange.opacity(0.8)
        case .critical: return Color.red.opacity(0.8)
        }
    }
    
    var borderColorSwiftUI: Color {
        switch self {
        case .low: return Color.green
        case .normal: return Color.blue
        case .high: return Color.orange
        case .critical: return Color.red
        }
    }
}

// MARK: - Additional Sections (Placeholder implementations)
struct ActiveDispatchesSection: View {
    @ObservedObject var viewModel: DispatchDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Dispatches")
                .font(.headline)
                .fontWeight(.semibold)
            
            if viewModel.recentDispatches.isEmpty {
                Text("No active dispatches")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.recentDispatches.prefix(5), id: \.orderId) { dispatch in
                    DispatchRow(dispatch: dispatch)
                }
            }
        }
    }
}

struct DispatchRow: View {
    let dispatch: DispatchResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Order #\(dispatch.orderId.suffix(6))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let courierId = dispatch.assignedCourierId {
                    Text("Courier: \(courierId.prefix(8))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Unassigned")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(dispatch.confidence * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(dispatch.confidence > 0.7 ? .green : .orange)
                
                Text("\(dispatch.routeDistance, specifier: "%.1f") km")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RebalanceSection: View {
    let onRebalance: () -> Void
    
    var body: some View {
        Button(action: onRebalance) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3)
                
                Text("Rebalance Couriers")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
    }
}

struct EmptyZonesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No zones configured")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Contact your administrator to set up delivery zones")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct PerformanceChartsSection: View {
    let metrics: DispatchMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Charts")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Placeholder for charts
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
                .overlay(
                    Text("Performance charts would be displayed here")
                        .foregroundColor(.secondary)
                )
        }
    }
}

struct EfficiencyMetricsSection: View {
    let metrics: DispatchMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Efficiency Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                EfficiencyCard(
                    title: "Peak Hour Efficiency",
                    value: "\(Int(metrics.peakHourEfficiency * 100))%",
                    color: .blue
                )
                
                EfficiencyCard(
                    title: "Geographic Coverage",
                    value: "\(Int(metrics.geographicCoverage * 100))%",
                    color: .green
                )
                
                EfficiencyCard(
                    title: "Multi-order Optimization",
                    value: "\(Int(metrics.multiOrderOptimization * 100))%",
                    color: .orange
                )
                
                EfficiencyCard(
                    title: "Customer Satisfaction",
                    value: String(format: "%.1f/5", metrics.customerSatisfactionScore),
                    color: .purple
                )
            }
        }
    }
}

struct EfficiencyCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct TrendsSection: View {
    let metrics: DispatchMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trends & Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                DispatchTrendItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Delivery times improved by 12% this week",
                    color: .green
                )
                
                DispatchTrendItem(
                    icon: "person.3.fill",
                    title: "Courier utilization is optimal in most zones",
                    color: .blue
                )
                
                DispatchTrendItem(
                    icon: "exclamationmark.triangle.fill",
                    title: "High demand expected during lunch hours",
                    color: .orange
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct DispatchTrendItem: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    DispatchDashboardView(algorithm: AdvancedDispatchAlgorithm())
}