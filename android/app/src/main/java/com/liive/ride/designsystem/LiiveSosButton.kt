//  LiiveSosButton.kt  ·  Liive Ride DS (Compose)  ·  mirrors components/ride/SOSButton
//  Coral disc + continuous pulse halo + press-shrink. onActivate should show a
//  confirm dialog before contacting emergency services.
package com.liive.ride.designsystem

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.sp

@Composable
fun LiiveSosButton(
    size: Dp = LiiveControl.xl + LiiveSpacing.s,
    showLabel: Boolean = true,
    modifier: Modifier = Modifier,
    onActivate: () -> Unit
) {
    val c = LiiveTheme.colors
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val pressScale by animateFloatAsState(
        targetValue = if (pressed) LiiveSosButtonLayout.PressedScale else LiiveSosButtonLayout.RestingScale,
        animationSpec = tween(durationMillis = LiiveMotion.fastMs, easing = LiiveMotion.easeOut),
        label = "LiiveSosButtonPressScale"
    )
    val transition = rememberInfiniteTransition(label = "sos")
    val pulse by transition.animateFloat(
        initialValue = LiiveSosButtonLayout.PulseStart,
        targetValue = LiiveSosButtonLayout.PulseEnd,
        animationSpec = infiniteRepeatable(
            tween(LiiveSosButtonLayout.PulseDurationMs, easing = LiiveMotion.easeOut),
            RepeatMode.Restart
        ),
        label = "pulse"
    )
    Box(
        modifier
            .size(size)
            .semantics { contentDescription = "Emergency SOS" },
        contentAlignment = Alignment.Center
    ) {
        Box(
            Modifier.matchParentSize().graphicsLayer {
                val pulseScale = LiiveSosButtonLayout.RestingScale + pulse * LiiveSosButtonLayout.PulseScaleDelta
                scaleX = pulseScale
                scaleY = pulseScale
                alpha = (LiiveSosButtonLayout.PulseEnd - pulse) * LiiveSosButtonLayout.PulseStartOpacity
            }.clip(CircleShape).background(c.danger)
        )
        Box(
            Modifier.matchParentSize().scale(pressScale)
                .shadow(
                    elevation = LiiveElevation.sos,
                    shape = CircleShape,
                    clip = false,
                    ambientColor = c.danger.copy(alpha = LiiveSosButtonLayout.ShadowColorAlpha),
                    spotColor = c.danger.copy(alpha = LiiveSosButtonLayout.ShadowColorAlpha),
                )
                .clip(CircleShape)
                .background(c.danger)
                .clickable(interactionSource = interaction, indication = null) { onActivate() },
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(LiiveSosButtonLayout.LabelGap)
            ) {
                Text(
                    "SOS",
                    color = LiiveSosButtonLayout.ForegroundColor,
                    fontWeight = FontWeight.Bold,
                    fontSize = (size.value * LiiveSosButtonLayout.SosTextScale).sp,
                    fontFamily = SchibstedGrotesk
                )
                if (showLabel) {
                    Text(
                        "HELP",
                        color = LiiveSosButtonLayout.ForegroundColor.copy(alpha = LiiveSosButtonLayout.HelpTextOpacity),
                        fontWeight = FontWeight.SemiBold,
                        fontSize = (size.value * LiiveSosButtonLayout.HelpTextScale).sp,
                        fontFamily = SchibstedGrotesk,
                        letterSpacing = LiiveSosButtonLayout.HelpLetterSpacing
                    )
                }
            }
        }
    }
}

private object LiiveSosButtonLayout {
    val LabelGap = LiiveSpacing.xs2 / 2
    const val RestingScale = 1f
    const val PressedScale = 0.94f
    const val PulseStart = 0f
    const val PulseEnd = 1f
    const val PulseScaleDelta = 0.5f
    const val PulseStartOpacity = 0.35f
    const val PulseDurationMs = LiiveMotion.slowMs + LiiveMotion.slowMs + LiiveMotion.slowMs +
        LiiveMotion.baseMs + LiiveMotion.fastMs
    const val SosTextScale = 0.28f
    const val HelpTextScale = 0.15f
    const val HelpTextOpacity = 0.9f
    const val ShadowColorAlpha = 0.45f
    val HelpLetterSpacing = (LiiveSpacing.xs2.value / 4).sp
    val ForegroundColor = Color.White
}
