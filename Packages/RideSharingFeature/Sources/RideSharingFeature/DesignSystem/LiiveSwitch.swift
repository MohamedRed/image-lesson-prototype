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
                    .frame(width: 51, height: 31)
                Circle()
                    .fill(.white)
                    .frame(width: 27, height: 27)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .offset(x: isOn ? 20 : 0)
                    .padding(2)
            }
            .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(Text("Switch"))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
