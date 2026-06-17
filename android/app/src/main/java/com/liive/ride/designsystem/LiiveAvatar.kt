//  LiiveAvatar.kt  ·  Liive Ride DS (Compose)  ·  mirrors components/core/Avatar
package com.liive.ride.designsystem

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.sp

@Composable
fun LiiveAvatar(
    name: String,
    size: Dp = LiiveControl.md + LiiveSpacing.xs,
    ring: Boolean = false,
    ringColor: Color? = null,
    image: Painter? = null
) {
    val c = LiiveTheme.colors
    val activeRingColor = ringColor ?: c.accent
    val initials = name.split(" ")
        .take(LiiveAvatarLayout.MaxInitialWords)
        .mapNotNull { it.firstOrNull() }
        .joinToString("")
        .uppercase()
        .ifEmpty { LiiveAvatarLayout.FallbackInitial }
    Box(
        Modifier
            .size(size),
        contentAlignment = Alignment.Center
    ) {
        if (ring) {
            Box(
                Modifier
                    .size(size + LiiveAvatarLayout.RingStrokeWidth * LiiveAvatarLayout.OuterRingSizeMultiplier)
                    .border(LiiveAvatarLayout.RingStrokeWidth, activeRingColor, CircleShape)
            )
            Box(
                Modifier
                    .size(size + LiiveAvatarLayout.RingStrokeWidth * LiiveAvatarLayout.InnerRingSizeMultiplier)
                    .border(LiiveAvatarLayout.RingStrokeWidth, c.surface, CircleShape)
            )
        }
        Box(
            Modifier
                .size(size)
                .clip(CircleShape)
                .background(c.fill),
            contentAlignment = Alignment.Center
        ) {
            if (image != null) {
                Image(
                    painter = image,
                    contentDescription = name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                Text(
                    initials,
                    color = c.text,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = (size.value * LiiveAvatarLayout.InitialsScale).sp,
                    fontFamily = SchibstedGrotesk
                )
            }
        }
    }
}

private object LiiveAvatarLayout {
    const val MaxInitialWords = 2
    const val FallbackInitial = "?"
    const val InitialsScale = 0.4f
    val RingStrokeWidth = LiiveSpacing.xs2 + LiiveSpacing.xs2 / 4
    const val InnerRingSizeMultiplier = 2
    const val OuterRingSizeMultiplier = 4
}
