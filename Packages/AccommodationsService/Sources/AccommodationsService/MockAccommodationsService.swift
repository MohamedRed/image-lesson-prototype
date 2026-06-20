import Foundation
import Combine
import CoreLocation

public class MockAccommodationsService: AccommodationsServiceProtocol {
    public static let shared = MockAccommodationsService()
    
    private var cancellables = Set<AnyCancellable>()
    private var savedProperties: [String] = []
    private var shortlists: [Shortlist] = []
    private var recentlyViewed: [String] = []
    
    public init() {}
    
    // MARK: - Search
    
    public func search(_ request: SearchRequest) -> AnyPublisher<SearchResponse, Error> {
        return Future<SearchResponse, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                let properties = Self.mockProperties.filter { property in
                    // Simple location filtering
                    switch request.location {
                    case .coordinates(let lat, let lng):
                        let distance = self.distance(from: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                                                   to: property.coordinates)
                        return distance < 50000 // 50km radius
                    case .address(let address):
                        return property.address.city.lowercased().contains(address.lowercased()) ||
                               property.address.formattedAddress.lowercased().contains(address.lowercased())
                    case .placeId(_):
                        return true // Mock: return all for place ID
                    }
                }
                
                // Apply filters
                let filteredProperties = properties.filter { property in
                    if let filters = request.filters {
                        if let budgetMax = filters.budgetMax,
                           let priceRange = property.priceRange,
                           priceRange.min > budgetMax {
                            return false
                        }
                        
                        if let budgetMin = filters.budgetMin,
                           let priceRange = property.priceRange,
                           priceRange.max < budgetMin {
                            return false
                        }
                        
                        if let rating = filters.rating,
                           let propertyRating = property.rating,
                           propertyRating < rating {
                            return false
                        }
                        
                        if let types = filters.types,
                           !types.contains(property.type) {
                            return false
                        }
                        
                        if let amenities = filters.amenities {
                            let hasAllAmenities = amenities.allSatisfy { amenity in
                                property.amenities.contains(amenity)
                            }
                            if !hasAllAmenities {
                                return false
                            }
                        }
                    }
                    return true
                }
                
                // Create availability summaries
                let availability = Dictionary(uniqueKeysWithValues: filteredProperties.map { property in
                    (property.id, AvailabilitySummary(
                        propertyId: property.id,
                        isAvailable: Bool.random(),
                        lowestPrice: property.priceRange?.min ?? Decimal(100),
                        currency: property.priceRange?.currency ?? "USD",
                        roomsAvailable: Int.random(in: 1...5)
                    ))
                })
                
                let response = SearchResponse(
                    properties: Array(filteredProperties.prefix(20)),
                    availability: availability,
                    totalResults: filteredProperties.count,
                    pageToken: nil,
                    searchId: UUID().uuidString,
                    cacheMetadata: CacheMetadata(cached: false)
                )
                
                promise(.success(response))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getRecommendations(context: RecommendationContext) -> AnyPublisher<RecommendationResponse, Error> {
        return Future<RecommendationResponse, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                let recommendations = Self.mockProperties.prefix(5).map { property in
                    RecommendedProperty(
                        property: property,
                        score: Double.random(in: 0.7...1.0),
                        explanation: "Matches your preferences for \(property.type.displayName.lowercased()) accommodations",
                        matchReasons: ["High rating", "Great location", "Excellent amenities"]
                    )
                }
                
                let response = RecommendationResponse(
                    recommendations: Array(recommendations),
                    explanations: ["algorithm": "Collaborative filtering with location proximity"]
                )
                
                promise(.success(response))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getPropertyDetails(_ id: String, params: PropertyDetailsParams?) -> AnyPublisher<PropertyDetailsResponse, Error> {
        return Future<PropertyDetailsResponse, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                guard let property = Self.mockProperties.first(where: { $0.id == id }) else {
                    promise(.failure(MockError.propertyNotFound))
                    return
                }
                
                let response = PropertyDetailsResponse(
                    property: property,
                    roomTypes: Self.mockRoomTypes,
                    ratePlans: Self.mockRatePlans,
                    availability: Self.mockAvailability
                )
                
                promise(.success(response))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Booking
    
    public func createBooking(_ request: BookingRequest) -> AnyPublisher<Booking, Error> {
        return Future<Booking, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
                guard let property = Self.mockProperties.first(where: { $0.id == request.propertyId }),
                      let roomType = Self.mockRoomTypes.first(where: { $0.id == request.roomTypeId }),
                      let ratePlan = Self.mockRatePlans.first(where: { $0.id == request.ratePlanId }) else {
                    promise(.failure(MockError.bookingFailed))
                    return
                }
                
                let booking = Booking(
                    id: UUID().uuidString,
                    userId: "mock-user",
                    propertyRef: property,
                    roomTypeRef: roomType,
                    ratePlanRef: ratePlan,
                    guests: request.guests,
                    dateRange: request.dateRange,
                    priceSnapshot: Self.mockPriceBreakdown,
                    paymentInfo: PaymentInfo(method: .card, status: .succeeded),
                    status: .confirmed,
                    providerConfirmation: ProviderConfirmation(
                        provider: "Mock Provider",
                        confirmationCode: "MOCK\(Int.random(in: 1000...9999))",
                        providerBookingId: "BK\(Int.random(in: 100000...999999))"
                    )
                )
                
                promise(.success(booking))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func importBooking(_ request: ImportRequest) -> AnyPublisher<ImportResult, Error> {
        return Future<ImportResult, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [self] in
                let result = ImportResult(
                    importId: UUID().uuidString,
                    success: Bool.random(),
                    booking: Bool.random() ? Self.mockBookings.first : nil,
                    error: Bool.random() ? "Unable to parse confirmation email" : nil,
                    deepLink: "liive://accommodations/booking/\(UUID().uuidString)"
                )
                
                promise(.success(result))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func getUserBookings() -> AnyPublisher<[Booking], Error> {
        return Future<[Booking], Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                promise(.success(Self.mockBookings))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func cancelBooking(_ id: String, reason: String?) -> AnyPublisher<CancelBookingResult, Error> {
        return Future<CancelBookingResult, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
                let result = CancelBookingResult(
                    success: true,
                    cancellationId: "CANCEL\(Int.random(in: 1000...9999))",
                    refundAmount: Decimal(Double.random(in: 50...500)),
                    cancellationFee: Decimal(Double.random(in: 0...50)),
                    message: "Your booking has been cancelled. Refund will be processed within 3-5 business days."
                )
                
                promise(.success(result))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Voice Assistant
    
    public func interpretVoice(_ request: VoiceInterpretRequest) -> AnyPublisher<VoiceInterpretResponse, Error> {
        return Future<VoiceInterpretResponse, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                let searchRequest = SearchRequest(
                    location: .address("New York"),
                    dateRange: DateRange(
                        startDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                        endDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
                    ),
                    guests: GuestConfiguration(adults: 2)
                )
                
                let response = VoiceInterpretResponse(
                    intent: SearchIntent(type: .search, entities: ["location": AnyCodable("New York")]),
                    normalizedParams: searchRequest,
                    nextPrompt: "I found hotels in New York. Would you like to see results?",
                    confidence: 0.92
                )
                
                promise(.success(response))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Saved Properties
    
    public func getSavedProperties() -> AnyPublisher<SavedPropertiesResponse, Error> {
        return Future<SavedPropertiesResponse, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                let favorites = savedProperties.compactMap { id in
                    Self.mockProperties.first(where: { $0.id == id })
                }
                
                let recent = recentlyViewed.compactMap { id in
                    Self.mockProperties.first(where: { $0.id == id })
                }
                
                let response = SavedPropertiesResponse(
                    favorites: favorites,
                    shortlists: shortlists,
                    recentlyViewed: recent
                )
                
                promise(.success(response))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func addToFavorites(_ propertyId: String) -> AnyPublisher<AccommodationProperty, Error> {
        return Future<AccommodationProperty, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                guard let property = Self.mockProperties.first(where: { $0.id == propertyId }) else {
                    promise(.failure(MockError.propertyNotFound))
                    return
                }
                
                savedProperties.append(propertyId)
                promise(.success(property))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func removeFromFavorites(_ propertyId: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                savedProperties.removeAll { $0 == propertyId }
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func createShortlist(_ request: ShortlistUpdateRequest) -> AnyPublisher<Shortlist, Error> {
        return Future<Shortlist, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                let shortlist = Shortlist(
                    id: UUID().uuidString,
                    name: request.name ?? "New Shortlist",
                    description: request.description ?? "",
                    propertyIds: request.propertyIds ?? [],
                    userId: "mock-user",
                    createdAt: Date(),
                    updatedAt: Date(),
                    isPrivate: !(request.isPrivate ?? true)
                )
                
                shortlists.append(shortlist)
                promise(.success(shortlist))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func updateShortlist(_ id: String, request: ShortlistUpdateRequest) -> AnyPublisher<Shortlist, Error> {
        return Future<Shortlist, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                guard let index = shortlists.firstIndex(where: { $0.id == id }) else {
                    promise(.failure(MockError.shortlistNotFound))
                    return
                }
                
                var shortlist = shortlists[index]
                shortlist = Shortlist(
                    id: shortlist.id,
                    name: request.name ?? shortlist.name,
                    description: request.description ?? shortlist.description,
                    propertyIds: request.propertyIds ?? shortlist.propertyIds,
                    userId: shortlist.userId,
                    createdAt: shortlist.createdAt,
                    updatedAt: Date(),
                    isPrivate: request.isPrivate ?? shortlist.isPrivate
                )
                
                shortlists[index] = shortlist
                promise(.success(shortlist))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func deleteShortlist(_ id: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                shortlists.removeAll { $0.id == id }
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func clearRecentlyViewed() -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                recentlyViewed.removeAll()
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Geocoding
    
    public func autocompleteDestinations(_ query: String, userLocation: CLLocationCoordinate2D?) -> AnyPublisher<[AutocompleteResult], Error> {
        return Future<[AutocompleteResult], Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                let results = Self.mockAutocompleteResults.filter { result in
                    result.placeName.lowercased().contains(query.lowercased())
                }
                
                promise(.success(Array(results.prefix(5))))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func geocodeAddress(_ address: String) -> AnyPublisher<[GeocodeResult], Error> {
        return Future<[GeocodeResult], Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                let result = GeocodeResult(
                    placeName: address,
                    coordinates: CLLocationCoordinate2D(
                        latitude: 40.7128 + Double.random(in: -0.1...0.1),
                        longitude: -74.0060 + Double.random(in: -0.1...0.1)
                    ),
                    context: GeocodeContext(
                        address: address,
                        locality: "New York",
                        region: "NY",
                        country: "United States",
                        postcode: "10001"
                    )
                )
                
                promise(.success([result]))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func reverseGeocode(_ coordinate: CLLocationCoordinate2D) -> AnyPublisher<String, Error> {
        return Future<String, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                let addresses = [
                    "123 Main St, New York, NY 10001",
                    "456 Broadway, New York, NY 10013",
                    "789 Fifth Ave, New York, NY 10022",
                    "321 Park Ave, New York, NY 10017"
                ]
                
                promise(.success(addresses.randomElement() ?? "Unknown location"))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
}

// MARK: - Mock Data

extension MockAccommodationsService {
    
    static let mockProperties: [AccommodationProperty] = [
        AccommodationProperty(
            id: "prop1",
            providerRefs: [ProviderReference(provider: "Booking.com", providerPropertyId: "123456")],
            name: "The Plaza Hotel",
            brand: "Plaza Hotels",
            type: .hotel,
            rating: 4.8,
            reviewsCount: 2847,
            address: Address(
                street: "768 5th Ave",
                city: "New York",
                state: "NY",
                postalCode: "10019",
                country: "United States",
                formattedAddress: "768 5th Ave, New York, NY 10019, USA"
            ),
            coordinates: CLLocationCoordinate2D(latitude: 40.7647, longitude: -73.9753),
            photos: [
                Photo(id: "photo1", url: "https://example.com/plaza1.jpg", caption: "Lobby"),
                Photo(id: "photo2", url: "https://example.com/plaza2.jpg", caption: "Suite")
            ],
            amenities: ["Wi-Fi", "Pool", "Spa", "Gym", "Concierge", "Room Service"],
            safetyFeatures: ["24/7 Security", "Fire Safety", "First Aid"],
            checkInTime: "15:00",
            checkOutTime: "12:00",
            policies: PropertyPolicies(
                cancellationPolicy: CancellationPolicy(
                    type: .moderate,
                    description: "Free cancellation until 24 hours before arrival"
                )
            ),
            priceRange: PriceRange(min: Decimal(200), max: Decimal(800), currency: "USD")
        ),
        
        AccommodationProperty(
            id: "prop2",
            providerRefs: [ProviderReference(provider: "Airbnb", providerPropertyId: "789012")],
            name: "Brooklyn Loft",
            type: .apartment,
            rating: 4.6,
            reviewsCount: 156,
            address: Address(
                city: "Brooklyn",
                state: "NY",
                country: "United States",
                formattedAddress: "Brooklyn, NY, USA"
            ),
            coordinates: CLLocationCoordinate2D(latitude: 40.6782, longitude: -73.9442),
            photos: [
                Photo(id: "photo3", url: "https://example.com/loft1.jpg", caption: "Living Room"),
                Photo(id: "photo4", url: "https://example.com/loft2.jpg", caption: "Kitchen")
            ],
            amenities: ["Wi-Fi", "Kitchen", "Washing Machine", "Air Conditioning"],
            safetyFeatures: ["Smoke Detector", "Fire Extinguisher"],
            checkInTime: "16:00",
            checkOutTime: "11:00",
            policies: PropertyPolicies(
                cancellationPolicy: CancellationPolicy(
                    type: .flexible,
                    description: "Free cancellation until 5 days before arrival"
                )
            ),
            priceRange: PriceRange(min: Decimal(80), max: Decimal(150), currency: "USD")
        ),
        
        AccommodationProperty(
            id: "prop3",
            providerRefs: [ProviderReference(provider: "Hostelworld", providerPropertyId: "345678")],
            name: "Manhattan Backpackers",
            type: .hostel,
            rating: 4.2,
            reviewsCount: 892,
            address: Address(
                street: "891 Amsterdam Ave",
                city: "New York",
                state: "NY",
                postalCode: "10025",
                country: "United States",
                formattedAddress: "891 Amsterdam Ave, New York, NY 10025, USA"
            ),
            coordinates: CLLocationCoordinate2D(latitude: 40.7937, longitude: -73.9734),
            photos: [
                Photo(id: "photo5", url: "https://example.com/hostel1.jpg", caption: "Dorm Room"),
                Photo(id: "photo6", url: "https://example.com/hostel2.jpg", caption: "Common Area")
            ],
            amenities: ["Wi-Fi", "Kitchen", "Laundry", "Lounge", "Luggage Storage"],
            safetyFeatures: ["24/7 Reception", "Lockers", "Security Cameras"],
            checkInTime: "14:00",
            checkOutTime: "11:00",
            policies: PropertyPolicies(
                cancellationPolicy: CancellationPolicy(
                    type: .strict,
                    description: "No refunds for cancellations"
                )
            ),
            priceRange: PriceRange(min: Decimal(25), max: Decimal(60), currency: "USD")
        )
    ]
    
    static let mockRoomTypes: [RoomType] = [
        RoomType(
            id: "room1",
            name: "Standard King Room",
            capacity: RoomCapacity(adults: 2),
            beds: [BedConfiguration(type: .king, count: 1)],
            amenities: ["Wi-Fi", "Air Conditioning", "Mini Bar"],
            images: [Photo(id: "room_photo1", url: "https://example.com/room1.jpg")],
            size: RoomSize(value: 25, unit: .squareMeters)
        )
    ]
    
    static let mockRatePlans: [RatePlan] = [
        RatePlan(
            id: "rate1",
            name: "Best Available Rate",
            mealPlan: .bedAndBreakfast,
            cancellationPolicy: CancellationPolicy(
                type: .moderate,
                description: "Free cancellation until 24 hours before"
            ),
            inclusions: ["Breakfast", "Wi-Fi"],
            exclusions: [],
            paymentType: .payNow,
            prepaymentRequired: false,
            depositRequired: false
        )
    ]
    
    static let mockAvailability: [Availability] = [
        Availability(
            propertyId: "prop1",
            roomTypeId: "room1",
            ratePlanId: "rate1",
            dateRange: DateRange(startDate: Date(), endDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()),
            inventoryCount: 5,
            priceBreakdown: mockPriceBreakdown,
            lastUpdated: Date(),
            isAvailable: true
        )
    ]
    
    static let mockPriceBreakdown = PriceBreakdown(
        basePrice: Decimal(199),
        taxes: [
            Tax(type: .cityTax, name: "City Tax", amount: Decimal(15)),
            Tax(type: .vat, name: "VAT", amount: Decimal(10))
        ],
        fees: [
            Fee(type: .serviceFee, name: "Service Fee", amount: Decimal(10))
        ],
        currency: "USD"
    )
    
    static let mockBookings: [Booking] = [
        Booking(
            id: "booking1",
            userId: "user1",
            propertyRef: mockProperties[0],
            roomTypeRef: mockRoomTypes[0],
            ratePlanRef: mockRatePlans[0],
            guests: [
                Guest(firstName: "John", lastName: "Doe", email: "john@example.com", isLead: true)
            ],
            dateRange: DateRange(
                startDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 33, to: Date()) ?? Date()
            ),
            priceSnapshot: mockPriceBreakdown,
            paymentInfo: PaymentInfo(method: .card, status: .succeeded),
            status: .confirmed,
            providerConfirmation: ProviderConfirmation(
                provider: "Booking.com",
                confirmationCode: "ABC123",
                providerBookingId: "BK789456"
            )
        )
    ]
    
    static let mockAutocompleteResults: [AutocompleteResult] = [
        AutocompleteResult(
            id: "place1",
            placeName: "New York, NY, USA",
            coordinates: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            context: GeocodeContext(locality: "New York", region: "NY", country: "United States")
        ),
        AutocompleteResult(
            id: "place2",
            placeName: "Los Angeles, CA, USA",
            coordinates: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
            context: GeocodeContext(locality: "Los Angeles", region: "CA", country: "United States")
        ),
        AutocompleteResult(
            id: "place3",
            placeName: "London, UK",
            coordinates: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            context: GeocodeContext(locality: "London", country: "United Kingdom")
        )
    ]
}

// MARK: - Mock Error Types

enum MockError: Error, LocalizedError {
    case propertyNotFound
    case bookingFailed
    case shortlistNotFound
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .propertyNotFound: return "Property not found"
        case .bookingFailed: return "Booking failed"
        case .shortlistNotFound: return "Shortlist not found"
        case .networkError: return "Network error"
        }
    }
}

// MARK: - Missing Model Types (based on other services)


