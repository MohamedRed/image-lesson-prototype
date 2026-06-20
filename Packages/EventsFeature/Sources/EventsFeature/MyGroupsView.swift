import SwiftUI
import EventsService

struct MyGroupsView: View {
    @ObservedObject var viewModel: EventsViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.myGroups.isEmpty {
                    EmptyGroupsView()
                } else {
                    ForEach(viewModel.myGroups) { group in
                        GroupCard(group: group) {
                            viewModel.selectedGroup = group
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadMyGroups()
        }
        .sheet(item: $viewModel.selectedGroup) { group in
            GroupDetailView(group: group, viewModel: viewModel)
        }
    }
}

struct EmptyGroupsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Groups Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Join or create groups to plan events with friends")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 50)
    }
}

struct GroupCard: View {
    let group: AttendanceGroup
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("\(group.participantUserIds.count) members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    StatusBadge(status: group.status.rawValue)
                }
                
                if !group.invitedUserIds.isEmpty {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("\(group.invitedUserIds.count) pending invites")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Divider()
                
                HStack {
                    if let createdAt = group.createdAt {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Created")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(createdAt, style: .date)
                                .font(.caption)
                        }
                    }
                    
                    Spacer()
                    
                    Button("View Details") {
                        onTap()
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct GroupDetailView: View {
    let group: AttendanceGroup
    @ObservedObject var viewModel: EventsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showInviteFriends = false
    @State private var showOrderCreation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Group Info
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                Text("Group for Event")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            StatusBadge(status: group.status.rawValue)
                        }
                        
                        // Members Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Members (\(group.participantUserIds.count))")
                                .font(.headline)
                            
                            // TODO: Show actual user profiles
                            ForEach(group.participantUserIds, id: \.self) { userId in
                                HStack {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.3))
                                        .frame(width: 30, height: 30)
                                    
                                    Text("User \(userId.prefix(8))")
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    if userId == group.organizerId {
                                        Text("Organizer")
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        
                        // Pending Invites
                        if !group.invitedUserIds.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Pending Invites (\(group.invitedUserIds.count))")
                                    .font(.headline)
                                
                                ForEach(group.invitedUserIds, id: \.self) { userId in
                                    HStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 30, height: 30)
                                        
                                        Text("User \(userId.prefix(8))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text("Invited")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                        
                        // Chat Thread
                        if let chatThreadId = group.chatThreadId {
                            Divider()
                            
                            Button("Open Group Chat") {
                                // TODO: Navigate to chat
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Group Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Invite Friends") {
                            showInviteFriends = true
                        }
                        
                        if group.status == .planning {
                            Button("Create Order") {
                                showOrderCreation = true
                            }
                        }
                        
                        if group.organizerId != "current_user" { // TODO: Check actual user ID
                            Button("Leave Group", role: .destructive) {
                                Task {
                                    await viewModel.leaveGroup(group.id!)
                                    dismiss()
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showInviteFriends) {
            InviteFriendsView(group: group, viewModel: viewModel)
        }
        .sheet(isPresented: $showOrderCreation) {
            CreateOrderView(group: group, viewModel: viewModel)
        }
    }
}