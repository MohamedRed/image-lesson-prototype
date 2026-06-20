import Foundation
import CoreLocation
import Combine

/// Advanced dispatch algorithm for optimal courier assignment
public protocol DispatchAlgorithmProtocol {
    // Core dispatch operations
    func dispatchOrder(_ request: DispatchRequest) async throws -> DispatchResult
    func findOptimalCourier(for request: DispatchRequest, candidates: [CourierCandidate]) async throws -> CourierCandidate?
    func calculateRouteOptimization(for courier: CourierCandidate, newOrder: DispatchRequest) async throws -> RouteOptimization
    
    // Zone management
    func updateZonePerformance() async throws -> [ZonePerformance]
    func getZoneMetrics(zoneId: String) async throws -> ZonePerformance
    func rebalanceCouriers() async throws
    
    // Analytics and optimization
    func getDispatchMetrics() async throws -> DispatchMetrics
    func optimizeBatchDispatches(_ requests: [DispatchRequest]) async throws -> [DispatchResult]
    
    // Real-time monitoring
    var zoneUpdates: AnyPublisher<[ZonePerformance], Never> { get }
    var dispatchMetrics: AnyPublisher<DispatchMetrics, Never> { get }
}

/// Core dispatch algorithm implementation
public class AdvancedDispatchAlgorithm: DispatchAlgorithmProtocol {
    private let locationService: LocationServiceProtocol
    private let routingService: RoutingServiceProtocol
    private let predictionService: DeliveryPredictionServiceProtocol
    
    private let zoneUpdatesSubject = CurrentValueSubject<[ZonePerformance], Never>([])
    private let metricsSubject = CurrentValueSubject<DispatchMetrics, Never>(DispatchMetrics())
    
    public var zoneUpdates: AnyPublisher<[ZonePerformance], Never> {
        zoneUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var dispatchMetrics: AnyPublisher<DispatchMetrics, Never> {
        metricsSubject.eraseToAnyPublisher()
    }
    
    public init(
        locationService: LocationServiceProtocol = LocationService(),
        routingService: RoutingServiceProtocol = RoutingService(),
        predictionService: DeliveryPredictionServiceProtocol = DeliveryPredictionService()
    ) {
        self.locationService = locationService
        self.routingService = routingService
        self.predictionService = predictionService
    }
    
    // MARK: - Core Dispatch Operations
    
    public func dispatchOrder(_ request: DispatchRequest) async throws -> DispatchResult {
        // Get available couriers in the area
        let candidates = try await getAvailableCouriers(near: request.pickupLocation, radius: 5.0)
        
        guard !candidates.isEmpty else {
            return DispatchResult(
                orderId: request.orderId,
                assignedCourierId: nil,
                confidence: 0.0,
                estimatedPickupTime: Date().addingTimeInterval(3600), // 1 hour fallback
                estimatedDeliveryTime: Date().addingTimeInterval(5400), // 1.5 hours fallback
                routeDistance: 0,
                routeDuration: 0,
                reason: "No available couriers in the area"
            )
        }
        
        // Find optimal courier using multi-criteria optimization
        guard let optimalCourier = try await findOptimalCourier(for: request, candidates: candidates) else {
            let alternatives = try await generateAlternatives(for: request, from: candidates.prefix(3))
            
            return DispatchResult(
                orderId: request.orderId,
                assignedCourierId: nil,
                confidence: 0.0,
                estimatedPickupTime: Date().addingTimeInterval(1800),
                estimatedDeliveryTime: Date().addingTimeInterval(3600),
                routeDistance: 0,
                routeDuration: 0,
                reason: "No optimal courier found within constraints",
                alternatives: Array(alternatives)
            )
        }
        
        // Calculate optimal route and timing
        let route = try await routingService.calculateRoute(
            from: optimalCourier.currentLocation,
            via: request.pickupLocation,
            to: request.dropoffLocation
        )
        
        let pickupTime = Date().addingTimeInterval(route.timeToPickup + request.estimatedPreparationTime)
        let deliveryTime = pickupTime.addingTimeInterval(route.timeToDelivery)
        
        // Calculate confidence score
        let confidence = calculateConfidenceScore(
            courier: optimalCourier,
            route: route,
            request: request
        )
        
        // Generate alternatives for transparency
        let alternatives = try await generateAlternatives(for: request, from: candidates.prefix(3))
        
        return DispatchResult(
            orderId: request.orderId,
            assignedCourierId: optimalCourier.courierId,
            confidence: confidence,
            estimatedPickupTime: pickupTime,
            estimatedDeliveryTime: deliveryTime,
            routeDistance: route.totalDistance,
            routeDuration: route.totalDuration,
            reason: "Optimal match: \(formatOptimizationReason(courier: optimalCourier, route: route))",
            alternatives: Array(alternatives)
        )
    }
    
    public func findOptimalCourier(for request: DispatchRequest, candidates: [CourierCandidate]) async throws -> CourierCandidate? {
        var scoredCouriers: [(courier: CourierCandidate, score: Double)] = []
        
        for candidate in candidates {
            let score = try await calculateCourierScore(candidate: candidate, request: request)
            scoredCouriers.append((candidate, score))
        }
        
        // Sort by score (highest first) and return the best match
        scoredCouriers.sort { $0.score > $1.score }
        
        // Apply additional constraints
        let filteredCouriers = scoredCouriers.filter { tuple in
            let courier = tuple.courier
            let score = tuple.score
            return score > 0.6 && validateCourierConstraints(courier: courier, request: request)
        }
        
        return filteredCouriers.first?.courier
    }
    
    public func calculateRouteOptimization(for courier: CourierCandidate, newOrder: DispatchRequest) async throws -> RouteOptimization {
        // If courier has no current orders, simple calculation
        guard let currentOrderId = courier.currentOrderId else {
            let route = try await routingService.calculateRoute(
                from: courier.currentLocation,
                via: newOrder.pickupLocation,
                to: newOrder.dropoffLocation
            )
            
            return RouteOptimization(
                courierID: courier.courierId,
                originalRoute: [],
                optimizedRoute: [
                    RouteWaypoint(location: newOrder.pickupLocation, type: .pickup, orderId: newOrder.orderId),
                    RouteWaypoint(location: newOrder.dropoffLocation, type: .dropoff, orderId: newOrder.orderId)
                ],
                timeSaved: 0,
                distanceSaved: 0,
                efficiency: route.efficiency
            )
        }
        
        // Multi-order optimization for couriers with existing orders
        let currentOrders = try await getCurrentOrdersForCourier(courier.courierId)
        let allWaypoints = extractWaypoints(from: currentOrders + [newOrder])
        
        // Use traveling salesman optimization for waypoint ordering
        let optimizedWaypoints = try await optimizeWaypoints(
            startingFrom: courier.currentLocation,
            waypoints: allWaypoints
        )
        
        let originalRoute = try await calculateRouteDistance(
            from: courier.currentLocation,
            waypoints: allWaypoints
        )
        
        let optimizedRoute = try await calculateRouteDistance(
            from: courier.currentLocation,
            waypoints: optimizedWaypoints
        )
        
        return RouteOptimization(
            courierID: courier.courierId,
            originalRoute: allWaypoints,
            optimizedRoute: optimizedWaypoints,
            timeSaved: originalRoute.totalDuration - optimizedRoute.totalDuration,
            distanceSaved: originalRoute.totalDistance - optimizedRoute.totalDistance,
            efficiency: optimizedRoute.efficiency
        )
    }
    
    // MARK: - Zone Management
    
    public func updateZonePerformance() async throws -> [ZonePerformance] {
        let zones = try await locationService.getDeliveryZones()
        var updatedZones: [ZonePerformance] = []
        
        for zone in zones {
            let couriers = try await getActiveCouriersInZone(zone.zoneId)
            let pendingOrders = try await getPendingOrdersInZone(zone.zoneId)
            let metrics = try await calculateZoneMetrics(zone.zoneId)
            
            let performance = ZonePerformance(
                zoneId: zone.zoneId,
                zoneName: zone.zoneName,
                boundaries: zone.boundaries,
                activeCouriers: couriers.count,
                pendingOrders: pendingOrders.count,
                averageWaitTime: metrics.averageWaitTime,
                demandLevel: calculateDemandLevel(couriers: couriers.count, orders: pendingOrders.count),
                surgeMultiplier: calculateSurgeMultiplier(demandLevel: metrics.demandLevel),
                lastUpdated: Date()
            )
            
            updatedZones.append(performance)
        }
        
        zoneUpdatesSubject.send(updatedZones)
        return updatedZones
    }
    
    public func getZoneMetrics(zoneId: String) async throws -> ZonePerformance {
        let zones = try await updateZonePerformance()
        guard let zone = zones.first(where: { $0.zoneId == zoneId }) else {
            throw FoodDeliveryError.networkError("Zone not found")
        }
        return zone
    }
    
    public func rebalanceCouriers() async throws {
        let zones = try await updateZonePerformance()
        
        // Identify overloaded and underutilized zones
        let overloadedZones = zones.filter { $0.demandLevel == .high || $0.demandLevel == .critical }
        let underutilizedZones = zones.filter { $0.demandLevel == .low }
        
        for overloadedZone in overloadedZones {
            // Find nearby couriers who can be redirected
            let nearbyCouriers = try await findRebalancingCandidates(
                targetZone: overloadedZone,
                sourceZones: underutilizedZones
            )
            
            // Send rebalancing suggestions
            for courier in nearbyCouriers.prefix(3) {
                try await sendRebalancingSuggestion(
                    courierId: courier.courierId,
                    targetZone: overloadedZone,
                    incentive: calculateRebalancingIncentive(courier: courier, zone: overloadedZone)
                )
            }
        }
    }
    
    // MARK: - Analytics and Optimization
    
    public func getDispatchMetrics() async throws -> DispatchMetrics {
        let metrics = try await calculateSystemMetrics()
        metricsSubject.send(metrics)
        return metrics
    }
    
    public func optimizeBatchDispatches(_ requests: [DispatchRequest]) async throws -> [DispatchResult] {
        // Sort requests by priority and timing constraints
        let sortedRequests = requests.sorted { req1, req2 in
            if req1.priority != req2.priority {
                return req1.priority.multiplier > req2.priority.multiplier
            }
            return req1.requestedAt < req2.requestedAt
        }
        
        var results: [DispatchResult] = []
        var availableCouriers = try await getAllAvailableCouriers()
        
        // Process high-priority orders first
        for request in sortedRequests {
            if let result = try await processOptimizedDispatch(
                request: request,
                availableCouriers: &availableCouriers
            ) {
                results.append(result)
            }
        }
        
        return results
    }
    
    // MARK: - Helper Methods
    
    private func calculateCourierScore(candidate: CourierCandidate, request: DispatchRequest) async throws -> Double {
        // Multi-factor scoring algorithm
        var score: Double = 0.0
        
        // Distance factor (40% weight)
        let distance = locationService.calculateDistance(
            from: candidate.currentLocation,
            to: request.pickupLocation
        )
        let distanceScore = max(0, (5.0 - distance) / 5.0) // Normalize to 0-1, prefer closer couriers
        score += distanceScore * 0.4
        
        // Courier rating factor (25% weight)
        let ratingScore = candidate.rating / 5.0 // Normalize to 0-1
        score += ratingScore * 0.25
        
        // Acceptance rate factor (15% weight)
        score += candidate.acceptanceRate * 0.15
        
        // Vehicle suitability factor (10% weight)
        let vehicleScore = calculateVehicleSuitability(
            vehicle: candidate.vehicleType,
            orderValue: request.orderValue,
            distance: distance
        )
        score += vehicleScore * 0.1
        
        // Experience factor (5% weight)
        let experienceScore = min(1.0, Double(candidate.completedDeliveries) / 100.0)
        score += experienceScore * 0.05
        
        // Capacity factor (5% weight)
        let capacityScore = calculateCapacityScore(capacity: candidate.currentCapacity)
        score += capacityScore * 0.05
        
        // Apply priority multiplier
        score *= request.priority.multiplier
        
        // Penalize for COD if courier can't handle it
        if request.paymentMethod == .cashOnDelivery && !candidate.currentCapacity.canHandleCOD {
            score *= 0.3
        }
        
        return min(1.0, score)
    }
    
    private func calculateVehicleSuitability(vehicle: Courier.VehicleType, orderValue: Double, distance: Double) -> Double {
        switch vehicle {
        case .bike:
            // Good for short distances and smaller orders
            if distance <= 2.0 && orderValue <= 150 {
                return 1.0
            } else if distance <= 5.0 && orderValue <= 300 {
                return 0.7
            } else {
                return 0.3
            }
            
        case .motorbike:
            // Balanced option for most orders
            if distance <= 8.0 && orderValue <= 500 {
                return 1.0
            } else if distance <= 15.0 {
                return 0.8
            } else {
                return 0.4
            }
            
        case .car:
            // Best for long distances and high-value orders
            if orderValue >= 300 || distance >= 10.0 {
                return 1.0
            } else if distance >= 5.0 {
                return 0.8
            } else {
                return 0.6
            }
        }
    }
    
    private func calculateCapacityScore(capacity: CourierCandidate.CourierCapacity) -> Double {
        let itemUtilization = Double(capacity.currentItems) / Double(capacity.maxItems)
        let weightUtilization = capacity.currentWeight / capacity.maxWeight
        
        // Prefer couriers with some capacity but not completely empty
        let averageUtilization = (itemUtilization + weightUtilization) / 2.0
        
        if averageUtilization < 0.2 {
            return 0.7 // Penalize completely empty couriers (may be far from action)
        } else if averageUtilization < 0.8 {
            return 1.0 // Optimal utilization
        } else {
            return max(0.0, (1.0 - averageUtilization) * 4) // Penalize overloaded couriers
        }
    }
    
    private func validateCourierConstraints(courier: CourierCandidate, request: DispatchRequest) -> Bool {
        // Check if courier is actually online and available
        guard courier.isOnline else { return false }
        
        // Check if courier can handle COD orders
        if request.paymentMethod == .cashOnDelivery && !courier.currentCapacity.canHandleCOD {
            return false
        }
        
        // Check capacity constraints
        if courier.currentCapacity.currentItems >= courier.currentCapacity.maxItems {
            return false
        }
        
        // Check if courier was active recently
        let timeSinceLastActive = Date().timeIntervalSince(courier.lastActive)
        if timeSinceLastActive > 1800 { // 30 minutes
            return false
        }
        
        // Check working zones if specified
        if !courier.workingZones.isEmpty {
            let orderZone = locationService.getZoneForLocation(request.pickupLocation)
            if !courier.workingZones.contains(orderZone.zoneId) {
                return false
            }
        }
        
        return true
    }
    
    private func calculateConfidenceScore(courier: CourierCandidate, route: RouteInfo, request: DispatchRequest) -> Double {
        var confidence: Double = 0.8 // Base confidence
        
        // Adjust based on courier rating
        confidence += (courier.rating - 4.0) * 0.1
        
        // Adjust based on acceptance rate
        confidence += (courier.acceptanceRate - 0.8) * 0.5
        
        // Adjust based on distance
        if route.totalDistance < 3.0 {
            confidence += 0.1
        } else if route.totalDistance > 10.0 {
            confidence -= 0.2
        }
        
        // Adjust based on estimated delivery time
        let estimatedDeliveryMinutes = route.totalDuration / 60
        if estimatedDeliveryMinutes < 30 {
            confidence += 0.1
        } else if estimatedDeliveryMinutes > 60 {
            confidence -= 0.1
        }
        
        return max(0.0, min(1.0, confidence))
    }
    
    private func formatOptimizationReason(courier: CourierCandidate, route: RouteInfo) -> String {
        var reasons: [String] = []
        
        if route.totalDistance < 2.0 {
            reasons.append("very close")
        } else if route.totalDistance < 5.0 {
            reasons.append("nearby")
        }
        
        if courier.rating >= 4.5 {
            reasons.append("highly rated")
        }
        
        if courier.acceptanceRate >= 0.9 {
            reasons.append("reliable")
        }
        
        if courier.completedDeliveries >= 100 {
            reasons.append("experienced")
        }
        
        return reasons.isEmpty ? "best available option" : reasons.joined(separator: ", ")
    }
    
    // MARK: - Mock Helper Methods (would be implemented with real services)
    
    private func getAvailableCouriers(near location: Coordinates, radius: Double) async throws -> [CourierCandidate] {
        // Mock implementation - would query real database
        return [
            CourierCandidate(
                courierId: "courier1",
                currentLocation: Coordinates(latitude: location.latitude + 0.01, longitude: location.longitude + 0.01),
                vehicleType: .motorbike,
                rating: 4.7,
                completedDeliveries: 150,
                acceptanceRate: 0.92
            ),
            CourierCandidate(
                courierId: "courier2",
                currentLocation: Coordinates(latitude: location.latitude - 0.005, longitude: location.longitude + 0.015),
                vehicleType: .bike,
                rating: 4.5,
                completedDeliveries: 89,
                acceptanceRate: 0.88
            )
        ]
    }
    
    private func generateAlternatives(for request: DispatchRequest, from candidates: any Sequence<CourierCandidate>) async throws -> [DispatchResult.CourierAlternative] {
        var alternatives: [DispatchResult.CourierAlternative] = []
        
        for candidate in candidates {
            let score = try await calculateCourierScore(candidate: candidate, request: request)
            let estimatedDelivery = Date().addingTimeInterval(1800 + TimeInterval.random(in: 0...1200))
            
            alternatives.append(DispatchResult.CourierAlternative(
                courierId: candidate.courierId,
                score: score,
                estimatedDeliveryTime: estimatedDelivery,
                reason: "Alternative option with \(String(format: "%.1f", score * 100))% match"
            ))
        }
        
        return alternatives.sorted { $0.score > $1.score }
    }
    
    private func calculateDemandLevel(couriers: Int, orders: Int) -> ZonePerformance.DemandLevel {
        let ratio = couriers == 0 ? Double.infinity : Double(orders) / Double(couriers)
        
        if ratio <= 0.5 {
            return .low
        } else if ratio <= 1.5 {
            return .normal
        } else if ratio <= 3.0 {
            return .high
        } else {
            return .critical
        }
    }
    
    private func calculateSurgeMultiplier(demandLevel: ZonePerformance.DemandLevel) -> Double {
        switch demandLevel {
        case .low: return 1.0
        case .normal: return 1.0
        case .high: return 1.3
        case .critical: return 1.6
        }
    }
    
    // Additional helper methods would be implemented here...
    private func getAllAvailableCouriers() async throws -> [CourierCandidate] { return [] }
    private func getCurrentOrdersForCourier(_ courierId: String) async throws -> [DispatchRequest] { return [] }
    private func extractWaypoints(from orders: [DispatchRequest]) -> [RouteWaypoint] { return [] }
    private func optimizeWaypoints(startingFrom location: Coordinates, waypoints: [RouteWaypoint]) async throws -> [RouteWaypoint] { return waypoints }
    private func calculateRouteDistance(from location: Coordinates, waypoints: [RouteWaypoint]) async throws -> RouteInfo { return RouteInfo() }
    private func getActiveCouriersInZone(_ zoneId: String) async throws -> [CourierCandidate] { return [] }
    private func getPendingOrdersInZone(_ zoneId: String) async throws -> [DispatchRequest] { return [] }
    private func calculateZoneMetrics(_ zoneId: String) async throws -> ZoneMetrics { return ZoneMetrics() }
    private func findRebalancingCandidates(targetZone: ZonePerformance, sourceZones: [ZonePerformance]) async throws -> [CourierCandidate] { return [] }
    private func sendRebalancingSuggestion(courierId: String, targetZone: ZonePerformance, incentive: Double) async throws {}
    private func calculateRebalancingIncentive(courier: CourierCandidate, zone: ZonePerformance) -> Double { return 0.0 }
    private func calculateSystemMetrics() async throws -> DispatchMetrics { return DispatchMetrics() }
    private func processOptimizedDispatch(request: DispatchRequest, availableCouriers: inout [CourierCandidate]) async throws -> DispatchResult? { return nil }
}

// MARK: - Supporting Services and Types

public protocol LocationServiceProtocol {
    func calculateDistance(from: Coordinates, to: Coordinates) -> Double
    func getDeliveryZones() async throws -> [DeliveryZone]
    func getZoneForLocation(_ location: Coordinates) -> DeliveryZone
}

public protocol RoutingServiceProtocol {
    func calculateRoute(from: Coordinates, via: Coordinates, to: Coordinates) async throws -> RouteInfo
}

public protocol DeliveryPredictionServiceProtocol {
    func predictDeliveryTime(route: RouteInfo, conditions: DeliveryConditions) async throws -> TimeInterval
}

public struct RouteInfo {
    public var totalDistance: Double = 0
    public var totalDuration: TimeInterval = 0
    public var timeToPickup: TimeInterval = 0
    public var timeToDelivery: TimeInterval = 0
    public var efficiency: Double = 0.8
    
    public init(totalDistance: Double = 0, totalDuration: TimeInterval = 0, timeToPickup: TimeInterval = 0, timeToDelivery: TimeInterval = 0, efficiency: Double = 0.8) {
        self.totalDistance = totalDistance
        self.totalDuration = totalDuration
        self.timeToPickup = timeToPickup
        self.timeToDelivery = timeToDelivery
        self.efficiency = efficiency
    }
}

public struct RouteOptimization {
    public var courierID: String
    public var originalRoute: [RouteWaypoint]
    public var optimizedRoute: [RouteWaypoint]
    public var timeSaved: TimeInterval
    public var distanceSaved: Double
    public var efficiency: Double
    
    public init(courierID: String, originalRoute: [RouteWaypoint], optimizedRoute: [RouteWaypoint], timeSaved: TimeInterval, distanceSaved: Double, efficiency: Double) {
        self.courierID = courierID
        self.originalRoute = originalRoute
        self.optimizedRoute = optimizedRoute
        self.timeSaved = timeSaved
        self.distanceSaved = distanceSaved
        self.efficiency = efficiency
    }
}

public struct RouteWaypoint {
    public var location: Coordinates
    public var type: WaypointType
    public var orderId: String
    
    public enum WaypointType {
        case pickup, dropoff
    }
    
    public init(location: Coordinates, type: WaypointType, orderId: String) {
        self.location = location
        self.type = type
        self.orderId = orderId
    }
}

public struct DeliveryZone {
    public var zoneId: String
    public var zoneName: String
    public var boundaries: [Coordinates]
    
    public init(zoneId: String, zoneName: String, boundaries: [Coordinates]) {
        self.zoneId = zoneId
        self.zoneName = zoneName
        self.boundaries = boundaries
    }
}

public struct DeliveryConditions {
    public var weather: String?
    public var trafficLevel: TrafficLevel
    public var timeOfDay: TimeOfDay
    
    public enum TrafficLevel {
        case low, moderate, heavy
    }
    
    public enum TimeOfDay {
        case morning, afternoon, evening, night
    }
    
    public init(weather: String? = nil, trafficLevel: TrafficLevel = .moderate, timeOfDay: TimeOfDay = .afternoon) {
        self.weather = weather
        self.trafficLevel = trafficLevel
        self.timeOfDay = timeOfDay
    }
}

public struct ZoneMetrics {
    public var averageWaitTime: TimeInterval = 300
    public var demandLevel: ZonePerformance.DemandLevel = .normal
    
    public init(averageWaitTime: TimeInterval = 300, demandLevel: ZonePerformance.DemandLevel = .normal) {
        self.averageWaitTime = averageWaitTime
        self.demandLevel = demandLevel
    }
}

// MARK: - Mock Implementations
public class LocationService: LocationServiceProtocol {
    public init() {}
    
    public func calculateDistance(from: Coordinates, to: Coordinates) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location1.distance(from: location2) / 1000.0 // Convert to km
    }
    
    public func getDeliveryZones() async throws -> [DeliveryZone] {
        return [
            DeliveryZone(zoneId: "casa_center", zoneName: "Casablanca Center", boundaries: []),
            DeliveryZone(zoneId: "casa_maarif", zoneName: "Maarif", boundaries: []),
            DeliveryZone(zoneId: "casa_anfa", zoneName: "Anfa", boundaries: [])
        ]
    }
    
    public func getZoneForLocation(_ location: Coordinates) -> DeliveryZone {
        return DeliveryZone(zoneId: "casa_center", zoneName: "Casablanca Center", boundaries: [])
    }
}

public class RoutingService: RoutingServiceProtocol {
    public init() {}
    
    public func calculateRoute(from: Coordinates, via: Coordinates, to: Coordinates) async throws -> RouteInfo {
        let pickupDistance = LocationService().calculateDistance(from: from, to: via)
        let deliveryDistance = LocationService().calculateDistance(from: via, to: to)
        
        let totalDistance = pickupDistance + deliveryDistance
        let totalDuration = totalDistance * 120 // Assume 120 seconds per km average
        
        return RouteInfo(
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            timeToPickup: pickupDistance * 120,
            timeToDelivery: deliveryDistance * 120,
            efficiency: 0.85
        )
    }
}

public class DeliveryPredictionService: DeliveryPredictionServiceProtocol {
    public init() {}
    
    public func predictDeliveryTime(route: RouteInfo, conditions: DeliveryConditions) async throws -> TimeInterval {
        var adjustedTime = route.totalDuration
        
        // Adjust for traffic
        switch conditions.trafficLevel {
        case .low:
            adjustedTime *= 0.9
        case .moderate:
            adjustedTime *= 1.0
        case .heavy:
            adjustedTime *= 1.4
        }
        
        // Adjust for time of day
        switch conditions.timeOfDay {
        case .morning, .evening:
            adjustedTime *= 1.2 // Rush hours
        case .afternoon:
            adjustedTime *= 1.0
        case .night:
            adjustedTime *= 0.8
        }
        
        return adjustedTime
    }
}