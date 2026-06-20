import SwiftUI
import FriendsService
import UIKit

struct MatchedContactRowView: View {
    let matchedUser: MatchedContact
    @ObservedObject var viewModel: FriendsViewModel
    @State private var isLoading = false
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: matchedUser.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(matchedUser.displayName)
                    .font(.headline)
                
                if let status = matchedUser.friendshipStatus {
                    Text(status.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else if matchedUser.friendshipStatus == nil {
                Button("Add") {
                    sendFriendRequest()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Image(systemName: friendshipIcon)
                    .foregroundColor(friendshipColor)
            }
        }
    }
    
    private var friendshipIcon: String {
        switch matchedUser.friendshipStatus {
        case .accepted: return "checkmark.circle.fill"
        case .pending: return "clock.circle.fill"
        case .declined: return "xmark.circle.fill"
        default: return "plus.circle"
        }
    }
    
    private var friendshipColor: Color {
        switch matchedUser.friendshipStatus {
        case .accepted: return .green
        case .pending: return .orange
        case .declined: return .red
        default: return .blue
        }
    }
    
    private func sendFriendRequest() {
        isLoading = true
        Task {
            try? await viewModel.sendFriendRequest(to: matchedUser.id)
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct InviteView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var inviteInfo: InviteInfo?
    @State private var isGenerating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "link.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Invite Friends")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let inviteInfo = inviteInfo {
                VStack(spacing: 12) {
                    Text("Share this link with friends:")
                        .font(.headline)
                    
                    Text(inviteInfo.url)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            UIPasteboard.general.string = inviteInfo.url
                        }
                    
                    Button("Share Link") {
                        shareInvite()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            } else {
                Button("Generate Invite Link") {
                    generateInvite()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Invite Friends")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func generateInvite() {
        isGenerating = true
        Task {
            do {
                inviteInfo = try await viewModel.generateInviteLink()
                await MainActor.run {
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }
    
    private func shareInvite() {
        guard let inviteInfo = inviteInfo else { return }
        
        let activityController = UIActivityViewController(
            activityItems: [inviteInfo.url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityController, animated: true)
        }
    }
}

struct WatchPartyView: View {
    let conversation: Conversation
    @ObservedObject var viewModel: FriendsViewModel
    @State private var isCreating = false
    @State private var mediaURL = ""
    @State private var title = ""
    @State private var showingActiveParty = false
    @State private var activeWatchPartyId: String?
    @State private var activeRoomName: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if showingActiveParty, let partyId = activeWatchPartyId, let roomName = activeRoomName {
                    // Inline active party inside the same sheet
                    WatchPartyActiveView(
                        conversation: conversation,
                        watchPartyId: partyId,
                        roomName: roomName,
                        viewModel: viewModel
                    )
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("Watch Party")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            TextField("Media URL (optional)", text: $mediaURL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Title (optional)", text: $title)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Start Watch Party") {
                                createWatchParty()
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .disabled(isCreating)
                            
                            // Demo: Show active watch party
                            Button("Join Demo Watch Party") {
                                activeWatchPartyId = "demo_party"
                                activeRoomName = "demo_room"
                                showingActiveParty = true
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Watch Party")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Prevent swipe-to-dismiss during creation or while party is active
            .interactiveDismissDisabled(isCreating || showingActiveParty)
        }
    }
    
    private func createWatchParty() {
        isCreating = true
        
        Task {
            do {
                let mediaURLToSend = mediaURL.isEmpty ? nil : mediaURL
                let titleToSend = title.isEmpty ? nil : title
                
                let (roomName, watchPartyId) = try await viewModel.createWatchParty(
                    in: conversation.id,
                    mediaURL: mediaURLToSend,
                    title: titleToSend
                )
                
                await MainActor.run {
                    // Instead of dismissing, show the active watch party
                    activeWatchPartyId = watchPartyId
                    activeRoomName = roomName
                    showingActiveParty = true
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }
}