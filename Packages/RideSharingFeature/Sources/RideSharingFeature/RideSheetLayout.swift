import SwiftUI

enum RideSheetLayout {
    static let stackedSpacing: CGFloat = 0
    static let hairlineHeight: CGFloat = 0.5
    static let selectedBorderWidth: CGFloat = 1.5

    static let compactGap = LiiveSpacing.xs2
    static let inlineGap = LiiveSpacing.xs + LiiveSpacing.xs2
    static let controlGap = LiiveSpacing.s
    static let rowGap = LiiveSpacing.s + LiiveSpacing.xs2
    static let headerBottomPadding = LiiveSpacing.m
    static let sectionGap = LiiveSpacing.m + LiiveSpacing.xs2

    static let searchHeight = LiiveControl.md + LiiveSpacing.xs2
    static let searchHorizontalPadding = sectionGap
    static let searchIconSize = LiiveSpacing.xl - LiiveSpacing.xs2

    static let backButtonSize = LiiveControl.sm
    static let backIconSize = LiiveSpacing.xl
    static let savedPlaceIconSize = LiiveControl.md - LiiveSpacing.s
    static let optionIconSize = LiiveControl.sm
    static let paymentStatusIconSize = LiiveControl.md - LiiveSpacing.s
    static let receiptIconSize = LiiveControl.xl

    static let tierSpacing = LiiveSpacing.s
    static let tierRowPadding = LiiveSpacing.m

    static let matchingDotCount = 3
    static let matchingDotSize = LiiveSpacing.s + LiiveSpacing.xs2 / 2
    static let matchingDotLift = -(LiiveSpacing.s - LiiveSpacing.xs2 / 2)
    static let matchingDotDuration: Double = 0.6
    static let matchingDotDelay: Double = 0.16
    static let matchingDescriptionMaxWidth = LiiveControl.xl * maxWidthColumnCount
    static let matchingContentTopPadding = LiiveSpacing.s
    static let matchingContentBottomPadding = LiiveSpacing.xxl - LiiveSpacing.xs2

    static let multiLegPanelPadding = sectionGap
    static let multiLegPanelTopPadding = LiiveSpacing.m
    static let multiLegIconSize = LiiveSpacing.l
    static let transferIconSize = LiiveSpacing.l - LiiveSpacing.xs2 / 2
    static let transferSeparatorTopPadding = LiiveSpacing.xs2

    static let receiptContentVerticalPadding = rowGap
    static let receiptButtonTopPadding = LiiveSpacing.xl
    static let fareCardHorizontalPadding = sectionGap
    static let fareCardTopPadding = LiiveSpacing.s
    static let fareCardBottomPadding = sectionGap
    static let paymentSectionGap = LiiveSpacing.m
    static let securityCopyTopPadding = rowGap

    static let ratingBottomPadding = LiiveSpacing.l
    static let ratingStarSize = LiiveSpacing.xxxl - LiiveSpacing.xs
    static let ratingStarPadding = LiiveSpacing.xs2

    static let sosMessageTopPadding = rowGap
    static let sosMessageBottomPadding = LiiveSpacing.xl - LiiveSpacing.xs2
    static let sosButtonGap = LiiveSpacing.s
    static let sosPanelPadding = LiiveSpacing.xxl - LiiveSpacing.xs2
    static let sosPanelMaxWidth = matchingDescriptionMaxWidth + LiiveSpacing.xl

    private static let maxWidthColumnCount: CGFloat = 5
}
