package com.liive.ride

data class RideSession(
    val id: String,
    val voiceRoomName: String,
    val driverName: String,
    val driverRating: Double,
    val vehicle: String,
    val plate: String,
)

data class RidePaymentReceipt(
    val id: String,
    val amount: Double,
    val destinationName: String,
)

interface RideService {
    suspend fun requestRide(config: RideConfig): RideSession
    fun cancelRide(session: RideSession?)
    suspend fun setMicrophoneEnabled(enabled: Boolean)
    suspend fun capturePayment(amount: Double, destinationName: String): RidePaymentReceipt
    suspend fun submitRating(rating: Int, session: RideSession?)
}

class MockRideService : RideService {
    override suspend fun requestRide(config: RideConfig): RideSession {
        val driver = RideFixtures.driver
        return RideSession(
            id = "ride_mock_001",
            voiceRoomName = "ride_mock_001",
            driverName = driver.name,
            driverRating = driver.rating,
            vehicle = driver.vehicle,
            plate = driver.plate,
        )
    }

    override fun cancelRide(session: RideSession?) = Unit

    override suspend fun setMicrophoneEnabled(enabled: Boolean) = Unit

    override suspend fun capturePayment(amount: Double, destinationName: String): RidePaymentReceipt =
        RidePaymentReceipt(id = "receipt_mock_001", amount = amount, destinationName = destinationName)

    override suspend fun submitRating(rating: Int, session: RideSession?) = Unit
}

fun RideSession.driver(): RideDriver =
    RideDriver(name = driverName, rating = driverRating, vehicle = vehicle, plate = plate)
