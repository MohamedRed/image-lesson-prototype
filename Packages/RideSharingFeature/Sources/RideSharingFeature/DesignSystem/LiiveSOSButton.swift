//  LiiveSOSButton.swift  ·  Liive Ride DS (SwiftUI)
//  Always-reachable emergency control: coral disc + continuous pulse halo,
//  press-shrink. onActivate should present a confirm dialog before dialing.

import SwiftUI

public struct LiiveSOSButton: View {
    var size: CGFloat = LiiveControl.xl + LiiveSpacing.s
    var showLabel: Bool = true
    let onActivate: () -> Void

    @State private var pressed = false
    @State private var pulse = false

    public init(
        size: CGFloat = LiiveControl.xl + LiiveSpacing.s,
        showLabel: Bool = true,
        onActivate: @escaping () -> Void
    ) {
        self.size = size; self.showLabel = showLabel; self.onActivate = onActivate
    }

    public var body: some View {
        Button(action: onActivate) {
            ZStack {
                Circle()
                    .fill(LiiveColor.danger)
                    .scaleEffect(pulse ? LiiveSOSButtonLayout.pulseScale : LiiveSOSButtonLayout.restingScale)
                    .opacity(pulse ? LiiveSOSButtonLayout.pulseEndOpacity : LiiveSOSButtonLayout.pulseStartOpacity)
                Circle().fill(LiiveColor.danger).liiveShadow(.sos)
                VStack(spacing: LiiveSOSButtonLayout.labelGap) {
                    Text("SOS").font(.system(size: size * LiiveSOSButtonLayout.sosTextScale, weight: .bold, design: .rounded))
                    if showLabel {
                        Text("HELP").font(.system(size: size * LiiveSOSButtonLayout.helpTextScale, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(LiiveSOSButtonLayout.helpTextOpacity))
                            .tracking(LiiveSOSButtonLayout.helpLetterSpacing)
                    }
                }
                .foregroundColor(LiiveSOSButtonLayout.foregroundColor)
            }
            .frame(width: size, height: size)
            .scaleEffect(pressed ? LiiveSOSButtonLayout.pressedScale : LiiveSOSButtonLayout.restingScale)
            .animation(.easeOut(duration: LiiveMotion.fast), value: pressed)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Emergency SOS"))
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }.onEnded { _ in pressed = false })
        .onAppear {
            withAnimation(.easeOut(duration: LiiveSOSButtonLayout.pulseDuration).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

private enum LiiveSOSButtonLayout {
    static let labelGap = LiiveSpacing.xs2 / 2
    static let restingScale: CGFloat = 1.0
    static let pressedScale: CGFloat = 0.94
    static let pulseScale: CGFloat = 1.5
    static let pulseStartOpacity = 0.35
    static let pulseEndOpacity = 0.0
    static let pulseDuration = LiiveMotion.slow + LiiveMotion.slow + LiiveMotion.slow + LiiveMotion.base + LiiveMotion.fast
    static let sosTextScale: CGFloat = 0.28
    static let helpTextScale: CGFloat = 0.15
    static let helpTextOpacity = 0.9
    static let helpLetterSpacing = LiiveSpacing.xs2 / 4
    static let foregroundColor = Color.white
}
