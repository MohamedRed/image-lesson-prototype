import SwiftUI

public struct LiiveCard<Content: View>: View {
    var active: Bool
    var raised: Bool
    var padding: CGFloat
    let content: Content

    public init(
        active: Bool = false,
        raised: Bool = false,
        padding: CGFloat = LiiveSpacing.l,
        @ViewBuilder content: () -> Content
    ) {
        self.active = active
        self.raised = raised
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(surfaceColor)
            .overlay(
                RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous)
                    .strokeBorder(active ? LiiveColor.accent : .clear, lineWidth: LiiveCardLayout.strokeWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
            .shadow(
                color: active ? .clear : LiiveShadow.card.color,
                radius: active ? LiiveCardLayout.activeShadowRadius : LiiveShadow.card.radius,
                x: LiiveShadow.card.x,
                y: LiiveShadow.card.y
            )
    }

    private var surfaceColor: Color {
        raised ? LiiveColor.surfaceRaised : LiiveColor.surface
    }
}

private enum LiiveCardLayout {
    static let strokeWidth = LiiveSpacing.xs2 - LiiveSpacing.xs2 / 4
    static let activeShadowRadius = CGFloat.zero
}
