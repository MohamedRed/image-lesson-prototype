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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.liive.ride.RideTestTags
import com.liive.ride.RidePhase
import com.liive.ride.RideTripSummary
import com.liive.ride.designsystem.LiiveMapMarker
import com.liive.ride.designsystem.LiiveTheme
import com.liive.ride.designsystem.MapMarkerKind
import kotlin.math.roundToInt

@Composable
fun RideMapCanvas(
    phase: RidePhase,
    isMultiLeg: Boolean,
    carProgress: Float,
    destinationName: String,
    tripSummary: RideTripSummary
) {
    val c = LiiveTheme.colors
    val effectivePhase = if (phase == RidePhase.Complete) RidePhase.Enroute else phase
    val showRoute = effectivePhase != RidePhase.Destination
    val showCar = effectivePhase == RidePhase.Enroute

    Box(Modifier.fillMaxSize().background(c.mapBackground).testTag(RideTestTags.Map)) {
        Canvas(Modifier.fillMaxSize()) {
            val viewport = MapSvgViewport(size.width, size.height)
            drawMapBlock(RideMapGeometry.WaterBlock, c.mapWater, viewport)
            drawMapBlock(RideMapGeometry.ParkBlock, c.mapPark, viewport)
            drawMapBlock(RideMapGeometry.DistrictBlock, c.mapDistrict, viewport)
            drawStreets(c.mapRoad, viewport)
            if (showRoute) {
                drawShadowedRoute(routePath(viewport, isMultiLeg), c.mapRoute, viewport)
                if (isMultiLeg) {
                    val t = viewport.point(RideMapGeometry.Transfer)
                    drawCircle(Color.White, radius = viewport.length(RideMapGeometry.TransferRadius), center = t)
                    drawCircle(
                        c.warning,
                        radius = viewport.length(RideMapGeometry.TransferRadius),
                        center = t,
                        style = Stroke(width = viewport.length(RideMapGeometry.TransferStrokeWidth))
                    )
                }
            }
        }

        if (effectivePhase == RidePhase.Destination) {
            OverlayAt(RideMapGeometry.Origin, OverlayAnchor.Center) {
                PulseMarker()
            }
        }
        if (showRoute && !showCar) OverlayAt(RideMapGeometry.Origin, OverlayAnchor.Bottom) {
            LiiveMapMarker(MapMarkerKind.Origin, "Pickup")
        }
        if (showCar) OverlayAt(carPoint(isMultiLeg, carProgress), OverlayAnchor.Bottom) {
            LiiveMapMarker(MapMarkerKind.Car, tripSummary.mapMarkerLabel)
        }
        if (isMultiLeg && showRoute) OverlayAt(RideMapGeometry.Transfer, OverlayAnchor.Bottom) {
            LiiveMapMarker(MapMarkerKind.Transfer, "Transfer")
        }
        if (effectivePhase != RidePhase.Destination) OverlayAt(RideMapGeometry.Destination, OverlayAnchor.Bottom) {
            LiiveMapMarker(MapMarkerKind.Destination, destinationName)
        }
        if (phase == RidePhase.Matching) OverlayAt(RideMapGeometry.Origin, OverlayAnchor.Center) {
            RadarMarker()
        }
    }
}

private fun DrawScope.drawMapBlock(block: MapBlock, blockColor: Color, viewport: MapSvgViewport) {
    rotate(degrees = block.rotationDegrees, pivot = viewport.point(block.pivot)) {
        drawRoundRect(
            blockColor,
            topLeft = viewport.point(block.topLeft),
            size = Size(viewport.length(block.size.width), viewport.length(block.size.height)),
            cornerRadius = CornerRadius(viewport.length(block.cornerRadius)),
            alpha = block.alpha
        )
    }
}

private fun DrawScope.drawShadowedRoute(path: Path, routeColor: Color, viewport: MapSvgViewport) {
    drawIntoCanvas { canvas ->
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.BLACK
            alpha = (255 * RideMapGeometry.RouteShadowAlpha).roundToInt()
            style = Paint.Style.STROKE
            strokeWidth = viewport.length(RideMapGeometry.RouteStrokeWidth)
            strokeCap = Paint.Cap.ROUND
            maskFilter = BlurMaskFilter(viewport.length(RideMapGeometry.RouteShadowBlur), BlurMaskFilter.Blur.NORMAL)
        }
        canvas.nativeCanvas.save()
        canvas.nativeCanvas.translate(0f, viewport.length(RideMapGeometry.RouteShadowYOffset))
        canvas.nativeCanvas.drawPath(path.asAndroidPath(), shadowPaint)
        canvas.nativeCanvas.restore()
    }
    drawPath(path, routeColor, style = Stroke(width = viewport.length(RideMapGeometry.RouteStrokeWidth), cap = StrokeCap.Round))
}

private fun DrawScope.drawStreets(roadColor: Color, viewport: MapSvgViewport) {
    RideMapGeometry.MajorStreets.forEach {
        drawLine(
            roadColor,
            viewport.point(it.x1, it.y1),
            viewport.point(it.x2, it.y2),
            strokeWidth = viewport.length(RideMapGeometry.MajorStreetWidth),
            cap = StrokeCap.Round,
            alpha = RideMapGeometry.MajorStreetAlpha
        )
    }
    RideMapGeometry.MinorStreets.forEach {
        drawLine(
            roadColor,
            viewport.point(it.x1, it.y1),
            viewport.point(it.x2, it.y2),
            strokeWidth = viewport.length(RideMapGeometry.MinorStreetWidth),
            cap = StrokeCap.Round,
            alpha = RideMapGeometry.MinorStreetAlpha
        )
    }
}

private fun routePath(viewport: MapSvgViewport, multiLeg: Boolean) = Path().apply {
    moveToPoint(RideMapGeometry.Origin, viewport)
    if (multiLeg) {
        RideMapGeometry.MultiLegControls.forEach {
            cubicToPoint(it.firstControl, it.secondControl, it.end, viewport)
        }
    } else {
        val controls = RideMapGeometry.SingleLegControls
        cubicToPoint(controls.firstControl, controls.secondControl, controls.end, viewport)
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
        val x = (constraints.maxWidth * (point.x / RideMapGeometry.MapWidth) - placeable.width / 2f).roundToInt()
        val yAnchor = when (anchor) {
            OverlayAnchor.Center -> placeable.height / 2f
            OverlayAnchor.Bottom -> placeable.height.toFloat()
        }
        val y = (constraints.maxHeight * (point.y / RideMapGeometry.MapHeight) - yAnchor).roundToInt()

        layout(constraints.maxWidth, constraints.maxHeight) {
            placeable.placeRelative(x, y)
        }
    }
}

@Composable
private fun PulseMarker() {
    val c = LiiveTheme.colors
    val transition = rememberInfiniteTransition(label = "pulse")
    val scale by transition.animateFloat(
        RideMapGeometry.CurrentPulseScaleStart,
        RideMapGeometry.PulseScaleEnd,
        infiniteRepeatable(tween(RideMapGeometry.CurrentPulseDurationMs), RepeatMode.Restart),
        label = "scale"
    )
    Box(Modifier.size(RideMapGeometry.CurrentPulseSize.dp)) {
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(
                c.accentTint,
                radius = size.minDimension / 2f * scale,
                center = center,
                alpha = pulseAlpha(
                    scale = scale,
                    startScale = RideMapGeometry.CurrentPulseScaleStart,
                    startOpacity = RideMapGeometry.CurrentPulseOpacityStart
                )
            )
            drawCircle(c.accent, radius = RideMapGeometry.CurrentDotRadius.dp.toPx(), center = center)
            drawCircle(
                Color.White,
                radius = RideMapGeometry.CurrentDotRadius.dp.toPx(),
                center = center,
                style = Stroke(width = RideMapGeometry.CurrentDotStrokeWidth.dp.toPx())
            )
        }
    }
}

@Composable
private fun RadarMarker() {
    val c = LiiveTheme.colors
    val transition = rememberInfiniteTransition(label = "radar")
    val scale by transition.animateFloat(
        RideMapGeometry.RadarPulseScaleStart,
        RideMapGeometry.PulseScaleEnd,
        infiniteRepeatable(tween(RideMapGeometry.RadarPulseDurationMs), RepeatMode.Restart),
        label = "scale"
    )
    Box(Modifier.size(RideMapGeometry.RadarPulseSize.dp)) {
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(
                c.accent,
                radius = size.minDimension / 2f * scale,
                center = center,
                alpha = pulseAlpha(
                    scale = scale,
                    startScale = RideMapGeometry.RadarPulseScaleStart,
                    startOpacity = RideMapGeometry.RadarPulseOpacityStart
                )
            )
            drawCircle(c.accent, radius = RideMapGeometry.RadarDotRadius.dp.toPx(), center = center)
            drawCircle(
                Color.White,
                radius = RideMapGeometry.RadarDotRadius.dp.toPx(),
                center = center,
                style = Stroke(width = RideMapGeometry.RadarDotStrokeWidth.dp.toPx())
            )
        }
    }
}

private fun pulseAlpha(scale: Float, startScale: Float, startOpacity: Float): Float {
    val scaleRange = RideMapGeometry.PulseScaleEnd - startScale
    val progress = ((scale - startScale) / scaleRange).coerceIn(
        PulseAlphaProgress.Start,
        PulseAlphaProgress.End
    )
    return startOpacity * (PulseAlphaProgress.End - progress)
}

private fun carPoint(multiLeg: Boolean, progress: Float): MapPoint {
    val points = RideMapGeometry.carPoints(multiLeg)
    val raw = (progress.coerceIn(0f, 1f) * (points.size - 1)).coerceAtMost((points.size - 1).toFloat())
    val index = raw.toInt().coerceAtMost(points.size - 2)
    val local = raw - index
    val start = points[index]
    val end = points[index + 1]
    return MapPoint(start.x + (end.x - start.x) * local, start.y + (end.y - start.y) * local)
}

private enum class OverlayAnchor { Center, Bottom }

private object PulseAlphaProgress {
    const val Start = 0f
    const val End = 1f
}
