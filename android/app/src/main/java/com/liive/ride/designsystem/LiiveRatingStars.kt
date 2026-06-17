//  LiiveRatingStars.kt  ·  Liive Ride DS (Compose)  ·  mirrors components/core/RatingStars
package com.liive.ride.designsystem

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.sp

@Composable
fun LiiveRatingStars(
    value: Double,
    max: Int = 5,
    size: Dp = LiiveSpacing.m + LiiveSpacing.xs2,
    showValue: Boolean = true
) {
    val c = LiiveTheme.colors
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(LiiveRatingStarsLayout.ValueSpacing)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(LiiveRatingStarsLayout.StarSpacing)) {
            for (i in 0 until max) {
                val fraction = (value - i).coerceIn(0.0, 1.0).toFloat()
                Box(Modifier.size(size)) {
                    Icon(painterResource(RideIcons.Star), null, tint = c.fill, modifier = Modifier.size(size))
                    Icon(painterResource(RideIcons.Star), null, tint = c.star,
                        modifier = Modifier.size(size).drawWithContent {
                            clipRect(right = this.size.width * fraction) { this@drawWithContent.drawContent() }
                        })
                }
            }
        }
        if (showValue) {
            Text(
                String.format("%.1f", value),
                color = c.text,
                style = MaterialTheme.typography.labelMedium.tabularNumbers().copy(
                    fontSize = (size.value - LiiveRatingStarsLayout.ValueFontDelta.value).sp,
                    fontWeight = FontWeight.SemiBold
                )
            )
        }
    }
}

private object LiiveRatingStarsLayout {
    val StarSpacing = LiiveSpacing.xs2 / 2
    val ValueSpacing = LiiveSpacing.xs + LiiveSpacing.xs2 / 2
    val ValueFontDelta = LiiveSpacing.xs2 / 2
}
