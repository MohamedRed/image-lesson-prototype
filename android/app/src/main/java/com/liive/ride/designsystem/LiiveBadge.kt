//  LiiveBadge.kt  ·  Liive Ride DS (Compose)  ·  mirrors components/core/Badge
package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

enum class BadgeColor { Neutral, Accent, Success, Warning, Danger, Info }

@Composable
fun LiiveBadge(text: String, color: BadgeColor = BadgeColor.Neutral, solid: Boolean = false, dot: Boolean = false) {
    val c = LiiveTheme.colors
    val fg = when (color) {
        BadgeColor.Neutral -> c.textSecondary; BadgeColor.Accent -> c.accent
        BadgeColor.Success -> c.success; BadgeColor.Warning -> c.warning
        BadgeColor.Danger -> c.danger; BadgeColor.Info -> c.info
    }
    val solidBg = when (color) {
        BadgeColor.Neutral -> c.fill; BadgeColor.Accent -> c.accent
        BadgeColor.Success -> c.success; BadgeColor.Warning -> c.warning
        BadgeColor.Danger -> c.danger; BadgeColor.Info -> c.info
    }
    val tintBg = when (color) {
        BadgeColor.Neutral -> c.fillTertiary; BadgeColor.Accent -> c.accentTint
        BadgeColor.Success -> c.successTint; BadgeColor.Warning -> c.warningTint
        BadgeColor.Danger -> c.dangerTint; BadgeColor.Info -> c.infoTint
    }
    val onSolid = if (color == BadgeColor.Warning || color == BadgeColor.Info) Color.Black else Color.White
    val content = if (solid) onSolid else fg

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        modifier = Modifier.clip(CircleShape).background(if (solid) solidBg else tintBg)
            .padding(horizontal = 9.dp, vertical = 3.dp)
    ) {
        if (dot) Box(Modifier.size(7.dp).clip(CircleShape).background(content))
        Text(text, color = content, style = MaterialTheme.typography.labelMedium.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold))
    }
}
