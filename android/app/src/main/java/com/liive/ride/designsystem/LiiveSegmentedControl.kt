//  LiiveSegmentedControl.kt
//  Liive Ride - "TIDE" segmented control (Jetpack Compose)
package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

data class LiiveSegment<T>(
    val value: T,
    val label: String,
)

@Composable
fun <T> LiiveSegmentedControl(
    options: List<LiiveSegment<T>>,
    selected: T,
    onSelected: (T) -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LiiveTheme.colors

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(LiiveRadius.full)
            .background(c.fillTertiary)
            .padding(LiiveSpacing.xs),
    ) {
        options.forEach { option ->
            val isSelected = option.value == selected
            Text(
                text = option.label,
                color = if (isSelected) c.text else c.textSecondary,
                style = MaterialTheme.typography.titleMedium,
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 36.dp)
                    .clip(LiiveRadius.full)
                    .background(if (isSelected) c.surfaceRaised else Color.Transparent)
                    .clickable { onSelected(option.value) }
                    .padding(horizontal = LiiveSpacing.m, vertical = LiiveSpacing.s),
            )
        }
    }
}
