import SwiftUI

public struct LiiveProgressDots: View {
    let legs: Int
    let current: Int

    public init(legs: Int, current: Int) {
        self.legs = max(1, legs)
        self.current = min(max(1, current), max(1, legs))
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(1...legs, id: \.self) { index in
                Circle()
                    .fill(index <= current ? LiiveColor.accent : LiiveColor.fill)
                    .frame(width: 12, height: 12)
                if index < legs {
                    Rectangle()
                        .fill(index < current ? LiiveColor.accent : LiiveColor.fill)
                        .frame(height: 3)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
