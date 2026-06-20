import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Coordinates
public struct Coordinates: Codable {
    public var latitude: Double
    public var longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - Restaurant
public struct Restaurant: Codable, Identifiable {
    @DocumentID public var id: String?
    public var name: String
    public var logoUrl: String?
    public var cuisineTags: [String]
    public var rating: Double
    public var isOpen: Bool
    public var phone: String?
    public var address: Address
    public var coordinates: Coordinates
    public var openingHours: [String: [TimeRange]]
    public var avgPrepMinutes: Int
    public var deliveryZones: [String]
    public var deliveryFeePolicy: DeliveryFeePolicy
    public var surgeProfile: SurgeProfile?
    public var kyc: KYC
    public var payouts: Payouts?
    @ServerTimestamp public var createdAt: Date?
    
    public struct Address: Codable {
        public var city: String
        public var arrondissement: String?
        public var street: String
        
        public init(city: String, arrondissement: String? = nil, street: String) {
            self.city = city
            self.arrondissement = arrondissement
            self.street = street
        }
    }
    
    public struct TimeRange: Codable {
        public var start: String  // "09:00"
        public var end: String    // "22:00"
        
        public init(start: String, end: String) {
            self.start = start
            self.end = end
        }
    }
    
    public struct DeliveryFeePolicy: Codable {
        public var baseMAD: Double
        public var perKmMAD: Double
        public var minimumOrderMAD: Double?
        public var smallOrderFeeMAD: Double?
        
        public init(baseMAD: Double, perKmMAD: Double, minimumOrderMAD: Double? = nil, smallOrderFeeMAD: Double? = nil) {
            self.baseMAD = baseMAD
            self.perKmMAD = perKmMAD
            self.minimumOrderMAD = minimumOrderMAD
            self.smallOrderFeeMAD = smallOrderFeeMAD
        }
    }
    
    public struct SurgeProfile: Codable {
        public var isActive: Bool
        public var multiplier: Double
        public var zones: [String]
        
        public init(isActive: Bool = false, multiplier: Double = 1.0, zones: [String] = []) {
            self.isActive = isActive
            self.multiplier = multiplier
            self.zones = zones
        }
    }
    
    public struct KYC: Codable {
        public var status: KYCStatus
        public var documents: [String]
        public var verificationTier: VerificationTier
        
        public enum KYCStatus: String, Codable {
            case pending
            case approved
            case rejected
            case incomplete
        }
        
        public enum VerificationTier: String, Codable {
            case unverified
            case basic
            case professional
            case premium
        }
        
        public init(status: KYCStatus = .pending, documents: [String] = [], verificationTier: VerificationTier = .unverified) {
            self.status = status
            self.documents = documents
            self.verificationTier = verificationTier
        }
    }
    
    public struct Payouts: Codable {
        public var stripeAccountId: String?
        public var bankAccount: String?
        
        public init(stripeAccountId: String? = nil, bankAccount: String? = nil) {
            self.stripeAccountId = stripeAccountId
            self.bankAccount = bankAccount
        }
    }
    
    public init(
        id: String? = nil,
        name: String,
        logoUrl: String? = nil,
        cuisineTags: [String] = [],
        rating: Double = 0.0,
        isOpen: Bool = true,
        phone: String? = nil,
        address: Address,
        coordinates: Coordinates,
        openingHours: [String: [TimeRange]] = [:],
        avgPrepMinutes: Int = 30,
        deliveryZones: [String] = [],
        deliveryFeePolicy: DeliveryFeePolicy,
        surgeProfile: SurgeProfile? = nil,
        kyc: KYC = KYC(),
        payouts: Payouts? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.logoUrl = logoUrl
        self.cuisineTags = cuisineTags
        self.rating = rating
        self.isOpen = isOpen
        self.phone = phone
        self.address = address
        self.coordinates = coordinates
        self.openingHours = openingHours
        self.avgPrepMinutes = avgPrepMinutes
        self.deliveryZones = deliveryZones
        self.deliveryFeePolicy = deliveryFeePolicy
        self.surgeProfile = surgeProfile
        self.kyc = kyc
        self.payouts = payouts
        self.createdAt = createdAt
    }
}

// MARK: - Menu Item
public struct MenuItem: Codable, Identifiable {
    @DocumentID public var id: String?
    public var restaurantId: String
    public var category: String
    public var title: String
    public var description: String
    public var imageUrl: String?
    public var price: Double
    public var currency: String
    public var isAvailable: Bool
    public var options: [MenuItemOption]
    public var maxAddons: Int?
    public var calories: Int?
    public var primaryIngredients: [String]
    public var dietaryTags: [String]
    @ServerTimestamp public var launchedAt: Date?
    
    public struct MenuItemOption: Codable, Identifiable {
        public var id: String
        public var name: String
        public var type: OptionType
        public var choices: [OptionChoice]
        public var isRequired: Bool
        public var maxSelections: Int
        
        public enum OptionType: String, Codable {
            case single    // radio buttons
            case multiple  // checkboxes
            case quantity  // stepper
        }
        
        public init(
            id: String = UUID().uuidString,
            name: String,
            type: OptionType,
            choices: [OptionChoice],
            isRequired: Bool = false,
            maxSelections: Int = 1
        ) {
            self.id = id
            self.name = name
            self.type = type
            self.choices = choices
            self.isRequired = isRequired
            self.maxSelections = maxSelections
        }
    }
    
    public struct OptionChoice: Codable, Identifiable {
        public var id: String
        public var name: String
        public var priceDelta: Double
        public var isDefault: Bool
        
        public init(
            id: String = UUID().uuidString,
            name: String,
            priceDelta: Double = 0.0,
            isDefault: Bool = false
        ) {
            self.id = id
            self.name = name
            self.priceDelta = priceDelta
            self.isDefault = isDefault
        }
    }
    
    public init(
        id: String? = nil,
        restaurantId: String,
        category: String,
        title: String,
        description: String,
        imageUrl: String? = nil,
        price: Double,
        currency: String = "MAD",
        isAvailable: Bool = true,
        options: [MenuItemOption] = [],
        maxAddons: Int? = nil,
        calories: Int? = nil,
        primaryIngredients: [String] = [],
        dietaryTags: [String] = [],
        launchedAt: Date? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.category = category
        self.title = title
        self.description = description
        self.imageUrl = imageUrl
        self.price = price
        self.currency = currency
        self.isAvailable = isAvailable
        self.options = options
        self.maxAddons = maxAddons
        self.calories = calories
        self.primaryIngredients = primaryIngredients
        self.dietaryTags = dietaryTags
        self.launchedAt = launchedAt
    }
}

// MARK: - Order
public struct Order: Codable, Identifiable {
    @DocumentID public var id: String?
    public var customerId: String
    public var restaurantId: String
    public var courierId: String?
    public var status: OrderStatus
    public var items: [OrderItem]
    public var subtotal: Double
    public var deliveryFee: Double
    public var serviceFee: Double
    public var tip: Double
    public var total: Double
    public var currency: String
    public var coupon: AppliedCoupon?
    public var payment: PaymentInfo
    public var addresses: OrderAddresses
    public var timings: OrderTimings
    public var tracking: OrderTracking?
    public var cancellation: OrderCancellation?
    public var notes: String?
    // Cash-on-delivery and ETA enhancements
    public var codInstructions: String?
    public var codCollectionStatus: CODCollectionStatus?
    public var estimatedDeliveryTime: Date?
    @ServerTimestamp public var createdAt: Date?
    @ServerTimestamp public var updatedAt: Date?
    
    public enum OrderStatus: String, Codable {
        case created
        case restaurantAccepted = "restaurant_accepted"
        case preparing
        case readyForPickup = "ready_for_pickup"
        case pickedUp = "picked_up"
        case onRoute = "on_route"
        case delivered
        case cancelledByCustomer = "cancelled_by_customer"
        case cancelledByMerchant = "cancelled_by_merchant"
        case cancelledNoCourier = "cancelled_no_courier"
        
        public var displayName: String {
            switch self {
            case .created: return "Order Placed"
            case .restaurantAccepted: return "Confirmed"
            case .preparing: return "Preparing"
            case .readyForPickup: return "Ready for Pickup"
            case .pickedUp: return "Picked Up"
            case .onRoute: return "On the Way"
            case .delivered: return "Delivered"
            case .cancelledByCustomer: return "Cancelled"
            case .cancelledByMerchant: return "Cancelled by Restaurant"
            case .cancelledNoCourier: return "Cancelled - No Courier"
            }
        }
        
        public var isActive: Bool {
            switch self {
            case .created, .restaurantAccepted, .preparing, .readyForPickup, .pickedUp, .onRoute:
                return true
            case .delivered, .cancelledByCustomer, .cancelledByMerchant, .cancelledNoCourier:
                return false
            }
        }
    }

    public enum CODCollectionStatus: String, Codable {
        case pending
        case collected
        case disputed
        case verified
    }
    
    public struct OrderItem: Codable, Identifiable {
        public var id: String
        public var menuItemId: String
        public var title: String
        public var basePrice: Double
        public var quantity: Int
        public var selectedOptions: [SelectedOption]
        public var totalPrice: Double
        public var specialInstructions: String?
        
        public struct SelectedOption: Codable, Equatable {
            // Detailed identifiers
            public var optionId: String
            public var optionName: String
            public var choiceId: String
            public var choiceName: String
            public var priceDelta: Double
            // Simple title used by some callers
            public var title: String?
            
            public init(optionId: String, optionName: String, choiceId: String, choiceName: String, priceDelta: Double, title: String? = nil) {
                self.optionId = optionId
                self.optionName = optionName
                self.choiceId = choiceId
                self.choiceName = choiceName
                self.priceDelta = priceDelta
                self.title = title
            }
        }
        
        public init(
            id: String = UUID().uuidString,
            menuItemId: String,
            title: String,
            basePrice: Double,
            quantity: Int,
            selectedOptions: [SelectedOption] = [],
            totalPrice: Double,
            specialInstructions: String? = nil
        ) {
            self.id = id
            self.menuItemId = menuItemId
            self.title = title
            self.basePrice = basePrice
            self.quantity = quantity
            self.selectedOptions = selectedOptions
            self.totalPrice = totalPrice
            self.specialInstructions = specialInstructions
        }
    }
    
    public struct AppliedCoupon: Codable {
        public var code: String
        public var discountAmount: Double
        public var discountType: DiscountType
        
        public enum DiscountType: String, Codable {
            case fixed
            case percentage
        }
        
        public init(code: String, discountAmount: Double, discountType: DiscountType) {
            self.code = code
            self.discountAmount = discountAmount
            self.discountType = discountType
        }
    }
    
    public struct PaymentInfo: Codable {
        public var method: PaymentMethod
        public var intentId: String?
        public var status: PaymentStatus
        
        public enum PaymentMethod: String, Codable {
            case card
            case cashOnDelivery
            
            public var displayName: String {
                switch self {
                case .card:
                    return "Credit/Debit Card"
                case .cashOnDelivery:
                    return "Cash on Delivery"
                }
            }
            
            public var icon: String {
                switch self {
                case .card:
                    return "creditcard.fill"
                case .cashOnDelivery:
                    return "banknote.fill"
                }
            }
        }
        
        public enum PaymentStatus: String, Codable {
            case pending
            case authorized
            case captured
            case failed
            case refunded
        }
        
        public init(method: PaymentMethod, intentId: String? = nil, status: PaymentStatus = .pending) {
            self.method = method
            self.intentId = intentId
            self.status = status
        }
    }
    
    public struct OrderAddresses: Codable {
        public var pickup: Restaurant.Address
        public var dropoff: DeliveryAddress
        
        public struct DeliveryAddress: Codable {
            public var latitude: Double
            public var longitude: Double
            public var addressLine: String
            public var city: String
            public var arrondissement: String?
            public var instructions: String?
            
            public init(
                latitude: Double,
                longitude: Double,
                addressLine: String,
                city: String,
                arrondissement: String? = nil,
                instructions: String? = nil
            ) {
                self.latitude = latitude
                self.longitude = longitude
                self.addressLine = addressLine
                self.city = city
                self.arrondissement = arrondissement
                self.instructions = instructions
            }
        }
        
        public init(pickup: Restaurant.Address, dropoff: DeliveryAddress) {
            self.pickup = pickup
            self.dropoff = dropoff
        }
    }
    
    public struct OrderTimings: Codable {
        @ServerTimestamp public var createdAt: Date?
        @ServerTimestamp public var acceptedAt: Date?
        @ServerTimestamp public var readyAt: Date?
        @ServerTimestamp public var pickedUpAt: Date?
        @ServerTimestamp public var deliveredAt: Date?
        @ServerTimestamp public var cancelledAt: Date?
        public var etaSeconds: Int?
        
        public init(etaSeconds: Int? = nil) {
            self.etaSeconds = etaSeconds
        }
    }
    
    public struct OrderTracking: Codable {
        public var routePolyline: String?
        public var distanceKm: Double
        public var currentCourierLocation: Coordinates?
        public var handoffProofUrl: String?
        // Additional fields used by some views/services
        public var courierId: String?
        public var courierLocation: Courier.CourierLocation?
        public var estimatedArrival: Date?
        public var handoffPhotoUrl: String?
        
        public init(
            routePolyline: String? = nil,
            distanceKm: Double,
            currentCourierLocation: Coordinates? = nil,
            handoffProofUrl: String? = nil,
            courierId: String? = nil,
            courierLocation: Courier.CourierLocation? = nil,
            estimatedArrival: Date? = nil,
            handoffPhotoUrl: String? = nil
        ) {
            self.routePolyline = routePolyline
            self.distanceKm = distanceKm
            self.currentCourierLocation = currentCourierLocation
            self.handoffProofUrl = handoffProofUrl
            self.courierId = courierId
            self.courierLocation = courierLocation
            self.estimatedArrival = estimatedArrival
            self.handoffPhotoUrl = handoffPhotoUrl
        }
    }
    
    public struct OrderCancellation: Codable {
        public var by: CancelledBy
        public var reasonCode: String
        public var notes: String?
        
        public enum CancelledBy: String, Codable {
            case customer
            case merchant
            case courier
            case system
        }
        
        public init(by: CancelledBy, reasonCode: String, notes: String? = nil) {
            self.by = by
            self.reasonCode = reasonCode
            self.notes = notes
        }
    }
    
    public init(
        id: String? = nil,
        customerId: String,
        restaurantId: String,
        courierId: String? = nil,
        status: OrderStatus = .created,
        items: [OrderItem],
        subtotal: Double,
        deliveryFee: Double,
        serviceFee: Double,
        tip: Double = 0.0,
        total: Double,
        currency: String = "MAD",
        coupon: AppliedCoupon? = nil,
        payment: PaymentInfo,
        addresses: OrderAddresses,
        timings: OrderTimings = OrderTimings(),
        tracking: OrderTracking? = nil,
        cancellation: OrderCancellation? = nil,
        notes: String? = nil,
        codInstructions: String? = nil,
        codCollectionStatus: CODCollectionStatus? = nil,
        estimatedDeliveryTime: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.customerId = customerId
        self.restaurantId = restaurantId
        self.courierId = courierId
        self.status = status
        self.items = items
        self.subtotal = subtotal
        self.deliveryFee = deliveryFee
        self.serviceFee = serviceFee
        self.tip = tip
        self.total = total
        self.currency = currency
        self.coupon = coupon
        self.payment = payment
        self.addresses = addresses
        self.timings = timings
        self.tracking = tracking
        self.cancellation = cancellation
        self.notes = notes
        self.codInstructions = codInstructions
        self.codCollectionStatus = codCollectionStatus
        self.estimatedDeliveryTime = estimatedDeliveryTime
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Courier
public struct Courier: Codable, Identifiable {
    @DocumentID public var id: String?
    public var userId: String
    public var name: String
    public var vehicleType: VehicleType
    public var rating: Double
    public var isOnline: Bool
    public var currentOrderId: String?
    public var location: CourierLocation?
    public var kyc: Restaurant.KYC
    public var payouts: Restaurant.Payouts?
    @ServerTimestamp public var createdAt: Date?
    
    public enum VehicleType: String, Codable {
        case bike
        case motorbike
        case car
    }
    
    public struct CourierLocation: Codable {
        public var latitude: Double
        public var longitude: Double
        @ServerTimestamp public var lastUpdatedAt: Date?
        
        public init(latitude: Double, longitude: Double, lastUpdatedAt: Date? = nil) {
            self.latitude = latitude
            self.longitude = longitude
            self.lastUpdatedAt = lastUpdatedAt
        }
    }
    
    public init(
        id: String? = nil,
        userId: String,
        name: String,
        vehicleType: VehicleType,
        rating: Double = 0.0,
        isOnline: Bool = false,
        currentOrderId: String? = nil,
        location: CourierLocation? = nil,
        kyc: Restaurant.KYC = Restaurant.KYC(),
        payouts: Restaurant.Payouts? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.vehicleType = vehicleType
        self.rating = rating
        self.isOnline = isOnline
        self.currentOrderId = currentOrderId
        self.location = location
        self.kyc = kyc
        self.payouts = payouts
        self.createdAt = createdAt
    }
}

// MARK: - Customer
public struct Customer: Codable, Identifiable {
    @DocumentID public var id: String?
    public var userId: String
    public var defaultAddresses: [SavedAddress]
    public var paymentMethods: [String] // Stripe payment method IDs
    public var preferences: CustomerPreferences
    public var tasteProfile: TasteProfile?
    @ServerTimestamp public var createdAt: Date?
    
    public struct SavedAddress: Codable, Identifiable {
        public var id: String
        public var label: String
        public var address: Order.OrderAddresses.DeliveryAddress
        public var isDefault: Bool
        
        public init(
            id: String = UUID().uuidString,
            label: String,
            address: Order.OrderAddresses.DeliveryAddress,
            isDefault: Bool = false
        ) {
            self.id = id
            self.label = label
            self.address = address
            self.isDefault = isDefault
        }
    }
    
    public struct CustomerPreferences: Codable {
        public var language: String
        public var currency: String
        public var notifications: NotificationPreferences
        
        public struct NotificationPreferences: Codable {
            public var orderUpdates: Bool
            public var promotions: Bool
            public var newRestaurants: Bool
            
            public init(orderUpdates: Bool = true, promotions: Bool = true, newRestaurants: Bool = false) {
                self.orderUpdates = orderUpdates
                self.promotions = promotions
                self.newRestaurants = newRestaurants
            }
        }
        
        public init(language: String = "fr-MA", currency: String = "MAD", notifications: NotificationPreferences = NotificationPreferences()) {
            self.language = language
            self.currency = currency
            self.notifications = notifications
        }
    }
    
    public struct TasteProfile: Codable {
        public var likedCuisines: [String]
        public var likedIngredients: [String]
        public var blockedIngredients: [String]
        public var dietaryTags: [String]
        public var priceBand: PriceBand
        public var noveltyPreference: Double // 0.0 = familiar, 1.0 = adventurous
        
        public enum PriceBand: String, Codable {
            case low
            case mid
            case high
        }
        
        public init(
            likedCuisines: [String] = [],
            likedIngredients: [String] = [],
            blockedIngredients: [String] = [],
            dietaryTags: [String] = [],
            priceBand: PriceBand = .mid,
            noveltyPreference: Double = 0.5
        ) {
            self.likedCuisines = likedCuisines
            self.likedIngredients = likedIngredients
            self.blockedIngredients = blockedIngredients
            self.dietaryTags = dietaryTags
            self.priceBand = priceBand
            self.noveltyPreference = noveltyPreference
        }
    }
    
    public init(
        id: String? = nil,
        userId: String,
        defaultAddresses: [SavedAddress] = [],
        paymentMethods: [String] = [],
        preferences: CustomerPreferences = CustomerPreferences(),
        tasteProfile: TasteProfile? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.defaultAddresses = defaultAddresses
        self.paymentMethods = paymentMethods
        self.preferences = preferences
        self.tasteProfile = tasteProfile
        self.createdAt = createdAt
    }
}

// MARK: - Request/Response Models
public struct OrderDraft: Codable {
    public var restaurantId: String
    public var items: [Order.OrderItem]
    public var deliveryAddress: Order.OrderAddresses.DeliveryAddress
    public var paymentMethod: Order.PaymentInfo.PaymentMethod
    public var couponCode: String?
    public var tip: Double
    public var specialInstructions: String?
    
    public init(
        restaurantId: String,
        items: [Order.OrderItem],
        deliveryAddress: Order.OrderAddresses.DeliveryAddress,
        paymentMethod: Order.PaymentInfo.PaymentMethod,
        couponCode: String? = nil,
        tip: Double = 0.0,
        specialInstructions: String? = nil
    ) {
        self.restaurantId = restaurantId
        self.items = items
        self.deliveryAddress = deliveryAddress
        self.paymentMethod = paymentMethod
        self.couponCode = couponCode
        self.tip = tip
        self.specialInstructions = specialInstructions
    }
}

public struct PricedOrder {
    public var draft: OrderDraft
    public var subtotal: Double
    public var deliveryFee: Double
    public var serviceFee: Double
    public var smallOrderFee: Double
    public var discount: Double
    public var total: Double
    public var etaMinutes: Int
    
    public init(
        draft: OrderDraft,
        subtotal: Double,
        deliveryFee: Double,
        serviceFee: Double,
        smallOrderFee: Double = 0.0,
        discount: Double = 0.0,
        total: Double,
        etaMinutes: Int
    ) {
        self.draft = draft
        self.subtotal = subtotal
        self.deliveryFee = deliveryFee
        self.serviceFee = serviceFee
        self.smallOrderFee = smallOrderFee
        self.discount = discount
        self.total = total
        self.etaMinutes = etaMinutes
    }
}

// (Removed duplicate Order definition present later in file)

// (Removed duplicate OrderDraft definition)

// MARK: - Recommendation Context
public struct RecContext: Codable {
    public var location: Coordinates
    public var timestamp: Date
    public var timeOfDay: TimeOfDay?
    public var weather: String?
    public var maxEtaMinutes: Int?
    public var priceBand: String?
    
    public enum TimeOfDay: String, Codable {
        case breakfast
        case lunch
        case dinner
        case late
    }
    
    public init(
        location: Coordinates,
        timestamp: Date = Date(),
        timeOfDay: TimeOfDay? = nil,
        weather: String? = nil,
        maxEtaMinutes: Int? = nil,
        priceBand: String? = nil
    ) {
        self.location = location
        self.timestamp = timestamp
        self.timeOfDay = timeOfDay
        self.weather = weather
        self.maxEtaMinutes = maxEtaMinutes
        self.priceBand = priceBand
    }
}

// MARK: - Promotion Models
public struct Promotion: Codable, Identifiable {
    @DocumentID public var id: String?
    public var title: String
    public var description: String
    public var imageUrl: String?
    public var type: PromotionType
    public var discount: DiscountInfo
    public var conditions: PromotionConditions
    public var validity: PromotionValidity
    public var targets: PromotionTargets
    public var usage: PromotionUsage
    public var status: PromotionStatus
    @ServerTimestamp public var createdAt: Date?
    @ServerTimestamp public var updatedAt: Date?
    
    public enum PromotionType: String, Codable {
        case discount = "discount"
        case freeDelivery = "free_delivery"
        case buyOneGetOne = "bogo"
        case firstOrder = "first_order"
        case loyaltyReward = "loyalty_reward"
        case flashSale = "flash_sale"
        case referral = "referral"
        case bundleDeal = "bundle_deal"
    }
    
    public enum PromotionStatus: String, Codable {
        case draft = "draft"
        case active = "active"
        case paused = "paused"
        case expired = "expired"
        case cancelled = "cancelled"
    }
    
    public struct DiscountInfo: Codable {
        public var type: DiscountType
        public var value: Double
        public var maxDiscount: Double?
        public var freeDelivery: Bool
        public var applyTo: DiscountTarget
        
        public enum DiscountType: String, Codable {
            case percentage = "percentage"
            case fixedAmount = "fixed_amount"
            case freeItem = "free_item"
        }
        
        public enum DiscountTarget: String, Codable {
            case subtotal = "subtotal"
            case deliveryFee = "delivery_fee"
            case serviceFee = "service_fee"
            case total = "total"
            case specificItems = "specific_items"
        }
        
        public init(type: DiscountType, value: Double, maxDiscount: Double? = nil, freeDelivery: Bool = false, applyTo: DiscountTarget = .subtotal) {
            self.type = type
            self.value = value
            self.maxDiscount = maxDiscount
            self.freeDelivery = freeDelivery
            self.applyTo = applyTo
        }
    }
    
    public struct PromotionConditions: Codable {
        public var minimumOrderValue: Double?
        public var maximumOrderValue: Double?
        public var eligibleRestaurants: [String]?
        public var eligibleMenuItems: [String]?
        public var excludedRestaurants: [String]?
        public var eligibleCuisineTypes: [String]?
        public var firstOrderOnly: Bool
        public var newCustomersOnly: Bool
        public var eligibleDays: [Int]? // 1-7 (Monday-Sunday)
        public var eligibleHours: Restaurant.TimeRange?
        public var eligibleCities: [String]?
        public var requiredPaymentMethods: [Order.PaymentInfo.PaymentMethod]?
        
        public init(
            minimumOrderValue: Double? = nil,
            maximumOrderValue: Double? = nil,
            eligibleRestaurants: [String]? = nil,
            eligibleMenuItems: [String]? = nil,
            excludedRestaurants: [String]? = nil,
            eligibleCuisineTypes: [String]? = nil,
            firstOrderOnly: Bool = false,
            newCustomersOnly: Bool = false,
            eligibleDays: [Int]? = nil,
            eligibleHours: Restaurant.TimeRange? = nil,
            eligibleCities: [String]? = nil,
            requiredPaymentMethods: [Order.PaymentInfo.PaymentMethod]? = nil
        ) {
            self.minimumOrderValue = minimumOrderValue
            self.maximumOrderValue = maximumOrderValue
            self.eligibleRestaurants = eligibleRestaurants
            self.eligibleMenuItems = eligibleMenuItems
            self.excludedRestaurants = excludedRestaurants
            self.eligibleCuisineTypes = eligibleCuisineTypes
            self.firstOrderOnly = firstOrderOnly
            self.newCustomersOnly = newCustomersOnly
            self.eligibleDays = eligibleDays
            self.eligibleHours = eligibleHours
            self.eligibleCities = eligibleCities
            self.requiredPaymentMethods = requiredPaymentMethods
        }
    }
    
    public struct PromotionValidity: Codable {
        public var startDate: Date
        public var endDate: Date
        public var timezone: String
        public var isActive: Bool
        
        public init(startDate: Date, endDate: Date, timezone: String = "Africa/Casablanca", isActive: Bool = true) {
            self.startDate = startDate
            self.endDate = endDate
            self.timezone = timezone
            self.isActive = isActive
        }
    }
    
    public struct PromotionTargets: Codable {
        public var customerSegments: [String]?
        public var specificCustomers: [String]?
        public var excludedCustomers: [String]?
        public var loyaltyTiers: [String]?
        
        public init(
            customerSegments: [String]? = nil,
            specificCustomers: [String]? = nil,
            excludedCustomers: [String]? = nil,
            loyaltyTiers: [String]? = nil
        ) {
            self.customerSegments = customerSegments
            self.specificCustomers = specificCustomers
            self.excludedCustomers = excludedCustomers
            self.loyaltyTiers = loyaltyTiers
        }
    }
    
    public struct PromotionUsage: Codable {
        public var totalUsageLimit: Int?
        public var perCustomerLimit: Int?
        public var currentUsageCount: Int
        public var remainingUses: Int?
        
        public init(totalUsageLimit: Int? = nil, perCustomerLimit: Int? = nil, currentUsageCount: Int = 0) {
            self.totalUsageLimit = totalUsageLimit
            self.perCustomerLimit = perCustomerLimit
            self.currentUsageCount = currentUsageCount
            self.remainingUses = totalUsageLimit.map { $0 - currentUsageCount }
        }
    }
    
    public init(
        id: String? = nil,
        title: String,
        description: String,
        imageUrl: String? = nil,
        type: PromotionType,
        discount: DiscountInfo,
        conditions: PromotionConditions = PromotionConditions(),
        validity: PromotionValidity,
        targets: PromotionTargets = PromotionTargets(),
        usage: PromotionUsage = PromotionUsage(),
        status: PromotionStatus = .active
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.imageUrl = imageUrl
        self.type = type
        self.discount = discount
        self.conditions = conditions
        self.validity = validity
        self.targets = targets
        self.usage = usage
        self.status = status
    }
}

// MARK: - Coupon Models
public struct Coupon: Codable, Identifiable {
    @DocumentID public var id: String?
    public var code: String
    public var title: String
    public var description: String
    public var promotionId: String
    public var assignedToCustomer: String?
    public var usageHistory: [CouponUsage]
    public var status: CouponStatus
    @ServerTimestamp public var createdAt: Date?
    @ServerTimestamp public var usedAt: Date?
    @ServerTimestamp public var expiredAt: Date?
    
    public enum CouponStatus: String, Codable {
        case active = "active"
        case used = "used"
        case expired = "expired"
        case cancelled = "cancelled"
    }
    
    public struct CouponUsage: Codable {
        public var orderId: String
        public var customerId: String
        public var discountApplied: Double
        @ServerTimestamp public var usedAt: Date?
        
        public init(orderId: String, customerId: String, discountApplied: Double, usedAt: Date? = nil) {
            self.orderId = orderId
            self.customerId = customerId
            self.discountApplied = discountApplied
            self.usedAt = usedAt
        }
    }
    
    public init(
        id: String? = nil,
        code: String,
        title: String,
        description: String,
        promotionId: String,
        assignedToCustomer: String? = nil,
        usageHistory: [CouponUsage] = [],
        status: CouponStatus = .active
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.description = description
        self.promotionId = promotionId
        self.assignedToCustomer = assignedToCustomer
        self.usageHistory = usageHistory
        self.status = status
    }
}

// MARK: - Customer Promotion Models
public struct CustomerPromotionEligibility: Codable {
    public var customerId: String
    public var eligiblePromotions: [String]
    public var usedPromotions: [String: Int]
    public var currentLoyaltyTier: String?
    public var totalOrderCount: Int
    public var firstOrderDate: Date?
    @ServerTimestamp public var lastUpdated: Date?
    
    public init(
        customerId: String,
        eligiblePromotions: [String] = [],
        usedPromotions: [String: Int] = [:],
        currentLoyaltyTier: String? = nil,
        totalOrderCount: Int = 0,
        firstOrderDate: Date? = nil
    ) {
        self.customerId = customerId
        self.eligiblePromotions = eligiblePromotions
        self.usedPromotions = usedPromotions
        self.currentLoyaltyTier = currentLoyaltyTier
        self.totalOrderCount = totalOrderCount
        self.firstOrderDate = firstOrderDate
    }
}

// MARK: - Promotion Validation Result
public struct PromotionValidationResult {
    public var isValid: Bool
    public var discountAmount: Double
    public var message: String
    public var appliedPromotion: Promotion?
    public var errors: [PromotionError]
    
    public enum PromotionError: String, Error {
        case promotionNotFound = "promotion_not_found"
        case promotionExpired = "promotion_expired"
        case promotionInactive = "promotion_inactive"
        case usageLimitExceeded = "usage_limit_exceeded"
        case minimumOrderNotMet = "minimum_order_not_met"
        case restaurantNotEligible = "restaurant_not_eligible"
        case customerNotEligible = "customer_not_eligible"
        case paymentMethodNotEligible = "payment_method_not_eligible"
        case timeNotEligible = "time_not_eligible"
        case alreadyApplied = "already_applied"
    }
    
    public init(
        isValid: Bool,
        discountAmount: Double = 0,
        message: String = "",
        appliedPromotion: Promotion? = nil,
        errors: [PromotionError] = []
    ) {
        self.isValid = isValid
        self.discountAmount = discountAmount
        self.message = message
        self.appliedPromotion = appliedPromotion
        self.errors = errors
    }
}

// MARK: - Dispatch Models
public struct DispatchRequest: Codable {
    public var orderId: String
    public var priority: DispatchPriority
    public var estimatedPreparationTime: TimeInterval
    public var pickupLocation: Coordinates
    public var dropoffLocation: Coordinates
    public var orderValue: Double
    public var paymentMethod: Order.PaymentInfo.PaymentMethod
    public var specialRequirements: [String]?
    public var customerTier: String?
    public var requestedAt: Date
    
    public enum DispatchPriority: String, Codable, CaseIterable {
        case low = "low"
        case normal = "normal"
        case high = "high"
        case urgent = "urgent"
        
        public var multiplier: Double {
            switch self {
            case .low: return 0.8
            case .normal: return 1.0
            case .high: return 1.3
            case .urgent: return 1.8
            }
        }
    }
    
    public init(
        orderId: String,
        priority: DispatchPriority = .normal,
        estimatedPreparationTime: TimeInterval,
        pickupLocation: Coordinates,
        dropoffLocation: Coordinates,
        orderValue: Double,
        paymentMethod: Order.PaymentInfo.PaymentMethod,
        specialRequirements: [String]? = nil,
        customerTier: String? = nil,
        requestedAt: Date = Date()
    ) {
        self.orderId = orderId
        self.priority = priority
        self.estimatedPreparationTime = estimatedPreparationTime
        self.pickupLocation = pickupLocation
        self.dropoffLocation = dropoffLocation
        self.orderValue = orderValue
        self.paymentMethod = paymentMethod
        self.specialRequirements = specialRequirements
        self.customerTier = customerTier
        self.requestedAt = requestedAt
    }
}

public struct CourierCandidate: Codable {
    public var courierId: String
    public var currentLocation: Coordinates
    public var isOnline: Bool
    public var currentOrderId: String?
    public var vehicleType: Courier.VehicleType
    public var rating: Double
    public var completedDeliveries: Int
    public var averageDeliveryTime: TimeInterval
    public var acceptanceRate: Double
    public var lastActive: Date
    public var workingZones: [String]
    public var preferredPaymentMethods: [Order.PaymentInfo.PaymentMethod]?
    public var maxConcurrentOrders: Int
    public var currentCapacity: CourierCapacity
    
    public struct CourierCapacity: Codable {
        public var maxItems: Int
        public var currentItems: Int
        public var maxWeight: Double // kg
        public var currentWeight: Double
        public var hasInsulatedBag: Bool
        public var canHandleCOD: Bool
        
        public init(
            maxItems: Int = 5,
            currentItems: Int = 0,
            maxWeight: Double = 15.0,
            currentWeight: Double = 0.0,
            hasInsulatedBag: Bool = true,
            canHandleCOD: Bool = true
        ) {
            self.maxItems = maxItems
            self.currentItems = currentItems
            self.maxWeight = maxWeight
            self.currentWeight = currentWeight
            self.hasInsulatedBag = hasInsulatedBag
            self.canHandleCOD = canHandleCOD
        }
    }
    
    public init(
        courierId: String,
        currentLocation: Coordinates,
        isOnline: Bool = true,
        currentOrderId: String? = nil,
        vehicleType: Courier.VehicleType,
        rating: Double,
        completedDeliveries: Int = 0,
        averageDeliveryTime: TimeInterval = 1800,
        acceptanceRate: Double = 0.9,
        lastActive: Date = Date(),
        workingZones: [String] = [],
        preferredPaymentMethods: [Order.PaymentInfo.PaymentMethod]? = nil,
        maxConcurrentOrders: Int = 1,
        currentCapacity: CourierCapacity = CourierCapacity()
    ) {
        self.courierId = courierId
        self.currentLocation = currentLocation
        self.isOnline = isOnline
        self.currentOrderId = currentOrderId
        self.vehicleType = vehicleType
        self.rating = rating
        self.completedDeliveries = completedDeliveries
        self.averageDeliveryTime = averageDeliveryTime
        self.acceptanceRate = acceptanceRate
        self.lastActive = lastActive
        self.workingZones = workingZones
        self.preferredPaymentMethods = preferredPaymentMethods
        self.maxConcurrentOrders = maxConcurrentOrders
        self.currentCapacity = currentCapacity
    }
}

public struct DispatchResult: Codable {
    public var orderId: String
    public var assignedCourierId: String?
    public var confidence: Double
    public var estimatedPickupTime: Date
    public var estimatedDeliveryTime: Date
    public var routeDistance: Double // km
    public var routeDuration: TimeInterval // seconds
    public var reason: String
    public var alternatives: [CourierAlternative]
    public var dispatchedAt: Date
    
    public struct CourierAlternative: Codable {
        public var courierId: String
        public var score: Double
        public var estimatedDeliveryTime: Date
        public var reason: String
        
        public init(courierId: String, score: Double, estimatedDeliveryTime: Date, reason: String) {
            self.courierId = courierId
            self.score = score
            self.estimatedDeliveryTime = estimatedDeliveryTime
            self.reason = reason
        }
    }
    
    public init(
        orderId: String,
        assignedCourierId: String? = nil,
        confidence: Double,
        estimatedPickupTime: Date,
        estimatedDeliveryTime: Date,
        routeDistance: Double,
        routeDuration: TimeInterval,
        reason: String,
        alternatives: [CourierAlternative] = [],
        dispatchedAt: Date = Date()
    ) {
        self.orderId = orderId
        self.assignedCourierId = assignedCourierId
        self.confidence = confidence
        self.estimatedPickupTime = estimatedPickupTime
        self.estimatedDeliveryTime = estimatedDeliveryTime
        self.routeDistance = routeDistance
        self.routeDuration = routeDuration
        self.reason = reason
        self.alternatives = alternatives
        self.dispatchedAt = dispatchedAt
    }
}

public struct DispatchMetrics: Codable {
    public var averageAssignmentTime: TimeInterval
    public var courierUtilization: Double
    public var averageDeliveryTime: TimeInterval
    public var customerSatisfactionScore: Double
    public var peakHourEfficiency: Double
    public var geographicCoverage: Double
    public var orderAcceptanceRate: Double
    public var multiOrderOptimization: Double
    
    public init(
        averageAssignmentTime: TimeInterval = 180,
        courierUtilization: Double = 0.75,
        averageDeliveryTime: TimeInterval = 1800,
        customerSatisfactionScore: Double = 4.5,
        peakHourEfficiency: Double = 0.85,
        geographicCoverage: Double = 0.9,
        orderAcceptanceRate: Double = 0.92,
        multiOrderOptimization: Double = 0.7
    ) {
        self.averageAssignmentTime = averageAssignmentTime
        self.courierUtilization = courierUtilization
        self.averageDeliveryTime = averageDeliveryTime
        self.customerSatisfactionScore = customerSatisfactionScore
        self.peakHourEfficiency = peakHourEfficiency
        self.geographicCoverage = geographicCoverage
        self.orderAcceptanceRate = orderAcceptanceRate
        self.multiOrderOptimization = multiOrderOptimization
    }
}

public struct ZonePerformance: Codable {
    public var zoneId: String
    public var zoneName: String
    public var boundaries: [Coordinates]
    public var activeCouriers: Int
    public var pendingOrders: Int
    public var averageWaitTime: TimeInterval
    public var demandLevel: DemandLevel
    public var surgeMultiplier: Double
    public var lastUpdated: Date
    
    public enum DemandLevel: String, Codable {
        case low = "low"
        case normal = "normal"
        case high = "high"
        case critical = "critical"
        
        public var color: String {
            switch self {
            case .low: return "#4CAF50"
            case .normal: return "#2196F3"
            case .high: return "#FF9800"
            case .critical: return "#F44336"
            }
        }
    }
    
    public init(
        zoneId: String,
        zoneName: String,
        boundaries: [Coordinates] = [],
        activeCouriers: Int = 0,
        pendingOrders: Int = 0,
        averageWaitTime: TimeInterval = 300,
        demandLevel: DemandLevel = .normal,
        surgeMultiplier: Double = 1.0,
        lastUpdated: Date = Date()
    ) {
        self.zoneId = zoneId
        self.zoneName = zoneName
        self.boundaries = boundaries
        self.activeCouriers = activeCouriers
        self.pendingOrders = pendingOrders
        self.averageWaitTime = averageWaitTime
        self.demandLevel = demandLevel
        self.surgeMultiplier = surgeMultiplier
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Real-time Tracking Models
public struct CourierLocation: Codable, Identifiable {
    public var id: String { courierId }
    public var courierId: String
    public var location: Coordinates
    public var heading: Double? // Compass direction (0-360 degrees)
    public var speed: Double? // km/h
    public var accuracy: Double? // meters
    public var timestamp: Date
    public var batteryLevel: Double?
    public var isOnline: Bool
    public var currentOrderIds: [String]
    
    public init(
        courierId: String,
        location: Coordinates,
        heading: Double? = nil,
        speed: Double? = nil,
        accuracy: Double? = nil,
        timestamp: Date = Date(),
        batteryLevel: Double? = nil,
        isOnline: Bool = true,
        currentOrderIds: [String] = []
    ) {
        self.courierId = courierId
        self.location = location
        self.heading = heading
        self.speed = speed
        self.accuracy = accuracy
        self.timestamp = timestamp
        self.batteryLevel = batteryLevel
        self.isOnline = isOnline
        self.currentOrderIds = currentOrderIds
    }
}

public struct DeliveryTracking: Codable, Identifiable {
    public var id: String { orderId }
    public var orderId: String
    public var customerId: String?
    public var courierId: String?
    public var status: DeliveryStatus
    public var progressValue: Double
    public var currentLocation: Coordinates?
    public var route: DeliveryRoute?
    public var estimatedArrival: Date?
    public var estimatedDeliveryTime: Date?
    public var actualPickupTime: Date?
    public var actualDeliveryTime: Date?
    public var deliveryProof: DeliveryProof?
    public var customerUpdates: [CustomerUpdate]
    public var metrics: TrackingMetrics?
    public var lastUpdated: Date
    
    public enum DeliveryStatus: String, Codable, CaseIterable {
        case orderPlaced = "order_placed"
        case restaurantConfirmed = "restaurant_confirmed"
        case preparing = "preparing"
        case readyForPickup = "ready_for_pickup"
        case courierAssigned = "courier_assigned"
        case courierEnRoute = "courier_en_route"
        case pickedUp = "picked_up"
        case outForDelivery = "out_for_delivery"
        case enRouteToCustomer = "en_route_to_customer"
        case arrivedAtCustomer = "arrived_at_customer"
        case orderDelivered = "order_delivered"
        case delivered = "delivered"
        case orderCancelled = "order_cancelled"
        case cancelled = "cancelled"
        
        public var displayName: String {
            switch self {
            case .orderPlaced: return "Order Placed"
            case .restaurantConfirmed: return "Restaurant Confirmed"
            case .preparing: return "Preparing"
            case .readyForPickup: return "Ready for Pickup"
            case .courierAssigned: return "Courier Assigned"
            case .courierEnRoute: return "Courier En Route"
            case .pickedUp: return "Picked Up"
            case .outForDelivery, .enRouteToCustomer: return "On the Way"
            case .arrivedAtCustomer: return "Courier Has Arrived"
            case .orderDelivered, .delivered: return "Order Delivered"
            case .orderCancelled, .cancelled: return "Order Cancelled"
            }
        }
        
        public var defaultProgress: Double {
            switch self {
            case .orderPlaced: return 0.1
            case .restaurantConfirmed: return 0.2
            case .preparing: return 0.4
            case .readyForPickup: return 0.5
            case .courierAssigned: return 0.6
            case .courierEnRoute: return 0.7
            case .pickedUp: return 0.8
            case .outForDelivery, .enRouteToCustomer: return 0.9
            case .arrivedAtCustomer: return 0.95
            case .orderDelivered, .delivered: return 1.0
            case .orderCancelled, .cancelled: return 0.0
            }
        }
    }
    
    public init(
        orderId: String,
        customerId: String? = nil,
        courierId: String? = nil,
        status: DeliveryStatus = .orderPlaced,
        progressValue: Double? = nil,
        currentLocation: Coordinates? = nil,
        route: DeliveryRoute? = nil,
        estimatedArrival: Date? = nil,
        estimatedDeliveryTime: Date? = nil,
        actualPickupTime: Date? = nil,
        actualDeliveryTime: Date? = nil,
        deliveryProof: DeliveryProof? = nil,
        customerUpdates: [CustomerUpdate] = [],
        metrics: TrackingMetrics? = nil,
        lastUpdated: Date = Date()
    ) {
        self.orderId = orderId
        self.customerId = customerId
        self.courierId = courierId
        self.status = status
        self.progressValue = progressValue ?? status.defaultProgress
        self.currentLocation = currentLocation
        self.route = route
        self.estimatedArrival = estimatedArrival
        self.estimatedDeliveryTime = estimatedDeliveryTime
        self.actualPickupTime = actualPickupTime
        self.actualDeliveryTime = actualDeliveryTime
        self.deliveryProof = deliveryProof
        self.customerUpdates = customerUpdates
        self.metrics = metrics
        self.lastUpdated = lastUpdated
    }
}

public struct DeliveryRoute: Codable {
    public var pickupLocation: Coordinates
    public var dropoffLocation: Coordinates
    public var waypoints: [Coordinates]
    public var routePolyline: String? // Encoded polyline for map display
    public var totalDistance: Double // km
    public var estimatedDuration: TimeInterval // seconds
    public var actualDistance: Double? // km (tracked during delivery)
    public var actualDuration: TimeInterval? // seconds
    public var trafficConditions: TrafficCondition
    
    public enum TrafficCondition: String, Codable {
        case light = "light"
        case moderate = "moderate"
        case heavy = "heavy"
        case severe = "severe"
        
        public var delayMultiplier: Double {
            switch self {
            case .light: return 1.0
            case .moderate: return 1.2
            case .heavy: return 1.5
            case .severe: return 2.0
            }
        }
        
        public var color: String {
            switch self {
            case .light: return "#4CAF50"
            case .moderate: return "#FF9800"
            case .heavy: return "#F44336"
            case .severe: return "#9C27B0"
            }
        }
    }
    
    public init(
        pickupLocation: Coordinates,
        dropoffLocation: Coordinates,
        waypoints: [Coordinates] = [],
        routePolyline: String? = nil,
        totalDistance: Double,
        estimatedDuration: TimeInterval,
        actualDistance: Double? = nil,
        actualDuration: TimeInterval? = nil,
        trafficConditions: TrafficCondition = .moderate
    ) {
        self.pickupLocation = pickupLocation
        self.dropoffLocation = dropoffLocation
        self.waypoints = waypoints
        self.routePolyline = routePolyline
        self.totalDistance = totalDistance
        self.estimatedDuration = estimatedDuration
        self.actualDistance = actualDistance
        self.actualDuration = actualDuration
        self.trafficConditions = trafficConditions
    }
}

public struct DeliveryProof: Codable {
    public var photoUrl: String?
    public var signatureData: String?
    public var timestamp: Date
    public var location: Coordinates
    public var verificationMethod: VerificationMethod
    public var notes: String?
    
    public enum VerificationMethod: String, Codable {
        case photo = "photo"
        case signature = "signature"
        case handoff = "handoff"
        case contactless = "contactless"
        case otp = "otp"
        
        public var displayName: String {
            switch self {
            case .photo: return "Photo Verification"
            case .signature: return "Digital Signature"
            case .handoff: return "In-Person Handoff"
            case .contactless: return "Contactless Delivery"
            case .otp: return "OTP Verification"
            }
        }
    }
    
    public init(
        photoUrl: String? = nil,
        signatureData: String? = nil,
        timestamp: Date = Date(),
        location: Coordinates,
        verificationMethod: VerificationMethod,
        notes: String? = nil
    ) {
        self.photoUrl = photoUrl
        self.signatureData = signatureData
        self.timestamp = timestamp
        self.location = location
        self.verificationMethod = verificationMethod
        self.notes = notes
    }
}

public struct CustomerUpdate: Codable, Identifiable {
    public var id: String
    public var orderId: String
    public var message: String
    public var timestamp: Date
    public var type: UpdateType
    public var estimatedTime: Date?
    public var estimatedArrival: Date?
    public var location: Coordinates?
    
    public enum UpdateType: String, Codable {
        case statusChange = "status_change"
        case statusUpdate = "status_update"
        case locationUpdate = "location_update"
        case delayNotification = "delay_notification"
        case arrivalSoon = "arrival_soon"
        case courierMessage = "courier_message"
        case deliveryAttempt = "delivery_attempt"
        
        public var icon: String {
            switch self {
            case .statusChange: return "arrow.right.circle"
            case .statusUpdate: return "arrow.right.circle"
            case .delayNotification: return "clock.badge.exclamationmark"
            case .arrivalSoon: return "location.circle"
            case .locationUpdate: return "location.circle"
            case .courierMessage: return "message.circle"
            case .deliveryAttempt: return "bell.circle"
            }
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        orderId: String,
        message: String,
        timestamp: Date = Date(),
        type: UpdateType,
        estimatedTime: Date? = nil,
        estimatedArrival: Date? = nil,
        location: Coordinates? = nil
    ) {
        self.id = id
        self.orderId = orderId
        self.message = message
        self.timestamp = timestamp
        self.type = type
        self.estimatedTime = estimatedTime
        self.estimatedArrival = estimatedArrival
        self.location = location
    }
}

public struct TrackingMetrics: Codable {
    public var totalActiveDeliveries: Int
    public var averageDeliveryTime: TimeInterval
    public var onTimeDeliveryRate: Double
    public var customerSatisfactionScore: Double
    public var averageDistanceAccuracy: Double
    public var routeEfficiencyScore: Double
    public var lastUpdated: Date
    
    public init(
        totalActiveDeliveries: Int = 0,
        averageDeliveryTime: TimeInterval = 1800,
        onTimeDeliveryRate: Double = 0.85,
        customerSatisfactionScore: Double = 4.3,
        averageDistanceAccuracy: Double = 0.95,
        routeEfficiencyScore: Double = 0.82,
        lastUpdated: Date = Date()
    ) {
        self.totalActiveDeliveries = totalActiveDeliveries
        self.averageDeliveryTime = averageDeliveryTime
        self.onTimeDeliveryRate = onTimeDeliveryRate
        self.customerSatisfactionScore = customerSatisfactionScore
        self.averageDistanceAccuracy = averageDistanceAccuracy
        self.routeEfficiencyScore = routeEfficiencyScore
        self.lastUpdated = lastUpdated
    }
}

public struct GeofenceEvent: Codable {
    public var eventId: String
    public var courierId: String
    public var orderId: String
    public var geofenceType: GeofenceType
    public var eventType: GeofenceEventType
    public var location: Coordinates
    public var timestamp: Date
    public var accuracy: Double?
    
    public enum GeofenceType: String, Codable {
        case restaurant = "restaurant"
        case customer = "customer"
        case zone = "zone"
        case depot = "depot"
    }
    
    public enum GeofenceEventType: String, Codable {
        case enter = "enter"
        case exit = "exit"
        case dwell = "dwell"
        case restaurantApproaching = "restaurant_approaching"
        case restaurantArrived = "restaurant_arrived"
        case restaurantDeparted = "restaurant_departed"
        case customerApproaching = "customer_approaching"
        case customerArrived = "customer_arrived"
        case deliveryCompleted = "delivery_completed"
    }
    
    public init(
        eventId: String = UUID().uuidString,
        courierId: String,
        orderId: String,
        geofenceType: GeofenceType,
        eventType: GeofenceEventType,
        location: Coordinates,
        timestamp: Date = Date(),
        accuracy: Double? = nil
    ) {
        self.eventId = eventId
        self.courierId = courierId
        self.orderId = orderId
        self.geofenceType = geofenceType
        self.eventType = eventType
        self.location = location
        self.timestamp = timestamp
        self.accuracy = accuracy
    }
}

// MARK: - Error Types
public enum FoodDeliveryError: Error, LocalizedError {
    case restaurantNotFound
    case menuItemNotFound
    case orderNotFound
    case courierNotFound
    case invalidOrderStatus
    case paymentFailed
    case outOfDeliveryZone
    case restaurantClosed
    case insufficientFunds
    case networkError(String)
    
    public var errorDescription: String? {
        switch self {
        case .restaurantNotFound:
            return "Restaurant not found"
        case .menuItemNotFound:
            return "Menu item not found"
        case .orderNotFound:
            return "Order not found"
        case .courierNotFound:
            return "Courier not found"
        case .invalidOrderStatus:
            return "Invalid order status"
        case .paymentFailed:
            return "Payment failed"
        case .outOfDeliveryZone:
            return "Address is outside delivery zone"
        case .restaurantClosed:
            return "Restaurant is currently closed"
        case .insufficientFunds:
            return "Insufficient funds"
        case .networkError(let message):
            return message
        }
    }
}