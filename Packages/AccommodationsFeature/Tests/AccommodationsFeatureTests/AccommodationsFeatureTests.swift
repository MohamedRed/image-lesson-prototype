import XCTest
import SwiftUI
import Combine
@testable import AccommodationsFeature
@testable import AccommodationsService

final class AccommodationsFeatureTests: XCTestCase {
    
    func testAccommodationsFeatureCreation() throws {
        let view = AccommodationsFeature()
        XCTAssertNotNil(view)
    }
}

// MARK: - View Model Tests

final class AccommodationsViewModelTests: XCTestCase {
    var viewModel: AccommodationsViewModel!
    var mockService: MockAccommodationsService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        mockService = MockAccommodationsService()
        viewModel = AccommodationsViewModel(service: mockService)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        viewModel = nil
        mockService = nil
    }
    
    func testInitialState() throws {
        XCTAssertTrue(viewModel.searchResults.isEmpty)
        XCTAssertTrue(viewModel.recommendations.isEmpty)
        XCTAssertTrue(viewModel.bookings.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.searchText.isEmpty)
        XCTAssertNil(viewModel.currentProperty)
    }
    
    func testDefaultSearchRequest() throws {
        let defaultRequest = viewModel.searchRequest
        
        XCTAssertNotNil(defaultRequest.location)
        XCTAssertNotNil(defaultRequest.dateRange)
        XCTAssertEqual(defaultRequest.guests.adults, 1)
        XCTAssertEqual(defaultRequest.guests.rooms, 1)
        XCTAssertEqual(defaultRequest.guests.children, 0)
    }
    
    func testUpdateGuestConfiguration() throws {
        let newGuests = GuestConfiguration(
            rooms: 2,
            adults: 4,
            children: 1,
            childrenAges: [8]
        )
        
        viewModel.updateGuests(newGuests)
        
        XCTAssertEqual(viewModel.searchRequest.guests.rooms, 2)
        XCTAssertEqual(viewModel.searchRequest.guests.adults, 4)
        XCTAssertEqual(viewModel.searchRequest.guests.children, 1)
        XCTAssertEqual(viewModel.searchRequest.guests.childrenAges, [8])
    }
    
    func testUpdateFilters() throws {
        let filters = SearchFilters(
            budgetMin: 150,
            budgetMax: 400,
            rating: 4.0,
            amenities: ["WiFi", "Pool"],
            types: [.hotel]
        )
        
        viewModel.updateFilters(filters)
        
        XCTAssertEqual(viewModel.selectedFilters.budgetMin, 150)
        XCTAssertEqual(viewModel.selectedFilters.budgetMax, 400)
        XCTAssertEqual(viewModel.selectedFilters.rating, 4.0)
        XCTAssertEqual(viewModel.selectedFilters.amenities?.count, 2)
        XCTAssertEqual(viewModel.selectedFilters.types?.count, 1)
    }
    
    func testUpdateDates() throws {
        let checkIn = Date()
        let checkOut = Calendar.current.date(byAdding: .day, value: 3, to: checkIn)!
        
        viewModel.updateDates(checkIn: checkIn, checkOut: checkOut)
        
        XCTAssertEqual(viewModel.searchRequest.dateRange.startDate, checkIn)
        XCTAssertEqual(viewModel.searchRequest.dateRange.endDate, checkOut)
    }
    
    func testUpdateSort() throws {
        viewModel.updateSort(.priceAsc)
        
        XCTAssertEqual(viewModel.sortOption, .priceAsc)
        XCTAssertEqual(viewModel.searchRequest.sortBy, .priceAsc)
    }
    
    func testSearchByText() throws {
        let searchText = "San Francisco"
        
        viewModel.searchByText(searchText)
        
        XCTAssertEqual(viewModel.searchText, searchText)
        
        if case .address(let address) = viewModel.searchRequest.location {
            XCTAssertEqual(address, searchText)
        } else {
            XCTFail("Expected address location type")
        }
    }
}

// MARK: - Mock Service for Testing

class MockAccommodationsService: AccommodationsServiceProtocol {
    
    func search(_ request: SearchRequest) -> AnyPublisher<SearchResponse, Error> {
        let mockProperty = AccommodationProperty(
            id: "test-1",
            providerRefs: [],
            name: "Test Hotel",
            type: .hotel,
            rating: 4.5,
            reviewsCount: 100,
            address: Address(city: "Test City", country: "US", formattedAddress: "123 Test St"),
            coordinates: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            photos: [],
            amenities: ["WiFi"],
            safetyFeatures: [],
            checkInTime: "15:00",
            checkOutTime: "11:00",
            policies: PropertyPolicies(
                cancellationPolicy: CancellationPolicy(
                    type: .flexible,
                    description: "Flexible"
                )
            )
        )
        
        let response = SearchResponse(
            properties: [mockProperty],
            availability: [:],
            totalResults: 1,
            searchId: "test-search-id"
        )
        
        return Just(response)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getRecommendations(context: RecommendationContext) -> AnyPublisher<RecommendationResponse, Error> {
        let response = RecommendationResponse(recommendations: [])
        return Just(response)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getPropertyDetails(_ id: String, params: PropertyDetailsParams?) -> AnyPublisher<PropertyDetailsResponse, Error> {
        let mockProperty = AccommodationProperty(
            id: id,
            providerRefs: [],
            name: "Test Hotel",
            type: .hotel,
            rating: 4.5,
            reviewsCount: 100,
            address: Address(city: "Test City", country: "US", formattedAddress: "123 Test St"),
            coordinates: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            photos: [],
            amenities: ["WiFi"],
            safetyFeatures: [],
            checkInTime: "15:00",
            checkOutTime: "11:00",
            policies: PropertyPolicies(
                cancellationPolicy: CancellationPolicy(
                    type: .flexible,
                    description: "Flexible"
                )
            )
        )
        
        let response = PropertyDetailsResponse(
            property: mockProperty,
            roomTypes: [],
            ratePlans: [],
            availability: []
        )
        
        return Just(response)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func createBooking(_ request: BookingRequest) -> AnyPublisher<Booking, Error> {
        return Fail(error: NSError(domain: "MockError", code: 0))
            .eraseToAnyPublisher()
    }
    
    func importBooking(_ request: ImportRequest) -> AnyPublisher<ImportResult, Error> {
        let result = ImportResult(importId: "test-import", success: false)
        return Just(result)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func interpretVoice(_ request: VoiceInterpretRequest) -> AnyPublisher<VoiceInterpretResponse, Error> {
        return Fail(error: NSError(domain: "MockError", code: 0))
            .eraseToAnyPublisher()
    }
    
    func getUserBookings() -> AnyPublisher<[Booking], Error> {
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func cancelBooking(_ id: String, reason: String?) -> AnyPublisher<CancelBookingResult, Error> {
        let result = CancelBookingResult(success: false)
        return Just(result)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}