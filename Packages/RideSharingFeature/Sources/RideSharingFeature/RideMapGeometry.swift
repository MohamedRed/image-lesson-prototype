import SwiftUI

enum RideMapGeometry {
    static let viewportSize = MapSize(width: 402, height: 740)

    static let origin = MapPoint(x: 196, y: 470)
    static let destination = MapPoint(x: 250, y: 165)
    static let transfer = MapPoint(x: 150, y: 320)

    static let waterBlock = MapBlock(
        center: MapPoint(x: 70, y: 670),
        size: MapSize(width: 220, height: 260),
        cornerRadius: 0,
        opacity: 0.9,
        rotationDegrees: -8
    )
    static let parkBlock = MapBlock(
        center: MapPoint(x: 370, y: 130),
        size: MapSize(width: 240, height: 180),
        cornerRadius: 10,
        opacity: 0.55,
        rotationDegrees: 0
    )
    static let districtBlock = MapBlock(
        center: MapPoint(x: 55, y: 195),
        size: MapSize(width: 150, height: 150),
        cornerRadius: 8,
        opacity: 0.50,
        rotationDegrees: 0
    )

    static let majorStreetWidth = 9.0
    static let majorStreetOpacity = 0.95
    static let minorStreetWidth = 4.0
    static let minorStreetOpacity = 0.60
    static let routeStrokeWidth = 7.0
    static let routeShadowRadius = 3.0
    static let routeShadowYOffset = 2.0
    static let routeShadowOpacity = 0.35
    static let transferRadius = 5.0
    static let transferStrokeWidth = 3.0
    static let currentPulseSize = 66.0
    static let currentPulseScaleStart = 0.33
    static let currentPulseOpacityStart = 0.65
    static let currentPulseDuration = 2.0
    static let currentDotSize = 22.0
    static let currentDotStrokeWidth = 3.0
    static let radarPulseSize = 126.0
    static let radarPulseScaleStart = 0.11
    static let radarPulseOpacityStart = 0.50
    static let radarPulseDuration = 1.8
    static let radarDotSize = 14.0
    static let radarDotStrokeWidth = 3.0

    static let majorStreets = [
        MapStreet(id: "m1", start: MapPoint(x: -20, y: 250), end: MapPoint(x: 430, y: 225)),
        MapStreet(id: "m2", start: MapPoint(x: -20, y: 370), end: MapPoint(x: 430, y: 350)),
        MapStreet(id: "m3", start: MapPoint(x: -20, y: 500), end: MapPoint(x: 430, y: 520)),
        MapStreet(id: "m4", start: MapPoint(x: -20, y: 630), end: MapPoint(x: 430, y: 650)),
        MapStreet(id: "m5", start: MapPoint(x: 70, y: -20), end: MapPoint(x: 120, y: 780)),
        MapStreet(id: "m6", start: MapPoint(x: 210, y: -20), end: MapPoint(x: 240, y: 780)),
        MapStreet(id: "m7", start: MapPoint(x: 330, y: -20), end: MapPoint(x: 360, y: 780))
    ]

    static let minorStreets = [
        MapStreet(id: "n1", start: MapPoint(x: -20, y: 180), end: MapPoint(x: 430, y: 165)),
        MapStreet(id: "n2", start: MapPoint(x: -20, y: 430), end: MapPoint(x: 430, y: 445)),
        MapStreet(id: "n3", start: MapPoint(x: 140, y: -20), end: MapPoint(x: 170, y: 780)),
        MapStreet(id: "n4", start: MapPoint(x: 280, y: -20), end: MapPoint(x: 305, y: 780))
    ]

    static let singleLegRouteControls = RouteControls(
        firstControl: MapPoint(x: 170, y: 400),
        secondControl: MapPoint(x: 300, y: 330),
        end: destination
    )

    static let multiLegRouteControls = [
        RouteControls(
            firstControl: MapPoint(x: 150, y: 430),
            secondControl: MapPoint(x: 120, y: 380),
            end: transfer
        ),
        RouteControls(
            firstControl: MapPoint(x: 175, y: 285),
            secondControl: MapPoint(x: 230, y: 230),
            end: destination
        )
    ]

    static func carPoints(isMultiLeg: Bool) -> [MapPoint] {
        if isMultiLeg {
            return [origin, MapPoint(x: 150, y: 400), transfer, MapPoint(x: 205, y: 250), destination]
        }
        return [origin, MapPoint(x: 215, y: 390), MapPoint(x: 285, y: 300), destination]
    }
}

struct MapPoint {
    let x: Double
    let y: Double
}

struct MapSize {
    let width: Double
    let height: Double
}

struct MapBlock {
    let center: MapPoint
    let size: MapSize
    let cornerRadius: Double
    let opacity: Double
    let rotationDegrees: Double
}

struct RouteControls {
    let firstControl: MapPoint
    let secondControl: MapPoint
    let end: MapPoint
}

struct MapStreet {
    let id: String
    let start: MapPoint
    let end: MapPoint

    func path(in viewport: MapSvgViewport) -> Path {
        var path = Path()
        path.move(to: viewport.point(start))
        path.addLine(to: viewport.point(end))
        return path
    }
}

struct MapSvgViewport {
    let scale: Double
    let offsetX: Double
    let offsetY: Double

    init(size: CGSize) {
        let viewport = RideMapGeometry.viewportSize
        scale = max(Double(size.width) / viewport.width, Double(size.height) / viewport.height)
        offsetX = (Double(size.width) - viewport.width * scale) / 2
        offsetY = (Double(size.height) - viewport.height * scale) / 2
    }

    func point(_ point: MapPoint) -> CGPoint {
        CGPoint(x: offsetX + point.x * scale, y: offsetY + point.y * scale)
    }

    func length(_ value: Double) -> CGFloat {
        CGFloat(value * scale)
    }
}
