package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
fun LiiveSwitch(
    checked: Boolean,
    disabled: Boolean = false,
    onCheckedChange: (Boolean) -> Unit
) {
    val c = LiiveTheme.colors
    Box(
        Modifier
            .size(width = 51.dp, height = 31.dp)
            .alpha(if (disabled) 0.5f else 1f)
            .clip(LiiveRadius.full)
            .background(if (checked) c.success else c.fill)
            .clickable(
                enabled = !disabled,
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onCheckedChange(!checked) }
            .padding(2.dp),
        contentAlignment = Alignment.CenterStart
    ) {
        Box(
            Modifier
                .offset(x = if (checked) 20.dp else 0.dp)
                .size(27.dp)
                .shadow(4.dp, CircleShape)
                .clip(CircleShape)
                .background(Color.White)
        )
    }
}
