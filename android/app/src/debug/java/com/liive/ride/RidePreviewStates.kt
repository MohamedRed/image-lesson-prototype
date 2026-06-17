package com.liive.ride

import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview

private object RidePreviewStates {
    val destination = RideUiState()

    val options = base(destinationIndex = 2, tier = RideTier.Premium).copy(
        phase = RidePhase.Options
    )

    val matching = base(destinationIndex = 2, tier = RideTier.Pool).copy(
        phase = RidePhase.Matching
    )

    val enroute = base(destinationIndex = 2, tier = RideTier.Pool).copy(
        phase = RidePhase.Enroute,
        carProgress = 0.56f
    )

    val payment = base(destinationIndex = 2, tier = RideTier.Premium).copy(
        phase = RidePhase.Complete,
        carProgress = 1f,
        rating = 4
    )

    val receipt = payment.copy(paid = true, rating = 5)

    private fun base(destinationIndex: Int, tier: RideTier): RideUiState {
        val destination = RideFixtures.destinations[destinationIndex]
        val config = RideConfig(
            tier = tier,
            femaleOnly = tier == RideTier.Pool,
            destinationName = destination.title
        )
        return RideUiState(
            destination = destination,
            config = config,
            tripSummary = config.tripSummary(),
            driver = RideFixtures.driver
        )
    }
}

@Preview(name = "1 Destination", widthDp = 402, heightDp = 740, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RideDestinationPreview() {
    RidePreviewContent(RidePreviewStates.destination, darkTheme = true)
}

@Preview(name = "2 Options", widthDp = 402, heightDp = 740, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RideOptionsPreview() {
    RidePreviewContent(RidePreviewStates.options, darkTheme = true)
}

@Preview(name = "3 Matching", widthDp = 402, heightDp = 740, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RideMatchingPreview() {
    RidePreviewContent(RidePreviewStates.matching, darkTheme = true)
}

@Preview(name = "4 Enroute", widthDp = 402, heightDp = 740, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RideEnroutePreview() {
    RidePreviewContent(RidePreviewStates.enroute, darkTheme = true)
}

@Preview(name = "5 Payment", widthDp = 402, heightDp = 740, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RidePaymentPreview() {
    RidePreviewContent(RidePreviewStates.payment, darkTheme = true)
}

@Preview(name = "6 Receipt", widthDp = 402, heightDp = 740, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun RideReceiptPreview() {
    RidePreviewContent(RidePreviewStates.receipt, darkTheme = true)
}

@Preview(name = "Light 1 Destination", widthDp = 402, heightDp = 740, uiMode = Configuration.UI_MODE_NIGHT_NO)
@Composable
private fun RideLightDestinationPreview() {
    RidePreviewContent(RidePreviewStates.destination, darkTheme = false)
}

@Preview(name = "Light 2 Options", widthDp = 402, heightDp = 740, uiMode = Configuration.UI_MODE_NIGHT_NO)
@Composable
private fun RideLightOptionsPreview() {
    RidePreviewContent(RidePreviewStates.options, darkTheme = false)
}

@Preview(name = "Light 3 Matching", widthDp = 402, heightDp = 740, uiMode = Configuration.UI_MODE_NIGHT_NO)
@Composable
private fun RideLightMatchingPreview() {
    RidePreviewContent(RidePreviewStates.matching, darkTheme = false)
}

@Preview(name = "Light 4 Enroute", widthDp = 402, heightDp = 740, uiMode = Configuration.UI_MODE_NIGHT_NO)
@Composable
private fun RideLightEnroutePreview() {
    RidePreviewContent(RidePreviewStates.enroute, darkTheme = false)
}

@Preview(name = "Light 5 Payment", widthDp = 402, heightDp = 740, uiMode = Configuration.UI_MODE_NIGHT_NO)
@Composable
private fun RideLightPaymentPreview() {
    RidePreviewContent(RidePreviewStates.payment, darkTheme = false)
}

@Preview(name = "Light 6 Receipt", widthDp = 402, heightDp = 740, uiMode = Configuration.UI_MODE_NIGHT_NO)
@Composable
private fun RideLightReceiptPreview() {
    RidePreviewContent(RidePreviewStates.receipt, darkTheme = false)
}

@Composable
private fun RidePreviewContent(state: RideUiState, darkTheme: Boolean) {
    RideAppContent(state = state, onEvent = {}, darkTheme = darkTheme)
}
