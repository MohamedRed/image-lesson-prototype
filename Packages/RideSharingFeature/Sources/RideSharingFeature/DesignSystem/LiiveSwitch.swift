import SwiftUI

public struct LiiveSwitch: View {
    @Binding var isOn: Bool

    public init(isOn: Binding<Bool>) {
        self._isOn = isOn
    }

    public var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .tint(LiiveColor.success)
            .frame(width: 52)
    }
}
