import SwiftUI
import HealthService

/// Main health feature entry point
public struct HealthView: View {
    @StateObject private var healthViewModel: HealthViewModel
    @StateObject private var healthKitService = HealthKitService()
    @State private var selectedTab: HealthTab = .overview
    @State private var showingPermissionsSheet = false
    
    public enum HealthTab: String, CaseIterable {
        case overview = "Overview"
        case programs = "Programs"
        case insights = "Insights"
        case leaderboard = "Leaderboard"
        case professionals = "Professionals"
        case news = "News"
        
        var icon: String {
            switch self {
            case .overview: return "heart.fill"
            case .programs: return "list.bullet.clipboard"
            case .insights: return "lightbulb.fill"
            case .leaderboard: return "trophy.fill"
            case .professionals: return "stethoscope"
            case .news: return "newspaper.fill"
            }
        }
    }
    
    public init(healthService: HealthService) {
        _healthViewModel = StateObject(wrappedValue: HealthViewModel(
            healthService: healthService,
            healthKitService: HealthKitService()
        ))
    }
    
    public var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Overview Dashboard
                HealthOverviewView()
                    .environmentObject(healthViewModel)
                    .environmentObject(healthKitService)
                    .tabItem {
                        Image(systemName: HealthTab.overview.icon)
                        Text(HealthTab.overview.rawValue)
                    }
                    .tag(HealthTab.overview)
                
                // Programs
                ProgramsView()
                    .environmentObject(healthViewModel)
                    .tabItem {
                        Image(systemName: HealthTab.programs.icon)
                        Text(HealthTab.programs.rawValue)
                    }
                    .tag(HealthTab.programs)
                
                // Insights
                InsightsView()
                    .environmentObject(healthViewModel)
                    .tabItem {
                        Image(systemName: HealthTab.insights.icon)
                        Text(HealthTab.insights.rawValue)
                    }
                    .tag(HealthTab.insights)
                
                // Leaderboard
                LeaderboardView()
                    .environmentObject(healthViewModel)
                    .tabItem {
                        Image(systemName: HealthTab.leaderboard.icon)
                        Text(HealthTab.leaderboard.rawValue)
                    }
                    .tag(HealthTab.leaderboard)
                
                // Professionals
                ProfessionalsView()
                    .environmentObject(healthViewModel)
                    .tabItem {
                        Image(systemName: HealthTab.professionals.icon)
                        Text(HealthTab.professionals.rawValue)
                    }
                    .tag(HealthTab.professionals)
                
                // News
                NewsView()
                    .environmentObject(healthViewModel)
                    .tabItem {
                        Image(systemName: HealthTab.news.icon)
                        Text(HealthTab.news.rawValue)
                    }
                    .tag(HealthTab.news)
            }
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingPermissionsSheet = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .sheet(isPresented: $showingPermissionsSheet) {
            HealthSettingsView()
                .environmentObject(healthViewModel)
                .environmentObject(healthKitService)
        }
        .task {
            await healthViewModel.loadInitialData()
        }
    }
}

/// Health overview dashboard
struct HealthOverviewView: View {
    @EnvironmentObject private var healthViewModel: HealthViewModel
    @EnvironmentObject private var healthKitService: HealthKitService
    @State private var showingAddDataSheet = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Health Summary Cards
                todayMetricsSection
                
                // Quick Actions
                quickActionsSection
                
                // Active Program Steps
                activeProgramsSection
                
                // Recent Insights
                recentInsightsSection
                
                // Leaderboard Position (if opted in)
                leaderboardPositionSection
            }
            .padding()
        }
        .refreshable {
            await healthViewModel.refreshHealthData()
        }
        .sheet(isPresented: $showingAddDataSheet) {
            AddHealthDataView()
                .environmentObject(healthViewModel)
        }
    }
    
    private var todayMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Add Data") {
                    showingAddDataSheet = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(
                    title: "Steps",
                    value: "\(healthViewModel.todaySteps)",
                    icon: "figure.walk",
                    color: .blue
                )
                
                MetricCard(
                    title: "Active Minutes",
                    value: "\(healthViewModel.activeMinutes)",
                    icon: "flame.fill",
                    color: .orange
                )
                
                MetricCard(
                    title: "Sleep",
                    value: String(format: "%.1fh", healthViewModel.sleepHours),
                    icon: "bed.double.fill",
                    color: .purple
                )
                
                MetricCard(
                    title: "Heart Rate",
                    value: "\(healthViewModel.heartRate) bpm",
                    icon: "heart.fill",
                    color: .red
                )
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Log Weight",
                    icon: "scalemass.fill",
                    color: .green
                ) {
                    // Show weight entry
                }
                
                QuickActionButton(
                    title: "Record Mood",
                    icon: "face.smiling.fill",
                    color: .yellow
                ) {
                    // Show mood entry
                }
                
                QuickActionButton(
                    title: "Voice Log",
                    icon: "mic.fill",
                    color: .blue
                ) {
                    // Start voice recording
                }
            }
        }
    }
    
    private var activeProgramsSection: some View {
        Group {
            if let steps = healthViewModel.healthOverview?.activeProgramSteps,
               !steps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's Tasks")
                        .font(.headline)
                    
                    ForEach(steps.prefix(3), id: \.id) { step in
                        ProgramStepRow(step: step) { stepId in
                            // Handle step completion
                        }
                    }
                    
                    if steps.count > 3 {
                        NavigationLink("View All Programs") {
                            ProgramsView()
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                }
            }
        }
    }
    
    private var recentInsightsSection: some View {
        Group {
            if let insights = healthViewModel.healthOverview?.insights,
               !insights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Health Insights")
                        .font(.headline)
                    
                    ForEach(insights.prefix(2), id: \.id) { insight in
                        InsightCard(insight: insight)
                    }
                    
                    if insights.count > 2 {
                        NavigationLink("View All Insights") {
                            InsightsView()
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                }
            }
        }
    }
    
    private var leaderboardPositionSection: some View {
        Group {
            if let position = healthViewModel.healthOverview?.leaderboardPosition {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Rank")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("#\(position.rank)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                            
                            Text("\(position.bucket) • Top \(Int(position.percentile))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: position.trend == "up" ? "arrow.up.circle.fill" : 
                               position.trend == "down" ? "arrow.down.circle.fill" : "minus.circle.fill")
                            .foregroundColor(position.trend == "up" ? .green : 
                                           position.trend == "down" ? .red : .gray)
                            .font(.title2)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProgramStepRow: View {
    let step: ProgramStep
    let onComplete: (String) -> Void
    
    var body: some View {
        HStack {
            Button {
                onComplete(step.id)
            } label: {
                Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(step.isCompleted ? .green : .gray)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.subheadline)
                    .strikethrough(step.isCompleted)
                
                Text(step.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct InsightCard: View {
    let insight: HealthInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: severityIcon(insight.severity))
                    .foregroundColor(severityColor(insight.severity))
            }
            
            Text(insight.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func severityIcon(_ severity: HealthInsight.InsightSeverity) -> String {
        switch severity {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "info.circle.fill"
        case .low: return "lightbulb.fill"
        }
    }
    
    private func severityColor(_ severity: HealthInsight.InsightSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .green
        }
    }
}

#Preview {
    NavigationStack {
        HealthView(healthService: HealthService(baseURL: URL(string: "https://api.example.com")!))
    }
}