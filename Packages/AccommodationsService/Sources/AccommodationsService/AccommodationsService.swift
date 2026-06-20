import Foundation
import Combine
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

public protocol AccommodationsServiceProtocol {
    func search(_ request: SearchRequest) -> AnyPublisher<SearchResponse, Error>
    func getRecommendations(context: RecommendationContext) -> AnyPublisher<RecommendationResponse, Error>
    func getPropertyDetails(_ id: String, params: PropertyDetailsParams?) -> AnyPublisher<PropertyDetailsResponse, Error>
    func createBooking(_ request: BookingRequest) -> AnyPublisher<Booking, Error>
    func importBooking(_ request: ImportRequest) -> AnyPublisher<ImportResult, Error>
    func interpretVoice(_ request: VoiceInterpretRequest) -> AnyPublisher<VoiceInterpretResponse, Error>
    func getUserBookings() -> AnyPublisher<[Booking], Error>
    func cancelBooking(_ id: String, reason: String?) -> AnyPublisher<CancelBookingResult, Error>
    
    // Saved properties
    func getSavedProperties() -> AnyPublisher<SavedPropertiesResponse, Error>
    func addToFavorites(_ propertyId: String) -> AnyPublisher<AccommodationProperty, Error>
    func removeFromFavorites(_ propertyId: String) -> AnyPublisher<Void, Error>
    func createShortlist(_ request: ShortlistUpdateRequest) -> AnyPublisher<Shortlist, Error>
    func updateShortlist(_ id: String, request: ShortlistUpdateRequest) -> AnyPublisher<Shortlist, Error>
    func deleteShortlist(_ id: String) -> AnyPublisher<Void, Error>
    func clearRecentlyViewed() -> AnyPublisher<Void, Error>
    
    // Geocoding
    func autocompleteDestinations(_ query: String, userLocation: CLLocationCoordinate2D?) -> AnyPublisher<[AutocompleteResult], Error>
    func geocodeAddress(_ address: String) -> AnyPublisher<[GeocodeResult], Error>
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) -> AnyPublisher<String, Error>
}

public final class AccommodationsService: AccommodationsServiceProtocol {
    private let networkManager: NetworkManager
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    public init(baseURL: String = "https://api.liive.app") {
        self.networkManager = NetworkManager(baseURL: baseURL)
    }
    
    public func search(_ request: SearchRequest) -> AnyPublisher<SearchResponse, Error> {
        var queryItems: [URLQueryItem] = []
        
        // Build query parameters
        switch request.location {
        case .coordinates(let lat, let lng):
            queryItems.append(URLQueryItem(name: "lat", value: "\(lat)"))
            queryItems.append(URLQueryItem(name: "lng", value: "\(lng)"))
        case .placeId(let placeId):
            queryItems.append(URLQueryItem(name: "placeId", value: placeId))
        case .address(let address):
            queryItems.append(URLQueryItem(name: "address", value: address))
        }
        
        // Date range
        let formatter = ISO8601DateFormatter()
        queryItems.append(URLQueryItem(name: "checkIn", value: formatter.string(from: request.dateRange.startDate)))
        queryItems.append(URLQueryItem(name: "checkOut", value: formatter.string(from: request.dateRange.endDate)))
        
        // Guests
        queryItems.append(URLQueryItem(name: "adults", value: "\(request.guests.adults)"))
        queryItems.append(URLQueryItem(name: "children", value: "\(request.guests.children)"))
        queryItems.append(URLQueryItem(name: "rooms", value: "\(request.guests.rooms)"))
        
        // Filters
        if let filters = request.filters {
            if let budgetMin = filters.budgetMin {
                queryItems.append(URLQueryItem(name: "budgetMin", value: "\(budgetMin)"))
            }
            if let budgetMax = filters.budgetMax {
                queryItems.append(URLQueryItem(name: "budgetMax", value: "\(budgetMax)"))
            }
            if let rating = filters.rating {
                queryItems.append(URLQueryItem(name: "rating", value: "\(rating)"))
            }
            if let amenities = filters.amenities {
                queryItems.append(URLQueryItem(name: "amenities", value: amenities.joined(separator: ",")))
            }
            if let types = filters.types {
                queryItems.append(URLQueryItem(name: "types", value: types.map { $0.rawValue }.joined(separator: ",")))
            }
            if let cancellable = filters.cancellable {
                queryItems.append(URLQueryItem(name: "cancellable", value: "\(cancellable)"))
            }
        }
        
        // Sort
        if let sortBy = request.sortBy {
            queryItems.append(URLQueryItem(name: "sortBy", value: sortBy.rawValue))
        }
        
        // Pagination
        if let pageToken = request.pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        
        return networkManager.request(
            endpoint: "accommodations/search",
            method: .GET,
            queryItems: queryItems
        )
    }
    
    public func getRecommendations(context: RecommendationContext) -> AnyPublisher<RecommendationResponse, Error> {
        return networkManager.request(
            endpoint: "accommodations/recommendations",
            method: .POST,
            body: context,
            requiresAuth: true
        )
    }
    
    public func getPropertyDetails(_ id: String, params: PropertyDetailsParams?) -> AnyPublisher<PropertyDetailsResponse, Error> {
        var queryItems: [URLQueryItem] = []
        
        if let params = params {
            let formatter = ISO8601DateFormatter()
            if let checkIn = params.checkIn {
                queryItems.append(URLQueryItem(name: "checkIn", value: formatter.string(from: checkIn)))
            }
            if let checkOut = params.checkOut {
                queryItems.append(URLQueryItem(name: "checkOut", value: formatter.string(from: checkOut)))
            }
            if let guests = params.guests {
                queryItems.append(URLQueryItem(name: "adults", value: "\(guests.adults)"))
                queryItems.append(URLQueryItem(name: "children", value: "\(guests.children)"))
            }
            if let currency = params.currency {
                queryItems.append(URLQueryItem(name: "currency", value: currency))
            }
        }
        
        return networkManager.request(
            endpoint: "accommodations/properties/\(id)",
            method: .GET,
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }
    
    public func createBooking(_ request: BookingRequest) -> AnyPublisher<Booking, Error> {
        return networkManager.request(
            endpoint: "accommodations/book",
            method: .POST,
            body: request,
            requiresAuth: true
        )
    }
    
    public func importBooking(_ request: ImportRequest) -> AnyPublisher<ImportResult, Error> {
        return networkManager.request(
            endpoint: "accommodations/import",
            method: .POST,
            body: request,
            requiresAuth: true
        )
    }
    
    public func interpretVoice(_ request: VoiceInterpretRequest) -> AnyPublisher<VoiceInterpretResponse, Error> {
        return networkManager.request(
            endpoint: "accommodations/voice/interpret",
            method: .POST,
            body: request
        )
    }
    
    public func getUserBookings() -> AnyPublisher<[Booking], Error> {
        return networkManager.request(
            endpoint: "accommodations/bookings",
            method: .GET,
            requiresAuth: true
        )
    }
    
    public func cancelBooking(_ id: String, reason: String?) -> AnyPublisher<CancelBookingResult, Error> {
        let body = reason.map { ["reason": $0] } ?? [:]
        
        return networkManager.request(
            endpoint: "accommodations/bookings/\(id)/cancel",
            method: .POST,
            body: body,
            requiresAuth: true
        )
    }
    
    // MARK: - Saved Properties
    
    public func getSavedProperties() -> AnyPublisher<SavedPropertiesResponse, Error> {
        return networkManager.request(
            endpoint: "accommodations/saved",
            method: .GET,
            requiresAuth: true
        )
    }
    
    public func addToFavorites(_ propertyId: String) -> AnyPublisher<AccommodationProperty, Error> {
        let body = ["propertyId": propertyId]
        
        return networkManager.request(
            endpoint: "accommodations/saved/favorites",
            method: .POST,
            body: body,
            requiresAuth: true
        )
    }
    
    public func removeFromFavorites(_ propertyId: String) -> AnyPublisher<Void, Error> {
        return networkManager.requestVoid(
            endpoint: "accommodations/saved/favorites/\(propertyId)",
            method: .DELETE,
            requiresAuth: true
        )
    }
    
    public func createShortlist(_ request: ShortlistUpdateRequest) -> AnyPublisher<Shortlist, Error> {
        return networkManager.request(
            endpoint: "accommodations/saved/shortlists",
            method: .POST,
            body: request,
            requiresAuth: true
        )
    }
    
    public func updateShortlist(_ id: String, request: ShortlistUpdateRequest) -> AnyPublisher<Shortlist, Error> {
        return networkManager.request(
            endpoint: "accommodations/saved/shortlists/\(id)",
            method: .PATCH,
            body: request,
            requiresAuth: true
        )
    }
    
    public func deleteShortlist(_ id: String) -> AnyPublisher<Void, Error> {
        return networkManager.requestVoid(
            endpoint: "accommodations/saved/shortlists/\(id)",
            method: .DELETE,
            requiresAuth: true
        )
    }
    
    public func clearRecentlyViewed() -> AnyPublisher<Void, Error> {
        return networkManager.requestVoid(
            endpoint: "accommodations/saved/recent",
            method: .DELETE,
            requiresAuth: true
        )
    }
    
    // MARK: - Geocoding
    
    public func autocompleteDestinations(_ query: String, userLocation: CLLocationCoordinate2D?) -> AnyPublisher<[AutocompleteResult], Error> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "query", value: query)
        ]
        
        if let location = userLocation {
            queryItems.append(URLQueryItem(name: "lat", value: "\(location.latitude)"))
            queryItems.append(URLQueryItem(name: "lng", value: "\(location.longitude)"))
        }
        
        return networkManager.request(
            endpoint: "accommodations/places/autocomplete",
            method: .GET,
            queryItems: queryItems
        )
        .map { (response: AutocompleteResponse) in response.results }
        .eraseToAnyPublisher()
    }
    
    public func geocodeAddress(_ address: String) -> AnyPublisher<[GeocodeResult], Error> {
        let body = ["address": address]
        
        return networkManager.request(
            endpoint: "accommodations/places/geocode",
            method: .POST,
            body: body
        )
        .map { (response: GeocodeResponse) in response.results }
        .eraseToAnyPublisher()
    }
    
    public func reverseGeocode(_ coordinate: CLLocationCoordinate2D) -> AnyPublisher<String, Error> {
        let body = [
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude
        ]
        
        return networkManager.request(
            endpoint: "accommodations/places/reverse-geocode",
            method: .POST,
            body: body
        )
        .map { (response: ReverseGeocodeResponse) in 
            response.results.first?.address ?? "Unknown location"
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Supporting Types

public struct PropertyDetailsParams: Codable {
    public let checkIn: Date?
    public let checkOut: Date?
    public let guests: GuestConfiguration?
    public let currency: String?
    
    public init(
        checkIn: Date? = nil,
        checkOut: Date? = nil,
        guests: GuestConfiguration? = nil,
        currency: String? = nil
    ) {
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.guests = guests
        self.currency = currency
    }
}

public struct PropertyDetailsResponse: Codable {
    public let property: AccommodationProperty
    public let roomTypes: [RoomType]
    public let ratePlans: [RatePlan]
    public let availability: [Availability]
    
    public init(
        property: AccommodationProperty,
        roomTypes: [RoomType],
        ratePlans: [RatePlan],
        availability: [Availability]
    ) {
        self.property = property
        self.roomTypes = roomTypes
        self.ratePlans = ratePlans
        self.availability = availability
    }
}

public struct BookingRequest: Codable {
    public let propertyId: String
    public let roomTypeId: String
    public let ratePlanId: String
    public let dateRange: DateRange
    public let guests: [Guest]
    public let paymentMethodId: String
    public let specialRequests: String?
    
    public init(
        propertyId: String,
        roomTypeId: String,
        ratePlanId: String,
        dateRange: DateRange,
        guests: [Guest],
        paymentMethodId: String,
        specialRequests: String? = nil
    ) {
        self.propertyId = propertyId
        self.roomTypeId = roomTypeId
        self.ratePlanId = ratePlanId
        self.dateRange = dateRange
        self.guests = guests
        self.paymentMethodId = paymentMethodId
        self.specialRequests = specialRequests
    }
}

public struct ImportRequest: Codable {
    public let url: String?
    public let provider: String?
    public let confirmationCode: String?
    public let lastName: String?
    
    public init(
        url: String? = nil,
        provider: String? = nil,
        confirmationCode: String? = nil,
        lastName: String? = nil
    ) {
        self.url = url
        self.provider = provider
        self.confirmationCode = confirmationCode
        self.lastName = lastName
    }
}

public struct ImportResult: Codable {
    public let importId: String
    public let success: Bool
    public let booking: Booking?
    public let error: String?
    public let deepLink: String?
    
    public init(
        importId: String,
        success: Bool,
        booking: Booking? = nil,
        error: String? = nil,
        deepLink: String? = nil
    ) {
        self.importId = importId
        self.success = success
        self.booking = booking
        self.error = error
        self.deepLink = deepLink
    }
}

public struct VoiceInterpretRequest: Codable {
    public let transcript: String
    public let audioRef: String?
    public let context: SearchContext?
    
    public init(
        transcript: String,
        audioRef: String? = nil,
        context: SearchContext? = nil
    ) {
        self.transcript = transcript
        self.audioRef = audioRef
        self.context = context
    }
}

public struct SearchContext: Codable {
    public let previousSearch: SearchRequest?
    public let sessionId: String?
    public let userId: String?
    
    public init(
        previousSearch: SearchRequest? = nil,
        sessionId: String? = nil,
        userId: String? = nil
    ) {
        self.previousSearch = previousSearch
        self.sessionId = sessionId
        self.userId = userId
    }
}

public struct VoiceInterpretResponse: Codable {
    public let intent: SearchIntent
    public let normalizedParams: SearchRequest
    public let nextPrompt: String?
    public let confidence: Double
    
    public init(
        intent: SearchIntent,
        normalizedParams: SearchRequest,
        nextPrompt: String? = nil,
        confidence: Double
    ) {
        self.intent = intent
        self.normalizedParams = normalizedParams
        self.nextPrompt = nextPrompt
        self.confidence = confidence
    }
}

public struct SearchIntent: Codable {
    public let type: IntentType
    public let entities: [String: AnyCodable]
    
    public init(type: IntentType, entities: [String: AnyCodable]) {
        self.type = type
        self.entities = entities
    }
}

public enum IntentType: String, Codable {
    case search = "SEARCH"
    case filter = "FILTER"
    case sort = "SORT"
    case book = "BOOK"
    case details = "DETAILS"
    case help = "HELP"
    case cancel = "CANCEL"
}

public struct CancelBookingResult: Codable {
    public let success: Bool
    public let cancellationId: String?
    public let refundAmount: Decimal?
    public let cancellationFee: Decimal?
    public let message: String?
    
    public init(
        success: Bool,
        cancellationId: String? = nil,
        refundAmount: Decimal? = nil,
        cancellationFee: Decimal? = nil,
        message: String? = nil
    ) {
        self.success = success
        self.cancellationId = cancellationId
        self.refundAmount = refundAmount
        self.cancellationFee = cancellationFee
        self.message = message
    }
}

// Helper for encoding/decoding Any values
public struct AnyCodable: Codable {
    public let value: Any
    
    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }
}

extension AnyCodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.init(())
        } else if let bool = try? container.decode(Bool.self) {
            self.init(bool)
        } else if let int = try? container.decode(Int.self) {
            self.init(int)
        } else if let double = try? container.decode(Double.self) {
            self.init(double)
        } else if let string = try? container.decode(String.self) {
            self.init(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self.init(array.map { $0.value })
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.init(dictionary.mapValues { $0.value })
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map(AnyCodable.init))
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues(AnyCodable.init))
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

// MARK: - Geocoding Models

public struct AutocompleteResult: Codable {
    public let id: String
    public let placeName: String
    public let coordinates: CLLocationCoordinate2D?
    public let context: GeocodeContext
    
    public init(id: String, placeName: String, coordinates: CLLocationCoordinate2D?, context: GeocodeContext) {
        self.id = id
        self.placeName = placeName
        self.coordinates = coordinates
        self.context = context
    }
}

public struct GeocodeResult: Codable {
    public let placeName: String
    public let coordinates: CLLocationCoordinate2D
    public let context: GeocodeContext
    
    public init(placeName: String, coordinates: CLLocationCoordinate2D, context: GeocodeContext) {
        self.placeName = placeName
        self.coordinates = coordinates
        self.context = context
    }
}

public struct ReverseGeocodeResult: Codable {
    public let address: String
    public let coordinates: CLLocationCoordinate2D
    public let context: GeocodeContext
    
    public init(address: String, coordinates: CLLocationCoordinate2D, context: GeocodeContext) {
        self.address = address
        self.coordinates = coordinates
        self.context = context
    }
}

public struct GeocodeContext: Codable {
    public let address: String?
    public let neighborhood: String?
    public let locality: String?
    public let region: String?
    public let country: String?
    public let postcode: String?
    
    public init(
        address: String? = nil,
        neighborhood: String? = nil,
        locality: String? = nil,
        region: String? = nil,
        country: String? = nil,
        postcode: String? = nil
    ) {
        self.address = address
        self.neighborhood = neighborhood
        self.locality = locality
        self.region = region
        self.country = country
        self.postcode = postcode
    }
}

public struct AutocompleteResponse: Codable {
    public let query: String
    public let results: [AutocompleteResult]
    public let metadata: ResponseMetadata
    
    public init(query: String, results: [AutocompleteResult], metadata: ResponseMetadata) {
        self.query = query
        self.results = results
        self.metadata = metadata
    }
}

public struct GeocodeResponse: Codable {
    public let address: String
    public let results: [GeocodeResult]
    public let metadata: ResponseMetadata
    
    public init(address: String, results: [GeocodeResult], metadata: ResponseMetadata) {
        self.address = address
        self.results = results
        self.metadata = metadata
    }
}

public struct ReverseGeocodeResponse: Codable {
    public let coordinates: CLLocationCoordinate2D
    public let results: [ReverseGeocodeResult]
    public let metadata: ResponseMetadata
    
    public init(coordinates: CLLocationCoordinate2D, results: [ReverseGeocodeResult], metadata: ResponseMetadata) {
        self.coordinates = coordinates
        self.results = results
        self.metadata = metadata
    }
}

public struct ResponseMetadata: Codable {
    public let count: Int
    public let timestamp: String
    
    public init(count: Int, timestamp: String) {
        self.count = count
        self.timestamp = timestamp
    }
}

// (CLLocationCoordinate2D Codable moved to models. Avoid duplicate conformances.)