import SwiftUI
import FoodDeliveryService

/// Menu management interface for restaurants
public struct MenuManagementView: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    @State private var selectedCategory: String = "All"
    @State private var showingAddItem = false
    @State private var editingItem: MenuItem?
    @State private var searchText = ""
    
    private var categories: [String] {
        let allCategories = Set(viewModel.menuItems.map { $0.category })
        return ["All"] + Array(allCategories).sorted()
    }
    
    private var filteredItems: [MenuItem] {
        var items = viewModel.menuItems
        
        // Filter by category
        if selectedCategory != "All" {
            items = items.filter { $0.category == selectedCategory }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            items = items.filter {
                $0.title.lowercased().contains(searchText.lowercased()) ||
                $0.description.lowercased().contains(searchText.lowercased())
            }
        }
        
        return items.sorted { $0.title < $1.title }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search and filters
            VStack(spacing: 12) {
                // Search bar
                SearchBar(text: $searchText)
                
                // Category filter
                CategoryScrollView(
                    categories: categories,
                    selectedCategory: $selectedCategory
                )
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Menu items list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredItems, id: \.id) { item in
                        MenuManagementItemCard(
                            item: item,
                            onEdit: {
                                editingItem = item
                            },
                            onToggleAvailability: {
                                Task {
                                    if let id = item.id {
                                        await viewModel.updateMenuItemAvailability(
                                            id,
                                            isAvailable: !item.isAvailable
                                        )
                                    }
                                }
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Menu Management")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Item") {
                    showingAddItem = true
                }
                .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddMenuItemSheet(viewModel: viewModel)
        }
        .sheet(item: $editingItem) { item in
            EditMenuItemSheet(item: item, viewModel: viewModel)
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search menu items...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Category Scroll View
struct CategoryScrollView: View {
    let categories: [String]
    @Binding var selectedCategory: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    CategoryChip(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Menu Item Card
struct MenuManagementItemCard: View {
    let item: MenuItem
    let onEdit: () -> Void
    let onToggleAvailability: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Item image placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Item header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        Text(item.category.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.0f MAD", item.price))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        AvailabilityToggle(
                            isAvailable: item.isAvailable,
                            onToggle: onToggleAvailability
                        )
                    }
                }
                
                // Item description
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Item details
                HStack(spacing: 16) {
                    if let calories = item.calories {
                        Label("\(calories) cal", systemImage: "flame")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if !item.dietaryTags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(item.dietaryTags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                            
                            if item.dietaryTags.count > 2 {
                                Text("+\(item.dietaryTags.count - 2)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button("Edit") {
                        onEdit()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .opacity(item.isAvailable ? 1.0 : 0.6)
    }
}

// MARK: - Availability Toggle
struct AvailabilityToggle: View {
    let isAvailable: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isAvailable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(isAvailable ? "Available" : "Unavailable")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isAvailable ? .green : .red)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((isAvailable ? Color.green : Color.red).opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Add Menu Item Sheet
struct AddMenuItemSheet: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var category = ""
    @State private var price = ""
    @State private var calories = ""
    @State private var selectedDietaryTags: Set<String> = []
    @State private var ingredients = ""
    
    private let dietaryTags = ["vegetarian", "vegan", "gluten-free", "halal", "spicy", "healthy"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Item Name", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Category", text: $category)
                    TextField("Price (MAD)", text: $price)
                        .keyboardType(.decimalPad)
                }
                
                Section("Additional Details") {
                    TextField("Calories (optional)", text: $calories)
                        .keyboardType(.numberPad)
                    
                    TextField("Main Ingredients (comma separated)", text: $ingredients)
                }
                
                Section("Dietary Tags") {
                    ForEach(dietaryTags, id: \.self) { tag in
                        Toggle(tag.capitalized, isOn: Binding(
                            get: { selectedDietaryTags.contains(tag) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDietaryTags.insert(tag)
                                } else {
                                    selectedDietaryTags.remove(tag)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Add Menu Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMenuItem()
                    }
                    .disabled(title.isEmpty || category.isEmpty || price.isEmpty)
                }
            }
        }
    }
    
    private func saveMenuItem() {
        // In a real implementation, this would create a new menu item
        // via the service and add it to the menu
        dismiss()
    }
}

// MARK: - Edit Menu Item Sheet
struct EditMenuItemSheet: View {
    let item: MenuItem
    @ObservedObject var viewModel: MerchantConsoleViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var category: String
    @State private var price: String
    @State private var calories: String
    @State private var selectedDietaryTags: Set<String>
    @State private var ingredients: String
    
    private let dietaryTags = ["vegetarian", "vegan", "gluten-free", "halal", "spicy", "healthy"]
    
    init(item: MenuItem, viewModel: MerchantConsoleViewModel) {
        self.item = item
        self.viewModel = viewModel
        
        self._title = State(initialValue: item.title)
        self._description = State(initialValue: item.description ?? "")
        self._category = State(initialValue: item.category)
        self._price = State(initialValue: String(format: "%.0f", item.price))
        self._calories = State(initialValue: item.calories.map(String.init) ?? "")
        self._selectedDietaryTags = State(initialValue: Set(item.dietaryTags))
        self._ingredients = State(initialValue: item.primaryIngredients.joined(separator: ", "))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Item Name", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Category", text: $category)
                    TextField("Price (MAD)", text: $price)
                        .keyboardType(.decimalPad)
                }
                
                Section("Additional Details") {
                    TextField("Calories (optional)", text: $calories)
                        .keyboardType(.numberPad)
                    
                    TextField("Main Ingredients (comma separated)", text: $ingredients)
                }
                
                Section("Dietary Tags") {
                    ForEach(dietaryTags, id: \.self) { tag in
                        Toggle(tag.capitalized, isOn: Binding(
                            get: { selectedDietaryTags.contains(tag) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDietaryTags.insert(tag)
                                } else {
                                    selectedDietaryTags.remove(tag)
                                }
                            }
                        ))
                    }
                }
                
                Section("Availability") {
                    Toggle("Available for Order", isOn: .constant(item.isAvailable))
                }
                
                Section {
                    Button("Delete Item", role: .destructive) {
                        // Handle deletion
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Menu Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty || category.isEmpty || price.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        // In a real implementation, this would update the menu item
        // via the service
        dismiss()
    }
}

#Preview {
    MenuManagementView(viewModel: MerchantConsoleViewModel(restaurantId: "rest1", service: MockFoodDeliveryService()))
}