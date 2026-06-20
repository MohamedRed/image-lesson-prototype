import SwiftUI
import FoodDeliveryService

/// View for customizing menu items with options and add-ons
public struct MenuItemCustomizationView: View {
    let menuItem: MenuItem
    @ObservedObject var viewModel: FoodDeliveryViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedOptions: [String: Set<String>] = [:]
    @State private var quantity = 1
    @State private var specialInstructions = ""
    
    public init(menuItem: MenuItem, viewModel: FoodDeliveryViewModel) {
        self.menuItem = menuItem
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Menu item header
                    menuItemHeader
                    
                    // Options sections
                    if !menuItem.options.isEmpty {
                        optionsSection
                    }
                    
                    // Special instructions
                    specialInstructionsSection
                    
                    // Quantity selector
                    quantitySection
                }
                .padding()
            }
            .navigationTitle(menuItem.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                addToCartButton
            }
        }
        .onAppear {
            setupDefaultSelections()
        }
    }
    
    private var menuItemHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Menu item image
            AsyncImage(url: URL(string: menuItem.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.gray)
                    )
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                // Title and price
                HStack(alignment: .top) {
                    Text(menuItem.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("\(Int(menuItem.price)) MAD")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                // Description
                Text(menuItem.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Dietary tags and calories
                HStack {
                    if !menuItem.dietaryTags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(menuItem.dietaryTags, id: \.self) { tag in
                                Text(tag.uppercased())
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if let calories = menuItem.calories {
                        Text("\(calories) cal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(menuItem.options, id: \.id) { option in
                OptionSectionView(
                    option: option,
                    selectedChoices: Binding(
                        get: { selectedOptions[option.id] ?? Set() },
                        set: { selectedOptions[option.id] = $0 }
                    )
                )
            }
        }
    }
    
    private var specialInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Special Instructions")
                .font(.headline)
            
            TextField("Any special requests...", text: $specialInstructions, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.roundedBorder)
            
            Text("Let us know about allergies, spice preferences, etc.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quantity")
                .font(.headline)
            
            HStack {
                Button {
                    if quantity > 1 {
                        quantity -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(quantity > 1 ? .blue : .gray)
                        .font(.title)
                }
                .disabled(quantity <= 1)
                
                Spacer()
                
                Text("\(quantity)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(minWidth: 40)
                
                Spacer()
                
                Button {
                    quantity += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var addToCartButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button(action: addToCart) {
                HStack {
                    Text("Add to Cart")
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(totalPrice, specifier: "%.0f") MAD")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(canAddToCart ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(25)
            }
            .disabled(!canAddToCart)
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    private var totalPrice: Double {
        let basePrice = menuItem.price
        let optionsPrice = calculateOptionsPrice()
        return (basePrice + optionsPrice) * Double(quantity)
    }
    
    private var canAddToCart: Bool {
        // Check if all required options are selected
        for option in menuItem.options where option.isRequired {
            if let selections = selectedOptions[option.id], selections.isEmpty {
                return false
            }
        }
        return true
    }
    
    private func setupDefaultSelections() {
        for option in menuItem.options {
            let defaultChoices = option.choices.filter { $0.isDefault }
            if !defaultChoices.isEmpty {
                selectedOptions[option.id] = Set(defaultChoices.map { $0.id })
            } else if option.isRequired && option.type == .single {
                // Auto-select first choice for required single-select options
                if let firstChoice = option.choices.first {
                    selectedOptions[option.id] = Set([firstChoice.id])
                }
            }
        }
    }
    
    private func calculateOptionsPrice() -> Double {
        var totalPrice: Double = 0
        
        for option in menuItem.options {
            if let selectedChoiceIds = selectedOptions[option.id] {
                for choiceId in selectedChoiceIds {
                    if let choice = option.choices.first(where: { $0.id == choiceId }) {
                        totalPrice += choice.priceDelta
                    }
                }
            }
        }
        
        return totalPrice
    }
    
    private func addToCart() {
        guard canAddToCart else { return }
        
        // Convert selected options to OrderItem format
        var orderItemOptions: [Order.OrderItem.SelectedOption] = []
        
        for option in menuItem.options {
            if let selectedChoiceIds = selectedOptions[option.id] {
                for choiceId in selectedChoiceIds {
                    if let choice = option.choices.first(where: { $0.id == choiceId }) {
                        orderItemOptions.append(
                            Order.OrderItem.SelectedOption(
                                optionId: option.id,
                                optionName: option.name,
                                choiceId: choice.id,
                                choiceName: choice.name,
                                priceDelta: choice.priceDelta
                            )
                        )
                    }
                }
            }
        }
        
        viewModel.addToCart(
            item: menuItem,
            selectedOptions: orderItemOptions,
            quantity: quantity,
            specialInstructions: specialInstructions.isEmpty ? nil : specialInstructions
        )
        
        dismiss()
    }
}

// MARK: - Option Section View

struct OptionSectionView: View {
    let option: MenuItem.MenuItemOption
    @Binding var selectedChoices: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(option.name)
                    .font(.headline)
                
                if option.isRequired {
                    Text("Required")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                if option.type == .multiple && option.maxSelections > 1 {
                    Text("Choose up to \(option.maxSelections)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 8) {
                ForEach(option.choices, id: \.id) { choice in
                    OptionChoiceRow(
                        choice: choice,
                        isSelected: selectedChoices.contains(choice.id),
                        selectionType: option.type
                    ) {
                        toggleChoice(choice.id)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func toggleChoice(_ choiceId: String) {
        switch option.type {
        case .single:
            selectedChoices = Set([choiceId])
        case .multiple:
            if selectedChoices.contains(choiceId) {
                selectedChoices.remove(choiceId)
            } else {
                if selectedChoices.count < option.maxSelections {
                    selectedChoices.insert(choiceId)
                }
            }
        case .quantity:
            // For quantity type, we'd need a different UI (stepper)
            selectedChoices = selectedChoices.contains(choiceId) ? Set() : Set([choiceId])
        }
    }
}

struct OptionChoiceRow: View {
    let choice: MenuItem.OptionChoice
    let isSelected: Bool
    let selectionType: MenuItem.MenuItemOption.OptionType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Selection indicator
                Image(systemName: selectionType == .single ? 
                    (isSelected ? "checkmark.circle.fill" : "circle") :
                    (isSelected ? "checkmark.square.fill" : "square")
                )
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title3)
                
                // Choice name
                Text(choice.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Price delta
                if choice.priceDelta > 0 {
                    Text("+\(choice.priceDelta, specifier: "%.0f") MAD")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if choice.priceDelta < 0 {
                    Text("\(choice.priceDelta, specifier: "%.0f") MAD")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MenuItemCustomizationView(
        menuItem: MenuItem(
            id: "item1",
            restaurantId: "rest1",
            category: "pizzas",
            title: "Margherita Pizza",
            description: "Fresh tomatoes, mozzarella, basil",
            price: 85,
            options: [
                MenuItem.MenuItemOption(
                    name: "Size",
                    type: .single,
                    choices: [
                        MenuItem.OptionChoice(name: "Small", priceDelta: 0, isDefault: true),
                        MenuItem.OptionChoice(name: "Large", priceDelta: 15)
                    ],
                    isRequired: true
                )
            ]
        ),
        viewModel: FoodDeliveryViewModel(service: MockFoodDeliveryService())
    )
}