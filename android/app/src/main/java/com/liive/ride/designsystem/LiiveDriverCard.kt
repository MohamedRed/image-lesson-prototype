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
            .padding(LiiveDriverCardLayout.CardPadding),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(LiiveDriverCardLayout.RowSpacing)
    ) {
        LiiveAvatar(name = name, size = LiiveDriverCardLayout.AvatarSize, ring = speaking, image = avatarPainter)
        Column(Modifier.weight(1f)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(LiiveDriverCardLayout.TitleRatingSpacing)
            ) {
                Text(
                    name,
                    color = c.text,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false)
                )
                if (rating != null) LiiveRatingStars(value = rating, size = LiiveDriverCardLayout.RatingStarSize)
            }
            if (vehicle != null || plate != null) {
                Row(Modifier.fillMaxWidth().padding(top = LiiveDriverCardLayout.SecondaryLineTopPadding)) {
                    if (vehicle != null) {
                        Text(
                            vehicle,
                            color = c.textSecondary,
                            style = LiiveSheetMeta,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f, fill = false)
                        )
                    }
                    if (vehicle != null && plate != null) {
                        Text(" · ", color = c.textSecondary, style = LiiveSheetMeta)
                    }
                    if (plate != null) {
                        Text(
                            plate,
                            color = c.text,
                            fontWeight = FontWeight.SemiBold,
                            style = LiiveSheetMeta.copy(letterSpacing = LiiveDriverCardLayout.PlateLetterSpacing),
                            maxLines = 1
                        )
                    }
                }
            }
        }
        if (eta != null) {
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(LiiveDriverCardLayout.TextSpacing)
            ) {
                Text(eta, color = c.accent, style = MaterialTheme.typography.headlineMedium.tabularNumbers())
                Text("away", color = c.textSecondary, style = MaterialTheme.typography.labelSmall)
            }
        }
        trailing?.invoke()
    }
}

private object LiiveDriverCardLayout {
    val RowSpacing = LiiveSpacing.s + LiiveSpacing.xs2
    val TitleRatingSpacing = LiiveSpacing.s
    val TextSpacing = LiiveSpacing.xs2
    val AvatarSize = LiiveControl.lg + LiiveSpacing.xs2
    val RatingStarSize = LiiveSpacing.m + LiiveSpacing.xs2 / 2
    val SecondaryLineTopPadding = LiiveSpacing.xs2
    val PlateLetterSpacing = (LiiveSpacing.xs2.value / 4).sp
    val CardPadding = RowSpacing
}
