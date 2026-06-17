package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight

@Composable
fun LiiveProgressDots(legs: Int, current: Int, modifier: Modifier = Modifier) {
    val boundedLegs = legs.coerceIn(LiiveProgressDotsLayout.FirstLeg, LiiveProgressDotsLayout.MaxLegs)
    val boundedCurrent = current.coerceAtLeast(LiiveProgressDotsLayout.FirstLeg)

    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        for (index in LiiveProgressDotsLayout.FirstLeg..boundedLegs) {
            ProgressLeg(index = index, current = boundedCurrent)
            if (index < boundedLegs) {
                ProgressTransfer(passed = index < boundedCurrent, modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun ProgressLeg(index: Int, current: Int) {
    val c = LiiveTheme.colors
    val completed = index < current
    val active = index == current
    val background = when {
        completed -> c.success
        active -> c.accent
        else -> c.fill
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(LiiveProgressDotsLayout.LegGap)
    ) {
        Box(
            Modifier
                .size(LiiveProgressDotsLayout.LegCircleSize)
                .clip(CircleShape)
                .background(background),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = index.toString(),
                color = if (completed || active) LiiveProgressDotsLayout.ActiveTextColor else c.textTertiary,
                style = MaterialTheme.typography.labelMedium.tabularNumbers(),
                fontWeight = FontWeight.Bold
            )
        }
        Text("Leg $index", color = c.textSecondary, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun ProgressTransfer(passed: Boolean, modifier: Modifier = Modifier) {
    val c = LiiveTheme.colors
    val color = if (passed) c.success else c.warning

    Column(
        modifier
            .defaultMinSize(minWidth = LiiveProgressDotsLayout.TransferMinWidth)
            .padding(bottom = LiiveProgressDotsLayout.TransferBottomPadding),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(LiiveProgressDotsLayout.TransferGap)
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(LiiveProgressDotsLayout.ConnectorHeight)
                .clip(LiiveRadius.full)
                .background(if (passed) c.success else c.fill)
        )
        Icon(
            painterResource(RideIcons.SwapHoriz),
            null,
            tint = color,
            modifier = Modifier.size(LiiveProgressDotsLayout.TransferIconSize)
        )
    }
}

private object LiiveProgressDotsLayout {
    const val FirstLeg = 1
    const val MaxLegs = 3
    val LegGap = LiiveSpacing.xs
    val LegCircleSize = LiiveSpacing.xxl
    val TransferGap = LiiveSpacing.xs - LiiveSpacing.xs2 / 2
    val ConnectorHeight = LiiveSpacing.xs2
    val TransferIconSize = LiiveSpacing.m + LiiveSpacing.xs2 / 2
    val TransferMinWidth = LiiveSpacing.xxl + LiiveSpacing.xs
    val TransferBottomPadding = LiiveSpacing.l - LiiveSpacing.xs2 / 2
    val ActiveTextColor = Color.White
}
