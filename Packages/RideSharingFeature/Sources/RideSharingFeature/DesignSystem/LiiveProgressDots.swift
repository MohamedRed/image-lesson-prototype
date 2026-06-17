import SwiftUI

public struct LiiveProgressDots: View {
    let legs: Int
    let current: Int

    public init(legs: Int, current: Int) {
        self.legs = min(max(LiiveProgressDotsLayout.firstLeg, legs), LiiveProgressDotsLayout.maxLegs)
        self.current = max(LiiveProgressDotsLayout.firstLeg, current)
    }

    public var body: some View {
        HStack(alignment: .center, spacing: LiiveProgressDotsLayout.containerSpacing) {
            ForEach(LiiveProgressDotsLayout.firstLeg...legs, id: \.self) { index in
                leg(index)
                if index < legs {
                    transfer(after: index)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func leg(_ index: Int) -> some View {
        let completed = index < current
        let active = index == current

        return VStack(spacing: LiiveProgressDotsLayout.legGap) {
            Text("\(index)")
                .font(LiiveFont.caption1.weight(.bold).monospacedDigit())
                .foregroundColor(
                    completed || active ? LiiveProgressDotsLayout.activeTextColor : LiiveColor.textTertiary
                )
                .frame(width: LiiveProgressDotsLayout.legCircleSize, height: LiiveProgressDotsLayout.legCircleSize)
                .background(legColor(completed: completed, active: active))
                .clipShape(Circle())
            Text("Leg \(index)")
                .font(LiiveFont.caption2)
                .foregroundColor(LiiveColor.textSecondary)
        }
        .fixedSize()
    }

    private func transfer(after index: Int) -> some View {
        let passed = index < current

        return VStack(spacing: LiiveProgressDotsLayout.transferGap) {
            Rectangle()
                .fill(passed ? LiiveColor.success : LiiveColor.fill)
                .frame(height: LiiveProgressDotsLayout.connectorHeight)
                .clipShape(Capsule())
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: LiiveProgressDotsLayout.transferIconSize, weight: .bold))
                .foregroundColor(passed ? LiiveColor.success : LiiveColor.warning)
        }
        .frame(minWidth: LiiveProgressDotsLayout.transferMinWidth, maxWidth: .infinity)
        .padding(.bottom, LiiveProgressDotsLayout.transferBottomPadding)
    }

    private func legColor(completed: Bool, active: Bool) -> Color {
        if completed {
            return LiiveColor.success
        }
        if active {
            return LiiveColor.accent
        }
        return LiiveColor.fill
    }
}

private enum LiiveProgressDotsLayout {
    static let firstLeg = 1
    static let maxLegs = 3
    static let containerSpacing: CGFloat = 0
    static let legGap = LiiveSpacing.xs
    static let legCircleSize = LiiveSpacing.xxl
    static let transferGap = LiiveSpacing.xs - LiiveSpacing.xs2 / 2
    static let connectorHeight = LiiveSpacing.xs2
    static let transferIconSize = LiiveSpacing.m + LiiveSpacing.xs2 / 2
    static let transferMinWidth = LiiveSpacing.xxl + LiiveSpacing.xs
    static let transferBottomPadding = LiiveSpacing.l - LiiveSpacing.xs2 / 2
    static let activeTextColor = Color.white
}
