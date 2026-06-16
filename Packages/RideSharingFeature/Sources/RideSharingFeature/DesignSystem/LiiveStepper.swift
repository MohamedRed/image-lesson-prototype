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
        HStack(spacing: 0) {
            control(label: "\u{2212}", enabled: value > range.lowerBound) {
                onChange(max(range.lowerBound, value - 1))
            }
            Rectangle()
                .fill(LiiveColor.separator)
                .frame(width: 1, height: 18)
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
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(enabled ? LiiveColor.text : LiiveColor.textQuaternary)
                .frame(width: 44, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
