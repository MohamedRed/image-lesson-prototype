import AppKit
import RideSharingFeature
import SwiftUI

@main
struct RideSharingFeatureSnapshot {
    @MainActor
    static func main() throws {
        guard #available(macOS 13.0, *) else {
            throw SnapshotError.unsupportedPlatform
        }

        let outputDirectory = outputURL()
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        for snapshot in SnapshotState.all {
            try render(snapshot, into: outputDirectory)
        }

        print("Liive Ride iOS snapshots written to \(outputDirectory.path)")
    }

    private static func outputURL() -> URL {
        if CommandLine.arguments.count > 1 {
            return URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        }

        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("liive-ride-ios-snapshots", isDirectory: true)
    }

    @available(macOS 13.0, *)
    @MainActor
    private static func render(_ snapshot: SnapshotState, into directory: URL) throws {
        let previousAppearance = NSApplication.shared.appearance
        NSApplication.shared.appearance = snapshot.appearance
        defer { NSApplication.shared.appearance = previousAppearance }

        let view = RideSharingView(
            service: MockRideSharingService(),
            preferredColorScheme: snapshot.colorScheme,
            initialState: snapshot.state
        )
        .environment(\.colorScheme, snapshot.colorScheme)
        .frame(width: SnapshotMetrics.width, height: SnapshotMetrics.height)

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(
            width: SnapshotMetrics.width,
            height: SnapshotMetrics.height
        )
        renderer.scale = SnapshotMetrics.scale

        guard let image = renderer.nsImage else {
            throw SnapshotError.renderFailed(snapshot.filename)
        }

        let destination = directory.appendingPathComponent(snapshot.filename)
        try writePNG(image, to: destination)
        print("captured \(destination.path)")
    }

    private static func writePNG(_ image: NSImage, to url: URL) throws {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw SnapshotError.pngEncodingFailed(url.lastPathComponent)
        }

        try pngData.write(to: url)
    }
}

private enum SnapshotMetrics {
    static let width = 402.0
    static let height = 740.0
    static let scale = 2.0
}

private struct SnapshotState {
    let filename: String
    let colorScheme: ColorScheme
    let state: RideUIState

    init(_ filename: String, _ colorScheme: ColorScheme, _ state: RideUIState) {
        self.filename = filename
        self.colorScheme = colorScheme
        self.state = state
    }

    var appearance: NSAppearance? {
        switch colorScheme {
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .light:
            return NSAppearance(named: .aqua)
        @unknown default:
            return NSAppearance(named: .darkAqua)
        }
    }

    static let all: [SnapshotState] = [
        SnapshotState("01-destination-dark.png", .dark, RideUIState()),
        SnapshotState("02-options-dark.png", .dark, options(tier: .premium)),
        SnapshotState("03-matching-dark.png", .dark, phase(.matching, tier: .pool)),
        SnapshotState("04-enroute-dark.png", .dark, enroute),
        SnapshotState("05-payment-dark.png", .dark, payment),
        SnapshotState("06-receipt-dark.png", .dark, receipt),
        SnapshotState("07-destination-light.png", .light, RideUIState()),
        SnapshotState("08-options-light.png", .light, options(tier: .premium)),
        SnapshotState("09-matching-light.png", .light, phase(.matching, tier: .pool)),
        SnapshotState("10-enroute-light.png", .light, enroute),
        SnapshotState("11-payment-light.png", .light, payment),
        SnapshotState("12-receipt-light.png", .light, receipt)
    ]

    private static var enroute: RideUIState {
        var state = phase(.enroute, tier: .pool)
        state.carProgress = 0.56
        return state
    }

    private static var payment: RideUIState {
        var state = phase(.complete, tier: .premium)
        state.carProgress = 1
        state.rating = 4
        return state
    }

    private static var receipt: RideUIState {
        var state = payment
        state.paid = true
        state.rating = 5
        return state
    }

    private static func phase(_ phase: RidePhase, tier: RideTier) -> RideUIState {
        var state = options(tier: tier)
        state.phase = phase
        return state
    }

    private static func options(tier: RideTier) -> RideUIState {
        let destination = unionSquare
        var state = RideUIState()
        state.phase = .options
        state.destination = destination
        state.config = RideConfiguration(
            tier: tier,
            femaleOnly: tier == .pool,
            destinationName: destination.title
        )
        state.tripSummary = RideTripSummary(configuration: state.config)
        state.driver = RideDriver(
            name: "John Driver",
            rating: 4.8,
            vehicle: "Toyota Camry · Blue",
            plate: "ABC 123"
        )
        return state
    }

    private static let unionSquare = RideDestination(
        id: "union-square",
        systemImage: "clock",
        color: "neutral",
        title: "Union Square",
        subtitle: "Geary & Powell"
    )
}

private enum SnapshotError: Error, CustomStringConvertible {
    case unsupportedPlatform
    case renderFailed(String)
    case pngEncodingFailed(String)

    var description: String {
        switch self {
        case .unsupportedPlatform:
            return "RideSharingFeatureSnapshot requires macOS 13 or newer."
        case .renderFailed(let name):
            return "SwiftUI rendering returned no image for \(name)."
        case .pngEncodingFailed(let name):
            return "Could not encode \(name) as PNG."
        }
    }
}
