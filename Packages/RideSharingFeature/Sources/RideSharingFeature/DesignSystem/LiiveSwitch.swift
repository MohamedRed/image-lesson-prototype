import SwiftUI

public struct LiiveSwitch: View {
    @Binding var isOn: Bool
    var disabled: Bool

    public init(isOn: Binding<Bool>, disabled: Bool = false) {
        self._isOn = isOn
        self.disabled = disabled
    }

    public var body: some View {
        Button {
            guard !disabled else { return }
            withAnimation(.easeOut(duration: LiiveMotion.base)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isOn ? LiiveColor.success : LiiveColor.fill)
                    .frame(width: LiiveSwitchLayout.trackWidth, height: LiiveSwitchLayout.trackHeight)
                Circle()
                    .fill(LiiveSwitchLayout.thumbColor)
                    .frame(width: LiiveSwitchLayout.thumbSize, height: LiiveSwitchLayout.thumbSize)
                    .shadow(
                        color: LiiveSwitchLayout.thumbShadowColor,
                        radius: LiiveSwitchLayout.thumbShadowRadius,
                        x: LiiveSwitchLayout.thumbShadowX,
                        y: LiiveSwitchLayout.thumbShadowY
                    )
                    .offset(x: isOn ? LiiveSwitchLayout.thumbTravel : LiiveSwitchLayout.thumbRestOffset)
                    .padding(LiiveSwitchLayout.trackPadding)
            }
            .opacity(disabled ? LiiveSwitchLayout.disabledOpacity : LiiveSwitchLayout.enabledOpacity)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(Text("Switch"))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private enum LiiveSwitchLayout {
    static let trackWidth = LiiveControl.lg + LiiveSpacing.xs2 / 2
    static let trackHeight = LiiveSpacing.xxxl - LiiveSpacing.xs2 / 2
    static let trackPadding = LiiveSpacing.xs2
    static let thumbSize = trackHeight - trackPadding - trackPadding
    static let thumbRestOffset = CGFloat.zero
    static let thumbTravel = trackWidth - thumbSize - trackPadding - trackPadding
    static let thumbShadowRadius = LiiveSpacing.xs
    static let thumbShadowX = CGFloat.zero
    static let thumbShadowY = LiiveSpacing.xs2
    static let thumbShadowColor = Color.black.opacity(0.25)
    static let thumbColor = Color.white
    static let disabledOpacity = 0.5
    static let enabledOpacity = 1.0
}
