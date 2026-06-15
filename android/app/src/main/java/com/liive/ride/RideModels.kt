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

data class RideUiState(
    val phase: RidePhase = RidePhase.Destination,
    val destination: RideDestination? = null,
    val config: RideConfig = RideConfig(),
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
