package com.liive.ride

import android.content.Context
import org.json.JSONObject

class RideStateStore(context: Context) {
    private val preferences = context.getSharedPreferences("liive_ride_state", Context.MODE_PRIVATE)

    fun read(): RideUiState {
        val raw = preferences.getString(KEY, null) ?: return RideUiState()
        return runCatching {
            val json = JSONObject(raw)
            val destination = json.optString("destinationId")
                .takeIf { it.isNotBlank() }
                ?.let { id -> RideFixtures.destinations.firstOrNull { it.id == id } }
            RideUiState(
                phase = json.enumValue("phase", RidePhase.Destination),
                destination = destination,
                config = RideConfig(
                    tier = json.enumValue("tier", RideTier.Premium),
                    passengers = json.optInt("passengers", 1).coerceIn(1, 4),
                    bags = json.optInt("bags", 1).coerceIn(0, 4),
                    femaleOnly = json.optBoolean("femaleOnly", false),
                    childSeat = json.optBoolean("childSeat", false),
                    destinationName = json.optString("destinationName", "Union Square")
                ),
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

    fun write(state: RideUiState) {
        val json = JSONObject()
            .put("phase", state.phase.name)
            .put("destinationId", state.destination?.id.orEmpty())
            .put("tier", state.config.tier.name)
            .put("passengers", state.config.passengers)
            .put("bags", state.config.bags)
            .put("femaleOnly", state.config.femaleOnly)
            .put("childSeat", state.config.childSeat)
            .put("destinationName", state.config.destinationName)
            .put("paid", state.paid)
            .put("rating", state.rating)
            .put("micEnabled", state.micEnabled)
            .put("carProgress", state.carProgress.toDouble())

        preferences.edit().putString(KEY, json.toString()).apply()
    }

    fun clear() {
        preferences.edit().remove(KEY).apply()
    }

    private inline fun <reified T : Enum<T>> JSONObject.enumValue(key: String, default: T): T {
        val name = optString(key, default.name)
        return enumValues<T>().firstOrNull { it.name == name } ?: default
    }

    private companion object {
        const val KEY = "ride_ui_state"
    }
}
