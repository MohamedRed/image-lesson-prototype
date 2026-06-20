import SwiftUI

// MARK: - Advanced Dialogue Interface

struct DialogueInterface: View {
    let npcId: String
    let npcName: String
    @ObservedObject var gameState: GameStateManager
    let dialogueSystem: DialogueSystem
    let onDismiss: () -> Void
    let onChoiceMade: (DialogueChoice) -> Void
    
    @State private var availableChoices: [DialogueChoice] = []
    @State private var conversationHistory: [DialogueMessage] = []
    @State private var currentNPCMessage: String = ""
    @State private var isThinking = false
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // NPC Portrait and Info
                npcHeaderView
                
                // Conversation Display
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(conversationHistory) { message in
                                DialogueMessageView(message: message)
                                    .id(message.id)
                            }
                            
                            if isThinking {
                                ThinkingIndicator()
                            }
                        }
                        .padding()
                    }
                    .frame(maxHeight: 300)
                    .onChange(of: conversationHistory.count) { _ in
                        if let lastMessage = conversationHistory.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Dialogue Choices
                if !availableChoices.isEmpty {
                    dialogueChoicesView
                } else {
                    // Continue button
                    Button("Continue") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .padding()
        }
        .onAppear {
            initializeDialogue()
        }
    }
    
    private var npcHeaderView: some View {
        HStack {
            // NPC Portrait
            Circle()
                .fill(getNPCColor())
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: getNPCIcon())
                        .font(.title)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading) {
                Text(npcName)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(getNPCTitle())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Relationship status
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(getRelationshipColor())
                        .font(.caption)
                    
                    Text(getRelationshipStatus())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var dialogueChoicesView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Choose your response:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                ForEach(availableChoices, id: \.id) { choice in
                    DialogueChoiceButton(
                        choice: choice,
                        playerStats: gameState.playerStats,
                        action: {
                            selectChoice(choice)
                        }
                    )
                }
            }
            .padding()
        }
        .frame(maxHeight: 200)
    }
    
    private func initializeDialogue() {
        loadDialogueChoices()
        
        // Add initial greeting
        let greeting = getInitialGreeting()
        let greetingMessage = DialogueMessage(
            id: UUID().uuidString,
            text: greeting,
            isFromPlayer: false,
            timestamp: Date(),
            speakerName: npcName
        )
        
        conversationHistory.append(greetingMessage)
    }
    
    private func loadDialogueChoices() {
        let context = GameDialogueContext(
            currentScene: gameState.currentScene.rawValue,
            playerStats: gameState.playerStats,
            inventory: gameState.inventory,
            questProgress: gameState.currentQuest?.objectives ?? []
        )
        
        availableChoices = dialogueSystem.getDialogueOptions(for: npcId, context: context)
    }
    
    private func selectChoice(_ choice: DialogueChoice) {
        // Add player message
        let playerMessage = DialogueMessage(
            id: UUID().uuidString,
            text: choice.text,
            isFromPlayer: true,
            timestamp: Date(),
            speakerName: "You"
        )
        
        conversationHistory.append(playerMessage)
        
        // Show thinking indicator
        isThinking = true
        availableChoices = []
        
        // Execute choice consequences
        dialogueSystem.executeChoice(choice, npcId: npcId)
        
        // Generate NPC response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isThinking = false
            
            let npcResponse = generateNPCResponse(to: choice)
            let npcMessage = DialogueMessage(
                id: UUID().uuidString,
                text: npcResponse,
                isFromPlayer: false,
                timestamp: Date(),
                speakerName: npcName
            )
            
            conversationHistory.append(npcMessage)
            
            // Check if conversation should continue
            if shouldContinueConversation(after: choice) {
                loadDialogueChoices()
            }
            
            // Notify that choice was made
            onChoiceMade(choice)
        }
    }
    
    private func getInitialGreeting() -> String {
        switch npcId {
        case "patriarch_sophronius":
            return "Peace be with you, Caliph Omar. I have been expecting your arrival. The fate of Jerusalem and its people weighs heavily on my heart."
        case "commander_khalid":
            return "Commander of the Faithful, the city awaits your orders. Our forces are ready, and the people watch to see what kind of ruler you will be."
        default:
            return "Greetings, Caliph. How may I serve you?"
        }
    }
    
    private func generateNPCResponse(to choice: DialogueChoice) -> String {
        // This would typically come from the RAG system or predefined responses
        switch (npcId, choice.id) {
        case ("patriarch_sophronius", "diplomatic_approach"):
            return "Your words give me hope. I see in you not just a conqueror, but a leader who understands the sacred nature of this city. Let us speak of how your rule might preserve what we hold most dear."
            
        case ("patriarch_sophronius", "show_respect"):
            return "Wisdom recognizes wisdom, Caliph. Your humility honors you. I believe we can find a path that serves both God and justice in this matter."
            
        case ("patriarch_sophronius", "religious_unity"):
            return "Truly, the Almighty works in mysterious ways. Your understanding of our shared reverence for the divine shows a heart touched by grace. I am moved to offer you this blessing."
            
        case ("commander_khalid", "military_strategy"):
            return "The city's defenses are sound, but more importantly, the people seem ready to accept just rule. A wise commander knows when mercy serves better than might."
            
        case ("commander_khalid", "peaceful_occupation"):
            return "Your wisdom guides us well, Caliph. A city taken through mercy rules longer than one taken by sword. I shall ensure our forces conduct themselves with honor."
            
        default:
            return "I understand your position and will consider your words carefully."
        }
    }
    
    private func shouldContinueConversation(after choice: DialogueChoice) -> Bool {
        // Continue conversation unless it's an ending choice
        return !["end_conversation", "leave", "farewell"].contains(choice.id)
    }
    
    private func getNPCColor() -> Color {
        switch npcId {
        case "patriarch_sophronius": return .blue
        case "commander_khalid": return .red
        default: return .gray
        }
    }
    
    private func getNPCIcon() -> String {
        switch npcId {
        case "patriarch_sophronius": return "cross.fill"
        case "commander_khalid": return "shield.fill"
        default: return "person.fill"
        }
    }
    
    private func getNPCTitle() -> String {
        switch npcId {
        case "patriarch_sophronius": return "Patriarch of Jerusalem"
        case "commander_khalid": return "Military Commander"
        default: return "Citizen"
        }
    }
    
    private func getRelationshipStatus() -> String {
        // This would be based on previous interactions
        return "Respectful"
    }
    
    private func getRelationshipColor() -> Color {
        return .green // Simplified - would be dynamic based on actual relationship
    }
}

struct DialogueMessage: Identifiable {
    let id: String
    let text: String
    let isFromPlayer: Bool
    let timestamp: Date
    let speakerName: String
}

struct DialogueMessageView: View {
    let message: DialogueMessage
    
    var body: some View {
        HStack {
            if message.isFromPlayer {
                Spacer()
                messageContent
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
            } else {
                messageContent
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                Spacer()
            }
        }
    }
    
    private var messageContent: some View {
        VStack(alignment: message.isFromPlayer ? .trailing : .leading, spacing: 4) {
            if !message.isFromPlayer {
                Text(message.speakerName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .cornerRadius(16)
        .frame(maxWidth: .infinity * 0.8, alignment: message.isFromPlayer ? .trailing : .leading)
    }
}

struct DialogueChoiceButton: View {
    let choice: DialogueChoice
    let playerStats: PlayerStats
    let action: () -> Void
    
    private var isAvailable: Bool {
        guard let (requiredStat, requiredValue) = choice.statRequirement else { return true }
        
        switch requiredStat {
        case .diplomacy: return playerStats.diplomacy >= requiredValue
        case .wisdom: return playerStats.wisdom >= requiredValue
        case .leadership: return playerStats.leadership >= requiredValue
        case .faith: return playerStats.faith >= requiredValue
        case .reputation: return playerStats.reputation >= requiredValue
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(choice.text)
                        .font(.body)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(isAvailable ? .primary : .secondary)
                    
                    Spacer()
                    
                    if let (stat, value) = choice.statRequirement {
                        StatRequirementBadge(stat: stat, requiredValue: value, isAvailable: isAvailable)
                    }
                }
                
                // Show consequence preview
                if !choice.consequences.statChanges.isEmpty {
                    HStack {
                        ForEach(Array(choice.consequences.statChanges.keys), id: \.self) { stat in
                            if let change = choice.consequences.statChanges[stat] {
                                StatChangeBadge(stat: stat, change: change)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(isAvailable ? Color(.systemGray6) : Color(.systemGray5))
            .cornerRadius(12)
            .opacity(isAvailable ? 1.0 : 0.6)
        }
        .disabled(!isAvailable)
    }
}

struct StatRequirementBadge: View {
    let stat: PlayerStats.StatType
    let requiredValue: Int
    let isAvailable: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: getStatIcon(stat))
                .font(.caption)
            Text("\(requiredValue)")
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isAvailable ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
        .foregroundColor(isAvailable ? .green : .red)
        .cornerRadius(8)
    }
    
    private func getStatIcon(_ stat: PlayerStats.StatType) -> String {
        switch stat {
        case .diplomacy: return "hand.raised"
        case .wisdom: return "brain"
        case .leadership: return "crown"
        case .faith: return "star"
        case .reputation: return "heart"
        }
    }
}

struct StatChangeBadge: View {
    let stat: PlayerStats.StatType
    let change: Int
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: getStatIcon(stat))
                .font(.caption2)
            Text(change > 0 ? "+\(change)" : "\(change)")
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .cornerRadius(6)
    }
    
    private func getStatIcon(_ stat: PlayerStats.StatType) -> String {
        switch stat {
        case .diplomacy: return "hand.raised"
        case .wisdom: return "brain"
        case .leadership: return "crown"
        case .faith: return "star"
        case .reputation: return "heart"
        }
    }
}

struct ThinkingIndicator: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            animationPhase = 1
        }
    }
}

// Game-specific dialogue context to avoid conflicts
struct GameDialogueContext {
    let currentScene: String
    let playerStats: PlayerStats
    let inventory: [InventoryItem]
    let questProgress: [QuestObjective]
}