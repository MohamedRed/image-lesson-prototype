import Foundation
import FoodDeliveryService
import Combine

/// ViewModel for the dispatch dashboard
@MainActor
public class DispatchDashboardViewModel: ObservableObject {
    @Published public var dispatchMetrics = DispatchMetrics()
    @Published public var zonePerformances: [ZonePerformance] = []
    @Published public var recentDispatches: [DispatchResult] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    // Real-time activity counters
    @Published public var pendingDispatches = 0
    @Published public var activeCouriers = 0
    @Published public var ordersInTransit = 0
    
    private let algorithm: DispatchAlgorithmProtocol
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    
    public init(algorithm: DispatchAlgorithmProtocol) {
        self.algorithm = algorithm
        setupSubscriptions()
    }
    
    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func setupSubscriptions() {
        // Subscribe to zone updates
        algorithm.zoneUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] zones in
                self?.zonePerformances = zones
            }
            .store(in: &cancellables)
        
        // Subscribe to dispatch metrics
        algorithm.dispatchMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.dispatchMetrics = metrics
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    public func startRealTimeUpdates() async {
        await refreshAll()
        
        // Start periodic updates every 30 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.updateRealTimeMetrics()
            }
        }
    }
    
    public func stopRealTimeUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    public func refreshAll() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let metricsTask = algorithm.getDispatchMetrics()
            async let zonesTask = algorithm.updateZonePerformance()
            async let activityTask = updateRealTimeMetrics()
            
            let (metrics, zones) = try await (metricsTask, zonesTask)
            await activityTask
            
            self.dispatchMetrics = metrics
            self.zonePerformances = zones
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func rebalanceCouriers() async {
        do {
            try await algorithm.rebalanceCouriers()
            // Refresh zones after rebalancing
            let zones = try await algorithm.updateZonePerformance()
            self.zonePerformances = zones
        } catch {
            self.errorMessage = "Failed to rebalance couriers: \(error.localizedDescription)"
        }
    }
    
    public func getZoneDetails(_ zoneId: String) async -> ZonePerformance? {
        do {
            return try await algorithm.getZoneMetrics(zoneId: zoneId)
        } catch {
            self.errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func updateRealTimeMetrics() async {
        // Simulate real-time activity updates
        // In a real implementation, these would come from live data sources
        
        pendingDispatches = Int.random(in: 5...25)
        activeCouriers = zonePerformances.reduce(0) { $0 + $1.activeCouriers }
        ordersInTransit = Int.random(in: 30...150)
        
        // Update recent dispatches with mock data
        recentDispatches = generateMockRecentDispatches()
    }
    
    private func generateMockRecentDispatches() -> [DispatchResult] {
        return (1...10).map { index in
            DispatchResult(
                orderId: "order\(1000 + index)",
                assignedCourierId: Bool.random() ? "courier\(index)" : nil,
                confidence: Double.random(in: 0.5...1.0),
                estimatedPickupTime: Date().addingTimeInterval(TimeInterval.random(in: 300...1800)),
                estimatedDeliveryTime: Date().addingTimeInterval(TimeInterval.random(in: 1800...3600)),
                routeDistance: Double.random(in: 1.0...15.0),
                routeDuration: TimeInterval.random(in: 600...2400),
                reason: "Optimally assigned based on proximity and rating"
            )
        }
    }
    
    // MARK: - Computed Properties
    
    public var criticalZones: [ZonePerformance] {
        zonePerformances.filter { $0.demandLevel == .critical }
    }
    
    public var highDemandZones: [ZonePerformance] {
        zonePerformances.filter { $0.demandLevel == .high }
    }
    
    public var averageWaitTime: TimeInterval {
        guard !zonePerformances.isEmpty else { return 0 }
        let totalWaitTime = zonePerformances.reduce(0) { $0 + $1.averageWaitTime }
        return totalWaitTime / Double(zonePerformances.count)
    }
    
    public var totalActiveCouriers: Int {
        zonePerformances.reduce(0) { $0 + $1.activeCouriers }
    }
    
    public var totalPendingOrders: Int {
        zonePerformances.reduce(0) { $0 + $1.pendingOrders }
    }
    
    public var systemHealth: SystemHealth {
        let criticalZoneCount = criticalZones.count
        let highDemandZoneCount = highDemandZones.count
        let totalZones = zonePerformances.count
        
        if criticalZoneCount > 0 {
            return .critical
        } else if highDemandZoneCount > totalZones / 2 {
            return .warning
        } else {
            return .healthy
        }
    }
    
    public enum SystemHealth {
        case healthy, warning, critical
        
        var color: String {
            switch self {
            case .healthy: return "#4CAF50"
            case .warning: return "#FF9800"
            case .critical: return "#F44336"
            }
        }
        
        var displayName: String {
            switch self {
            case .healthy: return "Healthy"
            case .warning: return "Warning"
            case .critical: return "Critical"
            }
        }
    }
}

// MARK: - Dispatch Analytics Helper
public extension DispatchDashboardViewModel {
    
    /// Calculate efficiency score for the dispatch system
    func calculateEfficiencyScore() -> Double {
        let metrics = dispatchMetrics
        
        // Weighted efficiency calculation
        let assignmentEfficiency = min(1.0, 300.0 / metrics.averageAssignmentTime) // Target: 5 minutes
        let deliveryEfficiency = min(1.0, 1800.0 / metrics.averageDeliveryTime) // Target: 30 minutes
        let utilizationScore = metrics.courierUtilization
        let acceptanceScore = metrics.orderAcceptanceRate
        
        return (assignmentEfficiency * 0.3 +
                deliveryEfficiency * 0.3 +
                utilizationScore * 0.2 +
                acceptanceScore * 0.2)
    }
    
    /// Get performance recommendations based on current metrics
    func getPerformanceRecommendations() -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []
        
        // Check assignment time
        if dispatchMetrics.averageAssignmentTime > 300 { // 5 minutes
            recommendations.append(
                PerformanceRecommendation(
                    type: .optimization,
                    title: "Improve Assignment Speed",
                    description: "Average assignment time is \(Int(dispatchMetrics.averageAssignmentTime / 60)) minutes. Consider adding more couriers to high-demand areas.",
                    priority: .high
                )
            )
        }
        
        // Check courier utilization
        if dispatchMetrics.courierUtilization < 0.6 {
            recommendations.append(
                PerformanceRecommendation(
                    type: .rebalancing,
                    title: "Optimize Courier Distribution",
                    description: "Courier utilization is low at \(Int(dispatchMetrics.courierUtilization * 100))%. Consider rebalancing couriers across zones.",
                    priority: .medium
                )
            )
        } else if dispatchMetrics.courierUtilization > 0.9 {
            recommendations.append(
                PerformanceRecommendation(
                    type: .scaling,
                    title: "Scale Courier Fleet",
                    description: "Courier utilization is very high at \(Int(dispatchMetrics.courierUtilization * 100))%. Consider adding more couriers.",
                    priority: .high
                )
            )
        }
        
        // Check acceptance rate
        if dispatchMetrics.orderAcceptanceRate < 0.8 {
            recommendations.append(
                PerformanceRecommendation(
                    type: .incentives,
                    title: "Improve Acceptance Rate",
                    description: "Order acceptance rate is \(Int(dispatchMetrics.orderAcceptanceRate * 100))%. Consider adjusting courier incentives.",
                    priority: .medium
                )
            )
        }
        
        // Check critical zones
        if !criticalZones.isEmpty {
            recommendations.append(
                PerformanceRecommendation(
                    type: .urgent,
                    title: "Address Critical Zones",
                    description: "\(criticalZones.count) zones are in critical state. Immediate action required.",
                    priority: .critical
                )
            )
        }
        
        return recommendations
    }
    
    /// Get demand forecast for the next few hours
    func getDemandForecast() -> DemandForecast {
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        // Simple demand prediction based on typical food delivery patterns
        let hourlyMultipliers: [Int: Double] = [
            11: 1.2, // Late morning
            12: 1.8, // Lunch peak
            13: 1.6, // Lunch continues
            14: 1.0, // Afternoon dip
            15: 0.8,
            16: 0.9,
            17: 1.1,
            18: 1.4, // Dinner starts
            19: 2.0, // Dinner peak
            20: 1.7, // Evening
            21: 1.3,
            22: 0.9,
            23: 0.6
        ]
        
        let currentDemand = totalPendingOrders
        let forecastHours = (0..<6).map { hourOffset in
            let hour = (currentHour + hourOffset) % 24
            let multiplier = hourlyMultipliers[hour] ?? 0.8
            return DemandForecast.HourlyForecast(
                hour: hour,
                expectedOrders: Int(Double(currentDemand) * multiplier),
                confidenceLevel: 0.8
            )
        }
        
        return DemandForecast(hourlyForecasts: forecastHours)
    }
}

// MARK: - Supporting Models
public struct PerformanceRecommendation {
    public let type: RecommendationType
    public let title: String
    public let description: String
    public let priority: Priority
    
    public enum RecommendationType {
        case optimization, rebalancing, scaling, incentives, urgent
        
        public var icon: String {
            switch self {
            case .optimization: return "speedometer"
            case .rebalancing: return "arrow.triangle.2.circlepath"
            case .scaling: return "plus.circle"
            case .incentives: return "star"
            case .urgent: return "exclamationmark.triangle"
            }
        }
    }
    
    public enum Priority {
        case low, medium, high, critical
        
        public var color: String {
            switch self {
            case .low: return "#4CAF50"
            case .medium: return "#2196F3"
            case .high: return "#FF9800"
            case .critical: return "#F44336"
            }
        }
    }
}

public struct DemandForecast {
    public let hourlyForecasts: [HourlyForecast]
    
    public struct HourlyForecast {
        public let hour: Int
        public let expectedOrders: Int
        public let confidenceLevel: Double
        
        public var hourDisplay: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let calendar = Calendar.current
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
            return formatter.string(from: date)
        }
    }
    
    public var peakHour: HourlyForecast? {
        hourlyForecasts.max { $0.expectedOrders < $1.expectedOrders }
    }
    
    public var averageExpectedOrders: Int {
        guard !hourlyForecasts.isEmpty else { return 0 }
        let total = hourlyForecasts.reduce(0) { $0 + $1.expectedOrders }
        return total / hourlyForecasts.count
    }
}