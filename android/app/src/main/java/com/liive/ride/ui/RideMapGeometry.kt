package com.liive.ride.ui

import androidx.compose.ui.geometry.Offset

internal object RideMapGeometry {
    const val MapWidth = 402f
    const val MapHeight = 740f

    val Origin = MapPoint(196f, 470f)
    val Destination = MapPoint(250f, 165f)
    val Transfer = MapPoint(150f, 320f)

    val WaterBlock = MapBlock(
        topLeft = MapPoint(-40f, 540f),
        pivot = MapPoint(70f, 670f),
        size = MapSize(220f, 260f),
        cornerRadius = 0f,
        alpha = 0.9f,
        rotationDegrees = -8f
    )
    val ParkBlock = MapBlock(
        topLeft = MapPoint(250f, 40f),
        pivot = MapPoint(370f, 130f),
        size = MapSize(240f, 180f),
        cornerRadius = 10f,
        alpha = 0.55f,
        rotationDegrees = 0f
    )
    val DistrictBlock = MapBlock(
        topLeft = MapPoint(-20f, 120f),
        pivot = MapPoint(55f, 195f),
        size = MapSize(150f, 150f),
        cornerRadius = 8f,
        alpha = 0.50f,
        rotationDegrees = 0f
    )

    const val MajorStreetWidth = 9f
    const val MajorStreetAlpha = 0.95f
    const val MinorStreetWidth = 4f
    const val MinorStreetAlpha = 0.60f
    const val RouteStrokeWidth = 7f
    const val RouteShadowBlur = 3f
    const val RouteShadowYOffset = 2f
    const val RouteShadowAlpha = 0.35f
    const val TransferRadius = 5f
    const val TransferStrokeWidth = 3f
    const val CurrentPulseSize = 66
    const val CurrentPulseScaleStart = 0.35f
    const val CurrentPulseDurationMs = 2_000
    const val CurrentDotRadius = 11
    const val CurrentDotStrokeWidth = 3
    const val RadarPulseSize = 126
    const val RadarPulseScaleStart = 0.11f
    const val RadarPulseDurationMs = 1_800
    const val RadarDotRadius = 7
    const val RadarDotStrokeWidth = 3

    val MajorStreets = listOf(
        MapLine(-20f, 250f, 430f, 225f),
        MapLine(-20f, 370f, 430f, 350f),
        MapLine(-20f, 500f, 430f, 520f),
        MapLine(-20f, 630f, 430f, 650f),
        MapLine(70f, -20f, 120f, 780f),
        MapLine(210f, -20f, 240f, 780f),
        MapLine(330f, -20f, 360f, 780f),
    )

    val MinorStreets = listOf(
        MapLine(-20f, 180f, 430f, 165f),
        MapLine(-20f, 430f, 430f, 445f),
        MapLine(140f, -20f, 170f, 780f),
        MapLine(280f, -20f, 305f, 780f),
    )

    val SingleLegControls = RouteControls(
        firstControl = MapPoint(170f, 400f),
        secondControl = MapPoint(300f, 330f),
        end = Destination,
    )

    val MultiLegControls = listOf(
        RouteControls(
            firstControl = MapPoint(150f, 430f),
            secondControl = MapPoint(120f, 380f),
            end = Transfer,
        ),
        RouteControls(
            firstControl = MapPoint(175f, 285f),
            secondControl = MapPoint(230f, 230f),
            end = Destination,
        ),
    )

    fun carPoints(multiLeg: Boolean): List<MapPoint> =
        if (multiLeg) {
            listOf(Origin, MapPoint(150f, 400f), Transfer, MapPoint(205f, 250f), Destination)
        } else {
            listOf(Origin, MapPoint(215f, 390f), MapPoint(285f, 300f), Destination)
        }
}

internal data class MapPoint(val x: Float, val y: Float)
internal data class MapSize(val width: Float, val height: Float)

internal data class MapBlock(
    val topLeft: MapPoint,
    val pivot: MapPoint,
    val size: MapSize,
    val cornerRadius: Float,
    val alpha: Float,
    val rotationDegrees: Float,
)

internal data class RouteControls(
    val firstControl: MapPoint,
    val secondControl: MapPoint,
    val end: MapPoint,
)

internal data class MapLine(val x1: Float, val y1: Float, val x2: Float, val y2: Float)

internal data class MapSvgViewport(val width: Float, val height: Float) {
    private val scale = maxOf(width / RideMapGeometry.MapWidth, height / RideMapGeometry.MapHeight)
    private val offsetX = (width - RideMapGeometry.MapWidth * scale) / 2f
    private val offsetY = (height - RideMapGeometry.MapHeight * scale) / 2f

    fun point(point: MapPoint) = point(point.x, point.y)

    fun point(x: Float, y: Float) = Offset(offsetX + x * scale, offsetY + y * scale)

    fun length(value: Float) = value * scale
}
