package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow

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
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val clickModifier = if (onClick != null) {
        Modifier.clickable(
            interactionSource = interactionSource,
            indication = null,
            onClick = onClick
        )
    } else {
        Modifier
    }
    Column(modifier.then(clickModifier)) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = LiiveSpacing.touchMin)
                .background(if (onClick != null && pressed) c.fillQuaternary else Color.Transparent)
                .padding(
                    horizontal = LiiveListRowLayout.HorizontalPadding,
                    vertical = LiiveListRowLayout.VerticalPadding
                ),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(LiiveListRowLayout.RowSpacing)
        ) {
            leading()
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(LiiveListRowLayout.TextSpacing)) {
                Text(
                    title,
                    color = c.text,
                    style = MaterialTheme.typography.bodyLarge.copy(
                        letterSpacing = MaterialTheme.typography.headlineSmall.letterSpacing
                    ),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                if (subtitle != null) {
                    Text(subtitle, color = c.textSecondary, style = MaterialTheme.typography.bodySmall, maxLines = 2)
                }
            }
            if (value != null) {
                Text(value, color = c.textSecondary, style = MaterialTheme.typography.bodyLarge)
            }
            trailing()
            if (chevron) {
                Icon(
                    painterResource(RideIcons.ChevronRight),
                    null,
                    tint = c.textTertiary,
                    modifier = Modifier.size(LiiveListRowLayout.ChevronIconSize)
                )
            }
        }
        if (divider) {
            Box(Modifier.fillMaxWidth().height(LiiveListRowLayout.DividerHeight).background(c.separator))
        }
    }
}

private object LiiveListRowLayout {
    val RowSpacing = LiiveSpacing.m
    val TextSpacing = LiiveSpacing.xs2 / 2
    val ChevronIconSize = LiiveSpacing.l - LiiveSpacing.xs2
    val HorizontalPadding = LiiveSpacing.screenGutter
    val VerticalPadding = LiiveSpacing.s + LiiveSpacing.xs2
    val DividerHeight = LiiveSpacing.xs2 / 4
}
