//  LiiveButton.swift
//  Liive Ride — sample component showing how DS tokens compose in SwiftUI.
//  Mirror this pattern for Badge, Card, ListRow, GlassPanel, SOSButton, etc.

import SwiftUI

public struct LiiveButton: View {
    public enum Variant { case primary, secondary, tinted, plain, destructive, destructivePlain }
    public enum Size { case sm, md, lg }
    public enum Shape { case rounded, capsule }

    let title: String
    var variant: Variant = .primary
    var size: Size = .md
    var shape: Shape = .rounded
    var fullWidth: Bool = false
    var icon: Image? = nil
    var iconRight: Image? = nil
    var iconOnly: Bool = false
    var accessibilityLabel: String? = nil
    var tabularNumbers: Bool = false
    var disabled: Bool = false
    var loading: Bool = false
    let action: () -> Void

    @GestureState private var pressed = false

    public init(_ title: String, variant: Variant = .primary, size: Size = .md,
                shape: Shape = .rounded, fullWidth: Bool = false, icon: Image? = nil,
                iconRight: Image? = nil, iconOnly: Bool = false, accessibilityLabel: String? = nil,
                tabularNumbers: Bool = false, disabled: Bool = false, loading: Bool = false,
                action: @escaping () -> Void) {
        self.title = title; self.variant = variant; self.size = size
        self.shape = shape; self.fullWidth = fullWidth; self.icon = icon
        self.iconRight = iconRight; self.iconOnly = iconOnly
        self.accessibilityLabel = accessibilityLabel; self.tabularNumbers = tabularNumbers
        self.disabled = disabled; self.loading = loading; self.action = action
    }

    private var height: CGFloat { size == .sm ? 32 : size == .lg ? 50 : 44 }
    private var bg: Color {
        if pressed { return bgPressed }
        switch variant {
        case .primary: return LiiveColor.accent
        case .secondary: return LiiveColor.fill
        case .tinted: return LiiveColor.accentTint
        case .plain, .destructivePlain: return .clear
        case .destructive: return LiiveColor.danger
        }
    }
    private var bgPressed: Color {
        switch variant {
        case .primary: return LiiveColor.accentPressed
        case .secondary: return LiiveColor.fillSecondary
        case .tinted: return LiiveColor.accentTint
        case .plain, .destructivePlain: return .clear
        case .destructive: return LiiveColor.danger
        }
    }
    private var fg: Color {
        switch variant {
        case .primary: return LiiveColor.onAccent
        case .secondary: return LiiveColor.text
        case .tinted: return LiiveColor.accent
        case .plain: return LiiveColor.accent
        case .destructive: return .white
        case .destructivePlain: return LiiveColor.danger
        }
    }
    private var radius: CGFloat { shape == .capsule ? LiiveRadius.full : LiiveRadius.md }
    private var isInteractive: Bool { !disabled && !loading }
    private var opacity: Double {
        if disabled { return 0.4 }
        if pressed {
            switch variant {
            case .plain, .tinted, .destructivePlain: return 0.5
            default: return 0.85
            }
        }
        return 1
    }

    public var body: some View {
        Button(action: { if isInteractive { action() } }) {
            HStack(spacing: LiiveSpacing.s) {
                if loading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(fg)
                        .frame(width: 18, height: 18)
                } else if iconOnly, let icon {
                    icon
                        .font(.system(size: 18, weight: .semibold))
                } else {
                    if let icon { icon }
                    Text(title)
                        .font(tabularNumbers ? LiiveFont.headline.monospacedDigit() : LiiveFont.headline)
                        .tracking(LiiveFont.Tracking.headline)
                    if let iconRight { iconRight }
                }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(width: iconOnly && !fullWidth ? height : nil)
            .frame(height: height)
            .padding(.horizontal, iconOnly ? 0 : size == .lg ? 22 : 18)
            .foregroundColor(fg)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .scaleEffect(pressed ? LiiveMotion.pressScale : 1)
            .opacity(opacity)
            .animation(.easeOut(duration: LiiveMotion.fast), value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(disabled || loading)
        .accessibilityLabel(Text(accessibilityLabel ?? title))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($pressed) { _, state, _ in
                    state = isInteractive
                }
        )
    }
}
