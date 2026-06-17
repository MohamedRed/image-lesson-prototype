package com.liive.ride

internal object RideFlowTiming {
    const val MatchingDelayMs = 2_600L
    const val RideDurationMs = 11_000f
    const val ProgressTickMs = 80L
    const val ProgressPrecision = 1_000f
}

internal object RidePersistence {
    const val StateStoreName = "liive_ride_state"
    const val StateKey = "ride_ui_state"
}
