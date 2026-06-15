package com.liive.ride.designsystem

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun LiiveFareRow(label: String, amount: String, muted: Boolean = false, total: Boolean = false) {
    val c = LiiveTheme.colors
    Row(Modifier.fillMaxWidth().padding(vertical = 7.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(
            label,
            color = if (muted) c.textSecondary else c.text,
            style = if (total) MaterialTheme.typography.titleLarge else MaterialTheme.typography.titleMedium
        )
        Spacer(Modifier.weight(1f))
        Text(
            amount,
            color = if (total) c.text else c.textSecondary,
            style = (if (total) MaterialTheme.typography.titleLarge else MaterialTheme.typography.titleMedium).tabularNumbers(),
            fontWeight = if (total) FontWeight.Bold else FontWeight.Normal
        )
    }
}
