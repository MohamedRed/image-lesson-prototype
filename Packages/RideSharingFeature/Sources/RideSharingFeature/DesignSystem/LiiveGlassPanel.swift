//  LiiveGlassPanel.swift  ·  Liive Ride DS (SwiftUI)
//  Frosted-glass panel that floats over the map (.ultraThin/.thin/.thick).

import SwiftUI

public struct LiiveGlassPanel<Content: View>: View {
    public enum Material { case thin, regular, thick }
    var material: Material = .regular
    var cornerRadius: CGFloat = LiiveRadius.lg
    var padding: CGFloat = LiiveSpacing.m + LiiveSpacing.xs2
    let content: Content

    public init(material: Material = .regular, cornerRadius: CGFloat = LiiveRadius.lg,
                padding: CGFloat = LiiveSpacing.m + LiiveSpacing.xs2, @ViewBuilder content: () -> Content) {
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

    private var materialFill: Color {
        switch material {
        case .thin: return LiiveColor.materialThin
        case .regular: return LiiveColor.materialRegular
        case .thick: return LiiveColor.materialThick
        }
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(padding)
            .background(materialFill, in: shape)
            .background(blur, in: shape)
            .overlay(
                shape.strokeBorder(LiiveColor.borderStrong, lineWidth: LiiveSpacing.xs2 / 4)
            )
            .liiveShadow(.hud)
    }
}
