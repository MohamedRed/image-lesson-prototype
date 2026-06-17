import SwiftUI

enum RideChromeLayout {
    static let topInset = LiiveSpacing.safeTop + LiiveSpacing.m + LiiveSpacing.xs2
    static let horizontalPadding = LiiveSpacing.screenGutter
    static let badgeHorizontalPadding = LiiveSpacing.m
    static let badgeVerticalPadding = LiiveSpacing.s - LiiveSpacing.xs2 / 2
    static let placeholderSize = LiiveSpacing.xs2 / 2
    static let buttonSpacing = LiiveSpacing.s
    static let buttonSize = LiiveControl.md
    static let buttonIconSize = LiiveSpacing.xl - LiiveSpacing.xs2 / 2
    static let buttonIconWeight = Font.Weight.semibold
    static let sosTopInset = topInset + buttonSize + LiiveSpacing.m + LiiveSpacing.xs2
    static let sosTrailingPadding = LiiveSpacing.screenGutter
    static let sosSize = LiiveControl.xl - LiiveSpacing.xs2
}
