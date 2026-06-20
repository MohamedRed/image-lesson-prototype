import SwiftUI
import AITutorService

struct EpisodeGameplayView: View {
    let episode: Episode
    @ObservedObject var viewModel: AITutorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentScene = "city_gates"
    @State private var gameProgress: Double = 0.0
    @State private var showingDialogue = false
    @State private var currentDialogue: DialogueState?
    @State private var playerChoices: [String] = []
    @State private var score: Double = 0.0
    @State private var showingInspection = false
    @State private var showingSources = false
    @State private var showingDecision = false
    @State private var inspectionText = ""
    @State private var availableSources: [String] = []
    @State private var decisionChoices: [String] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background environment
                backgroundEnvironment
                
                VStack {
                    // Top UI Bar
                    HStack {
                        Button("Exit") {
                            exitGame()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                        
                        Spacer()
                        
                        // Progress indicator
                        VStack(spacing: 4) {
                            Text("Progress")
                                .font(.caption)
                                .foregroundColor(.white)
                            SwiftUI.ProgressView(value: gameProgress)
                                .frame(width: 120)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                        
                        Spacer()
                        
                        // Score
                        Text("Score: \(Int(score * 100))")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(20)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Current scene content
                    currentSceneView
                    
                    Spacer()
                    
                    // Game controls
                    gameControls
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startEpisode()
        }
        .sheet(isPresented: $showingDialogue) {
            if let dialogue = currentDialogue {
                DialogueView(
                    dialogue: dialogue,
                    viewModel: viewModel,
                    onChoice: handlePlayerChoice
                )
            }
        }
        .sheet(isPresented: $showingInspection) {
            InspectionView(text: inspectionText) {
                showingInspection = false
            }
        }
        .sheet(isPresented: $showingSources) {
            SourcesView(sources: availableSources) {
                showingSources = false
            }
        }
        .sheet(isPresented: $showingDecision) {
            DecisionView(choices: decisionChoices) { choice in
                handleKeyDecision(choice)
                showingDecision = false
            }
        }
    }
    
    private var backgroundEnvironment: some View {
        Group {
            switch currentScene {
            case "city_gates":
                // Jerusalem city gates environment
                Image(systemName: "building.2")
                    .font(.system(size: 200))
                    .foregroundColor(.brown.opacity(0.3))
                    .overlay(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.6), Color.yellow.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .ignoresSafeArea()
                
            case "holy_sepulchre":
                // Church interior environment
                Image(systemName: "cross")
                    .font(.system(size: 200))
                    .foregroundColor(.blue.opacity(0.3))
                    .overlay(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
                
            default:
                Color.black.ignoresSafeArea()
            }
        }
    }
    
    private var currentSceneView: some View {
        VStack(spacing: 20) {
            // Scene title
            Text(sceneTitle)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(radius: 2)
            
            // Scene description
            Text(sceneDescription)
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .shadow(radius: 1)
            
            // Characters present
            if !currentCharacters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(currentCharacters, id: \.self) { character in
                            CharacterView(characterName: character)
                                .onTapGesture {
                                    startDialogue(with: character)
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var gameControls: some View {
        VStack(spacing: 16) {
            // Available actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(availableActions, id: \.title) { action in
                        ActionButton(
                            title: action.title,
                            icon: action.icon,
                            color: action.color
                        ) {
                            performAction(action)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Objectives
            if !currentObjectives.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Objectives:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(currentObjectives, id: \.self) { objective in
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.yellow)
                            Text(objective)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    // MARK: - Game Logic
    
    private func startEpisode() {
        currentScene = "city_gates"
        gameProgress = 0.1
        score = 0.0
        playerChoices = []
        
        // Log telemetry
        viewModel.logEvent(type: "episode_started", data: [
            "episodeId": episode.id,
            "scene": currentScene
        ])
    }
    
    private func performAction(_ action: GameAction) {
        switch action.id {
        case "negotiate":
            startDialogue(with: "Patriarch Sophronius")
        case "inspect":
            inspectArea()
        case "consult_sources":
            showSources()
        case "make_decision":
            makeKeyDecision()
        case "next_scene":
            advanceToNextScene()
        default:
            break
        }
        
        // Update progress and score
        gameProgress += 0.1
        score += action.scoreValue
        
        viewModel.logEvent(type: "action_taken", data: [
            "action": action.id,
            "scene": currentScene,
            "score": score
        ])
    }
    
    private func startDialogue(with character: String) {
        currentDialogue = DialogueState(
            character: character,
            prompt: getCharacterPrompt(character),
            context: getCurrentContext()
        )
        showingDialogue = true
    }
    
    private func handlePlayerChoice(_ choice: String) {
        playerChoices.append(choice)
        showingDialogue = false
        
        // Process choice consequences
        switch choice {
        case "diplomatic_approach":
            score += 0.15
            gameProgress += 0.15
        case "show_respect":
            score += 0.20
            gameProgress += 0.10
        case "cite_sources":
            score += 0.25
            gameProgress += 0.05
        default:
            score += 0.05
        }
        
        viewModel.logEvent(type: "dialogue_choice", data: [
            "choice": choice,
            "character": currentDialogue?.character ?? "",
            "scene": currentScene
        ])
        
        // Check for scene completion
        if gameProgress >= 0.5 && currentScene == "city_gates" {
            advanceToNextScene()
        } else if gameProgress >= 1.0 {
            completeEpisode()
        }
    }
    
    private func advanceToNextScene() {
        if currentScene == "city_gates" {
            currentScene = "holy_sepulchre"
            gameProgress = 0.6
        }
        
        viewModel.logEvent(type: "scene_advanced", data: [
            "newScene": currentScene,
            "progress": gameProgress
        ])
    }
    
    private func completeEpisode() {
        let finalScore = min(1.0, score)
        
        // Create completion result
        let result = MissionResult(
            episodeId: episode.id,
            completed: true,
            score: finalScore,
            decisions: playerChoices.enumerated().map { index, choice in
                Decision(
                    id: "choice_\(index)",
                    choice: choice,
                    timestamp: Date().timeIntervalSince1970
                )
            },
            playTime: 1200 // 20 minutes
        )
        
        // Submit assessment
        let assessment = AssessmentData(
            episodeId: episode.id,
            completedAt: Date(),
            score: finalScore,
            competencyScores: [
                "evidence_analysis": finalScore * 0.9,
                "ethical_reasoning": finalScore * 0.85,
                "historical_context": finalScore * 0.95
            ],
            decisionsAnalysis: []
        )
        
        viewModel.submitAssessment(assessment)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            dismiss()
        }
    }
    
    private func exitGame() {
        // Save progress if needed
        let saveData = SaveData(
            episodeId: episode.id,
            checkpoint: currentScene,
            progress: gameProgress,
            inventory: [:],
            decisions: playerChoices.enumerated().map { index, choice in
                Decision(
                    id: "choice_\(index)",
                    choice: choice,
                    timestamp: Date().timeIntervalSince1970
                )
            },
            insightCards: [],
            playTime: 600,
            lastPlayedAt: Date()
        )
        
        Task {
            try? await viewModel.saveMission(slot: 1, data: saveData)
        }
        
        dismiss()
    }
    
    // MARK: - Scene Data
    
    private var sceneTitle: String {
        switch currentScene {
        case "city_gates":
            return "The Gates of Jerusalem"
        case "holy_sepulchre":
            return "Church of the Holy Sepulchre"
        default:
            return "Unknown Location"
        }
    }
    
    private var sceneDescription: String {
        switch currentScene {
        case "city_gates":
            return "You stand before the ancient walls of Jerusalem. Patriarch Sophronius awaits your approach. The city's fate hangs in the balance of these negotiations."
        case "holy_sepulchre":
            return "Inside Christianity's holiest site, you must decide how to respect both faiths while establishing lasting precedent for governance."
        default:
            return "An unknown chapter in history unfolds..."
        }
    }
    
    private var currentCharacters: [String] {
        switch currentScene {
        case "city_gates":
            return ["Patriarch Sophronius", "Commander Khalid"]
        case "holy_sepulchre":
            return ["Patriarch Sophronius"]
        default:
            return []
        }
    }
    
    private var currentObjectives: [String] {
        switch currentScene {
        case "city_gates":
            return ["Establish peaceful terms", "Build trust with Christian leadership", "Secure the city"]
        case "holy_sepulchre":
            return ["Respect Christian sanctity", "Set governance precedent", "Demonstrate religious tolerance"]
        default:
            return []
        }
    }
    
    private var availableActions: [GameAction] {
        switch currentScene {
        case "city_gates":
            return [
                GameAction(
                    id: "negotiate",
                    title: "Negotiate",
                    icon: "bubble.left.and.bubble.right",
                    color: .blue,
                    scoreValue: 0.1
                ),
                GameAction(
                    id: "consult_sources",
                    title: "Consult Sources",
                    icon: "book.fill",
                    color: .purple,
                    scoreValue: 0.05
                ),
                GameAction(
                    id: "inspect",
                    title: "Survey Area",
                    icon: "eye.fill",
                    color: .green,
                    scoreValue: 0.03
                )
            ]
        case "holy_sepulchre":
            return [
                GameAction(
                    id: "make_decision",
                    title: "Make Decision",
                    icon: "hand.point.up.fill",
                    color: .orange,
                    scoreValue: 0.2
                ),
                GameAction(
                    id: "negotiate",
                    title: "Discuss",
                    icon: "bubble.left.and.bubble.right",
                    color: .blue,
                    scoreValue: 0.1
                )
            ]
        default:
            return []
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCharacterPrompt(_ character: String) -> String {
        switch character {
        case "Patriarch Sophronius":
            return "How can we ensure the protection of Christian holy sites and our people?"
        case "Commander Khalid":
            return "What are your orders for securing the city, Caliph?"
        default:
            return "How may I assist you?"
        }
    }
    
    private func getCurrentContext() -> DialogueContext {
        DialogueContext(
            previousExchanges: [],
            currentScene: currentScene,
            evidencePresented: []
        )
    }
    
    private func inspectArea() {
        inspectionText = getSceneInsights()
        showingInspection = true
        
        score += 0.03
        gameProgress += 0.05
        
        viewModel.logEvent(type: "area_inspected", data: [
            "scene": currentScene,
            "insights": inspectionText
        ])
    }
    
    private func showSources() {
        availableSources = getAvailableSources()
        showingSources = true
        
        score += 0.05
        gameProgress += 0.02
        
        viewModel.logEvent(type: "sources_consulted", data: [
            "scene": currentScene,
            "sources": availableSources
        ])
    }
    
    private func makeKeyDecision() {
        if currentScene == "holy_sepulchre" {
            decisionChoices = [
                "Pray outside the church to show respect for Christian space",
                "Accept the Patriarch's invitation to pray inside together", 
                "Suggest establishing a dedicated prayer area nearby"
            ]
            showingDecision = true
        }
    }
    
    private func handleKeyDecision(_ choice: String) {
        let choiceCategory: String
        let narrativeText: String
        
        switch choice {
        case let c where c.contains("outside"):
            choiceCategory = "diplomatic_approach"
            narrativeText = """
            You choose to pray outside the Church of the Holy Sepulchre, demonstrating respect for Christian sacred space while maintaining your own faith practices. This decision will be remembered as a pivotal moment establishing religious tolerance in Jerusalem.
            
            Patriarch Sophronius is deeply moved by this gesture of respect, seeing it as proof of your commitment to protecting Christian holy sites and communities.
            """
            score += 0.3
            gameProgress += 0.4
            
        case let c where c.contains("inside"):
            choiceCategory = "show_unity"
            narrativeText = """
            You accept the Patriarch's invitation to pray inside together, creating an unprecedented moment of interfaith worship. This bold choice demonstrates religious unity but may concern some of your advisors.
            
            The gesture creates a powerful symbol of cooperation between faiths.
            """
            score += 0.25
            gameProgress += 0.35
            
        default:
            choiceCategory = "compromise_solution"
            narrativeText = """
            You suggest establishing a dedicated prayer area nearby, creating a practical solution that respects both faiths while avoiding potential controversy.
            
            This measured approach satisfies most parties while establishing clear precedents for future governance.
            """
            score += 0.2
            gameProgress += 0.3
        }
        
        // Log the historic decision
        viewModel.logEvent(type: "historic_decision", data: [
            "choice": choice,
            "category": choiceCategory,
            "scene": currentScene
        ])
        
        // Process the choice through the normal game flow
        handlePlayerChoice(choiceCategory)
        
        print("HISTORIC DECISION: \(narrativeText)")
    }
    
    private func getSceneInsights() -> String {
        switch currentScene {
        case "city_gates":
            return """
            The massive stone gates of Jerusalem stand before you, weathered by centuries of conflict. Patriarch Sophronius waits with a small delegation of Christian leaders. The city's defenders have laid down their arms, but tension fills the air. You notice the strategic positioning of your own forces and the anxious faces of civilians watching from the walls above.
            """
        case "holy_sepulchre":
            return """
            You stand before Christianity's holiest site - the Church of the Holy Sepulchre, believed to house both Calvary and Christ's tomb. The architecture shows Byzantine and Roman influences. Patriarch Sophronius gestures toward the entrance, his eyes watching carefully for your response. This moment will define religious policy for generations.
            """
        default:
            return "You observe your surroundings carefully, noting important details about the current situation."
        }
    }
    
    private func getAvailableSources() -> [String] {
        switch currentScene {
        case "city_gates":
            return [
                "Chronicle of Theophanes: Account of Omar's arrival",
                "Al-Tabari's History: Muslim perspective on conquest", 
                "Byzantine sources: Sophronius's letters",
                "Archaeological evidence: 7th century Jerusalem"
            ]
        case "holy_sepulchre":
            return [
                "Sophronius's Synodical Letter: Religious concerns",
                "Early Islamic sources: Treatment of Christians",
                "Pilgrimage accounts: Description of the church",
                "Legal precedents: Previous conquests"
            ]
        default:
            return ["Historical chronicles", "Archaeological evidence"]
        }
    }
}

// MARK: - Supporting Views and Models

struct CharacterView: View {
    let characterName: String
    
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(characterColor)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: characterIcon)
                        .font(.title2)
                        .foregroundColor(.white)
                )
            
            Text(characterName)
                .font(.caption)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 80)
    }
    
    private var characterColor: Color {
        switch characterName {
        case "Patriarch Sophronius":
            return .blue
        case "Commander Khalid":
            return .red
        default:
            return .gray
        }
    }
    
    private var characterIcon: String {
        switch characterName {
        case "Patriarch Sophronius":
            return "cross"
        case "Commander Khalid":
            return "shield"
        default:
            return "person"
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .background(color)
            .cornerRadius(12)
        }
    }
}

struct GameAction {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let scoreValue: Double
}

struct DialogueState {
    let character: String
    let prompt: String
    let context: DialogueContext
}

// MARK: - Supporting Game Views

struct InspectionView: View {
    let text: String
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Area Inspection")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(text)
                        .font(.body)
                        .lineSpacing(4)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Continue") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

struct SourcesView: View {
    let sources: [String]
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List(sources, id: \.self) { source in
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.components(separatedBy: ":")[0])
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if source.contains(":") {
                        Text(source.components(separatedBy: ":").dropFirst().joined(separator: ":"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Historical Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

struct DecisionView: View {
    let choices: [String]
    let onChoice: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("Critical Decision")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("This choice will have lasting historical consequences. Choose carefully:")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                VStack(spacing: 16) {
                    ForEach(choices, id: \.self) { choice in
                        Button(action: {
                            onChoice(choice)
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(choice)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}