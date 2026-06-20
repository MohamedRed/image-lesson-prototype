import Foundation

public struct RoomType: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let capacity: RoomCapacity
    public let beds: [BedConfiguration]
    public let amenities: [String]
    public let images: [Photo]
    public let size: RoomSize?
    
    public init(
        id: String,
        name: String,
        capacity: RoomCapacity,
        beds: [BedConfiguration],
        amenities: [String],
        images: [Photo],
        size: RoomSize? = nil
    ) {
        self.id = id
        self.name = name
        self.capacity = capacity
        self.beds = beds
        self.amenities = amenities
        self.images = images
        self.size = size
    }
}

public struct RoomCapacity: Codable, Equatable {
    public let adults: Int
    public let children: Int
    public let infants: Int
    
    public init(adults: Int, children: Int = 0, infants: Int = 0) {
        self.adults = adults
        self.children = children
        self.infants = infants
    }
    
    public var total: Int {
        adults + children
    }
}

public struct BedConfiguration: Codable, Equatable {
    public let type: BedType
    public let count: Int
    
    public init(type: BedType, count: Int) {
        self.type = type
        self.count = count
    }
}

public enum BedType: String, Codable, CaseIterable {
    case single = "SINGLE"
    case double = "DOUBLE"
    case queen = "QUEEN"
    case king = "KING"
    case sofaBed = "SOFA_BED"
    case bunkBed = "BUNK_BED"
    
    public var displayName: String {
        switch self {
        case .single: return "Single"
        case .double: return "Double"
        case .queen: return "Queen"
        case .king: return "King"
        case .sofaBed: return "Sofa Bed"
        case .bunkBed: return "Bunk Bed"
        }
    }
}

public struct RoomSize: Codable, Equatable {
    public let value: Double
    public let unit: SizeUnit
    
    public init(value: Double, unit: SizeUnit) {
        self.value = value
        self.unit = unit
    }
    
    public var displayString: String {
        "\(Int(value)) \(unit.symbol)"
    }
}

public enum SizeUnit: String, Codable {
    case squareMeters = "SQUARE_METERS"
    case squareFeet = "SQUARE_FEET"
    
    public var symbol: String {
        switch self {
        case .squareMeters: return "m²"
        case .squareFeet: return "ft²"
        }
    }
}