import SwiftUI
import SceneKit

// MARK: - Complete Game UI System

struct GameHUD: View {
    @ObservedObject var gameState: GameStateManager
    @State private var showingInventory = false
    @State private var showingQuestJournal = false
    @State private var showingPlayerStats = false
    @State private var showingSettings = false
    
    var body: some View {
        VStack {
            // Top HUD
            HStack {
                // Quest tracker
                if let currentQuest = gameState.currentQuest {
                    QuestTrackerView(quest: currentQuest)
                }
                
                Spacer()
                
                // Time and date
                VStack(alignment: .trailing) {
                    Text("\(gameState.gameTime.timeOfDayString)")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("Day \(gameState.gameTime.currentDay)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
            }
            .padding()
            
            Spacer()
            
            // Bottom HUD
            HStack {
                // Quick access buttons
                HUD_Button(icon: "backpack.fill", label: "Inventory") {
                    showingInventory = true
                }
                
                Spacer()
                
                HUD_Button(icon: "book.fill", label: "Journal") {
                    showingQuestJournal = true
                }
                
                Spacer()
                
                HUD_Button(icon: "person.fill", label: "Stats") {
                    showingPlayerStats = true
                }
                
                Spacer()
                
                HUD_Button(icon: "gear", label: "Settings") {
                    showingSettings = true
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showingInventory) {
            InventoryView(gameState: gameState)
        }
        .sheet(isPresented: $showingQuestJournal) {
            QuestJournalView(gameState: gameState)
        }
        .sheet(isPresented: $showingPlayerStats) {
            PlayerStatsView(gameState: gameState)
        }
        .sheet(isPresented: $showingSettings) {
            GameSettingsView()
        }
    }
}

struct HUD_Button: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
        }
    }
}

struct QuestTrackerView: View {
    let quest: Quest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(quest.title)
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(quest.objectives.prefix(3), id: \.id) { objective in
                HStack {
                    Image(systemName: objective.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(objective.isCompleted ? .green : .white.opacity(0.7))
                        .font(.caption)
                    
                    Text(objective.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
        .frame(maxWidth: 300)
    }
}

// MARK: - Inventory System

struct InventoryView: View {
    @ObservedObject var gameState: GameStateManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: InventoryItem?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Inventory grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(gameState.inventory, id: \.id) { item in
                            InventorySlot(item: item) {
                                selectedItem = item
                            }
                        }
                        
                        // Empty slots
                        ForEach(0..<(20 - gameState.inventory.count), id: \.self) { _ in
                            EmptyInventorySlot()
                        }
                    }
                    .padding()
                }
                
                // Item details panel
                if let selectedItem = selectedItem {
                    ItemDetailsPanel(item: selectedItem)
                        .transition(.slide)
                }
            }
            .navigationTitle("Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct InventorySlot: View {
    let item: InventoryItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: item.iconName)
                    .font(.title2)
                    .foregroundColor(item.rarity.color)
                
                Text(item.name)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 80, height: 80)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(item.rarity.color, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyInventorySlot: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .frame(width: 80, height: 80)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

struct ItemDetailsPanel: View {
    let item: InventoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: item.iconName)
                    .font(.title)
                    .foregroundColor(item.rarity.color)
                
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.headline)
                    
                    Text(item.rarity.description)
                        .font(.caption)
                        .foregroundColor(item.rarity.color)
                }
                
                Spacer()
            }
            
            Text(item.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            // Item actions
            HStack {
                if item.type == .document {
                    Button("Read") {
                        // Open document viewer
                    }
                    .buttonStyle(.bordered)
                }
                
                if item.type == .key {
                    Button("Use") {
                        // Use key
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding()
    }
}

// MARK: - Quest Journal

struct QuestJournalView: View {
    @ObservedObject var gameState: GameStateManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedQuest: Quest?
    
    var body: some View {
        NavigationView {
            List {
                if let currentQuest = gameState.currentQuest {
                    Section("Active Quest") {
                        QuestRow(quest: currentQuest, isActive: true) {
                            selectedQuest = currentQuest
                        }
                    }
                }
                
                Section("Dialogue History") {
                    ForEach(gameState.dialogueHistory.suffix(10), id: \.id) { entry in
                        DialogueHistoryRow(entry: entry)
                    }
                }
                
                Section("Completed Quests") {
                    ForEach(Array(gameState.completedQuests), id: \.self) { questId in
                        CompletedQuestRow(questId: questId)
                    }
                }
            }
            .navigationTitle("Quest Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: Binding<QuestWrapper?>(
                get: { selectedQuest.map(QuestWrapper.init) },
                set: { selectedQuest = $0?.quest }
            )) { wrapper in
                QuestDetailView(quest: wrapper.quest)
            }
        }
    }
}

struct QuestWrapper: Identifiable {
    let id = UUID()
    let quest: Quest
}

struct QuestRow: View {
    let quest: Quest
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(quest.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if isActive {
                        Text("Active")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                Text(quest.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                ProgressView(
                    value: Double(quest.objectives.filter(\.isCompleted).count),
                    total: Double(quest.objectives.count)
                )
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DialogueHistoryRow: View {
    let entry: DialogueEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.npcName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let playerText = entry.playerText {
                Text("You: \(playerText)")
                    .font(.body)
                    .foregroundColor(.blue)
                    .italic()
            }
            
            Text("\(entry.npcName): \(entry.npcText)")
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
}

struct CompletedQuestRow: View {
    let questId: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text(questId.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.body)
            
            Spacer()
        }
    }
}

struct QuestDetailView: View {
    let quest: Quest
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(quest.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(quest.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Objectives")
                            .font(.headline)
                        
                        ForEach(quest.objectives, id: \.id) { objective in
                            HStack(alignment: .top) {
                                Image(systemName: objective.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(objective.isCompleted ? .green : .gray)
                                    .padding(.top, 2)
                                
                                Text(objective.description)
                                    .font(.body)
                            }
                        }
                    }
                    
                    if !quest.rewards.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Rewards")
                                .font(.headline)
                            
                            ForEach(quest.rewards, id: \.id) { reward in
                                HStack {
                                    Image(systemName: reward.iconName)
                                        .foregroundColor(reward.rarity.color)
                                    
                                    VStack(alignment: .leading) {
                                        Text(reward.name)
                                            .font(.body)
                                        Text(reward.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Quest Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Player Stats

struct PlayerStatsView: View {
    @ObservedObject var gameState: GameStateManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Character portrait area
                    VStack {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)
                            )
                        
                        Text("Caliph Omar ibn al-Khattab")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding()
                    
                    // Stats
                    VStack(spacing: 16) {
                        StatBar(label: "Diplomacy", value: gameState.playerStats.diplomacy, color: .blue)
                        StatBar(label: "Wisdom", value: gameState.playerStats.wisdom, color: .purple)
                        StatBar(label: "Leadership", value: gameState.playerStats.leadership, color: .orange)
                        StatBar(label: "Faith", value: gameState.playerStats.faith, color: .green)
                        StatBar(label: "Reputation", value: gameState.playerStats.reputation, color: .red)
                    }
                    .padding()
                    
                    // Achievements section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Achievements")
                            .font(.headline)
                        
                        // Example achievements based on game state
                        if gameState.completedQuests.contains("negotiate_surrender") {
                            AchievementRow(
                                icon: "hand.raised.fill",
                                title: "Peacemaker",
                                description: "Successfully negotiated the surrender of Jerusalem"
                            )
                        }
                        
                        if gameState.inventory.contains(where: { $0.type == .religious }) {
                            AchievementRow(
                                icon: "star.fill",
                                title: "Blessed",
                                description: "Received a religious blessing"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
            .navigationTitle("Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StatBar: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(value)/100")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: Double(value), total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
        }
    }
}

struct AchievementRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.yellow)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Game Settings

struct GameSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var masterVolume: Double = 0.7
    @State private var musicVolume: Double = 0.5
    @State private var sfxVolume: Double = 0.8
    @State private var enableVibration = true
    @State private var showFPS = false
    @State private var graphicsQuality = GraphicsQuality.high
    
    enum GraphicsQuality: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case ultra = "Ultra"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Audio") {
                    VStack {
                        HStack {
                            Text("Master Volume")
                            Spacer()
                            Text("\(Int(masterVolume * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $masterVolume, in: 0...1)
                    }
                    
                    VStack {
                        HStack {
                            Text("Music Volume")
                            Spacer()
                            Text("\(Int(musicVolume * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $musicVolume, in: 0...1)
                    }
                    
                    VStack {
                        HStack {
                            Text("SFX Volume")
                            Spacer()
                            Text("\(Int(sfxVolume * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $sfxVolume, in: 0...1)
                    }
                }
                
                Section("Gameplay") {
                    Toggle("Enable Vibration", isOn: $enableVibration)
                }
                
                Section("Graphics") {
                    Picker("Graphics Quality", selection: $graphicsQuality) {
                        ForEach(GraphicsQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    
                    Toggle("Show FPS Counter", isOn: $showFPS)
                }
                
                Section("Game Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Engine")
                        Spacer()
                        Text("SceneKit")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension InventoryItem.ItemRarity {
    var description: String {
        switch self {
        case .common: return "Common"
        case .rare: return "Rare"
        case .legendary: return "Legendary"
        }
    }
}