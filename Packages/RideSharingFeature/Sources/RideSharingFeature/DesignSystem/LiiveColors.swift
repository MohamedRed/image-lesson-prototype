//  LiiveColors.swift
//  Liive Ride — "TIDE" brand color tokens (SwiftUI)
//  Dark-mode first; light is the adaptive companion.
//  Generated from the Liive Ride Design System (styles.css → semantic.css).

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension Color {
    /// Hex initializer (RGB or RGBA, "#RRGGBB" / "RRGGBBAA").
    init(hex: String, opacity: Double = 1) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 8 { s = String(s.prefix(6)) } // ignore packed alpha; use opacity:
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Dynamic (light/dark) color helper.
private func dyn(_ light: Color, _ dark: Color) -> Color {
    #if canImport(UIKit)
    Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
    })
    #else
    dark
    #endif
}

public enum LiiveColor {
    // MARK: Accent (aqua)
    public static let accent        = dyn(Color(hex: "17A98F"), Color(hex: "54E0C6"))
    public static let accentPressed = dyn(Color(hex: "0E8E78"), Color(hex: "2EC9AD"))
    public static let accentBright  = dyn(Color(hex: "2EC9AD"), Color(hex: "7FECD6"))
    public static let accentTint    = dyn(Color(hex: "17A98F", opacity: 0.12), Color(hex: "54E0C6", opacity: 0.15))
    public static let onAccent      = dyn(Color(hex: "FFFFFF"), Color(hex: "04161A"))

    // MARK: Status
    public static let success       = dyn(Color(hex: "16A36B"), Color(hex: "2FD08A"))
    public static let successTint   = dyn(Color(hex: "16A36B", opacity: 0.12), Color(hex: "2FD08A", opacity: 0.16))
    public static let warning       = dyn(Color(hex: "D99412"), Color(hex: "F5B83D"))
    public static let warningTint   = dyn(Color(hex: "D99412", opacity: 0.14), Color(hex: "F5B83D", opacity: 0.16))
    public static let danger        = dyn(Color(hex: "E5484D"), Color(hex: "FF5A5F"))
    public static let dangerTint    = dyn(Color(hex: "E5484D", opacity: 0.12), Color(hex: "FF5A5F", opacity: 0.16))
    public static let info          = dyn(Color(hex: "17A98F"), Color(hex: "7FECD6"))
    public static let star          = dyn(Color(hex: "E0A41F"), Color(hex: "F5C24B"))

    // MARK: Surfaces
    public static let bg            = dyn(Color(hex: "EEF3F4"), Color(hex: "07121A"))
    public static let surface       = dyn(Color(hex: "FFFFFF"), Color(hex: "0E1E2A"))
    public static let surfaceRaised = dyn(Color(hex: "FFFFFF"), Color(hex: "15293A"))
    public static let surfaceSheet  = dyn(Color(hex: "FFFFFF"), Color(hex: "0C1E2A"))

    // MARK: Fills
    public static let fill          = dyn(Color(hex: "466E7D", opacity: 0.14), Color(hex: "78A0AF", opacity: 0.20))
    public static let fillSecondary = dyn(Color(hex: "466E7D", opacity: 0.11), Color(hex: "78A0AF", opacity: 0.16))
    public static let fillTertiary  = dyn(Color(hex: "466E7D", opacity: 0.08), Color(hex: "78A0AF", opacity: 0.12))

    // MARK: Text
    public static let text          = dyn(Color(hex: "07121A"), Color(hex: "EAF4F4"))
    public static let textSecondary = dyn(Color(hex: "07121A", opacity: 0.58), Color(hex: "EAF4F4", opacity: 0.58))
    public static let textTertiary  = dyn(Color(hex: "07121A", opacity: 0.32), Color(hex: "EAF4F4", opacity: 0.32))
    public static let textQuaternary = dyn(Color(hex: "07121A", opacity: 0.20), Color(hex: "EAF4F4", opacity: 0.18))

    // MARK: Lines
    public static let separator     = dyn(Color(hex: "07121A", opacity: 0.12), Color(hex: "78AAB9", opacity: 0.18))

    // MARK: Map
    public static let mapBackground = dyn(Color(hex: "DCE7E8"), Color(hex: "0A1822"))
    public static let mapRoad       = dyn(Color(hex: "FFFFFF"), Color(hex: "15293A"))
    public static let mapWater      = dyn(Color(hex: "B6D9DC"), Color(hex: "0C2230"))
    public static let mapRoute      = accent
    public static let mapRouteWalk  = warning
}
