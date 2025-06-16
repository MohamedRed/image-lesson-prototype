import SwiftUI

/// Centralised palette and sizing constants for the Image-Lesson feature.
///
/// All views should prefer these values over hard-coding colours or numbers
/// so visual tweaks can be performed in one place.
public enum Theme {
    // MARK: - Colours

    // Using adaptive system colors to support Light and Dark Mode.
    public static let accent = Color.accentColor
    public static let destructive = Color.red
    public static let controlDisabled = Color.gray

    public static let overlay = Color.black.opacity(0.4)
    public static let mutedSurface = Color(uiColor: .systemGray6)
    public static let secondarySurface = Color(uiColor: .systemGray5)

    // MARK: - Sizing & Spacing
    public static let cornerRadius: CGFloat = 12
    public static let mainSpacing: CGFloat = 16
    public static let controlButtonSpacing: CGFloat = 10
    public static let visualizerHeightRatio: CGFloat = 0.3
    public static let contentControlSpacing: CGFloat = 100
}