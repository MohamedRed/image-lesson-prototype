import SwiftUI
import MealPlanningService

struct AIAssistantView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @State private var messageText = ""
    @State private var showingHealthProfile = false
    @State private var showingBodyRegions = false
    @FocusState private var isMessageFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Welcome message if no messages
                            if viewModel.aiMessages.isEmpty {
                                WelcomeMessageView()
                                    .padding()
                            }
                            
                            ForEach(viewModel.aiMessages) { message in
                                MessageBubbleView(message: message)
                                    .environmentObject(viewModel)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.aiMessages.count) { _ in
                        if let lastMessage = viewModel.aiMessages.last {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input area
                VStack(spacing: 12) {
                    // Quick actions
                    if viewModel.aiMessages.isEmpty {
                        QuickActionsView()
                            .environmentObject(viewModel)
                    }
                    
                    // Message input
                    HStack(spacing: 12) {
                        TextField("Ask about recipes, meal plans, nutrition...", text: $messageText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .focused($isMessageFieldFocused)
                            .lineLimit(1...4)
                        
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(messageText.isEmpty ? Color.gray : Color.accentColor)
                                .clipShape(Circle())
                        }
                        .disabled(messageText.isEmpty)
                    }
                }
                .padding()
            }
            .navigationTitle("AI Assistant")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingHealthProfile = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    
                    Button {
                        showingBodyRegions = true
                    } label: {
                        Image(systemName: "figure.arms.open")
                    }
                }
            }
        }
        .sheet(isPresented: $showingHealthProfile) {
            HealthProfileSheet()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingBodyRegions) {
            BodyRegionsSheet()
                .environmentObject(viewModel)
        }
    }
    
    private func sendMessage() {
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        messageText = ""
        isMessageFieldFocused = false
        
        Task {
            await viewModel.sendAIMessage(message)
        }
    }
}

// MARK: - Welcome Message

struct WelcomeMessageView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("AI Meal Assistant")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("I can help you with meal planning, recipe suggestions, nutrition advice, and more!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Quick Actions

struct QuickActionsView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    
    private let quickActions = [
        "Suggest healthy breakfast recipes",
        "Create a Mediterranean meal plan",
        "What's good for heart health?",
        "Quick 20-minute dinner ideas"
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickActions, id: \.self) { action in
                    Button {
                        Task {
                            await viewModel.sendAIMessage(action)
                        }
                    } label: {
                        Text(action)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    let message: AIMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Message content
                Text(message.content)
                    .padding()
                    .background(message.isUser ? Color.accentColor : Color(.systemGray5))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .clipShape(MessageBubbleShape(isUser: message.isUser))
                
                // Suggested actions
                if !message.isUser && !message.suggestedActions.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(message.suggestedActions, id: \.title) { action in
                            Button {
                                Task {
                                    await viewModel.executeAIAction(action)
                                }
                            } label: {
                                HStack {
                                    Text(action.title)
                                        .font(.caption)
                                    
                                    if let description = action.description {
                                        Text("• \(description)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                
                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer(minLength: 50)
            }
        }
    }
}

// MARK: - Message Bubble Shape

struct MessageBubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isUser ?
                [.topLeft, .topRight, .bottomLeft] :
                [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 16, height: 16)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Health Profile Sheet

struct HealthProfileSheet: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var healthProfile: HealthProfile?
    @State private var selectedGoals: [HealthGoal] = []
    @State private var trackedNutrients: [String] = []
    @State private var symptoms: [String] = []
    
    private let availableGoals = [
        HealthGoal(type: .weightLoss, target: 0.5, unit: "kg/week"),
        HealthGoal(type: .weightGain, target: 0.3, unit: "kg/week"),
        HealthGoal(type: .muscleGain, target: 1, unit: "goal"),
        HealthGoal(type: .energyBoost, target: 1, unit: "goal"),
        HealthGoal(type: .immuneSupport, target: 1, unit: "goal"),
        HealthGoal(type: .heartHealth, target: 1, unit: "goal"),
        HealthGoal(type: .brainHealth, target: 1, unit: "goal"),
        HealthGoal(type: .digestiveHealth, target: 1, unit: "goal")
    ]
    
    private let availableNutrients = [
        "protein", "fiber", "omega_3", "vitamin_d", "vitamin_c",
        "calcium", "iron", "magnesium", "potassium", "zinc"
    ]
    
    private let commonSymptoms = [
        "fatigue", "digestive_issues", "joint_pain", "poor_sleep",
        "stress", "low_energy", "headaches", "skin_issues"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Health Goals") {
                    ForEach(availableGoals, id: \.type) { goal in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(goal.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.subheadline)
                                
                                if goal.type != .customNutrient {
                                    Text("Target: \(goal.target.clean) \(goal.unit)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedGoals.contains(where: { $0.type == goal.type }) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleGoal(goal)
                        }
                    }
                }
                
                Section("Track Nutrients") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(availableNutrients, id: \.self) { nutrient in
                            Button {
                                toggleNutrient(nutrient)
                            } label: {
                                Text(nutrient.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(trackedNutrients.contains(nutrient) ? Color.accentColor : Color(.systemGray5))
                                    .foregroundColor(trackedNutrients.contains(nutrient) ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                Section("Current Symptoms") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(commonSymptoms, id: \.self) { symptom in
                            Button {
                                toggleSymptom(symptom)
                            } label: {
                                Text(symptom.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(symptoms.contains(symptom) ? Color.orange : Color(.systemGray5))
                                    .foregroundColor(symptoms.contains(symptom) ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                Section {
                    Text("This information helps provide personalized nutrition advice. All data is private and not used for medical diagnosis.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Health Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                }
            }
        }
        .task {
            loadCurrentProfile()
        }
    }
    
    private func loadCurrentProfile() {
        if let current = viewModel.healthProfile {
            healthProfile = current
            selectedGoals = current.goals
            trackedNutrients = current.trackedNutrients
            symptoms = current.symptoms
        } else {
            healthProfile = HealthProfile(userId: viewModel.currentUserId ?? "")
        }
    }
    
    private func toggleGoal(_ goal: HealthGoal) {
        if selectedGoals.contains(where: { $0.type == goal.type }) {
            selectedGoals.removeAll { $0.type == goal.type }
        } else {
            selectedGoals.append(goal)
        }
    }
    
    private func toggleNutrient(_ nutrient: String) {
        if trackedNutrients.contains(nutrient) {
            trackedNutrients.removeAll { $0 == nutrient }
        } else {
            trackedNutrients.append(nutrient)
        }
    }
    
    private func toggleSymptom(_ symptom: String) {
        if symptoms.contains(symptom) {
            symptoms.removeAll { $0 == symptom }
        } else {
            symptoms.append(symptom)
        }
    }
    
    private func saveProfile() {
        let updatedProfile = HealthProfile(
            userId: healthProfile?.userId ?? viewModel.currentUserId ?? "",
            trackedNutrients: trackedNutrients,
            goals: selectedGoals,
            bodyRegionConcerns: healthProfile?.bodyRegionConcerns ?? [],
            symptoms: symptoms,
            flaggedConditions: healthProfile?.flaggedConditions ?? [],
            medicalDisclaimer: true
        )
        
        Task {
            await viewModel.updateHealthProfile(updatedProfile)
        }
    }
}

// MARK: - Body Regions Sheet

struct BodyRegionsSheet: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRegions: [BodyRegion] = []
    @State private var selectedSymptoms: [String] = []
    
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select body areas you'd like to focus on for nutritional support")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // 3D Body visualization placeholder
                BodyVisualizationView(selectedRegions: $selectedRegions)
                
                // Region list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(bodyRegions, id: \.anatomicalId) { region in
                            BodyRegionRow(
                                region: region,
                                isSelected: selectedRegions.contains { $0.anatomicalId == region.anatomicalId }
                            ) {
                                toggleRegion(region)
                            }
                        }
                    }
                    .padding()
                }
                
                Button {
                    getAdviceForSelectedRegions()
                } label: {
                    Text("Get Nutrition Advice")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedRegions.isEmpty)
                .padding()
            }
            .navigationTitle("Body Focus Areas")
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
    
    private func toggleRegion(_ region: BodyRegion) {
        if selectedRegions.contains(where: { $0.anatomicalId == region.anatomicalId }) {
            selectedRegions.removeAll { $0.anatomicalId == region.anatomicalId }
        } else {
            selectedRegions.append(region)
        }
    }
    
    private func getAdviceForSelectedRegions() {
        Task {
            await viewModel.getNutritionAdvice(bodyRegions: selectedRegions, symptoms: [])
            dismiss()
        }
    }
}

// MARK: - Body Visualization (Placeholder)

struct BodyVisualizationView: View {
    @Binding var selectedRegions: [BodyRegion]
    
    var body: some View {
        VStack {
            // This would be replaced with a proper 3D body visualization
            // For now, showing a simple representation
            Image(systemName: "figure.arms.open")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .padding()
            
            Text("3D Body Visualization")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Tap regions below to select areas of focus")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding()
    }
}

// MARK: - Body Region Row

struct BodyRegionRow: View {
    let region: BodyRegion
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title3)
            
            // Region info
            VStack(alignment: .leading, spacing: 4) {
                Text(region.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Focus: \(region.relatedNutrients.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(8)
        .onTapGesture {
            action()
        }
    }
}