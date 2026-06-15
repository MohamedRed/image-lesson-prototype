//  Type.kt
//  Liive Ride — "TIDE" typography (Jetpack Compose)
//  Typeface: Schibsted Grotesk. Easiest path on Android is Downloadable
//  Fonts via the Google Fonts provider (Schibsted Grotesk is available),
//  or bundle the TTFs in res/font.
package com.liive.ride.designsystem

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.googlefonts.GoogleFont
import androidx.compose.ui.text.googlefonts.Font as GoogleFontFont
import androidx.compose.ui.unit.sp

// --- Downloadable Google Font setup ---
// Add the certs provider in res/values/font_certs.xml, then:
val LiiveFontProvider = GoogleFont.Provider(
    providerAuthority = "com.google.android.gms.fonts",
    providerPackage = "com.google.android.gms",
    certificates = androidx.compose.ui.R.array.com_google_android_gms_fonts_certs
)
private val SchibstedGoogle = GoogleFont("Schibsted Grotesk")

val SchibstedGrotesk = FontFamily(
    GoogleFontFont(googleFont = SchibstedGoogle, fontProvider = LiiveFontProvider, weight = FontWeight.Normal),
    GoogleFontFont(googleFont = SchibstedGoogle, fontProvider = LiiveFontProvider, weight = FontWeight.Medium),
    GoogleFontFont(googleFont = SchibstedGoogle, fontProvider = LiiveFontProvider, weight = FontWeight.SemiBold),
    GoogleFontFont(googleFont = SchibstedGoogle, fontProvider = LiiveFontProvider, weight = FontWeight.Bold),
)
// If bundling TTFs instead, replace the family above with:
// val SchibstedGrotesk = FontFamily(
//     Font(R.font.schibsted_grotesk_regular, FontWeight.Normal),
//     Font(R.font.schibsted_grotesk_medium, FontWeight.Medium),
//     Font(R.font.schibsted_grotesk_semibold, FontWeight.SemiBold),
//     Font(R.font.schibsted_grotesk_bold, FontWeight.Bold),
// )

private fun sg(size: Int, line: Int, weight: FontWeight, tracking: Double) = TextStyle(
    fontFamily = SchibstedGrotesk,
    fontWeight = weight,
    fontSize = size.sp,
    lineHeight = line.sp,
    letterSpacing = tracking.sp,
)

// iOS-derived scale (size / line / tracking in pt). Material3 slot mapping:
val LiiveType = Typography(
    displayLarge   = sg(34, 40, FontWeight.Bold, -0.8),   // Large Title
    headlineLarge  = sg(28, 34, FontWeight.Bold, -0.6),   // Title 1
    headlineMedium = sg(22, 28, FontWeight.Bold, -0.5),   // Title 2
    headlineSmall  = sg(20, 25, FontWeight.SemiBold, -0.4),// Title 3
    titleLarge     = sg(17, 22, FontWeight.SemiBold, -0.3),// Headline
    bodyLarge      = sg(17, 22, FontWeight.Normal, -0.2),  // Body
    bodyMedium     = sg(16, 21, FontWeight.Normal, -0.31), // Callout
    titleMedium    = sg(15, 20, FontWeight.Normal, -0.23), // Subhead
    bodySmall      = sg(13, 18, FontWeight.Normal, -0.08), // Footnote
    labelMedium    = sg(12, 16, FontWeight.Normal, 0.0),   // Caption 1
    labelSmall     = sg(11, 13, FontWeight.Normal, 0.06),  // Caption 2
)
