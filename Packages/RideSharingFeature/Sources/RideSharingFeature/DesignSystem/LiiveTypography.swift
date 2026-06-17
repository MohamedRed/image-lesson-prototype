//  LiiveTypography.swift
//  Liive Ride — "TIDE" type tokens (SwiftUI)
//  Typeface: Schibsted Grotesk.

import SwiftUI

public enum LiiveFont {
    /// Family name as registered by the bundled Schibsted Grotesk TTFs.
    public static let family = "Schibsted Grotesk"

    private static func sg(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        Font.custom(family, size: size).weight(weight)
    }

    // Text styles  (size / line-height pt / tracking pt)
    public static let largeTitle = sg(34, .bold)      // line 40, tracking -0.8
    public static let title1     = sg(28, .bold)      // line 34, tracking -0.6
    public static let title2     = sg(22, .bold)      // line 28, tracking -0.5
    public static let title3     = sg(20, .semibold)  // line 25, tracking -0.4
    public static let headline   = sg(17, .semibold)  // line 22, tracking -0.3
    public static let body       = sg(17, .regular)   // line 22, tracking -0.2
    public static let callout    = sg(16, .regular)
    public static let subhead    = sg(15, .regular)
    public static let sheetMeta  = sg(14, .regular)
    public static let sheetMetaSemibold = sg(14, .semibold)
    public static let footnote   = sg(13, .regular)
    public static let caption1   = sg(12, .regular)
    public static let caption2   = sg(11, .regular)

    /// Tracking (letter-spacing) in points, apply via `.tracking(_:)`.
    public enum Tracking {
        public static let largeTitle: CGFloat = -0.8
        public static let title1: CGFloat = -0.6
        public static let title2: CGFloat = -0.5
        public static let title3: CGFloat = -0.4
        public static let headline: CGFloat = -0.3
        public static let body: CGFloat = -0.2
    }
}

// Convenience modifiers: `Text("…").liiveStyle(.title2)`
public extension Text {
    enum LiiveTextStyle { case largeTitle, title1, title2, title3, headline, body, callout, subhead, footnote, caption1, caption2 }

    func liiveStyle(_ style: LiiveTextStyle) -> some View {
        switch style {
        case .largeTitle: return self.font(LiiveFont.largeTitle).tracking(LiiveFont.Tracking.largeTitle)
        case .title1:     return self.font(LiiveFont.title1).tracking(LiiveFont.Tracking.title1)
        case .title2:     return self.font(LiiveFont.title2).tracking(LiiveFont.Tracking.title2)
        case .title3:     return self.font(LiiveFont.title3).tracking(LiiveFont.Tracking.title3)
        case .headline:   return self.font(LiiveFont.headline).tracking(LiiveFont.Tracking.headline)
        case .body:       return self.font(LiiveFont.body).tracking(LiiveFont.Tracking.body)
        case .callout:    return self.font(LiiveFont.callout)
        case .subhead:    return self.font(LiiveFont.subhead)
        case .footnote:   return self.font(LiiveFont.footnote)
        case .caption1:   return self.font(LiiveFont.caption1)
        case .caption2:   return self.font(LiiveFont.caption2)
        }
    }
}
