package com.liive.ride

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import org.json.JSONObject
import javax.inject.Inject

interface RideStateStoring {
    fun read(): RideUiState
    fun write(state: RideUiState)
    fun clear()
}

class RideStateStore @Inject constructor(
    @ApplicationContext context: Context
) : RideStateStoring {
    private val preferences = context.getSharedPreferences(RidePersistence.StateStoreName, Context.MODE_PRIVATE)

    override fun read(): RideUiState {
        val raw = preferences.getString(KEY, null) ?: return RideUiState()
        return runCatching {
            val json = JSONObject(raw)
            val destination = json.optString("destinationId")
                .takeIf { it.isNotBlank() }
                ?.let { id -> RideFixtures.destinations.firstOrNull { it.id == id } }
            val config = RideConfig(
                tier = json.enumValue("tier", RideTier.Premium),
                passengers = json.optInt("passengers", 1).coerceIn(1, 4),
                bags = json.optInt("bags", 1).coerceIn(0, 4),
                femaleOnly = json.optBoolean("femaleOnly", false),
                childSeat = json.optBoolean("childSeat", false),
                destinationName = json.optString("destinationName", "Union Square")
            )
            val tripSummary = json.tripSummary(config)
            val activeSession = json.activeSession(tripSummary)
            RideUiState(
                phase = json.enumValue("phase", RidePhase.Destination),
                destination = destination,
                config = config,
                tripSummary = tripSummary,
                driver = RideDriver(
                    name = json.optString("driverName", RideFixtures.driver.name),
                    rating = json.optDouble("driverRating", RideFixtures.driver.rating),
                    vehicle = json.optString("driverVehicle", RideFixtures.driver.vehicle),
                    plate = json.optString("driverPlate", RideFixtures.driver.plate)
                ),
                activeSession = activeSession,
                paid = json.optBoolean("paid", false),
                rating = json.optInt("rating", 0).coerceIn(0, 5),
                micEnabled = json.optBoolean("micEnabled", true),
                carProgress = json.optDouble("carProgress", 0.0).toFloat().coerceIn(0f, 1f),
                sosPresented = false
            )
        }.getOrElse {
            clear()
            RideUiState()
        }
    }

    override fun write(state: RideUiState) {
        val json = JSONObject()
            .put("phase", state.phase.name)
            .put("destinationId", state.destination?.id.orEmpty())
            .put("tier", state.config.tier.name)
            .put("passengers", state.config.passengers)
            .put("bags", state.config.bags)
            .put("femaleOnly", state.config.femaleOnly)
            .put("childSeat", state.config.childSeat)
            .put("destinationName", state.config.destinationName)
            .put("driverName", state.driver.name)
            .put("driverRating", state.driver.rating)
            .put("driverVehicle", state.driver.vehicle)
            .put("driverPlate", state.driver.plate)
            .put("tripEnrouteTitle", state.tripSummary.enrouteTitle)
            .put("tripDriverEta", state.tripSummary.driverEta)
            .put("tripMapMarkerLabel", state.tripSummary.mapMarkerLabel)
            .put("tripTransferStatus", state.tripSummary.transferStatus.orEmpty())
            .put("tripCompletedDuration", state.tripSummary.completedDuration)
            .put("tripCompletedDistance", state.tripSummary.completedDistance)
            .put("activeSessionId", state.activeSession?.id.orEmpty())
            .put("activeSessionVoiceRoomName", state.activeSession?.voiceRoomName.orEmpty())
            .put("activeSessionDriverName", state.activeSession?.driverName.orEmpty())
            .put("activeSessionDriverRating", state.activeSession?.driverRating ?: 0.0)
            .put("activeSessionVehicle", state.activeSession?.vehicle.orEmpty())
            .put("activeSessionPlate", state.activeSession?.plate.orEmpty())
            .put("paid", state.paid)
            .put("rating", state.rating)
            .put("micEnabled", state.micEnabled)
            .put("carProgress", state.carProgress.toDouble())

        preferences.edit().putString(KEY, json.toString()).apply()
    }

    override fun clear() {
        preferences.edit().remove(KEY).apply()
    }

    private inline fun <reified T : Enum<T>> JSONObject.enumValue(key: String, default: T): T {
        val name = optString(key, default.name)
        return enumValues<T>().firstOrNull { it.name == name } ?: default
    }

    private fun JSONObject.tripSummary(config: RideConfig): RideTripSummary {
        val defaultTrip = config.tripSummary()
        return RideTripSummary(
            enrouteTitle = optString("tripEnrouteTitle", defaultTrip.enrouteTitle),
            driverEta = optString("tripDriverEta", defaultTrip.driverEta),
            mapMarkerLabel = optString("tripMapMarkerLabel", defaultTrip.mapMarkerLabel),
            transferStatus = optString("tripTransferStatus", defaultTrip.transferStatus.orEmpty())
                .takeIf { it.isNotBlank() },
            completedDuration = optString("tripCompletedDuration", defaultTrip.completedDuration),
            completedDistance = optString("tripCompletedDistance", defaultTrip.completedDistance),
        )
    }

    private fun JSONObject.activeSession(tripSummary: RideTripSummary): RideSession? {
        val id = optString("activeSessionId").takeIf { it.isNotBlank() } ?: return null
        return RideSession(
            id = id,
            voiceRoomName = optString("activeSessionVoiceRoomName", id),
            driverName = optString("activeSessionDriverName", RideFixtures.driver.name),
            driverRating = optDouble("activeSessionDriverRating", RideFixtures.driver.rating),
            vehicle = optString("activeSessionVehicle", RideFixtures.driver.vehicle),
            plate = optString("activeSessionPlate", RideFixtures.driver.plate),
            tripSummary = tripSummary,
        )
    }

    private companion object {
        const val KEY = RidePersistence.StateKey
    }
}
