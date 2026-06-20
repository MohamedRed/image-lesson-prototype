import SwiftUI
import SceneKit
import MealPlanningService

struct BodyAssistantView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @State private var selectedRegions: [BodyRegion] = []
    @State private var selectedSymptoms: [String] = []
    @State private var showingAdvice = false
    @State private var nutritionAdvice: NutritionAdvice?
    @State private var isLoading = false
    
    private let bodyRegions = [
        BodyRegion(name: "Heart", anatomicalId: "heart", relatedNutrients: ["omega_3", "potassium", "fiber"]),
        BodyRegion(name: "Brain", anatomicalId: "brain", relatedNutrients: ["omega_3", "vitamin_d", "antioxidants"]),
        BodyRegion(name: "Digestive System", anatomicalId: "digestive", relatedNutrients: ["fiber", "probiotics", "prebiotics"]),
        BodyRegion(name: "Bones", anatomicalId: "bones", relatedNutrients: ["calcium", "vitamin_d", "magnesium"]),
        BodyRegion(name: "Muscles", anatomicalId: "muscles", relatedNutrients: ["protein", "creatine", "leucine"]),
        BodyRegion(name: "Liver", anatomicalId: "liver", relatedNutrients: ["antioxidants", "vitamin_e", "selenium"]),
        BodyRegion(name: "Skin", anatomicalId: "skin", relatedNutrients: ["vitamin_c", "vitamin_e", "zinc"]),
        BodyRegion(name: "Eyes", anatomicalId: "eyes", relatedNutrients: ["vitamin_a", "lutein", "zeaxanthin"])
    ]
    
    private let commonSymptoms = [
        "fatigue", "digestive_issues", "joint_pain", "poor_sleep",
        "stress", "low_energy", "headaches", "skin_issues"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Functional Nutrition Assistant")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Select body areas you'd like to support with targeted nutrition")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 3D Body Visualization
                        Body3DView(selectedRegions: $selectedRegions)
                            .frame(height: 300)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        
                        // Body Regions List
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Body Areas")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(bodyRegions, id: \.anatomicalId) { region in
                                    BodyRegionCard(
                                        region: region,
                                        isSelected: selectedRegions.contains { $0.anatomicalId == region.anatomicalId }
                                    ) {
                                        toggleRegion(region)
                                    }
                                }
                            }
                        }
                        
                        // Symptoms Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Current Symptoms (Optional)")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(commonSymptoms, id: \.self) { symptom in
                                    SymptomChip(
                                        symptom: symptom,
                                        isSelected: selectedSymptoms.contains(symptom)
                                    ) {
                                        toggleSymptom(symptom)
                                    }
                                }
                            }
                        }
                        
                        // Get Advice Button
                        Button {
                            getAdvice()
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                
                                Image(systemName: "brain.head.profile")
                                Text("Get Nutrition Advice")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedRegions.isEmpty || isLoading)
                        
                        // Disclaimer
                        VStack(spacing: 8) {
                            Text("⚠️ Important Disclaimer")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Text("This advice is for wellness purposes only and not a substitute for professional medical advice. Always consult with a healthcare provider for medical concerns.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAdvice) {
            if let advice = nutritionAdvice {
                NutritionAdviceSheet(advice: advice)
                    .environmentObject(viewModel)
            }
        }
    }
    
    private func toggleRegion(_ region: BodyRegion) {
        if selectedRegions.contains(where: { $0.anatomicalId == region.anatomicalId }) {
            selectedRegions.removeAll { $0.anatomicalId == region.anatomicalId }
        } else {
            selectedRegions.append(region)
        }
    }
    
    private func toggleSymptom(_ symptom: String) {
        if selectedSymptoms.contains(symptom) {
            selectedSymptoms.removeAll { $0 == symptom }
        } else {
            selectedSymptoms.append(symptom)
        }
    }
    
    private func getAdvice() {
        guard !selectedRegions.isEmpty else { return }
        
        isLoading = true
        
        Task {
            await viewModel.getNutritionAdvice(bodyRegions: selectedRegions, symptoms: selectedSymptoms)
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.showingAdvice = true
            }
        }
    }
}

// MARK: - 3D Body View

struct Body3DView: UIViewRepresentable {
    @Binding var selectedRegions: [BodyRegion]
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = createBodyScene()
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = UIColor.systemGray6
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateSelectedRegions(selectedRegions)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createBodyScene() -> SCNScene {
        let scene = SCNScene()
        
        // Create a simplified 3D body using basic shapes
        let bodyGroup = SCNNode()
        
        // Head
        let headGeometry = SCNSphere(radius: 0.8)
        let headNode = SCNNode(geometry: headGeometry)
        headNode.position = SCNVector3(0, 4, 0)
        headNode.name = "brain"
        bodyGroup.addChildNode(headNode)
        
        // Torso
        let torsoGeometry = SCNCylinder(radius: 1.2, height: 3.0)
        let torsoNode = SCNNode(geometry: torsoGeometry)
        torsoNode.position = SCNVector3(0, 1.5, 0)
        torsoNode.name = "heart"
        bodyGroup.addChildNode(torsoNode)
        
        // Arms
        for i in [-1, 1] {
            let armGeometry = SCNCylinder(radius: 0.3, height: 2.5)
            let armNode = SCNNode(geometry: armGeometry)
            armNode.position = SCNVector3(Float(i) * 1.8, 2.0, 0)
            armNode.eulerAngles = SCNVector3(0, 0, Float.pi/2)
            armNode.name = "muscles"
            bodyGroup.addChildNode(armNode)
        }
        
        // Legs
        for i in [-1, 1] {
            let legGeometry = SCNCylinder(radius: 0.4, height: 3.0)
            let legNode = SCNNode(geometry: legGeometry)
            legNode.position = SCNVector3(Float(i) * 0.6, -1.5, 0)
            legNode.name = "bones"
            bodyGroup.addChildNode(legNode)
        }
        
        // Add materials
        let defaultMaterial = SCNMaterial()
        defaultMaterial.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.7)
        
        bodyGroup.childNodes.forEach { node in
            node.geometry?.materials = [defaultMaterial]
        }
        
        scene.rootNode.addChildNode(bodyGroup)
        
        // Add camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 2, 8)
        scene.rootNode.addChildNode(cameraNode)
        
        return scene
    }
    
    class Coordinator: NSObject {
        var parent: Body3DView
        
        init(_ parent: Body3DView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let sceneView = gesture.view as! SCNView
            let location = gesture.location(in: sceneView)
            let hitResults = sceneView.hitTest(location, options: [:])
            
            if let hitResult = hitResults.first {
                if let nodeName = hitResult.node.name {
                    handleBodyPartSelection(nodeName)
                }
            }
        }
        
        func handleBodyPartSelection(_ partName: String) {
            // Map node names to body regions
            let regionMap: [String: String] = [
                "brain": "brain",
                "heart": "heart",
                "muscles": "muscles",
                "bones": "bones"
            ]
            
            if let anatomicalId = regionMap[partName] {
                // Find the corresponding region and toggle it
                if let region = parent.selectedRegions.first(where: { $0.anatomicalId == anatomicalId }) {
                    // Remove if already selected
                    parent.selectedRegions.removeAll { $0.anatomicalId == anatomicalId }
                } else {
                    // Add if not selected (create a basic region)
                    let newRegion = BodyRegion(
                        name: partName.capitalized,
                        anatomicalId: anatomicalId,
                        concernLevel: .medium,
                        relatedNutrients: getRelatedNutrients(for: anatomicalId)
                    )
                    parent.selectedRegions.append(newRegion)
                }
            }
        }
        
        func updateSelectedRegions(_ regions: [BodyRegion]) {
            // Update 3D model appearance based on selected regions
            // This would highlight selected body parts
        }
        
        private func getRelatedNutrients(for anatomicalId: String) -> [String] {
            switch anatomicalId {
            case "brain": return ["omega_3", "vitamin_d", "antioxidants"]
            case "heart": return ["omega_3", "potassium", "fiber"]
            case "muscles": return ["protein", "creatine", "leucine"]
            case "bones": return ["calcium", "vitamin_d", "magnesium"]
            default: return []
            }
        }
    }
}

// MARK: - Body Region Card

struct BodyRegionCard: View {
    let region: BodyRegion
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(region.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            
            Text("Focus: \(region.relatedNutrients.prefix(2).joined(separator: ", "))")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Symptom Chip

struct SymptomChip: View {
    let symptom: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(symptom.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.orange : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Nutrition Advice Sheet

struct NutritionAdviceSheet: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @Environment(\.dismiss) private var dismiss
    let advice: NutritionAdvice
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Personalized Nutrition Plan")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Based on your selected focus areas")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Recommended Nutrients
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Key Nutrients to Focus On")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(advice.recommendedNutrients.prefix(6), id: \.self) { nutrient in
                                NutrientBadge(nutrient: nutrient)
                            }
                        }
                    }
                    
                    // Suggested Recipes
                    if !advice.suggestedRecipes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommended Recipes")
                                .font(.headline)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(advice.suggestedRecipes.prefix(3), id: \.id) { recipe in
                                    RecipeRowView(recipe: recipe) {
                                        viewModel.selectRecipe(recipe)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Ingredients to Avoid
                    if !advice.avoidedIngredients.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Consider Avoiding")
                                .font(.headline)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(advice.avoidedIngredients, id: \.self) { ingredient in
                                    AvoidBadge(ingredient: ingredient)
                                }
                            }
                        }
                    }
                    
                    // Create Meal Plan Button
                    Button {
                        Task {
                            if let preferences = viewModel.userPreferences {
                                await viewModel.generateMealPlan(
                                    preferences: preferences,
                                    theme: "Health Focused"
                                )
                            }
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Create Health-Focused Meal Plan")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    // Disclaimer
                    VStack(spacing: 8) {
                        Text("⚠️ Medical Disclaimer")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text(advice.disclaimer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Nutrition Advice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct NutrientBadge: View {
    let nutrient: String
    
    var body: some View {
        Text(nutrient.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.2))
            .foregroundColor(.green)
            .clipShape(Capsule())
    }
}

struct AvoidBadge: View {
    let ingredient: String
    
    var body: some View {
        Text(ingredient.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.2))
            .foregroundColor(.red)
            .clipShape(Capsule())
    }
}

#Preview {
    BodyAssistantView()
        .environmentObject(MealPlanningViewModel())
}