import SwiftUI
import DebateService

public struct DebateLobbyView: View {
    @StateObject private var viewModel: DebateLobbyViewModel
    @State private var showCreateDebate = false
    @State private var selectedDebate: DebateInfo?
    
    public init(service: DebateServicing? = nil) {
        _viewModel = StateObject(wrappedValue: DebateLobbyViewModel(service: service))
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading debates...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.debates.isEmpty {
                    EmptyStateView()
                } else {
                    DebateListView(
                        debates: viewModel.debates,
                        onDebateSelected: { debate in
                            selectedDebate = debate
                        }
                    )
                }
            }
            .navigationTitle("Debates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateDebate = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .refreshable {
                await viewModel.loadDebates()
            }
            .sheet(isPresented: $showCreateDebate) {
                CreateDebateView { config in
                    await viewModel.createDebate(config)
                    showCreateDebate = false
                }
            }
            .sheet(item: $selectedDebate) { debate in
                NavigationStack {
                    DebateDetailView(debate: debate) { role in
                        // Navigate to debate room
                        await viewModel.joinDebate(debateId: debate.id, role: role)
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .task {
            await viewModel.loadDebates()
        }
    }
}

struct DebateListView: View {
    let debates: [DebateInfo]
    let onDebateSelected: (DebateInfo) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(debates) { debate in
                    DebateCard(debate: debate)
                        .onTapGesture {
                            onDebateSelected(debate)
                        }
                }
            }
            .padding()
        }
    }
}

struct DebateCard: View {
    let debate: DebateInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(debate.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(debate.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if debate.isLive {
                    LiveIndicator()
                }
            }
            
            HStack {
                Label(debate.category, systemImage: "tag")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label("\(debate.participantCount)/\(debate.maxDebaters)", 
                      systemImage: "person.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("by \(debate.hostName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct LiveIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(), value: isAnimating)
            
            Text("LIVE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.1))
        .cornerRadius(4)
        .onAppear {
            isAnimating = true
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Active Debates")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a new debate or wait for others to begin")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct CreateDebateView: View {
    @State private var title = ""
    @State private var description = ""
    @State private var category = "General"
    @State private var maxDebaters = 4
    @State private var isPublic = true
    @Environment(\.dismiss) private var dismiss
    
    let onCreate: (DebateConfig) async -> Void
    
    let categories = ["General", "Politics", "Technology", "Science", 
                     "Philosophy", "Economics", "Environment", "Education"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Debate Information") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Settings") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
                    Stepper("Max Debaters: \(maxDebaters)", value: $maxDebaters, in: 2...8)
                    
                    Toggle("Public Debate", isOn: $isPublic)
                }
            }
            .navigationTitle("Create Debate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            let config = DebateConfig(
                                title: title,
                                description: description,
                                category: category,
                                maxDebaters: maxDebaters,
                                isPublic: isPublic
                            )
                            await onCreate(config)
                        }
                    }
                    .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
    }
}

struct DebateDetailView: View {
    let debate: DebateInfo
    let onJoin: (DebateRole) async -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(debate.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(debate.description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label(debate.category, systemImage: "tag")
                Spacer()
                Label("\(debate.participantCount)/\(debate.maxDebaters) participants", 
                      systemImage: "person.2")
            }
            .font(.subheadline)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Host: \(debate.hostName)")
                    .font(.subheadline)
                
                if debate.isLive {
                    LiveIndicator()
                }
                
                if let scheduledAt = debate.scheduledAt {
                    Label("Scheduled for \(scheduledAt.formatted())", 
                          systemImage: "calendar")
                        .font(.subheadline)
                }
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                if debate.participantCount < debate.maxDebaters {
                    Button(action: {
                        Task {
                            await onJoin(.debater)
                            dismiss()
                        }
                    }) {
                        Label("Join as Debater", systemImage: "mic")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button(action: {
                    Task {
                        await onJoin(.spectator)
                        dismiss()
                    }
                }) {
                    Label("Watch Debate", systemImage: "eye")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .navigationTitle("Debate Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") { dismiss() }
            }
        }
    }
}