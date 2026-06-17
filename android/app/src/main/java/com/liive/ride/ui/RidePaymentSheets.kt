package com.liive.ride.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.liive.ride.RideEvent
import com.liive.ride.RideTestTags
import com.liive.ride.RideUiState
import com.liive.ride.fareBreakdown
import com.liive.ride.firstName
import com.liive.ride.rideCreditPrice
import com.liive.ride.ridePrice
import com.liive.ride.designsystem.IconCircleColor
import com.liive.ride.designsystem.LiiveBottomSheet
import com.liive.ride.designsystem.LiiveButton
import com.liive.ride.designsystem.LiiveButtonSize
import com.liive.ride.designsystem.LiiveFareRow
import com.liive.ride.designsystem.LiiveIconCircle
import com.liive.ride.designsystem.LiiveListRow
import com.liive.ride.designsystem.LiiveRadius
import com.liive.ride.designsystem.LiiveTheme
import com.liive.ride.designsystem.RideIcons
import com.liive.ride.designsystem.tabularNumbers

@Composable
internal fun PaidReceiptSheet(state: RideUiState, onEvent: (RideEvent) -> Unit) {
    val c = LiiveTheme.colors
    val fare = state.config.fareBreakdown()
    LiiveBottomSheet(modifier = Modifier.testTag(RideTestTags.ReceiptSheet)) {
        Column(Modifier.fillMaxWidth().padding(vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            LiiveIconCircle(RideIcons.Check, IconCircleColor.Success, 56.dp, filled = true)
            Text("Thanks for riding", color = c.text, style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(top = 14.dp))
            Text("${fare.total.ridePrice()} paid to ${state.driver.firstName()} · receipt sent", color = c.textSecondary, style = MaterialTheme.typography.titleMedium.tabularNumbers(), modifier = Modifier.padding(top = 6.dp))
        }
        Spacer(Modifier.height(20.dp))
        LiiveButton(
            title = "Done",
            onClick = { onEvent(RideEvent.Reset) },
            fullWidth = true,
            size = LiiveButtonSize.Lg,
            capsule = true
        )
    }
}

@Composable
internal fun PaymentSheet(state: RideUiState, onEvent: (RideEvent) -> Unit) {
    val c = LiiveTheme.colors
    val fare = state.config.fareBreakdown()
    LiiveBottomSheet(modifier = Modifier.testTag(RideTestTags.PaymentSheet)) {
        Row(Modifier.fillMaxWidth().padding(bottom = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            LiiveIconCircle(RideIcons.Flag, IconCircleColor.Success, 36.dp, filled = true)
            Column(Modifier.weight(1f)) {
                Text("You've arrived", color = c.text, style = MaterialTheme.typography.headlineSmall)
                Text("${state.config.destinationName} · ${completedTripLine(state)}", color = c.textSecondary, style = MaterialTheme.typography.bodySmall.tabularNumbers())
            }
        }
        Column(
            Modifier
                .fillMaxWidth()
                .clip(LiiveRadius.lg)
                .background(c.surfaceRaised)
                .padding(start = 14.dp, top = 8.dp, end = 14.dp, bottom = 14.dp)
        ) {
            LiiveFareRow("Ride fare", fare.rideFare.ridePrice())
            LiiveFareRow("Tax & fees", fare.taxAndFees.ridePrice())
            fare.costShareCredit?.let { LiiveFareRow("Cost-share credit", it.rideCreditPrice(), muted = true) }
            Box(Modifier.fillMaxWidth().height(0.5.dp).background(c.separator))
            LiiveFareRow("Total", fare.total.ridePrice(), total = true)
        }
        Spacer(Modifier.height(12.dp))
        Column(Modifier.fillMaxWidth().clip(LiiveRadius.lg).background(c.surfaceRaised)) {
            LiiveListRow("Google Pay", value = "default", divider = false, chevron = true, leading = {
                LiiveIconCircle(RideIcons.CreditCard, IconCircleColor.Neutral, 32.dp)
            })
        }
        RatingControl(state.rating, onEvent)
        LiiveButton(
            title = "Pay ${fare.total.ridePrice()}",
            onClick = { onEvent(RideEvent.Pay) },
            fullWidth = true,
            size = LiiveButtonSize.Lg,
            capsule = true,
            tabularNumbers = true
        )
        Text("Secured by Stripe", color = c.textTertiary, style = MaterialTheme.typography.labelMedium, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 10.dp))
    }
}

private fun completedTripLine(state: RideUiState): String =
    "${state.tripSummary.completedDuration} · ${state.tripSummary.completedDistance}"

@Composable
private fun RatingControl(rating: Int, onEvent: (RideEvent) -> Unit) {
    val c = LiiveTheme.colors
    Column(Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            "Rate your driver",
            color = c.textSecondary,
            style = MaterialTheme.typography.titleMedium.copy(fontSize = 14.sp)
        )
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(top = 8.dp)) {
            (1..5).forEach { value ->
                Icon(
                    painterResource(RideIcons.Star),
                    null,
                    tint = if (value <= rating) c.star else c.fill,
                    modifier = Modifier
                        .padding(2.dp)
                        .size(28.dp)
                        .clickableNoRipple { onEvent(RideEvent.Rate(value)) }
                )
            }
        }
    }
}
