import SwiftUI
import MarketplaceService
import AVFoundation

/// Apparel Try-On feature using on-device body segmentation
/// Per Section 6 of implementation-plan.md
struct ApparelTryOnView: View {
    let listing: Listing
    @ObservedObject var viewModel: MarketplaceViewModel
    
    @State private var selectedBodyMetrics: BodyMetrics?
    @State private var showingCamera = false
    @State private var showingBodyMeasurement = false
    @State private var capturedPhoto: UIImage?
    @State private var tryOnResult: TryOnResult?
    @State private var isProcessing = false
    @State private var selectedSize: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Virtual Try-On")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("See how this \(listing.category.displayName.lowercased()) looks on you")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Safety disclaimer
                DisclaimerCard()
                
                // Body metrics input
                BodyMetricsSection(
                    selectedMetrics: $selectedBodyMetrics,
                    showingBodyMeasurement: $showingBodyMeasurement
                )
                
                // Photo capture
                PhotoCaptureSection(
                    capturedPhoto: $capturedPhoto,
                    showingCamera: $showingCamera
                )
                
                // Size recommendation
                if let metrics = selectedBodyMetrics {
                    SizeRecommendationSection(
                        metrics: metrics,
                        selectedSize: $selectedSize,
                        listing: listing
                    )
                }
                
                // Try-on button
                if selectedBodyMetrics != nil && (capturedPhoto != nil || canUseExistingPhoto) {
                    Button(action: performTryOn) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Processing...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Try On")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                }
                
                // Results
                if let result = tryOnResult {
                    TryOnResultSection(result: result)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingCamera) {
            TryOnCameraView(capturedPhoto: $capturedPhoto)
        }
        .sheet(isPresented: $showingBodyMeasurement) {
            BodyMeasurementGuideView(bodyMetrics: $selectedBodyMetrics)
        }
    }
    
    private var canUseExistingPhoto: Bool {
        // Would check if user has authorized photos from previous try-ons
        false
    }
    
    private func performTryOn() {
        isProcessing = true
        
        // Simulate AI processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            tryOnResult = TryOnResult(
                previewImage: listing.images.first ?? "",
                fitScore: 85,
                sizeRecommendation: selectedSize ?? "M",
                fitAnalysis: "Good fit for your measurements. The shoulders and waist appear well-proportioned.",
                alterationSuggestions: selectedSize == "S" ? ["Consider taking in the waist slightly"] : []
            )
            isProcessing = false
        }
    }
}

// MARK: - Body Metrics

struct BodyMetrics {
    let tops: String? // S, M, L, XL
    let bottoms: String?
    let shoes: String?
    let measurements: BodyMeasurements?
    
    struct BodyMeasurements {
        let chest: Double // cm
        let waist: Double // cm
        let hips: Double // cm
        let height: Double // cm
    }
}

struct BodyMetricsSection: View {
    @Binding var selectedMetrics: BodyMetrics?
    @Binding var showingBodyMeasurement: Bool
    
    @State private var topSize = ""
    @State private var bottomSize = ""
    @State private var shoeSize = ""
    @State private var useDetailedMeasurements = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Size Information")
                .font(.headline)
            
            // Size selection
            VStack(spacing: 12) {
                HStack {
                    Text("Tops")
                        .frame(width: 80, alignment: .leading)
                    Picker("Top Size", selection: $topSize) {
                        Text("Select").tag("")
                        ForEach(["XS", "S", "M", "L", "XL", "XXL"], id: \.self) { size in
                            Text(size).tag(size)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                HStack {
                    Text("Bottoms")
                        .frame(width: 80, alignment: .leading)
                    Picker("Bottom Size", selection: $bottomSize) {
                        Text("Select").tag("")
                        ForEach(["XS", "S", "M", "L", "XL", "XXL"], id: \.self) { size in
                            Text(size).tag(size)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                HStack {
                    Text("Shoes")
                        .frame(width: 80, alignment: .leading)
                    Picker("Shoe Size", selection: $shoeSize) {
                        Text("Select").tag("")
                        ForEach(35...48, id: \.self) { size in
                            Text("\(size)").tag("\(size)")
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            // Detailed measurements option
            Toggle("Use detailed measurements for better accuracy", isOn: $useDetailedMeasurements)
                .font(.subheadline)
            
            if useDetailedMeasurements {
                Button("Measure with Guide") {
                    showingBodyMeasurement = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onChange(of: topSize) { _ in updateMetrics() }
        .onChange(of: bottomSize) { _ in updateMetrics() }
        .onChange(of: shoeSize) { _ in updateMetrics() }
    }
    
    private func updateMetrics() {
        selectedMetrics = BodyMetrics(
            tops: topSize.isEmpty ? nil : topSize,
            bottoms: bottomSize.isEmpty ? nil : bottomSize,
            shoes: shoeSize.isEmpty ? nil : shoeSize,
            measurements: nil // Would be set by measurement guide
        )
    }
}

// MARK: - Photo Capture

struct PhotoCaptureSection: View {
    @Binding var capturedPhoto: UIImage?
    @Binding var showingCamera: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Photo")
                .font(.headline)
            
            if let photo = capturedPhoto {
                VStack(spacing: 12) {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .cornerRadius(12)
                    
                    Button("Retake Photo") {
                        showingCamera = true
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        Text("Take a full-body photo")
                            .font(.headline)
                        
                        Text("Stand against a plain background with good lighting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    Button("Take Photo") {
                        showingCamera = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            // Privacy note
            Text("Photos are processed on-device and automatically deleted after try-on")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Size Recommendation

struct SizeRecommendationSection: View {
    let metrics: BodyMetrics
    @Binding var selectedSize: String?
    let listing: Listing
    
    private let availableSizes = ["XS", "S", "M", "L", "XL"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Size Recommendation")
                .font(.headline)
            
            // Recommended size
            if let recommendedSize = getRecommendedSize() {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("We recommend size \(recommendedSize) based on your measurements")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Size selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Select size to try on:")
                    .font(.subheadline)
                
                HStack {
                    ForEach(availableSizes, id: \.self) { size in
                        Button(size) {
                            selectedSize = size
                        }
                        .buttonStyle(.bordered)
                        .background(selectedSize == size ? Color.blue : Color.clear)
                        .foregroundColor(selectedSize == size ? .white : .primary)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            selectedSize = getRecommendedSize()
        }
    }
    
    private func getRecommendedSize() -> String? {
        // Simplified size recommendation logic
        return metrics.tops ?? "M"
    }
}

// MARK: - Try-On Result

struct TryOnResult {
    let previewImage: String
    let fitScore: Int // 0-100
    let sizeRecommendation: String
    let fitAnalysis: String
    let alterationSuggestions: [String]
}

struct TryOnResultSection: View {
    let result: TryOnResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Try-On Result")
                .font(.headline)
            
            // Preview image (would show actual try-on result)
            AsyncImage(url: URL(string: result.previewImage)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.2))
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                            Text("Try-on preview")
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                    )
            }
            .frame(height: 300)
            .cornerRadius(12)
            .overlay(
                Text("Preview Only - May Differ from Actual Fit")
                    .font(.caption2)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(),
                alignment: .topLeading
            )
            
            // Fit score
            VStack(alignment: .leading, spacing: 8) {
                Text("Fit Score")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    ProgressView(value: Double(result.fitScore), total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: fitScoreColor))
                    
                    Text("\(result.fitScore)%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(fitScoreColor)
                }
            }
            
            // Analysis
            VStack(alignment: .leading, spacing: 8) {
                Text("Fit Analysis")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(result.fitAnalysis)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Alteration suggestions
            if !result.alterationSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alteration Suggestions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(result.alterationSuggestions, id: \.self) { suggestion in
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.blue)
                            Text(suggestion)
                                .font(.body)
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
    
    private var fitScoreColor: Color {
        switch result.fitScore {
        case 80...100: return .green
        case 60...79: return .orange
        default: return .red
        }
    }
}

// MARK: - Helper Views

struct DisclaimerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Important")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Preview only - actual fit may differ")
                Text("• Photos processed securely on your device")
                Text("• No images are stored or shared")
                Text("• Results are for guidance only")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// Placeholder views
struct TryOnCameraView: View {
    @Binding var capturedPhoto: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Camera View")
            Text("Would implement AVFoundation camera here")
            
            Button("Simulate Photo Taken") {
                // Simulate taking a photo
                capturedPhoto = UIImage(systemName: "person.fill")
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Cancel") {
                dismiss()
            }
        }
    }
}

struct BodyMeasurementGuideView: View {
    @Binding var bodyMetrics: BodyMetrics?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Body Measurement Guide")
                Text("Step-by-step measurement instructions would go here")
                
                Button("Save Measurements") {
                    // Would save detailed measurements
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Measurements")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}