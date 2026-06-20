import SwiftUI
import AITutorService

struct DialogueView: View {
    let dialogue: DialogueState
    @ObservedObject var viewModel: AITutorViewModel
    let onChoice: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var ragResponse: RAGResponse?
    @State private var isLoading = true
    @State private var availableChoices: [String] = []
    @State private var conversationHistory: [DialogueMessage] = []
    @State private var userInput = ""
    @State private var showingChoices = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Character header
                characterHeader
                
                // Conversation area
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(conversationHistory) { message in
                            MessageBubble(message: message)
                        }
                        
                        // Current response from NPC
                        if let response = ragResponse {
                            ResponseView(response: response)
                        }
                        
                        if isLoading {
                            SwiftUI.ProgressView("Thinking...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .padding()
                }
                
                // Input area
                inputArea
            }
        }
        .onAppear {
            startDialogue()
        }
    }
    
    private var characterHeader: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(characterColor)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: characterIcon)
                        .font(.title2)
                        .foregroundColor(.white)
                )
            
            Text(dialogue.character)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(getCharacterTitle())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var inputArea: some View {
        VStack(spacing: 12) {
            if showingChoices && !availableChoices.isEmpty {
                // Show contextual choices
                VStack(spacing: 8) {
                    Text("Choose your approach:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(availableChoices, id: \.self) { choice in
                        Button(action: {
                            makeChoice(choice)
                        }) {
                            HStack {
                                Text(choice)
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
            } else {
                // Free-form input
                HStack {
                    TextField("What would you like to say or ask?", text: $userInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            if !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                sendMessage()
                            }
                        }
                    
                    Button("Send") {
                        sendMessage()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding(.horizontal)
            }
            
            // Control buttons
            HStack {
                Button("Show Choices") {
                    showContextualChoices()
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                Spacer()
                
                Button("End Conversation") {
                    endDialogue()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
        .background(Color(.systemBackground))
    }
    
    private func startDialogue() {
        // Add initial character greeting
        let initialMessage = DialogueMessage(
            id: UUID().uuidString,
            speaker: dialogue.character,
            text: dialogue.prompt,
            isUser: false,
            timestamp: Date()
        )
        conversationHistory.append(initialMessage)
        
        // Get initial response from RAG
        queryNPC(with: dialogue.prompt)
    }
    
    private func sendMessage() {
        let message = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        // Add user message to history
        let userMessage = DialogueMessage(
            id: UUID().uuidString,
            speaker: "You",
            text: message,
            isUser: true,
            timestamp: Date()
        )
        conversationHistory.append(userMessage)
        
        // Clear input and query NPC
        userInput = ""
        queryNPC(with: message)
    }
    
    private func queryNPC(with prompt: String) {
        isLoading = true
        showingChoices = false
        ragResponse = nil
        
        Task {
            do {
                let response = try await viewModel.queryNPC(
                    npcId: dialogue.character.lowercased().replacingOccurrences(of: " ", with: "_"),
                    prompt: prompt,
                    context: dialogue.context
                )
                
                await MainActor.run {
                    self.ragResponse = response
                    self.isLoading = false
                    
                    // Add NPC response to conversation
                    let npcMessage = DialogueMessage(
                        id: UUID().uuidString,
                        speaker: dialogue.character,
                        text: response.response,
                        isUser: false,
                        timestamp: Date()
                    )
                    self.conversationHistory.append(npcMessage)
                }
            } catch {
                await MainActor.run {
                    self.ragResponse = RAGResponse(
                        response: "I apologize, but I'm having difficulty responding right now. Perhaps we could try again?",
                        citations: [],
                        confidence: 0.0,
                        contested: false
                    )
                    self.isLoading = false
                }
            }
        }
    }
    
    private func showContextualChoices() {
        showingChoices = true
        
        // Generate contextual choices based on character and scene
        switch dialogue.character {
        case "Patriarch Sophronius":
            availableChoices = [
                "I come in peace, seeking to discuss the protection of holy sites",
                "What assurances do you need for the safety of your people?",
                "How can we establish terms that respect both faiths?",
                "I wish to understand your concerns about our governance"
            ]
        case "Commander Khalid":
            availableChoices = [
                "What is the current military situation in the city?",
                "How should we proceed with securing the gates?",
                "What are your recommendations for maintaining order?",
                "Tell me about the defenses and strategic positions"
            ]
        default:
            availableChoices = [
                "Tell me more about this situation",
                "What would you advise in this matter?",
                "How do you see this affecting our goals?",
                "What are the key considerations here?"
            ]
        }
    }
    
    private func makeChoice(_ choice: String) {
        // Add choice to conversation
        let choiceMessage = DialogueMessage(
            id: UUID().uuidString,
            speaker: "You",
            text: choice,
            isUser: true,
            timestamp: Date()
        )
        conversationHistory.append(choiceMessage)
        
        // Clear choices and query NPC
        showingChoices = false
        availableChoices = []
        
        // Determine choice category for scoring
        let choiceCategory = categorizeChoice(choice)
        
        // Query NPC with the choice
        queryNPC(with: choice)
        
        // Notify parent about the choice for game progression
        onChoice(choiceCategory)
    }
    
    private func categorizeChoice(_ choice: String) -> String {
        let lowerChoice = choice.lowercased()
        
        if lowerChoice.contains("peace") || lowerChoice.contains("respect") {
            return "diplomatic_approach"
        } else if lowerChoice.contains("assurance") || lowerChoice.contains("protection") {
            return "show_respect"
        } else if lowerChoice.contains("understand") || lowerChoice.contains("concern") {
            return "cite_sources"
        } else if lowerChoice.contains("military") || lowerChoice.contains("strategic") {
            return "military_strategy"
        } else {
            return "general_inquiry"
        }
    }
    
    private func endDialogue() {
        dismiss()
    }
    
    // Helper properties
    private var characterColor: Color {
        switch dialogue.character {
        case "Patriarch Sophronius":
            return .blue
        case "Commander Khalid":
            return .red
        default:
            return .gray
        }
    }
    
    private var characterIcon: String {
        switch dialogue.character {
        case "Patriarch Sophronius":
            return "cross"
        case "Commander Khalid":
            return "shield"
        default:
            return "person"
        }
    }
    
    private func getCharacterTitle() -> String {
        switch dialogue.character {
        case "Patriarch Sophronius":
            return "Christian Patriarch of Jerusalem"
        case "Commander Khalid":
            return "Military Commander"
        default:
            return "Historical Figure"
        }
    }
}

struct DialogueMessage: Identifiable {
    let id: String
    let speaker: String
    let text: String
    let isUser: Bool
    let timestamp: Date
}

struct MessageBubble: View {
    let message: DialogueMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                messageBubble
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
            } else {
                messageBubble
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                Spacer()
            }
        }
    }
    
    private var messageBubble: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            if !message.isUser {
                Text(message.speaker)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .background(Color.clear)
        .cornerRadius(16)
        .frame(maxWidth: .infinity * 0.8, alignment: message.isUser ? .trailing : .leading)
    }
}

struct ResponseView: View {
    let response: RAGResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main response
            Text(response.response)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            // Citations if available
            if !response.citations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Historical Sources:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(response.citations.indices, id: \.self) { index in
                        let citation = response.citations[index]
                        CitationView(citation: citation, index: index + 1)
                    }
                }
            }
            
            // Confidence and contested indicators
            HStack {
                if response.confidence > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal")
                            .foregroundColor(.green)
                        Text("\(Int(response.confidence * 100))% confident")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if response.contested {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Historically contested")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
    }
}

struct CitationView: View {
    let citation: Citation
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("[\(index)]")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(citation.source)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(citation.text)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                if let page = citation.page {
                    Text("Page \(page)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
}