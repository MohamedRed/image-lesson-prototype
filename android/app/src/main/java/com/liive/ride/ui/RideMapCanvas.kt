package com.liive.ride.ui

import android.graphics.BlurMaskFilter
import android.graphics.Paint
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.unit.dp
import com.liive.ride.RidePhase
import com.liive.ride.RideTripSummary
import com.liive.ride.designsystem.LiiveMapMarker
import com.liive.ride.designsystem.LiiveTheme
import com.liive.ride.designsystem.MapMarkerKind
import kotlin.math.roundToInt

@Composable
fun RideMapCanvas(phase: RidePhase, isMultiLeg: Boolean, carProgress: Float, tripSummary: RideTripSummary) {
    val c = LiiveTheme.colors
    val effectivePhase = if (phase == RidePhase.Complete) RidePhase.Enroute else phase
    val showRoute = effectivePhase != RidePhase.Destination
    val showCar = effectivePhase == RidePhase.Enroute

    Box(Modifier.fillMaxSize().background(c.mapBackground)) {
        Canvas(Modifier.fillMaxSize()) {
            val viewport = MapSvgViewport(size.width, size.height)
            rotate(degrees = -8f, pivot = viewport.point(70f, 670f)) {
                drawRect(
                    c.mapWater,
                    topLeft = viewport.point(-40f, 540f),
                    size = Size(viewport.length(220f), viewport.length(260f)),
                    alpha = 0.9f
                )
            }
            drawRoundRect(
                c.mapPark,
                topLeft = viewport.point(250f, 40f),
                size = Size(viewport.length(240f), viewport.length(180f)),
                cornerRadius = CornerRadius(viewport.length(10f)),
                alpha = 0.55f
            )
            drawRoundRect(
                c.mapDistrict,
                topLeft = viewport.point(-20f, 120f),
                size = Size(viewport.length(150f), viewport.length(150f)),
                cornerRadius = CornerRadius(viewport.length(8f)),
                alpha = 0.50f
            )
            drawStreets(c.mapRoad, viewport)
            if (showRoute) {
                drawShadowedRoute(routePath(viewport, isMultiLeg), c.mapRoute, viewport)
                if (isMultiLeg) {
                    val t = viewport.point(150f, 320f)
                    drawCircle(androidx.compose.ui.graphics.Color.White, radius = viewport.length(5f), center = t)
                    drawCircle(c.warning, radius = viewport.length(5f), center = t, style = Stroke(width = viewport.length(3f)))
                }
            }
        }

        if (effectivePhase == RidePhase.Destination) {
            OverlayAt(MapPoint(196f, 470f), OverlayAnchor.Center) {
                PulseMarker()
            }
        }
        if (showRoute && !showCar) OverlayAt(MapPoint(196f, 470f), OverlayAnchor.Bottom) {
            LiiveMapMarker(MapMarkerKind.Origin, "Pickup")
        }
        if (showCar) OverlayAt(carPoint(isMultiLeg, carProgress), OverlayAnchor.Bottom) {
            LiiveMapMarker(MapMarkerKind.Car, tripSummary.mapMarkerLabel)
        }
        if (isMultiLeg && showRoute) OverlayAt(MapPoint(150f, 320f), OverlayAnchor.Bottom) {
            LiiveMapMarker(MapMarkerKind.Transfer, "Transfer")
        }
        if (effectivePhase != RidePhase.Destination) OverlayAt(MapPoint(250f, 165f), OverlayAnchor.Bottom) {
            LiiveMapMarker(MapMarkerKind.Destination, "Union Square")
        }
        if (phase == RidePhase.Matching) OverlayAt(MapPoint(196f, 470f), OverlayAnchor.Center) {
            RadarMarker()
        }
    }
}

private fun DrawScope.drawShadowedRoute(path: Path, routeColor: Color, viewport: MapSvgViewport) {
    drawIntoCanvas { canvas ->
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.BLACK
            alpha = (255 * RouteShadowAlpha).roundToInt()
            style = Paint.Style.STROKE
            strokeWidth = viewport.length(RouteStrokeWidth)
            strokeCap = Paint.Cap.ROUND
            maskFilter = BlurMaskFilter(viewport.length(RouteShadowBlur), BlurMaskFilter.Blur.NORMAL)
        }
        canvas.nativeCanvas.save()
        canvas.nativeCanvas.translate(0f, viewport.length(RouteShadowYOffset))
        canvas.nativeCanvas.drawPath(path.asAndroidPath(), shadowPaint)
        canvas.nativeCanvas.restore()
    }
    drawPath(path, routeColor, style = Stroke(width = viewport.length(RouteStrokeWidth), cap = StrokeCap.Round))
}

private fun DrawScope.drawStreets(roadColor: Color, viewport: MapSvgViewport) {
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
    major.forEach {
        drawLine(
            roadColor,
            viewport.point(it.x1, it.y1),
            viewport.point(it.x2, it.y2),
            strokeWidth = viewport.length(9f),
            cap = StrokeCap.Round,
            alpha = 0.95f
        )
    }
    minor.forEach {
        drawLine(
            roadColor,
            viewport.point(it.x1, it.y1),
            viewport.point(it.x2, it.y2),
            strokeWidth = viewport.length(4f),
            cap = StrokeCap.Round,
            alpha = 0.60f
        )
    }
}

private fun routePath(viewport: MapSvgViewport, multiLeg: Boolean) = Path().apply {
    moveToPoint(MapPoint(196f, 470f), viewport)
    if (multiLeg) {
        cubicToPoint(MapPoint(150f, 430f), MapPoint(120f, 380f), MapPoint(150f, 320f), viewport)
        cubicToPoint(MapPoint(175f, 285f), MapPoint(230f, 230f), MapPoint(250f, 165f), viewport)
    } else {
        cubicToPoint(MapPoint(170f, 400f), MapPoint(300f, 330f), MapPoint(250f, 165f), viewport)
    }
}

private fun Path.moveToPoint(p: MapPoint, viewport: MapSvgViewport) {
    val point = viewport.point(p)
    moveTo(point.x, point.y)
}

private fun Path.cubicToPoint(c1: MapPoint, c2: MapPoint, end: MapPoint, viewport: MapSvgViewport) {
    val first = viewport.point(c1)
    val second = viewport.point(c2)
    val destination = viewport.point(end)
    cubicTo(first.x, first.y, second.x, second.y, destination.x, destination.y)
}

@Composable
private fun OverlayAt(point: MapPoint, anchor: OverlayAnchor, content: @Composable () -> Unit) {
    SubcomposeLayout(Modifier.fillMaxSize()) { constraints ->
        val placeable = subcompose("content", content).first().measure(
            constraints.copy(minWidth = 0, minHeight = 0)
        )
        val x = (constraints.maxWidth * (point.x / MapWidth) - placeable.width / 2f).roundToInt()
        val yAnchor = when (anchor) {
            OverlayAnchor.Center -> placeable.height / 2f
            OverlayAnchor.Bottom -> placeable.height.toFloat()
        }
        val y = (constraints.maxHeight * (point.y / MapHeight) - yAnchor).roundToInt()

        layout(constraints.maxWidth, constraints.maxHeight) {
            placeable.placeRelative(x, y)
        }
    }
}

@Composable
private fun PulseMarker() {
    val c = LiiveTheme.colors
    val transition = rememberInfiniteTransition(label = "pulse")
    val scale by transition.animateFloat(0.35f, 1f, infiniteRepeatable(tween(2000), RepeatMode.Restart), label = "scale")
    Box(Modifier.size(66.dp)) {
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(c.accentTint, radius = size.minDimension / 2f * scale, center = center, alpha = 1f - scale)
            drawCircle(c.accent, radius = 11.dp.toPx(), center = center)
            drawCircle(androidx.compose.ui.graphics.Color.White, radius = 11.dp.toPx(), center = center, style = Stroke(width = 3.dp.toPx()))
        }
    }
}

@Composable
private fun RadarMarker() {
    val c = LiiveTheme.colors
    val transition = rememberInfiniteTransition(label = "radar")
    val scale by transition.animateFloat(0.11f, 1f, infiniteRepeatable(tween(1800), RepeatMode.Restart), label = "scale")
    Box(Modifier.size(126.dp)) {
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(c.accent, radius = size.minDimension / 2f * scale, center = center, alpha = 1f - scale)
            drawCircle(c.accent, radius = 7.dp.toPx(), center = center)
            drawCircle(androidx.compose.ui.graphics.Color.White, radius = 7.dp.toPx(), center = center, style = Stroke(width = 3.dp.toPx()))
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

private enum class OverlayAnchor { Center, Bottom }
private data class MapPoint(val x: Float, val y: Float)
private data class MapLine(val x1: Float, val y1: Float, val x2: Float, val y2: Float)
private data class MapSvgViewport(val width: Float, val height: Float) {
    private val scale = maxOf(width / MapWidth, height / MapHeight)
    private val offsetX = (width - MapWidth * scale) / 2f
    private val offsetY = (height - MapHeight * scale) / 2f

    fun point(point: MapPoint) = point(point.x, point.y)

    fun point(x: Float, y: Float) = Offset(offsetX + x * scale, offsetY + y * scale)

    fun length(value: Float) = value * scale
}

private const val MapWidth = 402f
private const val MapHeight = 740f
private const val RouteStrokeWidth = 7f
private const val RouteShadowBlur = 3f
private const val RouteShadowYOffset = 2f
private const val RouteShadowAlpha = 0.35f
