import SwiftUI

public struct LiiveMapMarker: View {
    public enum Kind { case car, origin, destination, transfer }

    let kind: Kind
    let label: String

    public init(kind: Kind, label: String) {
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
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(label)
                    .font(LiiveFont.caption1.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundColor(kind == .car ? LiiveColor.onAccent : .white)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color)
            .clipShape(Capsule())
            .liiveShadow(.pin)
            Triangle()
                .fill(color)
                .frame(width: 12, height: 8)
                .offset(y: -8)
        }
        .fixedSize()
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
