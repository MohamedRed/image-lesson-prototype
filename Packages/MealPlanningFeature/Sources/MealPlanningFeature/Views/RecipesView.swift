import SwiftUI
import MealPlanningService

struct RecipesView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @State private var selectedSortOrder = SortOrder.recent
    @State private var selectedCategory = "All"
    @State private var showingFilterSheet = false
    
    private let categories = ["All", "Breakfast", "Lunch", "Dinner", "Snacks", "Desserts"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            FilterChip(
                                title: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Recipes List
                if filteredRecipes.isEmpty {
                    EmptyRecipesView()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredRecipes) { recipe in
                            RecipeCardView(recipe: recipe) {
                                viewModel.selectRecipe(recipe)
                            } onSave: {
                                Task {
                                    await viewModel.saveRecipe(recipe)
                                }
                            } onRemove: {
                                Task {
                                    await viewModel.removeRecipe(recipe)
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("My Recipes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $selectedSortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.title).tag(order)
                            }
                        }
                        
                        Button("Filter") {
                            showingFilterSheet = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            RecipeFilterSheet(selectedCategory: $selectedCategory, selectedSortOrder: $selectedSortOrder)
        }
        .sheet(isPresented: $viewModel.showRecipeDetail) {
            if let recipe = viewModel.selectedRecipe {
                RecipeDetailView(recipe: recipe)
                    .environmentObject(viewModel)
            }
        }
        .refreshable {
            await viewModel.loadMyRecipes()
        }
    }
    
    private var filteredRecipes: [Recipe] {
        let filtered = selectedCategory == "All" ? 
            viewModel.myRecipes : 
            viewModel.myRecipes.filter { recipe in
                // Simple category filtering based on tags or meal timing
                switch selectedCategory {
                case "Breakfast":
                    return recipe.tags.contains("breakfast") || recipe.totalTimeMinutes <= 15
                case "Lunch", "Dinner":
                    return recipe.tags.contains(selectedCategory.lowercased())
                case "Snacks":
                    return recipe.tags.contains("snack") || recipe.tags.contains("quick")
                case "Desserts":
                    return recipe.tags.contains("dessert") || recipe.tags.contains("sweet")
                default:
                    return true
                }
            }
        
        return filtered.sorted { recipe1, recipe2 in
            switch selectedSortOrder {
            case .recent:
                return recipe1.createdAt > recipe2.createdAt
            case .alphabetical:
                return recipe1.title < recipe2.title
            case .cookTime:
                return recipe1.totalTimeMinutes < recipe2.totalTimeMinutes
            case .difficulty:
                let order: [DifficultyLevel] = [.beginner, .intermediate, .advanced]
                return order.firstIndex(of: recipe1.difficultyLevel) ?? 0 < 
                       order.firstIndex(of: recipe2.difficultyLevel) ?? 0
            }
        }
    }
}

// MARK: - Sort Order

enum SortOrder: CaseIterable {
    case recent
    case alphabetical
    case cookTime
    case difficulty
    
    var title: String {
        switch self {
        case .recent: return "Recent"
        case .alphabetical: return "Alphabetical"
        case .cookTime: return "Cook Time"
        case .difficulty: return "Difficulty"
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Recipe Card View

struct RecipeCardView: View {
    let recipe: Recipe
    let action: () -> Void
    let onSave: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with image and basic info
            HStack(spacing: 12) {
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
                        }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let author = recipe.sourceAuthor {
                        Text("by \(author)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        DifficultyBadge(level: recipe.difficultyLevel)
                        
                        if !recipe.cuisines.isEmpty {
                            Text(recipe.cuisines.first ?? "")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    Button("View Details") {
                        action()
                    }
                    
                    Button("Save Copy") {
                        onSave()
                    }
                    
                    Divider()
                    
                    Button("Remove", role: .destructive) {
                        onRemove()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
            
            // Recipe stats
            HStack(spacing: 16) {
                StatView(icon: "clock", value: "\(recipe.totalTimeMinutes) min")
                
                if recipe.prepTimeMinutes > 0 {
                    StatView(icon: "timer", value: "\(recipe.prepTimeMinutes) min prep")
                }
                
                if let nutrition = recipe.nutrition {
                    StatView(icon: "flame", value: "\(Int(nutrition.calories)) cal")
                }
                
                StatView(icon: "person.2", value: "\(recipe.servings)")
                
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Tags
            if !recipe.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recipe.tags.prefix(5), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray6))
                                .cornerRadius(3)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let level: DifficultyLevel
    
    var body: some View {
        Text(level.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        switch level {
        case .beginner: return Color.green.opacity(0.2)
        case .intermediate: return Color.orange.opacity(0.2)
        case .advanced: return Color.red.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch level {
        case .beginner: return Color.green
        case .intermediate: return Color.orange
        case .advanced: return Color.red
        }
    }
}

// MARK: - Stat View

struct StatView: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
    }
}

// MARK: - Empty State

struct EmptyRecipesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Recipes Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Import recipes from social media or web to get started cooking!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Filter Sheet

struct RecipeFilterSheet: View {
    @Binding var selectedCategory: String
    @Binding var selectedSortOrder: SortOrder
    @Environment(\.dismiss) private var dismiss
    
    private let categories = ["All", "Breakfast", "Lunch", "Dinner", "Snacks", "Desserts"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category") {
                    ForEach(categories, id: \.self) { category in
                        HStack {
                            Text(category)
                            Spacer()
                            if selectedCategory == category {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCategory = category
                        }
                    }
                }
                
                Section("Sort Order") {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        HStack {
                            Text(order.title)
                            Spacer()
                            if selectedSortOrder == order {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSortOrder = order
                        }
                    }
                }
            }
            .navigationTitle("Filter & Sort")
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