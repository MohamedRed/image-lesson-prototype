//  LiiveLayout.swift
//  Liive Ride — "TIDE" spacing, radii, sizing, shadows (SwiftUI)

import SwiftUI

public enum LiiveSpacing {
    public static let xs2: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16     // standard screen gutter
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
    public static let xxxl: CGFloat = 32
    public static let huge: CGFloat = 40

    public static let screenGutter: CGFloat = 16
    public static let touchMin: CGFloat = 44
    public static let safeTop: CGFloat = 44
    public static let safeBottom: CGFloat = 34
}

public enum LiiveRadius {
    public static let xs: CGFloat = 6
    public static let sm: CGFloat = 8     // chips / badges
    public static let md: CGFloat = 10    // buttons / inputs
    public static let lg: CGFloat = 12    // cards / HUD
    public static let xl: CGFloat = 16    // feature cards
    public static let xxl: CGFloat = 20   // sheets
    public static let xxxl: CGFloat = 28  // large sheet top
    public static let full: CGFloat = 999 // capsule
}

public enum LiiveControl {
    public static let sm: CGFloat = 32
    public static let md: CGFloat = 44
    public static let lg: CGFloat = 50    // prominent CTA
    public static let xl: CGFloat = 56
}

/// Elevation shadows (color, radius, x, y).
public struct LiiveShadow {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public static let card   = LiiveShadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
    public static let hud    = LiiveShadow(color: .black.opacity(0.28), radius: 20, x: 0, y: 6)
    public static let pin    = LiiveShadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
    public static let sheet  = LiiveShadow(color: .black.opacity(0.30), radius: 30, x: 0, y: -8)
    public static let sos    = LiiveShadow(color: Color(hex: "FF5A5F").opacity(0.45), radius: 18, x: 0, y: 6)
}

public extension View {
    func liiveShadow(_ s: LiiveShadow) -> some View {
        shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

/// Motion. iOS spring-like; quick & subtle.
public enum LiiveMotion {
    public static let fast: Double = 0.15
    public static let base: Double = 0.25
    public static let slow: Double = 0.40
    public static let pressScale: CGFloat = 0.96
    public static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
}
