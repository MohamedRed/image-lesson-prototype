import SwiftUI

public struct LiiveCard<Content: View>: View {
    var active: Bool
    var padding: CGFloat
    let content: Content

    public init(active: Bool = false, padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.active = active
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(LiiveColor.surfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous)
                    .strokeBorder(active ? LiiveColor.accent : .clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
            .liiveShadow(.card)
    }
}
