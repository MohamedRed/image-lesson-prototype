import SwiftUI
import TripsService

struct TripDetailView: View {
    let trip: Trip
    @EnvironmentObject private var viewModel: TripsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: TripDetailTab = .overview
    
    enum TripDetailTab: String, CaseIterable {
        case overview = "Overview"
        case itinerary = "Itinerary"
        case budget = "Budget"
        case documents = "Documents"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                TripHeaderView(trip: trip)
                
                // Tab Bar
                Picker("Tab", selection: $selectedTab) {
                    ForEach(TripDetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    TripOverviewView(trip: trip)
                        .tag(TripDetailTab.overview)
                    
                    TripItineraryView(trip: trip)
                        .tag(TripDetailTab.itinerary)
                    
                    TripBudgetView(trip: trip)
                        .tag(TripDetailTab.budget)
                    
                    TripDocumentsView(trip: trip)
                        .tag(TripDetailTab.documents)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Trip") {
                            // TODO: Implement edit
                        }
                        
                        Button("Share Trip") {
                            // TODO: Implement sharing
                        }
                        
                        Button("Delete Trip", role: .destructive) {
                            Task {
                                await viewModel.deleteTrip(trip)
                                dismiss()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

struct TripHeaderView: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(formatDateRange())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                TripStatusBadge(status: trip.status)
            }
            
            HStack {
                if let budget = trip.constraints.budget {
                    Label(budget.total.formatted, systemImage: "dollarsign.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Label("\(trip.members.count) travelers", systemImage: "person.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        if let window = trip.startWindow {
            return "\(formatter.string(from: window.start)) - \(formatter.string(from: window.end))"
        } else {
            return "Flexible dates (\(trip.duration.days) days)"
        }
    }
}

struct TripOverviewView: View {
    let trip: Trip
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        QuickActionButton(
                            title: "Plan Itinerary",
                            icon: "map",
                            color: .blue
                        ) {
                            // TODO: Navigate to planning
                        }
                        
                        QuickActionButton(
                            title: "Book Flights",
                            icon: "airplane",
                            color: .green
                        ) {
                            // TODO: Navigate to flight search
                        }
                        
                        QuickActionButton(
                            title: "Find Hotels",
                            icon: "bed.double",
                            color: .purple
                        ) {
                            // TODO: Navigate to hotel search
                        }
                        
                        QuickActionButton(
                            title: "Voice Assistant",
                            icon: "mic",
                            color: .orange
                        ) {
                            // TODO: Start voice session
                        }
                    }
                }
                
                // Members
                if trip.members.count > 1 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Travelers")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(trip.members, id: \.userId) { member in
                            TripMemberRow(member: member)
                        }
                    }
                }
                
                // Constraints
                VStack(alignment: .leading, spacing: 12) {
                    Text("Constraints")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ConstraintsView(constraints: trip.constraints)
                }
            }
            .padding()
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        }
    }
}

struct TripMemberRow: View {
    let member: TripMember
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(member.name.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(member.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ConstraintsView: View {
    let constraints: TripConstraints
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let budget = constraints.budget {
                HStack {
                    Text("Budget:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(budget.total.formatted)
                        .foregroundColor(.secondary)
                }
            }
            
            if !constraints.mustInclude.isEmpty {
                HStack {
                    Text("Must include:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(constraints.mustInclude.joined(separator: ", "))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            if !constraints.mustAvoid.isEmpty {
                HStack {
                    Text("Avoid:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(constraints.mustAvoid.joined(separator: ", "))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TripItineraryView: View {
    let trip: Trip
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if trip.status == .draft {
                    Text("Itinerary planning in progress...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    Text("Detailed itinerary will be shown here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
    }
}

struct TripBudgetView: View {
    let trip: Trip
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let budget = trip.constraints.budget {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Budget Overview")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Text("Total Budget:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(budget.total.formatted)
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                } else {
                    Text("No budget set for this trip")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .padding()
        }
    }
}

struct TripDocumentsView: View {
    let trip: Trip
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Documents and compliance information will be shown here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
}

#Preview {
    let sampleTrip = Trip(
        ownerId: "user1",
        title: "European Adventure",
        scope: .international,
        duration: TripDuration(days: 7, nights: 6),
        startWindow: DateInterval(start: Date(), duration: 7 * 24 * 60 * 60),
        constraints: TripConstraints(budget: BudgetConstraint(total: Money(amount: 5000.0))),
        status: .draft
    )
    
    return TripDetailView(trip: sampleTrip)
        .environmentObject(TripsViewModel(service: MockTripsService()))
}