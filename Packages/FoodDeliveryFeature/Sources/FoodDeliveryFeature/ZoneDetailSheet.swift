import SwiftUI
import FoodDeliveryService

/// Detailed view for a specific delivery zone
public struct ZoneDetailSheet: View {
    let zone: ZonePerformance
    @ObservedObject var viewModel: DispatchDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCourierList = false
    @State private var showingOrderQueue = false
    
    public init(zone: ZonePerformance, viewModel: DispatchDashboardViewModel) {
        self.zone = zone
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Zone header
                    ZoneDetailHeader(zone: zone)
                    
                    // Key metrics
                    ZoneMetricsSection(zone: zone)
                    
                    // Performance indicators
                    ZonePerformanceIndicators(zone: zone)
                    
                    // Actions section
                    ZoneActionsSection(
                        zone: zone,
                        onShowCouriers: { showingCourierList = true },
                        onShowOrders: { showingOrderQueue = true },
                        onOptimize: { optimizeZone() }
                    )
                    
                    // Historical data
                    ZoneHistoricalSection(zone: zone)
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle(zone.zoneName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh Data", systemImage: "arrow.clockwise") {
                            refreshZoneData()
                        }
                        
                        Button("Export Report", systemImage: "square.and.arrow.up") {
                            // Export zone report
                        }
                        
                        Button("Set Alert", systemImage: "bell") {
                            // Set zone alert
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCourierList) {
            ZoneCourierListSheet(zoneId: zone.zoneId)
        }
        .sheet(isPresented: $showingOrderQueue) {
            ZoneOrderQueueSheet(zoneId: zone.zoneId)
        }
    }
    
    private func refreshZoneData() {
        Task {
            if let updatedZone = await viewModel.getZoneDetails(zone.zoneId) {
                // Zone data will be updated via the viewModel
            }
        }
    }
    
    private func optimizeZone() {
        Task {
            await viewModel.rebalanceCouriers()
        }
    }
}

// MARK: - Zone Detail Header
struct ZoneDetailHeader: View {
    let zone: ZonePerformance
    
    var body: some View {
        VStack(spacing: 16) {
            // Status indicator
            HStack {
                DemandLevelBadge(level: zone.demandLevel)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Updated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(zone.lastUpdated, style: .time)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Zone map placeholder
            ZoneMapView(zone: zone)
            
            // Quick stats
            HStack(spacing: 20) {
                ZoneQuickStat(
                    title: "Active",
                    value: "\(zone.activeCouriers)",
                    subtitle: "Couriers",
                    color: .blue
                )
                
                ZoneQuickStat(
                    title: "Pending",
                    value: "\(zone.pendingOrders)",
                    subtitle: "Orders",
                    color: .orange
                )
                
                ZoneQuickStat(
                    title: "Wait Time",
                    value: "\(Int(zone.averageWaitTime / 60))",
                    subtitle: "Minutes",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Zone Map View
struct ZoneMapView: View {
    let zone: ZonePerformance
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray6))
            .frame(height: 120)
            .overlay(
                VStack {
                    Image(systemName: "map")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    
                    Text("Zone Map")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Interactive map would be displayed here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            )
    }
}

// MARK: - Zone Quick Stat
struct ZoneQuickStat: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Zone Metrics Section
struct ZoneMetricsSection: View {
    let zone: ZonePerformance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ZoneMetricCard(
                    title: "Courier Density",
                    value: String(format: "%.1f", calculateCourierDensity()),
                    unit: "per km²",
                    icon: "person.3.fill",
                    color: .blue
                )
                
                ZoneMetricCard(
                    title: "Order Rate",
                    value: String(format: "%.1f", calculateOrderRate()),
                    unit: "per hour",
                    icon: "clock.arrow.circlepath",
                    color: .green
                )
                
                ZoneMetricCard(
                    title: "Efficiency",
                    value: "\(Int(calculateEfficiency() * 100))",
                    unit: "%",
                    icon: "speedometer",
                    color: .orange
                )
                
                ZoneMetricCard(
                    title: "Surge Level",
                    value: String(format: "%.1fx", zone.surgeMultiplier),
                    unit: "",
                    icon: zone.surgeMultiplier > 1.0 ? "bolt.fill" : "bolt",
                    color: zone.surgeMultiplier > 1.0 ? .yellow : .gray
                )
            }
        }
    }
    
    private func calculateCourierDensity() -> Double {
        // Mock calculation - would use actual zone area
        let estimatedAreaKm2 = 25.0
        return Double(zone.activeCouriers) / estimatedAreaKm2
    }
    
    private func calculateOrderRate() -> Double {
        // Mock calculation - orders per hour
        return Double(zone.pendingOrders) * 2.5
    }
    
    private func calculateEfficiency() -> Double {
        if zone.activeCouriers == 0 { return 0 }
        let ratio = Double(zone.pendingOrders) / Double(zone.activeCouriers)
        return max(0, min(1, 1.0 - (ratio - 1.0) / 2.0))
    }
}

// MARK: - Zone Metric Card
struct ZoneMetricCard: View {
    let title: String
    let value: String
    let unit: String
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
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Zone Performance Indicators
struct ZonePerformanceIndicators: View {
    let zone: ZonePerformance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Indicators")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                PerformanceIndicator(
                    title: "Wait Time",
                    current: zone.averageWaitTime / 60,
                    target: 5.0,
                    unit: "minutes",
                    goodIsLow: true
                )
                
                PerformanceIndicator(
                    title: "Courier Utilization",
                    current: Double(zone.pendingOrders) / max(1, Double(zone.activeCouriers)),
                    target: 1.5,
                    unit: "orders per courier",
                    goodIsLow: false
                )
                
                PerformanceIndicator(
                    title: "Response Time",
                    current: 3.2, // Mock data
                    target: 2.0,
                    unit: "minutes",
                    goodIsLow: true
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Performance Indicator
struct PerformanceIndicator: View {
    let title: String
    let current: Double
    let target: Double
    let unit: String
    let goodIsLow: Bool
    
    private var progress: Double {
        if goodIsLow {
            return max(0, min(1, (target * 2 - current) / (target * 2)))
        } else {
            return max(0, min(1, current / (target * 1.5)))
        }
    }
    
    private var status: IndicatorStatus {
        let tolerance = target * 0.2
        
        if goodIsLow {
            if current <= target {
                return .good
            } else if current <= target + tolerance {
                return .warning
            } else {
                return .poor
            }
        } else {
            if current >= target {
                return .good
            } else if current >= target - tolerance {
                return .warning
            } else {
                return .poor
            }
        }
    }
    
    enum IndicatorStatus {
        case good, warning, poor
        
        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .poor: return .red
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(String(format: "%.1f", current))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(status.color)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: status.color))
            
            HStack {
                Text("Target: \(String(format: "%.1f", target)) \(unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(status == .good ? "On Track" : status == .warning ? "Attention Needed" : "Action Required")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(status.color)
            }
        }
    }
}

// MARK: - Zone Actions Section
struct ZoneActionsSection: View {
    let zone: ZonePerformance
    let onShowCouriers: () -> Void
    let onShowOrders: () -> Void
    let onOptimize: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ActionButton(
                    title: "View Couriers",
                    subtitle: "\(zone.activeCouriers) active couriers in this zone",
                    icon: "person.3.fill",
                    color: .blue,
                    action: onShowCouriers
                )
                
                ActionButton(
                    title: "Order Queue",
                    subtitle: "\(zone.pendingOrders) orders waiting for assignment",
                    icon: "list.bullet",
                    color: .orange,
                    action: onShowOrders
                )
                
                ActionButton(
                    title: "Optimize Zone",
                    subtitle: "Rebalance couriers and optimize routes",
                    icon: "arrow.triangle.2.circlepath",
                    color: .green,
                    action: onOptimize
                )
            }
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Zone Historical Section
struct ZoneHistoricalSection: View {
    let zone: ZonePerformance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Trends")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                TrendItem(
                    title: "Peak demand was at 12:30 PM",
                    subtitle: "15 orders dispatched in 30 minutes",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue,
                    time: "2 hours ago"
                )
                
                TrendItem(
                    title: "Average wait time improved",
                    subtitle: "Down 25% from yesterday",
                    icon: "arrow.down.circle.fill",
                    color: .green,
                    time: "Today"
                )
                
                TrendItem(
                    title: "Courier shortage detected",
                    subtitle: "3 additional couriers recommended",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    time: "1 hour ago"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Trend Item
struct TrendItem: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let time: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Sheets
struct ZoneCourierListSheet: View {
    let zoneId: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Mock courier data
                ForEach(1...8, id: \.self) { index in
                    CourierRowView(
                        name: "Courier \(index)",
                        rating: Double.random(in: 4.0...5.0),
                        status: Bool.random() ? "Available" : "On Delivery",
                        distance: "\(String(format: "%.1f", Double.random(in: 0.5...3.0))) km away"
                    )
                }
            }
            .navigationTitle("Zone Couriers")
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

struct CourierRowView: View {
    let name: String
    let rating: Double
    let status: String
    let distance: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    
                    Text(String(format: "%.1f", rating))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(status)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(status == "Available" ? .green : .orange)
                
                Text(distance)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ZoneOrderQueueSheet: View {
    let zoneId: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Mock order data
                ForEach(1...12, id: \.self) { index in
                    OrderRowView(
                        orderId: "ORD\(1000 + index)",
                        restaurant: "Restaurant \(index)",
                        waitTime: "\(Int.random(in: 2...15)) min",
                        priority: index <= 3 ? "High" : "Normal"
                    )
                }
            }
            .navigationTitle("Order Queue")
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

struct OrderRowView: View {
    let orderId: String
    let restaurant: String
    let waitTime: String
    let priority: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(orderId)
                    .font(.headline)
                
                Text(restaurant)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(priority)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(priority == "High" ? .red : .blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background((priority == "High" ? Color.red : Color.blue).opacity(0.1))
                    .cornerRadius(4)
                
                Text("Waiting: \(waitTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DispatchSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Algorithm Settings") {
                    HStack {
                        Text("Assignment Timeout")
                        Spacer()
                        Text("5 minutes")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max Distance")
                        Spacer()
                        Text("15 km")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Priority Weighting")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Performance Targets") {
                    HStack {
                        Text("Target Assignment Time")
                        Spacer()
                        Text("3 minutes")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Target Delivery Time")
                        Spacer()
                        Text("30 minutes")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Notifications") {
                    Toggle("Zone Alerts", isOn: .constant(true))
                    Toggle("Performance Warnings", isOn: .constant(true))
                    Toggle("System Health", isOn: .constant(false))
                }
            }
            .navigationTitle("Dispatch Settings")
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

#Preview {
    ZoneDetailSheet(
        zone: ZonePerformance(
            zoneId: "casa_center",
            zoneName: "Casablanca Center",
            activeCouriers: 12,
            pendingOrders: 18,
            averageWaitTime: 420,
            demandLevel: .high,
            surgeMultiplier: 1.3
        ),
        viewModel: DispatchDashboardViewModel(algorithm: AdvancedDispatchAlgorithm())
    )
}