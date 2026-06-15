package com.liive.ride

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.math.round

class RideViewModel : ViewModel() {
    private val mutableState = MutableStateFlow(RideUiState())
    val state: StateFlow<RideUiState> = mutableState.asStateFlow()

    private var matchingJob: Job? = null
    private var rideJob: Job? = null

    fun onEvent(event: RideEvent) {
        when (event) {
            is RideEvent.SelectDestination -> mutableState.update {
                it.copy(
                    destination = event.destination,
                    phase = RidePhase.Options,
                    config = it.config.copy(destinationName = event.destination.title)
                )
            }
            RideEvent.BackToDestination -> mutableState.update { it.copy(phase = RidePhase.Destination) }
            is RideEvent.SelectTier -> mutableState.update { it.copy(config = it.config.copy(tier = event.tier)) }
            is RideEvent.SetPassengers -> mutableState.update { it.copy(config = it.config.copy(passengers = event.count.coerceIn(1, 4))) }
            is RideEvent.SetBags -> mutableState.update { it.copy(config = it.config.copy(bags = event.count.coerceIn(0, 4))) }
            is RideEvent.SetFemaleOnly -> mutableState.update { it.copy(config = it.config.copy(femaleOnly = event.enabled)) }
            is RideEvent.SetChildSeat -> mutableState.update { it.copy(config = it.config.copy(childSeat = event.enabled)) }
            RideEvent.ConfirmPickup -> startMatching()
            RideEvent.CancelMatching -> {
                cancelActiveJobs()
                mutableState.update { it.copy(phase = RidePhase.Options) }
            }
            RideEvent.CancelRide, RideEvent.Reset -> reset()
            RideEvent.MatchingComplete -> startEnroute()
            is RideEvent.SetCarProgress -> mutableState.update { it.copy(carProgress = event.progress.coerceIn(0f, 1f)) }
            RideEvent.FinishRide -> {
                cancelActiveJobs()
                mutableState.update { it.copy(phase = RidePhase.Complete, carProgress = 1f) }
            }
            RideEvent.ToggleMic -> mutableState.update { it.copy(micEnabled = !it.micEnabled) }
            is RideEvent.PresentSOS -> mutableState.update { it.copy(sosPresented = event.presented) }
            RideEvent.Pay -> mutableState.update { it.copy(paid = true) }
            is RideEvent.Rate -> mutableState.update { it.copy(rating = event.rating.coerceIn(0, 5)) }
        }
    }

    private fun startMatching() {
        cancelActiveJobs()
        mutableState.update { it.copy(phase = RidePhase.Matching, paid = false, rating = 0, carProgress = 0f) }
        matchingJob = viewModelScope.launch {
            delay(2_600)
            onEvent(RideEvent.MatchingComplete)
        }
    }

    private fun startEnroute() {
        matchingJob?.cancel()
        mutableState.update { it.copy(phase = RidePhase.Enroute, carProgress = 0f) }
        rideJob = viewModelScope.launch {
            val durationMs = 11_000f
            var elapsed = 0f
            while (elapsed < durationMs) {
                delay(80)
                elapsed += 80f
                onEvent(RideEvent.SetCarProgress(round((elapsed / durationMs) * 1000f) / 1000f))
            }
            onEvent(RideEvent.FinishRide)
        }
    }

    private fun reset() {
        cancelActiveJobs()
        mutableState.value = RideUiState()
    }

    private fun cancelActiveJobs() {
        matchingJob?.cancel()
        rideJob?.cancel()
        matchingJob = null
        rideJob = null
    }
}
