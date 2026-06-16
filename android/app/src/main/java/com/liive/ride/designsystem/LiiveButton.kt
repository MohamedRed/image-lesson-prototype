//  LiiveButton.kt
//  Liive Ride — sample component showing how DS tokens compose in Compose.
//  Mirror this pattern for Badge, Card, ListRow, GlassPanel, SosButton, etc.
package com.liive.ride.designsystem

import androidx.annotation.DrawableRes
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
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
    @DrawableRes icon: Int? = null,
    @DrawableRes iconRight: Int? = null,
    disabled: Boolean = false,
    loading: Boolean = false,
) {
    val c = LiiveTheme.colors
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val enabled = !disabled && !loading

    val height = when (size) { LiiveButtonSize.Sm -> 32.dp; LiiveButtonSize.Lg -> 50.dp; else -> 44.dp }
    val bgPressed = when (variant) {
        LiiveButtonVariant.Primary -> c.accentPressed
        LiiveButtonVariant.Secondary -> c.fillSecondary
        LiiveButtonVariant.Tinted -> c.accentTint
        LiiveButtonVariant.Plain, LiiveButtonVariant.DestructivePlain -> Color.Transparent
        LiiveButtonVariant.Destructive -> c.danger
    }
    val bg = if (enabled && pressed) {
        bgPressed
    } else {
        when (variant) {
            LiiveButtonVariant.Primary -> c.accent
            LiiveButtonVariant.Secondary -> c.fill
            LiiveButtonVariant.Tinted -> c.accentTint
            LiiveButtonVariant.Plain, LiiveButtonVariant.DestructivePlain -> Color.Transparent
            LiiveButtonVariant.Destructive -> c.danger
        }
    }
    val fg = when (variant) {
        LiiveButtonVariant.Primary -> c.onAccent
        LiiveButtonVariant.Secondary -> c.text
        LiiveButtonVariant.Tinted, LiiveButtonVariant.Plain -> c.accent
        LiiveButtonVariant.Destructive -> Color.White
        LiiveButtonVariant.DestructivePlain -> c.danger
    }
    val shape: RoundedCornerShape = if (capsule) LiiveRadius.full else LiiveRadius.md
    val opacity = when {
        disabled -> 0.4f
        enabled && pressed && variant in setOf(
            LiiveButtonVariant.Plain,
            LiiveButtonVariant.Tinted,
            LiiveButtonVariant.DestructivePlain
        ) -> 0.5f
        enabled && pressed -> 0.85f
        else -> 1f
    }

    Box(
        modifier = modifier
            .then(if (fullWidth) Modifier.fillMaxWidth() else Modifier)
            .height(height)
            .scale(if (enabled && pressed) LiiveMotion.pressScale else 1f)
            .alpha(opacity)
            .clip(shape)
            .background(bg)
            .clickable(interactionSource = interaction, indication = null, enabled = enabled) { onClick() }
            .padding(horizontal = if (size == LiiveButtonSize.Lg) 22.dp else 18.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) {
            CircularProgressIndicator(
                color = fg,
                strokeWidth = 2.dp,
                modifier = Modifier.size(18.dp)
            )
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (icon != null) Icon(painterResource(icon), null, tint = fg, modifier = Modifier.size(18.dp))
                Text(
                    text = title,
                    color = fg,
                    style = if (tabularNumbers) MaterialTheme.typography.titleLarge.tabularNumbers() else MaterialTheme.typography.titleLarge,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (iconRight != null) Icon(painterResource(iconRight), null, tint = fg, modifier = Modifier.size(18.dp))
            }
        }
    }
}
