import SwiftUI

public struct LiiveProgressDots: View {
    let legs: Int
    let current: Int

    public init(legs: Int, current: Int) {
        self.legs = min(max(1, legs), 3)
        self.current = max(1, current)
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(1...legs, id: \.self) { index in
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

        return VStack(spacing: 4) {
            Text("\(index)")
                .font(LiiveFont.caption1.weight(.bold).monospacedDigit())
                .foregroundColor(completed || active ? .white : LiiveColor.textTertiary)
                .frame(width: 24, height: 24)
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

        return VStack(spacing: 3) {
            Rectangle()
                .fill(passed ? LiiveColor.success : LiiveColor.fill)
                .frame(height: 2)
                .clipShape(Capsule())
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(passed ? LiiveColor.success : LiiveColor.warning)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, 11)
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
