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
        HStack(spacing: 10) {
            control(systemName: "minus", enabled: value > range.lowerBound) {
                onChange(max(range.lowerBound, value - 1))
            }
            Text("\(value)")
                .font(LiiveFont.headline.monospacedDigit())
                .foregroundColor(LiiveColor.text)
                .frame(width: 20)
            control(systemName: "plus", enabled: value < range.upperBound) {
                onChange(min(range.upperBound, value + 1))
            }
        }
    }

    private func control(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(enabled ? LiiveColor.text : LiiveColor.textQuaternary)
                .frame(width: 30, height: 30)
                .background(enabled ? LiiveColor.fill : LiiveColor.fillTertiary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
