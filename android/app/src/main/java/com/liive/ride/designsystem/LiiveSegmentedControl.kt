//  LiiveSegmentedControl.kt
//  Liive Ride - "TIDE" segmented control (Jetpack Compose)
package com.liive.ride.designsystem

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp

data class LiiveSegment<T>(
    val value: T,
    val label: String,
)

@Composable
fun <T> LiiveSegmentedControl(
    options: List<LiiveSegment<T>>,
    selected: T,
    onSelected: (T) -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LiiveTheme.colors

    if (options.isNotEmpty()) {
        val selectedIndex = options.indexOfFirst { it.value == selected }.let { if (it < 0) 0 else it }

        BoxWithConstraints(
            modifier = modifier
                .fillMaxWidth()
                .clip(LiiveRadius.sm)
                .background(c.fillTertiary)
                .padding(LiiveSegmentedControlLayout.ContainerInset),
        ) {
            val segmentWidth = maxWidth / options.size.toFloat()
            val selectedOffset by animateDpAsState(
                targetValue = segmentWidth * selectedIndex.toFloat(),
                animationSpec = tween(
                    durationMillis = LiiveMotion.baseMs,
                    easing = LiiveMotion.easeOut,
                ),
                label = "LiiveSegmentedControlPillOffset",
            )

            Box(Modifier.matchParentSize()) {
                Box(
                    Modifier
                        .offset(x = selectedOffset)
                        .width(segmentWidth)
                        .fillMaxHeight()
                        .shadow(
                            LiiveElevation.small,
                            LiiveSegmentedControlLayout.SelectedPillShape,
                            clip = false
                        )
                        .clip(LiiveSegmentedControlLayout.SelectedPillShape)
                        .background(c.surfaceRaised),
                )
            }

            Row(Modifier.fillMaxWidth()) {
                options.forEach { option ->
                    val isSelected = option.value == selected
                    val interactionSource = remember(option.value) { MutableInteractionSource() }

                    Text(
                        text = option.label,
                        color = if (isSelected) c.text else c.textSecondary,
                        style = MaterialTheme.typography.titleMedium.copy(
                            fontSize = LiiveSegmentedControlLayout.SegmentFontSize,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                            lineHeight = LiiveSegmentedControlLayout.SegmentLineHeight,
                            letterSpacing = LiiveSegmentedControlLayout.SegmentLetterSpacing,
                        ),
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier
                            .weight(1f)
                            .clip(LiiveRadius.sm)
                            .clickable(
                                interactionSource = interactionSource,
                                indication = null,
                            ) { onSelected(option.value) }
                            .padding(
                                horizontal = LiiveSegmentedControlLayout.SegmentHorizontalPadding,
                                vertical = LiiveSegmentedControlLayout.SegmentVerticalPadding
                            ),
                    )
                }
            }
        }
    }
}

private object LiiveSegmentedControlLayout {
    val SegmentFontSize = (LiiveSpacing.m + LiiveSpacing.xs2).value.sp
    val SegmentLineHeight = (LiiveSpacing.l + LiiveSpacing.xs2 / 2).value.sp
    val SegmentLetterSpacing = (LiiveSpacing.xs2 - LiiveSpacing.xs2).value.sp
    val SegmentHorizontalPadding = LiiveSpacing.m
    val SegmentVerticalPadding = LiiveSpacing.s - LiiveSpacing.xs2 / 2
    val ContainerInset = LiiveSpacing.xs2
    val SelectedPillShape = RoundedCornerShape(LiiveSpacing.s - LiiveSpacing.xs2 / 2)
}
