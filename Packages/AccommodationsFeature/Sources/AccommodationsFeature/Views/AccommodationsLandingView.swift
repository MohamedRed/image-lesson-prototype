import SwiftUI
import AccommodationsService

struct AccommodationsLandingView: View {
    @EnvironmentObject private var viewModel: AccommodationsViewModel
    @State private var showingSearch = false
    @State private var showingVoiceInput = false
    @State private var showingImport = false
    @State private var showingSaved = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                quickActionsSection
                recommendationsSection
                recentBookingsSection
            }
            .padding()
        }
        .navigationTitle("Accommodations")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingSaved = true
                } label: {
                    Image(systemName: "heart.circle")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            SearchView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingVoiceInput) {
            VoiceInputView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingImport) {
            ImportBookingView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingSaved) {
            SavedPropertiesView()
                .environmentObject(viewModel)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Find your perfect stay")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Discover hotels, apartments, and unique stays anywhere in the world")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                Button("Search destinations...") {
                    showingSearch = true
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button {
                    showingVoiceInput = true
                } label: {
                    Image(systemName: "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .onTapGesture {
                showingSearch = true
            }
            
            // Quick action buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ActionButton(
                    title: "Current Location",
                    icon: "location.circle.fill",
                    color: .blue
                ) {
                    viewModel.useCurrentLocation()
                    showingSearch = true
                }
                
                ActionButton(
                    title: "Import Booking",
                    icon: "square.and.arrow.down",
                    color: .green
                ) {
                    showingImport = true
                }
                
                ActionButton(
                    title: "Saved",
                    icon: "heart.circle.fill",
                    color: .red
                ) {
                    showingSaved = true
                }
            }
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.recommendations.isEmpty {
                HStack {
                    Text("Recommended for You")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("See All") {
                        // Navigate to full recommendations
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(viewModel.recommendations.prefix(5)), id: \.property.id) { recommendation in
                            RecommendationCard(recommendation: recommendation) {
                                viewModel.getPropertyDetails(recommendation.property)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var recentBookingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.bookings.isEmpty {
                HStack {
                    Text("Recent Bookings")
                        .font(.headline)
                    
                    Spacer()
                    
                    NavigationLink("View All") {
                        BookingsListView()
                            .environmentObject(viewModel)
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                
                ForEach(Array(viewModel.bookings.prefix(3)), id: \.id) { booking in
                    BookingCard(booking: booking)
                }
            } else {
                Text("No bookings yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
        }
    }
}

// MARK: - Supporting Views

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecommendationCard: View {
    let recommendation: RecommendedProperty
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Property image
                AsyncImage(url: URL(string: recommendation.property.photos.first?.url ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 200, height: 120)
                .clipped()
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.property.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    HStack {
                        if let rating = recommendation.property.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption)
                            }
                        }
                        
                        Spacer()
                        
                        if let priceRange = recommendation.property.priceRange {
                            let minInt = NSDecimalNumber(decimal: priceRange.min).intValue
                            Text("$\(minInt)+")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Text(recommendation.explanation)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 4)
                
                Spacer()
            }
            .frame(width: 200, height: 220)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BookingCard: View {
    let booking: Booking
    
    var body: some View {
        HStack(spacing: 12) {
            // Property image
            AsyncImage(url: URL(string: booking.propertyRef.photos.first?.url ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
            }
            .frame(width: 60, height: 60)
            .clipped()
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(booking.propertyRef.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(booking.dateRange.startDate.formatted(date: .abbreviated, time: .omitted)) - \(booking.dateRange.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    StatusBadge(status: booking.status)
                    
                    Spacer()
                    
                    Text("$\(NSDecimalNumber(decimal: booking.priceSnapshot.totalPrice).intValue)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatusBadge: View {
    let status: BookingStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .confirmed:
            return .green.opacity(0.2)
        case .pending:
            return .orange.opacity(0.2)
        case .cancelled:
            return .red.opacity(0.2)
        case .completed:
            return .blue.opacity(0.2)
        default:
            return .gray.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch status {
        case .confirmed:
            return .green
        case .pending:
            return .orange
        case .cancelled:
            return .red
        case .completed:
            return .blue
        default:
            return .gray
        }
    }
}

#Preview {
    NavigationStack {
        AccommodationsLandingView()
            .environmentObject(AccommodationsViewModel())
    }
}