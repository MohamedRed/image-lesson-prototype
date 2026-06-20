import SwiftUI
import FriendsService
import AVKit

// MARK: - Active Watch Party View
struct WatchPartyActiveView: View {
    let conversation: Conversation
    let watchPartyId: String
    let roomName: String
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 100
    @State private var volume: Float = 1.0
    @State private var showControls = true
    @State private var participants: [WatchPartyParticipant] = []
    @State private var messages: [WatchPartyMessage] = []
    @State private var messageText = ""
    @State private var showChat = true
    
    init(conversation: Conversation, watchPartyId: String, roomName: String, viewModel: FriendsViewModel) {
        self.conversation = conversation
        self.watchPartyId = watchPartyId
        self.roomName = roomName
        self.viewModel = viewModel
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Video player area
                    ZStack {
                        // Video placeholder
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .overlay(
                                VStack {
                                    Image(systemName: "play.tv.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white.opacity(0.5))
                                    Text("Morocco vs Portugal")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    Text("World Cup Highlights")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            )
                        
                        // Overlay controls
                        if showControls {
                            VStack {
                                // Top bar
                                HStack {
                                    Button(action: { dismiss() }) {
                                        Image(systemName: "xmark")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.5))
                                            .clipShape(Circle())
                                    }
                                    
                                    Spacer()
                                    
                                    // Participants
                                    HStack(spacing: -8) {
                                        ForEach(0..<min(3, participants.count), id: \.self) { index in
                                            participantAvatar(at: index)
                                        }
                                        if participants.count > 3 {
                                            Text("+\(participants.count - 3)")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.black.opacity(0.5))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Chat toggle
                                    Button(action: { showChat.toggle() }) {
                                        Image(systemName: showChat ? "message.fill" : "message")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.5))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding()
                                
                                Spacer()
                                
                                // Bottom controls
                                VStack(spacing: 12) {
                                    // Progress bar
                                    HStack {
                                        Text(formatTime(currentTime))
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        
                                        Slider(value: $currentTime, in: 0...duration)
                                            .accentColor(.white)
                                        
                                        Text(formatTime(duration))
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    
                                    // Playback controls
                                    HStack(spacing: 30) {
                                        Button(action: skipBackward) {
                                            Image(systemName: "gobackward.10")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                        }
                                        
                                        Button(action: togglePlayback) {
                                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                                .font(.system(size: 50))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Button(action: skipForward) {
                                            Image(systemName: "goforward.10")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                        }
                                    }
                                    
                                    // Volume control
                                    HStack {
                                        Image(systemName: "speaker.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        
                                        Slider(value: $volume, in: 0...1)
                                            .frame(width: 100)
                                            .accentColor(.white)
                                        
                                        Image(systemName: "speaker.wave.3.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0), Color.black.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                        }
                    }
                    .frame(height: showChat ? geometry.size.height * 0.6 : geometry.size.height)
                    .onTapGesture {
                        withAnimation {
                            showControls.toggle()
                        }
                    }
                    
                    // Chat area
                    if showChat {
                        WatchPartyChatView(
                            messages: $messages,
                            messageText: $messageText,
                            onSend: sendMessage
                        )
                        .frame(height: geometry.size.height * 0.4)
                        .background(Color(.systemBackground))
                    }
                }
            }
        }
        .onAppear {
            loadMockData()
            simulatePlayback()
        }
    }
    
    private func participantAvatar(at index: Int) -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 32, height: 32)
            .overlay(
                Text(participants[index].name.prefix(1))
                    .font(.caption)
                    .foregroundColor(.white)
            )
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func togglePlayback() {
        isPlaying.toggle()
        Task {
            try? await viewModel.friendsService.updatePlayback(
                in: conversation.id,
                action: isPlaying ? "play" : "pause",
                positionMs: Int(currentTime * 1000)
            )
        }
    }
    
    private func skipBackward() {
        currentTime = max(0, currentTime - 10)
    }
    
    private func skipForward() {
        currentTime = min(duration, currentTime + 10)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let newMessage = WatchPartyMessage(
            id: UUID().uuidString,
            senderName: "You",
            content: messageText,
            timestamp: Date()
        )
        messages.append(newMessage)
        messageText = ""
    }
    
    private func loadMockData() {
        participants = [
            WatchPartyParticipant(id: "1", name: "Alex"),
            WatchPartyParticipant(id: "2", name: "Sam"),
            WatchPartyParticipant(id: "3", name: "Jordan"),
            WatchPartyParticipant(id: "4", name: "Maya"),
            WatchPartyParticipant(id: "5", name: "You")
        ]
        
        messages = [
            WatchPartyMessage(id: "1", senderName: "Alex", content: "This match is incredible!", timestamp: Date().addingTimeInterval(-300)),
            WatchPartyMessage(id: "2", senderName: "Sam", content: "That goal was amazing 🔥", timestamp: Date().addingTimeInterval(-240)),
            WatchPartyMessage(id: "3", senderName: "Jordan", content: "Can't believe that save!", timestamp: Date().addingTimeInterval(-180)),
            WatchPartyMessage(id: "4", senderName: "Maya", content: "This is so much fun watching together", timestamp: Date().addingTimeInterval(-120))
        ]
    }
    
    private func simulatePlayback() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isPlaying && currentTime < duration {
                currentTime += 1
            }
        }
    }
}

// MARK: - Watch Party Chat View
struct WatchPartyChatView: View {
    @Binding var messages: [WatchPartyMessage]
    @Binding var messageText: String
    let onSend: () -> Void
    
    var body: some View {
        VStack {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            HStack(alignment: .top, spacing: 8) {
                                Text(message.senderName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                
                                Text(message.content)
                                    .font(.caption)
                                
                                Spacer()
                                
                                Text(message.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .id(message.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            HStack {
                TextField("Say something...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
    }
}

// MARK: - Data Models
struct WatchPartyParticipant: Identifiable {
    let id: String
    let name: String
}

struct WatchPartyMessage: Identifiable {
    let id: String
    let senderName: String
    let content: String
    let timestamp: Date
}

#if DEBUG
struct WatchPartyActiveView_Previews: PreviewProvider {
    static var previews: some View {
        WatchPartyActiveView(
            conversation: Conversation(
                id: "conv1",
                type: .group,
                participants: ["user1", "user2"],
                admins: [],
                createdAt: Date(),
                updatedAt: Date()
            ),
            watchPartyId: "party1",
            roomName: "room1",
            viewModel: FriendsViewModel(friendsService: MockFriendsService())
        )
    }
}
#endif