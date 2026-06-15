//  LiiveButton.kt
//  Liive Ride — sample component showing how DS tokens compose in Compose.
//  Mirror this pattern for Badge, Card, ListRow, GlassPanel, SosButton, etc.
package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.foundation.clickable
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.unit.dp

enum class LiiveButtonVariant { Primary, Secondary, Tinted, Plain, Destructive, DestructivePlain }
enum class LiiveButtonSize { Sm, Md, Lg }

@Composable
fun LiiveButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    variant: LiiveButtonVariant = LiiveButtonVariant.Primary,
    size: LiiveButtonSize = LiiveButtonSize.Md,
    capsule: Boolean = false,
    fullWidth: Boolean = false,
    tabularNumbers: Boolean = false,
) {
    val c = LiiveTheme.colors
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()

    val height = when (size) { LiiveButtonSize.Sm -> 32.dp; LiiveButtonSize.Lg -> 50.dp; else -> 44.dp }
    val bg = when (variant) {
        LiiveButtonVariant.Primary -> c.accent
        LiiveButtonVariant.Secondary -> c.fill
        LiiveButtonVariant.Tinted -> c.accentTint
        LiiveButtonVariant.Plain, LiiveButtonVariant.DestructivePlain -> Color.Transparent
        LiiveButtonVariant.Destructive -> c.danger
    }
    val fg = when (variant) {
        LiiveButtonVariant.Primary -> c.onAccent
        LiiveButtonVariant.Secondary -> c.text
        LiiveButtonVariant.Tinted, LiiveButtonVariant.Plain -> c.accent
        LiiveButtonVariant.Destructive -> Color.White
        LiiveButtonVariant.DestructivePlain -> c.danger
    }
    val shape: RoundedCornerShape = if (capsule) LiiveRadius.full else LiiveRadius.md

    Box(
        modifier = modifier
            .then(if (fullWidth) Modifier.fillMaxWidth() else Modifier)
            .height(height)
            .scale(if (pressed) LiiveMotion.pressScale else 1f)
            .alpha(if (pressed) 0.85f else 1f)
            .clip(shape)
            .background(bg)
            .clickable(interactionSource = interaction, indication = null) { onClick() }
            .padding(horizontal = if (size == LiiveButtonSize.Lg) 22.dp else 18.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = title,
            color = fg,
            style = if (tabularNumbers) MaterialTheme.typography.titleLarge.tabularNumbers() else MaterialTheme.typography.titleLarge,
            textAlign = TextAlign.Center,
        )
    }
}
