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

    private var starCount: Int {
        Swift.max(0, max)
    }

    private var fillFraction: CGFloat {
        guard starCount > 0 else { return 0 }
        let rawFraction = value / Double(starCount)
        return CGFloat(Swift.min(1, Swift.max(0, rawFraction)))
    }

    private func row(_ color: Color) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<starCount, id: \.self) { _ in
                RatingStarShape()
                    .fill(color)
                    .frame(width: size, height: size)
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
                            Rectangle().frame(width: geo.size.width * fillFraction)
                        }
                    }
            }
            if showValue {
                Text(String(format: "%.1f", value))
                    .font(Font.custom(LiiveFont.family, size: size - 1).weight(.semibold).monospacedDigit())
                    .foregroundColor(LiiveColor.text)
            }
        }
    }
}

private struct RatingStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [
            CGPoint(x: 12.0, y: 2.0),
            CGPoint(x: 14.9, y: 8.3),
            CGPoint(x: 21.8, y: 9.1),
            CGPoint(x: 16.7, y: 13.8),
            CGPoint(x: 18.1, y: 20.6),
            CGPoint(x: 12.0, y: 17.8),
            CGPoint(x: 5.9, y: 21.4),
            CGPoint(x: 7.3, y: 14.6),
            CGPoint(x: 2.2, y: 9.9),
            CGPoint(x: 9.1, y: 9.1)
        ]

        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: scaled(first, in: rect))
        points.dropFirst().forEach { path.addLine(to: scaled($0, in: rect)) }
        path.closeSubpath()
        return path
    }

    private func scaled(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x / 24 * rect.width,
            y: rect.minY + point.y / 24 * rect.height
        )
    }
}
