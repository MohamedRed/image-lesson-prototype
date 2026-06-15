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
}

public struct RideUIState: Codable, Equatable {
    public var phase: RidePhase = .destination
    public var destination: RideDestination?
    public var config = RideConfiguration()
    public var paid = false
    public var rating = 0
    public var micEnabled = true
    public var carProgress = 0.0
    public var isSOSPresented = false

    public init() {}
}

enum RideFixtures {
    static let destinations = [
        RideDestination(id: "home", systemImage: "house.fill", color: "accent", title: "Home", subtitle: "1208 Sutter St"),
        RideDestination(id: "work", systemImage: "briefcase.fill", color: "neutral", title: "Work", subtitle: "455 Market St, Floor 12"),
        RideDestination(id: "union-square", systemImage: "clock", color: "neutral", title: "Union Square", subtitle: "Geary & Powell"),
        RideDestination(id: "sfo-terminal-2", systemImage: "airplane", color: "neutral", title: "SFO — Terminal 2", subtitle: "Airport")
    ]
}
