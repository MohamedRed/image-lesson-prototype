package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp

@Composable
fun LiiveStepper(value: Int, range: IntRange, onChange: (Int) -> Unit) {
    val c = LiiveTheme.colors
    Row(
        Modifier
            .clip(LiiveRadius.sm)
            .background(c.fillTertiary),
        verticalAlignment = Alignment.CenterVertically
    ) {
        StepperControl("-", enabled = value > range.first) { onChange((value - 1).coerceAtLeast(range.first)) }
        Box(Modifier.width(1.dp).height(18.dp).background(c.separator))
        StepperControl("+", enabled = value < range.last) { onChange((value + 1).coerceAtMost(range.last)) }
    }
}

@Composable
private fun StepperControl(label: String, enabled: Boolean, onClick: () -> Unit) {
    val c = LiiveTheme.colors
    Box(
        Modifier.size(width = 44.dp, height = 32.dp)
            .clickable(enabled = enabled) { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text(
            label,
            color = if (enabled) c.text else c.textQuaternary,
            style = MaterialTheme.typography.titleLarge
        )
    }
}
