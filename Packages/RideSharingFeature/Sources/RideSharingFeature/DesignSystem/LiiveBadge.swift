//  LiiveBadge.swift  ·  Liive Ride DS (SwiftUI)
//  Capsule status/metadata badge. Mirrors components/core/Badge.

import SwiftUI

public struct LiiveBadge: View {
    public enum Color { case neutral, accent, success, warning, danger, info }
    let text: String
    var color: Color = .neutral
    var solid: Bool = false
    var dot: Bool = false

    public init(_ text: String, color: Color = .neutral, solid: Bool = false, dot: Bool = false) {
        self.text = text; self.color = color; self.solid = solid; self.dot = dot
    }

    private var fg: SwiftUI.Color {
        switch color {
        case .neutral: return LiiveColor.textSecondary
        case .accent: return LiiveColor.accent
        case .success: return LiiveColor.success
        case .warning: return LiiveColor.warning
        case .danger: return LiiveColor.danger
        case .info: return LiiveColor.info
        }
    }
    private var solidBg: SwiftUI.Color {
        switch color {
        case .neutral: return LiiveColor.fill
        case .accent: return LiiveColor.accent
        case .success: return LiiveColor.success
        case .warning: return LiiveColor.warning
        case .danger: return LiiveColor.danger
        case .info: return LiiveColor.info
        }
    }
    private var tintBg: SwiftUI.Color {
        switch color {
        case .neutral: return LiiveColor.fillTertiary
        case .accent: return LiiveColor.accentTint
        case .success: return LiiveColor.successTint
        case .warning: return LiiveColor.warningTint
        case .danger: return LiiveColor.dangerTint
        case .info: return LiiveColor.infoTint
        }
    }
    private var onSolid: SwiftUI.Color {
        (color == .warning || color == .info) ? .black : .white
    }

    public var body: some View {
        HStack(spacing: 5) {
            if dot {
                Circle().fill(solid ? onSolid : fg).frame(width: 7, height: 7)
            }
            Text(text)
                .font(LiiveFont.caption1.weight(.semibold))
        }
        .padding(.horizontal, 9).padding(.vertical, 3)
        .foregroundColor(solid ? onSolid : fg)
        .background(solid ? solidBg : tintBg)
        .clipShape(Capsule())
    }
}
