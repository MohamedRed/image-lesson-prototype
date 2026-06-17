package com.liive.ride

import androidx.annotation.DrawableRes
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.liive.ride.designsystem.*
import com.liive.ride.ui.*

@Composable
fun RideApp(viewModel: RideViewModel, darkTheme: Boolean = true) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LiiveTheme(darkTheme = darkTheme) {
        Box(Modifier.fillMaxSize().background(LiiveTheme.colors.bg)) {
            RideMapCanvas(
                phase = state.phase,
                isMultiLeg = state.config.tier.multiLeg,
                carProgress = state.carProgress,
                tripSummary = state.tripSummary
            )

            AnimatedVisibility(
                visible = state.phase == RidePhase.Complete,
                enter = fadeIn(),
                exit = fadeOut()
            ) {
                Box(Modifier.fillMaxSize().background(LiiveTheme.colors.scrimSubtle))
            }

            RideTopChrome(
                state = state,
                onToggleMic = { viewModel.onEvent(RideEvent.ToggleMic) }
            )

            if (state.phase == RidePhase.Matching || state.phase == RidePhase.Enroute) {
                LiiveSosButton(
                    size = 54.dp,
                    showLabel = false,
                    onActivate = { viewModel.onEvent(RideEvent.PresentSOS(true)) },
                    modifier = Modifier.align(Alignment.TopEnd).padding(top = 116.dp, end = 16.dp)
                )
            }

            Box(Modifier.align(Alignment.BottomCenter)) {
                when (state.phase) {
                    RidePhase.Destination -> RideDestinationSheet(viewModel::onEvent)
                    RidePhase.Options -> RideOptionsSheet(state, viewModel::onEvent)
                    RidePhase.Matching -> RideMatchingSheet(state, viewModel::onEvent)
                    RidePhase.Enroute -> RideEnrouteSheet(state, viewModel::onEvent)
                    RidePhase.Complete -> RideCompleteSheet(state, viewModel::onEvent)
                }
            }

            if (state.sosPresented) {
                RideSOSConfirmation(
                    onEmergency = { viewModel.onEvent(RideEvent.PresentSOS(false)) },
                    onCancel = { viewModel.onEvent(RideEvent.PresentSOS(false)) }
                )
            }
        }
    }
}

@Composable
private fun RideTopChrome(state: RideUiState, onToggleMic: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(top = 58.dp, start = 16.dp, end = 16.dp),
        verticalAlignment = Alignment.Top
    ) {
        if (state.phase == RidePhase.Enroute) {
            LiiveGlassPanel(material = GlassMaterial.Thin, shape = LiiveRadius.full, padding = 0.dp) {
                Box(Modifier.padding(horizontal = 12.dp, vertical = 7.dp)) {
                    LiiveBadge("Voice connected", BadgeColor.Success, dot = true)
                }
            }
        } else {
            Spacer(Modifier.size(1.dp))
        }

        Spacer(Modifier.weight(1f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (state.phase == RidePhase.Enroute) {
                ChromeButton(
                    icon = if (state.micEnabled) RideIcons.Mic else RideIcons.MicOff,
                    tint = if (state.micEnabled) LiiveTheme.colors.text else LiiveTheme.colors.danger,
                    onClick = onToggleMic
                )
            }
            ChromeButton(
                icon = RideIcons.LocationSearching,
                tint = LiiveTheme.colors.accent,
                onClick = {}
            )
        }
    }
}

@Composable
private fun ChromeButton(
    @DrawableRes icon: Int,
    tint: Color,
    onClick: () -> Unit
) {
    LiiveGlassPanel(
        modifier = Modifier.size(44.dp).clickableNoRipple(onClick),
        material = GlassMaterial.Thin,
        shape = LiiveRadius.full,
        padding = 0.dp
    ) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Icon(painterResource(icon), null, tint = tint, modifier = Modifier.size(19.dp))
        }
    }
}
