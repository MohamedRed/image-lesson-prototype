package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
fun LiiveCard(
    modifier: Modifier = Modifier,
    active: Boolean = false,
    content: @Composable ColumnScope.() -> Unit
) {
    val c = LiiveTheme.colors
    Column(
        modifier
            .clip(LiiveRadius.lg)
            .background(c.surfaceRaised)
            .border(1.5.dp, if (active) c.accent else Color.Transparent, LiiveRadius.lg)
            .padding(14.dp),
        content = content
    )
}
