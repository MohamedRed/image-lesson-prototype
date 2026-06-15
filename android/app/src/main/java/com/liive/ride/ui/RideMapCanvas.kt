package com.liive.ride.ui

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.liive.ride.RidePhase
import com.liive.ride.designsystem.LiiveMapMarker
import com.liive.ride.designsystem.LiiveTheme
import com.liive.ride.designsystem.MapMarkerKind
import kotlin.math.roundToInt

@Composable
fun RideMapCanvas(phase: RidePhase, isMultiLeg: Boolean, carProgress: Float) {
    val c = LiiveTheme.colors
    val effectivePhase = if (phase == RidePhase.Complete) RidePhase.Enroute else phase
    val showRoute = effectivePhase != RidePhase.Destination
    val showCar = effectivePhase == RidePhase.Enroute

    BoxWithConstraints(Modifier.fillMaxSize().background(c.mapBackground)) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(c.mapWater, topLeft = Offset(-40f, size.height * 0.73f), size = androidx.compose.ui.geometry.Size(size.width * 0.55f, size.height * 0.35f), alpha = 0.9f)
            drawRect(Color(0xFF222A22), topLeft = Offset(size.width * 0.62f, size.height * 0.05f), size = androidx.compose.ui.geometry.Size(size.width * 0.60f, size.height * 0.24f), alpha = 0.55f)
            drawRect(Color(0xFF2A2722), topLeft = Offset(-20f, size.height * 0.16f), size = androidx.compose.ui.geometry.Size(size.width * 0.38f, size.height * 0.20f), alpha = 0.50f)
            drawStreets(c.mapRoad)
            if (showRoute) {
                drawPath(routePath(size.width, size.height, isMultiLeg), c.accent, style = Stroke(width = 7.dp.toPx(), cap = StrokeCap.Round))
                if (isMultiLeg) {
                    val t = point(150f, 320f, size.width, size.height)
                    drawCircle(Color.White, radius = 5.dp.toPx(), center = t)
                    drawCircle(c.warning, radius = 5.dp.toPx(), center = t, style = Stroke(width = 3.dp.toPx()))
                }
            }
        }

        if (effectivePhase == RidePhase.Destination) {
            PulseMarker(point = MapPoint(196f, 470f), maxWidth = maxWidth, maxHeight = maxHeight)
        }
        if (showRoute && !showCar) MarkerAt(MapPoint(196f, 470f), maxWidth, maxHeight) {
            LiiveMapMarker(MapMarkerKind.Origin, "Pickup")
        }
        if (showCar) MarkerAt(carPoint(isMultiLeg, carProgress), maxWidth, maxHeight) {
            LiiveMapMarker(MapMarkerKind.Car, if (isMultiLeg) "Leg 2 · 3 min" else "4 min")
        }
        if (isMultiLeg && showRoute) MarkerAt(MapPoint(150f, 320f), maxWidth, maxHeight) {
            LiiveMapMarker(MapMarkerKind.Transfer, "Transfer")
        }
        if (effectivePhase != RidePhase.Destination) MarkerAt(MapPoint(250f, 165f), maxWidth, maxHeight) {
            LiiveMapMarker(MapMarkerKind.Destination, "Union Square")
        }
        if (phase == RidePhase.Matching) RadarMarker(point = MapPoint(196f, 470f), maxWidth = maxWidth, maxHeight = maxHeight)
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawStreets(roadColor: Color) {
    val major = listOf(
        MapLine(-20f, 250f, 430f, 225f), MapLine(-20f, 370f, 430f, 350f),
        MapLine(-20f, 500f, 430f, 520f), MapLine(-20f, 630f, 430f, 650f),
        MapLine(70f, -20f, 120f, 780f), MapLine(210f, -20f, 240f, 780f),
        MapLine(330f, -20f, 360f, 780f)
    )
    val minor = listOf(
        MapLine(-20f, 180f, 430f, 165f), MapLine(-20f, 430f, 430f, 445f),
        MapLine(140f, -20f, 170f, 780f), MapLine(280f, -20f, 305f, 780f)
    )
    major.forEach { drawLine(roadColor, point(it.x1, it.y1, size.width, size.height), point(it.x2, it.y2, size.width, size.height), strokeWidth = 9.dp.toPx(), cap = StrokeCap.Round, alpha = 0.95f) }
    minor.forEach { drawLine(roadColor, point(it.x1, it.y1, size.width, size.height), point(it.x2, it.y2, size.width, size.height), strokeWidth = 4.dp.toPx(), cap = StrokeCap.Round, alpha = 0.60f) }
}

private fun routePath(width: Float, height: Float, multiLeg: Boolean) = Path().apply {
    moveToPoint(MapPoint(196f, 470f), width, height)
    if (multiLeg) {
        cubicToPoint(MapPoint(150f, 430f), MapPoint(120f, 380f), MapPoint(150f, 320f), width, height)
        cubicToPoint(MapPoint(175f, 285f), MapPoint(230f, 230f), MapPoint(250f, 165f), width, height)
    } else {
        cubicToPoint(MapPoint(170f, 400f), MapPoint(300f, 330f), MapPoint(250f, 165f), width, height)
    }
}

private fun Path.moveToPoint(p: MapPoint, width: Float, height: Float) = moveTo(p.x / 402f * width, p.y / 740f * height)
private fun Path.cubicToPoint(c1: MapPoint, c2: MapPoint, end: MapPoint, width: Float, height: Float) =
    cubicTo(c1.x / 402f * width, c1.y / 740f * height, c2.x / 402f * width, c2.y / 740f * height, end.x / 402f * width, end.y / 740f * height)

private fun point(x: Float, y: Float, width: Float, height: Float) = Offset(x / 402f * width, y / 740f * height)

@Composable
private fun MarkerAt(point: MapPoint, maxWidth: Dp, maxHeight: Dp, content: @Composable () -> Unit) {
    Box(Modifier.offset(x = maxWidth * (point.x / 402f) - 58.dp, y = maxHeight * (point.y / 740f) - 48.dp)) {
        content()
    }
}

@Composable
private fun PulseMarker(point: MapPoint, maxWidth: Dp, maxHeight: Dp) {
    val c = LiiveTheme.colors
    val transition = rememberInfiniteTransition(label = "pulse")
    val scale by transition.animateFloat(0.35f, 1f, infiniteRepeatable(tween(2000), RepeatMode.Restart), label = "scale")
    MarkerAt(point, maxWidth, maxHeight) {
        Box(Modifier.size(66.dp)) {
            Canvas(Modifier.fillMaxSize()) {
                drawCircle(c.accentTint, radius = size.minDimension / 2f * scale, center = center, alpha = 1f - scale)
                drawCircle(c.accent, radius = 11.dp.toPx(), center = center)
                drawCircle(Color.White, radius = 11.dp.toPx(), center = center, style = Stroke(width = 3.dp.toPx()))
            }
        }
    }
}

@Composable
private fun RadarMarker(point: MapPoint, maxWidth: Dp, maxHeight: Dp) {
    val c = LiiveTheme.colors
    val density = LocalDensity.current
    val transition = rememberInfiniteTransition(label = "radar")
    val scale by transition.animateFloat(0.11f, 1f, infiniteRepeatable(tween(1800), RepeatMode.Restart), label = "scale")
    Box(Modifier.offset {
        with(density) {
            IntOffset(
                (maxWidth.toPx() * (point.x / 402f) - 63.dp.toPx()).roundToInt(),
                (maxHeight.toPx() * (point.y / 740f) - 63.dp.toPx()).roundToInt()
            )
        }
    }.size(126.dp)) {
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(c.accent, radius = size.minDimension / 2f * scale, center = center, alpha = 1f - scale)
            drawCircle(c.accent, radius = 7.dp.toPx(), center = center)
            drawCircle(Color.White, radius = 7.dp.toPx(), center = center, style = Stroke(width = 3.dp.toPx()))
        }
    }
}

private fun carPoint(multiLeg: Boolean, progress: Float): MapPoint {
    val points = if (multiLeg) {
        listOf(MapPoint(196f, 470f), MapPoint(150f, 400f), MapPoint(150f, 320f), MapPoint(205f, 250f), MapPoint(250f, 165f))
    } else {
        listOf(MapPoint(196f, 470f), MapPoint(215f, 390f), MapPoint(285f, 300f), MapPoint(250f, 165f))
    }
    val raw = (progress.coerceIn(0f, 1f) * (points.size - 1)).coerceAtMost((points.size - 1).toFloat())
    val index = raw.toInt().coerceAtMost(points.size - 2)
    val local = raw - index
    val start = points[index]
    val end = points[index + 1]
    return MapPoint(start.x + (end.x - start.x) * local, start.y + (end.y - start.y) * local)
}

private data class MapPoint(val x: Float, val y: Float)
private data class MapLine(val x1: Float, val y1: Float, val x2: Float, val y2: Float)
