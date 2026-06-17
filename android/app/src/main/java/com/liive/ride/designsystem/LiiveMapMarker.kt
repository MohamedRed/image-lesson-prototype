package com.liive.ride.designsystem

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.res.painterResource

@Composable
fun LiiveMapMarker(kind: MapMarkerKind, label: String? = null) {
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

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(LiiveMapMarkerLayout.MarkerGap),
        modifier = Modifier.widthIn(max = LiiveMapMarkerLayout.MaxLabelWidth)
    ) {
        if (kind == MapMarkerKind.Origin) {
            Box(
                Modifier
                    .size(LiiveMapMarkerLayout.DotSize)
                    .shadow(LiiveElevation.pin, CircleShape)
                    .clip(CircleShape)
                    .background(color)
                    .border(LiiveMapMarkerLayout.DotStrokeWidth, LiiveMapMarkerLayout.OutlineColor, CircleShape)
            )
        } else {
            Box(
                Modifier.size(LiiveMapMarkerLayout.PinSize),
                contentAlignment = Alignment.Center
            ) {
                PointerTail(
                    color = color,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .offset(y = LiiveMapMarkerLayout.PinTailOffset)
                )
                Box(
                    Modifier
                        .size(LiiveMapMarkerLayout.PinSize)
                        .shadow(LiiveElevation.pin, CircleShape)
                        .clip(CircleShape)
                        .background(color)
                        .border(
                            LiiveMapMarkerLayout.PinStrokeWidth,
                            LiiveMapMarkerLayout.OutlineColor,
                            CircleShape
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        painterResource(icon),
                        null,
                        tint = LiiveMapMarkerLayout.OutlineColor,
                        modifier = Modifier.size(LiiveMapMarkerLayout.GlyphSize)
                    )
                }
            }
        }
        if (!label.isNullOrEmpty()) {
            MarkerLabel(label = label, color = color)
        }
    }
}

@Composable
private fun PointerTail(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier.size(LiiveMapMarkerLayout.TailCanvasSize)) {
        val edge = LiiveMapMarkerLayout.TailEdgeSize.toPx()
        val strokeWidth = LiiveMapMarkerLayout.PinStrokeWidth.toPx()
        val left = (size.width - edge) / 2f
        val top = (size.height - edge) / 2f
        val right = left + edge
        val bottom = top + edge

        rotate(degrees = LiiveMapMarkerLayout.PointerRotationDegrees, pivot = center) {
            drawRect(color, topLeft = Offset(left, top), size = Size(edge, edge))
            drawLine(
                LiiveMapMarkerLayout.OutlineColor,
                Offset(right, top),
                Offset(right, bottom),
                strokeWidth = strokeWidth
            )
            drawLine(
                LiiveMapMarkerLayout.OutlineColor,
                Offset(left, bottom),
                Offset(right, bottom),
                strokeWidth = strokeWidth
            )
        }
    }
}

@Composable
private fun MarkerLabel(label: String, color: Color) {
    val c = LiiveTheme.colors

    Box(
        Modifier
            .shadow(LiiveElevation.small, LiiveRadius.full)
            .clip(LiiveRadius.full)
            .background(c.surface)
    ) {
        Text(
            label,
            color = c.text,
            style = MaterialTheme.typography.labelMedium,
            maxLines = 1,
            modifier = Modifier.padding(
                horizontal = LiiveMapMarkerLayout.LabelHorizontalPadding,
                vertical = LiiveMapMarkerLayout.LabelVerticalPadding
            )
        )
        Box(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(LiiveMapMarkerLayout.LabelIndicatorHeight)
                .background(color)
        )
    }
}

private object LiiveMapMarkerLayout {
    val MarkerGap = LiiveSpacing.xs
    val MaxLabelWidth = LiiveSpacing.huge + LiiveSpacing.huge + LiiveSpacing.huge +
        LiiveSpacing.xxxl - LiiveSpacing.xs2
    val DotSize = LiiveSpacing.l + LiiveSpacing.xs2
    val DotStrokeWidth = LiiveSpacing.xs - LiiveSpacing.xs2 / 2
    val PinSize = LiiveControl.md - LiiveSpacing.xs - LiiveSpacing.xs2
    val GlyphSize = DotSize
    val TailCanvasSize = DotSize
    val TailEdgeSize = LiiveSpacing.m
    val PinTailOffset = LiiveSpacing.s - LiiveSpacing.xs2 / 4
    val PinStrokeWidth = LiiveSpacing.xs2 + LiiveSpacing.xs2 / 4
    val LabelHorizontalPadding = LiiveSpacing.s
    val LabelVerticalPadding = LiiveSpacing.xs2
    val LabelIndicatorHeight = LiiveSpacing.xs2
    const val PointerRotationDegrees = 45f
    val OutlineColor = Color.White
}

enum class MapMarkerKind { Car, Origin, Destination, Transfer }
