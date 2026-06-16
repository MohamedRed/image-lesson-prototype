//  Color.kt
//  Liive Ride — "TIDE" brand color tokens (Jetpack Compose)
//  Generated from the Liive Ride Design System (semantic.css).
package com.liive.ride.designsystem

import androidx.compose.ui.graphics.Color

// ── Raw palette ────────────────────────────────────────────────
// Ink scale
val Ink950 = Color(0xFF07121A)
val Ink900 = Color(0xFF0A1822)
val Ink850 = Color(0xFF0C1E2A)
val Ink800 = Color(0xFF0E1E2A)
val Ink700 = Color(0xFF15293A)
val Ink600 = Color(0xFF1E3548)
val Ink500 = Color(0xFF2C4456)
val Ink400 = Color(0xFF3D586C)
// Aqua ramp
val Aqua300 = Color(0xFF9FF1E0)
val Aqua400 = Color(0xFF7FECD6)
val Aqua500 = Color(0xFF54E0C6)
val Aqua600 = Color(0xFF2EC9AD)
val Aqua700 = Color(0xFF17A98F)
// Status hues
val Mint500 = Color(0xFF2FD08A)
val Amber500 = Color(0xFFF5B83D)
val AmberStar = Color(0xFFF5C24B)
val Coral500 = Color(0xFFFF5A5F)
// Paper (light)
val Paper0 = Color(0xFFFFFFFF)
val Paper50 = Color(0xFFF4F8F8)
val Paper100 = Color(0xFFEEF3F4)
val Paper200 = Color(0xFFE2EAEC)
val Ice0 = Color(0xFFEAF4F4)

/** Semantic token set — resolved per theme (see Theme.kt). */
data class LiiveColors(
    val accent: Color, val accentPressed: Color, val accentBright: Color,
    val accentTint: Color, val onAccent: Color,
    val success: Color, val successTint: Color,
    val warning: Color, val warningTint: Color,
    val danger: Color, val dangerTint: Color,
    val info: Color, val star: Color,
    val bg: Color, val surface: Color, val surfaceRaised: Color, val surfaceSheet: Color,
    val fill: Color, val fillSecondary: Color, val fillTertiary: Color, val fillQuaternary: Color,
    val text: Color, val textSecondary: Color, val textTertiary: Color, val textQuaternary: Color,
    val separator: Color, val borderStrong: Color,
    val materialThin: Color, val materialRegular: Color, val materialThick: Color,
    val mapBackground: Color, val mapRoad: Color, val mapWater: Color,
    val mapPark: Color, val mapDistrict: Color, val mapRoute: Color, val mapRouteWalk: Color,
    val isDark: Boolean,
)

val LiiveDarkColors = LiiveColors(
    accent = Aqua500, accentPressed = Aqua600, accentBright = Aqua400,
    accentTint = Aqua500.copy(alpha = 0.15f), onAccent = Color(0xFF04161A),
    success = Mint500, successTint = Mint500.copy(alpha = 0.16f),
    warning = Amber500, warningTint = Amber500.copy(alpha = 0.16f),
    danger = Coral500, dangerTint = Coral500.copy(alpha = 0.16f),
    info = Aqua400, star = AmberStar,
    bg = Ink950, surface = Ink800, surfaceRaised = Ink700, surfaceSheet = Ink850,
    fill = Color(0xFF78A0AF).copy(alpha = 0.20f),
    fillSecondary = Color(0xFF78A0AF).copy(alpha = 0.16f),
    fillTertiary = Color(0xFF78A0AF).copy(alpha = 0.12f),
    fillQuaternary = Color(0xFF78A0AF).copy(alpha = 0.08f),
    text = Ice0,
    textSecondary = Ice0.copy(alpha = 0.58f),
    textTertiary = Ice0.copy(alpha = 0.32f),
    textQuaternary = Ice0.copy(alpha = 0.18f),
    separator = Color(0xFF78AAB9).copy(alpha = 0.18f),
    borderStrong = Paper0.copy(alpha = 0.10f),
    materialThin = Ink800.copy(alpha = 0.55f),
    materialRegular = Ink900.copy(alpha = 0.70f),
    materialThick = Color(0xFF08121A).copy(alpha = 0.86f),
    mapBackground = Ink900, mapRoad = Ink700, mapWater = Color(0xFF0C2230),
    mapPark = Color(0xFF222A22), mapDistrict = Color(0xFF2A2722),
    mapRoute = Aqua500, mapRouteWalk = Amber500,
    isDark = true,
)

val LiiveLightColors = LiiveColors(
    accent = Aqua700, accentPressed = Color(0xFF0E8E78), accentBright = Aqua600,
    accentTint = Aqua700.copy(alpha = 0.12f), onAccent = Color(0xFFFFFFFF),
    success = Color(0xFF16A36B), successTint = Color(0xFF16A36B).copy(alpha = 0.12f),
    warning = Color(0xFFD99412), warningTint = Color(0xFFD99412).copy(alpha = 0.14f),
    danger = Color(0xFFE5484D), dangerTint = Color(0xFFE5484D).copy(alpha = 0.12f),
    info = Aqua700, star = Color(0xFFE0A41F),
    bg = Paper100, surface = Paper0, surfaceRaised = Paper0, surfaceSheet = Paper0,
    fill = Color(0xFF466E7D).copy(alpha = 0.14f),
    fillSecondary = Color(0xFF466E7D).copy(alpha = 0.11f),
    fillTertiary = Color(0xFF466E7D).copy(alpha = 0.08f),
    fillQuaternary = Color(0xFF466E7D).copy(alpha = 0.05f),
    text = Ink950,
    textSecondary = Ink950.copy(alpha = 0.58f),
    textTertiary = Ink950.copy(alpha = 0.32f),
    textQuaternary = Ink950.copy(alpha = 0.20f),
    separator = Ink950.copy(alpha = 0.12f),
    borderStrong = Ink950.copy(alpha = 0.10f),
    materialThin = Paper50.copy(alpha = 0.70f),
    materialRegular = Paper0.copy(alpha = 0.80f),
    materialThick = Paper0.copy(alpha = 0.92f),
    mapBackground = Color(0xFFDCE7E8), mapRoad = Paper0, mapWater = Color(0xFFB6D9DC),
    mapPark = Color(0xFFD7E6D4), mapDistrict = Color(0xFFE6DED4),
    mapRoute = Aqua700, mapRouteWalk = Color(0xFFD99412),
    isDark = false,
)
