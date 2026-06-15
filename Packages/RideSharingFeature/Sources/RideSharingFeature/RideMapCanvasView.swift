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
            ZStack {
                LiiveColor.mapBackground
                mapBlocks
                streetGrid(size: size)
                if showsRoute {
                    routePath(size: size)
                        .stroke(LiiveColor.mapRoute, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
                    if isMultiLeg {
                        Circle()
                            .fill(.white)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(LiiveColor.warning, lineWidth: 3))
                            .position(scale(transfer, in: size))
                    }
                }
                mapMarkers(size: size)
                if phase == .matching {
                    RadarSweep()
                        .position(scale(origin, in: size))
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

    private var mapBlocks: some View {
        ZStack {
            Rectangle()
                .fill(LiiveColor.mapWater)
                .frame(width: 220, height: 260)
                .rotationEffect(.degrees(-8))
                .offset(x: -145, y: 285)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LiiveColor.mapPark.opacity(0.55))
                .frame(width: 240, height: 180)
                .offset(x: 230, y: -260)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LiiveColor.mapDistrict.opacity(0.50))
                .frame(width: 150, height: 150)
                .offset(x: -150, y: -210)
        }
    }

    private func streetGrid(size: CGSize) -> some View {
        ZStack {
            ForEach(MapStreet.major, id: \.id) { street in
                street.path(in: size)
                    .stroke(LiiveColor.mapRoad, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .opacity(0.95)
            }
            ForEach(MapStreet.minor, id: \.id) { street in
                street.path(in: size)
                    .stroke(LiiveColor.mapRoad, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .opacity(0.60)
            }
        }
    }

    private func routePath(size: CGSize) -> Path {
        var path = Path()
        path.move(to: scale(origin, in: size))
        if isMultiLeg {
            path.addCurve(
                to: scale(transfer, in: size),
                control1: scale(MapPoint(x: 150, y: 430), in: size),
                control2: scale(MapPoint(x: 120, y: 380), in: size)
            )
            path.addCurve(
                to: scale(destination, in: size),
                control1: scale(MapPoint(x: 175, y: 285), in: size),
                control2: scale(MapPoint(x: 230, y: 230), in: size)
            )
        } else {
            path.addCurve(
                to: scale(destination, in: size),
                control1: scale(MapPoint(x: 170, y: 400), in: size),
                control2: scale(MapPoint(x: 300, y: 330), in: size)
            )
        }
        return path
    }

    @ViewBuilder
    private func mapMarkers(size: CGSize) -> some View {
        if effectivePhase == .destination {
            CurrentLocationPulse()
                .position(scale(origin, in: size))
        }
        if showsRoute && !showsCar {
            LiiveMapMarker(kind: .origin, label: "Pickup")
                .position(scale(origin, in: size))
        }
        if showsCar {
            LiiveMapMarker(kind: .car, label: isMultiLeg ? "Leg 2 · 3 min" : "4 min")
                .position(scale(carPosition(), in: size))
        }
        if isMultiLeg && showsRoute {
            LiiveMapMarker(kind: .transfer, label: "Transfer")
                .position(scale(transfer, in: size))
        }
        if effectivePhase != .destination {
            LiiveMapMarker(kind: .destination, label: "Union Square")
                .position(scale(destination, in: size))
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

    private func scale(_ point: MapPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x / 402 * size.width, y: point.y / 740 * size.height)
    }
}

private struct MapPoint {
    let x: Double
    let y: Double
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

    func path(in size: CGSize) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: start.x / 402 * size.width, y: start.y / 740 * size.height))
        path.addLine(to: CGPoint(x: end.x / 402 * size.width, y: end.y / 740 * size.height))
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
