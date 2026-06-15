//  LiiveIconCircle.kt  ·  Liive Ride DS (Compose)  ·  mirrors components/core/IconCircle
package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

enum class IconCircleColor { Accent, Success, Warning, Danger, Info, Neutral }

@Composable
fun LiiveIconCircle(
    icon: ImageVector,
    color: IconCircleColor = IconCircleColor.Accent,
    size: Dp = 44.dp,
    filled: Boolean = false,
) {
    val c = LiiveTheme.colors
    val fg = when (color) {
        IconCircleColor.Accent -> c.accent; IconCircleColor.Success -> c.success
        IconCircleColor.Warning -> c.warning; IconCircleColor.Danger -> c.danger
        IconCircleColor.Info -> c.info; IconCircleColor.Neutral -> c.textSecondary
    }
    val solid = when (color) {
        IconCircleColor.Accent -> c.accent; IconCircleColor.Success -> c.success
        IconCircleColor.Warning -> c.warning; IconCircleColor.Danger -> c.danger
        IconCircleColor.Info -> c.info; IconCircleColor.Neutral -> c.fill
    }
    val tint = when (color) {
        IconCircleColor.Accent -> c.accentTint; IconCircleColor.Success -> c.successTint
        IconCircleColor.Warning -> c.warningTint; IconCircleColor.Danger -> c.dangerTint
        IconCircleColor.Info -> c.info.copy(alpha = 0.15f); IconCircleColor.Neutral -> c.fillTertiary
    }
    Box(
        Modifier.size(size).clip(CircleShape).background(if (filled) solid else tint),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, contentDescription = null, tint = if (filled) Color.White else fg,
            modifier = Modifier.size(size * 0.45f))
    }
}
