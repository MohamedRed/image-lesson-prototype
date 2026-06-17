package com.liive.ride.designsystem

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color

@Composable
fun LiiveSwitch(
    checked: Boolean,
    disabled: Boolean = false,
    onCheckedChange: (Boolean) -> Unit
) {
    val c = LiiveTheme.colors
    val trackColor by animateColorAsState(
        targetValue = if (checked) c.success else c.fill,
        animationSpec = tween(durationMillis = LiiveMotion.baseMs, easing = LiiveMotion.easeOut),
        label = "LiiveSwitchTrackColor"
    )
    val thumbOffset by animateDpAsState(
        targetValue = if (checked) LiiveSwitchLayout.ThumbTravel else LiiveSwitchLayout.ThumbRestOffset,
        animationSpec = tween(durationMillis = LiiveMotion.baseMs, easing = LiiveMotion.easeOut),
        label = "LiiveSwitchThumbOffset"
    )

    Box(
        Modifier
            .size(width = LiiveSwitchLayout.TrackWidth, height = LiiveSwitchLayout.TrackHeight)
            .alpha(if (disabled) LiiveSwitchLayout.DisabledOpacity else LiiveSwitchLayout.EnabledOpacity)
            .clip(LiiveRadius.full)
            .background(trackColor)
            .clickable(
                enabled = !disabled,
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onCheckedChange(!checked) }
            .padding(LiiveSwitchLayout.TrackPadding),
        contentAlignment = Alignment.CenterStart
    ) {
        Box(
            Modifier
                .offset(x = thumbOffset)
                .size(LiiveSwitchLayout.ThumbSize)
                .shadow(LiiveSwitchLayout.ThumbShadowRadius, CircleShape)
                .clip(CircleShape)
                .background(LiiveSwitchLayout.ThumbColor)
        )
    }
}

private object LiiveSwitchLayout {
    val TrackWidth = LiiveControl.lg + LiiveSpacing.xs2 / 2
    val TrackHeight = LiiveSpacing.xxxl - LiiveSpacing.xs2 / 2
    val TrackPadding = LiiveSpacing.xs2
    val ThumbSize = TrackHeight - TrackPadding - TrackPadding
    val ThumbRestOffset = LiiveSpacing.xs2 - LiiveSpacing.xs2
    val ThumbTravel = TrackWidth - ThumbSize - TrackPadding - TrackPadding
    val ThumbShadowRadius = LiiveSpacing.xs
    val ThumbColor = Color.White
    const val DisabledOpacity = 0.5f
    const val EnabledOpacity = 1f
}
