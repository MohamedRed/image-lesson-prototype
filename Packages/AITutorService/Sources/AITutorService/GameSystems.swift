import Foundation
import SceneKit
import AVFoundation
import SwiftUI

// MARK: - Complete Game State Management

class GameStateManager: ObservableObject {
    @Published var currentQuest: Quest?
    @Published var completedQuests: Set<String> = []
    @Published var inventory: [InventoryItem] = []
    @Published var playerStats: PlayerStats = PlayerStats()
    @Published var dialogueHistory: [DialogueEntry] = []
    @Published var currentScene: GameScene = .cityGates
    @Published var gameTime: GameTime = GameTime()
    
    enum GameScene: String, CaseIterable {
        case cityGates = "city_gates"
        case holySepulchre = "holy_sepulchre"
        case marketSquare = "market_square"
        case patriarch_chamber = "patriarch_chamber"
        case commandPost = "command_post"
    }
    
    func startQuest(_ quest: Quest) {
        currentQuest = quest
        print("🎯 Started quest: \(quest.title)")
    }
    
    func completeQuest(_ questId: String) {
        completedQuests.insert(questId)
        currentQuest = nil
        print("✅ Completed quest: \(questId)")
    }
    
    func addToInventory(_ item: InventoryItem) {
        inventory.append(item)
        print("📦 Added to inventory: \(item.name)")
    }
    
    func hasItem(_ itemId: String) -> Bool {
        return inventory.contains { $0.id == itemId }
    }
    
    func addDialogueEntry(_ entry: DialogueEntry) {
        dialogueHistory.append(entry)
    }
    
    func applyStatChanges(_ changes: [PlayerStats.StatType: Int]) {
        for (stat, change) in changes {
            switch stat {
            case .diplomacy: playerStats.diplomacy += change
            case .wisdom: playerStats.wisdom += change
            case .leadership: playerStats.leadership += change
            case .faith: playerStats.faith += change
            case .reputation: playerStats.reputation += change
            }
        }
        
        // Clamp values between 0 and 100
        playerStats.diplomacy = max(0, min(100, playerStats.diplomacy))
        playerStats.wisdom = max(0, min(100, playerStats.wisdom))
        playerStats.leadership = max(0, min(100, playerStats.leadership))
        playerStats.faith = max(0, min(100, playerStats.faith))
        playerStats.reputation = max(0, min(100, playerStats.reputation))
    }
    
    func getDecisionHistory() -> [DecisionHistoryEntry] {
        return dialogueHistory.compactMap { entry in
            if let choice = entry.playerChoice {
                return DecisionHistoryEntry(
                    choiceId: choice.id,
                    choiceText: choice.text,
                    npcId: entry.npcId,
                    timestamp: entry.timestamp
                )
            }
            return nil
        }
    }
}

struct DecisionHistoryEntry {
    let choiceId: String
    let choiceText: String
    let npcId: String
    let timestamp: Date
}

struct Quest {
    let id: String
    let title: String
    let description: String
    let objectives: [QuestObjective]
    let rewards: [InventoryItem]
    let requiredItems: [String]
    
    var isCompleted: Bool {
        return objectives.allSatisfy { $0.isCompleted }
    }
}

struct QuestObjective {
    let id: String
    let description: String
    var isCompleted: Bool = false
    let targetNPC: String?
    let requiredAction: String?
}

struct InventoryItem {
    let id: String
    let name: String
    let description: String
    let type: ItemType
    let rarity: ItemRarity
    let iconName: String
    
    enum ItemType {
        case document, artifact, key, diplomatic, religious
    }
    
    enum ItemRarity {
        case common, rare, legendary
        
        var color: Color {
            switch self {
            case .common: return .gray
            case .rare: return .blue
            case .legendary: return .orange
            }
        }
    }
}

struct PlayerStats {
    var diplomacy: Int = 50
    var wisdom: Int = 50
    var leadership: Int = 50
    var faith: Int = 50
    var reputation: Int = 50
    
    mutating func increaseStat(_ stat: StatType, by amount: Int) {
        switch stat {
        case .diplomacy: diplomacy = min(100, diplomacy + amount)
        case .wisdom: wisdom = min(100, wisdom + amount)
        case .leadership: leadership = min(100, leadership + amount)
        case .faith: faith = min(100, faith + amount)
        case .reputation: reputation = min(100, reputation + amount)
        }
    }
    
    enum StatType {
        case diplomacy, wisdom, leadership, faith, reputation
    }
    
    func calculateTotalScore() -> Int {
        return diplomacy + wisdom + leadership + faith + reputation
    }
}

struct DialogueEntry {
    let id: String
    let npcId: String
    let npcName: String
    let playerText: String?
    let npcText: String
    let timestamp: Date
    let playerChoice: DialogueChoice?
    let statChanges: [PlayerStats.StatType: Int]
}

struct DialogueChoice {
    let id: String
    let text: String
    let statRequirement: (PlayerStats.StatType, Int)?
    let unlockCondition: String?
    let consequences: DialogueConsequence
}

struct DialogueConsequence {
    let statChanges: [PlayerStats.StatType: Int]
    let itemsGained: [InventoryItem]
    let questUpdate: QuestUpdate?
    let sceneTransition: GameStateManager.GameScene?
}

struct QuestUpdate {
    let questId: String
    let progress: Double
}

struct GameTime {
    var currentHour: Int = 12
    var currentDay: Int = 1
    var season: Season = .spring
    
    enum Season {
        case spring, summer, autumn, winter
    }
    
    mutating func advance(hours: Int) {
        currentHour += hours
        if currentHour >= 24 {
            currentDay += currentHour / 24
            currentHour = currentHour % 24
        }
    }
    
    var timeOfDayString: String {
        switch currentHour {
        case 6...11: return "Morning"
        case 12...17: return "Afternoon"
        case 18...21: return "Evening"
        default: return "Night"
        }
    }
}

// MARK: - Advanced Audio System

class GameAudioManager {
    private var audioEngine: AVAudioEngine
    private var musicPlayer: AVAudioPlayerNode
    private var ambientPlayer: AVAudioPlayerNode
    private var sfxPlayer: AVAudioPlayerNode
    private var currentMusicTrack: String?
    
    init() {
        audioEngine = AVAudioEngine()
        musicPlayer = AVAudioPlayerNode()
        ambientPlayer = AVAudioPlayerNode()
        sfxPlayer = AVAudioPlayerNode()
        
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine.attach(musicPlayer)
        audioEngine.attach(ambientPlayer)
        audioEngine.attach(sfxPlayer)
        
        let mixer = audioEngine.mainMixerNode
        audioEngine.connect(musicPlayer, to: mixer, format: nil)
        audioEngine.connect(ambientPlayer, to: mixer, format: nil)
        audioEngine.connect(sfxPlayer, to: mixer, format: nil)
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func playMusic(_ trackName: String, volume: Float = 0.5) {
        guard trackName != currentMusicTrack else { return }
        
        // In a real implementation, you'd load actual audio files
        currentMusicTrack = trackName
        print("🎵 Playing music: \(trackName)")
        
        // Simulate different tracks for different scenes
        scheduleGeneratedTone(player: musicPlayer, frequency: getFrequencyForTrack(trackName), volume: volume)
    }
    
    func playAmbientSound(_ soundName: String, volume: Float = 0.3) {
        print("🌬️ Playing ambient sound: \(soundName)")
        scheduleGeneratedTone(player: ambientPlayer, frequency: getFrequencyForAmbient(soundName), volume: volume)
    }
    
    func playSFX(_ effectName: String, volume: Float = 0.7) {
        print("🔊 Playing SFX: \(effectName)")
        scheduleGeneratedTone(player: sfxPlayer, frequency: getFrequencyForSFX(effectName), volume: volume)
    }
    
    private func scheduleGeneratedTone(player: AVAudioPlayerNode, frequency: Float, volume: Float) {
        let sampleRate: Float = 44100
        let duration: Float = 2.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioEngine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: frameCount) else { return }
        
        buffer.frameLength = frameCount
        
        let channels = Int(buffer.format.channelCount)
        for channel in 0..<channels {
            let channelData = buffer.floatChannelData![channel]
            for frame in 0..<Int(frameCount) {
                let time = Float(frame) / sampleRate
                channelData[frame] = sin(2.0 * Float.pi * frequency * time) * volume * 0.1
            }
        }
        
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying {
            player.play()
        }
    }
    
    private func getFrequencyForTrack(_ trackName: String) -> Float {
        switch trackName {
        case "jerusalem_theme": return 220.0  // A3
        case "holy_sepulchre": return 174.6   // F3
        case "negotiation": return 196.0      // G3
        default: return 220.0
        }
    }
    
    private func getFrequencyForAmbient(_ soundName: String) -> Float {
        switch soundName {
        case "desert_wind": return 110.0    // A2
        case "city_bustle": return 130.8    // C3
        case "church_echo": return 87.3     // F2
        default: return 110.0
        }
    }
    
    private func getFrequencyForSFX(_ effectName: String) -> Float {
        switch effectName {
        case "footsteps": return 200.0
        case "door_open": return 300.0
        case "dialogue_beep": return 440.0
        case "quest_complete": return 880.0
        default: return 400.0
        }
    }
    
    func stopAll() {
        musicPlayer.stop()
        ambientPlayer.stop()
        sfxPlayer.stop()
    }
    
    func stopAllSounds() {
        stopAll()
    }
    
    func playAmbientMusic() {
        playMusic("jerusalem_theme", volume: 0.3)
        playAmbientSound("desert_wind", volume: 0.2)
    }
    
    func playDialogueSound() {
        playSFX("dialogue_beep", volume: 0.5)
    }
    
    func playChoiceSound() {
        playSFX("dialogue_beep", volume: 0.3)
    }
    
    func playQuestCompleteSound() {
        playSFX("quest_complete", volume: 0.8)
    }
}

// MARK: - Dialogue System

class DialogueSystem {
    private let gameState: GameStateManager
    private let audioManager: GameAudioManager
    
    init(gameState: GameStateManager, audioManager: GameAudioManager) {
        self.gameState = gameState
        self.audioManager = audioManager
    }
    
    func getDialogueOptions(for npcId: String, context: GameDialogueContext) -> [DialogueChoice] {
        switch npcId {
        case "patriarch_sophronius":
            return getPatriarchDialogue(context: context)
        case "commander_khalid":
            return getCommanderDialogue(context: context)
        default:
            return getGenericDialogue()
        }
    }
    
    private func getPatriarchDialogue(context: GameDialogueContext) -> [DialogueChoice] {
        var choices: [DialogueChoice] = []
        
        // Different dialogue based on game state
        if gameState.currentQuest?.id == "negotiate_surrender" {
            choices.append(DialogueChoice(
                id: "diplomatic_approach",
                text: "I come in peace to discuss terms that honor both our faiths",
                statRequirement: (.diplomacy, 30),
                unlockCondition: nil,
                consequences: DialogueConsequence(
                    statChanges: [.diplomacy: 5, .reputation: 3],
                    itemsGained: [],
                    questUpdate: QuestUpdate(questId: "negotiate_surrender", progress: 0.33),
                    sceneTransition: nil
                )
            ))
            
            choices.append(DialogueChoice(
                id: "show_respect",
                text: "Your wisdom is known throughout the land. Guide me in this matter",
                statRequirement: (.wisdom, 25),
                unlockCondition: nil,
                consequences: DialogueConsequence(
                    statChanges: [.wisdom: 4, .faith: 3],
                    itemsGained: [],
                    questUpdate: QuestUpdate(questId: "negotiate_surrender", progress: 0.5),
                    sceneTransition: nil
                )
            ))
            
            if gameState.playerStats.faith >= 40 {
                choices.append(DialogueChoice(
                    id: "religious_unity",
                    text: "Though our prayers differ, we both serve the same divine purpose",
                    statRequirement: (.faith, 40),
                    unlockCondition: nil,
                    consequences: DialogueConsequence(
                        statChanges: [.faith: 8, .diplomacy: 6],
                        itemsGained: [InventoryItem(
                            id: "blessed_scroll",
                            name: "Patriarch's Blessing",
                            description: "A sacred scroll blessed by Sophronius himself",
                            type: .religious,
                            rarity: .rare,
                            iconName: "scroll"
                        )],
                        questUpdate: QuestUpdate(questId: "negotiate_surrender", progress: 1.0),
                        sceneTransition: .holySepulchre
                    )
                ))
            }
        }
        
        return choices
    }
    
    private func getCommanderDialogue(context: GameDialogueContext) -> [DialogueChoice] {
        var choices: [DialogueChoice] = []
        
        if gameState.currentQuest?.id == "secure_city" {
            choices.append(DialogueChoice(
                id: "military_strategy",
                text: "What is your assessment of the city's defenses?",
                statRequirement: (.leadership, 20),
                unlockCondition: nil,
                consequences: DialogueConsequence(
                    statChanges: [.leadership: 4],
                    itemsGained: [InventoryItem(
                        id: "city_map",
                        name: "Jerusalem Strategic Map",
                        description: "Detailed military map showing defensive positions",
                        type: .document,
                        rarity: .common,
                        iconName: "map"
                    )],
                    questUpdate: QuestUpdate(questId: "secure_city", progress: 0.5),
                    sceneTransition: nil
                )
            ))
            
            choices.append(DialogueChoice(
                id: "peaceful_occupation",
                text: "We must secure the city without further bloodshed",
                statRequirement: (.diplomacy, 35),
                unlockCondition: nil,
                consequences: DialogueConsequence(
                    statChanges: [.diplomacy: 6, .reputation: 4],
                    itemsGained: [],
                    questUpdate: QuestUpdate(questId: "secure_city", progress: 1.0),
                    sceneTransition: nil
                )
            ))
        }
        
        return choices
    }
    
    private func getGenericDialogue() -> [DialogueChoice] {
        return [
            DialogueChoice(
                id: "general_greeting",
                text: "Peace be upon you",
                statRequirement: nil,
                unlockCondition: nil,
                consequences: DialogueConsequence(
                    statChanges: [.reputation: 1],
                    itemsGained: [],
                    questUpdate: nil,
                    sceneTransition: nil
                )
            )
        ]
    }
    
    func executeChoice(_ choice: DialogueChoice, npcId: String) {
        audioManager.playSFX("dialogue_beep")
        
        // Apply stat changes
        for (stat, change) in choice.consequences.statChanges {
            gameState.playerStats.increaseStat(stat, by: change)
        }
        
        // Add items to inventory
        for item in choice.consequences.itemsGained {
            gameState.addToInventory(item)
        }
        
        // Update quest
        if let questUpdate = choice.consequences.questUpdate {
            updateQuestProgress(questUpdate.questId, choiceId: choice.id)
        }
        
        // Handle scene transition
        if let newScene = choice.consequences.sceneTransition {
            gameState.currentScene = newScene
        }
        
        // Record dialogue entry
        let entry = DialogueEntry(
            id: UUID().uuidString,
            npcId: npcId,
            npcName: getNPCName(npcId),
            playerText: choice.text,
            npcText: generateNPCResponse(choice: choice, npcId: npcId),
            timestamp: Date(),
            playerChoice: choice,
            statChanges: choice.consequences.statChanges
        )
        
        gameState.addDialogueEntry(entry)
    }
    
    private func getNPCName(_ npcId: String) -> String {
        switch npcId {
        case "patriarch_sophronius": return "Patriarch Sophronius"
        case "commander_khalid": return "Commander Khalid"
        default: return "Unknown NPC"
        }
    }
    
    private func generateNPCResponse(choice: DialogueChoice, npcId: String) -> String {
        switch npcId {
        case "patriarch_sophronius":
            switch choice.id {
            case "diplomatic_approach":
                return "Your words bring hope, Caliph. Let us discuss terms that preserve the sanctity of our holy places while acknowledging your just rule."
            case "show_respect":
                return "Wisdom comes from understanding, not conquest. I see in you a leader who seeks truth over mere victory."
            case "religious_unity":
                return "Indeed, the Almighty works through many paths. Your respect for our faith honors both God and your character."
            default:
                return "I listen to your words with an open heart."
            }
        case "commander_khalid":
            switch choice.id {
            case "military_strategy":
                return "The city's walls are strong but the defenders are few. More importantly, the people seem ready for peace under just rule."
            case "peaceful_occupation":
                return "Your wisdom guides us, Caliph. A city taken through mercy rules longer than one taken by sword."
            default:
                return "Your orders shall be carried out, Commander of the Faithful."
            }
        default:
            return "I understand your position."
        }
    }
    
    private func updateQuestProgress(_ questId: String, choiceId: String) {
        guard let quest = gameState.currentQuest, quest.id == questId else { return }
        
        // Update specific objectives based on choice
        // This would be more complex in a full implementation
        print("🎯 Quest progress updated: \(questId) - \(choiceId)")
    }
}

// MARK: - Quest Management

class QuestManager {
    private let gameState: GameStateManager
    private let audioManager: GameAudioManager
    
    init(gameState: GameStateManager, audioManager: GameAudioManager) {
        self.gameState = gameState
        self.audioManager = audioManager
    }
    
    func initializeMainQuests() {
        let mainQuest = Quest(
            id: "omar_enters_jerusalem",
            title: "The Conquest of Jerusalem",
            description: "Navigate the complex negotiations for the peaceful surrender of Jerusalem while establishing lasting governance principles.",
            objectives: [
                QuestObjective(
                    id: "meet_patriarch",
                    description: "Meet with Patriarch Sophronius at the city gates",
                    targetNPC: "patriarch_sophronius",
                    requiredAction: "dialogue"
                ),
                QuestObjective(
                    id: "negotiate_terms",
                    description: "Negotiate surrender terms that protect Christian holy sites",
                    targetNPC: "patriarch_sophronius",
                    requiredAction: "diplomatic_choice"
                ),
                QuestObjective(
                    id: "prayer_decision",
                    description: "Make the historic decision about prayer at the Holy Sepulchre",
                    targetNPC: nil,
                    requiredAction: "historic_choice"
                ),
                QuestObjective(
                    id: "establish_governance",
                    description: "Establish governance principles for religious tolerance",
                    targetNPC: "commander_khalid",
                    requiredAction: "administrative_choice"
                )
            ],
            rewards: [
                InventoryItem(
                    id: "omar_covenant",
                    name: "The Covenant of Omar",
                    description: "Historic document establishing religious protections in Jerusalem",
                    type: .document,
                    rarity: .legendary,
                    iconName: "scroll.fill"
                )
            ],
            requiredItems: []
        )
        
        gameState.startQuest(mainQuest)
    }
    
    func getAvailableQuests() -> [Quest] {
        var quests: [Quest] = []
        
        // Add side quests based on game state
        if gameState.currentScene == .cityGates && !gameState.completedQuests.contains("explore_market") {
            quests.append(Quest(
                id: "explore_market",
                title: "Explore the Market",
                description: "Learn about the city's trade and economy",
                objectives: [
                    QuestObjective(
                        id: "visit_market",
                        description: "Visit the market square",
                        targetNPC: nil,
                        requiredAction: "location_visit"
                    )
                ],
                rewards: [
                    InventoryItem(
                        id: "merchant_seal",
                        name: "Merchant's Seal",
                        description: "Token of trust from local merchants",
                        type: .diplomatic,
                        rarity: .common,
                        iconName: "seal"
                    )
                ],
                requiredItems: []
            ))
        }
        
        return quests
    }
    
    func completeObjective(_ objectiveId: String) {
        guard var currentQuest = gameState.currentQuest else { return }
        
        // Find and complete the objective
        if let index = currentQuest.objectives.firstIndex(where: { $0.id == objectiveId }) {
            var updatedObjectives = currentQuest.objectives
            updatedObjectives[index] = QuestObjective(
                id: updatedObjectives[index].id,
                description: updatedObjectives[index].description,
                isCompleted: true,
                targetNPC: updatedObjectives[index].targetNPC,
                requiredAction: updatedObjectives[index].requiredAction
            )
            
            let updatedQuest = Quest(
                id: currentQuest.id,
                title: currentQuest.title,
                description: currentQuest.description,
                objectives: updatedObjectives,
                rewards: currentQuest.rewards,
                requiredItems: currentQuest.requiredItems
            )
            
            gameState.currentQuest = updatedQuest
            
            audioManager.playSFX("quest_complete")
            print("✅ Objective completed: \(objectiveId)")
            
            // Check if quest is fully completed
            if updatedQuest.isCompleted {
                completeQuest(updatedQuest)
            }
        }
    }
    
    private func completeQuest(_ quest: Quest) {
        gameState.completeQuest(quest.id)
        
        // Award quest rewards
        for reward in quest.rewards {
            gameState.addToInventory(reward)
        }
        
        audioManager.playSFX("quest_complete")
        print("🏆 Quest completed: \(quest.title)")
    }
    
    func startQuest(_ questId: String) {
        // Create the diplomatic conquest quest
        let diplomacyQuest = Quest(
            id: questId,
            title: "Diplomatic Conquest",
            description: "Achieve peaceful surrender through diplomatic negotiations",
            objectives: [
                QuestObjective(
                    id: "speak_patriarch",
                    description: "Speak with Patriarch Sophronius",
                    targetNPC: "patriarch_sophronius",
                    requiredAction: "dialogue"
                )
            ],
            rewards: [],
            requiredItems: []
        )
        
        gameState.startQuest(diplomacyQuest)
        print("🎯 Started quest: \(questId)")
    }
    
    func updateQuest(_ questId: String, progress: Double) {
        guard let currentQuest = gameState.currentQuest,
              currentQuest.id == questId else { return }
        
        // Update quest progress - in a full implementation this would
        // update specific objectives based on progress
        if progress >= 1.0 {
            completeQuest(currentQuest)
        }
        
        print("🎯 Updated quest progress: \(questId) - \(progress * 100)%")
    }
}