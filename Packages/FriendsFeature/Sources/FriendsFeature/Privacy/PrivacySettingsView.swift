import SwiftUI
import FriendsService

struct PrivacySettingsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @StateObject private var privacyViewModel = PrivacySettingsViewModel()
    @State private var showingBlockedUsers = false
    @State private var showingCircleManagement = false
    
    var body: some View {
        List {
            // Presence Settings
            Section("Presence & Status") {
                HStack {
                    Text("Show Online Status")
                    Spacer()
                    Toggle("", isOn: $privacyViewModel.showOnlineStatus)
                }
                
                HStack {
                    Text("Show Last Seen")
                    Spacer()
                    Toggle("", isOn: $privacyViewModel.showLastSeen)
                }
                
                HStack {
                    Text("Show Typing Indicators")
                    Spacer()
                    Toggle("", isOn: $privacyViewModel.showTypingIndicators)
                }
            }
            
            // Message Settings
            Section("Messages") {
                HStack {
                    Text("Read Receipts")
                    Spacer()
                    Toggle("", isOn: $privacyViewModel.readReceipts)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Who can message me")
                    Picker("Message Access", selection: $privacyViewModel.messageAccess) {
                        ForEach(MessageAccessLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            // Contact Discovery
            Section("Contact Discovery") {
                HStack {
                    Text("Allow Contact Discovery")
                    Spacer()
                    Toggle("", isOn: $privacyViewModel.allowContactDiscovery)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("When enabled, friends can find you by your phone number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Profile Visibility
            Section("Profile") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Profile visibility")
                    Picker("Profile Visibility", selection: $privacyViewModel.profileVisibility) {
                        ForEach(ProfileVisibility.allCases, id: \.self) { visibility in
                            Text(visibility.displayName).tag(visibility)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                HStack {
                    Text("Show City")
                    Spacer()
                    Toggle("", isOn: $privacyViewModel.showCity)
                }
            }
            
            // Friend Circles
            Section("Friend Circles") {
                NavigationLink("Manage Circles", destination: FriendCirclesView(viewModel: viewModel))
                
                Text("Organize friends into circles to control what they can see")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Blocked Users
            Section("Blocked Users") {
                NavigationLink("Blocked Users", destination: BlockedUsersView(viewModel: viewModel))
                    .badge(privacyViewModel.blockedUsersCount)
            }
            
            // Data & Storage
            Section("Data") {
                Button("Clear Chat History") {
                    // TODO: Implement chat history clearing
                }
                .foregroundColor(.red)
                
                Button("Download My Data") {
                    // TODO: Implement data export
                }
                
                Button("Delete Account") {
                    // TODO: Implement account deletion
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Privacy Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            privacyViewModel.loadSettings()
        }
        .onChange(of: privacyViewModel.showOnlineStatus) { _ in
            privacyViewModel.saveSettings()
        }
        .onChange(of: privacyViewModel.readReceipts) { _ in
            privacyViewModel.saveSettings()
        }
        // Add onChange for other settings...
    }
}

// MARK: - Privacy Settings ViewModel

@MainActor
class PrivacySettingsViewModel: ObservableObject {
    @Published var showOnlineStatus = true
    @Published var showLastSeen = true
    @Published var showTypingIndicators = true
    @Published var readReceipts = true
    @Published var messageAccess: MessageAccessLevel = .friends
    @Published var allowContactDiscovery = true
    @Published var profileVisibility: ProfileVisibility = .friends
    @Published var showCity = true
    @Published var blockedUsersCount = 0
    
    func loadSettings() {
        // TODO: Load from UserDefaults or Firebase
        // For now using defaults
    }
    
    func saveSettings() {
        // TODO: Save to UserDefaults and sync to Firebase
        print("Saving privacy settings...")
    }
}

// MARK: - Privacy Enums

enum MessageAccessLevel: String, CaseIterable {
    case everyone = "everyone"
    case friends = "friends"
    case closeFriends = "close_friends"
    
    var displayName: String {
        switch self {
        case .everyone: return "Everyone"
        case .friends: return "Friends"
        case .closeFriends: return "Close Friends"
        }
    }
}

enum ProfileVisibility: String, CaseIterable {
    case everyone = "everyone"
    case friends = "friends"
    case closeFriends = "close_friends"
    
    var displayName: String {
        switch self {
        case .everyone: return "Everyone"
        case .friends: return "Friends"
        case .closeFriends: return "Close Friends"
        }
    }
}

// MARK: - Friend Circles View

struct FriendCirclesView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var circles: [FriendCircle] = []
    @State private var showingCreateCircle = false
    
    var body: some View {
        List {
            Section {
                Button("Create New Circle") {
                    showingCreateCircle = true
                }
                .foregroundColor(.blue)
            }
            
            Section("Your Circles") {
                ForEach(circles) { circle in
                    NavigationLink(destination: CircleDetailView(circle: circle, viewModel: viewModel)) {
                        HStack {
                            Circle()
                                .fill(circle.color)
                                .frame(width: 12, height: 12)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(circle.name)
                                    .font(.headline)
                                
                                Text("\(circle.members.count) friends")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .onDelete(perform: deleteCircles)
            }
        }
        .navigationTitle("Friend Circles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingCreateCircle) {
            CreateCircleView(circles: $circles)
        }
        .onAppear {
            loadCircles()
        }
    }
    
    private func loadCircles() {
        // TODO: Load from backend
        circles = [
            FriendCircle(
                id: "family",
                name: "Family",
                color: .red,
                members: []
            ),
            FriendCircle(
                id: "close_friends",
                name: "Close Friends",
                color: .green,
                members: []
            ),
            FriendCircle(
                id: "work",
                name: "Work",
                color: .blue,
                members: []
            )
        ]
    }
    
    private func deleteCircles(offsets: IndexSet) {
        circles.remove(atOffsets: offsets)
        // TODO: Delete from backend
    }
}

// MARK: - Circle Detail View

struct CircleDetailView: View {
    let circle: FriendCircle
    @ObservedObject var viewModel: FriendsViewModel
    @State private var members: [FriendProfile] = []
    @State private var showingAddFriends = false
    
    var body: some View {
        List {
            Section("Circle Settings") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(circle.name)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Color")
                    Spacer()
                    Circle()
                        .fill(circle.color)
                        .frame(width: 20, height: 20)
                }
            }
            
            Section("Members (\(members.count))") {
                if members.isEmpty {
                    Text("No friends in this circle")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(members) { member in
                        HStack {
                            AsyncImage(url: URL(string: member.photoURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            Text(member.displayName)
                            
                            Spacer()
                        }
                    }
                    .onDelete(perform: removeMember)
                }
                
                Button("Add Friends") {
                    showingAddFriends = true
                }
                .foregroundColor(.blue)
            }
        }
        .navigationTitle(circle.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddFriends) {
            AddFriendsToCircleView(circle: circle, viewModel: viewModel) { selectedFriends in
                members.append(contentsOf: selectedFriends)
            }
        }
        .onAppear {
            loadMembers()
        }
    }
    
    private func loadMembers() {
        // TODO: Load circle members from backend
        members = []
    }
    
    private func removeMember(offsets: IndexSet) {
        members.remove(atOffsets: offsets)
        // TODO: Remove from backend
    }
}

// MARK: - Create Circle View

struct CreateCircleView: View {
    @Binding var circles: [FriendCircle]
    @Environment(\.dismiss) private var dismiss
    
    @State private var circleName = ""
    @State private var selectedColor = Color.blue
    
    let availableColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .indigo, .purple, .pink
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Circle Details") {
                    TextField("Circle Name", text: $circleName)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                            ForEach(availableColors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createCircle()
                    }
                    .disabled(circleName.isEmpty)
                }
            }
        }
    }
    
    private func createCircle() {
        let newCircle = FriendCircle(
            id: UUID().uuidString,
            name: circleName,
            color: selectedColor,
            members: []
        )
        
        circles.append(newCircle)
        // TODO: Save to backend
        
        dismiss()
    }
}

// MARK: - Add Friends to Circle View

struct AddFriendsToCircleView: View {
    let circle: FriendCircle
    @ObservedObject var viewModel: FriendsViewModel
    let onAdd: ([FriendProfile]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFriends = Set<String>()
    
    var body: some View {
        NavigationView {
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
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
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
            .navigationTitle("Add to \(circle.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add (\(selectedFriends.count))") {
                        addSelectedFriends()
                    }
                    .disabled(selectedFriends.isEmpty)
                }
            }
        }
    }
    
    private func addSelectedFriends() {
        let friendsToAdd = viewModel.friends.filter { selectedFriends.contains($0.id) }
        onAdd(friendsToAdd)
        dismiss()
    }
}

// MARK: - Blocked Users View

struct BlockedUsersView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var blockedUsers: [BlockedUser] = []
    
    var body: some View {
        List {
            if blockedUsers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    
                    Text("No Blocked Users")
                        .font(.headline)
                    
                    Text("When you block someone, they'll appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(blockedUsers) { blockedUser in
                    HStack {
                        AsyncImage(url: URL(string: blockedUser.photoURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(blockedUser.displayName)
                                .font(.headline)
                            
                            Text("Blocked \(blockedUser.blockedAt, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Unblock") {
                            unblockUser(blockedUser)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBlockedUsers()
        }
    }
    
    private func loadBlockedUsers() {
        // TODO: Load from backend
        blockedUsers = []
    }
    
    private func unblockUser(_ blockedUser: BlockedUser) {
        Task {
            do {
                try await viewModel.unblockUser(blockedUser.id)
                blockedUsers.removeAll { $0.id == blockedUser.id }
            } catch {
                // Handle error
            }
        }
    }
}

// MARK: - Data Models

struct FriendCircle: Identifiable {
    let id: String
    let name: String
    let color: Color
    let members: [String]
}

struct BlockedUser: Identifiable {
    let id: String
    let displayName: String
    let photoURL: String?
    let blockedAt: Date
}

#if DEBUG
struct PrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PrivacySettingsView(viewModel: FriendsViewModel())
        }
    }
}
#endif