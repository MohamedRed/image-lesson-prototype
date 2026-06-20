import SwiftUI
import HealthService

struct LeaderboardView: View {
    @StateObject private var leaderboardViewModel = LeaderboardViewModel(healthService: HealthService.shared)
    @State private var selectedScope: LeaderboardBucket.GeoLevel = .city
    @State private var selectedCategory: LeaderboardBucket.CompetitionCategory = .overall
    @State private var showingChallenges = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if let userPosition = leaderboardViewModel.userPosition {
                        userRankCard(userPosition)
                    }
                    
                    scopeAndCategorySelectors
                    
                    if leaderboardViewModel.topPerformers.isEmpty && !leaderboardViewModel.isLoading {
                        emptyStateView
                    } else {
                        leaderboardList
                    }
                    
                    challengesSection
                }
                .padding()
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Challenges") {
                        showingChallenges = true
                    }
                }
            }
            .refreshable {
                await loadLeaderboardData()
            }
            .sheet(isPresented: $showingChallenges) {
                ChallengesView()
                    .environmentObject(leaderboardViewModel)
            }
        }
        .task {
            await loadLeaderboardData()
            await leaderboardViewModel.loadChallenges()
        }
        .overlay {
            if leaderboardViewModel.isLoading {
                ProgressView("Loading leaderboard...")
            }
        }
    }
    
    private func loadLeaderboardData() async {
        await leaderboardViewModel.loadLeaderboard()
    }
    
    private func userRankCard(_ position: LeaderboardEntry) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Your Ranking")
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
            }
            
            HStack(spacing: 20) {
                VStack {
                    Text("#\(position.rank)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    
                    Text("Rank")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack {
                    Text("Top \(Int(position.percentile))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Percentile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack {
                    Text("\(position.score, specifier: "%.0f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.accentColor.opacity(0.1), Color.clear]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    private var scopeAndCategorySelectors: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Scope")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Scope", selection: $selectedScope) {
                    Text("City").tag(LeaderboardBucket.GeoLevel.city)
                    Text("State").tag(LeaderboardBucket.GeoLevel.state)
                    Text("Country").tag(LeaderboardBucket.GeoLevel.country)
                    Text("Global").tag(LeaderboardBucket.GeoLevel.global)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedScope) { newScope in
                    Task {
                        await leaderboardViewModel.changeBucket(newScope)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(LeaderboardBucket.CompetitionCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                title: category.displayName,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                                Task {
                                    await leaderboardViewModel.changeCategory(category)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var leaderboardList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Performers")
                .font(.headline)
            
            ForEach(Array(leaderboardViewModel.topPerformers.enumerated()), id: \.offset) { index, entry in
                LeaderboardRow(entry: entry, position: index + 1)
            }
        }
    }
    
    private var challengesSection: some View {
        Group {
            if !leaderboardViewModel.activeChallenges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Active Challenges")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("View All") {
                            showingChallenges = true
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(leaderboardViewModel.activeChallenges.prefix(3), id: \.id) { challenge in
                                ChallengeCard(challenge: challenge, isCompact: true) {
                                    Task {
                                        await leaderboardViewModel.joinChallenge(challenge.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Rankings Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start tracking your health activities to see your ranking")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let position: Int
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                if position <= 3 {
                    Image(systemName: rankIcon)
                        .foregroundColor(rankColor)
                        .font(.title3)
                } else {
                    Text("\(position)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(rankColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.anonymizedId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(entry.bucket.geoLevel.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.score, specifier: "%.0f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("pts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var rankIcon: String {
        switch position {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal"
        default: return ""
        }
    }
    
    private var rankColor: Color {
        switch position {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .accentColor
        }
    }
}

struct ChallengesView: View {
    @EnvironmentObject private var leaderboardViewModel: LeaderboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if !leaderboardViewModel.activeChallenges.isEmpty {
                        activeChallengesSection
                    }
                    
                    if !leaderboardViewModel.upcomingChallenges.isEmpty {
                        upcomingChallengesSection
                    }
                }
                .padding()
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var activeChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Challenges")
                .font(.headline)
            
            ForEach(leaderboardViewModel.activeChallenges, id: \.id) { challenge in
                ChallengeCard(challenge: challenge, isCompact: false) {
                    Task {
                        await leaderboardViewModel.joinChallenge(challenge.id)
                    }
                }
            }
        }
    }
    
    private var upcomingChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Challenges")
                .font(.headline)
            
            ForEach(leaderboardViewModel.upcomingChallenges, id: \.id) { challenge in
                ChallengeCard(challenge: challenge, isCompact: false) {
                    Task {
                        await leaderboardViewModel.joinChallenge(challenge.id)
                    }
                }
            }
        }
    }
}

struct ChallengeCard: View {
    let challenge: HealthChallenge
    let isCompact: Bool
    let onJoin: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(isCompact ? .subheadline : .headline)
                        .fontWeight(.semibold)
                    
                    if !isCompact {
                        Text(challenge.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                challengeStatusBadge
            }
            
            if !isCompact {
                challengeDetails
            }
            
            if challenge.status != .completed {
                Button(challenge.status == .upcoming ? "Join Challenge" : "Join Now") {
                    onJoin()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var challengeStatusBadge: some View {
        Text(challenge.status.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }
    
    private var statusColor: Color {
        switch challenge.status {
        case .upcoming: return .blue
        case .active: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
    
    private var challengeDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("\(challenge.participants) participants", systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(challenge.endDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let prizes = challenge.prizes, let first = prizes.first {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("Prize: \(first.title)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

extension LeaderboardBucket.CompetitionCategory {
    var displayName: String {
        switch self {
        case .overall: return "Overall"
        case .steps: return "Steps"
        case .activity: return "Activity"
        case .wellness: return "Wellness"
        case .challenges: return "Challenges"
        case .custom: return "Custom"
        }
    }
    
    static var allCases: [LeaderboardBucket.CompetitionCategory] {
        [.overall, .steps, .activity, .wellness, .challenges, .custom]
    }
}

#Preview {
    NavigationStack {
        LeaderboardView()
    }
}