import SwiftUI

public struct LiiveMapMarker: View {
    public enum Kind { case car, origin, destination, transfer }

    let kind: Kind
    let label: String?

    public init(kind: Kind, label: String? = nil) {
        self.kind = kind
        self.label = label
    }

    private var color: Color {
        switch kind {
        case .car: return LiiveColor.accent
        case .origin: return LiiveColor.success
        case .destination: return LiiveColor.danger
        case .transfer: return LiiveColor.warning
        }
    }

    private var icon: String {
        switch kind {
        case .car: return "car.fill"
        case .origin: return "location.fill"
        case .destination: return "mappin.circle.fill"
        case .transfer: return "arrow.triangle.swap"
        }
    }

    public var body: some View {
        VStack(spacing: 4) {
            if kind == .origin {
                originDot
            } else {
                pinMarker
            }
            if let label, !label.isEmpty {
                labelTag(label)
            }
        }
        .fixedSize()
    }

    private var originDot: some View {
        Circle()
            .fill(color)
            .frame(width: 18, height: 18)
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .liiveShadow(.pin)
    }

    private var pinMarker: some View {
        ZStack(alignment: .bottom) {
            PointerTail(color: color)
                .frame(width: 12, height: 12)
                .offset(y: 5)
            Circle()
                .fill(color)
                .frame(width: 38, height: 38)
                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                .liiveShadow(.pin)
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 38, height: 38)
    }

    private func labelTag(_ label: String) -> some View {
        Text(label)
            .font(LiiveFont.caption1.weight(.semibold))
            .foregroundColor(LiiveColor.text)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(LiiveColor.surface)
            .clipShape(Capsule())
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(color)
                    .frame(height: 2)
            }
            .liiveShadow(.card)
    }
}

private struct PointerTail: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(.white)
                    .frame(width: 2.5)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.white)
                    .frame(height: 2.5)
            }
            .rotationEffect(.degrees(45))
    }
}
