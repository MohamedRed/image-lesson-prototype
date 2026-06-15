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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun LiiveSosButton(size: Dp = 64.dp, showLabel: Boolean = true, onActivate: () -> Unit) {
    val c = LiiveTheme.colors
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val transition = rememberInfiniteTransition(label = "sos")
    val pulse by transition.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(1500, easing = LinearOutSlowInEasing), RepeatMode.Restart),
        label = "pulse"
    )
    Box(Modifier.size(size), contentAlignment = Alignment.Center) {
        Box(
            Modifier.matchParentSize().graphicsLayer {
                scaleX = 1f + pulse * 0.5f; scaleY = 1f + pulse * 0.5f; alpha = (1f - pulse) * 0.35f
            }.clip(CircleShape).background(c.danger)
        )
        Box(
            Modifier.matchParentSize().scale(if (pressed) 0.94f else 1f).clip(CircleShape)
                .background(c.danger)
                .clickable(interactionSource = interaction, indication = null) { onActivate() },
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("SOS", color = Color.White, fontWeight = FontWeight.Bold,
                    fontSize = (size.value * 0.28f).sp, fontFamily = SchibstedGrotesk)
                if (showLabel) Text("HELP", color = Color.White.copy(alpha = 0.9f),
                    fontWeight = FontWeight.SemiBold, fontSize = (size.value * 0.15f).sp, fontFamily = SchibstedGrotesk)
            }
        }
    }
}
