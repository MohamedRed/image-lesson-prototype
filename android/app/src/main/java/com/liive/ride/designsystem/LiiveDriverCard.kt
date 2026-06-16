//  LiiveDriverCard.kt  ·  Liive Ride DS (Compose)  ·  mirrors components/ride/DriverCard
//  Composes LiiveAvatar + LiiveRatingStars.
package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun LiiveDriverCard(
    name: String,
    rating: Double? = null,
    vehicle: String? = null,
    plate: String? = null,
    eta: String? = null,
    speaking: Boolean = false,
    avatarPainter: Painter? = null,
    trailing: @Composable (() -> Unit)? = null,
) {
    val c = LiiveTheme.colors
    Row(
        Modifier
            .shadow(LiiveElevation.card, LiiveRadius.lg)
            .clip(LiiveRadius.lg)
            .background(c.surface)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        LiiveAvatar(name = name, size = 54.dp, ring = speaking, image = avatarPainter)
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(name, color = c.text, style = MaterialTheme.typography.titleLarge)
                if (rating != null) LiiveRatingStars(value = rating, size = 13.dp)
            }
            if (vehicle != null || plate != null) {
                val vehicleStyle = MaterialTheme.typography.titleMedium.copy(fontSize = 14.sp)
                Row(Modifier.fillMaxWidth().padding(top = 2.dp)) {
                    if (vehicle != null) {
                        Text(
                            vehicle,
                            color = c.textSecondary,
                            style = vehicleStyle,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f, fill = false)
                        )
                    }
                    if (vehicle != null && plate != null) {
                        Text(" · ", color = c.textSecondary, style = vehicleStyle)
                    }
                    if (plate != null) {
                        Text(
                            plate,
                            color = c.text,
                            fontWeight = FontWeight.SemiBold,
                            style = vehicleStyle.copy(letterSpacing = 0.5.sp),
                            maxLines = 1
                        )
                    }
                }
            }
        }
        if (eta != null) {
            Column(horizontalAlignment = Alignment.End) {
                Text(eta, color = c.accent, style = MaterialTheme.typography.headlineMedium.tabularNumbers())
                Text("away", color = c.textSecondary, style = MaterialTheme.typography.labelSmall)
            }
        }
        trailing?.invoke()
    }
}
