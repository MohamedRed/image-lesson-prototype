//  LiiveBottomSheet.kt  ·  Liive Ride DS (Compose)  ·  mirrors components/ride/BottomSheet
//  The sheet content container that rises over the map. For a real modal use
//  Material3 ModalBottomSheet and place this content inside; this composable
//  is the styled body (rounded top, grabber, opaque surface, nav-bar inset).
package com.liive.ride.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.Dp

@Composable
fun LiiveBottomSheet(
    modifier: Modifier = Modifier,
    grabber: Boolean = true,
    padding: Dp? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val c = LiiveTheme.colors
    val sheetPadding = padding ?: LiiveBottomSheetLayout.ContentPadding
    Column(
        modifier
            .fillMaxWidth()
            .shadow(LiiveElevation.sheet, LiiveRadius.sheetTop, clip = false)
            .clip(LiiveRadius.sheetTop)
            .background(c.surfaceSheet)
            .padding(horizontal = sheetPadding)
            .padding(top = if (grabber) LiiveBottomSheetLayout.GrabberTopPadding else sheetPadding)
            .padding(bottom = sheetPadding)
            .navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        if (grabber) {
            Box(
                Modifier
                    .padding(bottom = LiiveBottomSheetLayout.GrabberBottomPadding)
                    .size(
                        width = LiiveBottomSheetLayout.GrabberWidth,
                        height = LiiveBottomSheetLayout.GrabberHeight
                    )
                    .clip(CircleShape)
                    .background(c.fill)
            )
        }
        Column(Modifier.fillMaxWidth(), content = content)
    }
}

private object LiiveBottomSheetLayout {
    val ContentPadding = LiiveSpacing.screenGutter
    val GrabberWidth = LiiveControl.sm + LiiveSpacing.xs
    val GrabberHeight = LiiveSpacing.xs + LiiveSpacing.xs2 / 2
    val GrabberTopPadding = LiiveSpacing.s
    val GrabberBottomPadding = LiiveSpacing.m + LiiveSpacing.xs2
}
