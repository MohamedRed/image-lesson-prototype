//  LiiveBottomSheet.swift  ·  Liive Ride DS (SwiftUI)
//  The sheet container that rises over the map: rounded top, grabber,
//  opaque surface, safe-area bottom inset. Drop your screen content inside.

import SwiftUI

public struct LiiveBottomSheet<Content: View>: View {
    var grabber: Bool = true
    var padding: CGFloat = 16
    let content: Content

    public init(grabber: Bool = true, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.grabber = grabber; self.padding = padding; self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            if grabber {
                Capsule().fill(LiiveColor.fill)
                    .frame(width: 36, height: 5)
                    .padding(.top, 8).padding(.bottom, 14)
            }
            content
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, padding)
        .padding(.bottom, padding + LiiveSpacing.safeBottom)
        .padding(.top, grabber ? 0 : padding)
        .background(LiiveColor.surfaceSheet)
        .clipShape(TopRoundedRectangle(radius: LiiveRadius.xxxl))
        .liiveShadow(.sheet)
    }
}

/// Rounds only the top two corners.
struct TopRoundedRectangle: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
