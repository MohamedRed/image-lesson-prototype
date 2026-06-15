//  Theme.kt
//  Liive Ride — "TIDE" theme provider (Jetpack Compose)
//  Exposes LiiveColors via CompositionLocal. Dark-first.
package com.liive.ride.designsystem

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf

val LocalLiiveColors = staticCompositionLocalOf { LiiveDarkColors }

/** Access tokens anywhere: `LiiveTheme.colors.accent`. */
object LiiveTheme {
    val colors: LiiveColors
        @Composable get() = LocalLiiveColors.current
}

@Composable
fun LiiveTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colors = if (darkTheme) LiiveDarkColors else LiiveLightColors

    // Bridge a few tokens into Material3 so stock components stay on-brand.
    val m3 = if (darkTheme)
        darkColorScheme(
            primary = colors.accent, onPrimary = colors.onAccent,
            background = colors.bg, surface = colors.surface,
            error = colors.danger, onBackground = colors.text, onSurface = colors.text,
        )
    else
        lightColorScheme(
            primary = colors.accent, onPrimary = colors.onAccent,
            background = colors.bg, surface = colors.surface,
            error = colors.danger, onBackground = colors.text, onSurface = colors.text,
        )

    CompositionLocalProvider(LocalLiiveColors provides colors) {
        MaterialTheme(colorScheme = m3, typography = LiiveType, content = content)
    }
}
