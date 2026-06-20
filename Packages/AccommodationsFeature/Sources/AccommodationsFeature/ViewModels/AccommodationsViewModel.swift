import Foundation
import Combine
import SwiftUI
import AccommodationsService
import CoreLocation

@MainActor
public class AccommodationsViewModel: ObservableObject {
    @Published var searchResults: [AccommodationProperty] = []
    @Published var recommendations: [RecommendedProperty] = []
    @Published var bookings: [Booking] = []
    @Published var currentProperty: AccommodationProperty?
    @Published var propertyDetails: PropertyDetailsResponse?
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var showingVoiceInput = false
    
    // Saved properties
    @Published var favoriteProperties: [AccommodationProperty] = []
    @Published var shortlists: [Shortlist] = []
    @Published var recentlyViewedProperties: [AccommodationProperty] = []
    
    // Geocoding
    @Published var autocompleteResults: [AutocompleteResult] = []
    @Published var currentLocationName: String?
    
    // Search state
    @Published var searchRequest: SearchRequest = AccommodationsViewModel.defaultSearchRequest()
    @Published var selectedFilters = SearchFilters()
    @Published var sortOption: SortOption = .relevance
    
    private let service: AccommodationsServiceProtocol
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    public init(service: AccommodationsServiceProtocol = AccommodationsService()) {
        self.service = service
        setupLocationManager()
        loadUserBookings()
        loadRecommendations()
    }
    
    // MARK: - Search
    
    func search() {
        isLoading = true
        errorMessage = nil
        
        service.search(searchRequest)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.searchResults = response.properties
                }
            )
            .store(in: &cancellables)
    }
    
    func searchByLocation(_ location: SearchLocation) {
        searchRequest = SearchRequest(
            location: location,
            dateRange: searchRequest.dateRange,
            guests: searchRequest.guests,
            filters: searchRequest.filters,
            sortBy: searchRequest.sortBy,
            pageToken: nil
        )
        search()
    }
    
    func searchByText(_ text: String) {
        searchText = text
        searchRequest = SearchRequest(
            location: .address(text),
            dateRange: searchRequest.dateRange,
            guests: searchRequest.guests,
            filters: searchRequest.filters,
            sortBy: searchRequest.sortBy,
            pageToken: nil
        )
        search()
    }
    
    func updateFilters(_ filters: SearchFilters) {
        selectedFilters = filters
        searchRequest = SearchRequest(
            location: searchRequest.location,
            dateRange: searchRequest.dateRange,
            guests: searchRequest.guests,
            filters: filters,
            sortBy: searchRequest.sortBy,
            pageToken: nil
        )
        search()
    }
    
    func updateSort(_ option: SortOption) {
        sortOption = option
        searchRequest = SearchRequest(
            location: searchRequest.location,
            dateRange: searchRequest.dateRange,
            guests: searchRequest.guests,
            filters: searchRequest.filters,
            sortBy: option,
            pageToken: nil
        )
        search()
    }
    
    func updateDates(checkIn: Date, checkOut: Date) {
        let newRange = DateRange(startDate: checkIn, endDate: checkOut)
        searchRequest = SearchRequest(
            location: searchRequest.location,
            dateRange: newRange,
            guests: searchRequest.guests,
            filters: searchRequest.filters,
            sortBy: searchRequest.sortBy,
            pageToken: nil
        )
        search()
    }
    
    func updateGuests(_ guests: GuestConfiguration) {
        searchRequest = SearchRequest(
            location: searchRequest.location,
            dateRange: searchRequest.dateRange,
            guests: guests,
            filters: searchRequest.filters,
            sortBy: searchRequest.sortBy,
            pageToken: nil
        )
        search()
    }
    
    // MARK: - Property Details
    
    func getPropertyDetails(_ property: AccommodationProperty) {
        currentProperty = property
        isLoading = true
        
        let params = PropertyDetailsParams(
            checkIn: searchRequest.dateRange.startDate,
            checkOut: searchRequest.dateRange.endDate,
            guests: searchRequest.guests
        )
        
        service.getPropertyDetails(property.id, params: params)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.propertyDetails = response
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Booking
    
    func createBooking(
        roomTypeId: String,
        ratePlanId: String,
        guests: [Guest],
        paymentMethodId: String,
        specialRequests: String? = nil
    ) {
        guard let property = currentProperty else { return }
        
        isLoading = true
        
        let bookingRequest = BookingRequest(
            propertyId: property.id,
            roomTypeId: roomTypeId,
            ratePlanId: ratePlanId,
            dateRange: searchRequest.dateRange,
            guests: guests,
            paymentMethodId: paymentMethodId,
            specialRequests: specialRequests
        )
        
        service.createBooking(bookingRequest)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] booking in
                    self?.bookings.insert(booking, at: 0)
                    // Navigate to booking confirmation
                }
            )
            .store(in: &cancellables)
    }
    
    func cancelBooking(_ booking: Booking, reason: String?) {
        isLoading = true
        
        service.cancelBooking(booking.id, reason: reason)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] result in
                    if result.success {
                        self?.loadUserBookings() // Refresh bookings
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Voice
    
    func processVoiceInput(_ transcript: String) {
        let context = SearchContext(
            previousSearch: searchRequest,
            sessionId: UUID().uuidString
        )
        
        let voiceRequest = VoiceInterpretRequest(
            transcript: transcript,
            context: context
        )
        
        service.interpretVoice(voiceRequest)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.handleVoiceResponse(response)
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleVoiceResponse(_ response: VoiceInterpretResponse) {
        searchRequest = response.normalizedParams
        
        switch response.intent.type {
        case .search:
            search()
        case .filter:
            // Update filters based on entities
            search()
        case .sort:
            // Update sort based on entities
            search()
        default:
            break
        }
    }
    
    // MARK: - Import
    
    func importBooking(url: String) {
        isLoading = true
        
        let importRequest = ImportRequest(url: url)
        
        service.importBooking(importRequest)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] result in
                    if result.success, let booking = result.booking {
                        self?.bookings.insert(booking, at: 0)
                    } else {
                        self?.errorMessage = result.error ?? "Import failed"
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func importBooking(provider: String, confirmationCode: String, lastName: String?) {
        isLoading = true
        
        let importRequest = ImportRequest(
            provider: provider,
            confirmationCode: confirmationCode,
            lastName: lastName
        )
        
        service.importBooking(importRequest)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] result in
                    if result.success, let booking = result.booking {
                        self?.bookings.insert(booking, at: 0)
                    } else {
                        self?.errorMessage = result.error ?? "Import failed"
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Recommendations
    
    private func loadRecommendations() {
        let context = RecommendationContext()
        
        service.getRecommendations(context: context)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.recommendations = response.recommendations
                }
            )
            .store(in: &cancellables)
    }
    
    private func loadUserBookings() {
        service.getUserBookings()
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Failed to load bookings: \(error)")
                    }
                },
                receiveValue: { [weak self] bookings in
                    self?.bookings = bookings
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Location
    
    private func setupLocationManager() {
        locationManager.delegate = LocationDelegate { [weak self] location in
            // Handle location updates if needed
        }
    }
    
    private func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Saved Properties
    
    func loadSavedProperties() {
        isLoading = true
        errorMessage = nil
        
        service.getSavedProperties()
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.favoriteProperties = response.favorites
                    self?.shortlists = response.shortlists
                    self?.recentlyViewedProperties = response.recentlyViewed
                }
            )
            .store(in: &cancellables)
    }
    
    func addToFavorites(_ propertyId: String) {
        service.addToFavorites(propertyId)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] property in
                    self?.favoriteProperties.insert(property, at: 0)
                }
            )
            .store(in: &cancellables)
    }
    
    func removeFromFavorites(_ propertyId: String) {
        service.removeFromFavorites(propertyId)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.favoriteProperties.removeAll { $0.id == propertyId }
                }
            )
            .store(in: &cancellables)
    }
    
    func createShortlist(name: String, description: String) {
        let request = ShortlistUpdateRequest(name: name, description: description)
        
        service.createShortlist(request)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] shortlist in
                    self?.shortlists.insert(shortlist, at: 0)
                }
            )
            .store(in: &cancellables)
    }
    
    func updateShortlist(_ shortlistId: String, request: ShortlistUpdateRequest) {
        service.updateShortlist(shortlistId, request: request)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] updatedShortlist in
                    if let index = self?.shortlists.firstIndex(where: { $0.id == shortlistId }) {
                        self?.shortlists[index] = updatedShortlist
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func deleteShortlist(_ shortlistId: String) {
        service.deleteShortlist(shortlistId)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.shortlists.removeAll { $0.id == shortlistId }
                }
            )
            .store(in: &cancellables)
    }
    
    func addPropertyToShortlist(_ propertyId: String, shortlistId: String) {
        if let index = shortlists.firstIndex(where: { $0.id == shortlistId }) {
            var updatedPropertyIds = shortlists[index].propertyIds
            if !updatedPropertyIds.contains(propertyId) {
                updatedPropertyIds.append(propertyId)
                let request = ShortlistUpdateRequest(propertyIds: updatedPropertyIds)
                updateShortlist(shortlistId, request: request)
            }
        }
    }
    
    func removePropertyFromShortlist(_ propertyId: String, shortlistId: String) {
        if let index = shortlists.firstIndex(where: { $0.id == shortlistId }) {
            var updatedPropertyIds = shortlists[index].propertyIds
            updatedPropertyIds.removeAll { $0 == propertyId }
            let request = ShortlistUpdateRequest(propertyIds: updatedPropertyIds)
            updateShortlist(shortlistId, request: request)
        }
    }
    
    func clearRecentlyViewed() {
        service.clearRecentlyViewed()
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.recentlyViewedProperties.removeAll()
                }
            )
            .store(in: &cancellables)
    }
    
    func applySavedPropertiesFilter(_ filter: SavedPropertiesFilter) {
        // Apply local filtering and sorting to saved properties
        favoriteProperties = applySortAndFilter(to: favoriteProperties, filter: filter)
        recentlyViewedProperties = applySortAndFilter(to: recentlyViewedProperties, filter: filter)
    }
    
    private func applySortAndFilter(to properties: [AccommodationProperty], filter: SavedPropertiesFilter) -> [AccommodationProperty] {
        var filtered = properties
        
        // Filter by property types
        if !filter.propertyTypes.isEmpty {
            filtered = filtered.filter { property in
                filter.propertyTypes.contains(property.type)
            }
        }
        
        // Filter by minimum rating
        if filter.minimumRating > 0 {
            filtered = filtered.filter { property in
                (property.rating ?? 0) >= filter.minimumRating
            }
        }
        
        // Filter by price range
        if let priceRange = filter.priceRange {
            filtered = filtered.filter { property in
                guard let propertyPriceRange = property.priceRange else { return false }
                let minDouble = NSDecimalNumber(decimal: propertyPriceRange.min).doubleValue
                let maxDouble = NSDecimalNumber(decimal: propertyPriceRange.max).doubleValue
                return minDouble >= priceRange.lowerBound && maxDouble <= priceRange.upperBound
            }
        }
        
        // Sort
        switch filter.sortBy {
        case .dateAdded:
            // Would need dateAdded field in property model for proper implementation
            break
        case .priceAscending:
            filtered.sort {
                let lhs = $0.priceRange.map { NSDecimalNumber(decimal: $0.min).doubleValue } ?? Double.infinity
                let rhs = $1.priceRange.map { NSDecimalNumber(decimal: $0.min).doubleValue } ?? Double.infinity
                return lhs < rhs
            }
        case .priceDescending:
            filtered.sort {
                let lhs = $0.priceRange.map { NSDecimalNumber(decimal: $0.min).doubleValue } ?? 0
                let rhs = $1.priceRange.map { NSDecimalNumber(decimal: $0.min).doubleValue } ?? 0
                return lhs > rhs
            }
        case .rating:
            filtered.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .alphabetical:
            filtered.sort { $0.name < $1.name }
        }
        
        return filtered
    }
    
    // MARK: - Geocoding
    
    func searchDestinations(_ query: String) {
        guard !query.isEmpty else {
            autocompleteResults = []
            return
        }
        
        let userLocation = locationManager.location?.coordinate
        
        service.autocompleteDestinations(query, userLocation: userLocation)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Autocomplete error: \(error)")
                    }
                },
                receiveValue: { [weak self] results in
                    self?.autocompleteResults = results
                }
            )
            .store(in: &cancellables)
    }
    
    func selectDestination(_ result: AutocompleteResult) {
        if let coordinates = result.coordinates {
            searchRequest = SearchRequest(
                location: .coordinates(lat: coordinates.latitude, lng: coordinates.longitude),
                dateRange: searchRequest.dateRange,
                guests: searchRequest.guests,
                filters: searchRequest.filters,
                sortBy: searchRequest.sortBy,
                pageToken: nil
            )
        }
        searchText = result.placeName
        autocompleteResults = []
    }
    
    func useCurrentLocation() {
        requestLocationPermission()
        
        guard let location = locationManager.location else {
            errorMessage = "Location not available"
            return
        }
        
        searchRequest = SearchRequest(
            location: .coordinates(lat: location.coordinate.latitude, lng: location.coordinate.longitude),
            dateRange: searchRequest.dateRange,
            guests: searchRequest.guests,
            filters: searchRequest.filters,
            sortBy: searchRequest.sortBy,
            pageToken: nil
        )
        
        // Get location name for display
        service.reverseGeocode(location.coordinate)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Reverse geocode error: \(error)")
                    }
                },
                receiveValue: { [weak self] locationName in
                    self?.currentLocationName = locationName
                    self?.searchText = locationName
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Helpers
    
    private static func defaultSearchRequest() -> SearchRequest {
        SearchRequest(
            location: .coordinates(lat: 37.7749, lng: -122.4194), // San Francisco
            dateRange: DateRange(
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
            ),
            guests: GuestConfiguration(adults: 1)
        )
    }
}

// MARK: - Location Delegate

private class LocationDelegate: NSObject, CLLocationManagerDelegate {
    let onLocationUpdate: (CLLocation) -> Void
    
    init(onLocationUpdate: @escaping (CLLocation) -> Void) {
        self.onLocationUpdate = onLocationUpdate
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onLocationUpdate(location)
    }
}