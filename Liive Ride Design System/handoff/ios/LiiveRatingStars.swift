//  LiiveRatingStars.swift  ·  Liive Ride DS (SwiftUI)
//  Compact star rating with fractional fill + optional numeric value.

import SwiftUI

public struct LiiveRatingStars: View {
    let value: Double
    var max: Int = 5
    var size: CGFloat = 14
    var showValue: Bool = true

    public init(value: Double, max: Int = 5, size: CGFloat = 14, showValue: Bool = true) {
        self.value = value; self.max = max; self.size = size; self.showValue = showValue
    }

    private func row(_ color: Color) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<max, id: \.self) { _ in
                Image(systemName: "star.fill").font(.system(size: size)).foregroundColor(color)
            }
        }
    }

    public var body: some View {
        HStack(spacing: 5) {
            ZStack(alignment: .leading) {
                row(LiiveColor.fill)
                row(LiiveColor.star)
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * CGFloat(min(1, value / Double(max))))
                        }
                    }
            }
            if showValue {
                Text(String(format: "%.1f", value))
                    .font(.system(size: size - 1, weight: .semibold).monospacedDigit())
                    .foregroundColor(LiiveColor.text)
            }
        }
    }
}
