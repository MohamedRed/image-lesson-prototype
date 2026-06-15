import SwiftUI

public struct LiiveFareRow: View {
    let label: String
    let amount: String
    var muted: Bool
    var total: Bool

    public init(label: String, amount: String, muted: Bool = false, total: Bool = false) {
        self.label = label
        self.amount = amount
        self.muted = muted
        self.total = total
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(total ? LiiveFont.headline : LiiveFont.subhead)
                .fontWeight(total ? .semibold : .regular)
                .foregroundColor(labelColor)
            Spacer()
            Text(amount)
                .font((total ? LiiveFont.headline : LiiveFont.subhead).monospacedDigit())
                .fontWeight(total ? .bold : .medium)
                .foregroundColor(LiiveColor.text)
        }
        .padding(.top, total ? 12 : 6)
        .padding(.bottom, total ? 0 : 6)
    }

    private var labelColor: Color {
        if total { return LiiveColor.text }
        return muted ? LiiveColor.textTertiary : LiiveColor.textSecondary
    }
}
