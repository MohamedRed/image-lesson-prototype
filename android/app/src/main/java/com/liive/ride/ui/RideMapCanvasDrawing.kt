package com.liive.ride.ui

import android.graphics.BlurMaskFilter
import android.graphics.Paint
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

internal fun DrawScope.drawPinShadowCircle(color: Color, radius: Float, center: Offset) {
    drawIntoCanvas { canvas ->
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = Color.Black.toArgb()
            alpha = (255 * RideMapGeometry.DotShadowAlpha).roundToInt()
            maskFilter = BlurMaskFilter(RideMapGeometry.DotShadowBlur.dp.toPx(), BlurMaskFilter.Blur.NORMAL)
        }
        canvas.nativeCanvas.drawCircle(
            center.x,
            center.y + RideMapGeometry.DotShadowYOffset.dp.toPx(),
            radius,
            shadowPaint
        )
    }
    drawCircle(color, radius = radius, center = center)
}
