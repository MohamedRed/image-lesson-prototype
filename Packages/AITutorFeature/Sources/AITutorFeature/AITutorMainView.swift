import SwiftUI
import AITutorService

public struct AITutorMainView: View {
    @StateObject private var viewModel: AITutorViewModel
    @State private var selectedTab = 0
    
    public init(service: AITutorServicing = AITutorService()) {
        _viewModel = StateObject(wrappedValue: AITutorViewModel(service: service))
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.episodes.isEmpty {
                    SwiftUI.ProgressView("Loading episodes...")
                        .font(.title3)
                } else {
                    TabView(selection: $selectedTab) {
                        // Episodes Tab
                        EpisodesListView(viewModel: viewModel)
                            .tabItem {
                                Label("Episodes", systemImage: "play.rectangle.fill")
                            }
                            .tag(0)
                        
                        // Progress Tab
                        ProgressView(viewModel: viewModel)
                            .tabItem {
                                Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                            }
                            .tag(1)
                        
                        // Insights Tab
                        InsightsView(viewModel: viewModel)
                            .tabItem {
                                Label("Insights", systemImage: "lightbulb.fill")
                            }
                            .tag(2)
                        
                        // Saves Tab
                        SavesView(viewModel: viewModel)
                            .tabItem {
                                Label("Saves", systemImage: "square.and.arrow.down.fill")
                            }
                            .tag(3)
                    }
                }
            }
            .navigationTitle("AI Tutor")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.loadEpisodes()
            }
        }
    }
}

// MARK: - Episodes List View

struct EpisodesListView: View {
    @ObservedObject var viewModel: AITutorViewModel
    @State private var selectedDomain: Episode.Domain?
    
    var filteredEpisodes: [Episode] {
        guard let domain = selectedDomain else {
            return viewModel.episodes
        }
        return viewModel.episodes.filter { $0.domain == domain }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Domain Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedDomain == nil,
                        action: { selectedDomain = nil }
                    )
                    
                    ForEach(Episode.Domain.allCases, id: \.self) { domain in
                        FilterChip(
                            title: domain.displayName,
                            isSelected: selectedDomain == domain,
                            color: domain.color,
                            action: { selectedDomain = domain }
                        )
                    }
                }
                .padding()
            }
            
            // Episodes Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(filteredEpisodes) { episode in
                        EpisodeCard(episode: episode, viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Episode Card

struct EpisodeCard: View {
    let episode: Episode
    @ObservedObject var viewModel: AITutorViewModel
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(episode.domain.color.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fit)
                    
                    if let thumbnailURL = episode.thumbnailURL,
                       let url = URL(string: thumbnailURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: episode.domain.icon)
                                .font(.largeTitle)
                                .foregroundColor(episode.domain.color)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: episode.domain.icon)
                            .font(.largeTitle)
                            .foregroundColor(episode.domain.color)
                    }
                    
                    // Duration badge
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(episode.duration) min")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .padding(8)
                        }
                        Spacer()
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    Text(episode.era)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Difficulty
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Image(systemName: index < episode.difficulty.level ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        // Mechanics icons
                        HStack(spacing: 2) {
                            ForEach(episode.mechanics.prefix(3), id: \.self) { mechanic in
                                Image(systemName: mechanic.icon)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            EpisodeDetailView(episode: episode, viewModel: viewModel)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? color : Color(.systemGray5)
                )
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Progress View

struct ProgressView: View {
    @ObservedObject var viewModel: AITutorViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall Stats
                VStack(spacing: 16) {
                    Text("Learning Progress")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 30) {
                        StatCard(
                            title: "Episodes",
                            value: "3",
                            subtitle: "Completed",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                        
                        StatCard(
                            title: "Time",
                            value: "2.5",
                            subtitle: "Hours",
                            icon: "clock.fill",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Insights",
                            value: "12",
                            subtitle: "Earned",
                            icon: "lightbulb.fill",
                            color: .orange
                        )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                
                // Competency Scores
                VStack(alignment: .leading, spacing: 12) {
                    Text("Competencies")
                        .font(.headline)
                    
                    CompetencyBar(name: "Evidence Analysis", score: 0.85, color: .blue)
                    CompetencyBar(name: "Ethical Reasoning", score: 0.72, color: .purple)
                    CompetencyBar(name: "Historical Context", score: 0.90, color: .green)
                    CompetencyBar(name: "Critical Thinking", score: 0.78, color: .orange)
                    CompetencyBar(name: "Decision Making", score: 0.65, color: .red)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
            }
            .padding()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CompetencyBar: View {
    let name: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(score * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * score, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Extensions

extension Episode.Domain {
    var displayName: String {
        switch self {
        case .history: return "History"
        case .science: return "Science"
        case .philosophy: return "Philosophy"
        case .art: return "Art"
        case .law: return "Law"
        case .other: return "Other"
        }
    }
    
    var color: Color {
        switch self {
        case .history: return .brown
        case .science: return .green
        case .philosophy: return .purple
        case .art: return .pink
        case .law: return .indigo
        case .other: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .history: return "clock.arrow.circlepath"
        case .science: return "flask.fill"
        case .philosophy: return "brain.head.profile"
        case .art: return "paintpalette.fill"
        case .law: return "scale.3d"
        case .other: return "puzzlepiece.fill"
        }
    }
}

extension Episode.Difficulty {
    var level: Int {
        switch self {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        }
    }
}

extension MechanicType {
    var icon: String {
        switch self {
        case .debateMode: return "bubble.left.and.bubble.right.fill"
        case .commandMap: return "map.fill"
        case .experimentBuilder: return "flask.fill"
        case .policyBoard: return "slider.horizontal.3"
        case .courtroom: return "building.columns.fill"
        case .fieldwork: return "binoculars.fill"
        case .evidenceBoard: return "doc.text.magnifyingglass"
        }
    }
}

#if DEBUG
struct AITutorMainView_Previews: PreviewProvider {
    static var previews: some View {
        AITutorMainView(service: MockAITutorService())
    }
}
#endif