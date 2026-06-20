import SwiftUI
import DebateService

struct TimelineView: View {
    let events: [TimelineEvent]
    let factCheckResults: [String: FactCheckResult]
    @State private var selectedEvent: TimelineEvent?
    @Environment(\.dismiss) private var dismiss
    
    var groupedEvents: [(String, [TimelineEvent])] {
        let grouped = Dictionary(grouping: events) { $0.debaterName }
        return grouped.sorted { $0.key < $1.key }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedEvents, id: \.0) { debaterName, debaterEvents in
                    Section(debaterName) {
                        ForEach(debaterEvents) { event in
                            TimelineEventRow(
                                event: event,
                                factCheckResult: factCheckResults[event.id]
                            )
                            .onTapGesture {
                                selectedEvent = event
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedEvent) { event in
                TimelineEventDetailView(
                    event: event,
                    factCheckResult: factCheckResults[event.id]
                )
            }
        }
    }
}

struct TimelineEventRow: View {
    let event: TimelineEvent
    let factCheckResult: FactCheckResult?
    
    var statusIcon: String {
        switch event.factCheckStatus {
        case .verified: return "checkmark.circle.fill"
        case .disputed: return "exclamationmark.triangle.fill"
        case .false_claim: return "xmark.circle.fill"
        case .pending: return "clock.fill"
        case .needsSource: return "questionmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var statusColor: Color {
        switch event.factCheckStatus {
        case .verified: return .green
        case .disputed: return .orange
        case .false_claim: return .red
        case .pending: return .gray
        case .needsSource: return .yellow
        case .unknown: return .gray
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title3)
                
                if let confidence = factCheckResult?.confidence {
                    Text("\(Int(confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                
                Text(event.historicalDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(event.description)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(.secondary)
                
                if !event.sources.isEmpty {
                    HStack {
                        Image(systemName: "link")
                            .font(.caption)
                        Text("\(event.sources.count) source(s)")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct TimelineEventDetailView: View {
    let event: TimelineEvent
    let factCheckResult: FactCheckResult?
    @Environment(\.dismiss) private var dismiss
    
    var statusText: String {
        switch event.factCheckStatus {
        case .verified: return "Verified"
        case .disputed: return "Disputed"
        case .false_claim: return "False Claim"
        case .pending: return "Pending Verification"
        case .needsSource: return "Needs Source"
        case .unknown: return "Unknown"
        }
    }
    
    var statusColor: Color {
        switch event.factCheckStatus {
        case .verified: return .green
        case .disputed: return .orange
        case .false_claim: return .red
        case .pending: return .gray
        case .needsSource: return .yellow
        case .unknown: return .gray
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Label(event.historicalDate, systemImage: "calendar")
                            Spacer()
                            Label(statusText, systemImage: "checkmark.shield")
                                .foregroundColor(statusColor)
                        }
                        .font(.subheadline)
                        
                        Text("Added by \(event.debaterName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(event.description)
                            .font(.body)
                    }
                    
                    // Fact Check Result
                    if let result = factCheckResult {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Fact Check")
                                    .font(.headline)
                                Spacer()
                                if result.confidence > 0 {
                                    Text("Confidence: \(Int(result.confidence * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let explanation = result.explanation {
                                Text(explanation)
                                    .font(.body)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            if !result.sources.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Verification Sources")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    ForEach(result.sources, id: \.self) { source in
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                            Text(source)
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Original Sources
                    if !event.sources.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Original Sources")
                                .font(.headline)
                            
                            ForEach(event.sources, id: \.self) { source in
                                HStack {
                                    Image(systemName: "link")
                                        .font(.caption)
                                    Text(source)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}