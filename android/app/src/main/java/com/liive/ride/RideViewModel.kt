package com.liive.ride

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.CreationExtras
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.math.round

class RideViewModel(
    private val stateStore: RideStateStore,
    private val service: RideService,
) : ViewModel() {
    private val mutableState = MutableStateFlow(stateStore.read())
    val state: StateFlow<RideUiState> = mutableState.asStateFlow()

    private var matchingJob: Job? = null
    private var rideJob: Job? = null
    private var activeSession: RideSession? = null

    init {
        resumeTimelineIfNeeded()
    }

    fun onEvent(event: RideEvent) {
        when (event) {
            is RideEvent.SelectDestination -> updateState {
                it.copy(
                    destination = event.destination,
                    phase = RidePhase.Options,
                    config = it.config.copy(destinationName = event.destination.title)
                )
            }
            RideEvent.BackToDestination -> updateState { it.copy(phase = RidePhase.Destination) }
            is RideEvent.SelectTier -> updateState { it.copy(config = it.config.copy(tier = event.tier)) }
            is RideEvent.SetPassengers -> updateState { it.copy(config = it.config.copy(passengers = event.count.coerceIn(1, 4))) }
            is RideEvent.SetBags -> updateState { it.copy(config = it.config.copy(bags = event.count.coerceIn(0, 4))) }
            is RideEvent.SetFemaleOnly -> updateState { it.copy(config = it.config.copy(femaleOnly = event.enabled)) }
            is RideEvent.SetChildSeat -> updateState { it.copy(config = it.config.copy(childSeat = event.enabled)) }
            RideEvent.ConfirmPickup -> startMatching()
            RideEvent.CancelMatching -> {
                cancelActiveRide()
                updateState { it.copy(phase = RidePhase.Options) }
            }
            RideEvent.CancelRide -> cancelRideAndReset()
            RideEvent.Reset -> reset()
            RideEvent.MatchingComplete -> startEnroute()
            is RideEvent.SetCarProgress -> updateState { it.copy(carProgress = event.progress.coerceIn(0f, 1f)) }
            RideEvent.FinishRide -> {
                cancelTimeline()
                updateState { it.copy(phase = RidePhase.Complete, carProgress = 1f) }
            }
            RideEvent.ToggleMic -> {
                updateState { it.copy(micEnabled = !it.micEnabled) }
                val enabled = mutableState.value.micEnabled
                viewModelScope.launch { service.setMicrophoneEnabled(enabled) }
            }
            is RideEvent.PresentSOS -> updateState { it.copy(sosPresented = event.presented) }
            RideEvent.Pay -> capturePayment()
            is RideEvent.Rate -> {
                updateState { it.copy(rating = event.rating.coerceIn(0, 5)) }
                val rating = mutableState.value.rating
                val session = activeSession
                viewModelScope.launch { service.submitRating(rating, session) }
            }
        }
    }

    private fun startMatching() {
        cancelActiveRide()
        val config = mutableState.value.config
        updateState { it.copy(phase = RidePhase.Matching, paid = false, rating = 0, carProgress = 0f) }
        matchingJob = viewModelScope.launch {
            activeSession = service.requestRide(config)
            delay(2_600)
            onEvent(RideEvent.MatchingComplete)
        }
    }

    private fun startEnroute() {
        matchingJob?.cancel()
        updateState { it.copy(phase = RidePhase.Enroute, carProgress = 0f) }
        startEnrouteFrom(initialProgress = 0f)
    }

    private fun reset() {
        cancelTimeline()
        activeSession = null
        mutableState.value = RideUiState()
        stateStore.clear()
    }

    private fun cancelRideAndReset() {
        cancelActiveRide()
        mutableState.value = RideUiState()
        stateStore.clear()
    }

    private fun cancelTimeline() {
        matchingJob?.cancel()
        rideJob?.cancel()
        matchingJob = null
        rideJob = null
    }

    private fun cancelActiveRide() {
        cancelTimeline()
        service.cancelRide(activeSession)
        activeSession = null
    }

    private fun updateState(transform: (RideUiState) -> RideUiState) {
        mutableState.update(transform)
        stateStore.write(mutableState.value)
    }

    private fun resumeTimelineIfNeeded() {
        when (mutableState.value.phase) {
            RidePhase.Matching -> startMatching()
            RidePhase.Enroute -> startEnrouteFrom(mutableState.value.carProgress)
            RidePhase.Destination, RidePhase.Options, RidePhase.Complete -> Unit
        }
    }

    private fun startEnrouteFrom(initialProgress: Float) {
        rideJob?.cancel()
        rideJob = viewModelScope.launch {
            val durationMs = 11_000f
            var elapsed = initialProgress.coerceIn(0f, 1f) * durationMs
            while (elapsed < durationMs) {
                delay(80)
                elapsed += 80f
                onEvent(RideEvent.SetCarProgress(round((elapsed / durationMs) * 1000f) / 1000f))
            }
            onEvent(RideEvent.FinishRide)
        }
    }

    private fun capturePayment() {
        val config = mutableState.value.config
        viewModelScope.launch {
            service.capturePayment(config.tier.price, config.destinationName)
            updateState { it.copy(paid = true) }
        }
    }

    companion object {
        fun factory(
            stateStore: RideStateStore,
            service: RideService = MockRideService(),
        ): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>, extras: CreationExtras): T {
                    return RideViewModel(stateStore, service) as T
                }
            }
    }
}
