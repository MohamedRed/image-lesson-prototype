import SwiftUI
import MealPlanningService
import PhotosUI

public struct MealSharingView: View {
    let recipe: Recipe
    @StateObject private var memoryCreator = MealMemoryCreator()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var cookingImages: [UIImage] = []
    @State private var personalNotes = ""
    @State private var rating: Int = 5
    @State private var cookingTime: Int = 0
    @State private var difficulty: CookingDifficulty = .medium
    @State private var wouldMakeAgain = true
    @State private var showingShareSheet = false
    @State private var showingFriendsSelection = false
    @State private var selectedFriends: Set<String> = []
    
    public init(recipe: Recipe) {
        self.recipe = recipe
    }
    
    public var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // Recipe Summary
                    recipeSummaryCard
                    
                    // Photo Selection
                    photoSelectionSection
                    
                    // Experience Details
                    experienceDetailsSection
                    
                    // Personal Review
                    personalReviewSection
                    
                    // Sharing Options
                    sharingOptionsSection
                }
                .padding()
            }
            .navigationTitle("Share Your Cooking")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Share") { createAndShareMemory() }.disabled(cookingImages.isEmpty)
            )
        }
        .photosPicker(isPresented: .constant(true), 
                     selection: $selectedPhotos,
                     maxSelectionCount: 5,
                     matching: .images)
        .onChange(of: selectedPhotos) { newItems in
            Task<Void, Never> {
                await loadSelectedPhotos(newItems)
            }
        }
        .sheet(isPresented: $showingFriendsSelection) {
            FriendsSelectionView(selectedFriends: $selectedFriends)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let mealMemory = memoryCreator.createdMemory {
                MealMemoryShareSheet(memory: mealMemory)
            }
        }
    }
    
    private var recipeSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
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
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text("Completed cooking session")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(Date().formatted(date: .abbreviated, time: .shortened), 
                          systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var photoSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Photos")
                .font(.headline)
            
            Text("Share photos of your cooking process and final dish")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if cookingImages.isEmpty {
                PhotosPickerEmptyState()
            } else {
                PhotosGridView(images: cookingImages) { index in
                    cookingImages.remove(at: index)
                }
            }
        }
    }
    
    private var experienceDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cooking Experience")
                .font(.headline)
            
            // Cooking Time
            HStack {
                Text("Actual cooking time:")
                Spacer()
                Text("\(cookingTime) minutes")
                    .foregroundColor(.secondary)
                
                Stepper("", value: $cookingTime, in: 0...480, step: 5)
                    .labelsHidden()
            }
            
            // Difficulty Rating
            HStack {
                Text("Difficulty:")
                Spacer()
                
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(CookingDifficulty.allCases, id: \.self) { difficulty in
                        Text(difficulty.displayName).tag(difficulty)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 180)
            }
            
            // Would Make Again
            Toggle("Would make again", isOn: $wouldMakeAgain)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var personalReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Review")
                .font(.headline)
            
            // Star Rating
            HStack {
                Text("Rating:")
                
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .foregroundColor(star <= rating ? .yellow : .gray)
                            .onTapGesture {
                                rating = star
                            }
                    }
                }
            }
            
            // Personal Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes & Tips:")
                    .font(.subheadline)
                
                TextEditor(text: $personalNotes)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var sharingOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Share With")
                .font(.headline)
            
            // Share with Friends
            Button {
                showingFriendsSelection = true
            } label: {
                HStack {
                    Image(systemName: "person.2")
                    Text("Friends")
                    Spacer()
                    if !selectedFriends.isEmpty {
                        Text("\(selectedFriends.count) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
            .foregroundColor(.primary)
            
            // Public Sharing Options
            VStack(spacing: 12) {
                ShareToggle(
                    title: "Recipe Collection",
                    description: "Add to your public recipe collection",
                    isOn: .constant(true)
                )
                
                ShareToggle(
                    title: "Community Feed",
                    description: "Share with the cooking community",
                    isOn: .constant(false)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        
        DispatchQueue.main.async {
            self.cookingImages = images
        }
    }
    
    private func createAndShareMemory() {
        Task<Void, Never> {
            let memory = MealMemory(
                id: UUID().uuidString,
                recipeId: recipe.id ?? "",
                recipeTitle: recipe.title,
                images: cookingImages,
                rating: rating,
                personalNotes: personalNotes,
                cookingTime: cookingTime,
                difficulty: difficulty,
                wouldMakeAgain: wouldMakeAgain,
                createdAt: Date()
            )
            
            await memoryCreator.createMemory(memory, shareWith: selectedFriends)
            
            DispatchQueue.main.async {
                showingShareSheet = true
                
                // Track sharing event
                MealPlanningAnalytics.shared.trackFeatureUsage(
                    feature: "meal_sharing",
                    usage: "memory_created"
                )
            }
        }
    }
}

// MARK: - Supporting Views

struct PhotosPickerEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("Add photos of your cooking")
                .font(.headline)
            
            Text("Share your cooking process and final results")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 2, dash: [5]))
        )
    }
}

struct PhotosGridView: View {
    let images: [UIImage]
    let onRemove: (Int) -> Void
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Button {
                        onRemove(index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(4)
                }
            }
        }
    }
}

struct ShareToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct FriendsSelectionView: View {
    @Binding var selectedFriends: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var mockFriends = [
        Friend(id: "1", name: "Alice Johnson", avatar: "person.circle"),
        Friend(id: "2", name: "Bob Smith", avatar: "person.circle"),
        Friend(id: "3", name: "Carol Davis", avatar: "person.circle")
    ]
    
    var body: some View {
        NavigationView {
            List(mockFriends) { friend in
                HStack {
                    Image(systemName: friend.avatar)
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text(friend.name)
                    
                    Spacer()
                    
                    if selectedFriends.contains(friend.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedFriends.contains(friend.id) {
                        selectedFriends.remove(friend.id)
                    } else {
                        selectedFriends.insert(friend.id)
                    }
                }
            }
            .navigationTitle("Share with Friends")
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

struct Friend: Identifiable {
    let id: String
    let name: String
    let avatar: String
}

struct MealMemoryShareSheet: View {
    let memory: MealMemory
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Memory Created! 🎉")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your cooking memory has been saved and shared")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // Preview of memory
            MealMemoryPreview(memory: memory)
            
            HStack(spacing: 16) {
                Button("Share More") {
                    // Share to other platforms
                }
                .buttonStyle(.bordered)
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

struct MealMemoryPreview: View {
    let memory: MealMemory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(memory.recipeTitle)
                .font(.headline)
            
            HStack {
                // Star rating
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= memory.rating ? "star.fill" : "star")
                            .foregroundColor(star <= memory.rating ? .yellow : .gray)
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                Text("\(memory.cookingTime) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !memory.personalNotes.isEmpty {
                Text(memory.personalNotes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Models

public enum CookingDifficulty: String, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    public var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}

public struct MealMemory {
    public let id: String
    public let recipeId: String
    public let recipeTitle: String
    public let images: [UIImage]
    public let rating: Int
    public let personalNotes: String
    public let cookingTime: Int
    public let difficulty: CookingDifficulty
    public let wouldMakeAgain: Bool
    public let createdAt: Date
}

// MARK: - Memory Creator

public final class MealMemoryCreator: ObservableObject {
    @Published public var createdMemory: MealMemory?
    @Published public var isCreating = false
    
    public func createMemory(_ memory: MealMemory, shareWith friends: Set<String>) async {
        DispatchQueue.main.async {
            self.isCreating = true
        }
        
        // Simulate memory creation process
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // In real implementation, this would:
        // 1. Upload images to cloud storage
        // 2. Create memory record in database
        // 3. Send notifications to selected friends
        // 4. Update user's cooking history
        
        DispatchQueue.main.async {
            self.createdMemory = memory
            self.isCreating = false
            
            // Track memory creation
            MealPlanningAnalytics.shared.trackFeatureUsage(
                feature: "meal_memory",
                usage: "created"
            )
        }
    }
}

#Preview {
    MealSharingView(recipe: Recipe(
        id: "preview",
        title: "Delicious Pasta",
        description: "A wonderful pasta dish",
        images: [],
        videoUrl: nil,
        sourcePlatform: .manual,
        sourceAuthor: nil,
        sourceAttribution: nil,
        tags: [],
        cuisines: [],
        steps: [],
        ingredients: [],
        utensils: [],
        nutrition: nil,
        servings: 4,
        prepTimeMinutes: 10,
        cookTimeMinutes: 20,
        totalTimeMinutes: 30,
        difficultyLevel: .beginner
    ))
}