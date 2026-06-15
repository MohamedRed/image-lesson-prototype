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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@Composable
fun LiiveBottomSheet(
    modifier: Modifier = Modifier,
    grabber: Boolean = true,
    padding: Dp = 16.dp,
    content: @Composable ColumnScope.() -> Unit
) {
    val c = LiiveTheme.colors
    Column(
        modifier
            .fillMaxWidth()
            .clip(LiiveRadius.sheetTop)
            .background(c.surfaceSheet)
            .padding(horizontal = padding)
            .padding(top = if (grabber) 8.dp else padding)
            .padding(bottom = padding)
            .navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        if (grabber) {
            Box(Modifier.padding(bottom = 14.dp).size(width = 36.dp, height = 5.dp)
                .clip(CircleShape).background(c.fill))
        }
        Column(Modifier.fillMaxWidth(), content = content)
    }
}
