import SwiftUI
import MealPlanningService

struct ShoppingListView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @State private var selectedStore = ""
    @State private var showingStoreComparison = false
    @State private var showingOrderSheet = false
    @State private var groupByCategory = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let shoppingList = viewModel.currentShoppingList {
                    // Store selector and totals
                    StoreHeaderView(
                        shoppingList: shoppingList,
                        selectedStore: $selectedStore,
                        showingComparison: $showingStoreComparison
                    )
                    .padding()
                    
                    // Items list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if groupByCategory {
                                ForEach(groupedItems(shoppingList.normalizedItems), id: \.category) { group in
                                    CategorySection(
                                        category: group.category,
                                        items: group.items,
                                        selectedStore: selectedStore
                                    )
                                    .environmentObject(viewModel)
                                }
                            } else {
                                ForEach(shoppingList.normalizedItems) { item in
                                    GroceryItemView(
                                        item: item,
                                        selectedStore: selectedStore
                                    )
                                    .environmentObject(viewModel)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Action buttons
                    ShoppingActionsView(
                        shoppingList: shoppingList,
                        selectedStore: selectedStore,
                        showingOrderSheet: $showingOrderSheet
                    )
                    .environmentObject(viewModel)
                    .padding()
                    
                } else {
                    EmptyShoppingListView()
                }
            }
            .navigationTitle("Shopping List")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        groupByCategory.toggle()
                    } label: {
                        Image(systemName: groupByCategory ? "list.bullet" : "square.grid.2x2")
                    }
                    
                    if viewModel.currentShoppingList != nil {
                        Button {
                            showingStoreComparison = true
                        } label: {
                            Image(systemName: "chart.bar")
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadShoppingList()
        }
        .sheet(isPresented: $showingStoreComparison) {
            if let shoppingList = viewModel.currentShoppingList {
                StoreComparisonSheet(shoppingList: shoppingList, selectedStore: $selectedStore)
                    .environmentObject(viewModel)
            }
        }
        .sheet(isPresented: $showingOrderSheet) {
            if let shoppingList = viewModel.currentShoppingList {
                OrderCheckoutSheet(shoppingList: shoppingList, selectedStore: selectedStore)
                    .environmentObject(viewModel)
            }
        }
    }
    
    private func groupedItems(_ items: [GroceryItem]) -> [CategoryGroup] {
        let grouped = Dictionary(grouping: items) { $0.category }
        return grouped.map { CategoryGroup(category: $0.key, items: $0.value) }
            .sorted { $0.category.rawValue < $1.category.rawValue }
    }
}

// MARK: - Category Group

struct CategoryGroup {
    let category: IngredientCategory
    let items: [GroceryItem]
}

// MARK: - Store Header

struct StoreHeaderView: View {
    let shoppingList: ShoppingList
    @Binding var selectedStore: String
    @Binding var showingComparison: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Store picker
            Picker("Store", selection: $selectedStore) {
                Text("Compare All").tag("")
                ForEach(shoppingList.stores, id: \.id) { store in
                    Text(store.name).tag(store.id)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Total and completion
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(shoppingList.normalizedItems.count)")
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Purchased")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(purchasedCount)/\(shoppingList.normalizedItems.count)")
                        .font(.headline)
                        .foregroundColor(purchasedCount == shoppingList.normalizedItems.count ? .green : .primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Estimated Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let selectedStoreInfo = shoppingList.stores.first(where: { $0.id == selectedStore }),
                       let total = selectedStoreInfo.estimatedTotal {
                        Text(total.formatted)
                            .font(.headline)
                    } else if let estimatedTotal = shoppingList.estimatedTotal {
                        Text(estimatedTotal.formatted)
                            .font(.headline)
                    } else {
                        Text("--")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var purchasedCount: Int {
        shoppingList.normalizedItems.filter { $0.isPurchased }.count
    }
}

// MARK: - Category Section

struct CategorySection: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    let category: IngredientCategory
    let items: [GroceryItem]
    let selectedStore: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.rawValue.capitalized)
                    .font(.headline)
                    .foregroundColor(.accentColor)
                
                Spacer()
                
                Text("\(purchasedCount)/\(items.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(items) { item in
                GroceryItemView(item: item, selectedStore: selectedStore)
                    .environmentObject(viewModel)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var purchasedCount: Int {
        items.filter { $0.isPurchased }.count
    }
}

// MARK: - Grocery Item View

struct GroceryItemView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    let item: GroceryItem
    let selectedStore: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                Task {
                    await viewModel.toggleItemPurchased(item)
                }
            } label: {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isPurchased ? .green : .secondary)
                    .font(.title2)
            }
            
            // Item info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(item.isPurchased)
                    .foregroundColor(item.isPurchased ? .secondary : .primary)
                
                HStack(spacing: 8) {
                    Text("\(item.totalQuantity.clean) \(item.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !item.recipeReferences.isEmpty {
                        Text("• \(item.recipeReferences.count) recipe\(item.recipeReferences.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !item.substitutions.isEmpty && !selectedStore.isEmpty {
                    Text("Substitutions available")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Price
            if let price = currentPrice {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price.formatted)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let store = shoppingList?.stores.first(where: { $0.id == selectedStore }) {
                        Text(store.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(item.isPurchased ? Color(.systemGray6).opacity(0.5) : Color(.systemBackground))
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.2), value: item.isPurchased)
    }
    
    private var currentPrice: Money? {
        if selectedStore.isEmpty {
            return item.priceEstimates.min { $0.price.amount < $1.price.amount }?.price
        } else {
            return item.priceEstimates.first { $0.storeId == selectedStore }?.price
        }
    }
    
    private var shoppingList: ShoppingList? {
        viewModel.currentShoppingList
    }
}

// MARK: - Shopping Actions

struct ShoppingActionsView: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    let shoppingList: ShoppingList
    let selectedStore: String
    @Binding var showingOrderSheet: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Store actions
            if !selectedStore.isEmpty,
               let store = shoppingList.stores.first(where: { $0.id == selectedStore }) {
                
                HStack(spacing: 12) {
                    if store.pickupAvailable {
                        Button {
                            showingOrderSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "car")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Pickup")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    if let pickupTime = store.estimatedPickupTime {
                                        Text(pickupTime)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if store.deliveryAvailable {
                        Button {
                            showingOrderSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "shippingbox")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Delivery")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    if let deliveryTime = store.estimatedDeliveryTime {
                                        Text(deliveryTime)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            // Progress indicator
            if purchasedCount > 0 {
                HStack {
                    Text("Shopping Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(Double(purchasedCount) / Double(totalCount) * 100))% Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: Double(purchasedCount), total: Double(totalCount))
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
            }
        }
    }
    
    private var purchasedCount: Int {
        shoppingList.normalizedItems.filter { $0.isPurchased }.count
    }
    
    private var totalCount: Int {
        shoppingList.normalizedItems.count
    }
}

// MARK: - Empty State

struct EmptyShoppingListView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Shopping List")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Create a meal plan to generate your shopping list")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Store Comparison Sheet

struct StoreComparisonSheet: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @Environment(\.dismiss) private var dismiss
    let shoppingList: ShoppingList
    @Binding var selectedStore: String
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Store comparison cards
                LazyVStack(spacing: 12) {
                    ForEach(shoppingList.stores, id: \.id) { store in
                        StoreComparisonCard(
                            store: store,
                            isSelected: selectedStore == store.id
                        ) {
                            selectedStore = store.id
                            dismiss()
                        }
                    }
                }
                .padding()
                
                // Compare prices button
                Button {
                    Task {
                        await viewModel.comparePrices(stores: shoppingList.stores.map { $0.id })
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text("Update Prices")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Compare Stores")
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

// MARK: - Store Comparison Card

struct StoreComparisonCard: View {
    let store: StoreInfo
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.name)
                        .font(.headline)
                    
                    Text(store.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if let total = store.estimatedTotal {
                    Text(total.formatted)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .accentColor : .primary)
                }
            }
            
            HStack(spacing: 16) {
                if store.pickupAvailable, let pickupTime = store.estimatedPickupTime {
                    Label(pickupTime, systemImage: "car")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if store.deliveryAvailable, let deliveryTime = store.estimatedDeliveryTime {
                    Label(deliveryTime, systemImage: "shippingbox")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
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

// MARK: - Order Checkout Sheet

struct OrderCheckoutSheet: View {
    @EnvironmentObject var viewModel: MealPlanningViewModel
    @Environment(\.dismiss) private var dismiss
    let shoppingList: ShoppingList
    let selectedStore: String
    @State private var fulfillmentType: FulfillmentType = .pickup
    @State private var isOrdering = false
    
    private var selectedStoreInfo: StoreInfo? {
        shoppingList.stores.first { $0.id == selectedStore }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let store = selectedStoreInfo {
                    // Store info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Order from \(store.name)")
                            .font(.headline)
                        
                        Text(store.address)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        if let total = store.estimatedTotal {
                            HStack {
                                Text("Estimated Total:")
                                    .font(.subheadline)
                                Spacer()
                                Text(total.formatted)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    
                    // Fulfillment options
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fulfillment")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            if store.pickupAvailable {
                                FulfillmentOption(
                                    type: .pickup,
                                    title: "Store Pickup",
                                    subtitle: store.estimatedPickupTime ?? "Ready in 2 hours",
                                    icon: "car",
                                    isSelected: fulfillmentType == .pickup
                                ) {
                                    fulfillmentType = .pickup
                                }
                            }
                            
                            if store.deliveryAvailable {
                                FulfillmentOption(
                                    type: .delivery,
                                    title: "Home Delivery",
                                    subtitle: store.estimatedDeliveryTime ?? "Delivered in 3-5 hours",
                                    icon: "shippingbox",
                                    isSelected: fulfillmentType == .delivery
                                ) {
                                    fulfillmentType = .delivery
                                }
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Order button
                    Button {
                        Task {
                            isOrdering = true
                            let order = await viewModel.createShoppingOrder(
                                storeId: selectedStore,
                                fulfillmentType: fulfillmentType
                            )
                            isOrdering = false
                            
                            if order != nil {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if isOrdering {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text("Place Order")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isOrdering)
                    .padding()
                }
            }
            .navigationTitle("Checkout")
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

// MARK: - Fulfillment Option

struct FulfillmentOption: View {
    let type: FulfillmentType
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title2)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(8)
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Extensions

extension Double {
    var clean: String {
        return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
    }
}