import SwiftUI

public struct LiiveListRow<Leading: View, Trailing: View>: View {
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
            HStack(spacing: 12) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(LiiveFont.headline)
                        .foregroundColor(LiiveColor.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(LiiveFont.footnote)
                            .foregroundColor(LiiveColor.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(LiiveFont.subhead)
                        .foregroundColor(LiiveColor.textSecondary)
                }
                trailing
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(LiiveColor.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            if divider {
                Rectangle()
                    .fill(LiiveColor.separator)
                    .frame(height: 0.5)
                    .padding(.leading, 60)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { action?() }
    }
}
