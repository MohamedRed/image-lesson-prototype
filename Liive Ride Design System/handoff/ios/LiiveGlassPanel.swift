//  LiiveGlassPanel.swift  ·  Liive Ride DS (SwiftUI)
//  Frosted-glass panel that floats over the map (.ultraThin/.thin/.thick).

import SwiftUI

public struct LiiveGlassPanel<Content: View>: View {
    public enum Material { case thin, regular, thick }
    var material: Material = .regular
    var cornerRadius: CGFloat = LiiveRadius.lg
    var padding: CGFloat = 14
    let content: Content

    public init(material: Material = .regular, cornerRadius: CGFloat = LiiveRadius.lg,
                padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.material = material; self.cornerRadius = cornerRadius
        self.padding = padding; self.content = content()
    }

    private var blur: SwiftUI.Material {
        switch material {
        case .thin: return .ultraThinMaterial
        case .regular: return .thinMaterial
        case .thick: return .regularMaterial
        }
    }

    public var body: some View {
        content
            .padding(padding)
            .background(blur, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LiiveColor.separator, lineWidth: 0.5)
            )
            .liiveShadow(.hud)
    }
}
