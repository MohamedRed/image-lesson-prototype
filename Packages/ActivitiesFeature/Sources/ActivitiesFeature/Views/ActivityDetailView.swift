import SwiftUI
import ActivitiesService

struct ActivityDetailView: View {
    let activity: Activity
    @ObservedObject var viewModel: ActivitiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSession: ActivitySession?
    @State private var sessions: [ActivitySession] = []
    @State private var perspectives: ActivityPerspectives?
    @State private var isLoadingSessions = true
    @State private var showingBookingFlow = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero Image
                    heroImageSection
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Basic Info
                        basicInfoSection
                        
                        // Description
                        descriptionSection
                        
                        // Equipment / Tags
                        if !activity.equipmentNeeded.isEmpty || !activity.tags.isEmpty {
                            equipmentSection
                        }
                        
                        // AI Perspectives
                        if let perspectives = perspectives {
                            perspectivesSection(perspectives)
                        }
                        
                        // Available Sessions
                        sessionsSection
                        
                        // Location
                        locationSection
                        
                        // Provider Info - TODO: Load provider details
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadSessionsAndPerspectives()
        }
        .sheet(isPresented: $showingBookingFlow) {
            if let session = selectedSession {
                BookingFlowView(
                    activity: activity,
                    session: session,
                    viewModel: viewModel
                )
            }
        }
    }
    
    private var heroImageSection: some View {
        TabView {
            ForEach(activity.images, id: \.self) { imageURL in
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .overlay {
                            ProgressView()
                        }
                }
                .frame(height: 250)
                .clipped()
            }
        }
        .frame(height: 250)
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(activity.title)
                .font(.title)
                .fontWeight(.bold)
            
            HStack {
                Label(activity.category.displayName, systemImage: "tag.fill")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                Spacer()
            }
            // Show basic per-unit pricing and duration
            HStack {
                Image(systemName: "tag")
                    .foregroundColor(.green)
                Text("\(Int(activity.pricePerUnit)) MAD / \(activity.unit.displayName)")
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                Spacer()
                Text("\(activity.durationMinutes) min")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(activity.description)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !activity.equipmentNeeded.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Equipment Needed")
                        .font(.headline)
                        .fontWeight(.semibold)
                    ForEach(activity.equipmentNeeded, id: \.self) { item in
                        Label(item, systemImage: "wrench.and.screwdriver")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            if !activity.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.headline)
                        .fontWeight(.semibold)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 8)], spacing: 8) {
                        ForEach(activity.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
    
    private func perspectivesSection(_ perspectives: ActivityPerspectives) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                if !perspectives.beginnerTips.isEmpty {
                    PerspectiveCard(
                        title: "Beginner Tips",
                        items: perspectives.beginnerTips,
                        color: .green,
                        icon: "lightbulb.fill"
                    )
                }
                
                if !perspectives.expertInsights.isEmpty {
                    PerspectiveCard(
                        title: "Expert Insights",
                        items: perspectives.expertInsights,
                        color: .blue,
                        icon: "star.fill"
                    )
                }
                
                if !perspectives.safetyNotes.isEmpty {
                    PerspectiveCard(
                        title: "Safety Notes",
                        items: perspectives.safetyNotes,
                        color: .orange,
                        icon: "shield.fill"
                    )
                }
                
                if let culturalContext = perspectives.culturalContext {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Cultural Context", systemImage: "globe")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        
                        Text(culturalContext)
                            .font(.caption)
                            .padding()
                            .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
    
    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Sessions")
                .font(.headline)
                .fontWeight(.semibold)
            
            if isLoadingSessions {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if sessions.isEmpty {
                Text("No sessions available at the moment")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(sessions.prefix(3)) { session in
                        SessionCard(session: session) {
                            selectedSession = session
                            showingBookingFlow = true
                        }
                    }
                }
                
                if sessions.count > 3 {
                    Button("View All \(sessions.count) Sessions") {
                        // TODO: Show all sessions view
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                    VStack(alignment: .leading) {
                        Text(activity.location.address)
                            .font(.subheadline)
                        if let neighborhood = activity.location.neighborhood {
                            Text(neighborhood)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // no instructions field in ActivityLocation for now
            }
        }
    }
    
    private func loadSessionsAndPerspectives() async {
        async let sessionsTask: Void = loadSessions()
        async let perspectivesTask: Void = loadPerspectives()
        
        _ = await (sessionsTask, perspectivesTask)
    }
    
    private func loadSessions() async {
        do {
            let loadedSessions = try await viewModel.fetchActivitySessions(activityId: activity.id, dateRange: nil)
            
            await MainActor.run {
                self.sessions = loadedSessions
                self.isLoadingSessions = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingSessions = false
            }
        }
    }
    
    private func loadPerspectives() async {
        let loadedPerspectives = await viewModel.getActivityPerspectives(for: activity.id)
        
        await MainActor.run {
            self.perspectives = loadedPerspectives
        }
    }
}

struct PerspectiveCard: View {
    let title: String
    let items: [String]
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items.prefix(3), id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        
                        Text(item)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                if items.count > 3 {
                    Text("and \(items.count - 3) more...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                }
            }
            .padding()
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SessionCard: View {
    let session: ActivitySession
    let onBook: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(DateFormatter.sessionDate.string(from: session.startAt))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(session.startAt, formatter: DateFormatter.sessionTime) - \(session.endAt, formatter: DateFormatter.sessionTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Capacity: \(session.bookedCount)/\(session.capacity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Book") {
                    onBook()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

extension DateFormatter {
    static let sessionDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    static let sessionTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    ActivityDetailView(
        activity: Activity(
            id: "1",
            providerId: "provider1",
            title: "Rock Climbing Basics",
            category: .fitness,
            description: "Learn the fundamentals of indoor rock climbing in a safe, controlled environment.",
            images: [],
            rules: [],
            minParticipants: 2,
            maxParticipants: 8,
            pricePerUnit: 100,
            unit: .person,
            durationMinutes: 120,
            location: ActivityLocation(lat: 33.5731, lng: -7.5898, address: "123 Climbing Street, Casablanca", neighborhood: nil),
            tags: [],
            ageRestrictions: nil,
            skillLevel: .any,
            equipmentNeeded: [],
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        viewModel: ActivitiesViewModel()
    )
}