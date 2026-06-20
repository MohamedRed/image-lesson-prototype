import SwiftUI
import AccommodationsService

// MARK: - Date Picker View

struct DatePickerView: View {
    @EnvironmentObject private var viewModel: AccommodationsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var checkInDate: Date
    @State private var checkOutDate: Date
    
    init() {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        _checkInDate = State(initialValue: today)
        _checkOutDate = State(initialValue: tomorrow)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("When are you traveling?")
                        .font(.headline)
                    
                    VStack(spacing: 16) {
                        DateSection(
                            title: "Check-in",
                            date: $checkInDate,
                            minimumDate: Date()
                        )
                        
                        DateSection(
                            title: "Check-out",
                            date: $checkOutDate,
                            minimumDate: Calendar.current.date(byAdding: .day, value: 1, to: checkInDate) ?? checkInDate
                        )
                    }
                }
                
                VStack(spacing: 8) {
                    Text("\(numberOfNights) night\(numberOfNights == 1 ? "" : "s")")
                        .font(.headline)
                    
                    Text(dateRangeString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Select Dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.updateDates(checkIn: checkInDate, checkOut: checkOutDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            checkInDate = viewModel.searchRequest.dateRange.startDate
            checkOutDate = viewModel.searchRequest.dateRange.endDate
        }
    }
    
    private var numberOfNights: Int {
        Calendar.current.dateComponents([.day], from: checkInDate, to: checkOutDate).day ?? 0
    }
    
    private var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        return "\(formatter.string(from: checkInDate)) - \(formatter.string(from: checkOutDate))"
    }
}

struct DateSection: View {
    let title: String
    @Binding var date: Date
    let minimumDate: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            DatePicker(
                "",
                selection: $date,
                in: minimumDate...,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
        }
    }
}

// MARK: - Guest Picker View

struct GuestPickerView: View {
    @EnvironmentObject private var viewModel: AccommodationsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var adults: Int = 1
    @State private var children: Int = 0
    @State private var rooms: Int = 1
    @State private var childrenAges: [Int] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        guestCountersSection
                        
                        if children > 0 {
                            childrenAgesSection
                        }
                        
                        guestSummarySection
                    }
                    .padding()
                }
                
                bottomActionButton
            }
            .navigationTitle("Guests & Rooms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            let guests = viewModel.searchRequest.guests
            adults = guests.adults
            children = guests.children
            rooms = guests.rooms
            childrenAges = guests.childrenAges
        }
    }
    
    private var guestCountersSection: some View {
        VStack(spacing: 20) {
            GuestCounter(
                title: "Adults",
                subtitle: "Ages 13+",
                count: $adults,
                minimumCount: 1,
                maximumCount: 8
            )
            
            GuestCounter(
                title: "Children",
                subtitle: "Ages 0-12",
                count: $children,
                minimumCount: 0,
                maximumCount: 8
            )
            .onChange(of: children) { newValue in
                updateChildrenAges(newValue)
            }
            
            GuestCounter(
                title: "Rooms",
                subtitle: "",
                count: $rooms,
                minimumCount: 1,
                maximumCount: 4
            )
        }
    }
    
    private var childrenAgesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Children's Ages")
                .font(.headline)
            
            ForEach(0..<children, id: \.self) { index in
                HStack {
                    Text("Child \(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Picker("Age", selection: Binding(
                        get: { childrenAges[safe: index] ?? 0 },
                        set: { newValue in
                            if childrenAges.indices.contains(index) {
                                childrenAges[index] = newValue
                            }
                        }
                    )) {
                        ForEach(0...12, id: \.self) { age in
                            Text("\(age) year\(age == 1 ? "" : "s")")
                                .tag(age)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var guestSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("\(adults) adult\(adults == 1 ? "" : "s")")
                    .font(.subheadline)
                
                if children > 0 {
                    Text("\(children) child\(children == 1 ? "" : "ren")")
                        .font(.subheadline)
                }
                
                if rooms > 1 {
                    Text("\(rooms) rooms")
                        .font(.subheadline)
                }
            }
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var bottomActionButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button("Done") {
                let guestConfig = GuestConfiguration(
                    rooms: rooms,
                    adults: adults,
                    children: children,
                    childrenAges: childrenAges
                )
                viewModel.updateGuests(guestConfig)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    private func updateChildrenAges(_ newChildrenCount: Int) {
        if newChildrenCount > childrenAges.count {
            // Add ages for new children
            childrenAges.append(contentsOf: Array(repeating: 0, count: newChildrenCount - childrenAges.count))
        } else if newChildrenCount < childrenAges.count {
            // Remove ages for removed children
            childrenAges = Array(childrenAges.prefix(newChildrenCount))
        }
    }
}

struct GuestCounter: View {
    let title: String
    let subtitle: String
    @Binding var count: Int
    let minimumCount: Int
    let maximumCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    if count > minimumCount {
                        count -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(count > minimumCount ? .accentColor : .gray)
                }
                .disabled(count <= minimumCount)
                
                Text("\(count)")
                    .font(.headline)
                    .frame(minWidth: 30)
                
                Button {
                    if count < maximumCount {
                        count += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(count < maximumCount ? .accentColor : .gray)
                }
                .disabled(count >= maximumCount)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Filters View

struct FiltersView: View {
    @EnvironmentObject private var viewModel: AccommodationsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var budgetMin: Double = 0
    @State private var budgetMax: Double = 1000
    @State private var selectedRating: Double = 0
    @State private var selectedTypes: Set<AccommodationType> = []
    @State private var selectedAmenities: Set<String> = []
    
    private let commonAmenities = [
        "Free WiFi", "Free Parking", "Swimming Pool", "Fitness Center",
        "Air Conditioning", "Restaurant", "Bar", "Room Service",
        "Business Center", "Pet Friendly", "Spa", "Kitchen"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    priceRangeSection
                    ratingSection
                    accommodationTypesSection
                    amenitiesSection
                }
                .padding()
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        resetFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        applyFilters()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadCurrentFilters()
        }
    }
    
    private var priceRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Price Range per Night")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("$\(Int(budgetMin))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("$\(Int(budgetMax))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                // Custom range slider would go here
                // For now, using basic sliders
                VStack {
                    HStack {
                        Text("Min: $\(Int(budgetMin))")
                            .font(.caption)
                        Spacer()
                    }
                    Slider(value: $budgetMin, in: 0...500, step: 10)
                }
                
                VStack {
                    HStack {
                        Text("Max: $\(Int(budgetMax))")
                            .font(.caption)
                        Spacer()
                    }
                    Slider(value: $budgetMax, in: budgetMin...1000, step: 10)
                }
            }
        }
    }
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Minimum Rating")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    ForEach(0..<5) { index in
                        Button {
                            selectedRating = Double(index + 1)
                        } label: {
                            Image(systemName: selectedRating >= Double(index + 1) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.title2)
                        }
                    }
                    
                    Spacer()
                    
                    if selectedRating > 0 {
                        Button("Clear") {
                            selectedRating = 0
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                }
                
                if selectedRating > 0 {
                    Text("\(Int(selectedRating))+ stars")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private var accommodationTypesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Property Types")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(AccommodationType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        isSelected: selectedTypes.contains(type)
                    ) {
                        if selectedTypes.contains(type) {
                            selectedTypes.remove(type)
                        } else {
                            selectedTypes.insert(type)
                        }
                    }
                }
            }
        }
    }
    
    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Amenities")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(commonAmenities, id: \.self) { amenity in
                    FilterChip(
                        title: amenity,
                        isSelected: selectedAmenities.contains(amenity)
                    ) {
                        if selectedAmenities.contains(amenity) {
                            selectedAmenities.remove(amenity)
                        } else {
                            selectedAmenities.insert(amenity)
                        }
                    }
                }
            }
        }
    }
    
    private func loadCurrentFilters() {
        let filters = viewModel.selectedFilters
        if let min = filters.budgetMin as Decimal? { budgetMin = NSDecimalNumber(decimal: min).doubleValue } else { budgetMin = 0 }
        if let max = filters.budgetMax as Decimal? { budgetMax = NSDecimalNumber(decimal: max).doubleValue } else { budgetMax = 1000 }
        selectedRating = filters.rating ?? 0
        selectedTypes = Set(filters.types ?? [])
        selectedAmenities = Set(filters.amenities ?? [])
    }
    
    private func applyFilters() {
        let filters = SearchFilters(
            budgetMin: budgetMin > 0 ? Decimal(budgetMin) : nil,
            budgetMax: budgetMax < 1000 ? Decimal(budgetMax) : nil,
            rating: selectedRating > 0 ? selectedRating : nil,
            amenities: selectedAmenities.isEmpty ? nil : Array(selectedAmenities),
            types: selectedTypes.isEmpty ? nil : Array(selectedTypes)
        )
        
        viewModel.updateFilters(filters)
    }
    
    private func resetFilters() {
        budgetMin = 0
        budgetMax = 1000
        selectedRating = 0
        selectedTypes = []
        selectedAmenities = []
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Additional Supporting Views

struct AmenitiesView: View {
    @Environment(\.dismiss) private var dismiss
    let amenities: [String]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(amenities, id: \.self) { amenity in
                        AmenityRow(name: amenity)
                    }
                }
                .padding()
            }
            .navigationTitle("All Amenities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AmenityRow: View {
    let name: String
    
    var body: some View {
        HStack {
            Image(systemName: amenityIcon(for: name))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(name)
                .font(.subheadline)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
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

struct ReviewsView: View {
    @Environment(\.dismiss) private var dismiss
    let property: AccommodationProperty
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Review summary
                    if let rating = property.rating {
                        VStack(spacing: 12) {
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 48, weight: .bold))
                            
                            HStack(spacing: 2) {
                                ForEach(0..<5) { index in
                                    Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                }
                            }
                            
                            Text("Based on \(property.reviewsCount) reviews")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Mock reviews
                    ForEach(0..<5, id: \.self) { index in
                        ReviewCard(
                            rating: [5, 4, 5, 3, 4][index],
                            title: ["Excellent stay!", "Good location", "Clean and comfortable", "Average", "Great value"][index],
                            comment: ["Had a wonderful time. The staff was very friendly and helpful.", "Perfect location near the city center.", "Room was clean and bed was comfortable.", "It was okay, nothing special.", "Great value for money, would stay again."][index],
                            author: ["John D.", "Sarah M.", "Mike R.", "Lisa K.", "Tom W."][index],
                            date: Date()
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ReviewCard: View {
    let rating: Int
    let title: String
    let comment: String
    let author: String
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < rating ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(title)
                .font(.headline)
            
            Text(comment)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("— \(author)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
}

struct BookingsListView: View {
    @EnvironmentObject private var viewModel: AccommodationsViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.bookings, id: \.id) { booking in
                BookingListRow(booking: booking)
            }
        }
        .navigationTitle("My Bookings")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct BookingListRow: View {
    let booking: Booking
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: booking.propertyRef.photos.first?.url ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
            }
            .frame(width: 80, height: 80)
            .clipped()
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(booking.propertyRef.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(booking.propertyRef.address.city)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    StatusBadge(status: booking.status)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$\(NSDecimalNumber(decimal: booking.priceSnapshot.totalPrice).intValue)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("total")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        DatePickerView()
            .environmentObject(AccommodationsViewModel())
    }
}