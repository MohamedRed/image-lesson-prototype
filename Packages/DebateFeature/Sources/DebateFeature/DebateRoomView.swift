import SwiftUI
import DebateService

public struct DebateRoomView: View {
    @StateObject private var viewModel: DebateRoomViewModel
    @State private var showTimeline = false
    @State private var showAddEvent = false
    @State private var showSharedMedia = false
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss
    
    public init(debateId: String, role: DebateRole, service: DebateServicing? = nil) {
        _viewModel = StateObject(wrappedValue: DebateRoomViewModel(
            debateId: debateId,
            role: role,
            service: service
        ))
    }
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Participant tiles
                ParticipantGridView(participants: viewModel.participants)
                    .frame(maxHeight: .infinity)
                
                // Timeline preview
                if !viewModel.timelineEvents.isEmpty {
                    TimelinePreviewBar(events: viewModel.timelineEvents) {
                        showTimeline = true
                    }
                    .frame(height: 80)
                }
                
                // Controls
                DebateControlsView(
                    isMicEnabled: viewModel.isMicEnabled,
                    isCameraEnabled: viewModel.isCameraEnabled,
                    isDebater: viewModel.role == .debater,
                    onToggleMic: { viewModel.toggleMicrophone() },
                    onToggleCamera: { viewModel.toggleCamera() },
                    onAddEvent: { showAddEvent = true },
                    onLeave: { 
                        viewModel.leaveDebate()
                        dismiss()
                    },
                    showSharedMedia: $showSharedMedia
                )
                .padding()
                .background(Color(.systemBackground))
            }
            
            // Connection status overlay
            if viewModel.connectionState != .connected {
                ConnectionStatusOverlay(state: viewModel.connectionState)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showTimeline) {
            TimelineView(events: viewModel.timelineEvents, 
                        factCheckResults: viewModel.factCheckResults)
        }
        .sheet(isPresented: $showAddEvent) {
            AddTimelineEventView { event in
                await viewModel.addTimelineEvent(event)
                showAddEvent = false
            }
        }
        .sheet(isPresented: $showSharedMedia) {
            SharedMediaView(
                debateId: viewModel.debateId,
                isDebater: viewModel.role == .debater,
                service: viewModel.service
            )
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .task {
            await viewModel.joinDebate()
        }
    }
}

struct ParticipantGridView: View {
    let participants: [ParticipantTrack]
    
    var gridLayout: [GridItem] {
        let count = participants.count
        if count <= 2 {
            return Array(repeating: GridItem(.flexible()), count: 1)
        } else if count <= 4 {
            return Array(repeating: GridItem(.flexible()), count: 2)
        } else {
            return Array(repeating: GridItem(.flexible()), count: 3)
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridLayout, spacing: 8) {
                ForEach(participants) { participant in
                    ParticipantTileView(participant: participant)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding()
        }
        .background(Color(.systemGray6))
    }
}

struct ParticipantTileView: View {
    let participant: ParticipantTrack
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
            
            VStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                
                Text(participant.participantName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if participant.role == .moderator {
                    Label("Moderator", systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            
            // Audio indicator
            if participant.audioTrack != nil {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "mic.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(4)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
    }
}

struct TimelinePreviewBar: View {
    let events: [TimelineEvent]
    let onShowFullTimeline: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Text("Timeline (\(events.count) events)")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("View All") {
                    onShowFullTimeline()
                }
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(events.suffix(5)) { event in
                        TimelineEventCard(event: event)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .background(Color(.systemBackground))
    }
}

struct TimelineEventCard: View {
    let event: TimelineEvent
    
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(event.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            Text(event.historicalDate)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct DebateControlsView: View {
    let isMicEnabled: Bool
    let isCameraEnabled: Bool
    let isDebater: Bool
    let onToggleMic: () -> Void
    let onToggleCamera: () -> Void
    let onAddEvent: () -> Void
    let onLeave: () -> Void
    @Binding var showSharedMedia: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: onToggleMic) {
                Image(systemName: isMicEnabled ? "mic.fill" : "mic.slash.fill")
                    .font(.title2)
                    .foregroundColor(isMicEnabled ? .primary : .red)
            }
            .disabled(!isDebater)
            
            Button(action: onToggleCamera) {
                Image(systemName: isCameraEnabled ? "video.fill" : "video.slash.fill")
                    .font(.title2)
                    .foregroundColor(isCameraEnabled ? .primary : .red)
            }
            .disabled(!isDebater)
            
            if isDebater {
                Button(action: onAddEvent) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                }
            }
            
            Button(action: { showSharedMedia = true }) {
                Image(systemName: "doc.on.doc")
                    .font(.title2)
            }
            
            Spacer()
            
            Button(action: onLeave) {
                Label("Leave", systemImage: "phone.down.fill")
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(20)
            }
        }
    }
}

struct ConnectionStatusOverlay: View {
    let state: ConnectionState
    
    var body: some View {
        VStack {
            ProgressView()
            Text(statusText)
                .font(.subheadline)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
    
    var statusText: String {
        switch state {
        case .connecting: return "Connecting..."
        case .reconnecting: return "Reconnecting..."
        case .failed(let error): return "Failed: \(error)"
        default: return ""
        }
    }
}

struct AddTimelineEventView: View {
    @State private var title = ""
    @State private var description = ""
    @State private var historicalDate = ""
    @State private var sources = ""
    @Environment(\.dismiss) private var dismiss
    
    let onAdd: (TimelineEventInput) async -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Event Information") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Historical Date (YYYY-MM-DD)", text: $historicalDate)
                }
                
                Section("Sources") {
                    TextField("Sources (comma separated)", text: $sources, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Timeline Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            let event = TimelineEventInput(
                                title: title,
                                description: description,
                                historicalDate: historicalDate,
                                sources: sources.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                            )
                            await onAdd(event)
                        }
                    }
                    .disabled(title.isEmpty || description.isEmpty || historicalDate.isEmpty)
                }
            }
        }
    }
}