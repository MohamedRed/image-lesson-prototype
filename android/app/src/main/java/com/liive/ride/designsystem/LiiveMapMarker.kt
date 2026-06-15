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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp

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

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier.widthIn(max = 150.dp)
    ) {
        if (kind == MapMarkerKind.Origin) {
            Box(
                Modifier
                    .size(18.dp)
                    .shadow(LiiveElevation.card, CircleShape)
                    .clip(CircleShape)
                    .background(color)
                    .border(3.dp, Color.White, CircleShape)
            )
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(0.dp)) {
                Box(
                    Modifier
                        .size(38.dp)
                        .shadow(LiiveElevation.card, CircleShape)
                        .clip(CircleShape)
                        .background(color)
                        .border(2.5.dp, Color.White, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(painterResource(icon), null, tint = Color.White, modifier = Modifier.size(18.dp))
                }
                PointerTail(color = color)
            }
        }
        MarkerLabel(label = label, color = color)
    }
}

@Composable
private fun PointerTail(color: Color) {
    Canvas(Modifier.size(width = 12.dp, height = 8.dp).offset(y = (-1).dp)) {
        val fill = Path().apply {
            moveTo(size.width / 2f, size.height)
            lineTo(0f, 0f)
            lineTo(size.width, 0f)
            close()
        }
        drawPath(fill, color)
        drawLine(Color.White, Offset(size.width / 2f, size.height), Offset(0f, 0f), strokeWidth = 2.5f)
        drawLine(Color.White, Offset(size.width / 2f, size.height), Offset(size.width, 0f), strokeWidth = 2.5f)
    }
}

@Composable
private fun MarkerLabel(label: String, color: Color) {
    val c = LiiveTheme.colors

    Box(
        Modifier
            .shadow(LiiveElevation.card, LiiveRadius.full)
            .clip(LiiveRadius.full)
            .background(c.surface)
            .padding(horizontal = 8.dp, vertical = 2.dp)
    ) {
        Text(label, color = c.text, style = MaterialTheme.typography.labelMedium, maxLines = 1)
        Box(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(2.dp)
                .background(color)
        )
    }
}

enum class MapMarkerKind { Car, Origin, Destination, Transfer }
