import SwiftUI
import AccommodationsService
import CoreLocation

struct PropertyDetailsView: View {
    @EnvironmentObject private var viewModel: AccommodationsViewModel
    @Environment(\.dismiss) private var dismiss
    
    let property: AccommodationProperty
    
    @State private var selectedRoomType: RoomType?
    @State private var selectedRatePlan: RatePlan?
    @State private var showingBooking = false
    @State private var showingPhotoGallery = false
    @State private var showingAllAmenities = false
    @State private var showingReviews = false
    @State private var currentPhotoIndex = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    photoSection
                    propertyInfoSection
                    amenitiesSection
                    roomsSection
                    reviewsSection
                    policiesSection
                    locationSection
                }
            }
            .navigationTitle(property.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.PropertyDetails.closeButton)
                    .accessibilityLabel("Close property details")
                    .accessibilityHint("Returns to search results")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Add to favorites
                    } label: {
                        Image(systemName: "heart")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.PropertyDetails.favoriteButton)
                    .accessibilityLabel("Add to favorites")
                    .accessibilityHint("Double tap to save this property to your favorites")
                }
            }
            .sheet(isPresented: $showingPhotoGallery) {
                PhotoGalleryView(photos: property.photos, currentIndex: $currentPhotoIndex)
            }
            .sheet(isPresented: $showingBooking) {
                if let roomType = selectedRoomType, let ratePlan = selectedRatePlan {
                    BookingView(
                        property: property,
                        roomType: roomType,
                        ratePlan: ratePlan
                    )
                    .environmentObject(viewModel)
                }
            }
            .sheet(isPresented: $showingAllAmenities) {
                AmenitiesView(amenities: property.amenities)
            }
            .sheet(isPresented: $showingReviews) {
                ReviewsView(property: property)
            }
        }
        .onAppear {
            viewModel.getPropertyDetails(property)
        }
    }
    
    // MARK: - Photo Section
    
    private var photoSection: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $currentPhotoIndex) {
                ForEach(Array(property.photos.enumerated()), id: \.offset) { index, photo in
                    AsyncImage(url: URL(string: photo.url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                    }
                    .clipped()
                    .tag(index)
                }
            }
            .frame(height: 300)
            .tabViewStyle(PageTabViewStyle())
            .onTapGesture {
                showingPhotoGallery = true
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.PropertyDetails.photoGallery)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityHelper.photoGalleryLabel(
                index: currentPhotoIndex,
                total: property.photos.count,
                caption: property.photos[safe: currentPhotoIndex]?.caption
            ))
            .accessibilityHint("Double tap to open photo gallery")
            .accessibilityAddTraits(.isButton)
            
            // Photo counter
            if property.photos.count > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "photo.stack")
                        .font(.caption)
                    Text("\(currentPhotoIndex + 1)/\(property.photos.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding()
            }
        }
    }
    
    // MARK: - Property Info Section
    
    private var propertyInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(property.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier(AccessibilityIdentifiers.PropertyDetails.propertyName)
                        .accessibleHeading(level: .h1)
                    
                    Text(property.address.formattedAddress)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(property.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let rating = property.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                                .accessibilityHidden(true)
                            
                            Text(String(format: "%.1f", rating))
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(AccessibilityHelper.starRatingLabel(rating: rating))
                        .accessibilityIdentifier(AccessibilityIdentifiers.PropertyDetails.propertyRating)
                        
                        Text("\(property.reviewsCount) reviews")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityLabel("\(property.reviewsCount) customer reviews")
                    }
                    
                    if let priceRange = property.priceRange {
                        VStack(alignment: .trailing, spacing: 2) {
                            let minInt = NSDecimalNumber(decimal: priceRange.min).intValue
                            Text("from $\(minInt)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("per night")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Brand info
            if let brand = property.brand {
                Label(brand, systemImage: "building.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Hotel brand: \(brand)")
            }
            
            // Check-in/out times
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Check-in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(property.checkInTime)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Check-in time: \(property.checkInTime)")
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Check-out")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(property.checkOutTime)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Check-out time: \(property.checkOutTime)")
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Amenities Section
    
    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Amenities")
                    .font(.headline)
                    .accessibleHeading(level: .h2)
                
                Spacer()
                
                if property.amenities.count > 6 {
                    Button("See all (\(property.amenities.count))") {
                        showingAllAmenities = true
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .accessibilityLabel("View all \(property.amenities.count) amenities")
                    .accessibilityHint("Double tap to see complete list of amenities")
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(Array(property.amenities.prefix(6)), id: \.self) { amenity in
                    HStack {
                        Image(systemName: amenityIcon(for: amenity))
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                            .accessibilityHidden(true)
                        
                        Text(amenity)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Amenity: \(amenity)")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .accessibilityIdentifier(AccessibilityIdentifiers.PropertyDetails.amenitiesList)
    }
    
    // MARK: - Rooms Section
    
    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Rooms")
                .font(.headline)
                .accessibleHeading(level: .h2)
                .accessibilityIdentifier(AccessibilityIdentifiers.PropertyDetails.roomTypesList)
            
            if let details = viewModel.propertyDetails {
                ForEach(details.roomTypes, id: \.id) { roomType in
                    RoomTypeCard(
                        roomType: roomType,
                        ratePlans: details.ratePlans.filter { plan in
                            // Filter rate plans for this room type
                            true // Simplified - would need proper filtering logic
                        },
                        isSelected: selectedRoomType?.id == roomType.id
                    ) { selectedPlan in
                        selectedRoomType = roomType
                        selectedRatePlan = selectedPlan
                        showingBooking = true
                    }
                }
            } else if viewModel.isLoading {
                ProgressView("Loading room details...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .accessibilityLabel(AccessibilityHelper.loadingStateLabel(action: "room details"))
            } else {
                Text("Room details not available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .accessibilityLabel(AccessibilityHelper.emptyStateLabel(content: "room details"))
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Reviews Section
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reviews")
                    .font(.headline)
                    .accessibleHeading(level: .h2)
                
                Spacer()
                
                Button("See all reviews") {
                    showingReviews = true
                }
                .font(.caption)
                .foregroundColor(.accentColor)
                .accessibilityLabel("View all customer reviews")
                .accessibilityHint("Double tap to see detailed reviews from other guests")
            }
            
            if let rating = property.rating {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", rating))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(AccessibilityHelper.starRatingLabel(rating: rating))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(property.reviewsCount) reviews")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Excellent rating")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(property.reviewsCount) customer reviews with excellent rating")
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .accessibilityIdentifier(AccessibilityIdentifiers.PropertyDetails.reviewsSection)
    }
    
    // MARK: - Policies Section
    
    private var policiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Policies")
                .font(.headline)
                .accessibleHeading(level: .h2)
            
            VStack(alignment: .leading, spacing: 8) {
                PolicyRow(
                    icon: "xmark.circle",
                    title: "Cancellation",
                    description: property.policies.cancellationPolicy.description
                )
                
                PolicyRow(
                    icon: property.policies.childrenAllowed ? "checkmark.circle.fill" : "xmark.circle.fill",
                    title: "Children",
                    description: property.policies.childrenAllowed ? "Children allowed" : "No children",
                    iconColor: property.policies.childrenAllowed ? .green : .red
                )
                
                PolicyRow(
                    icon: property.policies.petsAllowed ? "checkmark.circle.fill" : "xmark.circle.fill",
                    title: "Pets",
                    description: property.policies.petsAllowed ? "Pets allowed" : "No pets",
                    iconColor: property.policies.petsAllowed ? .green : .red
                )
                
                PolicyRow(
                    icon: property.policies.smokingAllowed ? "checkmark.circle.fill" : "xmark.circle.fill",
                    title: "Smoking",
                    description: property.policies.smokingAllowed ? "Smoking allowed" : "No smoking",
                    iconColor: property.policies.smokingAllowed ? .green : .red
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .accessibilityIdentifier(AccessibilityIdentifiers.PropertyDetails.policiesSection)
    }
    
    // MARK: - Location Section
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
                .accessibleHeading(level: .h2)
            
            // Simple map placeholder - would integrate with actual map
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 200)
                .cornerRadius(12)
                .overlay(
                    VStack {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        
                        Text("Map View")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
                .accessibilityLabel("Map showing property location")
                .accessibilityHint("Interactive map would be available here")
            
            Text(property.address.formattedAddress)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityLabel("Property address: \(property.address.formattedAddress)")
            
            Button("Get directions") {
                // Open in Maps app
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Get directions to property")
            .accessibilityHint("Opens navigation app with directions")
        }
        .padding()
        .background(Color(.systemGray6))
        .accessibilityIdentifier(AccessibilityIdentifiers.PropertyDetails.locationSection)
    }
    
    // MARK: - Helper Functions
    
    private func amenityIcon(for amenity: String) -> String {
        switch amenity.lowercased() {
        case let str where str.contains("wifi"):
            return "wifi"
        case let str where str.contains("pool"):
            return "figure.pool.swim"
        case let str where str.contains("gym"), let str where str.contains("fitness"):
            return "figure.strengthtraining.traditional"
        case let str where str.contains("spa"):
            return "leaf"
        case let str where str.contains("restaurant"):
            return "fork.knife"
        case let str where str.contains("parking"):
            return "car"
        case let str where str.contains("air conditioning"), let str where str.contains("ac"):
            return "snow"
        case let str where str.contains("kitchen"):
            return "oven"
        default:
            return "checkmark.circle"
        }
    }
}

// MARK: - Supporting Views

struct RoomTypeCard: View {
    let roomType: RoomType
    let ratePlans: [RatePlan]
    let isSelected: Bool
    let onSelectRatePlan: (RatePlan) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Room type header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(roomType.name)
                        .font(.headline)
                        .accessibleHeading(level: .h3)
                    
                    Text("Sleeps \(roomType.capacity.total)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let size = roomType.size {
                    Text(size.displayString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Room size: \(size.displayString)")
                }
            }
            
            // Bed configuration
            if !roomType.beds.isEmpty {
                HStack {
                    ForEach(roomType.beds, id: \.type) { bed in
                        Text("\(bed.count) \(bed.type.displayName)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                            .accessibilityLabel("\(bed.count) \(bed.type.displayName) bed")
                    }
                    
                    Spacer()
                }
            }
            
            // Rate plans
            if let firstRatePlan = ratePlans.first {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(firstRatePlan.mealPlan.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(firstRatePlan.cancellationPolicy.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button("Select") {
                        onSelectRatePlan(firstRatePlan)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel("Select \(roomType.name)")
                    .accessibilityHint("Double tap to book this room type")
                    .accessibilityIdentifier(AccessibilityIdentifiers.PropertyDetails.roomSelectButton(roomType.id))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.PropertyDetails.roomTypeCard(roomType.id))
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

struct PolicyRow: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    
    init(icon: String, title: String, description: String, iconColor: Color = .accentColor) {
        self.icon = icon
        self.title = title
        self.description = description
        self.iconColor = iconColor
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(description)")
    }
}

#Preview {
    NavigationStack {
        PropertyDetailsView(property: AccommodationProperty(
            id: "test-property",
            providerRefs: [],
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
            amenities: ["WiFi", "Pool", "Gym", "Spa", "Restaurant", "Parking"],
            safetyFeatures: [],
            checkInTime: "15:00",
            checkOutTime: "11:00",
            policies: PropertyPolicies(
                cancellationPolicy: CancellationPolicy(
                    type: .flexible,
                    description: "Free cancellation up to 24 hours before check-in"
                )
            )
        ))
        .environmentObject(AccommodationsViewModel())
    }
}