import Foundation
import SwiftUI
import FriendsService

// MARK: - Deep Link Handler

public class FriendsDeepLinkHandler: ObservableObject {
    @Published var pendingNavigation: FriendsDeepLinkDestination?
    
    private let friendsService: FriendsServicing
    
    public init(friendsService: FriendsServicing) {
        self.friendsService = friendsService
    }
    
    public func handle(url: URL) -> Bool {
        guard url.scheme == "liive" || url.host?.contains("liive") == true else {
            return false
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = url.path
        
        // Handle friends-specific deep links
        if path.hasPrefix("/friends/") {
            return handleFriendsDeepLink(path: path, components: components)
        }
        
        return false
    }
    
    private func handleFriendsDeepLink(path: String, components: URLComponents?) -> Bool {
        let pathComponents = path.split(separator: "/").map(String.init)
        
        guard pathComponents.count >= 2, pathComponents[0] == "friends" else {
            return false
        }
        
        switch pathComponents[1] {
        case "invite":
            return handleInviteLink(pathComponents: pathComponents, components: components)
        case "convo", "conversation":
            return handleConversationLink(pathComponents: pathComponents)
        case "call":
            return handleCallLink(pathComponents: pathComponents)
        case "user":
            return handleUserLink(pathComponents: pathComponents)
        default:
            // Default to opening friends feature
            pendingNavigation = .friendsMain
            return true
        }
    }
    
    private func handleInviteLink(pathComponents: [String], components: URLComponents?) -> Bool {
        guard pathComponents.count >= 3 else {
            return false
        }
        
        let inviteCode = pathComponents[2]
        pendingNavigation = .invite(code: inviteCode)
        return true
    }
    
    private func handleConversationLink(pathComponents: [String]) -> Bool {
        guard pathComponents.count >= 3 else {
            return false
        }
        
        let conversationId = pathComponents[2]
        pendingNavigation = .conversation(id: conversationId)
        return true
    }
    
    private func handleCallLink(pathComponents: [String]) -> Bool {
        guard pathComponents.count >= 3 else {
            return false
        }
        
        let conversationId = pathComponents[2]
        let callType: CallType = pathComponents.contains("video") ? .video : .voice
        
        pendingNavigation = .call(conversationId: conversationId, type: callType)
        return true
    }
    
    private func handleUserLink(pathComponents: [String]) -> Bool {
        guard pathComponents.count >= 3 else {
            return false
        }
        
        let userId = pathComponents[2]
        pendingNavigation = .userProfile(id: userId)
        return true
    }
    
    public func clearPendingNavigation() {
        pendingNavigation = nil
    }
}

// MARK: - Deep Link Destinations

public enum FriendsDeepLinkDestination {
    case friendsMain
    case conversation(id: String)
    case call(conversationId: String, type: CallType)
    case invite(code: String)
    case userProfile(id: String)
}

public enum CallType {
    case voice
    case video
}

// MARK: - Deep Link Navigation View

public struct FriendsDeepLinkNavigationView: View {
    @ObservedObject var deepLinkHandler: FriendsDeepLinkHandler
    @ObservedObject var viewModel: FriendsViewModel
    
    public init(deepLinkHandler: FriendsDeepLinkHandler, viewModel: FriendsViewModel) {
        self.deepLinkHandler = deepLinkHandler
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Group {
            if let destination = deepLinkHandler.pendingNavigation {
                destinationView(for: destination)
            } else {
                FriendsView()
            }
        }
        .onAppear {
            // Clear navigation after showing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                deepLinkHandler.clearPendingNavigation()
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: FriendsDeepLinkDestination) -> some View {
        switch destination {
        case .friendsMain:
            FriendsView()
            
        case .conversation(let conversationId):
            if let conversation = viewModel.getConversation(by: conversationId) {
                ConversationView(conversation: conversation, viewModel: viewModel)
            } else {
                // Show loading or error state while fetching conversation
                ConversationLoadingView(conversationId: conversationId, viewModel: viewModel)
            }
            
        case .call(let conversationId, let type):
            if let conversation = viewModel.getConversation(by: conversationId) {
                CallView(conversation: conversation, viewModel: viewModel)
            } else {
                ConversationLoadingView(conversationId: conversationId, viewModel: viewModel) {
                    // Start call once conversation loads
                }
            }
            
        case .invite(let code):
            InviteAcceptView(inviteCode: code, viewModel: viewModel)
            
        case .userProfile(let userId):
            if let friend = viewModel.getFriend(by: userId) {
                FriendProfileView(friend: friend, viewModel: viewModel)
            } else {
                UserProfileLoadingView(userId: userId, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Loading Views

struct ConversationLoadingView: View {
    let conversationId: String
    @ObservedObject var viewModel: FriendsViewModel
    let onLoad: (() -> Void)?
    
    init(conversationId: String, viewModel: FriendsViewModel, onLoad: (() -> Void)? = nil) {
        self.conversationId = conversationId
        self.viewModel = viewModel
        self.onLoad = onLoad
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading conversation...")
                .font(.headline)
            
            Text("Please wait while we fetch your conversation")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .onAppear {
            // TODO: Fetch conversation by ID if not in current list
            // For now, we'll wait for real-time updates to populate it
            
            // Call onLoad after a brief delay to allow for data loading
            if let onLoad = onLoad {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    onLoad()
                }
            }
        }
    }
}

struct UserProfileLoadingView: View {
    let userId: String
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading profile...")
                .font(.headline)
            
            Text("Please wait while we fetch the user profile")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .onAppear {
            // TODO: Fetch user profile by ID
        }
    }
}

struct InviteAcceptView: View {
    let inviteCode: String
    @ObservedObject var viewModel: FriendsViewModel
    @State private var inviteInfo: InviteInfo?
    @State private var isLoading = true
    @State private var error: String?
    @State private var isAccepting = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading invite...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text("Invalid Invite")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if let invite = inviteInfo {
                    VStack(spacing: 24) {
                        // Invite header
                        VStack(spacing: 12) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Friend Invitation")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("You've been invited to connect!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Invite details
                        VStack(spacing: 8) {
                            Text("Invite Code: \(invite.code)")
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                            
                            if let context = invite.context {
                                Text("From: \(context.source)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Uses: \(invite.usageCount)/\(invite.maxUses)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Accept button
                        Button("Accept Invitation") {
                            acceptInvite()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(isAccepting)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadInvite()
        }
    }
    
    private func loadInvite() async {
        do {
            inviteInfo = try await viewModel.resolveInviteLink(inviteCode)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    private func acceptInvite() {
        isAccepting = true
        
        Task {
            do {
                try await viewModel.acceptInvite(inviteCode)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isAccepting = false
                }
            }
        }
    }
}

// MARK: - Deep Link URL Builders

public struct FriendsDeepLinkBuilder {
    public static func conversationURL(id: String) -> URL? {
        URL(string: "liive://friends/convo/\(id)")
    }
    
    public static func inviteURL(code: String) -> URL? {
        URL(string: "liive://friends/invite/\(code)")
    }
    
    public static func voiceCallURL(conversationId: String) -> URL? {
        URL(string: "liive://friends/call/\(conversationId)?type=voice")
    }
    
    public static func videoCallURL(conversationId: String) -> URL? {
        URL(string: "liive://friends/call/\(conversationId)?type=video")
    }
    
    public static func userProfileURL(userId: String) -> URL? {
        URL(string: "liive://friends/user/\(userId)")
    }
    
    public static func friendsMainURL() -> URL? {
        URL(string: "liive://friends/")
    }
}

#if DEBUG
struct InviteAcceptView_Previews: PreviewProvider {
    static var previews: some View {
        InviteAcceptView(inviteCode: "ABC123", viewModel: FriendsViewModel())
    }
}
#endif