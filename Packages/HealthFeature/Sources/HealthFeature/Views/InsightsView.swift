import SwiftUI
import HealthService

struct InsightsView: View {
    @StateObject private var insightsViewModel = InsightsViewModel(healthService: HealthService.shared)
    @State private var selectedCategory: HealthInsight.InsightCategory? = nil
    @State private var selectedInsight: HealthInsight?
    
    private let categories: [HealthInsight.InsightCategory] = [
        .nutrition, .activity, .sleep, .stress, .vitals, .medication, .general
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if insightsViewModel.unreadCount > 0 {
                        unreadBanner
                    }
                    
                    categoryFilterSection
                    
                    if filteredInsights.isEmpty && !insightsViewModel.isLoading {
                        emptyStateView
                    } else {
                        insightsList
                    }
                }
                .padding()
            }
            .navigationTitle("Health Insights")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await insightsViewModel.loadInsights(category: selectedCategory)
            }
            .sheet(item: $selectedInsight) { insight in
                InsightDetailView(insight: insight)
                    .environmentObject(insightsViewModel)
            }
        }
        .task {
            await insightsViewModel.loadInsights()
        }
        .overlay {
            if insightsViewModel.isLoading {
                ProgressView("Loading insights...")
            }
        }
    }
    
    private var unreadBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Insights Available")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(insightsViewModel.unreadCount) unread insights")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.title2)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CategoryFilterChip(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    action: {
                        selectedCategory = nil
                        Task {
                            await insightsViewModel.loadInsights()
                        }
                    }
                )
                
                ForEach(categories, id: \.self) { category in
                    CategoryFilterChip(
                        title: category.rawValue.capitalized,
                        isSelected: selectedCategory == category,
                        action: {
                            selectedCategory = category
                            Task {
                                await insightsViewModel.loadInsights(category: category)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var filteredInsights: [HealthInsight] {
        if let selectedCategory = selectedCategory {
            return insightsViewModel.insights.filter { $0.category == selectedCategory }
        }
        return insightsViewModel.insights
    }
    
    private var insightsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredInsights.sorted { !$0.isRead && $1.isRead }, id: \.id) { insight in
                InsightRowCard(insight: insight) {
                    selectedInsight = insight
                    if !insight.isRead {
                        Task {
                            await insightsViewModel.markInsightRead(insight.id)
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Insights Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your health insights will appear here as we analyze your data")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }
}

struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct InsightRowCard: View {
    let insight: HealthInsight
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack {
                    Image(systemName: severityIcon)
                        .foregroundColor(severityColor)
                        .font(.title2)
                    
                    if !insight.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(insight.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(insight.createdAt.timeAgoDisplay)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(insight.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(insight.category.rawValue.capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                        
                        if !insight.recommendedActions.isEmpty {
                            Text("\(insight.recommendedActions.count) actions")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(insight.isRead ? Color(.systemGray6) : Color(.systemBlue).opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var severityIcon: String {
        switch insight.severity {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "info.circle.fill"
        case .low: return "lightbulb.fill"
        }
    }
    
    private var severityColor: Color {
        switch insight.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .green
        }
    }
}

struct InsightDetailView: View {
    let insight: HealthInsight
    @EnvironmentObject private var insightsViewModel: InsightsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    insightHeader
                    descriptionSection
                    
                    if !insight.recommendedActions.isEmpty {
                        recommendedActionsSection
                    }
                    
                    if !insight.evidenceLinks.isEmpty {
                        evidenceSection
                    }
                    
                    triggerInfoSection
                }
                .padding()
            }
            .navigationTitle("Insight Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Dismiss") {
                        Task {
                            await insightsViewModel.dismissInsight(insight.id)
                            dismiss()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    private var insightHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(insight.category.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(severityText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(severityColor)
                    
                    Text(insight.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)
            
            Text(insight.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var recommendedActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Actions")
                .font(.headline)
            
            ForEach(Array(insight.recommendedActions.enumerated()), id: \.offset) { index, action in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 20, height: 20)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    
                    Text(action.title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supporting Evidence")
                .font(.headline)
            
            ForEach(insight.evidenceLinks, id: \.url) { link in
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.blue)
                    
                    Text(link.title)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private var triggerInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What triggered this insight?")
                .font(.headline)
            
            Text(insight.trigger.condition)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    private var severityIcon: String {
        switch insight.severity {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "info.circle.fill"
        case .low: return "lightbulb.fill"
        }
    }
    
    private var severityColor: Color {
        switch insight.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .green
        }
    }
    
    private var severityText: String {
        switch insight.severity {
        case .critical: return "Critical"
        case .high: return "High Priority"
        case .medium: return "Medium Priority"
        case .low: return "Low Priority"
        }
    }
}

extension Date {
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
}