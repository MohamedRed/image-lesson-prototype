import Foundation

public struct Availability: Codable, Equatable {
    public let propertyId: String
    public let roomTypeId: String
    public let ratePlanId: String
    public let dateRange: DateRange
    public let inventoryCount: Int
    public let priceBreakdown: PriceBreakdown
    public let lastUpdated: Date
    public let isAvailable: Bool
    
    public init(
        propertyId: String,
        roomTypeId: String,
        ratePlanId: String,
        dateRange: DateRange,
        inventoryCount: Int,
        priceBreakdown: PriceBreakdown,
        lastUpdated: Date,
        isAvailable: Bool
    ) {
        self.propertyId = propertyId
        self.roomTypeId = roomTypeId
        self.ratePlanId = ratePlanId
        self.dateRange = dateRange
        self.inventoryCount = inventoryCount
        self.priceBreakdown = priceBreakdown
        self.lastUpdated = lastUpdated
        self.isAvailable = isAvailable
    }
}

public struct DateRange: Codable, Equatable {
    public let startDate: Date
    public let endDate: Date
    
    public init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
    
    public var nights: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}

public struct PriceBreakdown: Codable, Equatable {
    public let basePrice: Decimal
    public let taxes: [Tax]
    public let fees: [Fee]
    public let currency: String
    public let totalPrice: Decimal
    
    public init(
        basePrice: Decimal,
        taxes: [Tax] = [],
        fees: [Fee] = [],
        currency: String
    ) {
        self.basePrice = basePrice
        self.taxes = taxes
        self.fees = fees
        self.currency = currency
        self.totalPrice = basePrice + taxes.reduce(Decimal.zero) { $0 + $1.amount } + fees.reduce(Decimal.zero) { $0 + $1.amount }
    }
}

public struct Tax: Codable, Equatable {
    public let type: TaxType
    public let name: String
    public let amount: Decimal
    public let percentage: Double?
    
    public init(
        type: TaxType,
        name: String,
        amount: Decimal,
        percentage: Double? = nil
    ) {
        self.type = type
        self.name = name
        self.amount = amount
        self.percentage = percentage
    }
}

public enum TaxType: String, Codable {
    case vat = "VAT"
    case salesTax = "SALES_TAX"
    case cityTax = "CITY_TAX"
    case touristTax = "TOURIST_TAX"
    case occupancyTax = "OCCUPANCY_TAX"
    case other = "OTHER"
}

public struct Fee: Codable, Equatable {
    public let type: FeeType
    public let name: String
    public let amount: Decimal
    public let mandatory: Bool
    
    public init(
        type: FeeType,
        name: String,
        amount: Decimal,
        mandatory: Bool = true
    ) {
        self.type = type
        self.name = name
        self.amount = amount
        self.mandatory = mandatory
    }
}

public enum FeeType: String, Codable {
    case serviceFee = "SERVICE_FEE"
    case resortFee = "RESORT_FEE"
    case cleaningFee = "CLEANING_FEE"
    case bookingFee = "BOOKING_FEE"
    case processingFee = "PROCESSING_FEE"
    case other = "OTHER"
}