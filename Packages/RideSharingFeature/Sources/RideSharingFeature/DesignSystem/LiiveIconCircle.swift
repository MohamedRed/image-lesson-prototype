//  LiiveIconCircle.swift  ·  Liive Ride DS (SwiftUI)
//  Tinted circular icon badge. Mirrors components/core/IconCircle.

import SwiftUI

public struct LiiveIconCircle: View {
    public enum Color { case accent, success, warning, danger, info, neutral }
    let systemName: String
    var color: Color = .accent
    var size: CGFloat = LiiveControl.md
    var filled: Bool = false

    public init(
        systemName: String,
        color: Color = .accent,
        size: CGFloat = LiiveControl.md,
        filled: Bool = false
    ) {
        self.systemName = systemName; self.color = color; self.size = size; self.filled = filled
    }

    private var fg: SwiftUI.Color {
        switch color {
        case .accent: return LiiveColor.accent
        case .success: return LiiveColor.success
        case .warning: return LiiveColor.warning
        case .danger: return LiiveColor.danger
        case .info: return LiiveColor.info
        case .neutral: return LiiveColor.textSecondary
        }
    }
    private var solid: SwiftUI.Color {
        switch color {
        case .accent: return LiiveColor.accent
        case .success: return LiiveColor.success
        case .warning: return LiiveColor.warning
        case .danger: return LiiveColor.danger
        case .info: return LiiveColor.info
        case .neutral: return LiiveColor.fill
        }
    }
    private var tint: SwiftUI.Color {
        switch color {
        case .accent: return LiiveColor.accentTint
        case .success: return LiiveColor.successTint
        case .warning: return LiiveColor.warningTint
        case .danger: return LiiveColor.dangerTint
        case .info: return LiiveColor.infoTint
        case .neutral: return LiiveColor.fillTertiary
        }
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * LiiveIconCircleLayout.iconScale, weight: .semibold))
            .foregroundColor(filled ? LiiveIconCircleLayout.filledForegroundColor : fg)
            .frame(width: size, height: size)
            .background(filled ? solid : tint)
            .clipShape(Circle())
    }
}

private enum LiiveIconCircleLayout {
    static let iconScale: CGFloat = 0.45
    static let filledForegroundColor = SwiftUI.Color.white
}
