import SwiftUI
import MealPlanningService

struct MealPlannerView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @State private var showingNewPlanSheet = false
    @State private var selectedDay = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let currentPlan = viewModel.currentMealPlan {
                    // Week Navigator
                    WeekNavigatorView(
                        weekStartDate: currentPlan.weekStartDate,
                        selectedDay: $selectedDay
                    )
                    .padding()
                    
                    // Meal Plan Grid
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(currentPlan.days.enumerated()), id: \.1.id) { dayIndex, dayPlan in
                                DayPlanView(
                                    dayPlan: dayPlan,
                                    dayIndex: dayIndex,
                                    isSelected: selectedDay == dayIndex
                                )
                                .environmentObject(viewModel)
                                .onTapGesture {
                                    selectedDay = dayIndex
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Plan Generation Progress
                    if viewModel.isGeneratingPlan, let progress = viewModel.planGenerationProgress {
                        PlanGenerationProgressView(progress: progress)
                            .padding()
                    }
                    
                } else {
                    EmptyPlanView {
                        showingNewPlanSheet = true
                    }
                }
            }
            .navigationTitle("Meal Planner")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if viewModel.currentMealPlan != nil {
                        Menu {
                            Button("New Plan") {
                                showingNewPlanSheet = true
                            }
                            
                            Button("Share Plan") {
                                // TODO: Implement sharing
                            }
                            
                            Button("Sync to Health") {
                                Task {
                                    await viewModel.syncNutritionToHealth()
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    
                    Button {
                        showingNewPlanSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewPlanSheet) {
            NewPlanSheet()
                .environmentObject(viewModel)
        }
    }
}

// MARK: - Week Navigator

struct WeekNavigatorView: View {
    let weekStartDate: Date
    @Binding var selectedDay: Int
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private var weekDays: [Date] {
        (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Week header
            HStack {
                Text(weekStartDate, style: .date)
                    .font(.headline)
                
                Spacer()
                
                Text("Week \(calendar.component(.weekOfYear, from: weekStartDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Day selector
            HStack(spacing: 0) {
                ForEach(Array(weekDays.enumerated()), id: \.1) { dayIndex, date in
                    VStack(spacing: 4) {
                        Text(dayName(for: date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(calendar.component(.day, from: date))")
                            .font(.headline)
                            .foregroundColor(selectedDay == dayIndex ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedDay == dayIndex ? Color.accentColor : Color.clear)
                    )
                    .onTapGesture {
                        selectedDay = dayIndex
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Day Plan View

struct DayPlanView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    let dayPlan: DayPlan
    let dayIndex: Int
    let isSelected: Bool
    @State private var showingMealOptions = false
    @State private var selectedMealSlot: MealSlot?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack {
                Text(dayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                
                Spacer()
                
                if let nutrition = dayPlan.dailyNutrition {
                    NutritionSummaryView(nutrition: nutrition)
                }
            }
            
            // Meals
            VStack(spacing: 8) {
                ForEach(dayPlan.meals) { meal in
                    MealSlotView(
                        meal: meal,
                        dayIndex: dayIndex
                    ) {
                        selectedMealSlot = meal
                        Task {
                            await viewModel.getMealRecommendations(for: dayIndex, slot: meal.type)
                        }
                        showingMealOptions = true
                    }
                    .environmentObject(viewModel)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: isSelected ? 4 : 2, x: 0, y: 2)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .sheet(isPresented: $showingMealOptions) {
            if let mealSlot = selectedMealSlot {
                MealOptionsSheet(
                    dayIndex: dayIndex,
                    mealSlot: mealSlot
                )
                .environmentObject(viewModel)
            }
        }
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: dayPlan.date)
    }
}

// MARK: - Nutrition Summary

struct NutritionSummaryView: View {
    let nutrition: NutrientProfile
    
    var body: some View {
        HStack(spacing: 6) {
            Text("\(Int(nutrition.calories))")
                .font(.caption2)
                .fontWeight(.medium)
            Text("cal")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.systemGray6))
        .cornerRadius(4)
    }
}

// MARK: - Meal Slot View

struct MealSlotView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    let meal: MealSlot
    let dayIndex: Int
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Meal type icon
            MealTypeIcon(type: meal.type)
            
            if let recipe = meal.recipe {
                // Recipe info
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let plannedTime = meal.plannedTime {
                            Label(plannedTime, systemImage: "clock")
                        }
                        
                        Label("\(recipe.totalTimeMinutes) min", systemImage: "timer")
                        
                        if let nutrition = recipe.nutrition {
                            Label("\(Int(nutrition.calories * meal.servingSize)) cal", systemImage: "flame")
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Recipe image
                AsyncImage(url: URL(string: recipe.images.first ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
            } else {
                // Empty slot
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add \(meal.type.rawValue.capitalized)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let plannedTime = meal.plannedTime {
                        Text(plannedTime)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "plus.circle.dashed")
                    .foregroundColor(.accentColor)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Meal Type Icon

struct MealTypeIcon: View {
    let type: MealSlotType
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
            .font(.title3)
            .frame(width: 24, height: 24)
    }
    
    private var iconName: String {
        switch type {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "leaf"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .purple
        case .snack: return .green
        }
    }
}

// MARK: - Plan Generation Progress

struct PlanGenerationProgressView: View {
    let progress: PlanGenerationProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Generating Meal Plan")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(progress.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
            
            Text(progress.message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Empty Plan View

struct EmptyPlanView: View {
    let createAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Meal Plan Yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Create your first meal plan to start cooking delicious meals!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button {
                createAction()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Create Meal Plan")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - New Plan Sheet

struct NewPlanSheet: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTheme = "Balanced"
    @State private var preferences = MealPlanPreferences()
    
    private let themes = ["Balanced", "Mediterranean", "Vegetarian", "High Protein", "Quick & Easy", "Comfort Food"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Theme") {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Dietary Preferences") {
                    MultiSelectionView(
                        title: "Dietary Restrictions",
                        options: DietaryRestriction.allCases.map { $0.rawValue.capitalized },
                        selections: Binding(
                            get: { preferences.dietary.map { $0.rawValue } },
                            set: { selections in
                                let newDietary = selections.compactMap { DietaryRestriction(rawValue: $0.lowercased()) }
                                preferences = MealPlanPreferences(
                                    dietary: newDietary,
                                    allergies: preferences.allergies,
                                    macroTargets: preferences.macroTargets,
                                    timeBudgetMinutes: preferences.timeBudgetMinutes,
                                    costBudgetRange: preferences.costBudgetRange,
                                    cuisines: preferences.cuisines,
                                    utensilsMinimize: preferences.utensilsMinimize,
                                    weekendComplexityHigh: preferences.weekendComplexityHigh,
                                    leftoversPolicy: preferences.leftoversPolicy,
                                    dislikedIngredients: preferences.dislikedIngredients,
                                    preferredMealTimes: preferences.preferredMealTimes
                                )
                            }
                        )
                    )
                }
                
                Section("Time & Budget") {
                    HStack {
                        Text("Time Budget")
                        Spacer()
                        Text("\(preferences.timeBudgetMinutes) minutes")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(preferences.timeBudgetMinutes) },
                            set: { newValue in
                                preferences = MealPlanPreferences(
                                    dietary: preferences.dietary,
                                    allergies: preferences.allergies,
                                    macroTargets: preferences.macroTargets,
                                    timeBudgetMinutes: Int(newValue),
                                    costBudgetRange: preferences.costBudgetRange,
                                    cuisines: preferences.cuisines,
                                    utensilsMinimize: preferences.utensilsMinimize,
                                    weekendComplexityHigh: preferences.weekendComplexityHigh,
                                    leftoversPolicy: preferences.leftoversPolicy,
                                    dislikedIngredients: preferences.dislikedIngredients,
                                    preferredMealTimes: preferences.preferredMealTimes
                                )
                            }
                        ),
                        in: 15...120,
                        step: 15
                    )
                }
                
                Section("Preferences") {
                    Toggle(
                        "Minimize Utensils",
                        isOn: Binding(
                            get: { preferences.utensilsMinimize },
                            set: { newValue in
                                preferences = MealPlanPreferences(
                                    dietary: preferences.dietary,
                                    allergies: preferences.allergies,
                                    macroTargets: preferences.macroTargets,
                                    timeBudgetMinutes: preferences.timeBudgetMinutes,
                                    costBudgetRange: preferences.costBudgetRange,
                                    cuisines: preferences.cuisines,
                                    utensilsMinimize: newValue,
                                    weekendComplexityHigh: preferences.weekendComplexityHigh,
                                    leftoversPolicy: preferences.leftoversPolicy,
                                    dislikedIngredients: preferences.dislikedIngredients,
                                    preferredMealTimes: preferences.preferredMealTimes
                                )
                            }
                        )
                    )
                    Toggle(
                        "Complex Weekend Meals",
                        isOn: Binding(
                            get: { preferences.weekendComplexityHigh },
                            set: { newValue in
                                preferences = MealPlanPreferences(
                                    dietary: preferences.dietary,
                                    allergies: preferences.allergies,
                                    macroTargets: preferences.macroTargets,
                                    timeBudgetMinutes: preferences.timeBudgetMinutes,
                                    costBudgetRange: preferences.costBudgetRange,
                                    cuisines: preferences.cuisines,
                                    utensilsMinimize: preferences.utensilsMinimize,
                                    weekendComplexityHigh: newValue,
                                    leftoversPolicy: preferences.leftoversPolicy,
                                    dislikedIngredients: preferences.dislikedIngredients,
                                    preferredMealTimes: preferences.preferredMealTimes
                                )
                            }
                        )
                    )
                    
                    Picker(
                        "Leftovers Policy",
                        selection: Binding(
                            get: { preferences.leftoversPolicy },
                            set: { newValue in
                                preferences = MealPlanPreferences(
                                    dietary: preferences.dietary,
                                    allergies: preferences.allergies,
                                    macroTargets: preferences.macroTargets,
                                    timeBudgetMinutes: preferences.timeBudgetMinutes,
                                    costBudgetRange: preferences.costBudgetRange,
                                    cuisines: preferences.cuisines,
                                    utensilsMinimize: preferences.utensilsMinimize,
                                    weekendComplexityHigh: preferences.weekendComplexityHigh,
                                    leftoversPolicy: newValue,
                                    dislikedIngredients: preferences.dislikedIngredients,
                                    preferredMealTimes: preferences.preferredMealTimes
                                )
                            }
                        )
                    ) {
                        ForEach(LeftoversPolicy.allCases, id: \.self) { policy in
                            Text(policy.rawValue.capitalized).tag(policy)
                        }
                    }
                }
            }
            .navigationTitle("New Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await viewModel.generateMealPlan(
                                preferences: preferences,
                                theme: selectedTheme
                            )
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isGeneratingPlan)
                }
            }
        }
        .task {
            if let userPrefs = viewModel.userPreferences {
                preferences = userPrefs
            }
        }
    }
}

// MARK: - Multi Selection View

struct MultiSelectionView: View {
    let title: String
    let options: [String]
    @Binding var selections: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(options, id: \.self) { option in
                    SelectionChip(
                        title: option,
                        isSelected: selections.contains(option)
                    ) {
                        if selections.contains(option) {
                            selections.removeAll { $0 == option }
                        } else {
                            selections.append(option)
                        }
                    }
                }
            }
        }
    }
}

struct SelectionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Meal Options Sheet

struct MealOptionsSheet: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @Environment(\.dismiss) private var dismiss
    let dayIndex: Int
    let mealSlot: MealSlot
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current meal (if any)
                if let recipe = mealSlot.recipe {
                    CurrentMealView(recipe: recipe, mealSlot: mealSlot)
                        .padding()
                }
                
                // Suggestions
                if !viewModel.recipeSuggestions.isEmpty {
                    Text("Suggestions")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.recipeSuggestions) { recipe in
                            RecipeRowView(recipe: recipe) {
                                Task {
                                    await viewModel.replaceMeal(day: dayIndex, slot: mealSlot.type, with: recipe)
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("\(mealSlot.type.rawValue.capitalized) Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct CurrentMealView: View {
    let recipe: Recipe
    let mealSlot: MealSlot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Meal")
                .font(.headline)
            
            RecipeRowView(recipe: recipe) {}
        }
    }
}