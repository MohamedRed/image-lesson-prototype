package com.liive.ride.ui

import androidx.compose.ui.unit.dp
import com.liive.ride.designsystem.LiiveControl
import com.liive.ride.designsystem.LiiveSpacing

internal object RideChromeLayout {
    val topInset = LiiveSpacing.huge + LiiveSpacing.xl - LiiveSpacing.xs2
    val horizontalPadding = LiiveSpacing.screenGutter
    val glassPanelPadding = LiiveSpacing.xs2 - LiiveSpacing.xs2
    val badgeHorizontalPadding = LiiveSpacing.m
    val badgeVerticalPadding = LiiveSpacing.s - LiiveSpacing.xs2 / 2
    val placeholderSize = LiiveSpacing.xs2 / 2
    val buttonSpacing = LiiveSpacing.s
    val buttonSize = LiiveControl.md
    val buttonIconSize = LiiveSpacing.xl - LiiveSpacing.xs2 / 2
    val sosTopInset = topInset + buttonSize + LiiveSpacing.m + LiiveSpacing.xs2
    val sosEndPadding = LiiveSpacing.screenGutter
    val sosSize = LiiveControl.xl - LiiveSpacing.xs2
    val noticeTopInset = topInset + buttonSize + LiiveSpacing.l
    val noticeMaxWidth = 340.dp
    val noticeHorizontalPadding = LiiveSpacing.l
    val noticeVerticalPadding = LiiveSpacing.m
    val noticeTextGap = LiiveSpacing.xs
}
