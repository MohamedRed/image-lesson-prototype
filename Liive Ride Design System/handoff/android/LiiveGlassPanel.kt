//  LiiveGlassPanel.kt  ·  Liive Ride DS (Compose)  ·  mirrors components/ride/GlassPanel
//  Frosted-glass panel over the map. True backdrop blur needs RenderEffect
//  (API 31+); this stub uses a translucent material color + hairline, which
//  reads correctly over a map. Add a blurred backdrop layer where supported.
package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

enum class GlassMaterial { Thin, Regular, Thick }

@Composable
fun LiiveGlassPanel(
    modifier: Modifier = Modifier,
    material: GlassMaterial = GlassMaterial.Regular,
    shape: RoundedCornerShape = LiiveRadius.lg,
    padding: Dp = 14.dp,
    content: @Composable () -> Unit
) {
    val c = LiiveTheme.colors
    val base = if (c.isDark) Color(0xFF0E1E2A) else Color.White
    val alpha = when (material) { GlassMaterial.Thin -> 0.62f; GlassMaterial.Regular -> 0.78f; GlassMaterial.Thick -> 0.9f }
    Box(
        modifier
            .clip(shape)
            .background(base.copy(alpha = alpha))
            .border(0.5.dp, c.separator, shape)
            .padding(padding)
    ) { content() }
}
