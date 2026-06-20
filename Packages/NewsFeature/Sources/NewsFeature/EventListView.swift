import SwiftUI
import NewsService

struct EventListView: View {
    let events: [NewsEventSummary]
    let isLoading: Bool
    let section: NewsSection
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void
    
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if events.isEmpty && !isLoading {
                    emptyStateView
                } else {
                    ForEach(events) { event in
                        NavigationLink(value: event) {
                            EventCardView(event: event, section: section)
                        }
                    }
                    
                    if isLoading && !events.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    
                    if !events.isEmpty {
                        Button(action: {
                            Task { await onLoadMore() }
                        }) {
                            Text("Load More")
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                                .padding()
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await onRefresh()
        }
        
        .overlay {
            if isLoading && events.isEmpty {
                ProgressView("Loading news...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: section.icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No \(section.title) Available")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(section == .good ? 
                 "Check back soon for positive stories and progress updates" :
                 "No challenging news to report right now")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                Task { await onRefresh() }
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(section.color.opacity(0.2))
                    .foregroundColor(section.color)
                    .cornerRadius(20)
            }
        }
        .padding(.vertical, 60)
    }
}

struct EventCardView: View {
    let event: NewsEventSummary
    let section: NewsSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(event.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    HStack(spacing: 12) {
                        if let impact = event.impact {
                            if let peopleAffected = impact.peopleAffected {
                                Label("\(formatNumber(peopleAffected)) affected", systemImage: "person.2")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !event.regions.isEmpty {
                            Label(event.regions.first ?? "", systemImage: "location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Label(formatTime(event.lastUpdatedAt), systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let imageUrl = event.thumbnailUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.2))
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                }
            }
            
            HStack(spacing: 8) {
                ForEach(event.tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(section.color.opacity(0.1))
                        .foregroundColor(section.color)
                        .cornerRadius(10)
                }
                
                if event.perspectives.count > 0 {
                    Spacer()
                    Label("\(event.perspectives.count) perspectives", systemImage: "person.3")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        
        if number >= 1_000_000 {
            return "\(formatter.string(from: NSNumber(value: Double(number) / 1_000_000)) ?? "0")M"
        } else if number >= 1_000 {
            return "\(formatter.string(from: NSNumber(value: Double(number) / 1_000)) ?? "0")K"
        }
        return "\(number)"
    }
    
    private func formatTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 {
            return "\(Int(diff / 60))m ago"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))h ago"
        } else {
            return "\(Int(diff / 86400))d ago"
        }
    }
}