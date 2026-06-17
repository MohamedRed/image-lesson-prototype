import SwiftUI

struct RideMapCanvasView: View {
    let phase: RidePhase
    let isMultiLeg: Bool
    let carProgress: Double
    let destinationName: String
    let tripSummary: RideTripSummary

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
                        .stroke(
                            LiiveColor.mapRoute,
                            style: StrokeStyle(lineWidth: mapViewport.length(RideMapGeometry.routeStrokeWidth), lineCap: .round)
                        )
                        .shadow(
                            color: .black.opacity(RideMapGeometry.routeShadowOpacity),
                            radius: mapViewport.length(RideMapGeometry.routeShadowRadius),
                            x: 0,
                            y: mapViewport.length(RideMapGeometry.routeShadowYOffset)
                        )
                    if isMultiLeg {
                        Circle()
                            .fill(.white)
                            .frame(
                                width: mapViewport.length(RideMapGeometry.transferRadius * 2),
                                height: mapViewport.length(RideMapGeometry.transferRadius * 2)
                            )
                            .overlay(
                                Circle().stroke(
                                    LiiveColor.warning,
                                    lineWidth: mapViewport.length(RideMapGeometry.transferStrokeWidth)
                                )
                            )
                            .position(mapViewport.point(RideMapGeometry.transfer))
                    }
                }
                mapMarkers(size: size)
                if phase == .matching {
                    RadarSweep()
                        .position(markerPoint(RideMapGeometry.origin, in: size))
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
            mapBlock(RideMapGeometry.waterBlock, color: LiiveColor.mapWater, viewport: viewport)
            mapBlock(RideMapGeometry.parkBlock, color: LiiveColor.mapPark, viewport: viewport)
            mapBlock(RideMapGeometry.districtBlock, color: LiiveColor.mapDistrict, viewport: viewport)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func mapBlock(_ block: MapBlock, color: Color, viewport: MapSvgViewport) -> some View {
        RoundedRectangle(cornerRadius: viewport.length(block.cornerRadius), style: .continuous)
            .fill(color.opacity(block.opacity))
            .frame(width: viewport.length(block.size.width), height: viewport.length(block.size.height))
            .rotationEffect(.degrees(block.rotationDegrees))
            .position(viewport.point(block.center))
    }

    private func streetGrid(viewport: MapSvgViewport) -> some View {
        ZStack {
            ForEach(RideMapGeometry.majorStreets, id: \.id) { street in
                street.path(in: viewport)
                    .stroke(
                        LiiveColor.mapRoad,
                        style: StrokeStyle(lineWidth: viewport.length(RideMapGeometry.majorStreetWidth), lineCap: .round)
                    )
                    .opacity(RideMapGeometry.majorStreetOpacity)
            }
            ForEach(RideMapGeometry.minorStreets, id: \.id) { street in
                street.path(in: viewport)
                    .stroke(
                        LiiveColor.mapRoad,
                        style: StrokeStyle(lineWidth: viewport.length(RideMapGeometry.minorStreetWidth), lineCap: .round)
                    )
                    .opacity(RideMapGeometry.minorStreetOpacity)
            }
        }
    }

    private func routePath(viewport: MapSvgViewport) -> Path {
        var path = Path()
        path.move(to: viewport.point(RideMapGeometry.origin))
        if isMultiLeg {
            RideMapGeometry.multiLegRouteControls.forEach {
                path.addCurve(
                    to: viewport.point($0.end),
                    control1: viewport.point($0.firstControl),
                    control2: viewport.point($0.secondControl)
                )
            }
        } else {
            let controls = RideMapGeometry.singleLegRouteControls
            path.addCurve(
                to: viewport.point(controls.end),
                control1: viewport.point(controls.firstControl),
                control2: viewport.point(controls.secondControl)
            )
        }
        return path
    }

    @ViewBuilder
    private func mapMarkers(size: CGSize) -> some View {
        if effectivePhase == .destination {
            CurrentLocationPulse()
                .position(markerPoint(RideMapGeometry.origin, in: size))
        }
        if showsRoute && !showsCar {
            bottomAnchoredMarker(kind: .origin, label: "Pickup", at: RideMapGeometry.origin, size: size)
        }
        if showsCar {
            bottomAnchoredMarker(
                kind: .car,
                label: tripSummary.mapMarkerLabel,
                at: carPosition(),
                size: size
            )
        }
        if isMultiLeg && showsRoute {
            bottomAnchoredMarker(kind: .transfer, label: "Transfer", at: RideMapGeometry.transfer, size: size)
        }
        if effectivePhase != .destination {
            bottomAnchoredMarker(kind: .destination, label: destinationName, at: RideMapGeometry.destination, size: size)
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
        let points = RideMapGeometry.carPoints(isMultiLeg: isMultiLeg)
        let maxSegment = points.count - 2
        let raw = min(Double(points.count - 1), max(0, carProgress) * Double(points.count - 1))
        let index = min(maxSegment, Int(raw.rounded(.down)))
        let local = raw - Double(index)
        let start = points[index]
        let end = points[index + 1]
        return MapPoint(x: start.x + (end.x - start.x) * local, y: start.y + (end.y - start.y) * local)
    }

    private func markerPoint(_ point: MapPoint, in size: CGSize) -> CGPoint {
        let viewport = RideMapGeometry.viewportSize
        return CGPoint(x: point.x / viewport.width * size.width, y: point.y / viewport.height * size.height)
    }
}

private struct CurrentLocationPulse: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(LiiveColor.accentTint)
                .frame(width: RideMapGeometry.currentPulseSize, height: RideMapGeometry.currentPulseSize)
                .scaleEffect(pulse ? 1 : RideMapGeometry.currentPulseScaleStart)
                .opacity(pulse ? 0 : RideMapGeometry.currentPulseOpacityStart)
            Circle()
                .fill(LiiveColor.accent)
                .frame(width: RideMapGeometry.currentDotSize, height: RideMapGeometry.currentDotSize)
                .overlay(Circle().stroke(.white, lineWidth: RideMapGeometry.currentDotStrokeWidth))
                .liiveShadow(.pin)
        }
        .onAppear {
            withAnimation(.easeOut(duration: RideMapGeometry.currentPulseDuration).repeatForever(autoreverses: false)) {
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
                .frame(width: RideMapGeometry.radarPulseSize, height: RideMapGeometry.radarPulseSize)
                .scaleEffect(pulse ? 1 : RideMapGeometry.radarPulseScaleStart)
                .opacity(pulse ? 0 : RideMapGeometry.radarPulseOpacityStart)
            Circle()
                .fill(LiiveColor.accent)
                .frame(width: RideMapGeometry.radarDotSize, height: RideMapGeometry.radarDotSize)
                .overlay(Circle().stroke(.white, lineWidth: RideMapGeometry.radarDotStrokeWidth))
                .liiveShadow(.pin)
        }
        .onAppear {
            withAnimation(.easeOut(duration: RideMapGeometry.radarPulseDuration).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}
