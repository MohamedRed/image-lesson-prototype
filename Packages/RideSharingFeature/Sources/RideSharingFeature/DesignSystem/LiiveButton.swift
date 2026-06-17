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

    private var height: CGFloat {
        switch size {
        case .sm: return LiiveButtonLayout.smallHeight
        case .md: return LiiveButtonLayout.mediumHeight
        case .lg: return LiiveButtonLayout.largeHeight
        }
    }
    private var horizontalPadding: CGFloat {
        switch size {
        case .sm: return LiiveButtonLayout.smallHorizontalPadding
        case .md: return LiiveButtonLayout.mediumHorizontalPadding
        case .lg: return LiiveButtonLayout.largeHorizontalPadding
        }
    }
    private var titleFont: Font {
        size == .sm ? LiiveFont.subhead : LiiveFont.headline
    }
    private var titleWeight: Font.Weight {
        switch variant {
        case .plain, .destructivePlain: return .regular
        default: return .semibold
        }
    }
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
        case .destructive: return LiiveButtonLayout.destructiveForegroundColor
        case .destructivePlain: return LiiveColor.danger
        }
    }
    private var radius: CGFloat { shape == .capsule ? LiiveRadius.full : LiiveRadius.md }
    private var isInteractive: Bool { !disabled && !loading }
    private var opacity: Double {
        if disabled { return LiiveButtonLayout.disabledOpacity }
        if pressed {
            switch variant {
            case .plain, .tinted, .destructivePlain: return LiiveButtonLayout.subtlePressedOpacity
            default: return LiiveButtonLayout.filledPressedOpacity
            }
        }
        return LiiveButtonLayout.enabledOpacity
    }

    public var body: some View {
        Button(action: { if isInteractive { action() } }) {
            HStack(spacing: LiiveButtonLayout.contentGap) {
                if loading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(fg)
                        .frame(width: LiiveButtonLayout.spinnerSize, height: LiiveButtonLayout.spinnerSize)
                } else if iconOnly, let icon {
                    icon
                        .font(.system(size: LiiveButtonLayout.iconSize, weight: .semibold))
                } else {
                    if let icon { icon }
                    Text(title)
                        .font((tabularNumbers ? titleFont.monospacedDigit() : titleFont).weight(titleWeight))
                        .tracking(LiiveFont.Tracking.title3)
                    if let iconRight { iconRight }
                }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(width: iconOnly && !fullWidth ? height : nil)
            .frame(height: height)
            .padding(.horizontal, iconOnly ? LiiveButtonLayout.iconOnlyHorizontalPadding : horizontalPadding)
            .foregroundColor(fg)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .scaleEffect(pressed ? LiiveMotion.pressScale : LiiveButtonLayout.restingScale)
            .opacity(opacity)
            .animation(.easeOut(duration: LiiveMotion.fast), value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(disabled || loading)
        .accessibilityLabel(Text(accessibilityLabel ?? title))
        .simultaneousGesture(
            DragGesture(minimumDistance: LiiveButtonLayout.dragMinimumDistance)
                .updating($pressed) { _, state, _ in
                    state = isInteractive
                }
        )
    }
}

private enum LiiveButtonLayout {
    static let smallHeight = LiiveControl.sm
    static let mediumHeight = LiiveControl.md
    static let largeHeight = LiiveControl.lg
    static let smallHorizontalPadding = LiiveSpacing.m + LiiveSpacing.xs2
    static let mediumHorizontalPadding = LiiveSpacing.l + LiiveSpacing.xs2
    static let largeHorizontalPadding = LiiveSpacing.xxl - LiiveSpacing.xs2
    static let iconOnlyHorizontalPadding = LiiveSpacing.xs2 - LiiveSpacing.xs2
    static let contentGap = LiiveSpacing.s
    static let iconSize = LiiveSpacing.l + LiiveSpacing.xs2
    static let spinnerSize = iconSize
    static let disabledOpacity = 0.4
    static let subtlePressedOpacity = 0.5
    static let filledPressedOpacity = 0.85
    static let enabledOpacity = 1.0
    static let restingScale: CGFloat = 1.0
    static let dragMinimumDistance = LiiveSpacing.xs2 - LiiveSpacing.xs2
    static let destructiveForegroundColor = Color.white
}
