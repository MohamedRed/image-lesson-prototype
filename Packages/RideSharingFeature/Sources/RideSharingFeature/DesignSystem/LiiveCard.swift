import SwiftUI

public struct LiiveCard<Content: View>: View {
    var active: Bool
    var raised: Bool
    var padding: CGFloat
    let content: Content

    public init(active: Bool = false, raised: Bool = false, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
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
                    .strokeBorder(active ? LiiveColor.accent : .clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
            .shadow(
                color: active ? .clear : LiiveShadow.card.color,
                radius: active ? 0 : LiiveShadow.card.radius,
                x: LiiveShadow.card.x,
                y: LiiveShadow.card.y
            )
    }

    private var surfaceColor: Color {
        raised ? LiiveColor.surfaceRaised : LiiveColor.surface
    }
}
