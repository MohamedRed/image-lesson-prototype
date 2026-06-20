import SwiftUI
import MealPlanningService

struct RecipeDetailView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var selectedTab = 0
    @State private var showingCookingMode = false
    @State private var servingSize: Double = 1.0
    
    // no explicit ToolbarContent builder to avoid overload ambiguity

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Hero image and basic info
                RecipeHeroView(recipe: recipe, servingSize: $servingSize)
                
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Ingredients").tag(1)
                    Text("Steps").tag(2)
                    Text("Nutrition").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Tab content
                TabView(selection: $selectedTab) {
                    RecipeOverviewView(recipe: recipe)
                        .tag(0)
                    
                    IngredientsView(recipe: recipe, servingSize: servingSize)
                        .tag(1)
                    
                    StepsView(recipe: recipe)
                        .tag(2)
                    
                    NutritionView(recipe: recipe, servingSize: servingSize)
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Action buttons
                HStack(spacing: 16) {
                    Button {
                        Task {
                            await viewModel.saveRecipe(recipe)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "heart")
                            Text("Save")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        showingCookingMode = true
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Cooking")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Done") { dismiss() },
                trailing:
                    Menu {
                        Button("Share Recipe") { /* TODO */ }
                        Button("Add to Meal Plan") { /* TODO */ }
                        if let videoUrl = recipe.videoUrl {
                            Button("Watch Original Video") { /* TODO */ }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
            )
        }
        .fullScreenCover(isPresented: $showingCookingMode) {
            CookingModeView(recipe: recipe, servingSize: servingSize)
                .environmentObject(viewModel)
        }
    }
}

// MARK: - Recipe Hero

struct RecipeHeroView: View {
    let recipe: Recipe
    @Binding var servingSize: Double
    
    var body: some View {
        VStack(spacing: 0) {
            // Image
            AsyncImage(url: URL(string: recipe.images.first ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                            .font(.system(size: 48))
                    }
            }
            .frame(height: 200)
            .clipShape(Rectangle())
            
            // Recipe info overlay
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if let author = recipe.sourceAuthor {
                            Text("by \(author)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Serving size adjuster
                    VStack(spacing: 4) {
                        Text("Servings")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack(spacing: 8) {
                            Button {
                                if servingSize > 0.5 {
                                    servingSize -= 0.5
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            
                            Text("\(servingSize.clean)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(minWidth: 30)
                            
                            Button {
                                servingSize += 0.5
                            } label: {
                                Image(systemName: "plus")
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                
                // Quick stats
                HStack(spacing: 16) {
                    StatBadge(icon: "clock", value: "\(recipe.totalTimeMinutes) min", color: .white)
                    StatBadge(icon: "person.2", value: "\(recipe.servings)", color: .white)
                    
                    if let nutrition = recipe.nutrition {
                        StatBadge(icon: "flame", value: "\(Int(nutrition.calories * servingSize)) cal", color: .white)
                    }
                    
                    DifficultyBadge(level: recipe.difficultyLevel)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
        .font(.caption)
        .foregroundColor(color)
    }
}

// MARK: - Recipe Overview

struct RecipeOverviewView: View {
    let recipe: Recipe
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Description
                Text(recipe.description)
                    .font(.body)
                
                // Cuisines and tags
                if !recipe.cuisines.isEmpty || !recipe.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if !recipe.cuisines.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cuisine")
                                    .font(.headline)
                                
                                HStack {
                                    ForEach(recipe.cuisines, id: \.self) { cuisine in
                                        Text(cuisine)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor.opacity(0.2))
                                            .foregroundColor(.accentColor)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        
                        if !recipe.tags.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tags")
                                    .font(.headline)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], alignment: .leading, spacing: 6) {
                                    ForEach(recipe.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.systemGray5))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Utensils required
                if !recipe.utensils.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Equipment Needed")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], alignment: .leading, spacing: 8) {
                            ForEach(recipe.utensils) { utensil in
                                HStack {
                                    Image(systemName: utensilIcon(for: utensil.category))
                                        .foregroundColor(.secondary)
                                    
                                    Text(utensil.name)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                
                // Source info
                if recipe.sourceAuthor != nil || recipe.sourcePlatform != .manual {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Source")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: platformIcon(for: recipe.sourcePlatform))
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                if let author = recipe.sourceAuthor {
                                    Text(author)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                Text(recipe.sourcePlatform.rawValue.capitalized)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                if let attribution = recipe.sourceAttribution {
                                    Text(attribution)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func utensilIcon(for category: UtensilCategory) -> String {
        switch category {
        case .cookware: return "pot"
        case .bakeware: return "oven"
        case .knives: return "scissors"
        case .smallAppliances: return "appliance"
        case .handTools: return "wrench.and.screwdriver"
        case .measuring: return "ruler"
        }
    }
    
    private func platformIcon(for platform: SourcePlatform) -> String {
        switch platform {
        case .instagram: return "camera"
        case .tiktok: return "music.note"
        case .youtube: return "play.rectangle"
        case .web: return "globe"
        case .manual: return "doc.text"
        }
    }
}

// MARK: - Ingredients View

struct IngredientsView: View {
    let recipe: Recipe
    let servingSize: Double
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(recipe.ingredients) { ingredient in
                    IngredientRowView(ingredient: ingredient, servingSize: servingSize)
                }
            }
            .padding()
        }
    }
}

struct IngredientRowView: View {
    let ingredient: Ingredient
    let servingSize: Double
    @State private var isChecked = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                isChecked.toggle()
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .green : .secondary)
                    .font(.title3)
            }
            
            // Ingredient info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if let quantity = ingredient.quantity, let unit = ingredient.unit {
                        Text("\(adjustedQuantity) \(unit)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    }
                    
                    Text(ingredient.name)
                        .font(.subheadline)
                        .strikethrough(isChecked)
                        .foregroundColor(isChecked ? .secondary : .primary)
                    
                    if ingredient.isOptional {
                        Text("(optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let notes = ingredient.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !ingredient.substitutions.isEmpty {
                    Text("Substitutes: \(ingredient.substitutions.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.2), value: isChecked)
    }
    
    private var adjustedQuantity: String {
        guard let quantity = ingredient.quantity else { return "" }
        let adjusted = quantity * servingSize
        return adjusted.clean
    }
}

// MARK: - Steps View

struct StepsView: View {
    let recipe: Recipe
    @State private var completedSteps: Set<String> = []
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(recipe.steps) { step in
                    StepRowView(
                        step: step,
                        isCompleted: completedSteps.contains(step.id)
                    ) {
                        if completedSteps.contains(step.id) {
                            completedSteps.remove(step.id)
                        } else {
                            completedSteps.insert(step.id)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct StepRowView: View {
    let step: RecipeStep
    let isCompleted: Bool
    let toggleAction: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number and checkbox
            VStack(spacing: 8) {
                Text("\(step.stepNumber)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(isCompleted ? Color.green : Color.accentColor)
                    .clipShape(Circle())
                
                Button {
                    toggleAction()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? .green : .secondary)
                        .font(.title3)
                }
            }
            
            // Step content
            VStack(alignment: .leading, spacing: 8) {
                Text(step.instruction)
                    .font(.body)
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                
                // Step metadata
                HStack(spacing: 16) {
                    if let timer = step.timerSeconds {
                        Label("\(timer / 60):\(String(format: "%02d", timer % 60))", systemImage: "timer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let temp = step.temperature {
                        Label("\(Int(temp.value))\(temp.unit.rawValue)", systemImage: "thermometer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !step.utensilRefs.isEmpty {
                        Label("\(step.utensilRefs.count) tools", systemImage: "wrench.and.screwdriver")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let notes = step.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .italic()
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
    }
}

// MARK: - Nutrition View

struct NutritionView: View {
    let recipe: Recipe
    let servingSize: Double
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let nutrition = recipe.nutrition {
                    // Calories
                    NutritionCard(
                        title: "Calories",
                        value: Int(nutrition.calories * servingSize),
                        unit: "kcal",
                        color: .red
                    )
                    
                    // Macronutrients
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Macronutrients")
                            .font(.headline)
                        
                        MacronutrientView(
                            macros: nutrition.macros,
                            servingSize: servingSize
                        )
                    }
                    
                    // Micronutrients
                    if !nutrition.micronutrients.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Micronutrients")
                                .font(.headline)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(Array(nutrition.micronutrients.keys.sorted()), id: \.self) { nutrient in
                                    if let value = nutrition.micronutrients[nutrient] {
                                        MicronutrientRow(
                                            name: nutrient.replacingOccurrences(of: "_", with: " ").capitalized,
                                            value: value * servingSize,
                                            unit: "mg" // Simplified unit
                                        )
                                    }
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Nutrition information not available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("This recipe doesn't have detailed nutrition data yet.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
        }
    }
}

struct NutritionCard: View {
    let title: String
    let value: Int
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(value)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MacronutrientView: View {
    let macros: Macronutrients
    let servingSize: Double
    
    var body: some View {
        HStack(spacing: 16) {
            MacroBar(
                name: "Protein",
                value: macros.protein * servingSize,
                unit: "g",
                color: .blue
            )
            
            MacroBar(
                name: "Carbs",
                value: macros.carbs * servingSize,
                unit: "g",
                color: .green
            )
            
            MacroBar(
                name: "Fat",
                value: macros.fat * servingSize,
                unit: "g",
                color: .orange
            )
            
            if macros.fiber > 0 {
                MacroBar(
                    name: "Fiber",
                    value: macros.fiber * servingSize,
                    unit: "g",
                    color: .brown
                )
            }
        }
    }
}

struct MacroBar: View {
    let name: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(value.clean)\(unit)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MicronutrientRow: View {
    let name: String
    let value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(name)
                .font(.caption)
            
            Spacer()
            
            Text("\(value.clean) \(unit)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Cooking Mode View

struct CookingModeView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    let servingSize: Double
    
    @State private var currentStep = 0
    @State private var timerSeconds = 0
    @State private var isTimerRunning = false
    @State private var timer: Timer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentStep), total: Double(recipe.steps.count))
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                    .padding()
                
                // Current step
                if currentStep < recipe.steps.count {
                    let step = recipe.steps[currentStep]
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Step number
                            Text("Step \(step.stepNumber) of \(recipe.steps.count)")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                            
                            // Instruction
                            Text(step.instruction)
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            // Timer if available
                            if let stepTimer = step.timerSeconds {
                                TimerView(
                                    totalSeconds: stepTimer,
                                    currentSeconds: timerSeconds,
                                    isRunning: isTimerRunning
                                ) {
                                    startTimer(stepTimer)
                                } onStop: {
                                    stopTimer()
                                } onReset: {
                                    resetTimer()
                                }
                            }
                            
                            // Temperature
                            if let temp = step.temperature {
                                HStack {
                                    Image(systemName: "thermometer")
                                        .foregroundColor(.orange)
                                    Text("Heat to \(Int(temp.value))\(temp.unit.rawValue)")
                                        .font(.headline)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // Notes
                            if let notes = step.notes {
                                Text("💡 \(notes)")
                                    .font(.body)
                                    .foregroundColor(.blue)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                } else {
                    // Completion view
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        
                        Text("Recipe Complete!")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Enjoy your \(recipe.title)!")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Navigation controls
                HStack(spacing: 16) {
                    Button("Previous") {
                        if currentStep > 0 {
                            currentStep -= 1
                            resetTimer()
                        }
                    }
                    .disabled(currentStep == 0)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    
                    if currentStep < recipe.steps.count {
                        Button("Next Step") {
                            currentStep += 1
                            resetTimer()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Finish") {
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer(_ seconds: Int) {
        timerSeconds = seconds
        isTimerRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timerSeconds > 0 {
                timerSeconds -= 1
            } else {
                stopTimer()
                // TODO: Play sound or send notification
            }
        }
    }
    
    private func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func resetTimer() {
        stopTimer()
        timerSeconds = 0
    }
}

// MARK: - Timer View

struct TimerView: View {
    let totalSeconds: Int
    let currentSeconds: Int
    let isRunning: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Timer display
            VStack(spacing: 8) {
                Text(timeString(from: currentSeconds))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(currentSeconds == 0 ? .red : .primary)
                
                ProgressView(value: Double(totalSeconds - currentSeconds), total: Double(totalSeconds))
                    .progressViewStyle(LinearProgressViewStyle(tint: currentSeconds == 0 ? .red : .accentColor))
            }
            
            // Timer controls
            HStack(spacing: 16) {
                Button(isRunning ? "Stop" : "Start") {
                    if isRunning {
                        onStop()
                    } else {
                        onStart()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Reset") {
                    onReset()
                }
                .buttonStyle(.bordered)
                .disabled(isRunning)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}