import SwiftUI

/// A view that displays a transcript of the conversation between the user and the agent.
struct ChatView: View {
    let messages: [ChatMessage]
    var onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    ForEach(messages) { message in
                        ChatMessageView(message: message)
                    }
                }
                .padding()
            }
            .navigationTitle("Transcript")
        }
    }
}

#if DEBUG
#Preview {
    struct PreviewWrapper: View {
        let messages: [ChatMessage] = [
            ChatMessage(role: .agent, text: "Hello! Welcome to your lesson. Let's talk about the image you see."),
            ChatMessage(role: .user, text: "Okay, sounds good. I see a picture of a landscape."),
            ChatMessage(role: .agent, text: "Great observation! Can you describe the colors you see in the sky?"),
            ChatMessage(role: .user, text: "The sky is a mix of orange and pink, it looks like a sunset."),
            ChatMessage(role: .agent, text: "That's a perfect description. Well done!")
        ]
        
        var body: some View {
            ChatView(messages: messages, onDismiss: {})
        }
    }
    
    return PreviewWrapper()
}
#endif 