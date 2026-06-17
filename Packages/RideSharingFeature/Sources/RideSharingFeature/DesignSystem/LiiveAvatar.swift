//  LiiveAvatar.swift  ·  Liive Ride DS (SwiftUI)
//  Driver/rider avatar: image or initials; optional accent speaking ring.

import SwiftUI

public struct LiiveAvatar: View {
    let name: String
    var image: Image? = nil
    var size: CGFloat = LiiveControl.md + LiiveSpacing.xs
    var ring: Bool = false
    var ringColor: Color = LiiveColor.accent

    public init(
        name: String,
        image: Image? = nil,
        size: CGFloat = LiiveControl.md + LiiveSpacing.xs,
        ring: Bool = false,
        ringColor: Color = LiiveColor.accent
    ) {
        self.name = name; self.image = image; self.size = size
        self.ring = ring; self.ringColor = ringColor
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    public var body: some View {
        ZStack {
            if let image {
                image.resizable().scaledToFill()
            } else {
                LiiveColor.fill
                Text(initials.isEmpty ? "?" : initials)
                    .font(Font.custom(LiiveFont.family, size: size * LiiveAvatarLayout.initialsScale).weight(.semibold))
                    .foregroundColor(LiiveColor.text)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(LiiveColor.surface, lineWidth: ring ? LiiveAvatarLayout.ringStrokeWidth : 0)
                .padding(-LiiveAvatarLayout.ringStrokeWidth)
                .opacity(ring ? 1 : 0)
        )
        .overlay(
            Circle()
                .stroke(ringColor, lineWidth: ring ? LiiveAvatarLayout.ringStrokeWidth : 0)
                .padding(-LiiveAvatarLayout.ringStrokeWidth * 2)
                .opacity(ring ? 1 : 0)
        )
    }
}

private enum LiiveAvatarLayout {
    static let initialsScale = 0.4
    static let ringStrokeWidth = LiiveSpacing.xs2 + LiiveSpacing.xs2 / 4
}
