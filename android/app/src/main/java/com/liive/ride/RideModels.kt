package com.liive.ride

import androidx.annotation.DrawableRes
import com.liive.ride.designsystem.IconCircleColor
import com.liive.ride.designsystem.RideIcons

enum class RidePhase { Destination, Options, Matching, Enroute, Complete }

data class RideDestination(
    val id: String,
    @param:DrawableRes val icon: Int,
    val color: IconCircleColor,
    val title: String,
    val subtitle: String,
)

enum class RideTier(
    val displayName: String,
    @param:DrawableRes val icon: Int,
    val detail: String,
    val price: Double,
    val eta: String,
    val multiLeg: Boolean,
) {
    Pool("Pool", RideIcons.Group, "Share · may transfer once", 9.50, "12 min", true),
    Premium("Premium", RideIcons.Car, "Private · direct route", 12.50, "8 min", false),
    Exclusive("Exclusive", RideIcons.Star, "Top-rated · luxury", 18.00, "7 min", false),
}

data class RideConfig(
    val tier: RideTier = RideTier.Premium,
    val passengers: Int = 1,
    val bags: Int = 1,
    val femaleOnly: Boolean = false,
    val childSeat: Boolean = false,
    val destinationName: String = "Union Square",
)

data class RideFareBreakdown(
    val rideFare: Double,
    val taxAndFees: Double,
    val costShareCredit: Double?,
    val total: Double,
)

data class RideTripSummary(
    val enrouteTitle: String,
    val driverEta: String,
    val mapMarkerLabel: String,
    val transferStatus: String?,
    val completedDuration: String,
    val completedDistance: String,
)

data class RideDriver(
    val name: String,
    val rating: Double,
    val vehicle: String,
    val plate: String,
)

data class RideUiState(
    val phase: RidePhase = RidePhase.Destination,
    val destination: RideDestination? = null,
    val config: RideConfig = RideConfig(),
    val tripSummary: RideTripSummary = RideConfig().tripSummary(),
    val driver: RideDriver = RideFixtures.driver,
    val activeSession: RideSession? = null,
    val paid: Boolean = false,
    val rating: Int = 0,
    val micEnabled: Boolean = true,
    val carProgress: Float = 0f,
    val sosPresented: Boolean = false,
)

sealed interface RideEvent {
    data class SelectDestination(val destination: RideDestination) : RideEvent
    data object BackToDestination : RideEvent
    data class SelectTier(val tier: RideTier) : RideEvent
    data class SetPassengers(val count: Int) : RideEvent
    data class SetBags(val count: Int) : RideEvent
    data class SetFemaleOnly(val enabled: Boolean) : RideEvent
    data class SetChildSeat(val enabled: Boolean) : RideEvent
    data object ConfirmPickup : RideEvent
    data object CancelMatching : RideEvent
    data object CancelRide : RideEvent
    data object MatchingComplete : RideEvent
    data class SetCarProgress(val progress: Float) : RideEvent
    data object FinishRide : RideEvent
    data object ToggleMic : RideEvent
    data class PresentSOS(val presented: Boolean) : RideEvent
    data object Pay : RideEvent
    data class Rate(val rating: Int) : RideEvent
    data object Reset : RideEvent
}

object RideFixtures {
    val driver = RideDriver(
        name = "John Driver",
        rating = 4.8,
        vehicle = "Toyota Camry · Blue",
        plate = "ABC 123",
    )

    val destinations = listOf(
        RideDestination("home", RideIcons.Home, IconCircleColor.Accent, "Home", "1208 Sutter St"),
        RideDestination("work", RideIcons.Work, IconCircleColor.Neutral, "Work", "455 Market St, Floor 12"),
        RideDestination("union-square", RideIcons.History, IconCircleColor.Neutral, "Union Square", "Geary & Powell"),
        RideDestination("sfo-terminal-2", RideIcons.Flight, IconCircleColor.Neutral, "SFO — Terminal 2", "Airport"),
    )

    val passengerIcon = RideIcons.Group
    val bagIcon = RideIcons.Bag
    val safetyIcon = RideIcons.Shield
    val childSeatIcon = RideIcons.ChildSeat
}

fun Double.ridePrice(): String = "$" + "%,.2f".format(this)

fun Double.rideCreditPrice(): String = "–$" + "%,.2f".format(kotlin.math.abs(this))

fun RideConfig.fareBreakdown(): RideFareBreakdown {
    val rideFare = (tier.price / TAX_MULTIPLIER).roundedCurrency()
    return RideFareBreakdown(
        rideFare = rideFare,
        taxAndFees = (tier.price - rideFare).roundedCurrency(),
        costShareCredit = if (tier.multiLeg) 2.00 else null,
        total = tier.price,
    )
}

fun RideConfig.tripSummary(): RideTripSummary {
    val multiLeg = tier.multiLeg
    return RideTripSummary(
        enrouteTitle = if (multiLeg) RideTripDefaults.MultiLegEnrouteTitle else RideTripDefaults.SingleLegEnrouteTitle,
        driverEta = if (multiLeg) RideTripDefaults.MultiLegEta else RideTripDefaults.SingleLegEta,
        mapMarkerLabel = if (multiLeg) RideTripDefaults.MultiLegMarkerLabel else RideTripDefaults.SingleLegMarkerLabel,
        transferStatus = if (multiLeg) RideTripDefaults.TransferStatus else null,
        completedDuration = RideTripDefaults.CompletedDuration,
        completedDistance = RideTripDefaults.CompletedDistance,
    )
}

fun RideDriver.firstName(): String = name.substringBefore(" ")

private const val TAX_MULTIPLIER = 1.0875

private fun Double.roundedCurrency(): Double = kotlin.math.round(this * 100.0) / 100.0

private object RideTripDefaults {
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
