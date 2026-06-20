import Foundation
import Combine
import AITutorService

@MainActor
public class AITutorViewModel: ObservableObject {
    @Published var episodes: [Episode] = []
    @Published var currentEpisode: Episode?
    @Published var saves: [Int: SaveData] = [:]
    @Published var insightCards: [InsightCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    
    private let service: AITutorServicing
    private var cancellables = Set<AnyCancellable>()
    
    public init(service: AITutorServicing = MockAITutorService()) {
        self.service = service
    }
    
    // MARK: - Episode Management
    
    func loadEpisodes() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loadedEpisodes = try await service.listEpisodes()
                self.episodes = loadedEpisodes
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func startEpisode(_ episode: Episode, slot: Int? = nil) {
        currentEpisode = episode
        isDownloading = true
        downloadProgress = 0
        
        Task {
            do {
                // Load save if slot provided
                if let slot = slot {
                    let saveData = try await service.loadSave(slot: slot)
                    // Apply save data
                    if let save = saveData {
                        print("Loaded save for episode \(save.episodeId) at checkpoint \(save.checkpoint)")
                    }
                }
                
                // Download episode assets
                downloadProgress = 0.2
                let assets = try await service.downloadEpisodeAssets(episodeId: episode.id)
                
                downloadProgress = 0.5
                
                // Get episode configuration
                let config = try await service.getEpisodeConfig(episodeId: episode.id)
                
                downloadProgress = 0.8
                
                // Initialize Unity bridge and start mission
                if let unityBridge = service.unityBridge {
                    unityBridge.startMission(episodeId: episode.id, assets: assets)
                    
                    // Set up Unity callbacks
                    setupUnityCallbacks()
                } else {
                    // For now, just simulate without Unity
                    print("Unity not available - simulating episode start")
                }
                
                downloadProgress = 1.0
                isDownloading = false
                
            } catch {
                self.errorMessage = error.localizedDescription
                self.isDownloading = false
            }
        }
    }
    
    // MARK: - Save Management
    
    func loadSaves() {
        Task {
            do {
                for slot in 1...3 {
                    if let save = try await service.loadSave(slot: slot) {
                        saves[slot] = save
                    }
                }
            } catch {
                print("Failed to load saves: \(error)")
            }
        }
    }
    
    func saveProgress(slot: Int) {
        guard let episode = currentEpisode else { return }
        
        let saveData = SaveData(
            episodeId: episode.id,
            checkpoint: "scene_1", // Would come from Unity
            progress: 0.5, // Would come from Unity
            inventory: [:],
            decisions: [],
            insightCards: [],
            playTime: 1800,
            lastPlayedAt: Date()
        )
        
        Task {
            do {
                try await service.saveMission(slot: slot, data: saveData)
                saves[slot] = saveData
            } catch {
                self.errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteSave(slot: Int) {
        Task {
            do {
                try await service.deleteSave(slot: slot)
                saves.removeValue(forKey: slot)
            } catch {
                self.errorMessage = "Failed to delete save: \(error.localizedDescription)"
            }
        }
    }
    
    func saveMission(slot: Int, data: SaveData) async throws {
        try await service.saveMission(slot: slot, data: data)
        saves[slot] = data
    }
    
    // MARK: - RAG Integration
    
    func queryNPC(npcId: String, prompt: String, context: DialogueContext?) async throws -> RAGResponse {
        guard let episode = currentEpisode else {
            throw AITutorError.invalidResponse
        }
        
        return try await service.queryRAG(
            episodeId: episode.id,
            npcId: npcId,
            prompt: prompt,
            context: context
        )
    }
    
    // MARK: - Assessment & Insights
    
    func submitAssessment(_ assessment: AssessmentData) {
        Task {
            do {
                let insights = try await service.submitAssessment(
                    episodeId: assessment.episodeId,
                    assessment: assessment
                )
                
                self.insightCards.append(contentsOf: insights.cards)
            } catch {
                print("Failed to submit assessment: \(error)")
            }
        }
    }
    
    func loadInsightCards() {
        // Load from local storage or service
        // For now, use mock data
        insightCards = [
            InsightCard(id: "1",
                        competency: "evidence_analysis",
                        prompt: "How do primary sources differ from secondary sources?",
                        difficulty: .easy,
                        nextReviewDate: Date().addingTimeInterval(86400)),
            InsightCard(id: "2",
                        competency: "ethical_reasoning",
                        prompt: "When is compromise more valuable than standing firm?",
                        difficulty: .medium,
                        nextReviewDate: Date().addingTimeInterval(172800)),
            InsightCard(id: "3",
                        competency: "historical_context",
                        prompt: "How did religious diversity shape medieval Jerusalem?",
                        difficulty: .hard,
                        nextReviewDate: Date().addingTimeInterval(259200))
        ]
    }
    
    // MARK: - Telemetry
    
    func logEvent(type: String, data: [String: Any]) {
        guard let episode = currentEpisode else { return }
        
        let event = TelemetryEvent(
            sessionId: UUID().uuidString,
            episodeId: episode.id,
            timestamp: Date().timeIntervalSince1970,
            type: type,
            data: data
        )
        
        Task {
            try? await service.logEvents([event])
        }
    }
    
    // MARK: - Unity Bridge Setup
    
    private func setupUnityCallbacks() {
        guard let unityBridge = service.unityBridge else { return }
        
        // Handle mission completion
        var mutableBridge = unityBridge
        mutableBridge.onMissionCompleted = { [weak self] result in
            self?.handleMissionCompleted(result)
        }
        
        // Handle RAG queries from Unity
        mutableBridge.onRAGQueryRequested = { [weak self] npcId, prompt in
            guard let self = self else {
                return RAGResponse(response: "Error: Service unavailable",
                                    citations: [],
                                    confidence: 0,
                                    contested: false)
            }
            
            do {
                return try await self.queryNPC(npcId: npcId, prompt: prompt, context: nil)
            } catch {
                return RAGResponse(response: "Error: \(error.localizedDescription)",
                                    citations: [],
                                    confidence: 0,
                                    contested: false)
            }
        }
        
        // Handle telemetry events
        mutableBridge.onEventsLogged = { [weak self] events in
            Task {
                try? await self?.service.logEvents(events)
            }
        }
    }
    
    private func handleMissionCompleted(_ result: MissionResult) {
        // Create assessment from result
        let assessment = AssessmentData(episodeId: result.episodeId,
                                         completedAt: Date(),
                                         score: result.score,
                                         competencyScores: [
                                            "evidence_analysis": result.score * 0.9,
                                            "ethical_reasoning": result.score * 0.85,
                                            "historical_context": result.score * 0.95
                                         ],
                                         decisionsAnalysis: result.decisions.map { decision in
                                            DecisionAnalysis(decisionId: decision.id,
                                                             quality: 0.8,
                                                             reasoning: "Well-considered",
                                                             ethicalConsideration: true,
                                                             evidenceUsed: [])
                                         })
        
        submitAssessment(assessment)
        currentEpisode = nil
    }
}