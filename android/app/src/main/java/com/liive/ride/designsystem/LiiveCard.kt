package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp

@Composable
fun LiiveCard(
    modifier: Modifier = Modifier,
    active: Boolean = false,
    raised: Boolean = false,
    padding: Dp = LiiveCardLayout.Padding,
    content: @Composable ColumnScope.() -> Unit
) {
    val c = LiiveTheme.colors
    Column(
        modifier
            .shadow(if (active) LiiveCardLayout.ActiveElevation else LiiveElevation.card, LiiveRadius.lg)
            .clip(LiiveRadius.lg)
            .background(if (raised) c.surfaceRaised else c.surface)
            .border(LiiveCardLayout.StrokeWidth, if (active) c.accent else Color.Transparent, LiiveRadius.lg)
            .padding(padding),
        content = content
    )
}

private object LiiveCardLayout {
    val Padding = LiiveSpacing.l
    val StrokeWidth = LiiveSpacing.xs2 - LiiveSpacing.xs2 / 4
    val ActiveElevation = LiiveSpacing.xs2 - LiiveSpacing.xs2
}
