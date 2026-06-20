import SwiftUI
import MarketplaceService

/// Chat conversation view with anti-fraud features
/// Per Section 11 of implementation-plan.md
public struct ConversationView: View {
    let conversation: Conversation
    @ObservedObject var viewModel: MarketplaceViewModel
    
    @State private var messages: [Message] = []
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var showingOfferSheet = false
    @State private var showingReservationSheet = false
    @State private var isLoadingMessages = true
    @State private var selectedImage: UIImage?
    
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with listing info
            ConversationHeaderView(conversation: conversation)
            
            Divider()
            
            // Messages list
            SwiftUI.ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if isLoadingMessages {
                            ProgressView("Loading messages...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if messages.isEmpty {
                            EmptyConversationView()
                        } else {
                            ForEach(messages) { message in
                                MessageBubbleView(
                                    message: message,
                                    isFromCurrentUser: isFromCurrentUser(message)
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onAppear {
                    loadMessages()
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            Divider()
            
            // Message input
            MessageInputView(
                messageText: $messageText,
                selectedImage: $selectedImage,
                showingImagePicker: $showingImagePicker,
                onSend: sendMessage,
                onImageTap: { showingImagePicker = true }
            )
            
            // Quick actions
            QuickActionsView(
                onMakeOffer: { showingOfferSheet = true },
                onScheduleMeetup: { showingReservationSheet = true }
            )
        }
        .navigationTitle("Message")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingOfferSheet) {
            // Would show offer sheet for the listing
            Text("Make Offer Sheet - Listing \(conversation.listingId)")
        }
        .sheet(isPresented: $showingReservationSheet) {
            // Would show reservation sheet
            Text("Schedule Meet-up - Listing \(conversation.listingId)")
        }
    }
    
    private func isFromCurrentUser(_ message: Message) -> Bool {
        // Would check against actual current user ID
        return message.senderId == "current_user_id"
    }
    
    private func loadMessages() {
        // Simulate loading messages
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            messages = [
                Message(
                    id: "1",
                    conversationId: conversation.id ?? "",
                    senderId: "other_user",
                    type: .text,
                    content: "Hi! Is this item still available?",
                    createdAt: Date().addingTimeInterval(-3600)
                ),
                Message(
                    id: "2",
                    conversationId: conversation.id ?? "",
                    senderId: "current_user_id",
                    type: .text,
                    content: "Yes, it's still available! Are you interested?",
                    createdAt: Date().addingTimeInterval(-3500)
                ),
                Message(
                    id: "3",
                    conversationId: conversation.id ?? "",
                    senderId: "other_user",
                    type: .text,
                    content: "Great! What's the condition like? Any scratches or damage?",
                    createdAt: Date().addingTimeInterval(-3400)
                )
            ]
            isLoadingMessages = false
        })
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newMessage = Message(
            id: UUID().uuidString,
            conversationId: conversation.id ?? "",
            senderId: "current_user_id",
            type: (selectedImage != nil ? Message.MessageType.image : Message.MessageType.text),
            content: messageText,
            createdAt: Date()
        )
        
        messages.append(newMessage)
        
        Task {
            do {
                try await viewModel.sendMessage(
                    conversationId: conversation.id ?? "",
                    text: messageText
                )
            } catch {
                // Handle error
            }
        }
        
        messageText = ""
        selectedImage = nil
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Header View

struct ConversationHeaderView: View {
    let conversation: Conversation
    @State private var listing: Listing?
    
    var body: some View {
        HStack(spacing: 12) {
            // Listing thumbnail
            if let listing = listing {
                AsyncImage(url: URL(string: listing.thumbnails.first ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.2))
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(listing.price.displayAmount)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(listing.location.arrondissement ?? "")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading) {
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            VStack(alignment: .trailing, spacing: 2) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text("Online")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            // Simulate loading listing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Would load actual listing
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message content
                Group {
                    switch message.type {
                    case .text:
                        Text(message.content)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(isFromCurrentUser ? Color.blue : Color(.systemGray6))
                            )
                            .foregroundColor(isFromCurrentUser ? .white : .primary)
                    
                    case .image:
                        VStack(alignment: .leading, spacing: 8) {
                            // Image placeholder
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 200, height: 150)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                            
                            if !message.content.isEmpty {
                                Text(message.content)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(isFromCurrentUser ? Color.blue : Color(.systemGray6))
                                    )
                                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                            }
                        }
                    
                    case .system:
                        Text(message.content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                            )
                    }
                }
                
                // Timestamp
                if message.type != .system {
                    Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 280, alignment: isFromCurrentUser ? .trailing : .leading)
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
    }
}

// MARK: - Message Input

struct MessageInputView: View {
    @Binding var messageText: String
    @Binding var selectedImage: UIImage?
    @Binding var showingImagePicker: Bool
    let onSend: () -> Void
    let onImageTap: () -> Void
    
    @State private var isValidMessage = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Selected image preview
            if let image = selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 60)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Button("Remove") {
                        selectedImage = nil
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding(.horizontal)
            }
            
            // Input row
            HStack(spacing: 12) {
                // Image button
                Button(action: onImageTap) {
                    Image(systemName: "camera")
                        .foregroundColor(.blue)
                }
                
                // Text input
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                    .onChange(of: messageText) { _ in
                        validateMessage()
                    }
                
                // Send button
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(isValidMessage ? .blue : .gray)
                        .font(.title2)
                }
                .disabled(!isValidMessage)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .onAppear {
            validateMessage()
        }
    }
    
    private func validateMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !trimmed.isEmpty
        let hasImage = selectedImage != nil
        let containsForbidden = checkForForbiddenContent(trimmed)
        
        isValidMessage = (hasText || hasImage) && !containsForbidden
    }
    
    private func checkForForbiddenContent(_ text: String) -> Bool {
        // Anti-fraud filters per implementation plan
        let forbiddenPatterns = [
            "whatsapp",
            "telegram",
            "paypal",
            "western union",
            "money gram",
            "bitcoin",
            "crypto",
            "send money",
            "transfer money"
        ]
        
        let lowercased = text.lowercased()
        return forbiddenPatterns.contains { lowercased.contains($0) }
    }
}

// MARK: - Quick Actions

struct QuickActionsView: View {
    let onMakeOffer: () -> Void
    let onScheduleMeetup: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onMakeOffer) {
                Label("Make Offer", systemImage: "tag")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            Button(action: onScheduleMeetup) {
                Label("Schedule Meet-up", systemImage: "calendar")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Empty State

struct EmptyConversationView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            Text("Start the conversation")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Send a message to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 100)
    }
}

// MARK: - Safety Guidelines

struct ConversationSafetyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Safety Guidelines", systemImage: "shield.checkered")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                SafetyGuideline(
                    icon: "exclamationmark.triangle",
                    text: "Never share personal financial information"
                )
                SafetyGuideline(
                    icon: "location.slash",
                    text: "Don't share your exact address until meeting"
                )
                SafetyGuideline(
                    icon: "phone.badge.plus",
                    text: "Use the in-app messaging for communications"
                )
                SafetyGuideline(
                    icon: "eye",
                    text: "Meet in public places during daylight"
                )
                SafetyGuideline(
                    icon: "flag",
                    text: "Report suspicious behavior immediately"
                )
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SafetyGuideline: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}