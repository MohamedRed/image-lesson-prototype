//  LiiveButton.kt
//  Liive Ride — sample component showing how DS tokens compose in Compose.
//  Mirror this pattern for Badge, Card, ListRow, GlassPanel, SosButton, etc.
package com.liive.ride.designsystem

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
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
import androidx.compose.ui.text.font.FontWeight
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
    iconOnly: Boolean = false,
    contentDescription: String? = null,
    disabled: Boolean = false,
    loading: Boolean = false,
) {
    val c = LiiveTheme.colors
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val enabled = !disabled && !loading

    val height = when (size) { LiiveButtonSize.Sm -> 32.dp; LiiveButtonSize.Lg -> 50.dp; else -> 44.dp }
    val horizontalPadding = when (size) {
        LiiveButtonSize.Sm -> 14.dp
        LiiveButtonSize.Md -> 18.dp
        LiiveButtonSize.Lg -> 22.dp
    }
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
    val labelWeight = when (variant) {
        LiiveButtonVariant.Plain, LiiveButtonVariant.DestructivePlain -> FontWeight.Normal
        else -> FontWeight.SemiBold
    }
    val labelStyle = (if (size == LiiveButtonSize.Sm) {
        MaterialTheme.typography.titleMedium
    } else {
        MaterialTheme.typography.titleLarge
    }).copy(
        fontWeight = labelWeight,
        letterSpacing = MaterialTheme.typography.headlineSmall.letterSpacing
    ).let { style ->
        if (tabularNumbers) style.tabularNumbers() else style
    }
    val shape: RoundedCornerShape = if (capsule) LiiveRadius.full else LiiveRadius.md
    val targetOpacity = when {
        disabled -> 0.4f
        enabled && pressed && variant in setOf(
            LiiveButtonVariant.Plain,
            LiiveButtonVariant.Tinted,
            LiiveButtonVariant.DestructivePlain
        ) -> 0.5f
        enabled && pressed -> 0.85f
        else -> 1f
    }
    val motionSpec = tween<Float>(durationMillis = LiiveMotion.fastMs, easing = LiiveMotion.easeOut)
    val animatedScale by animateFloatAsState(
        targetValue = if (enabled && pressed) LiiveMotion.pressScale else 1f,
        animationSpec = motionSpec,
        label = "LiiveButtonScale"
    )
    val animatedOpacity by animateFloatAsState(
        targetValue = targetOpacity,
        animationSpec = motionSpec,
        label = "LiiveButtonOpacity"
    )
    val animatedBackground by animateColorAsState(
        targetValue = bg,
        animationSpec = tween(durationMillis = LiiveMotion.fastMs, easing = LiiveMotion.easeOut),
        label = "LiiveButtonBackground"
    )

    Box(
        modifier = modifier
            .then(
                when {
                    fullWidth -> Modifier.fillMaxWidth()
                    iconOnly -> Modifier.width(height)
                    else -> Modifier
                }
            )
            .height(height)
            .scale(animatedScale)
            .alpha(animatedOpacity)
            .clip(shape)
            .background(animatedBackground)
            .clickable(interactionSource = interaction, indication = null, enabled = enabled) { onClick() }
            .padding(horizontal = if (iconOnly) 0.dp else horizontalPadding),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) {
            CircularProgressIndicator(
                color = fg,
                strokeWidth = 2.dp,
                modifier = Modifier.size(18.dp)
            )
        } else if (iconOnly && icon != null) {
            Icon(painterResource(icon), contentDescription, tint = fg, modifier = Modifier.size(18.dp))
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (icon != null) Icon(painterResource(icon), null, tint = fg, modifier = Modifier.size(18.dp))
                Text(
                    text = title,
                    color = fg,
                    style = labelStyle,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (iconRight != null) Icon(painterResource(iconRight), null, tint = fg, modifier = Modifier.size(18.dp))
            }
        }
    }
}
