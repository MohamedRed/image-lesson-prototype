import Foundation

public struct RideCoordinate: Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    var asTuple: (Double, Double) { (latitude, longitude) }
}

public struct RideCoordinateSegment: Equatable {
    public let start: RideCoordinate
    public let end: RideCoordinate

    public init(start: RideCoordinate, end: RideCoordinate) {
        self.start = start
        self.end = end
    }
}

public struct RideJourneyDisplayGeometry: Equatable {
    public let legCount: Int
    public let routeSegments: [RideCoordinateSegment]
    public let transferPoints: [RideCoordinate]
    public let walkingSegments: [RideCoordinateSegment]

    public init(
        legCount: Int,
        routeSegments: [RideCoordinateSegment],
        transferPoints: [RideCoordinate],
        walkingSegments: [RideCoordinateSegment]
    ) {
        self.legCount = legCount
        self.routeSegments = routeSegments
        self.transferPoints = transferPoints
        self.walkingSegments = walkingSegments
    }
}

public func rideJourneyDisplayGeometry(from journey: [String: AnyCodable]) -> RideJourneyDisplayGeometry? {
    guard let legs = journeyArray(journey["legs"]) else { return nil }

    var routeSegments: [RideCoordinateSegment] = []
    routeSegments.reserveCapacity(legs.count)
    for leg in legs {
        guard
            let pickup = journeyPoint(in: leg, matching: ["pickup", "Pickup"]),
            let dropoff = journeyPoint(in: leg, matching: ["dropoff", "Dropoff"])
        else { return nil }
        routeSegments.append(RideCoordinateSegment(start: pickup, end: dropoff))
    }

    let transferPoints: [RideCoordinate]
    if routeSegments.count > 1 {
        transferPoints = routeSegments.dropLast().map { $0.end }
    } else {
        transferPoints = []
    }

    let walkingSegments: [RideCoordinateSegment]
    if routeSegments.count > 1 {
        walkingSegments = zip(routeSegments.dropLast(), routeSegments.dropFirst()).map { previous, next in
            RideCoordinateSegment(start: previous.end, end: next.start)
        }
    } else {
        walkingSegments = []
    }

    return RideJourneyDisplayGeometry(
        legCount: legs.count,
        routeSegments: routeSegments,
        transferPoints: transferPoints,
        walkingSegments: walkingSegments
    )
}

private func journeyPoint(in leg: [String: Any], matching keys: [String]) -> RideCoordinate? {
    for key in keys {
        guard let point = journeyDictionary(leg[key]) else { continue }
        guard
            let latitude = journeyDouble(point["latitude"]) ?? journeyDouble(point["Latitude"]),
            let longitude = journeyDouble(point["longitude"]) ?? journeyDouble(point["Longitude"])
        else { continue }
        return RideCoordinate(latitude: latitude, longitude: longitude)
    }
    return nil
}

private func journeyArray(_ value: Any?) -> [[String: Any]]? {
    switch unwrapJourneyValue(value) {
    case let legs as [[String: Any]]:
        return legs
    case let legs as [[String: AnyCodable]]:
        return legs.map { leg in leg.mapValues { unwrapJourneyValue($0) } }
    case let values as [Any]:
        let legs = values.compactMap { journeyDictionary($0) }
        return legs.count == values.count ? legs : nil
    default:
        return nil
    }
}

private func journeyDictionary(_ value: Any?) -> [String: Any]? {
    switch unwrapJourneyValue(value) {
    case let dictionary as [String: Any]:
        return dictionary
    case let dictionary as [String: AnyCodable]:
        return dictionary.mapValues { unwrapJourneyValue($0) }
    default:
        return nil
    }
}

private func journeyDouble(_ value: Any?) -> Double? {
    switch unwrapJourneyValue(value) {
    case let double as Double:
        return double
    case let int as Int:
        return Double(int)
    case let number as NSNumber:
        return number.doubleValue
    default:
        return nil
    }
}

private func unwrapJourneyValue(_ value: Any?) -> Any? {
    if let codable = value as? AnyCodable {
        return unwrapJourneyValue(codable.value)
    }
    return value
}
