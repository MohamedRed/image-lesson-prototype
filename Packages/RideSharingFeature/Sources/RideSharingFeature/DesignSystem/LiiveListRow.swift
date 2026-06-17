import SwiftUI

public struct LiiveListRow<Leading: View, Trailing: View>: View {
    @GestureState private var isPressed = false

    let title: String
    var subtitle: String?
    var value: String?
    var divider: Bool
    var chevron: Bool
    let leading: Leading
    let trailing: Trailing
    let action: (() -> Void)?

    public init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        divider: Bool = true,
        chevron: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.divider = divider
        self.chevron = chevron
        self.action = action
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: LiiveListRowLayout.rowSpacing) {
                leading
                VStack(alignment: .leading, spacing: LiiveListRowLayout.textSpacing) {
                    Text(title)
                        .font(LiiveFont.body)
                        .tracking(LiiveFont.Tracking.title3)
                        .foregroundColor(LiiveColor.text)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(LiiveFont.footnote)
                            .foregroundColor(LiiveColor.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: LiiveListRowLayout.spacerMinLength)
                if let value {
                    Text(value)
                        .font(LiiveFont.body)
                        .foregroundColor(LiiveColor.textSecondary)
                }
                trailing
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: LiiveListRowLayout.chevronIconSize, weight: .semibold))
                        .foregroundColor(LiiveColor.textTertiary)
                }
            }
            .frame(minHeight: LiiveSpacing.touchMin)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, LiiveListRowLayout.horizontalPadding)
            .padding(.vertical, LiiveListRowLayout.verticalPadding)
            .background(action != nil && isPressed ? LiiveColor.fillQuaternary : Color.clear)
            if divider {
                Rectangle()
                    .fill(LiiveColor.separator)
                    .frame(height: LiiveListRowLayout.dividerHeight)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    state = action != nil
                }
        )
        .animation(.easeOut(duration: LiiveMotion.fast), value: isPressed)
        .onTapGesture { action?() }
    }
}

private enum LiiveListRowLayout {
    static let rowSpacing = LiiveSpacing.m
    static let textSpacing = LiiveSpacing.xs2 / 2
    static let spacerMinLength = LiiveSpacing.s
    static let chevronIconSize = LiiveSpacing.l - LiiveSpacing.xs2
    static let horizontalPadding = LiiveSpacing.screenGutter
    static let verticalPadding = LiiveSpacing.s + LiiveSpacing.xs2
    static let dividerHeight = LiiveSpacing.xs2 / 4
}
