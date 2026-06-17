package com.liive.ride.ui

import com.liive.ride.designsystem.LiiveControl
import com.liive.ride.designsystem.LiiveSpacing
import com.liive.ride.designsystem.LiiveStroke

internal object RideSheetLayout {
    val hairlineHeight = LiiveStroke.hairline
    val selectedBorderWidth = LiiveStroke.active

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
    val matchingDescriptionMaxWidth = LiiveControl.xl * MaxWidthColumnCount
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
    val sosPanelMaxWidth = matchingDescriptionMaxWidth + LiiveSpacing.xl

    private const val MaxWidthColumnCount = 5f
}
