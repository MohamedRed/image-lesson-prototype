import Foundation

public struct RideSession: Codable, Equatable, Identifiable {
    public let id: String
    public let voiceRoomName: String
    public let driverName: String
    public let driverRating: Double
    public let vehicle: String
    public let plate: String
    public let tripSummary: RideTripSummary

    public init(
        id: String,
        voiceRoomName: String,
        driverName: String,
        driverRating: Double,
        vehicle: String,
        plate: String,
        tripSummary: RideTripSummary
    ) {
        self.id = id
        self.voiceRoomName = voiceRoomName
        self.driverName = driverName
        self.driverRating = driverRating
        self.vehicle = vehicle
        self.plate = plate
        self.tripSummary = tripSummary
    }

    public var driver: RideDriver {
        RideDriver(name: driverName, rating: driverRating, vehicle: vehicle, plate: plate)
    }
}

public struct RidePaymentReceipt: Codable, Equatable, Identifiable {
    public let id: String
    public let amount: Double
    public let destinationName: String

    public init(id: String, amount: Double, destinationName: String) {
        self.id = id
        self.amount = amount
        self.destinationName = destinationName
    }
}

public protocol RideSharingServicing {
    func requestRide(with config: RideConfiguration) async throws -> RideSession
    func cancelRide(_ session: RideSession?)
    func setMicrophoneEnabled(_ enabled: Bool) async
    func capturePayment(amount: Double, destinationName: String) async throws -> RidePaymentReceipt
    func submitRating(_ rating: Int, session: RideSession?) async
}

public final class MockRideSharingService: RideSharingServicing {
    public init() {}

    public func requestRide(with config: RideConfiguration) async throws -> RideSession {
        let driver = RideFixtures.driver
        return RideSession(
            id: "ride_mock_001",
            voiceRoomName: "ride_mock_001",
            driverName: driver.name,
            driverRating: driver.rating,
            vehicle: driver.vehicle,
            plate: driver.plate,
            tripSummary: RideTripSummary(configuration: config)
        )
    }

    public func cancelRide(_ session: RideSession?) {}

    public func setMicrophoneEnabled(_ enabled: Bool) async {}

    public func capturePayment(amount: Double, destinationName: String) async throws -> RidePaymentReceipt {
        RidePaymentReceipt(id: "receipt_mock_001", amount: amount, destinationName: destinationName)
    }

    public func submitRating(_ rating: Int, session: RideSession?) async {}
}
