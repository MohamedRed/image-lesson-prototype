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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
                style = MaterialTheme.typography.titleMedium.copy(fontSize = 14.sp),
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
    val driver = state.driver
    LiiveBottomSheet {
        Row(Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
            Text(
                if (config.tier.multiLeg) "On leg 2 of 2" else "Your driver is arriving",
                color = c.text,
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.alignByBaseline()
            )
            Spacer(Modifier.weight(1f))
            Text(
                "to ${config.destinationName}",
                color = c.textSecondary,
                style = MaterialTheme.typography.titleMedium.copy(fontSize = 14.sp),
                modifier = Modifier.alignByBaseline()
            )
        }
        LiiveDriverCard(
            name = driver.name,
            rating = driver.rating,
            vehicle = driver.vehicle,
            plate = driver.plate,
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
            Text(
                "Multi-leg journey",
                color = c.text,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
        }
        LiiveProgressDots(legs = 2, current = 2)
        Box(Modifier.fillMaxWidth().height(2.5.dp)) {
            Box(
                Modifier.align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(0.5.dp)
                    .background(c.separator)
            )
        }
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
fun RideSOSConfirmation(onEmergency: () -> Unit, onCancel: () -> Unit) {
    val c = LiiveTheme.colors
    Box(Modifier.fillMaxSize().background(c.scrimStrong), contentAlignment = Alignment.Center) {
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
