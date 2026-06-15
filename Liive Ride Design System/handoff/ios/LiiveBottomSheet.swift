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
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight],
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}
