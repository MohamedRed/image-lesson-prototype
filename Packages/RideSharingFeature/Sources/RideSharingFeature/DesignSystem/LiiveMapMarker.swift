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
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 38, height: 38)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .liiveShadow(.pin)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            Triangle()
                .fill(color)
                .frame(width: 12, height: 8)
                .overlay(Triangle().stroke(.white, lineWidth: 2.5))
                .offset(y: -1)
        }
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
