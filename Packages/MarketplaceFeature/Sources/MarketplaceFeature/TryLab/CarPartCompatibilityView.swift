import SwiftUI
import MarketplaceService

/// Car Part Compatibility checker using userTraits.carModel
/// Per Section 6 of implementation-plan.md
struct CarPartCompatibilityView: View {
    let listing: Listing
    @ObservedObject var viewModel: MarketplaceViewModel
    
    @State private var selectedCarModel: CarModel?
    @State private var compatibilityResult: CompatibilityResult?
    @State private var isChecking = false
    @State private var showingCarSelector = false
    @State private var showingTutorials = false
    @State private var installationTutorials: [InstallationTutorial] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compatibility Check")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Check if this \(listing.title) fits your vehicle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Car selection
                CarSelectionSection(
                    selectedCar: $selectedCarModel,
                    showingCarSelector: $showingCarSelector
                )
                
                // Part information
                PartInformationSection(listing: listing)
                
                // Compatibility check button
                if selectedCarModel != nil {
                    Button(action: checkCompatibility) {
                        HStack {
                            if isChecking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Checking compatibility...")
                            } else {
                                Image(systemName: "checkmark.shield")
                                Text("Check Compatibility")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isChecking)
                }
                
                // Results
                if let result = compatibilityResult {
                    CompatibilityResultSection(
                        result: result,
                        onShowTutorials: {
                            showingTutorials = true
                        }
                    )
                }
                
                // Installation guide
                if !installationTutorials.isEmpty {
                    InstallationGuideSection(tutorials: installationTutorials)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingCarSelector) {
            CarSelectorView(selectedCar: $selectedCarModel)
        }
        .sheet(isPresented: $showingTutorials) {
            TutorialListView(tutorials: installationTutorials)
        }
        .onAppear {
            loadUserCarModel()
        }
    }
    
    private func loadUserCarModel() {
        // Would load from userTraits.carModel via Parent AI
        selectedCarModel = CarModel(
            make: "Toyota",
            model: "Camry",
            year: 2020,
            engine: "2.5L",
            trim: "LE"
        )
    }
    
    private func checkCompatibility() {
        guard let car = selectedCarModel else { return }
        
        isChecking = true
        
        // Simulate compatibility check
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            compatibilityResult = CompatibilityResult(
                isCompatible: true,
                compatibilityScore: 95,
                fitNotes: [
                    "Direct fit for \(car.year) \(car.make) \(car.model)",
                    "No modifications required",
                    "OEM quality replacement"
                ],
                warnings: [],
                alternativeParts: [],
                installationDifficulty: .moderate,
                estimatedInstallTime: "45-60 minutes",
                requiredTools: ["Socket wrench set", "Phillips screwdriver", "Jack and stands"]
            )
            
            installationTutorials = [
                InstallationTutorial(
                    title: "How to Replace \(listing.title)",
                    videoUrl: "https://youtube.com/watch?v=example1",
                    duration: "12:34",
                    difficulty: "Moderate",
                    views: "125K",
                    thumbnailUrl: ""
                ),
                InstallationTutorial(
                    title: "Tools Needed for Installation",
                    videoUrl: "https://youtube.com/watch?v=example2",
                    duration: "5:42",
                    difficulty: "Beginner",
                    views: "89K",
                    thumbnailUrl: ""
                )
            ]
            
            isChecking = false
        }
    }
}

// MARK: - Car Model

struct CarModel {
    let make: String
    let model: String
    let year: Int
    let engine: String?
    let trim: String?
    
    var displayName: String {
        var name = "\(year) \(make) \(model)"
        if let trim = trim {
            name += " \(trim)"
        }
        if let engine = engine {
            name += " (\(engine))"
        }
        return name
    }
}

// MARK: - Car Selection

struct CarSelectionSection: View {
    @Binding var selectedCar: CarModel?
    @Binding var showingCarSelector: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Vehicle")
                .font(.headline)
            
            if let car = selectedCar {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(car.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Tap to change vehicle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onTapGesture {
                        showingCarSelector = true
                    }
                }
            } else {
                Button(action: { showingCarSelector = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Your Vehicle")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            Text("We'll use your vehicle information to check part compatibility")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Part Information

struct PartInformationSection: View {
    let listing: Listing
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Part Information")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                // Part image
                if let imageUrl = listing.images.first {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.2))
                    }
                    .frame(height: 150)
                    .cornerRadius(8)
                }
                
                // Part details from attributes
                if !listing.attributes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(listing.attributes.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(formatAttributeKey(key))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 100, alignment: .leading)
                                
                                Text(listing.attributes[key] ?? "")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                            }
                        }
                    }
                } else {
                    // Default attributes for demo
                    VStack(alignment: .leading, spacing: 8) {
                        AttributeRow(key: "Part Number", value: "12345-ABC-789")
                        AttributeRow(key: "Brand", value: "OEM")
                        AttributeRow(key: "Condition", value: listing.condition.displayName)
                        AttributeRow(key: "Warranty", value: "30 days")
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatAttributeKey(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct AttributeRow: View {
    let key: String
    let value: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

// MARK: - Compatibility Result

struct CompatibilityResult {
    let isCompatible: Bool
    let compatibilityScore: Int // 0-100
    let fitNotes: [String]
    let warnings: [String]
    let alternativeParts: [String]
    let installationDifficulty: InstallationDifficulty
    let estimatedInstallTime: String
    let requiredTools: [String]
}

enum InstallationDifficulty: String, CaseIterable {
    case easy = "Easy"
    case moderate = "Moderate"
    case difficult = "Difficult"
    case professional = "Professional Required"
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .moderate: return .orange
        case .difficult: return .red
        case .professional: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .easy: return "1.circle.fill"
        case .moderate: return "2.circle.fill"
        case .difficult: return "3.circle.fill"
        case .professional: return "wrench.and.screwdriver.fill"
        }
    }
}

struct CompatibilityResultSection: View {
    let result: CompatibilityResult
    let onShowTutorials: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Compatibility status
            HStack {
                Image(systemName: result.isCompatible ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.isCompatible ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.isCompatible ? "Compatible" : "Not Compatible")
                        .font(.headline)
                        .foregroundColor(result.isCompatible ? .green : .red)
                    
                    if result.isCompatible {
                        Text("\(result.compatibilityScore)% match")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(result.isCompatible ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .cornerRadius(12)
            
            if result.isCompatible {
                // Fit notes
                if !result.fitNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fit Information")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(result.fitNotes, id: \.self) { note in
                            HStack(alignment: .top) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Installation info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Installation")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Difficulty")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: result.installationDifficulty.icon)
                                    .foregroundColor(result.installationDifficulty.color)
                                Text(result.installationDifficulty.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(result.installationDifficulty.color)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Est. Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(result.estimatedInstallTime)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    
                    // Required tools
                    if !result.requiredTools.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Required Tools")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            FlowLayout(items: result.requiredTools) { tool in
                                Text(tool)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // Tutorial button
                Button(action: onShowTutorials) {
                    Label("View Installation Tutorials", systemImage: "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                // Alternative suggestions
                if !result.alternativeParts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alternative Parts")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(result.alternativeParts, id: \.self) { part in
                            Text("• \(part)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Warnings
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Important Notes", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    ForEach(result.warnings, id: \.self) { warning in
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
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Installation Guide

struct InstallationTutorial {
    let title: String
    let videoUrl: String
    let duration: String
    let difficulty: String
    let views: String
    let thumbnailUrl: String
}

struct InstallationGuideSection: View {
    let tutorials: [InstallationTutorial]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Installation Tutorials")
                .font(.headline)
            
            ForEach(Array(tutorials.enumerated()), id: \.offset) { index, tutorial in
                TutorialRow(tutorial: tutorial)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TutorialRow: View {
    let tutorial: InstallationTutorial
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: tutorial.thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 80, height: 60)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tutorial.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack {
                    Text(tutorial.duration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(tutorial.difficulty)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(tutorial.views) views")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .onTapGesture {
            // Would open tutorial video
        }
    }
}

// MARK: - Helper Views

struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(chunks(items, size: 3), id: \.self) { chunk in
                HStack {
                    ForEach(chunk, id: \.self) { item in
                        content(item)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private func chunks<T>(_ array: [T], size: Int) -> [[T]] {
        return stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }
}

// Placeholder views
struct CarSelectorView: View {
    @Binding var selectedCar: CarModel?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Car Selector")
                Text("Would implement car search and selection here")
                
                Button("Select Toyota Camry 2020") {
                    selectedCar = CarModel(
                        make: "Toyota",
                        model: "Camry",
                        year: 2020,
                        engine: "2.5L",
                        trim: "LE"
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Select Vehicle")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

struct TutorialListView: View {
    let tutorials: [InstallationTutorial]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(Array(tutorials.enumerated()), id: \.offset) { index, tutorial in
                TutorialRow(tutorial: tutorial)
            }
            .navigationTitle("Installation Tutorials")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}