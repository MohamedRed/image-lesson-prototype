import Testing
@testable import RideSharingService

@Test func journeyDisplayGeometryUsesBackendSelectedPickupDropoffAndTransferPoints() async throws {
    let journey: [String: AnyCodable] = [
        "legs": AnyCodable([
            [
                "driverId": "driverA",
                "pickup": ["latitude": 37.1001, "longitude": -122.1001],
                "dropoff": ["latitude": 37.1501, "longitude": -122.1501],
            ],
            [
                "driverId": "driverB",
                "pickup": ["latitude": 37.1510, "longitude": -122.1510],
                "dropoff": ["latitude": 37.2001, "longitude": -122.2001],
            ],
        ])
    ]

    let geometry = try #require(rideJourneyDisplayGeometry(from: journey))

    #expect(geometry.legCount == 2)
    #expect(geometry.routeSegments == [
        RideCoordinateSegment(
            start: RideCoordinate(latitude: 37.1001, longitude: -122.1001),
            end: RideCoordinate(latitude: 37.1501, longitude: -122.1501)
        ),
        RideCoordinateSegment(
            start: RideCoordinate(latitude: 37.1510, longitude: -122.1510),
            end: RideCoordinate(latitude: 37.2001, longitude: -122.2001)
        ),
    ])
    #expect(geometry.transferPoints == [
        RideCoordinate(latitude: 37.1501, longitude: -122.1501),
    ])
    #expect(geometry.walkingSegments == [
        RideCoordinateSegment(
            start: RideCoordinate(latitude: 37.1501, longitude: -122.1501),
            end: RideCoordinate(latitude: 37.1510, longitude: -122.1510)
        ),
    ])
}

@Test func journeyDisplayGeometryRejectsPartialLegGeometry() async throws {
    let journey: [String: AnyCodable] = [
        "legs": AnyCodable([
            [
                "driverId": "driverA",
                "pickup": ["latitude": 37.1001, "longitude": -122.1001],
                "dropoff": ["latitude": 37.1501, "longitude": -122.1501],
            ],
            [
                "driverId": "driverB",
                "pickup": ["latitude": 37.1510, "longitude": -122.1510],
            ],
        ])
    ]

    #expect(rideJourneyDisplayGeometry(from: journey) == nil)
}

@Test func journeyDisplayGeometryAcceptsPlannerUppercaseCoordinateKeys() async throws {
    let journey: [String: AnyCodable] = [
        "legs": AnyCodable([
            [
                "driverId": "driverA",
                "Pickup": ["Latitude": 37.1001, "Longitude": -122.1001],
                "Dropoff": ["Latitude": 37.2001, "Longitude": -122.2001],
            ],
        ])
    ]

    let geometry = try #require(rideJourneyDisplayGeometry(from: journey))

    #expect(geometry.legCount == 1)
    #expect(geometry.routeSegments == [
        RideCoordinateSegment(
            start: RideCoordinate(latitude: 37.1001, longitude: -122.1001),
            end: RideCoordinate(latitude: 37.2001, longitude: -122.2001)
        ),
    ])
    #expect(geometry.transferPoints == [])
    #expect(geometry.walkingSegments == [])
}
