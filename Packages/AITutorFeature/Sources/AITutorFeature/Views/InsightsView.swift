import SwiftUI
import AITutorService
// Allow using InsightCard in .sheet(item:)
extension InsightCard: Identifiable {}

struct InsightsView: View {
    @ObservedObject var viewModel: AITutorViewModel
    @State private var selectedCard: InsightCard?
    
    var upcomingCards: [InsightCard] {
        viewModel.insightCards
            .filter { $0.nextReviewDate <= Date().addingTimeInterval(86400) }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }
    
    var futureCards: [InsightCard] {
        viewModel.insightCards
            .filter { $0.nextReviewDate > Date().addingTimeInterval(86400) }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Insight Cards")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Reinforce your learning with spaced repetition")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Review Session Button
                if !upcomingCards.isEmpty {
                    Button(action: startReviewSession) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Review Session")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("\(upcomingCards.count) cards ready")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Upcoming Cards
                if !upcomingCards.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Due for Review")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(upcomingCards) { card in
                                    InsightCardView(card: card)
                                        .onTapGesture {
                                            selectedCard = card
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Future Cards
                if !futureCards.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(futureCards) { card in
                            FutureInsightRow(card: card)
                                .padding(.horizontal)
                        }
                    }
                }
                
                // Statistics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Statistics")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        StatBox(
                            title: "Total Cards",
                            value: "\(viewModel.insightCards.count)",
                            icon: "rectangle.stack.fill"
                        )
                        
                        StatBox(
                            title: "Reviewed",
                            value: "42",
                            icon: "checkmark.circle.fill"
                        )
                        
                        StatBox(
                            title: "Streak",
                            value: "7 days",
                            icon: "flame.fill"
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .onAppear {
            viewModel.loadInsightCards()
        }
        .sheet(item: $selectedCard) { card in
            InsightReviewView(card: card, viewModel: viewModel)
        }
    }
    
    private func startReviewSession() {
        if let firstCard = upcomingCards.first {
            selectedCard = firstCard
        }
    }
}

struct InsightCardView: View {
    let card: InsightCard
    
    var difficultyColor: Color {
        switch card.difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Competency
            Text(card.competency.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            // Prompt
            Text(card.prompt)
                .font(.subheadline)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Difficulty indicator
            HStack {
                Circle()
                    .fill(difficultyColor)
                    .frame(width: 8, height: 8)
                
                Text(card.difficulty.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(relativeDate(card.nextReviewDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 200, height: 140)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct FutureInsightRow: View {
    let card: InsightCard
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.competency.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(card.prompt)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(card.nextReviewDate, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct InsightReviewView: View {
    let card: InsightCard
    @ObservedObject var viewModel: AITutorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAnswer = false
    @State private var userResponse = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Progress indicator
                SwiftUI.ProgressView(value: 0.3)
                    .padding(.horizontal)
                
                // Card content
                VStack(spacing: 16) {
                    Text(card.competency.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(card.prompt)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    // Response area
                    if !showingAnswer {
                        VStack(spacing: 12) {
                            Text("Think about your answer...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $userResponse)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            Button("Show Insights") {
                                showingAnswer = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else {
                        // Show insights/guidance
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Key Insights")
                                .font(.headline)
                            
                            Text(getInsightText())
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            // Confidence buttons
                            Text("How well did you know this?")
                                .font(.subheadline)
                                .padding(.top)
                            
                            HStack(spacing: 12) {
                                ForEach(["Again", "Hard", "Good", "Easy"], id: \.self) { level in
                                    Button(level) {
                                        recordResponse(level: level)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getInsightText() -> String {
        // This would come from the backend based on the card
        switch card.competency {
        case "evidence_analysis":
            return "Primary sources are original documents from the time period, while secondary sources analyze and interpret primary sources. Always verify claims against multiple sources when possible."
        case "ethical_reasoning":
            return "Ethical decisions often involve trade-offs. Consider the consequences, stakeholders affected, and principles at stake. Sometimes compromise preserves relationships while standing firm preserves principles."
        default:
            return "Consider multiple perspectives and evidence when forming conclusions. Historical context shapes decisions and outcomes."
        }
    }
    
    private func recordResponse(level: String) {
        // Update next review date based on response
        // This would use spaced repetition algorithm
        dismiss()
    }
}