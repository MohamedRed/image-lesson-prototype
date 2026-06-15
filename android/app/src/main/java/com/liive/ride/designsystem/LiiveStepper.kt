package com.liive.ride.designsystem

import androidx.annotation.DrawableRes
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp

@Composable
fun LiiveStepper(value: Int, range: IntRange, onChange: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        StepperControl(RideIcons.Remove, enabled = value > range.first) { onChange((value - 1).coerceAtLeast(range.first)) }
        Text(value.toString(), color = LiiveTheme.colors.text, style = MaterialTheme.typography.titleLarge, modifier = Modifier.width(20.dp))
        StepperControl(RideIcons.Add, enabled = value < range.last) { onChange((value + 1).coerceAtMost(range.last)) }
    }
}

@Composable
private fun StepperControl(@DrawableRes icon: Int, enabled: Boolean, onClick: () -> Unit) {
    val c = LiiveTheme.colors
    Box(
        Modifier.size(30.dp).clip(CircleShape).background(if (enabled) c.fill else c.fillTertiary)
            .clickable(enabled = enabled) { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Icon(painterResource(icon), null, tint = if (enabled) c.text else c.textQuaternary, modifier = Modifier.size(16.dp))
    }
}
