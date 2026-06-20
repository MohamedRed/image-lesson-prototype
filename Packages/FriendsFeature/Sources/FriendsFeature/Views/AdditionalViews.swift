import SwiftUI
import FriendsService

// MARK: - Friend Requests View

struct FriendRequestsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        List {
            Section("Received") {
                ForEach(viewModel.incomingRequests) { request in
                    FriendRequestRowView(request: request, viewModel: viewModel, isIncoming: true)
                }
            }
            
            Section("Sent") {
                ForEach(viewModel.outgoingRequests) { request in
                    FriendRequestRowView(request: request, viewModel: viewModel, isIncoming: false)
                }
            }
        }
        .navigationTitle("Friend Requests")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FriendRequestRowView: View {
    let request: Friendship
    @ObservedObject var viewModel: FriendsViewModel
    let isIncoming: Bool
    @State private var isLoading = false
    
    private var otherUserId: String {
        request.users.first { $0 != viewModel.friendsService.currentUserId } ?? ""
    }
    
    var body: some View {
        HStack {
            // Avatar placeholder
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading) {
                Text("User \(otherUserId.prefix(8))")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(isIncoming ? "Wants to be friends" : "Request sent")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else if isIncoming {
                HStack {
                    Button("Accept") {
                        acceptRequest()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Decline") {
                        declineRequest()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button("Cancel") {
                    cancelRequest()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func acceptRequest() {
        isLoading = true
        Task {
            try? await viewModel.acceptFriendRequest(request)
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func declineRequest() {
        isLoading = true
        Task {
            try? await viewModel.declineFriendRequest(request)
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func cancelRequest() {
        isLoading = true
        Task {
            try? await viewModel.cancelFriendRequest(request)
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Friend Profile View

struct FriendProfileView: View {
    let friend: FriendProfile
    @ObservedObject var viewModel: FriendsViewModel
    @State private var mutualFriends: [FriendProfile] = []
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile header
                VStack(spacing: 12) {
                    AsyncImage(url: URL(string: friend.photoURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    
                    Text(friend.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let handle = friend.handle {
                        Text("@\(handle)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let city = friend.city {
                        Text(city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Presence status
                    HStack {
                        Circle()
                            .fill(viewModel.getPresenceStatus(friend.id).color)
                            .frame(width: 8, height: 8)
                        Text(viewModel.getPresenceStatus(friend.id).rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Actions
                VStack(spacing: 12) {
                    Button("Send Message") {
                        startConversation()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("Remove Friend") {
                        removeFriend()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                // Mutual friends
                if !mutualFriends.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mutual Friends")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                            ForEach(mutualFriends) { mutualFriend in
                                VStack {
                                    AsyncImage(url: URL(string: mutualFriend.photoURL ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                    
                                    Text(mutualFriend.displayName)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle(friend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMutualFriends()
        }
    }
    
    private func startConversation() {
        Task {
            do {
                let conversation = try await viewModel.startConversation(with: [friend.id])
                // TODO: Navigate to conversation
            } catch {
                // Handle error
            }
        }
    }
    
    private func removeFriend() {
        Task {
            try? await viewModel.removeFriend(friend.id)
        }
    }
    
    private func loadMutualFriends() async {
        do {
            mutualFriends = try await viewModel.getMutualFriends(with: friend.id)
        } catch {
            // Handle error silently
        }
    }
}

// MARK: - Additional Views

struct AddFriendView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var searchText = ""
    @State private var searchResults: [FriendProfile] = []
    @State private var isSearching = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
                
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(searchResults) { user in
                            DiscoverUserRowView(user: user, viewModel: viewModel)
                        }
                    }
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty, searchText.count >= 3 else { return }
        
        isSearching = true
        Task {
            do {
                let results = try await viewModel.searchUsers(query: searchText)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
}

struct NewConversationView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var selectedFriends = Set<String>()
    @State private var groupName = ""
    @State private var isCreating = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if selectedFriends.count > 1 {
                    TextField("Group Name", text: $groupName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }
                
                List {
                    ForEach(viewModel.friends) { friend in
                        HStack {
                            AsyncImage(url: URL(string: friend.photoURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            Text(friend.displayName)
                            
                            Spacer()
                            
                            if selectedFriends.contains(friend.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedFriends.contains(friend.id) {
                                selectedFriends.remove(friend.id)
                            } else {
                                selectedFriends.insert(friend.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createConversation()
                    }
                    .disabled(selectedFriends.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createConversation() {
        isCreating = true
        
        Task {
            do {
                if selectedFriends.count == 1 {
                    _ = try await viewModel.startConversation(with: Array(selectedFriends))
                } else {
                    let title = groupName.isEmpty ? nil : groupName
                    _ = try await viewModel.createGroupConversation(with: Array(selectedFriends), title: title ?? "Group Chat")
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }
}

struct ContactsImportView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @StateObject private var contactsViewModel: ContactsImportViewModel
    
    init(viewModel: FriendsViewModel) {
        self.viewModel = viewModel
        self._contactsViewModel = StateObject(wrappedValue: ContactsImportViewModel(friendsService: viewModel.friendsService))
    }
    
    var body: some View {
        VStack {
            if !contactsViewModel.hasRequestedPermission {
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Find Friends from Contacts")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("We'll help you find friends who are already using the app by securely comparing your contacts.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button("Import Contacts") {
                        contactsViewModel.requestContactsPermission()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                List {
                    ForEach(contactsViewModel.matchedUsers) { matchedUser in
                        MatchedContactRowView(matchedUser: matchedUser, viewModel: viewModel)
                    }
                }
                .overlay {
                    if contactsViewModel.isLoading {
                        ProgressView("Finding friends...")
                    } else if contactsViewModel.matchedUsers.isEmpty {
                        EmptyStateView(
                            image: "person.crop.circle.badge.questionmark",
                            title: "No Friends Found",
                            subtitle: "None of your contacts are using the app yet"
                        )
                    }
                }
                .task {
                    contactsViewModel.loadContacts()
                    try? await contactsViewModel.findMatchingUsers()
                }
            }
        }
        .navigationTitle("Import Contacts")
        .navigationBarTitleDisplayMode(.inline)
    }
}