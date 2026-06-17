package com.liive.ride

internal object RidePricing {
    const val PoolFare = 9.50
    const val PremiumFare = 12.50
    const val ExclusiveFare = 18.00
    const val PoolCostShareCredit = 2.00
    const val TaxMultiplier = 1.0875
    const val CurrencyScale = 100.0
}

internal object RideTripDefaults {
    const val SingleLegEnrouteTitle = "Your driver is arriving"
    const val MultiLegEnrouteTitle = "On leg 2 of 2"
    const val SingleLegEta = "4 min"
    const val MultiLegEta = "3 min"
    const val SingleLegMarkerLabel = "4 min"
    const val MultiLegMarkerLabel = "Leg 2 · 3 min"
    const val TransferStatus = "Transfer at Hayes St complete · 150m walk"
    const val CompletedDuration = "18 min"
    const val CompletedDistance = "5.2 km"
}
