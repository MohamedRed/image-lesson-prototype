import SwiftUI
import TripsService

public struct TripsContainerView: View {
    let useRealService: Bool
    
    public init(useRealService: Bool = false) {
        self.useRealService = useRealService
    }
    
    public var body: some View {
        TripsView()
            .environmentObject(TripsViewModel(service: createService()))
    }
    
    private func createService() -> TripsServicing {
        if useRealService {
            TripsServiceFactory.configure(environment: .production)
        } else {
            TripsServiceFactory.configure(environment: .mock)
        }
        return TripsServiceFactory.makeService()
    }
}

struct TripsView: View {
    @EnvironmentObject private var viewModel: TripsViewModel
    @State private var showingCreateTrip = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Trips")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Plan, book, and manage your adventures")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Create Trip Button
                    Button(action: { showingCreateTrip = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Plan New Trip")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Trip List
                    if viewModel.isLoading {
                        ProgressView("Loading trips...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if viewModel.trips.isEmpty {
                        EmptyTripsView()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.trips) { trip in
                                TripCardView(trip: trip)
                                    .onTapGesture {
                                        viewModel.selectedTrip = trip
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                await viewModel.loadTrips()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCreateTrip) {
            CreateTripView()
                .environmentObject(viewModel)
        }
        .sheet(item: $viewModel.selectedTrip) { trip in
            TripDetailView(trip: trip)
                .environmentObject(viewModel)
        }
        .task {
            await viewModel.loadTrips()
        }
    }
}

struct EmptyTripsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("No trips yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start planning your next adventure")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

#Preview {
    TripsContainerView(useRealService: false)
}