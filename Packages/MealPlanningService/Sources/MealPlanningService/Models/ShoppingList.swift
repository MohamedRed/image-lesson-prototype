import Foundation

public struct ShoppingList: Identifiable, Codable, Hashable {
    public let id: String?
    public let mealPlanId: String
    public let userId: String
    public let normalizedItems: [GroceryItem]
    public let estimatedTotal: Money?
    public let stores: [StoreInfo]
    public let status: ShoppingListStatus
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String? = nil,
        mealPlanId: String,
        userId: String,
        normalizedItems: [GroceryItem] = [],
        estimatedTotal: Money? = nil,
        stores: [StoreInfo] = [],
        status: ShoppingListStatus = .draft,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.mealPlanId = mealPlanId
        self.userId = userId
        self.normalizedItems = normalizedItems
        self.estimatedTotal = estimatedTotal
        self.stores = stores
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ShoppingListStatus: String, Codable, CaseIterable {
    case draft
    case ready
    case inProgress
    case completed
}

public struct GroceryItem: Identifiable, Codable, Hashable {
    public let id: String
    public let ingredientKey: String
    public let displayName: String
    public let totalQuantity: Double
    public let unit: String
    public let category: IngredientCategory
    public let preferredBrands: [String]
    public let substitutions: [String]
    public let storeMappings: [String: StoreSKU] // storeId -> SKU
    public let priceEstimates: [StorePrice]
    public let recipeReferences: [RecipeReference]
    public let isPurchased: Bool
    public let notes: String?
    
    public init(
        id: String = UUID().uuidString,
        ingredientKey: String,
        displayName: String,
        totalQuantity: Double,
        unit: String,
        category: IngredientCategory,
        preferredBrands: [String] = [],
        substitutions: [String] = [],
        storeMappings: [String: StoreSKU] = [:],
        priceEstimates: [StorePrice] = [],
        recipeReferences: [RecipeReference] = [],
        isPurchased: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.ingredientKey = ingredientKey
        self.displayName = displayName
        self.totalQuantity = totalQuantity
        self.unit = unit
        self.category = category
        self.preferredBrands = preferredBrands
        self.substitutions = substitutions
        self.storeMappings = storeMappings
        self.priceEstimates = priceEstimates
        self.recipeReferences = recipeReferences
        self.isPurchased = isPurchased
        self.notes = notes
    }
}

public struct StoreSKU: Codable, Hashable {
    public let sku: String
    public let productName: String
    public let brand: String?
    public let packageSize: String?
    public let unitPrice: Money
    
    public init(
        sku: String,
        productName: String,
        brand: String? = nil,
        packageSize: String? = nil,
        unitPrice: Money
    ) {
        self.sku = sku
        self.productName = productName
        self.brand = brand
        self.packageSize = packageSize
        self.unitPrice = unitPrice
    }
}

public struct StorePrice: Codable, Hashable {
    public let storeId: String
    public let storeName: String
    public let price: Money
    public let availability: ProductAvailability
    public let lastUpdated: Date
    public let promotionText: String?
    
    public init(
        storeId: String,
        storeName: String,
        price: Money,
        availability: ProductAvailability = .available,
        lastUpdated: Date = Date(),
        promotionText: String? = nil
    ) {
        self.storeId = storeId
        self.storeName = storeName
        self.price = price
        self.availability = availability
        self.lastUpdated = lastUpdated
        self.promotionText = promotionText
    }
}

public enum ProductAvailability: String, Codable, CaseIterable {
    case available
    case lowStock
    case outOfStock
    case unknown
}

public struct StoreInfo: Codable, Hashable {
    public let id: String
    public let name: String
    public let address: String
    public let coordinates: Coordinates?
    public let pickupAvailable: Bool
    public let deliveryAvailable: Bool
    public let estimatedTotal: Money?
    public let estimatedPickupTime: String? // e.g., "2 hours"
    public let estimatedDeliveryTime: String? // e.g., "1-3 hours"
    
    public init(
        id: String,
        name: String,
        address: String,
        coordinates: Coordinates? = nil,
        pickupAvailable: Bool = true,
        deliveryAvailable: Bool = false,
        estimatedTotal: Money? = nil,
        estimatedPickupTime: String? = nil,
        estimatedDeliveryTime: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinates = coordinates
        self.pickupAvailable = pickupAvailable
        self.deliveryAvailable = deliveryAvailable
        self.estimatedTotal = estimatedTotal
        self.estimatedPickupTime = estimatedPickupTime
        self.estimatedDeliveryTime = estimatedDeliveryTime
    }
}

public struct Coordinates: Codable, Hashable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct Money: Codable, Hashable {
    public let amount: Double
    public let currency: String
    
    public init(amount: Double, currency: String = "MAD") {
        self.amount = amount
        self.currency = currency
    }
    
    public var formatted: String {
        return String(format: "%.2f %@", amount, currency)
    }
}

public struct RecipeReference: Codable, Hashable {
    public let recipeId: String
    public let recipeName: String
    public let quantity: Double
    public let unit: String
    
    public init(recipeId: String, recipeName: String, quantity: Double, unit: String) {
        self.recipeId = recipeId
        self.recipeName = recipeName
        self.quantity = quantity
        self.unit = unit
    }
}

public struct ShoppingOrder: Identifiable, Codable, Hashable {
    public let id: String?
    public let shoppingListId: String
    public let storeId: String
    public let items: [OrderItem]
    public let total: Money
    public let fulfillmentType: FulfillmentType
    public let status: OrderStatus
    public let estimatedReadyAt: Date?
    public let trackingInfo: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String? = nil,
        shoppingListId: String,
        storeId: String,
        items: [OrderItem],
        total: Money,
        fulfillmentType: FulfillmentType,
        status: OrderStatus = .pending,
        estimatedReadyAt: Date? = nil,
        trackingInfo: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.shoppingListId = shoppingListId
        self.storeId = storeId
        self.items = items
        self.total = total
        self.fulfillmentType = fulfillmentType
        self.status = status
        self.estimatedReadyAt = estimatedReadyAt
        self.trackingInfo = trackingInfo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum FulfillmentType: String, Codable, CaseIterable {
    case pickup
    case delivery
    case curbside
}

public enum OrderStatus: String, Codable, CaseIterable {
    case pending
    case confirmed
    case preparing
    case ready
    case completed
    case cancelled
}

public struct OrderItem: Identifiable, Codable, Hashable {
    public let id: String
    public let sku: String
    public let productName: String
    public let quantity: Int
    public let unitPrice: Money
    public let totalPrice: Money
    
    public init(
        id: String = UUID().uuidString,
        sku: String,
        productName: String,
        quantity: Int,
        unitPrice: Money,
        totalPrice: Money
    ) {
        self.id = id
        self.sku = sku
        self.productName = productName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
    }
}