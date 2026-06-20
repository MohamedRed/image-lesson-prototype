import SwiftUI
import NewsService

struct EventDetailView: View {
    let eventId: String
    private let service: NewsServicing
    @StateObject private var viewModel: EventDetailViewModel
    @State private var selectedPerspective: Int = 0
    @State private var showingArticles = false
    @State private var showingComments = false
    
    init(eventId: String, service: NewsServicing) {
        self.eventId = eventId
        self.service = service
        self._viewModel = StateObject(wrappedValue: EventDetailViewModel(eventId: eventId, service: service))
    }
    
    var body: some View {
        ScrollView {
            if let event = viewModel.event {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection(event: event)
                    
                    if let context = event.historicalContext {
                        historicalContextSection(context: context)
                    }
                    
                    if !event.perspectives.isEmpty {
                        perspectivesSection(perspectives: event.perspectives)
                    }
                    
                    if event.goodness == "challenging", !event.solutions.isEmpty {
                        solutionsSection(solutions: event.solutions)
                    }
                    
                    articlesButton(count: viewModel.articles.count)
                    
                    commentsButton
                }
                .padding()
            } else if viewModel.isLoading {
                ProgressView("Loading event details...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if viewModel.error != nil {
                ErrorView(message: viewModel.error ?? "Failed to load event") {
                    Task { await viewModel.loadEvent() }
                }
                .padding(.top, 100)
            }
        }
        .navigationTitle("News Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingArticles) {
            ArticleListView(articles: viewModel.articles, eventTitle: viewModel.event?.title ?? "")
        }
        .sheet(isPresented: $showingComments) {
            if let event = viewModel.event {
                CommentThreadView(
                    parentCollection: "newsEvents",
                    parentId: eventId,
                    title: event.title,
                    service: service
                )
            }
        }
        .onAppear {
            Task {
                await viewModel.loadEvent()
                await viewModel.loadArticles()
            }
        }
    }
    
    private func headerSection(event: NewsEventDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(event.goodness == "good" ? "Good News" : "Challenging News",
                      systemImage: event.goodness == "good" ? "sun.max.fill" : "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(event.goodness == "good" ? .green : .orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((event.goodness == "good" ? Color.green : Color.orange).opacity(0.1))
                    .cornerRadius(12)
                
                Spacer()
                
                if let confidence = event.historicalContext?.confidence {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield")
                        Text("\(Int(confidence * 100))% confidence")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Text(event.title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(event.summary)
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                if let impact = event.impact {
                    if let peopleAffected = impact.peopleAffected {
                        Label("\(formatNumber(peopleAffected)) affected", systemImage: "person.2")
                            .font(.caption)
                    }
                    if let regions = impact.regions, !regions.isEmpty {
                        Label(regions.joined(separator: ", "), systemImage: "location")
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                
                Label(formatDate(event.lastUpdatedAt), systemImage: "clock")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(event.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func historicalContextSection(context: HistoricalContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Historical Context", systemImage: "clock.arrow.circlepath")
                .font(.headline)
            
            Text(context.text)
                .font(.body)
            
            if !context.citations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sources")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(context.citations.prefix(3)) { citation in
                        Link(destination: URL(string: citation.url)!) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .font(.caption)
                                Text(citation.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    private func perspectivesSection(perspectives: [NewsPerspective]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Multiple Perspectives", systemImage: "person.3")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(perspectives.enumerated()), id: \.element.id) { index, perspective in
                        Button(action: { selectedPerspective = index }) {
                            VStack(spacing: 4) {
                                Image(systemName: perspectiveIcon(for: perspective))
                                    .font(.title3)
                                Text(perspective.label)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 80, height: 60)
                            .foregroundColor(selectedPerspective == index ? .white : .primary)
                            .background(
                                selectedPerspective == index ?
                                AnyView(Color.accentColor) :
                                AnyView(Color(.secondarySystemBackground))
                            )
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            if perspectives.indices.contains(selectedPerspective) {
                let perspective = perspectives[selectedPerspective]
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(perspective.label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if let confidence = perspective.confidence {
                            Text("\(Int(confidence * 100))% confident")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(perspective.summary)
                        .font(.body)
                    
                    if !perspective.citations.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sources")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            ForEach(perspective.citations.prefix(2)) { citation in
                                Link(destination: URL(string: citation.url)!) {
                                    HStack {
                                        Image(systemName: "link")
                                            .font(.caption2)
                                        Text(citation.title)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    private func solutionsSection(solutions: [NewsSolution]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Constructive Solutions", systemImage: "lightbulb")
                .font(.headline)
            
            ForEach(solutions) { solution in
                VStack(alignment: .leading, spacing: 8) {
                    Text(solution.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(solution.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let feasibility = solution.feasibility {
                        HStack {
                            Text("Feasibility:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(feasibility)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(feasibilityColor(feasibility))
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    private func articlesButton(count: Int) -> some View {
        Button(action: { showingArticles = true }) {
            HStack {
                Image(systemName: "newspaper")
                Text("View \(count) Source Articles")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var commentsButton: some View {
        Button(action: { showingComments = true }) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                Text("Comments & Discussion")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func perspectiveIcon(for perspective: NewsPerspective) -> String {
        if let geo = perspective.axes?.geography {
            return "globe"
        } else if let ideology = perspective.axes?.ideology {
            return "brain"
        } else if let stakeholder = perspective.axes?.stakeholder {
            switch stakeholder.lowercased() {
            case "government": return "building.columns"
            case "industry": return "building.2"
            case "ngo": return "heart.circle"
            default: return "person.2"
            }
        }
        return "eye"
    }
    
    private func feasibilityColor(_ feasibility: String) -> Color {
        switch feasibility.lowercased() {
        case "high", "easy": return .green
        case "medium", "moderate": return .orange
        case "low", "difficult": return .red
        default: return .secondary
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}