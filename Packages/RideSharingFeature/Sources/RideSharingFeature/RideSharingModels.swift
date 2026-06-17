import Foundation

public enum RidePhase: String, Codable, Equatable {
    case destination
    case options
    case matching
    case enroute
    case complete
}

enum RideSemanticColor: String, Codable {
    case accent
    case neutral
    case success
    case warning
    case danger

    var iconColor: LiiveIconCircle.Color {
        switch self {
        case .accent: return .accent
        case .neutral: return .neutral
        case .success: return .success
        case .warning: return .warning
        case .danger: return .danger
        }
    }
}

public struct RideDestination: Identifiable, Codable, Equatable {
    public let id: String
    public let systemImage: String
    public let color: String
    public let title: String
    public let subtitle: String

    var semanticColor: RideSemanticColor {
        RideSemanticColor(rawValue: color) ?? .neutral
    }

    public init(id: String, systemImage: String, color: String, title: String, subtitle: String) {
        self.id = id
        self.systemImage = systemImage
        self.color = color
        self.title = title
        self.subtitle = subtitle
    }
}

public enum RideTier: String, CaseIterable, Codable, Identifiable, Equatable {
    case pool
    case premium
    case exclusive

    public var id: String { rawValue }

    var name: String {
        switch self {
        case .pool: return "Pool"
        case .premium: return "Premium"
        case .exclusive: return "Exclusive"
        }
    }

    var systemImage: String {
        switch self {
        case .pool: return "person.2.fill"
        case .premium: return "car.fill"
        case .exclusive: return "star.fill"
        }
    }

    var detail: String {
        switch self {
        case .pool: return "Share · may transfer once"
        case .premium: return "Private · direct route"
        case .exclusive: return "Top-rated · luxury"
        }
    }

    var price: Double {
        switch self {
        case .pool: return 9.50
        case .premium: return 12.50
        case .exclusive: return 18.00
        }
    }

    var eta: String {
        switch self {
        case .pool: return "12 min"
        case .premium: return "8 min"
        case .exclusive: return "7 min"
        }
    }

    var isMultiLeg: Bool { self == .pool }
}

public struct RideConfiguration: Codable, Equatable {
    public var tier: RideTier = .premium
    public var passengers = 1
    public var bags = 1
    public var femaleOnly = false
    public var childSeat = false
    public var destinationName = "Union Square"

    public var price: Double { tier.price }
    public var eta: String { tier.eta }
    public var isMultiLeg: Bool { tier.isMultiLeg }
    public var fareBreakdown: RideFareBreakdown { RideFareBreakdown(configuration: self) }
}

public struct RideFareBreakdown: Codable, Equatable {
    public let rideFare: Double
    public let taxAndFees: Double
    public let costShareCredit: Double?
    public let total: Double

    public init(rideFare: Double, taxAndFees: Double, costShareCredit: Double?, total: Double) {
        self.rideFare = rideFare
        self.taxAndFees = taxAndFees
        self.costShareCredit = costShareCredit
        self.total = total
    }

    public init(configuration: RideConfiguration) {
        let rideFare = (configuration.price / 1.0875).roundedToCents()
        self.init(
            rideFare: rideFare,
            taxAndFees: (configuration.price - rideFare).roundedToCents(),
            costShareCredit: configuration.isMultiLeg ? 2.00 : nil,
            total: configuration.price
        )
    }
}

private extension Double {
    func roundedToCents() -> Double {
        (self * 100).rounded() / 100
    }
}

public struct RideDriver: Codable, Equatable {
    public let name: String
    public let rating: Double
    public let vehicle: String
    public let plate: String

    public init(name: String, rating: Double, vehicle: String, plate: String) {
        self.name = name
        self.rating = rating
        self.vehicle = vehicle
        self.plate = plate
    }
}

public struct RideUIState: Codable, Equatable {
    public var phase: RidePhase = .destination
    public var destination: RideDestination?
    public var config = RideConfiguration()
    public var driver = RideFixtures.driver
    public var paid = false
    public var rating = 0
    public var micEnabled = true
    public var carProgress = 0.0
    public var isSOSPresented = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case phase
        case destination
        case config
        case driver
        case paid
        case rating
        case micEnabled
        case carProgress
        case isSOSPresented
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phase = try container.decodeIfPresent(RidePhase.self, forKey: .phase) ?? .destination
        destination = try container.decodeIfPresent(RideDestination.self, forKey: .destination)
        config = try container.decodeIfPresent(RideConfiguration.self, forKey: .config) ?? RideConfiguration()
        driver = try container.decodeIfPresent(RideDriver.self, forKey: .driver) ?? RideFixtures.driver
        paid = try container.decodeIfPresent(Bool.self, forKey: .paid) ?? false
        rating = try container.decodeIfPresent(Int.self, forKey: .rating) ?? 0
        micEnabled = try container.decodeIfPresent(Bool.self, forKey: .micEnabled) ?? true
        carProgress = try container.decodeIfPresent(Double.self, forKey: .carProgress) ?? 0
        isSOSPresented = try container.decodeIfPresent(Bool.self, forKey: .isSOSPresented) ?? false
    }
}

enum RideFixtures {
    static let driver = RideDriver(
        name: "John Driver",
        rating: 4.8,
        vehicle: "Toyota Camry · Blue",
        plate: "ABC 123"
    )

    static let destinations = [
        RideDestination(id: "home", systemImage: "house.fill", color: "accent", title: "Home", subtitle: "1208 Sutter St"),
        RideDestination(id: "work", systemImage: "briefcase.fill", color: "neutral", title: "Work", subtitle: "455 Market St, Floor 12"),
        RideDestination(id: "union-square", systemImage: "clock", color: "neutral", title: "Union Square", subtitle: "Geary & Powell"),
        RideDestination(id: "sfo-terminal-2", systemImage: "airplane", color: "neutral", title: "SFO — Terminal 2", subtitle: "Airport")
    ]
}
