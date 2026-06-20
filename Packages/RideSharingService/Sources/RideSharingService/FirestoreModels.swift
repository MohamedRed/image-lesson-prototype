import Foundation
import FirebaseFirestore
// import FirebaseFirestoreSwift

public struct Driver: Codable, Identifiable {
    public var id: String?

    public var capacitySeats: Int?
    public var currentLocation: GeoPoint?
    public var gender: String?
    public var routePolyline: String?
    public var name: String?

    enum CodingKeys: String, CodingKey {
        case id
        case capacitySeats
        case currentLocation
        case gender
        case routePolyline
        case name
    }
}

public struct RideRequest: Codable, Identifiable {
    public var id: String?

    public var origin: GeoPoint
    public var destination: GeoPoint
    public var passengerCount: Int
    public var riderGender: String?
    public var assignedDriverId: String?
    public var state: String?
    public var fareBreakdown: [String: Double]?
    public var paymentStatus: String?
    public var journey: [String: AnyCodable]?
    public var createdAt: Timestamp

    enum CodingKeys: String, CodingKey {
        case id
        case origin
        case destination
        case passengerCount
        case riderGender
        case assignedDriverId
        case state
        case fareBreakdown
        case paymentStatus
        case journey
        case createdAt
    }
}

// MARK: - AnyCodable for heterogenous JSON storage
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) { self.value = value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Double.self) { value = d }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let s = try? container.decode(String.self) { value = s }
        else if let b = try? container.decode(Bool.self) { value = b }
        else if let arr = try? container.decode([AnyCodable].self) { value = arr.map { $0.value } }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict.mapValues { $0.value } }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type") }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let d as Double: try container.encode(d)
        case let i as Int: try container.encode(i)
        case let s as String: try container.encode(s)
        case let b as Bool: try container.encode(b)
        case let arr as [Any]: try container.encode(arr.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        default: throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
} 