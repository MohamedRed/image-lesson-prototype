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
        HStack(spacing: LiiveDriverCardLayout.rowSpacing) {
            LiiveAvatar(name: name, image: avatarImage, size: LiiveDriverCardLayout.avatarSize, ring: speaking)
            VStack(alignment: .leading, spacing: LiiveDriverCardLayout.textSpacing) {
                HStack(spacing: LiiveDriverCardLayout.titleRatingSpacing) {
                    Text(name)
                        .font(LiiveFont.headline)
                        .foregroundColor(LiiveColor.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    if let rating {
                        LiiveRatingStars(value: rating, size: LiiveDriverCardLayout.ratingStarSize)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                if vehicle != nil || plate != nil {
                    HStack(spacing: 0) {
                        if let vehicle {
                            Text(vehicle)
                                .foregroundColor(LiiveColor.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        if vehicle != nil && plate != nil { Text(" · ").foregroundColor(LiiveColor.textSecondary) }
                        if let plate {
                            Text(plate)
                                .fontWeight(.semibold)
                                .tracking(LiiveDriverCardLayout.plateTracking)
                                .foregroundColor(LiiveColor.text)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .font(LiiveFont.sheetMeta)
                    .lineLimit(1)
                    .padding(.top, LiiveDriverCardLayout.secondaryLineTopPadding)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let eta {
                VStack(alignment: .trailing, spacing: LiiveDriverCardLayout.textSpacing) {
                    Text(eta).font(LiiveFont.title2.monospacedDigit()).foregroundColor(LiiveColor.accent)
                    Text("away").font(LiiveFont.caption2).foregroundColor(LiiveColor.textSecondary)
                }
            }
            trailing
        }
        .padding(LiiveDriverCardLayout.cardPadding)
        .background(LiiveColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
        .liiveShadow(.card)
    }
}

private enum LiiveDriverCardLayout {
    static let rowSpacing = LiiveSpacing.m + LiiveSpacing.xs2
    static let titleRatingSpacing = LiiveSpacing.s
    static let textSpacing = LiiveSpacing.xs2
    static let avatarSize = LiiveControl.xl - LiiveSpacing.xs2
    static let ratingStarSize = LiiveSpacing.m + LiiveSpacing.xs2 / 2
    static let secondaryLineTopPadding = LiiveSpacing.xs2
    static let plateTracking = LiiveSpacing.xs2 / 4
    static let cardPadding = rowSpacing
}
