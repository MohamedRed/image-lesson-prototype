import SwiftUI

struct RideMapCanvasView: View {
    let phase: RidePhase
    let isMultiLeg: Bool
    let carProgress: Double

    private let origin = MapPoint(x: 196, y: 470)
    private let destination = MapPoint(x: 250, y: 165)
    private let transfer = MapPoint(x: 150, y: 320)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let mapViewport = MapSvgViewport(size: size)
            ZStack {
                LiiveColor.mapBackground
                mapBlocks(viewport: mapViewport)
                streetGrid(viewport: mapViewport)
                if showsRoute {
                    routePath(viewport: mapViewport)
                        .stroke(LiiveColor.mapRoute, style: StrokeStyle(lineWidth: mapViewport.length(7), lineCap: .round))
                        .shadow(color: .black.opacity(0.35), radius: mapViewport.length(3), x: 0, y: mapViewport.length(2))
                    if isMultiLeg {
                        Circle()
                            .fill(.white)
                            .frame(width: mapViewport.length(10), height: mapViewport.length(10))
                            .overlay(Circle().stroke(LiiveColor.warning, lineWidth: mapViewport.length(3)))
                            .position(mapViewport.point(transfer))
                    }
                }
                mapMarkers(size: size)
                if phase == .matching {
                    RadarSweep()
                        .position(markerPoint(origin, in: size))
                }
            }
            .ignoresSafeArea()
        }
    }

    private var effectivePhase: RidePhase {
        phase == .complete ? .enroute : phase
    }

    private var showsRoute: Bool {
        effectivePhase != .destination
    }

    private var showsCar: Bool {
        effectivePhase == .enroute
    }

    private func mapBlocks(viewport: MapSvgViewport) -> some View {
        ZStack {
            Rectangle()
                .fill(LiiveColor.mapWater)
                .frame(width: viewport.length(220), height: viewport.length(260))
                .rotationEffect(.degrees(-8))
                .position(viewport.point(MapPoint(x: 70, y: 670)))
            RoundedRectangle(cornerRadius: viewport.length(10), style: .continuous)
                .fill(LiiveColor.mapPark.opacity(0.55))
                .frame(width: viewport.length(240), height: viewport.length(180))
                .position(viewport.point(MapPoint(x: 370, y: 130)))
            RoundedRectangle(cornerRadius: viewport.length(8), style: .continuous)
                .fill(LiiveColor.mapDistrict.opacity(0.50))
                .frame(width: viewport.length(150), height: viewport.length(150))
                .position(viewport.point(MapPoint(x: 55, y: 195)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func streetGrid(viewport: MapSvgViewport) -> some View {
        ZStack {
            ForEach(MapStreet.major, id: \.id) { street in
                street.path(in: viewport)
                    .stroke(LiiveColor.mapRoad, style: StrokeStyle(lineWidth: viewport.length(9), lineCap: .round))
                    .opacity(0.95)
            }
            ForEach(MapStreet.minor, id: \.id) { street in
                street.path(in: viewport)
                    .stroke(LiiveColor.mapRoad, style: StrokeStyle(lineWidth: viewport.length(4), lineCap: .round))
                    .opacity(0.60)
            }
        }
    }

    private func routePath(viewport: MapSvgViewport) -> Path {
        var path = Path()
        path.move(to: viewport.point(origin))
        if isMultiLeg {
            path.addCurve(
                to: viewport.point(transfer),
                control1: viewport.point(MapPoint(x: 150, y: 430)),
                control2: viewport.point(MapPoint(x: 120, y: 380))
            )
            path.addCurve(
                to: viewport.point(destination),
                control1: viewport.point(MapPoint(x: 175, y: 285)),
                control2: viewport.point(MapPoint(x: 230, y: 230))
            )
        } else {
            path.addCurve(
                to: viewport.point(destination),
                control1: viewport.point(MapPoint(x: 170, y: 400)),
                control2: viewport.point(MapPoint(x: 300, y: 330))
            )
        }
        return path
    }

    @ViewBuilder
    private func mapMarkers(size: CGSize) -> some View {
        if effectivePhase == .destination {
            CurrentLocationPulse()
                .position(markerPoint(origin, in: size))
        }
        if showsRoute && !showsCar {
            bottomAnchoredMarker(kind: .origin, label: "Pickup", at: origin, size: size)
        }
        if showsCar {
            bottomAnchoredMarker(
                kind: .car,
                label: isMultiLeg ? "Leg 2 · 3 min" : "4 min",
                at: carPosition(),
                size: size
            )
        }
        if isMultiLeg && showsRoute {
            bottomAnchoredMarker(kind: .transfer, label: "Transfer", at: transfer, size: size)
        }
        if effectivePhase != .destination {
            bottomAnchoredMarker(kind: .destination, label: "Union Square", at: destination, size: size)
        }
    }

    private func bottomAnchoredMarker(
        kind: LiiveMapMarker.Kind,
        label: String,
        at point: MapPoint,
        size: CGSize
    ) -> some View {
        MapBottomAnchoredView(position: markerPoint(point, in: size)) {
            LiiveMapMarker(kind: kind, label: label)
        }
    }

    private func carPosition() -> MapPoint {
        let points = isMultiLeg
            ? [origin, MapPoint(x: 150, y: 400), transfer, MapPoint(x: 205, y: 250), destination]
            : [origin, MapPoint(x: 215, y: 390), MapPoint(x: 285, y: 300), destination]
        let maxSegment = points.count - 2
        let raw = min(Double(points.count - 1), max(0, carProgress) * Double(points.count - 1))
        let index = min(maxSegment, Int(raw.rounded(.down)))
        let local = raw - Double(index)
        let start = points[index]
        let end = points[index + 1]
        return MapPoint(x: start.x + (end.x - start.x) * local, y: start.y + (end.y - start.y) * local)
    }

    private func markerPoint(_ point: MapPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x / 402 * size.width, y: point.y / 740 * size.height)
    }
}

private struct MapPoint {
    let x: Double
    let y: Double
}

private struct MapSvgViewport {
    private static let width = 402.0
    private static let height = 740.0

    let scale: Double
    let offsetX: Double
    let offsetY: Double

    init(size: CGSize) {
        scale = max(Double(size.width) / Self.width, Double(size.height) / Self.height)
        offsetX = (Double(size.width) - Self.width * scale) / 2
        offsetY = (Double(size.height) - Self.height * scale) / 2
    }

    func point(_ point: MapPoint) -> CGPoint {
        CGPoint(x: offsetX + point.x * scale, y: offsetY + point.y * scale)
    }

    func length(_ value: Double) -> CGFloat {
        CGFloat(value * scale)
    }
}

private struct MapStreet {
    let id: String
    let start: MapPoint
    let end: MapPoint

    static let major = [
        MapStreet(id: "m1", start: MapPoint(x: -20, y: 250), end: MapPoint(x: 430, y: 225)),
        MapStreet(id: "m2", start: MapPoint(x: -20, y: 370), end: MapPoint(x: 430, y: 350)),
        MapStreet(id: "m3", start: MapPoint(x: -20, y: 500), end: MapPoint(x: 430, y: 520)),
        MapStreet(id: "m4", start: MapPoint(x: -20, y: 630), end: MapPoint(x: 430, y: 650)),
        MapStreet(id: "m5", start: MapPoint(x: 70, y: -20), end: MapPoint(x: 120, y: 780)),
        MapStreet(id: "m6", start: MapPoint(x: 210, y: -20), end: MapPoint(x: 240, y: 780)),
        MapStreet(id: "m7", start: MapPoint(x: 330, y: -20), end: MapPoint(x: 360, y: 780))
    ]

    static let minor = [
        MapStreet(id: "n1", start: MapPoint(x: -20, y: 180), end: MapPoint(x: 430, y: 165)),
        MapStreet(id: "n2", start: MapPoint(x: -20, y: 430), end: MapPoint(x: 430, y: 445)),
        MapStreet(id: "n3", start: MapPoint(x: 140, y: -20), end: MapPoint(x: 170, y: 780)),
        MapStreet(id: "n4", start: MapPoint(x: 280, y: -20), end: MapPoint(x: 305, y: 780))
    ]

    func path(in viewport: MapSvgViewport) -> Path {
        var path = Path()
        path.move(to: viewport.point(start))
        path.addLine(to: viewport.point(end))
        return path
    }
}

private struct CurrentLocationPulse: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(LiiveColor.accentTint)
                .frame(width: 66, height: 66)
                .scaleEffect(pulse ? 1 : 0.33)
                .opacity(pulse ? 0 : 0.65)
            Circle()
                .fill(LiiveColor.accent)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .liiveShadow(.pin)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

private struct RadarSweep: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(LiiveColor.accent)
                .frame(width: 126, height: 126)
                .scaleEffect(pulse ? 1 : 0.11)
                .opacity(pulse ? 0 : 0.50)
            Circle()
                .fill(LiiveColor.accent)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .liiveShadow(.pin)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}
