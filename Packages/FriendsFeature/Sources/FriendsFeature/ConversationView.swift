import SwiftUI
import FriendsService
import Combine

struct ConversationView: View {
    let conversation: Conversation
    @ObservedObject var viewModel: FriendsViewModel
    let onStartWatchParty: (Conversation) -> Void
    @StateObject private var messagesViewModel: MessagesViewModel
    @State private var messageText = ""
    @State private var showingActionSheet = false
    @State private var showingWatchParty = false
    @State private var showingCall = false
    @FocusState private var isMessageFieldFocused: Bool
    
    init(conversation: Conversation, viewModel: FriendsViewModel, onStartWatchParty: @escaping (Conversation) -> Void = { _ in }) {
        self.conversation = conversation
        self.viewModel = viewModel
        self.onStartWatchParty = onStartWatchParty
        self._messagesViewModel = StateObject(wrappedValue: MessagesViewModel(
            conversationId: conversation.id,
            friendsService: viewModel.friendsService
        ))
    }
    
    var body: some View {
        VStack {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messagesViewModel.messages.reversed()) { message in
                            MessageRowView(
                                message: message,
                                isFromCurrentUser: message.senderId == viewModel.friendsService.currentUserId,
                                viewModel: viewModel
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messagesViewModel.messages.count) { _ in
                    if let lastMessage = messagesViewModel.messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Typing indicators
            if !messagesViewModel.typingUsers.isEmpty {
                TypingIndicatorView(userIds: messagesViewModel.typingUsers, viewModel: viewModel)
                    .padding(.horizontal)
            }
            
            // Message input
            MessageInputView(
                text: $messageText,
                isTyping: $messagesViewModel.isTyping,
                onSend: sendMessage,
                onShowActions: { showingActionSheet = true }
            )
            .focused($isMessageFieldFocused)
        }
        .navigationTitle(conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    // Voice call button
                    Button(action: { showingCall = true }) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.green)
                    }
                    
                    // Video call button
                    Button(action: { 
                        showingCall = true 
                    }) {
                        Image(systemName: "video.fill")
                            .foregroundColor(.blue)
                    }
                    
                    // More menu
                    Menu {
                        if conversation.type != .direct {
                            Button("Group Info") {
                                // TODO: Show group info
                            }
                        }
                        
                        Button("Start Watch Party") { onStartWatchParty(conversation) }
                        
                        Button("Share Location") {
                            shareLocation()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            markAsRead()
        }
        .onDisappear {
            Task {
                try? await viewModel.setTyping(in: conversation.id, isTyping: false)
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Send"),
                buttons: [
                    .default(Text("Photo")) { selectPhoto() },
                    .default(Text("Location")) { shareLocation() },
                    .default(Text("Action Card")) { sendActionCard() },
                    .cancel()
                ]
            )
        }
        // Watch party sheet now anchored at FriendsView root via onStartWatchParty
        .fullScreenCover(isPresented: $showingCall) {
            CallView(conversation: conversation, viewModel: viewModel)
        }
    }
    
    private var conversationTitle: String {
        if let title = conversation.title {
            return title
        } else if conversation.type == .direct {
            // Find the other participant for direct messages
            let otherParticipantId = conversation.participants.first { $0 != viewModel.friendsService.currentUserId }
            if let otherParticipantId = otherParticipantId,
               let friend = viewModel.getFriend(by: otherParticipantId) {
                return friend.displayName
            }
            return "Direct Message"
        } else {
            return "Group Chat"
        }
    }
    
    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        messageText = ""
        isMessageFieldFocused = true
        
        Task {
            try? await viewModel.sendMessage(to: conversation.id, content: content)
        }
    }
    
    private func selectPhoto() {
        // TODO: Implement photo picker
    }
    
    private func shareLocation() {
        // TODO: Implement location sharing
    }
    
    private func sendActionCard() {
        let actionCard = ActionCardPayload(
            kind: "ride_sharing",
            refId: UUID().uuidString,
            meta: [
                "type": AnyCodable("request"),
                "pickup": AnyCodable("Current Location"),
                "destination": AnyCodable("Airport")
            ]
        )
        
        Task {
            try? await viewModel.sendActionCard(
                to: conversation.id,
                content: "Want to share a ride to the airport?",
                actionCard: actionCard
            )
        }
    }
    
    private func markAsRead() {
        Task {
            try? await viewModel.friendsService.markAsRead(conversation.id)
        }
    }
}

// MARK: - Message Row View

struct MessageRowView: View {
    let message: Message
    let isFromCurrentUser: Bool
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
                messageContent
            } else {
                messageContent
                Spacer(minLength: 50)
            }
        }
    }
    
    @ViewBuilder
    private var messageContent: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            // Sender name (only for group chats and not current user)
            if !isFromCurrentUser && message.senderId != "system" {
                if let friend = viewModel.getFriend(by: message.senderId) {
                    Text(friend.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                }
            }
            
            // Message bubble
            Group {
                switch message.type {
                case .text:
                    textMessage
                case .image:
                    imageMessage
                case .action:
                    actionCardMessage
                case .system:
                    systemMessage
                case .voice, .location:
                    textMessage // TODO: Implement specific views
                }
            }
            
            // Message metadata
            HStack(spacing: 4) {
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if message.editedAt != nil {
                    Text("edited")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding(.horizontal, 12)
        }
    }
    
    private var textMessage: some View {
        Text(message.content)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isFromCurrentUser ? Color.blue : Color(.systemGray5))
            )
            .foregroundColor(isFromCurrentUser ? .white : .primary)
    }
    
    private var imageMessage: some View {
        AsyncImage(url: URL(string: message.content)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            ProgressView()
        }
        .frame(maxWidth: 200, maxHeight: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var actionCardMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !message.content.isEmpty {
                Text(message.content)
                    .font(.subheadline)
                    .padding(.bottom, 4)
            }
            
            if let action = message.action {
                ActionCardRenderer(actionCard: action, viewModel: viewModel) { cardAction in
                    handleActionCardTap(cardAction)
                }
            }
        }
    }
    
    private func handleActionCardTap(_ action: ActionCardAction) {
        switch action {
        case .openFeature(let featureId, let referenceId, let metadata):
            // TODO: Navigate to specific feature with context
            print("Opening feature: \(featureId) with ref: \(referenceId ?? "none")")
            
        case .joinSession(let sessionId):
            // TODO: Join LiveKit session or watch party
            print("Joining session: \(sessionId)")
            
        case .acceptInvite(let inviteId):
            // TODO: Accept invite to event or activity
            print("Accepting invite: \(inviteId)")
            
        case .viewDetails(let itemId):
            // TODO: Show details view for item
            print("Viewing details for: \(itemId)")
            
        case .shareLocation:
            // TODO: Open maps or location sharing
            print("Sharing location")
            
        case .custom(let actionType, let data):
            // TODO: Handle custom actions
            print("Custom action: \(actionType) with data: \(data)")
        }
    }
    
    private var systemMessage: some View {
        Text(message.content)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
    }
}

// MARK: - Message Input View

struct MessageInputView: View {
    @Binding var text: String
    @Binding var isTyping: Bool
    let onSend: () -> Void
    let onShowActions: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onShowActions) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            TextField("Message", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit(onSend)
                .onChange(of: text) { newValue in
                    // Handle typing indicator
                    let wasEmpty = text.isEmpty
                    let isEmpty = newValue.isEmpty
                    
                    if wasEmpty && !isEmpty {
                        isTyping = true
                    } else if !wasEmpty && isEmpty {
                        isTyping = false
                    }
                }
            
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: {}) {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    let userIds: [String]
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        HStack {
            if userIds.count == 1 {
                Text("\(getUserName(userIds[0])) is typing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if userIds.count > 1 {
                Text("\(userIds.count) people are typing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            TypingAnimation()
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private func getUserName(_ userId: String) -> String {
        viewModel.getFriend(by: userId)?.displayName ?? "Someone"
    }
}

struct TypingAnimation: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 4, height: 4)
                    .scaleEffect(animating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}


#if DEBUG
struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        let mockConversation = Conversation(
            id: "123",
            type: .direct,
            participants: ["user1", "user2"],
            admins: [],
            title: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        NavigationView {
            ConversationView(conversation: mockConversation, viewModel: FriendsViewModel())
        }
    }
}
#endif