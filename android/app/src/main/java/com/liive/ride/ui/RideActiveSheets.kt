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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import com.liive.ride.*
import com.liive.ride.designsystem.*

@Composable
fun RideMatchingSheet(state: RideUiState, onEvent: (RideEvent) -> Unit) {
    val c = LiiveTheme.colors
    val transition = rememberInfiniteTransition(label = "matching")

    LiiveBottomSheet(modifier = Modifier.testTag(RideTestTags.MatchingSheet)) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(
                    top = RideSheetLayout.matchingContentTopPadding,
                    bottom = RideSheetLayout.matchingContentBottomPadding
                ),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(RideSheetLayout.inlineGap),
                modifier = Modifier.padding(bottom = LiiveSpacing.l)
            ) {
                repeat(RideSheetLayout.matchingDotCount) { index ->
                    val dotProgress by transition.animateFloat(
                        initialValue = 0f,
                        targetValue = 1f,
                        animationSpec = infiniteRepeatable(
                            animation = tween(
                                durationMillis = RideSheetLayout.matchingDotDurationMs,
                                delayMillis = index * RideSheetLayout.matchingDotDelayMs,
                                easing = FastOutSlowInEasing
                            ),
                            repeatMode = RepeatMode.Reverse
                        ),
                        label = "matchingDot$index"
                    )
                    Box(
                        Modifier.offset(y = RideSheetLayout.matchingDotLift * dotProgress)
                            .alpha(0.5f + dotProgress * 0.5f)
                            .size(RideSheetLayout.matchingDotSize).clip(CircleShape).background(c.accent)
                    )
                }
            }
            Text("Finding your driver…", color = c.text, style = MaterialTheme.typography.headlineSmall)
            Text(
                "Matching you with a nearby${if (state.config.femaleOnly) " female-only" else ""} ${state.config.tier.name.lowercase()} driver and reserving a legal curb.",
                color = c.textSecondary,
                style = LiiveSheetMeta,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .widthIn(max = RideSheetLayout.matchingDescriptionMaxWidth)
                    .padding(top = RideSheetLayout.inlineGap)
            )
            Row(
                horizontalArrangement = Arrangement.spacedBy(RideSheetLayout.controlGap),
                modifier = Modifier.padding(top = LiiveSpacing.l)
            ) {
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
    LiiveBottomSheet(modifier = Modifier.testTag(RideTestTags.EnrouteSheet)) {
        Row(Modifier.fillMaxWidth().padding(bottom = RideSheetLayout.headerBottomPadding)) {
            Text(
                state.tripSummary.enrouteTitle,
                color = c.text,
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.alignByBaseline()
            )
            Spacer(Modifier.weight(1f))
            Text(
                "to ${config.destinationName}",
                color = c.textSecondary,
                style = LiiveSheetMeta,
                modifier = Modifier.alignByBaseline()
            )
        }
        LiiveDriverCard(
            name = driver.name,
            rating = driver.rating,
            vehicle = driver.vehicle,
            plate = driver.plate,
            eta = state.tripSummary.driverEta,
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
        state.tripSummary.transferStatus?.let { MultiLegPanel(it) }
        Row(
            Modifier.fillMaxWidth().padding(top = RideSheetLayout.sectionGap),
            horizontalArrangement = Arrangement.spacedBy(RideSheetLayout.rowGap)
        ) {
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
private fun MultiLegPanel(transferStatus: String) {
    val c = LiiveTheme.colors
    Column(
        Modifier
            .fillMaxWidth()
            .padding(top = RideSheetLayout.multiLegPanelTopPadding)
            .clip(LiiveRadius.lg)
            .background(c.surfaceRaised)
            .padding(RideSheetLayout.multiLegPanelPadding),
        verticalArrangement = Arrangement.spacedBy(RideSheetLayout.rowGap)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(RideSheetLayout.controlGap)) {
            Icon(painterResource(RideIcons.Map), null, tint = c.accent, modifier = Modifier.size(RideSheetLayout.multiLegIconSize))
            Text(
                "Multi-leg journey",
                color = c.text,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
        }
        LiiveProgressDots(legs = 2, current = 2)
        Box(Modifier.fillMaxWidth().height(RideSheetLayout.progressSeparatorTrackHeight)) {
            Box(
                Modifier.align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(RideSheetLayout.hairlineHeight)
                    .background(c.separator)
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(RideSheetLayout.inlineGap)) {
            Icon(painterResource(RideIcons.Walk), null, tint = c.warning, modifier = Modifier.size(RideSheetLayout.transferIconSize))
            Text(transferStatus, color = c.textSecondary, style = MaterialTheme.typography.bodySmall)
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
    Box(
        Modifier
            .fillMaxSize()
            .background(c.scrimStrong)
            .testTag(RideTestTags.SosConfirmation),
        contentAlignment = Alignment.Center
    ) {
        Column(
            Modifier
                .widthIn(max = RideSheetLayout.sosPanelMaxWidth)
                .clip(LiiveRadius.xl)
                .background(c.surface)
                .padding(RideSheetLayout.sosPanelPadding),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("Emergency Alert", color = c.text, style = MaterialTheme.typography.headlineSmall)
            Text(
                "This will immediately alert emergency services and your emergency contacts. Are you sure?",
                color = c.textSecondary,
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(
                    top = RideSheetLayout.sosMessageTopPadding,
                    bottom = RideSheetLayout.sosMessageBottomPadding
                )
            )
            LiiveButton("Call Emergency Services", fullWidth = true, variant = LiiveButtonVariant.Destructive, size = LiiveButtonSize.Lg, capsule = true, onClick = onEmergency)
            Spacer(Modifier.height(RideSheetLayout.sosButtonGap))
            LiiveButton("Cancel", fullWidth = true, variant = LiiveButtonVariant.Plain, onClick = onCancel)
        }
    }
}
