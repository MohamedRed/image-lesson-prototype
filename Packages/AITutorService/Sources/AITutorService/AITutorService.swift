import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage

// MARK: - Service Protocol
public protocol AITutorServicing {
    // Episode Management
    func listEpisodes() async throws -> [Episode]
    func getEpisodeConfig(episodeId: String) async throws -> EpisodeConfig
    func downloadEpisodeAssets(episodeId: String) async throws -> EpisodeAssets
    
    // RAG & Dialogue
    func queryRAG(episodeId: String, npcId: String, prompt: String, context: DialogueContext?) async throws -> RAGResponse
    
    // Save Management
    func loadSave(slot: Int) async throws -> SaveData?
    func saveMission(slot: Int, data: SaveData) async throws
    func deleteSave(slot: Int) async throws
    
    // Telemetry
    func logEvents(_ events: [TelemetryEvent]) async throws
    
    // Assessment
    func submitAssessment(episodeId: String, assessment: AssessmentData) async throws -> InsightCards
    
    // Unity Bridge
    var unityBridge: UnityBridgeProtocol? { get set }
}

// MARK: - Main Service Implementation
public final class AITutorService: AITutorServicing {
    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    private let storage = Storage.storage()
    private let auth = Auth.auth()
    
    public var unityBridge: UnityBridgeProtocol?
    
    private var currentUserId: String? {
        auth.currentUser?.uid
    }
    
    public init() {
        // Initialize with mock Unity bridge
        self.unityBridge = MockUnityBridge()
    }
    
    // MARK: - Episode Management
    
    public func listEpisodes() async throws -> [Episode] {
        let snapshot = try await db.collection("aiTutorEpisodes")
            .whereField("published", isEqualTo: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Episode.self)
        }
    }
    
    public func getEpisodeConfig(episodeId: String) async throws -> EpisodeConfig {
        let function = functions.httpsCallable("getEpisodeConfigHttp")
        let result = try await function.call(["episodeId": episodeId])
        
        guard let data = result.data as? [String: Any],
              let configData = try? JSONSerialization.data(withJSONObject: data),
              let config = try? JSONDecoder().decode(EpisodeConfig.self, from: configData) else {
            throw AITutorError.invalidResponse
        }
        
        return config
    }
    
    public func downloadEpisodeAssets(episodeId: String) async throws -> EpisodeAssets {
        let config = try await getEpisodeConfig(episodeId: episodeId)
        
        // Download addressable bundles
        var downloadedAssets: [String: URL] = [:]
        
        for bundle in config.bundles {
            let localURL = try await downloadBundle(from: bundle.url, bundleId: bundle.id)
            downloadedAssets[bundle.id] = localURL
        }
        
        return EpisodeAssets(
            episodeId: episodeId,
            manifestURL: URL(string: config.manifestURL)!,
            bundleURLs: downloadedAssets
        )
    }
    
    // MARK: - RAG & Dialogue
    
    public func queryRAG(episodeId: String, npcId: String, prompt: String, context: DialogueContext?) async throws -> RAGResponse {
        let function = functions.httpsCallable("ragQueryHttp")
        
        var params: [String: Any] = [
            "episodeId": episodeId,
            "npcId": npcId,
            "prompt": prompt
        ]
        
        if let context = context {
            params["context"] = [
                "previousExchanges": context.previousExchanges.map { [
                    "speaker": $0.speaker,
                    "text": $0.text,
                    "timestamp": $0.timestamp
                ]},
                "currentScene": context.currentScene,
                "evidencePresented": context.evidencePresented
            ]
        }
        
        let result = try await function.call(params)
        
        guard let data = result.data as? [String: Any] else {
            throw AITutorError.invalidResponse
        }
        
        return RAGResponse(
            response: data["response"] as? String ?? "",
            citations: (data["citations"] as? [[String: Any]] ?? []).compactMap { Citation(from: $0) },
            confidence: data["confidence"] as? Double ?? 0.5,
            contested: data["contested"] as? Bool ?? false
        )
    }
    
    // MARK: - Save Management
    
    public func loadSave(slot: Int) async throws -> SaveData? {
        guard let userId = currentUserId else {
            throw AITutorError.notAuthenticated
        }
        
        let doc = try await db.collection("aiTutorSaves")
            .document(userId)
            .collection("slots")
            .document("slot_\(slot)")
            .getDocument()
        
        guard doc.exists else { return nil }
        
        return try doc.data(as: SaveData.self)
    }
    
    public func saveMission(slot: Int, data: SaveData) async throws {
        guard let userId = currentUserId else {
            throw AITutorError.notAuthenticated
        }
        
        try await db.collection("aiTutorSaves")
            .document(userId)
            .collection("slots")
            .document("slot_\(slot)")
            .setData(from: data)
    }
    
    public func deleteSave(slot: Int) async throws {
        guard let userId = currentUserId else {
            throw AITutorError.notAuthenticated
        }
        
        try await db.collection("aiTutorSaves")
            .document(userId)
            .collection("slots")
            .document("slot_\(slot)")
            .delete()
    }
    
    // MARK: - Telemetry
    
    public func logEvents(_ events: [TelemetryEvent]) async throws {
        let function = functions.httpsCallable("logTelemetryHttp")
        
        let eventsData = events.map { event in
            [
                "sessionId": event.sessionId,
                "episodeId": event.episodeId,
                "timestamp": event.timestamp,
                "type": event.type,
                "data": event.data
            ]
        }
        
        _ = try await function.call(["events": eventsData])
    }
    
    // MARK: - Assessment
    
    public func submitAssessment(episodeId: String, assessment: AssessmentData) async throws -> InsightCards {
        guard let userId = currentUserId else {
            throw AITutorError.notAuthenticated
        }
        
        // Store assessment
        try await db.collection("aiTutorAssessments")
            .document(userId)
            .collection("episodes")
            .document(episodeId)
            .setData(from: assessment)
        
        // Generate insight cards based on assessment
        return generateInsightCards(from: assessment)
    }
    
    // MARK: - Private Helpers
    
    private func downloadBundle(from urlString: String, bundleId: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw AITutorError.invalidURL
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bundlePath = documentsPath.appendingPathComponent("AITutor/Bundles/\(bundleId)")
        
        // Create directory if needed
        try FileManager.default.createDirectory(at: bundlePath.deletingLastPathComponent(), 
                                               withIntermediateDirectories: true)
        
        // Download file
        let (localURL, _) = try await URLSession.shared.download(from: url)
        try FileManager.default.moveItem(at: localURL, to: bundlePath)
        
        return bundlePath
    }
    
    private func generateInsightCards(from assessment: AssessmentData) -> InsightCards {
        var cards: [InsightCard] = []
        
        // Generate cards based on performance
        for (competency, score) in assessment.competencyScores {
            if score < 0.7 {
                cards.append(InsightCard(
                    id: UUID().uuidString,
                    competency: competency,
                    prompt: "Review: \(competency)",
                    difficulty: .medium,
                    nextReviewDate: Date().addingTimeInterval(86400) // 1 day
                ))
            }
        }
        
        return InsightCards(cards: cards, generatedAt: Date())
    }
}

// MARK: - Error Types
public enum AITutorError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case invalidURL
    case downloadFailed
    case unityNotInitialized
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User must be authenticated"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidURL:
            return "Invalid URL"
        case .downloadFailed:
            return "Failed to download assets"
        case .unityNotInitialized:
            return "Unity framework not initialized"
        }
    }
}