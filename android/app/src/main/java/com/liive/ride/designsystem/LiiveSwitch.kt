package com.liive.ride.designsystem

import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.runtime.Composable

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
