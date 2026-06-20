import XCTest
import Combine
@testable import AccommodationsService

final class AccommodationsServiceTests: XCTestCase {
    var sut: AccommodationsService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        sut = AccommodationsService(baseURL: "https://test-api.example.com")
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        sut = nil
    }
    
    func testSearchRequestCreation() throws {
        let searchRequest = SearchRequest(
            location: .coordinates(lat: 37.7749, lng: -122.4194),
            dateRange: DateRange(
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!
            ),
            guests: GuestConfiguration(adults: 2)
        )
        
        XCTAssertEqual(searchRequest.guests.adults, 2)
        XCTAssertEqual(searchRequest.guests.rooms, 1) // Default
        XCTAssertEqual(searchRequest.guests.children, 0) // Default
    }
    
    func testAccommodationPropertyModel() throws {
        let property = AccommodationProperty(
            id: "test-property-1",
            providerRefs: [
                ProviderReference(
                    provider: "test-provider",
                    providerPropertyId: "12345"
                )
            ],
            name: "Test Hotel",
            type: .hotel,
            rating: 4.5,
            reviewsCount: 150,
            address: Address(
                city: "San Francisco",
                country: "US",
                formattedAddress: "123 Test St, San Francisco, CA"
            ),
            coordinates: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            photos: [],
            amenities: ["WiFi", "Pool", "Gym"],
            safetyFeatures: ["Security cameras", "24/7 front desk"],
            checkInTime: "15:00",
            checkOutTime: "11:00",
            policies: PropertyPolicies(
                cancellationPolicy: CancellationPolicy(
                    type: .flexible,
                    description: "Free cancellation up to 24 hours before check-in"
                )
            )
        )
        
        XCTAssertEqual(property.name, "Test Hotel")
        XCTAssertEqual(property.type, .hotel)
        XCTAssertEqual(property.rating, 4.5)
        XCTAssertEqual(property.amenities.count, 3)
        XCTAssertTrue(property.amenities.contains("WiFi"))
    }
    
    func testDateRange() throws {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 3, to: startDate)!
        
        let dateRange = DateRange(startDate: startDate, endDate: endDate)
        
        XCTAssertEqual(dateRange.nights, 3)
    }
    
    func testPriceBreakdown() throws {
        let taxes = [
            Tax(type: .vat, name: "VAT", amount: 20.00, percentage: 10.0),
            Tax(type: .cityTax, name: "City Tax", amount: 5.00)
        ]
        
        let fees = [
            Fee(type: .serviceFee, name: "Service Fee", amount: 15.00)
        ]
        
        let priceBreakdown = PriceBreakdown(
            basePrice: 200.00,
            taxes: taxes,
            fees: fees,
            currency: "USD"
        )
        
        XCTAssertEqual(priceBreakdown.basePrice, 200.00)
        XCTAssertEqual(priceBreakdown.totalPrice, 240.00) // 200 + 20 + 5 + 15
        XCTAssertEqual(priceBreakdown.currency, "USD")
    }
    
    func testGuestConfiguration() throws {
        let guests = GuestConfiguration(
            rooms: 2,
            adults: 4,
            children: 2,
            childrenAges: [8, 12]
        )
        
        XCTAssertEqual(guests.rooms, 2)
        XCTAssertEqual(guests.adults, 4)
        XCTAssertEqual(guests.children, 2)
        XCTAssertEqual(guests.childrenAges, [8, 12])
    }
    
    func testSearchFilters() throws {
        let filters = SearchFilters(
            budgetMin: 100,
            budgetMax: 300,
            rating: 4.0,
            amenities: ["WiFi", "Pool"],
            types: [.hotel, .apartment],
            cancellable: true
        )
        
        XCTAssertEqual(filters.budgetMin, 100)
        XCTAssertEqual(filters.budgetMax, 300)
        XCTAssertEqual(filters.rating, 4.0)
        XCTAssertEqual(filters.amenities?.count, 2)
        XCTAssertTrue(filters.cancellable ?? false)
    }
    
    func testBookingStatus() throws {
        XCTAssertEqual(BookingStatus.confirmed.displayName, "Confirmed")
        XCTAssertEqual(BookingStatus.pending.displayName, "Pending")
        XCTAssertEqual(BookingStatus.cancelled.displayName, "Cancelled")
    }
    
    func testAccommodationTypes() throws {
        XCTAssertEqual(AccommodationType.hotel.displayName, "Hotel")
        XCTAssertEqual(AccommodationType.apartment.displayName, "Apartment")
        XCTAssertEqual(AccommodationType.bedAndBreakfast.displayName, "B&B")
    }
    
    func testRoomCapacity() throws {
        let capacity = RoomCapacity(adults: 2, children: 1, infants: 1)
        
        XCTAssertEqual(capacity.adults, 2)
        XCTAssertEqual(capacity.children, 1)
        XCTAssertEqual(capacity.infants, 1)
        XCTAssertEqual(capacity.total, 3) // adults + children (infants not counted)
    }
    
    func testBedConfiguration() throws {
        let bed = BedConfiguration(type: .queen, count: 1)
        
        XCTAssertEqual(bed.type, .queen)
        XCTAssertEqual(bed.count, 1)
        XCTAssertEqual(bed.type.displayName, "Queen")
    }
    
    func testRoomSize() throws {
        let roomSize = RoomSize(value: 25.0, unit: .squareMeters)
        
        XCTAssertEqual(roomSize.value, 25.0)
        XCTAssertEqual(roomSize.unit, .squareMeters)
        XCTAssertEqual(roomSize.displayString, "25 m²")
    }
    
    func testMealPlan() throws {
        XCTAssertEqual(MealPlan.roomOnly.displayName, "Room Only")
        XCTAssertEqual(MealPlan.bedAndBreakfast.displayName, "Bed & Breakfast")
        XCTAssertEqual(MealPlan.allInclusive.displayName, "All Inclusive")
    }
}

// MARK: - Network Manager Tests

final class NetworkManagerTests: XCTestCase {
    var networkManager: NetworkManager!
    
    override func setUpWithError() throws {
        networkManager = NetworkManager(baseURL: "https://test-api.example.com")
    }
    
    override func tearDownWithError() throws {
        networkManager = nil
    }
    
    func testNetworkErrorDescriptions() throws {
        XCTAssertEqual(NetworkError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(NetworkError.notAuthenticated.errorDescription, "Authentication required")
        XCTAssertEqual(NetworkError.rateLimited.errorDescription, "Too many requests. Please try again later.")
        XCTAssertEqual(NetworkError.serverError.errorDescription, "Server error. Please try again later.")
    }
    
    func testAPIErrorWithMessage() throws {
        let error = NetworkError.apiError("Custom error message")
        XCTAssertEqual(error.errorDescription, "Custom error message")
    }
    
    func testHTTPError() throws {
        let error = NetworkError.httpError(404)
        XCTAssertEqual(error.errorDescription, "HTTP error: 404")
    }
}