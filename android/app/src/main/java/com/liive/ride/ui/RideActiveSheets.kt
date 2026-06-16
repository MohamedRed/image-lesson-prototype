package com.liive.ride.ui

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.liive.ride.*
import com.liive.ride.designsystem.*

@Composable
fun RideMatchingSheet(state: RideUiState, onEvent: (RideEvent) -> Unit) {
    val c = LiiveTheme.colors
    val transition = rememberInfiniteTransition(label = "matching")

    LiiveBottomSheet {
        Column(
            Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 22.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(bottom = 16.dp)) {
                repeat(3) { index ->
                    val dotProgress by transition.animateFloat(
                        initialValue = 0f,
                        targetValue = 1f,
                        animationSpec = infiniteRepeatable(
                            animation = tween(
                                durationMillis = 600,
                                delayMillis = index * 160,
                                easing = FastOutSlowInEasing
                            ),
                            repeatMode = RepeatMode.Reverse
                        ),
                        label = "matchingDot$index"
                    )
                    Box(
                        Modifier.offset(y = (-7).dp * dotProgress)
                            .alpha(0.5f + dotProgress * 0.5f)
                            .size(9.dp).clip(CircleShape).background(c.accent)
                    )
                }
            }
            Text("Finding your driver…", color = c.text, style = MaterialTheme.typography.headlineSmall)
            Text(
                "Matching you with a nearby${if (state.config.femaleOnly) " female-only" else ""} ${state.config.tier.name.lowercase()} driver and reserving a legal curb.",
                color = c.textSecondary,
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
                modifier = Modifier.widthIn(max = 280.dp).padding(top = 6.dp)
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 16.dp)) {
                LiiveBadge("Curb reserved", BadgeColor.Success, dot = true)
                if (state.config.femaleOnly) LiiveBadge("Female-only pool", BadgeColor.Accent)
            }
        }
        LiiveButton(
            title = "Cancel",
            onClick = { onEvent(RideEvent.CancelMatching) },
            fullWidth = true,
            variant = LiiveButtonVariant.Secondary,
            size = LiiveButtonSize.Lg,
            capsule = true
        )
    }
}

@Composable
fun RideEnrouteSheet(state: RideUiState, onEvent: (RideEvent) -> Unit) {
    val c = LiiveTheme.colors
    val config = state.config
    LiiveBottomSheet {
        Row(Modifier.fillMaxWidth().padding(bottom = 12.dp), verticalAlignment = Alignment.Bottom) {
            Text(if (config.tier.multiLeg) "On leg 2 of 2" else "Your driver is arriving", color = c.text, style = MaterialTheme.typography.headlineSmall)
            Spacer(Modifier.weight(1f))
            Text("to ${config.destinationName}", color = c.textSecondary, style = MaterialTheme.typography.bodySmall)
        }
        LiiveDriverCard(
            name = "John Driver",
            rating = 4.8,
            vehicle = "Toyota Camry · Blue",
            plate = "ABC 123",
            eta = if (config.tier.multiLeg) "3 min" else "4 min",
            speaking = true
        ) {
            LiiveButton(
                title = "",
                onClick = {},
                variant = LiiveButtonVariant.Tinted,
                icon = RideIcons.Phone,
                iconOnly = true,
                contentDescription = "Call driver"
            )
        }
        if (config.tier.multiLeg) MultiLegPanel()
        Row(Modifier.fillMaxWidth().padding(top = 14.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            LiiveButton(
                title = "Message",
                onClick = {},
                modifier = Modifier.weight(1f),
                variant = LiiveButtonVariant.Secondary,
                size = LiiveButtonSize.Lg,
                icon = RideIcons.Message
            )
            LiiveButton(
                title = "Cancel Ride",
                onClick = { onEvent(RideEvent.CancelRide) },
                modifier = Modifier.weight(1f),
                variant = LiiveButtonVariant.DestructivePlain,
                size = LiiveButtonSize.Lg
            )
        }
    }
}

@Composable
private fun MultiLegPanel() {
    val c = LiiveTheme.colors
    Column(
        Modifier.fillMaxWidth().padding(top = 12.dp).clip(LiiveRadius.lg).background(c.surfaceRaised).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(painterResource(RideIcons.Map), null, tint = c.accent, modifier = Modifier.size(16.dp))
            Text("Multi-leg journey", color = c.text, style = MaterialTheme.typography.titleMedium)
        }
        LiiveProgressDots(legs = 2, current = 2)
        Box(Modifier.fillMaxWidth().height(0.5.dp).background(c.separator))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(painterResource(RideIcons.Walk), null, tint = c.warning, modifier = Modifier.size(15.dp))
            Text("Transfer at Hayes St complete · 150m walk", color = c.textSecondary, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
fun RideCompleteSheet(state: RideUiState, onEvent: (RideEvent) -> Unit) {
    if (state.paid) PaidReceiptSheet(state, onEvent) else PaymentSheet(state, onEvent)
}

@Composable
private fun PaidReceiptSheet(state: RideUiState, onEvent: (RideEvent) -> Unit) {
    val c = LiiveTheme.colors
    LiiveBottomSheet {
        Column(Modifier.fillMaxWidth().padding(vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            LiiveIconCircle(RideIcons.Check, IconCircleColor.Success, 56.dp, filled = true)
            Text("Thanks for riding", color = c.text, style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(top = 14.dp))
            Text("${state.config.tier.price.ridePrice()} paid to John · receipt sent", color = c.textSecondary, style = MaterialTheme.typography.titleMedium.tabularNumbers(), modifier = Modifier.padding(top = 6.dp))
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
private fun PaymentSheet(state: RideUiState, onEvent: (RideEvent) -> Unit) {
    val c = LiiveTheme.colors
    val fare = state.config.tier.price
    val base = kotlin.math.round((fare / 1.0875) * 100.0) / 100.0
    val tax = kotlin.math.round((fare - base) * 100.0) / 100.0
    LiiveBottomSheet {
        Row(Modifier.fillMaxWidth().padding(bottom = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            LiiveIconCircle(RideIcons.Flag, IconCircleColor.Success, 36.dp, filled = true)
            Column(Modifier.weight(1f)) {
                Text("You've arrived", color = c.text, style = MaterialTheme.typography.headlineSmall)
                Text("${state.config.destinationName} · 18 min · 5.2 km", color = c.textSecondary, style = MaterialTheme.typography.bodySmall.tabularNumbers())
            }
        }
        Column(Modifier.fillMaxWidth().clip(LiiveRadius.lg).background(c.surfaceRaised).padding(horizontal = 14.dp, vertical = 8.dp)) {
            LiiveFareRow("Ride fare", base.ridePrice())
            LiiveFareRow("Tax & fees", tax.ridePrice())
            if (state.config.tier.multiLeg) LiiveFareRow("Cost-share credit", "–$2.00", muted = true)
            Box(Modifier.fillMaxWidth().height(0.5.dp).background(c.separator))
            LiiveFareRow("Total", fare.ridePrice(), total = true)
        }
        Spacer(Modifier.height(12.dp))
        Column(Modifier.fillMaxWidth().clip(LiiveRadius.lg).background(c.surfaceRaised)) {
            LiiveListRow("Google Pay", value = "default", divider = false, chevron = true, leading = {
                LiiveIconCircle(RideIcons.CreditCard, IconCircleColor.Neutral, 32.dp)
            })
        }
        RatingControl(state.rating, onEvent)
        LiiveButton(
            title = "Pay ${fare.ridePrice()}",
            onClick = { onEvent(RideEvent.Pay) },
            fullWidth = true,
            size = LiiveButtonSize.Lg,
            capsule = true,
            tabularNumbers = true
        )
        Text("Secured by Stripe", color = c.textTertiary, style = MaterialTheme.typography.labelMedium, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 10.dp))
    }
}

@Composable
private fun RatingControl(rating: Int, onEvent: (RideEvent) -> Unit) {
    val c = LiiveTheme.colors
    Column(Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text("Rate your driver", color = c.textSecondary, style = MaterialTheme.typography.bodySmall)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(top = 8.dp)) {
            (1..5).forEach { value ->
                Icon(
                    painterResource(RideIcons.Star),
                    null,
                    tint = if (value <= rating) c.star else c.fill,
                    modifier = Modifier.size(28.dp).clickableNoRipple { onEvent(RideEvent.Rate(value)) }
                )
            }
        }
    }
}

@Composable
fun RideSOSConfirmation(onEmergency: () -> Unit, onCancel: () -> Unit) {
    val c = LiiveTheme.colors
    Box(Modifier.fillMaxSize().background(androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.55f)), contentAlignment = Alignment.Center) {
        Column(
            Modifier.widthIn(max = 300.dp).clip(LiiveRadius.xl).background(c.surface).padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("Emergency Alert", color = c.text, style = MaterialTheme.typography.headlineSmall)
            Text(
                "This will immediately alert emergency services and your emergency contacts. Are you sure?",
                color = c.textSecondary,
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 10.dp, bottom = 18.dp)
            )
            LiiveButton("Call Emergency Services", fullWidth = true, variant = LiiveButtonVariant.Destructive, size = LiiveButtonSize.Lg, capsule = true, onClick = onEmergency)
            Spacer(Modifier.height(8.dp))
            LiiveButton("Cancel", fullWidth = true, variant = LiiveButtonVariant.Plain, onClick = onCancel)
        }
    }
}
