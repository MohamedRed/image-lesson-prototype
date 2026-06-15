package com.liive.ride.designsystem

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

@Composable
fun LiiveCard(
    modifier: Modifier = Modifier,
    active: Boolean = false,
    content: @Composable ColumnScope.() -> Unit
) {
    val c = LiiveTheme.colors
    Column(
        modifier
            .clip(LiiveRadius.lg)
            .background(c.surfaceRaised)
            .border(1.5.dp, if (active) c.accent else androidx.compose.ui.graphics.Color.Transparent, LiiveRadius.lg)
            .padding(14.dp),
        content = content
    )
}

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
                if (subtitle != null) Text(subtitle, color = c.textSecondary, style = MaterialTheme.typography.bodySmall, maxLines = 2)
            }
            if (value != null) Text(value, color = c.textSecondary, style = MaterialTheme.typography.titleMedium)
            trailing()
            if (chevron) Icon(painterResource(RideIcons.ChevronRight), null, tint = c.textTertiary, modifier = Modifier.size(18.dp))
        }
        if (divider) Box(Modifier.padding(start = 60.dp).fillMaxWidth().height(0.5.dp).background(c.separator))
    }
}

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

@Composable
fun LiiveSwitch(checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    val c = LiiveTheme.colors
    Switch(
        checked = checked,
        onCheckedChange = onCheckedChange,
        colors = SwitchDefaults.colors(
            checkedThumbColor = c.text,
            checkedTrackColor = c.success,
            uncheckedThumbColor = c.textSecondary,
            uncheckedTrackColor = c.fill
        )
    )
}

@Composable
fun LiiveProgressDots(legs: Int, current: Int, modifier: Modifier = Modifier) {
    val c = LiiveTheme.colors
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        for (index in 1..legs) {
            Box(Modifier.size(12.dp).clip(CircleShape).background(if (index <= current) c.accent else c.fill))
            if (index < legs) Box(Modifier.weight(1f).height(3.dp).background(if (index < current) c.accent else c.fill))
        }
    }
}

@Composable
fun LiiveMapMarker(kind: MapMarkerKind, label: String) {
    val c = LiiveTheme.colors
    val color = when (kind) {
        MapMarkerKind.Car -> c.accent
        MapMarkerKind.Origin -> c.success
        MapMarkerKind.Destination -> c.danger
        MapMarkerKind.Transfer -> c.warning
    }
    val icon = when (kind) {
        MapMarkerKind.Car -> RideIcons.Car
        MapMarkerKind.Origin, MapMarkerKind.Destination -> RideIcons.LocationOn
        MapMarkerKind.Transfer -> RideIcons.SwapHoriz
    }
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.widthIn(max = 150.dp)) {
        Row(
            Modifier.clip(CircleShape).background(color).padding(horizontal = 9.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            Icon(painterResource(icon), null, tint = if (kind == MapMarkerKind.Car) c.onAccent else androidx.compose.ui.graphics.Color.White, modifier = Modifier.size(14.dp))
            Text(label, color = if (kind == MapMarkerKind.Car) c.onAccent else androidx.compose.ui.graphics.Color.White, style = MaterialTheme.typography.labelMedium)
        }
        Canvas(Modifier.size(width = 12.dp, height = 8.dp)) {
            drawPath(Path().apply {
                moveTo(size.width / 2f, size.height)
                lineTo(0f, 0f)
                lineTo(size.width, 0f)
                close()
            }, color)
        }
    }
}

enum class MapMarkerKind { Car, Origin, Destination, Transfer }

@Composable
fun LiiveFareRow(label: String, amount: String, muted: Boolean = false, total: Boolean = false) {
    val c = LiiveTheme.colors
    Row(Modifier.fillMaxWidth().padding(vertical = 7.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = if (muted) c.textSecondary else c.text, style = if (total) MaterialTheme.typography.titleLarge else MaterialTheme.typography.titleMedium)
        Spacer(Modifier.weight(1f))
        Text(
            amount,
            color = if (total) c.text else c.textSecondary,
            style = (if (total) MaterialTheme.typography.titleLarge else MaterialTheme.typography.titleMedium).tabularNumbers(),
            fontWeight = if (total) FontWeight.Bold else FontWeight.Normal
        )
    }
}
