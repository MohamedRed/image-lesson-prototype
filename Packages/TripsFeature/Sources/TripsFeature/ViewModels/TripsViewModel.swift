import Foundation
import Combine
import TripsService

@MainActor
public class TripsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var trips: [Trip] = []
    @Published var selectedTrip: Trip?
    @Published var isLoading = false
    @Published var error: String?
    
    // MARK: - Private Properties
    
    private let service: TripsServicing
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(service: TripsServicing) {
        self.service = service
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    func loadTrips() async {
        isLoading = true
        error = nil
        
        do {
            trips = try await service.getMyTrips()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createTrip(title: String, scope: TripScope, duration: TripDuration, constraints: TripConstraints) async {
        isLoading = true
        error = nil
        
        do {
            let newTrip = try await service.createTrip(
                title: title,
                scope: scope,
                duration: duration,
                constraints: constraints
            )
            trips.append(newTrip)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteTrip(_ trip: Trip) async {
        do {
            try await service.deleteTrip(id: trip.id)
            trips.removeAll { $0.id == trip.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        service.tripUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedTrip in
                guard let self = self else { return }
                
                if let index = self.trips.firstIndex(where: { $0.id == updatedTrip.id }) {
                    self.trips[index] = updatedTrip
                } else {
                    self.trips.append(updatedTrip)
                }
            }
            .store(in: &cancellables)
    }
}