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
    let action: () -> Void

    @State private var pressed = false

    public init(_ title: String, variant: Variant = .primary, size: Size = .md,
                shape: Shape = .rounded, fullWidth: Bool = false, icon: Image? = nil,
                action: @escaping () -> Void) {
        self.title = title; self.variant = variant; self.size = size
        self.shape = shape; self.fullWidth = fullWidth; self.icon = icon; self.action = action
    }

    private var height: CGFloat { size == .sm ? 32 : size == .lg ? 50 : 44 }
    private var bg: Color {
        switch variant {
        case .primary: return LiiveColor.accent
        case .secondary: return LiiveColor.fill
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

    public var body: some View {
        Button(action: action) {
            HStack(spacing: LiiveSpacing.s) {
                if let icon { icon }
                Text(title)
                    .font(LiiveFont.headline)
                    .tracking(LiiveFont.Tracking.headline)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: height)
            .padding(.horizontal, size == .lg ? 22 : 18)
            .foregroundColor(fg)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .scaleEffect(pressed ? LiiveMotion.pressScale : 1)
            .opacity(pressed ? 0.85 : 1)
            .animation(.easeOut(duration: LiiveMotion.fast), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false })
    }
}

#Preview {
    ZStack {
        LiiveColor.bg.ignoresSafeArea()
        VStack(spacing: 12) {
            LiiveButton("Request Ride") {}
            LiiveButton("Call", variant: .tinted) {}
            LiiveButton("Confirm Pickup · $12.50", variant: .primary, size: .lg, shape: .capsule, fullWidth: true) {}
            LiiveButton("Cancel Ride", variant: .destructivePlain) {}
        }.padding()
    }
    .preferredColorScheme(.dark)
}
