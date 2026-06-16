//  LiiveGlassPanel.kt  ·  Liive Ride DS (Compose)  ·  mirrors components/ride/GlassPanel
//  Frosted material panel over the live map for HUD chips and voice controls.
package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
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
    val materialColor = when (material) {
        GlassMaterial.Thin -> c.materialThin
        GlassMaterial.Regular -> c.materialRegular
        GlassMaterial.Thick -> c.materialThick
    }

    Box(
        modifier
            .shadow(LiiveElevation.hud, shape, clip = false)
            .clip(shape)
            .background(materialColor)
            .border(0.5.dp, c.borderStrong, shape)
            .padding(padding)
    ) { content() }
}
