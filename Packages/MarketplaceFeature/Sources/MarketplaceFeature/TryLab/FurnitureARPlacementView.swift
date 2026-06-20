import SwiftUI
import RealityKit
import ARKit
import MarketplaceService

/// Furniture AR Placement using RealityKit
/// Per Section 6 of implementation-plan.md
struct FurnitureARPlacementView: View {
    let listing: Listing
    @ObservedObject var viewModel: MarketplaceViewModel
    
    @State private var showingARView = false
    @State private var arPlacementResult: ARPlacementResult?
    @State private var selectedRoom: RoomType = .livingRoom
    @State private var roomDimensions: RoomDimensions?
    @State private var showingRoomMeasurement = false
    @State private var placementOptions: PlacementOptions = PlacementOptions()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("AR Placement")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("See how this \(listing.title) looks in your space")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // AR Requirements check
                ARRequirementsSection()
                
                // Room selection
                RoomSelectionSection(
                    selectedRoom: $selectedRoom,
                    roomDimensions: $roomDimensions,
                    showingRoomMeasurement: $showingRoomMeasurement
                )
                
                // Furniture dimensions
                FurnitureDimensionsSection(listing: listing)
                
                // Placement options
                PlacementOptionsSection(options: $placementOptions)
                
                // AR button
                if ARWorldTrackingConfiguration.isSupported {
                    Button(action: { showingARView = true }) {
                        HStack {
                            Image(systemName: "arkit")
                            Text("Start AR Placement")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // Results
                if let result = arPlacementResult {
                    ARPlacementResultSection(result: result)
                }
                
                // Tips
                ARPlacementTipsSection()
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showingARView) {
            ARPlacementView(
                listing: listing,
                selectedRoom: selectedRoom,
                placementOptions: placementOptions,
                onResult: { result in
                    arPlacementResult = result
                }
            )
        }
        .sheet(isPresented: $showingRoomMeasurement) {
            RoomMeasurementGuideView(roomDimensions: $roomDimensions)
        }
    }
}

// MARK: - Room Types and Models

enum RoomType: String, CaseIterable {
    case livingRoom = "living_room"
    case bedroom = "bedroom"
    case diningRoom = "dining_room"
    case kitchen = "kitchen"
    case office = "office"
    case bathroom = "bathroom"
    
    var displayName: String {
        switch self {
        case .livingRoom: return "Living Room"
        case .bedroom: return "Bedroom"
        case .diningRoom: return "Dining Room"
        case .kitchen: return "Kitchen"
        case .office: return "Office"
        case .bathroom: return "Bathroom"
        }
    }
    
    var icon: String {
        switch self {
        case .livingRoom: return "sofa"
        case .bedroom: return "bed.double"
        case .diningRoom: return "table.furniture"
        case .kitchen: return "oven"
        case .office: return "desk"
        case .bathroom: return "bathtub"
        }
    }
}

struct RoomDimensions {
    let width: Double // meters
    let length: Double // meters
    let height: Double // meters
    
    var area: Double {
        width * length
    }
    
    var displayString: String {
        "\(String(format: "%.1f", width))m × \(String(format: "%.1f", length))m"
    }
}

struct PlacementOptions {
    var checkClearance: Bool = true
    var showDimensions: Bool = true
    var snapToWalls: Bool = false
    var checkDoorways: Bool = true
}

// MARK: - AR Requirements

struct ARRequirementsSection: View {
    @State private var arSupported = ARWorldTrackingConfiguration.isSupported
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AR Requirements")
                .font(.headline)
            
            VStack(spacing: 8) {
                RequirementRow(
                    title: "AR Support",
                    isAvailable: arSupported,
                    description: arSupported ? "Your device supports AR" : "AR not supported on this device"
                )
                
                RequirementRow(
                    title: "Camera Access",
                    isAvailable: cameraPermission == .authorized,
                    description: cameraPermission == .authorized ? "Camera access granted" : "Camera access required"
                )
                
                RequirementRow(
                    title: "Good Lighting",
                    isAvailable: true,
                    description: "Ensure your room has adequate lighting"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            checkCameraPermission()
        }
    }
    
    private func checkCameraPermission() {
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        
        if cameraPermission == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .authorized : .denied
                }
            }
        }
    }
}

struct RequirementRow: View {
    let title: String
    let isAvailable: Bool
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isAvailable ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Room Selection

struct RoomSelectionSection: View {
    @Binding var selectedRoom: RoomType
    @Binding var roomDimensions: RoomDimensions?
    @Binding var showingRoomMeasurement: Bool
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Room Type")
                .font(.headline)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(RoomType.allCases, id: \.self) { room in
                    RoomTypeCard(
                        room: room,
                        isSelected: selectedRoom == room,
                        onSelect: { selectedRoom = room }
                    )
                }
            }
            
            // Room dimensions
            VStack(alignment: .leading, spacing: 8) {
                Text("Room Dimensions (Optional)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let dimensions = roomDimensions {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dimensions.displayString)
                                .font(.subheadline)
                            Text("Area: \(String(format: "%.1f", dimensions.area)) m²")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Edit") {
                            showingRoomMeasurement = true
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                } else {
                    Button("Measure Room") {
                        showingRoomMeasurement = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Text("Room dimensions help ensure furniture fits and provide clearance warnings")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RoomTypeCard: View {
    let room: RoomType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: room.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(room.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Furniture Dimensions

struct FurnitureDimensionsSection: View {
    let listing: Listing
    
    private var dimensions: FurnitureDimensions {
        // Extract from listing attributes or estimate
        FurnitureDimensions(
            width: Double(listing.attributes["width"] ?? "120") ?? 120,
            depth: Double(listing.attributes["depth"] ?? "60") ?? 60,
            height: Double(listing.attributes["height"] ?? "75") ?? 75,
            weight: Double(listing.attributes["weight"] ?? "25") ?? 25
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Furniture Specifications")
                .font(.headline)
            
            VStack(spacing: 12) {
                DimensionRow(label: "Width", value: dimensions.width, unit: "cm")
                DimensionRow(label: "Depth", value: dimensions.depth, unit: "cm")
                DimensionRow(label: "Height", value: dimensions.height, unit: "cm")
                DimensionRow(label: "Weight", value: dimensions.weight, unit: "kg")
            }
            
            // 3D preview placeholder
            VStack(spacing: 8) {
                Text("3D Preview")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Rectangle()
                    .foregroundColor(.gray.opacity(0.2))
                    .frame(height: 120)
                    .cornerRadius(8)
                    .overlay(
                        VStack {
                            Image(systemName: "cube.fill")
                                .font(.title)
                                .foregroundColor(.gray)
                            Text("3D Model")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FurnitureDimensions {
    let width: Double // cm
    let depth: Double // cm
    let height: Double // cm
    let weight: Double // kg
}

struct DimensionRow: View {
    let label: String
    let value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text("\(String(format: "%.0f", value)) \(unit)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

// MARK: - Placement Options

struct PlacementOptionsSection: View {
    @Binding var options: PlacementOptions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Placement Options")
                .font(.headline)
            
            VStack(spacing: 12) {
                OptionToggle(
                    title: "Check Clearance",
                    description: "Verify walkway space around furniture",
                    isOn: $options.checkClearance
                )
                
                OptionToggle(
                    title: "Show Dimensions",
                    description: "Display measurements in AR view",
                    isOn: $options.showDimensions
                )
                
                OptionToggle(
                    title: "Snap to Walls",
                    description: "Automatically align with detected walls",
                    isOn: $options.snapToWalls
                )
                
                OptionToggle(
                    title: "Check Doorways",
                    description: "Ensure furniture fits through doorways",
                    isOn: $options.checkDoorways
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct OptionToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - AR Placement Result

struct ARPlacementResult {
    let placementSuccessful: Bool
    let fitAnalysis: FitAnalysis
    let clearanceWarnings: [String]
    let recommendations: [String]
    let placementImage: String? // Screenshot from AR
}

struct FitAnalysis {
    let fitsInRoom: Bool
    let clearanceScore: Int // 0-100
    let accessibilityScore: Int // 0-100
    let visualHarmony: Int // 0-100
}

struct ARPlacementResultSection: View {
    let result: ARPlacementResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status
            HStack {
                Image(systemName: result.placementSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.placementSuccessful ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.placementSuccessful ? "Placement Successful" : "Placement Issues")
                        .font(.headline)
                        .foregroundColor(result.placementSuccessful ? .green : .red)
                    
                    Text("Analysis complete")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(result.placementSuccessful ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .cornerRadius(12)
            
            // Fit analysis scores
            if result.placementSuccessful {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fit Analysis")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScoreRow(
                        title: "Room Fit",
                        score: result.fitAnalysis.fitsInRoom ? 100 : 0,
                        icon: "house"
                    )
                    
                    ScoreRow(
                        title: "Clearance",
                        score: result.fitAnalysis.clearanceScore,
                        icon: "arrow.up.and.down.and.arrow.left.and.right"
                    )
                    
                    ScoreRow(
                        title: "Accessibility",
                        score: result.fitAnalysis.accessibilityScore,
                        icon: "figure.walk"
                    )
                    
                    ScoreRow(
                        title: "Visual Harmony",
                        score: result.fitAnalysis.visualHarmony,
                        icon: "eye"
                    )
                }
            }
            
            // Warnings
            if !result.clearanceWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Clearance Warnings", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    ForEach(result.clearanceWarnings, id: \.self) { warning in
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Recommendations
            if !result.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendations")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(result.recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(recommendation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ScoreRow: View {
    let title: String
    let score: Int
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(scoreColor)
                .frame(width: 20)
            
            Text(title)
                .font(.caption)
                .frame(width: 80, alignment: .leading)
            
            ProgressView(value: Double(score), total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: scoreColor))
            
            Text("\(score)%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(scoreColor)
        }
    }
    
    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60...79: return .orange
        default: return .red
        }
    }
}

// MARK: - AR Tips

struct ARPlacementTipsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AR Placement Tips", systemImage: "lightbulb")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                TipRow(icon: "light.max", text: "Ensure good lighting for better tracking")
                TipRow(icon: "iphone", text: "Move your device slowly for best results")
                TipRow(icon: "camera.viewfinder", text: "Point at the floor to detect surfaces")
                TipRow(icon: "move.3d", text: "Tap and drag to reposition furniture")
                TipRow(icon: "ruler", text: "Use room dimensions for accurate scaling")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - AR View

struct ARPlacementView: UIViewRepresentable {
    let listing: Listing
    let selectedRoom: RoomType
    let placementOptions: PlacementOptions
    let onResult: (ARPlacementResult) -> Void
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        
        // Add coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coachingOverlay)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update AR view if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: ARPlacementView
        
        init(_ parent: ARPlacementView) {
            self.parent = parent
        }
    }
}

// Placeholder views
struct RoomMeasurementGuideView: View {
    @Binding var roomDimensions: RoomDimensions?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Room Measurement Guide")
                Text("Step-by-step room measurement instructions")
                
                Button("Save Dimensions") {
                    roomDimensions = RoomDimensions(width: 4.0, length: 5.0, height: 2.8)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Measure Room")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}