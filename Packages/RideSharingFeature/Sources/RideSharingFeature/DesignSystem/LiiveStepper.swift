import SwiftUI

public struct LiiveStepper: View {
    let value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    public init(value: Int, range: ClosedRange<Int>, onChange: @escaping (Int) -> Void) {
        self.value = value
        self.range = range
        self.onChange = onChange
    }

    public var body: some View {
        HStack(spacing: LiiveStepperLayout.containerSpacing) {
            control(label: "\u{2212}", enabled: value > range.lowerBound) {
                onChange(max(range.lowerBound, value - 1))
            }
            Rectangle()
                .fill(LiiveColor.separator)
                .frame(width: LiiveStepperLayout.separatorWidth, height: LiiveStepperLayout.separatorHeight)
            control(label: "+", enabled: value < range.upperBound) {
                onChange(min(range.upperBound, value + 1))
            }
        }
        .background(LiiveColor.fillTertiary)
        .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.sm, style: .continuous))
    }

    private func control(label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Font.custom(LiiveFont.family, size: LiiveStepperLayout.controlFontSize).weight(.regular))
                .foregroundColor(enabled ? LiiveColor.text : LiiveColor.textQuaternary)
                .frame(width: LiiveStepperLayout.controlWidth, height: LiiveStepperLayout.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private enum LiiveStepperLayout {
    static let containerSpacing = CGFloat.zero
    static let separatorWidth = LiiveSpacing.xs2 / 2
    static let separatorHeight = LiiveSpacing.l + LiiveSpacing.xs2
    static let controlWidth = LiiveControl.md
    static let controlHeight = LiiveControl.sm
    static let controlFontSize = LiiveSpacing.xl
}
