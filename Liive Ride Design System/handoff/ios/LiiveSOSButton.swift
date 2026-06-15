//  LiiveSOSButton.swift  ·  Liive Ride DS (SwiftUI)
//  Always-reachable emergency control: coral disc + continuous pulse halo,
//  press-shrink. onActivate should present a confirm dialog before dialing.

import SwiftUI

public struct LiiveSOSButton: View {
    var size: CGFloat = 64
    var showLabel: Bool = true
    let onActivate: () -> Void

    @State private var pressed = false
    @State private var pulse = false

    public init(size: CGFloat = 64, showLabel: Bool = true, onActivate: @escaping () -> Void) {
        self.size = size; self.showLabel = showLabel; self.onActivate = onActivate
    }

    public var body: some View {
        Button(action: onActivate) {
            ZStack {
                Circle()
                    .fill(LiiveColor.danger)
                    .opacity(0.35)
                    .scaleEffect(pulse ? 1.5 : 1)
                    .opacity(pulse ? 0 : 0.35)
                Circle().fill(LiiveColor.danger).liiveShadow(.sos)
                VStack(spacing: 1) {
                    Text("SOS").font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    if showLabel {
                        Text("HELP").font(.system(size: size * 0.15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .foregroundColor(.white)
            }
            .frame(width: size, height: size)
            .scaleEffect(pressed ? 0.94 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }.onEnded { _ in pressed = false })
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}
