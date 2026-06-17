package com.liive.ride.ui

import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.liive.ride.designsystem.LiiveControl
import com.liive.ride.designsystem.LiiveSpacing

internal object RideSheetLayout {
    val hairlineHeight = 0.5.dp
    val selectedBorderWidth = 1.5.dp

    val compactGap = LiiveSpacing.xs2
    val inlineGap = LiiveSpacing.xs + LiiveSpacing.xs2
    val controlGap = LiiveSpacing.s
    val rowGap = LiiveSpacing.s + LiiveSpacing.xs2
    val headerBottomPadding = LiiveSpacing.m
    val sectionGap = LiiveSpacing.m + LiiveSpacing.xs2

    val searchHeight = LiiveControl.md + LiiveSpacing.xs2
    val searchHorizontalPadding = sectionGap
    val searchIconSize = LiiveSpacing.xl - LiiveSpacing.xs2

    val backButtonSize = LiiveControl.sm
    val backIconSize = LiiveSpacing.xl
    val savedPlaceIconSize = LiiveControl.md - LiiveSpacing.s
    val optionIconSize = LiiveControl.sm
    val paymentStatusIconSize = LiiveControl.md - LiiveSpacing.s
    val receiptIconSize = LiiveControl.xl

    val tierSpacing = LiiveSpacing.s
    val tierRowPadding = LiiveSpacing.m

    val matchingDotCount = 3
    val matchingDotSize = LiiveSpacing.s + LiiveSpacing.xs2 / 2
    val matchingDotLift = -(LiiveSpacing.s - LiiveSpacing.xs2 / 2)
    const val matchingDotDurationMs = 600
    const val matchingDotDelayMs = 160
    val matchingMetaFontSize = 14.sp
    val matchingDescriptionMaxWidth = 280.dp
    val matchingContentTopPadding = LiiveSpacing.s
    val matchingContentBottomPadding = LiiveSpacing.xxl - LiiveSpacing.xs2

    val multiLegPanelPadding = sectionGap
    val multiLegPanelTopPadding = LiiveSpacing.m
    val multiLegIconSize = LiiveSpacing.l
    val transferIconSize = LiiveSpacing.l - LiiveSpacing.xs2 / 2
    val progressSeparatorTrackHeight = LiiveSpacing.xs2 + LiiveSpacing.xs2 / 4

    val receiptContentVerticalPadding = rowGap
    val receiptButtonTopPadding = LiiveSpacing.xl
    val fareCardHorizontalPadding = sectionGap
    val fareCardTopPadding = LiiveSpacing.s
    val fareCardBottomPadding = sectionGap
    val paymentSectionGap = LiiveSpacing.m
    val securityCopyTopPadding = rowGap

    val ratingTopPadding = LiiveSpacing.m
    val ratingBottomPadding = LiiveSpacing.l
    val ratingStarSize = LiiveSpacing.xxxl - LiiveSpacing.xs
    val ratingStarPadding = LiiveSpacing.xs2

    val sosMessageTopPadding = rowGap
    val sosMessageBottomPadding = LiiveSpacing.xl - LiiveSpacing.xs2
    val sosButtonGap = LiiveSpacing.s
    val sosPanelPadding = LiiveSpacing.xxl - LiiveSpacing.xs2
    val sosPanelMaxWidth = 300.dp
}
