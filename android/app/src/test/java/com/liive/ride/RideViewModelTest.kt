package com.liive.ride

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class RideViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun offlinePoolFlowAdvancesThroughRequiredPhases() = runTest(dispatcher) {
        val store = FakeRideStateStore()
        val service = RecordingRideService()
        val viewModel = RideViewModel(store, service)
        val destination = RideFixtures.destinations[2]

        viewModel.onEvent(RideEvent.SelectDestination(destination))
        assertEquals(RidePhase.Options, viewModel.state.value.phase)
        assertEquals("Union Square", viewModel.state.value.config.destinationName)

        viewModel.onEvent(RideEvent.SelectTier(RideTier.Pool))
        viewModel.onEvent(RideEvent.SetFemaleOnly(true))
        assertTrue(viewModel.state.value.config.tier.multiLeg)
        assertEquals("Transfer at Hayes St complete · 150m walk", viewModel.state.value.tripSummary.transferStatus)

        viewModel.onEvent(RideEvent.ConfirmPickup)
        assertEquals(RidePhase.Matching, viewModel.state.value.phase)
        runCurrent()
        assertEquals(listOf(RideTier.Pool), service.requestedConfigs.map { it.tier })

        viewModel.onEvent(RideEvent.MatchingComplete)
        assertEquals(RidePhase.Enroute, viewModel.state.value.phase)

        viewModel.onEvent(RideEvent.FinishRide)
        assertEquals(RidePhase.Complete, viewModel.state.value.phase)
        assertEquals(1f, viewModel.state.value.carProgress)

        viewModel.onEvent(RideEvent.Rate(5))
        advanceUntilIdle()
        assertEquals(listOf(5), service.submittedRatings)

        viewModel.onEvent(RideEvent.Pay)
        advanceUntilIdle()
        assertTrue(viewModel.state.value.paid)
        assertEquals(listOf(9.5), service.capturedPayments.map { it.amount })
        assertEquals(listOf("Union Square"), service.capturedPayments.map { it.destinationName })
    }

    @Test
    fun optionsStatePersistsAndRestoresFromStore() = runTest(dispatcher) {
        val store = FakeRideStateStore()
        val firstViewModel = RideViewModel(store, RecordingRideService())

        firstViewModel.onEvent(RideEvent.SelectDestination(RideFixtures.destinations[1]))
        firstViewModel.onEvent(RideEvent.SelectTier(RideTier.Exclusive))
        firstViewModel.onEvent(RideEvent.SetPassengers(3))
        firstViewModel.onEvent(RideEvent.SetBags(2))

        val restoredViewModel = RideViewModel(store, RecordingRideService())
        assertEquals(RidePhase.Options, restoredViewModel.state.value.phase)
        assertEquals("Work", restoredViewModel.state.value.destination?.title)
        assertEquals("Work", restoredViewModel.state.value.config.destinationName)
        assertEquals(RideTier.Exclusive, restoredViewModel.state.value.config.tier)
        assertEquals(3, restoredViewModel.state.value.config.passengers)
        assertEquals(2, restoredViewModel.state.value.config.bags)
    }

    @Test
    fun rideRequestFailureReturnsToOptionsWithoutStartingRide() = runTest(dispatcher) {
        val store = FakeRideStateStore()
        val viewModel = RideViewModel(store, FailingRideService())

        viewModel.onEvent(RideEvent.SelectDestination(RideFixtures.destinations[2]))
        viewModel.onEvent(RideEvent.ConfirmPickup)
        assertEquals(RidePhase.Matching, viewModel.state.value.phase)

        runCurrent()
        assertEquals(RidePhase.Options, viewModel.state.value.phase)
    }

    @Test
    fun paymentFailureLeavesCompletedRideUnpaid() = runTest(dispatcher) {
        val store = FakeRideStateStore(RideUiState(phase = RidePhase.Complete))
        val service = PaymentFailingRideService()
        val viewModel = RideViewModel(store, service)

        viewModel.onEvent(RideEvent.Pay)
        runCurrent()

        assertEquals(1, service.paymentAttempts)
        assertEquals(false, viewModel.state.value.paid)
    }
}

private class FakeRideStateStore(initialState: RideUiState = RideUiState()) : RideStateStoring {
    private var storedState = initialState

    override fun read(): RideUiState = storedState

    override fun write(state: RideUiState) {
        storedState = state
    }

    override fun clear() {
        storedState = RideUiState()
    }
}

private class RecordingRideService : RideService {
    val requestedConfigs = mutableListOf<RideConfig>()
    val capturedPayments = mutableListOf<RidePaymentReceipt>()
    val submittedRatings = mutableListOf<Int>()
    val microphoneStates = mutableListOf<Boolean>()
    val cancelledSessions = mutableListOf<RideSession?>()

    override suspend fun requestRide(config: RideConfig): RideSession {
        requestedConfigs += config
        val driver = RideFixtures.driver
        return RideSession(
            id = "test_ride",
            voiceRoomName = "ride_test",
            driverName = driver.name,
            driverRating = driver.rating,
            vehicle = driver.vehicle,
            plate = driver.plate,
            tripSummary = config.tripSummary(),
        )
    }

    override fun cancelRide(session: RideSession?) {
        cancelledSessions += session
    }

    override suspend fun setMicrophoneEnabled(enabled: Boolean) {
        microphoneStates += enabled
    }

    override suspend fun capturePayment(amount: Double, destinationName: String): RidePaymentReceipt {
        val receipt = RidePaymentReceipt(id = "test_receipt", amount = amount, destinationName = destinationName)
        capturedPayments += receipt
        return receipt
    }

    override suspend fun submitRating(rating: Int, session: RideSession?) {
        submittedRatings += rating
    }
}

private class FailingRideService : RideService {
    override suspend fun requestRide(config: RideConfig): RideSession {
        error("Synthetic ride request failure.")
    }

    override fun cancelRide(session: RideSession?) = Unit

    override suspend fun setMicrophoneEnabled(enabled: Boolean) = Unit

    override suspend fun capturePayment(amount: Double, destinationName: String): RidePaymentReceipt {
        error("Synthetic payment failure.")
    }

    override suspend fun submitRating(rating: Int, session: RideSession?) = Unit
}

private class PaymentFailingRideService : RideService {
    var paymentAttempts = 0
        private set

    override suspend fun requestRide(config: RideConfig): RideSession {
        val driver = RideFixtures.driver
        return RideSession(
            id = "test_ride",
            voiceRoomName = "ride_test",
            driverName = driver.name,
            driverRating = driver.rating,
            vehicle = driver.vehicle,
            plate = driver.plate,
            tripSummary = config.tripSummary(),
        )
    }

    override fun cancelRide(session: RideSession?) = Unit

    override suspend fun setMicrophoneEnabled(enabled: Boolean) = Unit

    override suspend fun capturePayment(amount: Double, destinationName: String): RidePaymentReceipt {
        paymentAttempts += 1
        error("Synthetic payment failure.")
    }

    override suspend fun submitRating(rating: Int, session: RideSession?) = Unit
}
