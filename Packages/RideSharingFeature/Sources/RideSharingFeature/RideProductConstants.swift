import Foundation

enum RidePricing {
    static let poolFare = 9.50
    static let premiumFare = 12.50
    static let exclusiveFare = 18.00
    static let poolCostShareCredit = 2.00
    static let taxMultiplier = 1.0875
    static let currencyScale = 100.0
}

enum RideTripDefaults {
    static let singleLegEnrouteTitle = "Your driver is arriving"
    static let multiLegEnrouteTitle = "On leg 2 of 2"
    static let singleLegETA = "4 min"
    static let multiLegETA = "3 min"
    static let singleLegMarkerLabel = "4 min"
    static let multiLegMarkerLabel = "Leg 2 · 3 min"
    static let transferStatus = "Transfer at Hayes St complete · 150m walk"
    static let completedDuration = "18 min"
    static let completedDistance = "5.2 km"
}
