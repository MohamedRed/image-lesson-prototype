package com.liive.ride.designsystem

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight

@Composable
fun LiiveFareRow(label: String, amount: String, muted: Boolean = false, total: Boolean = false) {
    val c = LiiveTheme.colors
    Row(
        Modifier
            .fillMaxWidth()
            .padding(
                top = if (total) LiiveFareRowLayout.TotalTopPadding else LiiveFareRowLayout.RowVerticalPadding,
                bottom = if (total) LiiveFareRowLayout.TotalBottomPadding else LiiveFareRowLayout.RowVerticalPadding
            ),
        horizontalArrangement = Arrangement.spacedBy(LiiveFareRowLayout.ContentGap)
    ) {
        Text(
            label,
            color = when {
                total -> c.text
                muted -> c.textTertiary
                else -> c.textSecondary
            },
            style = if (total) MaterialTheme.typography.titleLarge else MaterialTheme.typography.titleMedium,
            fontWeight = if (total) FontWeight.SemiBold else FontWeight.Normal,
            modifier = Modifier.alignByBaseline()
        )
        Spacer(Modifier.weight(1f))
        Text(
            amount,
            color = c.text,
            style = (if (total) MaterialTheme.typography.titleLarge else MaterialTheme.typography.titleMedium).tabularNumbers(),
            fontWeight = if (total) FontWeight.Bold else FontWeight.Medium,
            modifier = Modifier.alignByBaseline()
        )
    }
}

private object LiiveFareRowLayout {
    val ContentGap = LiiveSpacing.m
    val RowVerticalPadding = LiiveSpacing.s - LiiveSpacing.xs2
    val TotalTopPadding = LiiveSpacing.m
    val TotalBottomPadding = LiiveSpacing.xs2 - LiiveSpacing.xs2
}
