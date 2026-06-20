import SwiftUI
import EventsService

struct AIAssistantView: View {
    @ObservedObject var viewModel: EventsViewModel
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if viewModel.aiMessages.isEmpty {
                            WelcomeView()
                        } else {
                            ForEach(viewModel.aiMessages) { message in
                                AIMessageView(message: message) { event in
                                    viewModel.selectEvent(event)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.aiMessages.count) { _ in
                    if let lastMessage = viewModel.aiMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input
            HStack(spacing: 12) {
                TextField("Ask about events...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .lineLimit(1...4)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? .secondary : .accentColor)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .navigationTitle("AI Assistant")
    }
    
    private func sendMessage() {
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        messageText = ""
        isTextFieldFocused = false
        
        Task {
            await viewModel.sendAIMessage(message)
        }
    }
}

struct WelcomeView: View {
    let suggestions = [
        "Find jazz events this weekend",
        "Show me family-friendly activities",
        "What concerts are happening in Casablanca?",
        "Find indoor events under 200 MAD"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title)
                        .foregroundColor(.purple)
                    
                    Text("AI Event Assistant")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Text("I can help you discover events, plan outings, and answer questions about what's happening around you.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Try asking:")
                    .font(.headline)
                
                ForEach(suggestions, id: \.self) { suggestion in
                    Text("• \(suggestion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 50)
    }
}

struct AIMessageView: View {
    let message: AIMessage
    let onEventTap: (Event) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !message.isUser {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                Text(message.content)
                    .font(.body)
                    .padding(12)
                    .background(
                        message.isUser
                            ? Color.accentColor
                            : Color(.systemGray6)
                    )
                    .foregroundColor(
                        message.isUser ? .white : .primary
                    )
                    .cornerRadius(16)
                
                // Suggested Events
                if let events = message.suggestedEvents, !events.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggested Events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        ForEach(events.prefix(3)) { event in
                            Button {
                                onEventTap(event)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Text(event.venueName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if let minPrice = event.priceTiers.map(\.priceMAD).min() {
                                        Text("\(Int(minPrice)) MAD")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.05), radius: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.isUser {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

#if DEBUG
#Preview {
    AIAssistantView(viewModel: EventsViewModel())
}
#endif