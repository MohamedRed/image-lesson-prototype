import SwiftUI
import FriendsService
import Combine

public struct FriendsView: View {
    @StateObject private var viewModel: FriendsViewModel
    @State private var selectedTab: FriendsTab = .conversations
    @State private var activeWatchPartyConversation: Conversation?
    
    public init() {
        _viewModel = StateObject(wrappedValue: FriendsViewModel())
    }
    
    // Dependency-injected initializer to allow providing a custom service (e.g., mock)
    public init(service: FriendsServicing) {
        _viewModel = StateObject(wrappedValue: FriendsViewModel(friendsService: service))
    }
    
    public var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                ConversationsListView(
                    viewModel: viewModel,
                    onStartWatchParty: { conversation in
                        activeWatchPartyConversation = conversation
                    }
                )
                    .tabItem {
                        Image(systemName: "message")
                        Text("Chats")
                    }
                    .tag(FriendsTab.conversations)
                
                FriendsListView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "person.2")
                        Text("Friends")
                    }
                    .tag(FriendsTab.friends)
                
                DiscoverView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Discover")
                    }
                    .tag(FriendsTab.discover)
            }
            .navigationTitle(selectedTab.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(viewModel: viewModel)) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(item: $activeWatchPartyConversation, onDismiss: { activeWatchPartyConversation = nil }) { conversation in
                WatchPartyView(conversation: conversation, viewModel: viewModel)
            }
        }
    }
}

enum FriendsTab: CaseIterable {
    case conversations
    case friends
    case discover
    
    var title: String {
        switch self {
        case .conversations: return "Chats"
        case .friends: return "Friends"
        case .discover: return "Discover"
        }
    }
}

// MARK: - Conversations List

struct ConversationsListView: View {
    @ObservedObject var viewModel: FriendsViewModel
    let onStartWatchParty: (Conversation) -> Void
    
    var body: some View {
        List {
            ForEach(viewModel.conversations) { conversation in
                NavigationLink(destination: ConversationView(conversation: conversation, viewModel: viewModel, onStartWatchParty: onStartWatchParty)) {
                    ConversationRowView(conversation: conversation, viewModel: viewModel)
                }
            }
        }
        .refreshable {
            // Refresh handled by real-time listeners
        }
        .overlay {
            if viewModel.conversations.isEmpty {
                EmptyStateView(
                    image: "message.circle",
                    title: "No Conversations",
                    subtitle: "Start a conversation with a friend to get started"
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: NewConversationView(viewModel: viewModel)) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }
}

struct ConversationRowView: View {
    let conversation: Conversation
    @ObservedObject var viewModel: FriendsViewModel
    
    private var unreadCount: Int {
        guard let userId = viewModel.friendsService.currentUserId else { return 0 }
        return conversation.unreadCount[userId] ?? 0
    }
    
    var body: some View {
        HStack {
            // Conversation avatar
            ConversationAvatarView(conversation: conversation, size: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(conversation.title ?? "Direct Message")
                    .font(.headline)
                    .lineLimit(1)
                
                // Last message preview
                if let lastMessageAt = conversation.lastMessageAt {
                    Text("Last message \(lastMessageAt, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack {
                // Unread badge
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Friends List

struct FriendsListView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var showingRequests = false
    
    private var pendingRequestsCount: Int {
        viewModel.friendRequests.filter { $0.requestedBy != viewModel.friendsService.currentUserId }.count
    }
    
    var body: some View {
        List {
            // Friend requests section
            if pendingRequestsCount > 0 {
                Section {
                    Button(action: { showingRequests = true }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.blue)
                            Text("Friend Requests")
                            Spacer()
                            Text("\(pendingRequestsCount)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            
            // Online friends section
            Section("Online") {
                ForEach(viewModel.onlineFriends) { friend in
                    FriendRowView(friend: friend, viewModel: viewModel)
                }
            }
            
            // All friends section
            Section("All Friends") {
                ForEach(viewModel.friends) { friend in
                    FriendRowView(friend: friend, viewModel: viewModel)
                }
            }
        }
        .refreshable {
            // Refresh handled by real-time listeners
        }
        .overlay {
            if viewModel.friends.isEmpty {
                EmptyStateView(
                    image: "person.2.circle",
                    title: "No Friends Yet",
                    subtitle: "Discover and add friends to get started"
                )
            }
        }
        .sheet(isPresented: $showingRequests) {
            NavigationView {
                FriendRequestsView(viewModel: viewModel)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: AddFriendView(viewModel: viewModel)) {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
    }
}

struct FriendRowView: View {
    let friend: FriendProfile
    @ObservedObject var viewModel: FriendsViewModel
    
    private var presenceStatus: PresenceStatus.Status {
        viewModel.presenceStatuses[friend.id]?.status ?? .offline
    }
    
    var body: some View {
        NavigationLink(destination: FriendProfileView(friend: friend, viewModel: viewModel)) {
            HStack {
                // Avatar with presence indicator
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: friend.photoURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    
                    // Presence indicator
                    Circle()
                        .fill(presenceStatus.color)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                
                VStack(alignment: .leading) {
                    Text(friend.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let handle = friend.handle {
                        Text("@\(handle)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let city = friend.city {
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Discover View

struct DiscoverView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var searchText = ""
    @State private var searchResults: [FriendProfile] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack {
            // Search bar
            SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
            
            if isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                EmptyStateView(
                    image: "magnifyingglass.circle",
                    title: "No Results",
                    subtitle: "Try searching with a different name or handle"
                )
            } else {
                List {
                    if !searchText.isEmpty {
                        Section("Search Results") {
                            ForEach(searchResults) { user in
                                DiscoverUserRowView(user: user, viewModel: viewModel)
                            }
                        }
                    }
                    
                    Section {
                        NavigationLink(destination: ContactsImportView(viewModel: viewModel)) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Find Friends from Contacts")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        NavigationLink(destination: InviteView(viewModel: viewModel)) {
                            HStack {
                                Image(systemName: "link.circle")
                                    .foregroundColor(.green)
                                Text("Invite Friends")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: searchText) { newValue in
            if newValue.isEmpty {
                searchResults = []
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

struct DiscoverUserRowView: View {
    let user: FriendProfile
    @ObservedObject var viewModel: FriendsViewModel
    @State private var isLoading = false
    
    var body: some View {
        HStack {
            // Avatar
            AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.gray)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(user.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                if let handle = user.handle {
                    Text("@\(handle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let city = user.city {
                    Text(city)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button("Add") {
                    sendFriendRequest()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func sendFriendRequest() {
        isLoading = true
        Task {
            do {
                try await viewModel.sendFriendRequest(to: user.id)
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct EmptyStateView: View {
    let image: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: image)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct ConversationAvatarView: View {
    let conversation: Conversation
    let size: CGFloat
    
    var body: some View {
        Group {
            if conversation.type == .group {
                // Group avatar - show overlapping circles
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: size, height: size)
                    
                    Image(systemName: "person.3.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundColor(.blue)
                }
            } else {
                // Direct message - show other participant's avatar
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: size * 0.8))
                            .foregroundColor(.gray)
                    )
            }
        }
    }
}

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        searchBar.placeholder = "Search users..."
        searchBar.searchBarStyle = .minimal
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UISearchBarDelegate {
        let parent: SearchBar
        
        init(_ parent: SearchBar) {
            self.parent = parent
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }
        
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            parent.onSearchButtonClicked()
            searchBar.resignFirstResponder()
        }
    }
}

// MARK: - Extensions

extension PresenceStatus.Status {
    var color: Color {
        switch self {
        case .online: return .green
        case .away: return .yellow
        case .dnd: return .red
        case .offline: return .gray
        }
    }
}

#if DEBUG
struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsView()
    }
}
#endif