import SwiftUI
import EventsService

struct DiscoveryView: View {
    @ObservedObject var viewModel: EventsViewModel
    @State private var selectedCategory: EventCategory?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Hero section with trending events
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Trending Now")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button("See All") {
                            // TODO: Show trending events list
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(viewModel.trendingEvents) { event in
                                TrendingEventCard(event: event) {
                                    viewModel.selectEvent(event)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.horizontal, -16)
                }
                
                // Category filters
                VStack(alignment: .leading, spacing: 12) {
                    Text("Categories")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(EventCategory.allCases, id: \.self) { category in
                                CategoryChip(
                                    category: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = selectedCategory == category ? nil : category
                                    
                                    if let category = selectedCategory {
                                        Task {
                                            await viewModel.loadEventsByCategory(category)
                                        }
                                    } else {
                                        Task {
                                            await viewModel.loadUpcomingEvents()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.horizontal, -16)
                }
                
                // Upcoming events
                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedCategory?.rawValue.capitalized ?? "Upcoming Events")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(viewModel.upcomingEvents) { event in
                            EventCard(event: event) {
                                viewModel.selectEvent(event)
                            }
                        }
                    }
                }
                
                // AI Suggestions
                if let suggestions = viewModel.aiResponse?.suggestedEvents, !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.purple)
                            Text("AI Recommendations")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        ForEach(suggestions) { event in
                            EventListItem(event: event) {
                                viewModel.selectEvent(event)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadUpcomingEvents()
        }
        .task {
            if viewModel.upcomingEvents.isEmpty {
                await viewModel.loadUpcomingEvents()
            }
        }
    }
}

// MARK: - Supporting Views

struct TrendingEventCard: View {
    let event: Event
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: event.images.first ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 280, height: 160)
                .cornerRadius(12)
                .clipped()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    Text(event.venueName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                        
                        Text(event.startAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                .frame(width: 280, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CategoryChip: View {
    let category: EventCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: iconForCategory(category))
                    .font(.caption)
                
                Text(category.rawValue.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? Color.accentColor : Color.gray.opacity(0.1)
            )
            .foregroundColor(
                isSelected ? .white : .primary
            )
            .cornerRadius(16)
        }
    }
    
    private func iconForCategory(_ category: EventCategory) -> String {
        switch category {
        case .music: return "music.note"
        case .culture: return "theatermasks"
        case .sports: return "sportscourt"
        case .theater: return "drama.masks"
        case .conference: return "mic"
        case .family: return "person.3"
        case .other: return "star"
        }
    }
}

struct EventCard: View {
    let event: Event
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: event.images.first ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(height: 120)
                .cornerRadius(8)
                .clipped()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    Text(event.startAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let minPrice = event.priceTiers.map(\.priceMAD).min() {
                        Text("From \(Int(minPrice)) MAD")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct EventListItem: View {
    let event: Event
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: event.images.first ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .clipped()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    Text(event.venueName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(event.startAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let minPrice = event.priceTiers.map(\.priceMAD).min() {
                    VStack(alignment: .trailing) {
                        Text("From")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(minPrice)) MAD")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    DiscoveryView(viewModel: EventsViewModel())
}
#endif