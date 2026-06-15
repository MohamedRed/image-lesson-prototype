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
        HStack {
            Text(label)
                .font(total ? LiiveFont.headline : LiiveFont.subhead)
                .foregroundColor(muted ? LiiveColor.textSecondary : LiiveColor.text)
            Spacer()
            Text(amount)
                .font((total ? LiiveFont.headline : LiiveFont.subhead).monospacedDigit())
                .fontWeight(total ? .bold : .regular)
                .foregroundColor(total ? LiiveColor.text : LiiveColor.textSecondary)
        }
        .padding(.vertical, 7)
    }
}
