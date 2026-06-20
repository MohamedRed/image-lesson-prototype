import Foundation
import FirebaseFirestore

// MARK: - Episode Models

public struct Episode: Codable, Identifiable {
    public let id: String
    public let title: String
    public let domain: Domain
    public let era: String
    public let summary: String
    public let learningObjectives: [String]
    public let constraints: [String]
    public let mechanics: [MechanicType]
    public let thumbnailURL: String?
    public let duration: Int // minutes
    public let difficulty: Difficulty
    public let published: Bool
    public let version: Int
    
    public enum Domain: String, Codable, CaseIterable {
        case history = "history"
        case science = "science"
        case philosophy = "philosophy"
        case art = "art"
        case law = "law"
        case other = "other"
    }
    
    public enum Difficulty: String, Codable, CaseIterable {
        case beginner = "beginner"
        case intermediate = "intermediate"
        case advanced = "advanced"
    }
}

public struct EpisodeConfig: Codable {
    public let id: String
    public let manifestURL: String
    public let bundles: [AssetBundle]
    public let artifacts: [Artifact]
    public let npcs: [NPCConfig]
    public let scenes: [SceneConfig]
    public let constraints: ConstraintSet
    public let assessment: AssessmentConfig
}

public struct AssetBundle: Codable {
    public let id: String
    public let url: String
    public let type: BundleType
    public let size: Int64
    public let hash: String
    
    public enum BundleType: String, Codable {
        case environment = "environment"
        case characters = "characters"
        case props = "props"
        case audio = "audio"
        case ui = "ui"
    }
}

public struct Artifact: Codable {
    public let id: String
    public let type: ArtifactType
    public let title: String
    public let uri: String
    public let citation: String
    
    public enum ArtifactType: String, Codable {
        case primarySource = "primary_source"
        case secondarySource = "secondary_source"
        case reference = "reference"
    }
}

// MARK: - NPC & Dialogue Models

public struct NPCConfig: Codable {
    public let id: String
    public let name: String
    public let persona: String
    public let knowledgeBase: [String] // artifact IDs
    public let allowedTopics: [String]
    public let voiceProfile: String?
}

public struct DialogueContext: Codable {
    public let previousExchanges: [DialogueExchange]
    public let currentScene: String
    public let evidencePresented: [String]
    
    public init(previousExchanges: [DialogueExchange], currentScene: String, evidencePresented: [String]) {
        self.previousExchanges = previousExchanges
        self.currentScene = currentScene
        self.evidencePresented = evidencePresented
    }
    
    public struct DialogueExchange: Codable {
        public let speaker: String
        public let text: String
        public let timestamp: TimeInterval
        
        public init(speaker: String, text: String, timestamp: TimeInterval) {
            self.speaker = speaker
            self.text = text
            self.timestamp = timestamp
        }
    }
}

public struct RAGResponse: Codable {
    public let response: String
    public let citations: [Citation]
    public let confidence: Double
    public let contested: Bool

    // Public initializer for cross-module construction
    public init(response: String, citations: [Citation], confidence: Double, contested: Bool) {
        self.response = response
        self.citations = citations
        self.confidence = confidence
        self.contested = contested
    }
}

public struct Citation: Codable {
    public let source: String
    public let text: String
    public let confidence: Double
    public let page: String?
    
    init?(from dict: [String: Any]) {
        guard let source = dict["source"] as? String,
              let text = dict["text"] as? String else { return nil }
        
        self.source = source
        self.text = text
        self.confidence = dict["confidence"] as? Double ?? 0.5
        self.page = dict["page"] as? String
    }
}

// MARK: - Scene & Mechanics Models

public struct SceneConfig: Codable {
    public let id: String
    public let environment: String
    public let goals: [String]
    public let beats: [SceneBeat]
    public let failStates: [String]
}

public struct SceneBeat: Codable {
    public let id: String
    public let mechanic: MechanicType
    public let evidence: [String]
    public let constraints: [String]
}

public enum MechanicType: String, Codable, CaseIterable {
    case debateMode = "debate_mode"
    case commandMap = "command_map"
    case experimentBuilder = "experiment_builder"
    case policyBoard = "policy_board"
    case courtroom = "courtroom"
    case fieldwork = "fieldwork"
    case evidenceBoard = "evidence_board"
}

// MARK: - Constraint Models

public struct ConstraintSet: Codable {
    public let techLimits: [String]
    public let legalBounds: [String]
    public let resourceLimits: ResourceLimits
    public let socialNorms: [String]
}

public struct ResourceLimits: Codable {
    public let maxTroops: Int?
    public let maxGold: Int?
    public let maxSupplies: Int?
    public let timeLimit: TimeInterval?
}

// MARK: - Save Data Models

public struct SaveData: Codable {
    public let episodeId: String
    public let checkpoint: String
    public let progress: Double
    public let inventory: [String: Int]
    public let decisions: [Decision]
    public let insightCards: [String]
    public let playTime: TimeInterval
    public let lastPlayedAt: Date

    // Public initializer for cross-module construction
    public init(episodeId: String,
                checkpoint: String,
                progress: Double,
                inventory: [String: Int],
                decisions: [Decision],
                insightCards: [String],
                playTime: TimeInterval,
                lastPlayedAt: Date) {
        self.episodeId = episodeId
        self.checkpoint = checkpoint
        self.progress = progress
        self.inventory = inventory
        self.decisions = decisions
        self.insightCards = insightCards
        self.playTime = playTime
        self.lastPlayedAt = lastPlayedAt
    }
}

public struct Decision: Codable {
    public let id: String
    public let choice: String
    public let timestamp: TimeInterval
    public let effects: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, choice, timestamp, effects
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        choice = try container.decode(String.self, forKey: .choice)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        effects = [:] // Simplified for now
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(choice, forKey: .choice)
        try container.encode(timestamp, forKey: .timestamp)
        // Effects encoding simplified
    }

    // Convenience initializer for programmatic construction (effects optional)
    public init(id: String, choice: String, timestamp: TimeInterval, effects: [String: Any] = [:]) {
        self.id = id
        self.choice = choice
        self.timestamp = timestamp
        self.effects = effects
    }
}

// MARK: - Assessment Models

public struct AssessmentConfig: Codable {
    public let rubrics: [String]
    public let insightCardTemplates: [InsightCardTemplate]
}

public struct InsightCardTemplate: Codable {
    public let id: String
    public let competency: String
    public let prompt: String
    public let triggerCondition: String
}

public struct AssessmentData: Codable {
    public let episodeId: String
    public let completedAt: Date
    public let score: Double
    public let competencyScores: [String: Double]
    public let decisionsAnalysis: [DecisionAnalysis]

    // Public initializer for cross-module construction
    public init(episodeId: String,
                completedAt: Date,
                score: Double,
                competencyScores: [String: Double],
                decisionsAnalysis: [DecisionAnalysis]) {
        self.episodeId = episodeId
        self.completedAt = completedAt
        self.score = score
        self.competencyScores = competencyScores
        self.decisionsAnalysis = decisionsAnalysis
    }
}

// Public memberwise initializer for cross-module construction
// (Removed duplicate extension initializer that conflicted with the struct initializer)

public struct DecisionAnalysis: Codable {
    public let decisionId: String
    public let quality: Double
    public let reasoning: String
    public let ethicalConsideration: Bool
    public let evidenceUsed: [String]

    // Public initializer for cross-module construction
    public init(decisionId: String,
                quality: Double,
                reasoning: String,
                ethicalConsideration: Bool,
                evidenceUsed: [String]) {
        self.decisionId = decisionId
        self.quality = quality
        self.reasoning = reasoning
        self.ethicalConsideration = ethicalConsideration
        self.evidenceUsed = evidenceUsed
    }
}

// Public memberwise initializer for cross-module construction
// (Removed duplicate extension initializer that conflicted with the struct initializer)

public struct InsightCards: Codable {
    public let cards: [InsightCard]
    public let generatedAt: Date
}

public struct InsightCard: Codable {
    public let id: String
    public let competency: String
    public let prompt: String
    public let difficulty: Difficulty
    public let nextReviewDate: Date
    
    public enum Difficulty: String, Codable {
        case easy, medium, hard
    }

    // Public initializer for cross-module construction
    public init(id: String,
                competency: String,
                prompt: String,
                difficulty: Difficulty,
                nextReviewDate: Date) {
        self.id = id
        self.competency = competency
        self.prompt = prompt
        self.difficulty = difficulty
        self.nextReviewDate = nextReviewDate
    }
}

// MARK: - Telemetry Models

public struct TelemetryEvent: Codable {
    public let sessionId: String
    public let episodeId: String
    public let timestamp: TimeInterval
    public let type: String
    public let data: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case sessionId, episodeId, timestamp, type, data
    }
    
    public init(sessionId: String, episodeId: String, timestamp: TimeInterval, type: String, data: [String: Any]) {
        self.sessionId = sessionId
        self.episodeId = episodeId
        self.timestamp = timestamp
        self.type = type
        self.data = data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        episodeId = try container.decode(String.self, forKey: .episodeId)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        type = try container.decode(String.self, forKey: .type)
        data = [:] // Simplified
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(episodeId, forKey: .episodeId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(type, forKey: .type)
        // Data encoding simplified
    }
}

// MARK: - Mission Result Models

public struct MissionResult: Codable {
    public let episodeId: String
    public let completed: Bool
    public let score: Double
    public let decisions: [Decision]
    public let playTime: TimeInterval
    
    public init(episodeId: String, completed: Bool, score: Double, decisions: [Decision], playTime: TimeInterval) {
        self.episodeId = episodeId
        self.completed = completed
        self.score = score
        self.decisions = decisions
        self.playTime = playTime
    }
}

// MARK: - Unity Bridge Models

public struct EpisodeAssets {
    public let episodeId: String
    public let manifestURL: URL
    public let bundleURLs: [String: URL]
}

// MARK: - Unity Bridge Protocol

public protocol UnityBridgeProtocol: AnyObject {
    func initialize(sessionToken: String, userId: String)
    func startMission(episodeId: String, assets: EpisodeAssets)
    func pause()
    func resume()
    func requestSave(slot: Int)
    func quit()
    
    // Callbacks from Unity
    var onMissionCompleted: ((MissionResult) -> Void)? { get set }
    var onRAGQueryRequested: ((String, String) async -> RAGResponse)? { get set }
    var onEventsLogged: (([TelemetryEvent]) -> Void)? { get set }
}