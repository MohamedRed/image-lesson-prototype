//  LiiveDriverCard.swift  ·  Liive Ride DS (SwiftUI)
//  Matched-driver summary: avatar, name, rating, vehicle + plate, ETA pill.
//  Composes LiiveAvatar + LiiveRatingStars.

import SwiftUI

public struct LiiveDriverCard<Trailing: View>: View {
    let name: String
    var rating: Double? = nil
    var vehicle: String? = nil
    var plate: String? = nil
    var eta: String? = nil
    var speaking: Bool = false
    var avatarImage: Image? = nil
    let trailing: Trailing

    public init(name: String, rating: Double? = nil, vehicle: String? = nil, plate: String? = nil,
                eta: String? = nil, speaking: Bool = false, avatarImage: Image? = nil,
                @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.name = name; self.rating = rating; self.vehicle = vehicle; self.plate = plate
        self.eta = eta; self.speaking = speaking; self.avatarImage = avatarImage; self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: 14) {
            LiiveAvatar(name: name, image: avatarImage, size: 54, ring: speaking)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(name).font(LiiveFont.headline).foregroundColor(LiiveColor.text)
                    if let rating { LiiveRatingStars(value: rating, size: 13) }
                }
                if vehicle != nil || plate != nil {
                    HStack(spacing: 0) {
                        if let vehicle { Text(vehicle).foregroundColor(LiiveColor.textSecondary) }
                        if vehicle != nil && plate != nil { Text(" · ").foregroundColor(LiiveColor.textSecondary) }
                        if let plate { Text(plate).fontWeight(.semibold).tracking(0.5).foregroundColor(LiiveColor.text) }
                    }
                    .font(Font.custom(LiiveFont.family, size: 14))
                    .lineLimit(1)
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 8)
            if let eta {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(eta).font(LiiveFont.title2.monospacedDigit()).foregroundColor(LiiveColor.accent)
                    Text("away").font(LiiveFont.caption2).foregroundColor(LiiveColor.textSecondary)
                }
            }
            trailing
        }
        .padding(14)
        .background(LiiveColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
        .liiveShadow(.card)
    }
}
