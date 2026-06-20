import SwiftUI
import MarketplaceService
import MapKit

/// Detailed view of a listing with Try Lab integration
/// Per Section 6 (Try Lab) and Section 16 (UX Flows)
public struct ListingDetailView: View {
    let listing: Listing
    @ObservedObject var viewModel: MarketplaceViewModel
    
    @State private var selectedImageIndex = 0
    @State private var showingTryLab = false
    @State private var showingMakeOffer = false
    @State private var showingReservation = false
    @State private var showingChat = false
    @State private var showingSeller = false
    @State private var showingShareSheet = false
    @State private var isSaved = false
    
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Image carousel
                TabView(selection: $selectedImageIndex) {
                    ForEach(Array(listing.images.enumerated()), id: \.offset) { index, imageUrl in
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.2))
                                .overlay(
                                    ProgressView()
                                )
                        }
                        .tag(index)
                    }
                }
                .frame(height: 300)
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                VStack(alignment: .leading, spacing: 16) {
                    // Price and condition
                    HStack {
                        Text(listing.price.displayAmount)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        ConditionBadge(condition: listing.condition)
                    }
                    
                    // Title
                    Text(listing.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Category and Try Lab capabilities
                    HStack {
                        CategoryBadge(category: listing.category)
                        
                        if !listing.category.tryLabCapabilities.isEmpty {
                            Button(action: { showingTryLab = true }) {
                                Label("Try Lab", systemImage: "sparkles")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Location
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading) {
                            if let neighborhood = listing.location.arrondissement {
                                Text(neighborhood)
                                    .font(.subheadline)
                            }
                            if let address = listing.location.addressLine {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Mini map
                        Map(coordinateRegion: .constant(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: listing.location.lat,
                                longitude: listing.location.lng
                            ),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )), annotationItems: [listing]) { _ in
                            MapMarker(coordinate: CLLocationCoordinate2D(
                                latitude: listing.location.lat,
                                longitude: listing.location.lng
                            ), tint: .blue)
                        }
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                        .disabled(true)
                    }
                    
                    Divider()
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        Text(listing.description)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Delivery options
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Delivery Options")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            if listing.deliveryOptions.meetup {
                                Label("Meet-up", systemImage: "figure.walk")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                            }
                            
                            if listing.deliveryOptions.courier {
                                Label("Courier", systemImage: "car")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Seller info
                    Button(action: { showingSeller = true }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading) {
                                Text("Seller")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("View Profile")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Attributes (if any)
                    if !listing.attributes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Details")
                                .font(.headline)
                            
                            ForEach(Array(listing.attributes.keys.sorted()), id: \.self) { key in
                                HStack {
                                    Text(key.capitalized)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(listing.attributes[key] ?? "")
                                        .fontWeight(.medium)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    
                    // Posted date
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        Text("Posted \(listing.createdAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    // Save button
                    Button(action: toggleSave) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    }
                    
                    // Share button
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Action buttons
            HStack(spacing: 12) {
                // Message seller
                Button(action: { showingChat = true }) {
                    Label("Message", systemImage: "bubble.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                // Make offer or reserve
                if listing.status == .active {
                    Button(action: { showingMakeOffer = true }) {
                        Label("Make Offer", systemImage: "tag")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.regularMaterial)
        }
        .sheet(isPresented: $showingTryLab) {
            TryLabView(listing: listing, viewModel: viewModel)
        }
        .sheet(isPresented: $showingMakeOffer) {
            MakeOfferView(listing: listing, viewModel: viewModel)
        }
        .sheet(isPresented: $showingReservation) {
            ReservationView(listing: listing, viewModel: viewModel)
        }
        .sheet(isPresented: $showingChat) {
            NavigationView {
                ChatPlaceholderView(userId: listing.sellerId, listingId: listing.id ?? "")
                    .navigationTitle("Message Seller")
                    .navigationBarItems(trailing: Button("Done") { showingChat = false })
            }
        }
        .sheet(isPresented: $showingSeller) {
            SellerProfileView(sellerId: listing.sellerId)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = URL(string: "liive://marketplace/listing/\(listing.id ?? "")") {
                ShareSheet(items: [url])
            }
        }
    }
    
    private func toggleSave() {
        isSaved.toggle()
        // Track interaction
        Task {
            // await viewModel.trackInteraction(type: isSaved ? .save : .unsave, entityId: listing.id)
        }
    }
}

// MARK: - Helper Views

struct ConditionBadge: View {
    let condition: ItemCondition
    
    var body: some View {
        Text(condition.displayName)
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(conditionColor.opacity(0.2))
            .foregroundColor(conditionColor)
            .cornerRadius(8)
    }
    
    private var conditionColor: Color {
        switch condition {
        case .new: return .green
        case .likeNew: return .blue
        case .good: return .orange
        case .fair: return .red
        }
    }
}

struct CategoryBadge: View {
    let category: ListingCategory
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: categoryIcon)
                .font(.caption)
            Text(category.displayName)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var categoryIcon: String {
        switch category {
        case .electronics: return "tv"
        case .furniture: return "sofa"
        case .apparel: return "tshirt"
        case .carParts: return "car"
        case .books: return "book"
        case .sports: return "sportscourt"
        case .toys: return "teddybear"
        case .appliances: return "washer"
        case .jewelry: return "sparkle"
        case .art: return "paintpalette"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Try Lab View

struct TryLabView: View {
    let listing: Listing
    @ObservedObject var viewModel: MarketplaceViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                switch listing.category {
                case .apparel:
                    ApparelTryOnView(listing: listing, viewModel: viewModel)
                case .carParts:
                    CarPartCompatibilityView(listing: listing, viewModel: viewModel)
                case .furniture:
                    FurnitureARPlacementView(listing: listing, viewModel: viewModel)
                default:
                    Text("Try Lab not available for this category")
                }
            }
            .navigationTitle("Try Lab")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

// MARK: - Make Offer View

struct MakeOfferView: View {
    let listing: Listing
    @ObservedObject var viewModel: MarketplaceViewModel
    @State private var offerAmount = ""
    @State private var isSubmitting = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Listing") {
                    HStack {
                        Text(listing.title)
                            .lineLimit(2)
                        Spacer()
                        Text(listing.price.displayAmount)
                            .fontWeight(.semibold)
                    }
                }
                
                Section("Your Offer") {
                    HStack {
                        Text(listing.price.currency)
                        TextField("Amount", text: $offerAmount)
                            .keyboardType(.numberPad)
                    }
                    
                    // Price analysis
                    if let amount = Int(offerAmount), amount > 0 {
                        let percentage = Double(amount) / Double(listing.price.amount) * 100
                        Text("\(Int(percentage))% of asking price")
                            .font(.caption)
                            .foregroundColor(percentage < 50 ? .red : percentage < 80 ? .orange : .green)
                    }
                }
                
                Section {
                    Button(action: submitOffer) {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Submit Offer")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(offerAmount.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Make Offer")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Submit") { submitOffer() }
                    .disabled(offerAmount.isEmpty || isSubmitting)
            )
        }
    }
    
    private func submitOffer() {
        guard let amount = Int(offerAmount), amount > 0 else { return }
        
        isSubmitting = true
        
        Task {
            do {
                let money = Money(amount: amount * 100, currency: listing.price.currency)
                _ = try await viewModel.makeOffer(listingId: listing.id ?? "", amount: money)
                dismiss()
            } catch {
                // Handle error
                isSubmitting = false
            }
        }
    }
}

// MARK: - Reservation View

struct ReservationView: View {
    let listing: Listing
    @ObservedObject var viewModel: MarketplaceViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Reservation Flow - To Be Implemented")
                .navigationTitle("Reserve Item")
                .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

// MARK: - Placeholder Views

struct ChatPlaceholderView: View {
    let userId: String
    let listingId: String
    
    var body: some View {
        VStack {
            Text("Chat with seller about listing")
            Text("User: \(userId)")
            Text("Listing: \(listingId)")
        }
    }
}

struct SellerProfileView: View {
    let sellerId: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Seller Profile")
                Text("ID: \(sellerId)")
            }
            .navigationTitle("Seller")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}