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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.liive.ride.designsystem.*
import com.liive.ride.ui.*

@Composable
fun RideApp(viewModel: RideViewModel, darkTheme: Boolean = true) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    RideAppContent(
        state = state,
        onEvent = viewModel::onEvent,
        darkTheme = darkTheme
    )
}

@Composable
internal fun RideAppContent(
    state: RideUiState,
    onEvent: (RideEvent) -> Unit,
    darkTheme: Boolean = true
) {
    LiiveTheme(darkTheme = darkTheme) {
        Box(
            Modifier
                .fillMaxSize()
                .background(LiiveTheme.colors.bg)
                .testTag(RideTestTags.Root)
        ) {
            RideMapCanvas(
                phase = state.phase,
                isMultiLeg = state.config.tier.multiLeg,
                carProgress = state.carProgress,
                destinationName = state.config.destinationName,
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
                onToggleMic = { onEvent(RideEvent.ToggleMic) }
            )

            if (state.phase == RidePhase.Matching || state.phase == RidePhase.Enroute) {
                LiiveSosButton(
                    size = RideChromeLayout.sosSize,
                    showLabel = false,
                    onActivate = { onEvent(RideEvent.PresentSOS(true)) },
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = RideChromeLayout.sosTopInset, end = RideChromeLayout.sosEndPadding)
                        .testTag(RideTestTags.SosButton)
                )
            }

            Box(Modifier.align(Alignment.BottomCenter)) {
                when (state.phase) {
                    RidePhase.Destination -> RideDestinationSheet(onEvent)
                    RidePhase.Options -> RideOptionsSheet(state, onEvent)
                    RidePhase.Matching -> RideMatchingSheet(state, onEvent)
                    RidePhase.Enroute -> RideEnrouteSheet(state, onEvent)
                    RidePhase.Complete -> RideCompleteSheet(state, onEvent)
                }
            }

            if (state.sosPresented) {
                RideSOSConfirmation(
                    onEmergency = { onEvent(RideEvent.PresentSOS(false)) },
                    onCancel = { onEvent(RideEvent.PresentSOS(false)) }
                )
            }
        }
    }
}

@Composable
private fun RideTopChrome(state: RideUiState, onToggleMic: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(
                top = RideChromeLayout.topInset,
                start = RideChromeLayout.horizontalPadding,
                end = RideChromeLayout.horizontalPadding
            )
            .testTag(RideTestTags.TopChrome),
        verticalAlignment = Alignment.Top
    ) {
        if (state.phase == RidePhase.Enroute) {
            LiiveGlassPanel(material = GlassMaterial.Thin, shape = LiiveRadius.full, padding = RideChromeLayout.glassPanelPadding) {
                Box(
                    Modifier.padding(
                        horizontal = RideChromeLayout.badgeHorizontalPadding,
                        vertical = RideChromeLayout.badgeVerticalPadding
                    )
                ) {
                    LiiveBadge("Voice connected", BadgeColor.Success, dot = true)
                }
            }
        } else {
            Spacer(Modifier.size(RideChromeLayout.placeholderSize))
        }

        Spacer(Modifier.weight(1f))
        Row(horizontalArrangement = Arrangement.spacedBy(RideChromeLayout.buttonSpacing)) {
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
        modifier = Modifier.size(RideChromeLayout.buttonSize).clickableNoRipple(onClick),
        material = GlassMaterial.Thin,
        shape = LiiveRadius.full,
        padding = RideChromeLayout.glassPanelPadding
    ) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Icon(painterResource(icon), null, tint = tint, modifier = Modifier.size(RideChromeLayout.buttonIconSize))
        }
    }
}
