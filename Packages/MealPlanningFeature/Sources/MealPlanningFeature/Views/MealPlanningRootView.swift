import SwiftUI
import MealPlanningService

public struct MealPlanningRootView: View {
    @StateObject private var viewModel = MealPlanningViewModel()
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Discover & Import Tab
            DiscoverView()
                .environmentObject(viewModel)
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }
                .tag(0)
                .accessibilityLabel("Discover recipes")
                .accessibilityHint("Find and import new recipes from various sources")
            
            // My Recipes Tab
            RecipesView()
                .environmentObject(viewModel)
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }
                .tag(1)
                .accessibilityLabel("My recipes")
                .accessibilityHint("View and manage your saved recipes")
            
            // Meal Planner Tab
            MealPlannerView()
                .environmentObject(viewModel)
                .tabItem {
                    Label("Planner", systemImage: "calendar")
                }
                .tag(2)
                .accessibilityLabel("Meal planner")
                .accessibilityHint("Plan your weekly meals and generate meal plans")
            
            // Shopping List Tab
            ShoppingListView()
                .environmentObject(viewModel)
                .tabItem {
                    Label("Shopping", systemImage: "cart")
                }
                .tag(3)
                .accessibilityLabel("Shopping list")
                .accessibilityHint("View your shopping list and compare prices")
            
            // AI Assistant Tab
            AIAssistantView()
                .environmentObject(viewModel)
                .tabItem {
                    Label("Assistant", systemImage: "brain")
                }
                .tag(4)
                .accessibilityLabel("AI assistant")
                .accessibilityHint("Chat with AI for meal recommendations and nutrition advice")
        }
        .accessibilityElement(children: .contain)
        .highContrastSupport()
        .task {
            await viewModel.loadInitialData()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

// MARK: - Discover View

struct DiscoverView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @State private var importURL = ""
    @State private var showingImportSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Import Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Import Recipe")
                        .font(.headline)
                    
                    Text("Paste a URL from Instagram, TikTok, YouTube, or any recipe website")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Recipe URL...", text: $importURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Import") {
                            Task {
                                await viewModel.importRecipe(from: importURL)
                                importURL = ""
                            }
                        }
                        .disabled(importURL.isEmpty || viewModel.isImporting)
                    }
                    
                    if viewModel.isImporting, let progress = viewModel.importProgress {
                        ImportProgressView(progress: progress)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Search Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search Recipes")
                        .font(.headline)
                    
                    SearchBar(text: $viewModel.searchQuery) {
                        Task {
                            await viewModel.searchRecipes(viewModel.searchQuery)
                        }
                    }
                    
                    if viewModel.isSearching {
                        ProgressView("Searching...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if !viewModel.searchResults.isEmpty {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.searchResults) { recipe in
                                RecipeRowView(recipe: recipe) {
                                    viewModel.selectRecipe(recipe)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Discover")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingImportSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportSheetView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.showRecipeDetail) {
            if let recipe = viewModel.selectedRecipe {
                RecipeDetailView(recipe: recipe)
                    .environmentObject(viewModel)
            }
        }
    }
}

// MARK: - Import Progress View

struct ImportProgressView: View {
    let progress: ImportProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(progress.stage.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(progress.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            Text(progress.message)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    let onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            TextField("Search recipes...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    onSearchButtonClicked()
                }
            
            Button("Search") {
                onSearchButtonClicked()
            }
            .disabled(text.isEmpty)
        }
    }
}

// MARK: - Recipe Row View

struct RecipeRowView: View {
    let recipe: Recipe
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Recipe Image
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
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Recipe Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(recipe.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Label("\(recipe.totalTimeMinutes) min", systemImage: "clock")
                    
                    if let nutrition = recipe.nutrition {
                        Label("\(Int(nutrition.calories)) cal", systemImage: "flame")
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .recipeCardAccessibility(recipe.title)
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Import Sheet

struct ImportSheetView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import Recipe")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Paste a URL from your favorite cooking content")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Supported Platforms:")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        PlatformButton(name: "Instagram", icon: "camera", color: .pink)
                        PlatformButton(name: "TikTok", icon: "music.note", color: .black)
                        PlatformButton(name: "YouTube", icon: "play.rectangle", color: .red)
                        PlatformButton(name: "Web", icon: "globe", color: .blue)
                    }
                }
                
                TextField("Paste recipe URL here...", text: $url, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3, reservesSpace: true)
                
                Button {
                    Task {
                        await viewModel.importRecipe(from: url)
                        dismiss()
                    }
                } label: {
                    HStack {
                        if viewModel.isImporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text("Import Recipe")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(url.isEmpty || viewModel.isImporting)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PlatformButton: View {
    let name: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    MealPlanningRootView()
}