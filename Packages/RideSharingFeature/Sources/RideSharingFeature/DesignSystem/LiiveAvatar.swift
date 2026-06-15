//  LiiveAvatar.swift  ·  Liive Ride DS (SwiftUI)
//  Driver/rider avatar: image or initials; optional accent speaking ring.

import SwiftUI

public struct LiiveAvatar: View {
    let name: String
    var image: Image? = nil
    var size: CGFloat = 48
    var ring: Bool = false

    public init(name: String, image: Image? = nil, size: CGFloat = 48, ring: Bool = false) {
        self.name = name; self.image = image; self.size = size; self.ring = ring
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
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(LiiveColor.text)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(LiiveColor.accent, lineWidth: ring ? 2.5 : 0)
                .padding(-4.5)
                .opacity(ring ? 1 : 0)
        )
    }
}
