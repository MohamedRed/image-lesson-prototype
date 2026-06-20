import SwiftUI
import ActivitiesService

struct GroupDetailView: View {
    let group: ActivityGroup
    @ObservedObject var viewModel: ActivitiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var suggestions: [ActivitySuggestion] = []
    @State private var showingInviteUsers = false
    @State private var showingActivityBooking = false
    @State private var selectedActivity: Activity?
    @State private var invitationResponse: InvitationResponse?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Group Header
                    groupHeaderSection
                    
                    // Members Section
                    membersSection
                    
                    // Preferences Section
                    preferencesSection
                    
                    // Current Booking (omitted in this build)
                    
                    // AI Suggestions
                    if !suggestions.isEmpty {
                        suggestionsSection
                    }
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Group Details")
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
            await loadSuggestions()
        }
        .sheet(isPresented: $showingInviteUsers) {
            InviteUsersView(group: group, viewModel: viewModel)
        }
        .sheet(isPresented: $showingActivityBooking) {
            if let activity = selectedActivity {
                ActivityDetailView(activity: activity, viewModel: viewModel)
            }
        }
        .alert("Invitation Response", isPresented: .constant(invitationResponse != nil)) {
            if let response = invitationResponse {
                Button("Accept") {
                    Task {
                        await viewModel.respondToInvitation(groupId: group.id, response: .accepted)
                        invitationResponse = nil
                        dismiss()
                    }
                }
                Button("Decline") {
                    Task {
                        await viewModel.respondToInvitation(groupId: group.id, response: .declined)
                        invitationResponse = nil
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {
                    invitationResponse = nil
                }
            }
        } message: {
            Text("Respond to group invitation")
        }
    }
    
    private var groupHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(group.status.displayName)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(group.status.color.opacity(0.15), in: Capsule())
                        .foregroundColor(group.status.color)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                if isGroupOrganizer {
                    Button("Invite") {
                        showingInviteUsers = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            Text("Created \(RelativeDateTimeFormatter().localizedString(for: group.createdAt, relativeTo: Date()))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members (\(group.participantUserIds.count))")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(group.participantUserIds, id: \.self) { userId in
                    MemberRow(
                        userId: userId,
                        isOrganizer: userId == group.organizerId,
                        isCurrentUser: userId == getCurrentUserId()
                    )
                }
            }
            
            if !group.invitedUserIds.isEmpty {
                Text("Pending Invitations (\(group.invitedUserIds.count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
                
                LazyVStack(spacing: 8) {
                    ForEach(group.invitedUserIds, id: \.self) { userId in
                        PendingInvitationRow(userId: userId)
                    }
                }
            }
        }
    }
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Group Preferences")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                if let categories = group.preferences.categories, !categories.isEmpty {
                    PreferenceRow(
                        title: "Activity Types",
                        value: categories.map { $0.displayName }.joined(separator: ", ")
                    )
                }
                
                if let skillLevel = group.preferences.skillLevel {
                    PreferenceRow(
                        title: "Skill Level",
                        value: skillLevel
                    )
                }
                
                if let timeBands = group.preferences.timeBands, !timeBands.isEmpty {
                    PreferenceRow(
                        title: "Preferred Days",
                        value: timeBands.joined(separator: ", ")
                    )
                }
                
                if let priceRange = group.preferences.priceRange {
                    PreferenceRow(
                        title: "Budget",
                        value: "\(Int(priceRange.min)) - \(Int(priceRange.max)) MAD"
                    )
                }
            }
        }
    }
    
    private func currentBookingSection(_ bookingId: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Booking")
                .font(.headline)
                .fontWeight(.semibold)
            
            // TODO: Load and display booking details
            HStack {
                VStack(alignment: .leading) {
                    Text("Booking #\(bookingId.prefix(8))")
                        .fontWeight(.medium)
                    Text("Status: Confirmed")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Button("View Details") {
                    // TODO: Navigate to booking details
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Suggestions")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(suggestions.prefix(3), id: \.activityId) { suggestion in
                    SuggestionCard(suggestion: suggestion) {
                        // TODO: Load and show activity details
                        selectedActivity = nil // Placeholder
                        showingActivityBooking = true
                    }
                }
            }
            
            if suggestions.count > 3 {
                Button("View All Suggestions") {
                    // TODO: Show all suggestions view
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if isInvitedUser {
                HStack(spacing: 12) {
                    Button("Accept Invitation") {
                        invitationResponse = .accepted
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("Decline") {
                        invitationResponse = .declined
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            } else if isGroupMember && !isGroupOrganizer {
                Button("Leave Group") {
                    Task {
                        await viewModel.leaveGroup(groupId: group.id)
                        dismiss()
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var isGroupOrganizer: Bool {
        group.organizerId == getCurrentUserId()
    }
    
    private var isGroupMember: Bool {
        group.participantUserIds.contains(getCurrentUserId())
    }
    
    private var isInvitedUser: Bool {
        group.invitedUserIds.contains(getCurrentUserId())
    }
    
    private func loadSuggestions() async {
        suggestions = await viewModel.generateGroupSuggestions(for: group.id)
    }
    
    private func getCurrentUserId() -> String {
        // TODO: Get from auth service
        return "current_user_id"
    }
}

struct MemberRow: View {
    let userId: String
    let isOrganizer: Bool
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title3)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                HStack {
                    Text(userId) // TODO: Load user name
                        .fontWeight(.medium)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                if isOrganizer {
                    Text("Group Organizer")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("Member")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct PendingInvitationRow: View {
    let userId: String
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title3)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading) {
                Text(userId) // TODO: Load user name
                    .fontWeight(.medium)
                Text("Invitation Pending")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct PreferenceRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct SuggestionCard: View {
    let suggestion: ActivitySuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("\(Int(suggestion.matchScore))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.purple)
                }
                
                Text(suggestion.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding()
            .background(.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.purple.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct InviteUsersView: View {
    let group: ActivityGroup
    @ObservedObject var viewModel: ActivitiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedUserIds: Set<String> = []
    @State private var inviteMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Search
                SearchBar(text: $searchText, placeholder: "Search users...")
                
                // User List - TODO: Implement user search
                List {
                    Text("User search functionality to be implemented")
                        .foregroundColor(.secondary)
                }
                
                // Invite Message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invitation Message (Optional)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextEditor(text: $inviteMessage)
                        .frame(height: 60)
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding()
                
                // Send Invites Button
                Button("Send Invitations") {
                    Task {
                        await viewModel.inviteToGroup(
                            groupId: group.id,
                            userIds: Array(selectedUserIds),
                            message: inviteMessage.isEmpty ? nil : inviteMessage
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding()
                .disabled(selectedUserIds.isEmpty)
            }
            .navigationTitle("Invite Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal)
    }
}

extension DateFormatter {
    static let relativeDate: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}

#Preview {
    GroupDetailView(
        group: ActivityGroup(
            id: "group1",
            organizerId: "user1",
            name: "Weekend Warriors",
            activityId: nil,
            sessionId: nil,
            cityId: "casablanca",
            status: .planning,
            preferences: GroupPreferences(
                categories: [.sport, .fitness],
                skillLevel: "intermediate",
                timeBands: ["weekends"],
                priceRange: BudgetRange(min: 10, max: 100),
                preferredLocation: nil
            ),
            invitedUserIds: ["user3"],
            participantUserIds: ["user1", "user2"],
            partnerRequestId: nil,
            chatThreadId: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        viewModel: ActivitiesViewModel()
    )
}