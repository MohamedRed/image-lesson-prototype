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
        VStack(spacing: LiiveMapMarkerLayout.markerGap) {
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
            .frame(width: LiiveMapMarkerLayout.dotSize, height: LiiveMapMarkerLayout.dotSize)
            .overlay(
                Circle().stroke(
                    LiiveMapMarkerLayout.outlineColor,
                    lineWidth: LiiveMapMarkerLayout.dotStrokeWidth
                )
            )
            .liiveShadow(.pin)
    }

    private var pinMarker: some View {
        ZStack(alignment: .bottom) {
            PointerTail(color: color)
                .frame(width: LiiveMapMarkerLayout.pinTailSize, height: LiiveMapMarkerLayout.pinTailSize)
                .offset(y: LiiveMapMarkerLayout.pinTailOffset)
            Circle()
                .fill(color)
                .frame(width: LiiveMapMarkerLayout.pinSize, height: LiiveMapMarkerLayout.pinSize)
                .overlay(
                    Circle().stroke(
                        LiiveMapMarkerLayout.outlineColor,
                        lineWidth: LiiveMapMarkerLayout.pinStrokeWidth
                    )
                )
                .liiveShadow(.pin)
            Image(systemName: icon)
                .font(.system(size: LiiveMapMarkerLayout.glyphSize, weight: .bold))
                .foregroundColor(LiiveMapMarkerLayout.outlineColor)
        }
        .frame(width: LiiveMapMarkerLayout.pinSize, height: LiiveMapMarkerLayout.pinSize)
    }

    private func labelTag(_ label: String) -> some View {
        Text(label)
            .font(LiiveFont.caption1.weight(.semibold))
            .foregroundColor(LiiveColor.text)
            .lineLimit(1)
            .padding(.horizontal, LiiveMapMarkerLayout.labelHorizontalPadding)
            .padding(.vertical, LiiveMapMarkerLayout.labelVerticalPadding)
            .background(LiiveColor.surface)
            .clipShape(Capsule())
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(color)
                    .frame(height: LiiveMapMarkerLayout.labelIndicatorHeight)
            }
            .liiveShadow(.small)
    }
}

private enum LiiveMapMarkerLayout {
    static let markerGap = LiiveSpacing.xs
    static let dotSize = LiiveSpacing.l + LiiveSpacing.xs2
    static let dotStrokeWidth = LiiveSpacing.xs - LiiveSpacing.xs2 / 2
    static let pinSize = LiiveControl.md - LiiveSpacing.xs - LiiveSpacing.xs2
    static let glyphSize = dotSize
    static let pinTailSize = LiiveSpacing.m
    static let pinTailOffset = LiiveSpacing.xs + LiiveSpacing.xs2 / 2
    static let pinStrokeWidth = LiiveSpacing.xs2 + LiiveSpacing.xs2 / 4
    static let labelHorizontalPadding = LiiveSpacing.s
    static let labelVerticalPadding = LiiveSpacing.xs2
    static let labelIndicatorHeight = LiiveSpacing.xs2
    static let pointerRotationDegrees = 45.0
    static let outlineColor = Color.white
}

private struct PointerTail: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(LiiveMapMarkerLayout.outlineColor)
                    .frame(width: LiiveMapMarkerLayout.pinStrokeWidth)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(LiiveMapMarkerLayout.outlineColor)
                    .frame(height: LiiveMapMarkerLayout.pinStrokeWidth)
            }
            .rotationEffect(.degrees(LiiveMapMarkerLayout.pointerRotationDegrees))
    }
}
