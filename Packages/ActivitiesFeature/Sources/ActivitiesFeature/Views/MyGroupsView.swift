import SwiftUI
import ActivitiesService

struct MyGroupsView: View {
    @ObservedObject var viewModel: ActivitiesViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header
                headerSection
                
                // Create Group Button
                createGroupButton
                
                // Groups List
                if viewModel.myGroups.isEmpty {
                    EmptyStateView(
                        title: "No Groups Yet",
                        message: "Create your first group to start planning activities with friends",
                        systemImage: "person.3"
                    )
                    .frame(height: 300)
                } else {
                    groupsList
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadMyGroups()
        }
        .sheet(isPresented: $viewModel.showingCreateGroup) {
            CreateGroupView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingGroupDetail) {
            if let group = viewModel.selectedGroup {
                GroupDetailView(group: group, viewModel: viewModel)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.blue)
                Text("My Groups")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Text("Coordinate activities with your friends and family")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var createGroupButton: some View {
        Button {
            viewModel.showingCreateGroup = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Create New Group")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding()
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
    }
    
    private var groupsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.myGroups) { group in
                GroupCard(group: group) {
                    viewModel.selectGroup(group)
                }
            }
        }
    }
}

struct GroupCard: View {
    let group: ActivityGroup
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        Text(group.status.displayName)
                            .font(.subheadline)
                            .foregroundColor(group.status.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(group.status.color.opacity(0.15), in: Capsule())
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Participants
                HStack {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(group.participantUserIds.count) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !group.invitedUserIds.isEmpty {
                        Text("• \(group.invitedUserIds.count) pending invites")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                }
                
                // Preferences
                if let categories = group.preferences.categories, !categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(categories.prefix(3), id: \.self) { category in
                                Text(category.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.gray.opacity(0.15), in: Capsule())
                                    .foregroundColor(.primary)
                            }
                            if categories.count > 3 {
                                Text("+\(categories.count - 3)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct CreateGroupView: View {
    @ObservedObject var viewModel: ActivitiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupName = ""
    @State private var selectedCategories: Set<ActivityCategory> = []
    @State private var selectedSkillLevel: SkillLevel?
    @State private var inviteUserIds: [String] = []
    @State private var showingUserPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Group Details") {
                    TextField("Group Name", text: $groupName)
                }
                
                Section("Activity Preferences") {
                    MultipleSelectionRow(
                        title: "Activity Categories",
                        options: ActivityCategory.allCases,
                        selections: $selectedCategories
                    ) { category in
                        category.displayName
                    }
                    
                    Picker("Skill Level", selection: $selectedSkillLevel) {
                        Text("Any Level").tag(Optional<SkillLevel>(nil))
                        ForEach(SkillLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(Optional(level))
                        }
                    }
                }
                
                Section("Invite Members (Optional)") {
                    Button("Add Members") {
                        showingUserPicker = true
                    }
                    
                    ForEach(inviteUserIds, id: \.self) { userId in
                        HStack {
                            Text(userId) // TODO: Show user name
                            Spacer()
                            Button("Remove") {
                                inviteUserIds.removeAll { $0 == userId }
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            let preferences = GroupPreferences(
                                categories: Array(selectedCategories),
                                skillLevel: selectedSkillLevel?.rawValue
                            )
                            
                            await viewModel.createGroup(
                                name: groupName,
                                preferences: preferences,
                                invitedUserIds: inviteUserIds
                            )
                        }
                    }
                    .disabled(groupName.isEmpty || selectedCategories.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingUserPicker) {
            // TODO: Implement user picker
            Text("User Picker - TODO")
        }
    }
}

struct MultipleSelectionRow<T: Hashable>: View {
    let title: String
    let options: [T]
    @Binding var selections: Set<T>
    let displayName: (T) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        if selections.contains(option) {
                            selections.remove(option)
                        } else {
                            selections.insert(option)
                        }
                    } label: {
                        Text(displayName(option))
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selections.contains(option) ? .blue : .gray.opacity(0.2),
                                in: Capsule()
                            )
                            .foregroundColor(selections.contains(option) ? .white : .primary)
                    }
                }
            }
        }
    }
}

// MARK: - Extensions
extension GroupStatus {
    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .booking: return "Booking"
        case .confirmed: return "Confirmed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .planning: return .orange
        case .booking: return .blue
        case .confirmed: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

extension ActivityCategory {
    var displayName: String {
        switch self {
        case .sport: return "Sports"
        case .fitness: return "Fitness"
        case .culture: return "Arts & Culture"
        case .food: return "Food & Dining"
        case .game: return "Games"
        case .education: return "Education"
        case .outdoor: return "Outdoor"
        case .workshop: return "Workshop"
        case .other: return "Other"
        }
    }
}

extension SkillLevel {
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .any: return "Any Level"
        }
    }
}

#Preview {
    NavigationView {
        MyGroupsView(viewModel: ActivitiesViewModel())
    }
}