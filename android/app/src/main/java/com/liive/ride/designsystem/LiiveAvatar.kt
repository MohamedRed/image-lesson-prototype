//  LiiveAvatar.kt  ·  Liive Ride DS (Compose)  ·  mirrors components/core/Avatar
package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun LiiveAvatar(name: String, size: Dp = 48.dp, ring: Boolean = false, ringColor: Color? = null) {
    val c = LiiveTheme.colors
    val activeRingColor = ringColor ?: c.accent
    val initials = name.split(" ").take(2).mapNotNull { it.firstOrNull() }
        .joinToString("").uppercase().ifEmpty { "?" }
    Box(
        Modifier
            .size(size),
        contentAlignment = Alignment.Center
    ) {
        if (ring) {
            Box(Modifier.size(size + 10.dp).border(2.5.dp, activeRingColor, CircleShape))
            Box(Modifier.size(size + 5.dp).border(2.5.dp, c.surface, CircleShape))
        }
        Box(
            Modifier
                .size(size)
                .clip(CircleShape)
                .background(c.fill),
            contentAlignment = Alignment.Center
        ) {
            Text(
                initials,
                color = c.text,
                fontWeight = FontWeight.SemiBold,
                fontSize = (size.value * 0.4f).sp,
                fontFamily = SchibstedGrotesk
            )
        }
    }
}
