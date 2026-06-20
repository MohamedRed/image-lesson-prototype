import SwiftUI
import FriendsService
import LiveKitCore
import Combine

struct CallView: View {
    let conversation: Conversation
    @ObservedObject var viewModel: FriendsViewModel
    @StateObject private var callViewModel: CallViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(conversation: Conversation, viewModel: FriendsViewModel) {
        self.conversation = conversation
        self.viewModel = viewModel
        self._callViewModel = StateObject(wrappedValue: CallViewModel(
            conversationId: conversation.id,
            friendsService: viewModel.friendsService
        ))
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack {
                // Header
                VStack(spacing: 8) {
                    Text(conversationTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(callStatusText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if callViewModel.callDuration > 0 {
                        Text(formatDuration(callViewModel.callDuration))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Participant Views
                participantViews
                
                Spacer()
                
                // Controls
                callControls
                    .padding(.bottom, 60)
            }
            
            // Incoming call overlay
            if callViewModel.incomingCall != nil && !callViewModel.isConnected {
                incomingCallOverlay
            }
        }
        .onAppear {
            callViewModel.startCall()
        }
        .onDisappear {
            callViewModel.endCall()
        }
    }
    
    private var conversationTitle: String {
        if let title = conversation.title {
            return title
        } else if conversation.type == .direct {
            let otherParticipantId = conversation.participants.first { $0 != viewModel.friendsService.currentUserId }
            if let otherParticipantId = otherParticipantId,
               let friend = viewModel.getFriend(by: otherParticipantId) {
                return friend.displayName
            }
            return "Direct Call"
        } else {
            return "Group Call"
        }
    }
    
    private var callStatusText: String {
        switch callViewModel.callState {
        case .idle: return "Preparing call..."
        case .connecting: return "Connecting..."
        case .ringing: return "Ringing..."
        case .connected: return "Connected"
        case .ended: return "Call ended"
        case .failed: return "Connection failed"
        }
    }
    
    @ViewBuilder
    private var participantViews: some View {
        if callViewModel.isVideoEnabled {
            // Video grid layout
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(callViewModel.participants) { participant in
                    ParticipantVideoView(participant: participant)
                        .aspectRatio(4/3, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        } else {
            // Audio-only layout with avatars
            LazyVGrid(columns: audioGridColumns, spacing: 20) {
                ForEach(callViewModel.participants) { participant in
                    ParticipantAudioView(participant: participant, viewModel: viewModel)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var gridColumns: [GridItem] {
        let count = callViewModel.participants.count
        if count <= 2 {
            return [GridItem(.flexible())]
        } else if count <= 4 {
            return Array(repeating: GridItem(.flexible()), count: 2)
        } else {
            return Array(repeating: GridItem(.flexible()), count: 3)
        }
    }
    
    private var audioGridColumns: [GridItem] {
        let count = callViewModel.participants.count
        if count <= 2 {
            return [GridItem(.flexible())]
        } else if count <= 4 {
            return Array(repeating: GridItem(.flexible()), count: 2)
        } else {
            return Array(repeating: GridItem(.flexible()), count: 3)
        }
    }
    
    @ViewBuilder
    private var callControls: some View {
        HStack(spacing: 30) {
            // Mute button
            Button(action: { callViewModel.toggleMute() }) {
                Image(systemName: callViewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(callViewModel.isMuted ? Color.red : Color.white.opacity(0.3))
                    )
            }
            
            // Video button
            Button(action: { callViewModel.toggleVideo() }) {
                Image(systemName: callViewModel.isVideoEnabled ? "video.fill" : "video.slash.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(callViewModel.isVideoEnabled ? Color.white.opacity(0.3) : Color.red)
                    )
            }
            
            // End call button
            Button(action: { 
                callViewModel.endCall()
                dismiss()
            }) {
                Image(systemName: "phone.down.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(Color.red)
                    )
            }
            
            // Speaker button
            Button(action: { callViewModel.toggleSpeaker() }) {
                Image(systemName: callViewModel.isSpeakerEnabled ? "speaker.wave.3.fill" : "speaker.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(callViewModel.isSpeakerEnabled ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                    )
            }
        }
    }
    
    @ViewBuilder
    private var incomingCallOverlay: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Incoming Call")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(conversationTitle)
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            HStack(spacing: 60) {
                // Decline button
                Button(action: {
                    callViewModel.declineCall()
                    dismiss()
                }) {
                    Image(systemName: "phone.down.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(
                            Circle()
                                .fill(Color.red)
                        )
                }
                
                // Accept button
                Button(action: {
                    callViewModel.acceptCall()
                }) {
                    Image(systemName: "phone.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(
                            Circle()
                                .fill(Color.green)
                        )
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Participant Views

struct ParticipantVideoView: View {
    let participant: CallParticipant
    
    var body: some View {
        ZStack {
            // Video view (would be LiveKit VideoView in real implementation)
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    VStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Video Feed")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                )
            
            // Participant info overlay
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(participant.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                            )
                        
                        if participant.isMuted {
                            HStack(spacing: 4) {
                                Image(systemName: "mic.slash.fill")
                                    .font(.caption2)
                                Text("Muted")
                                    .font(.caption2)
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                            )
                        }
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
    }
}

struct ParticipantAudioView: View {
    let participant: CallParticipant
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Avatar with audio visualizer
                AsyncImage(url: URL(string: participant.photoURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(participant.isSpeaking ? Color.green : Color.clear, lineWidth: 3)
                        .scaleEffect(participant.isSpeaking ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: participant.isSpeaking)
                )
            }
            
            Text(participant.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            if participant.isMuted {
                Image(systemName: "mic.slash.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Call ViewModel

@MainActor
class CallViewModel: ObservableObject {
    @Published var callState: CallState = .idle
    @Published var participants: [CallParticipant] = []
    @Published var isMuted = false
    @Published var isVideoEnabled = false
    @Published var isSpeakerEnabled = false
    @Published var isConnected = false
    @Published var callDuration = 0
    @Published var incomingCall: IncomingCall?
    
    private let conversationId: String
    private let friendsService: FriendsServicing
    private var callTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    enum CallState {
        case idle
        case connecting
        case ringing
        case connected
        case ended
        case failed
    }
    
    init(conversationId: String, friendsService: FriendsServicing) {
        self.conversationId = conversationId
        self.friendsService = friendsService
        setupMockData()
    }
    
    func startCall() {
        callState = .connecting
        
        // Simulate connection process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.callState = .ringing
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.callState = .connected
                self.isConnected = true
                self.startCallTimer()
            }
        }
        
        // TODO: Integrate with real LiveKit service
        // Task {
        //     try await friendsService.joinRoom(conversationId: conversationId)
        // }
    }
    
    func endCall() {
        callState = .ended
        stopCallTimer()
        
        // TODO: Integrate with real LiveKit service
        // Task {
        //     await friendsService.leaveRoom()
        // }
    }
    
    func acceptCall() {
        guard let _ = incomingCall else { return }
        incomingCall = nil
        startCall()
    }
    
    func declineCall() {
        incomingCall = nil
        endCall()
    }
    
    func toggleMute() {
        isMuted.toggle()
        
        // TODO: Integrate with real LiveKit service
        // Task {
        //     await friendsService.toggleMicrophone()
        // }
    }
    
    func toggleVideo() {
        isVideoEnabled.toggle()
        
        // TODO: Integrate with real LiveKit service
        // Task {
        //     await friendsService.toggleCamera()
        // }
    }
    
    func toggleSpeaker() {
        isSpeakerEnabled.toggle()
        
        // TODO: Configure audio session
    }
    
    private func startCallTimer() {
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.callDuration += 1
        }
    }
    
    private func stopCallTimer() {
        callTimer?.invalidate()
        callTimer = nil
    }
    
    private func setupMockData() {
        // Mock participants for demo
        participants = [
            CallParticipant(
                id: "current_user",
                displayName: "You",
                photoURL: nil,
                isMuted: false,
                isVideoEnabled: false,
                isSpeaking: false
            ),
            CallParticipant(
                id: "friend_1",
                displayName: "Alex",
                photoURL: nil,
                isMuted: false,
                isVideoEnabled: false,
                isSpeaking: true
            )
        ]
        
        // Simulate incoming call for demo
        if Bool.random() {
            incomingCall = IncomingCall(
                id: conversationId,
                callerName: "Alex",
                isVideo: false
            )
        }
        
        // Simulate speaking animation
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if let randomParticipant = self.participants.randomElement() {
                for i in 0..<self.participants.count {
                    self.participants[i].isSpeaking = self.participants[i].id == randomParticipant.id
                }
            }
        }
    }
}

// MARK: - Data Models

struct CallParticipant: Identifiable {
    let id: String
    let displayName: String
    let photoURL: String?
    var isMuted: Bool
    var isVideoEnabled: Bool
    var isSpeaking: Bool
}

struct IncomingCall {
    let id: String
    let callerName: String
    let isVideo: Bool
}

#if DEBUG
struct CallView_Previews: PreviewProvider {
    static var previews: some View {
        let mockConversation = Conversation(
            id: "123",
            type: .direct,
            participants: ["user1", "user2"],
            admins: [],
            title: "Alex",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        CallView(conversation: mockConversation, viewModel: FriendsViewModel())
    }
}
#endif