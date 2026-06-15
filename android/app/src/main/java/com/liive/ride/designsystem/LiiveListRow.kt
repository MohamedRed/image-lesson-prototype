package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

@Composable
fun LiiveListRow(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    value: String? = null,
    divider: Boolean = true,
    chevron: Boolean = false,
    leading: @Composable () -> Unit,
    trailing: @Composable RowScope.() -> Unit = {},
    onClick: (() -> Unit)? = null,
) {
    val c = LiiveTheme.colors
    Column(modifier.then(if (onClick != null) Modifier.clickable { onClick() } else Modifier)) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            leading()
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, color = c.text, style = MaterialTheme.typography.titleLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (subtitle != null) {
                    Text(subtitle, color = c.textSecondary, style = MaterialTheme.typography.bodySmall, maxLines = 2)
                }
            }
            if (value != null) {
                Text(value, color = c.textSecondary, style = MaterialTheme.typography.titleMedium)
            }
            trailing()
            if (chevron) {
                Icon(painterResource(RideIcons.ChevronRight), null, tint = c.textTertiary, modifier = Modifier.size(18.dp))
            }
        }
        if (divider) {
            Box(Modifier.padding(start = 60.dp).fillMaxWidth().height(0.5.dp).background(c.separator))
        }
    }
}
