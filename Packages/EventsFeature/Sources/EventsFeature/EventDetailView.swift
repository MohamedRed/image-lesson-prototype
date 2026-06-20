import SwiftUI
import EventsService
import FriendsService

struct EventDetailView: View {
    let event: Event
    @ObservedObject var viewModel: EventsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showGroupCreation = false
    @State private var showTicketLinking = false
    @State private var selectedSession: EventSession?
    @State private var availableSessions: [EventSession] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero Image
                    if let imageUrl = event.images.first {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(height: 250)
                        .cornerRadius(12)
                        .clipped()
                    }
                    
                    // Event Info
                    VStack(alignment: .leading, spacing: 12) {
                        // Title and Category
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                Text(event.category.rawValue.capitalized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            
                            Spacer()
                            
                            // Save Button
                            Button {
                                Task {
                                    await viewModel.saveEvent(event)
                                }
                            } label: {
                                Image(systemName: "bookmark")
                                    .font(.title2)
                            }
                        }
                        
                        // Date, Time, Location
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.accentColor)
                                Text(event.startAt, style: .date)
                                    .fontWeight(.medium)
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(event.startAt, style: .time)
                            }
                            
                            HStack {
                                Image(systemName: "location")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.venueName)
                                        .fontWeight(.medium)
                                    if let neighborhood = event.neighborhood {
                                        Text(neighborhood)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            if !event.indoor {
                                HStack {
                                    Image(systemName: "sun.max")
                                        .foregroundColor(.orange)
                                    Text("Outdoor Event")
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .font(.subheadline)
                        
                        Divider()
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.headline)
                            
                            Text(event.description)
                                .font(.body)
                        }
                        
                        if !event.rules.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Rules & Guidelines")
                                    .font(.headline)
                                
                                ForEach(event.rules, id: \.self) { rule in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        Text(rule)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Price Tiers
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tickets")
                                .font(.headline)
                            
                            ForEach(event.priceTiers, id: \.name) { tier in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tier.name)
                                            .fontWeight(.semibold)
                                        
                                        if let description = tier.description {
                                            Text(description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(Int(tier.priceMAD)) \(tier.currency)")
                                        .fontWeight(.bold)
                                        .foregroundColor(.accentColor)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        
                        if !availableSessions.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Available Sessions")
                                    .font(.headline)
                                
                                ForEach(availableSessions) { session in
                                    SessionCard(
                                        session: session,
                                        isSelected: selectedSession?.id == session.id
                                    ) {
                                        selectedSession = session
                                    }
                                }
                            }
                        }
                        
                        // Age Restrictions
                        if let ageRestrictions = event.ageRestrictions {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Age Requirements")
                                    .font(.headline)
                                
                                if let minAge = ageRestrictions.minimumAge {
                                    Text("Minimum age: \(minAge) years")
                                        .font(.subheadline)
                                }
                                
                                if ageRestrictions.requiresGuardian {
                                    Text("Children must be accompanied by an adult")
                                        .font(.subheadline)
                                }
                            }
                        }
                        
                        // Tags
                        if !event.tags.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tags")
                                    .font(.headline)
                                
                                FlowLayout(alignment: .leading, spacing: 8) {
                                    ForEach(event.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor.opacity(0.1))
                                            .foregroundColor(.accentColor)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.shareEvent(event)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Create Group") {
                            showGroupCreation = true
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        
                        Button("Link Tickets") {
                            showTicketLinking = true
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .sheet(isPresented: $showGroupCreation) {
            CreateGroupView(event: event, viewModel: viewModel)
        }
        .sheet(isPresented: $showTicketLinking) {
            LinkTicketsView(event: event, viewModel: viewModel)
        }
        .task {
            await loadEventSessions()
        }
    }
    
    private func loadEventSessions() async {
        do {
            let sessions = try await viewModel.getEventSessions(eventId: event.id!)
            await MainActor.run {
                self.availableSessions = sessions
            }
        } catch {
            // Handle error silently or show in UI
        }
    }
}

struct SessionCard: View {
    let session: EventSession
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.startAt, style: .date)
                        .fontWeight(.semibold)
                    
                    Text(session.startAt, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(session.status.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor(session.status))
                    
                    Text("Available seats")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                isSelected 
                    ? Color.accentColor.opacity(0.1) 
                    : Color(.systemGray6)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .scheduled: return .green
        case .limited: return .orange
        case .soldOut: return .red
        case .cancelled: return .gray
        }
    }
}

// Custom FlowLayout for tags
struct FlowLayout: Layout {
    let alignment: Alignment
    let spacing: CGFloat
    
    init(alignment: Alignment = .center, spacing: CGFloat = 8) {
        self.alignment = alignment
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                         proposal: ProposedViewSize(result.sizes[index]))
        }
    }
}

struct FlowResult {
    let size: CGSize
    let positions: [CGPoint]
    let sizes: [CGSize]
    
    init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
        var sizes: [CGSize] = []
        var positions: [CGPoint] = []
        
        var currentRow = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentRow += 1
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            sizes.append(size)
            
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        
        self.positions = positions
        self.sizes = sizes
        self.size = CGSize(width: maxWidth, height: currentY + rowHeight)
    }
}

#if DEBUG
#Preview {
    EventDetailView(
        event: Event(
            promoterId: "test",
            title: "Jazz Night at Blue Note",
            category: .music,
            description: "An evening of smooth jazz featuring local artists",
            priceTiers: [
                PriceTier(name: "General", priceMAD: 150),
                PriceTier(name: "VIP", priceMAD: 300)
            ],
            location: .init(latitude: 33.5731, longitude: -7.5898),
            venueName: "Blue Note Casablanca",
            startAt: Date(),
            endAt: Date().addingTimeInterval(3600 * 3),
            seating: SeatingInfo()
        ),
        viewModel: EventsViewModel()
    )
}
#endif