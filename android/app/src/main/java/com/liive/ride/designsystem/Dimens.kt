//  Dimens.kt
//  Liive Ride — "TIDE" spacing, radii, sizing (Jetpack Compose)
package com.liive.ride.designsystem

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

object LiiveSpacing {
    val xs2 = 2.dp
    val xs = 4.dp
    val s = 8.dp
    val m = 12.dp
    val l = 16.dp           // standard screen gutter
    val xl = 20.dp
    val xxl = 24.dp
    val xxxl = 32.dp
    val huge = 40.dp
    val screenGutter = 16.dp
    val touchMin = 44.dp
}

object LiiveRadius {
    val xs = RoundedCornerShape(6.dp)
    val sm = RoundedCornerShape(8.dp)    // chips / badges
    val md = RoundedCornerShape(10.dp)   // buttons / inputs
    val lg = RoundedCornerShape(12.dp)   // cards / HUD
    val xl = RoundedCornerShape(16.dp)   // feature cards
    val xxl = RoundedCornerShape(20.dp)  // sheets
    val xxxl = RoundedCornerShape(28.dp) // large sheet top
    val full = RoundedCornerShape(999.dp)// capsule
    // Sheet (top corners only)
    val sheetTop = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
}

object LiiveControl {
    val sm = 32.dp
    val md = 44.dp
    val lg = 50.dp   // prominent CTA
    val xl = 56.dp
}

object LiiveElevation {
    val small = 2.dp
    val card = 4.dp
    val hud = 12.dp
    val sheet = 16.dp
    val sos = 18.dp
}

object LiiveMotion {
    val easeOut = CubicBezierEasing(0.16f, 1f, 0.3f, 1f)
    const val fastMs = 150
    const val baseMs = 250
    const val slowMs = 400
    const val pressScale = 0.96f
}
