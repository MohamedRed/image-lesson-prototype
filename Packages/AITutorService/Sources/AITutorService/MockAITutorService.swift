import Foundation
import Combine

public final class MockAITutorService: AITutorServicing {
    public var unityBridge: UnityBridgeProtocol?
    
    public init() {
        // Initialize with mock Unity bridge
        self.unityBridge = MockUnityBridge()
    }
    
    // MARK: - Episode Management
    
    public func listEpisodes() async throws -> [Episode] {
        return [
            Episode(
                id: "omar_jerusalem",
                title: "Omar Enters Jerusalem",
                domain: .history,
                era: "7th Century CE",
                summary: "Experience the historic entry of Omar ibn al-Khattab into Jerusalem. Navigate diplomacy, establish governance, and make decisions that shaped history.",
                learningObjectives: [
                    "Understand historical context of Jerusalem's surrender",
                    "Practice diplomatic negotiation",
                    "Analyze leadership under constraints"
                ],
                constraints: ["era_technology", "religious_law", "resource_scarcity"],
                mechanics: [.debateMode, .commandMap, .policyBoard],
                thumbnailURL: "https://example.com/omar_thumb.jpg",
                duration: 25,
                difficulty: .intermediate,
                published: true,
                version: 1
            ),
            Episode(
                id: "john_snow_cholera",
                title: "John Snow & the Broad Street Pump",
                domain: .science,
                era: "Victorian London, 1854",
                summary: "Investigate the cholera outbreak as Dr. John Snow. Collect data, challenge prevailing theories, and prove the waterborne transmission of disease.",
                learningObjectives: [
                    "Apply scientific method to epidemiology",
                    "Challenge established doctrine with evidence",
                    "Understand public health emergence"
                ],
                constraints: ["victorian_tech", "medical_knowledge", "social_resistance"],
                mechanics: [.fieldwork, .experimentBuilder, .evidenceBoard],
                thumbnailURL: "https://example.com/snow_thumb.jpg",
                duration: 30,
                difficulty: .intermediate,
                published: true,
                version: 1
            ),
            Episode(
                id: "socrates_trial",
                title: "Trial of Socrates",
                domain: .philosophy,
                era: "Athens, 399 BCE",
                summary: "Defend Socrates in his trial for impiety and corrupting youth. Use logic, rhetoric, and philosophy to argue before the Athenian jury.",
                learningObjectives: [
                    "Practice philosophical argumentation",
                    "Understand Athenian democracy and law",
                    "Explore ethics of civil disobedience"
                ],
                constraints: ["athenian_law", "jury_sentiment", "political_climate"],
                mechanics: [.courtroom, .debateMode, .evidenceBoard],
                thumbnailURL: "https://example.com/socrates_thumb.jpg",
                duration: 35,
                difficulty: .advanced,
                published: true,
                version: 1
            )
        ]
    }
    
    public func getEpisodeConfig(episodeId: String) async throws -> EpisodeConfig {
        // Return mock config for omar_jerusalem episode
        return EpisodeConfig(
            id: episodeId,
            manifestURL: "https://example.com/episodes/\(episodeId)/manifest.json",
            bundles: [
                AssetBundle(
                    id: "env_jerusalem",
                    url: "https://example.com/bundles/env_jerusalem.bundle",
                    type: .environment,
                    size: 52428800, // 50MB
                    hash: "abc123"
                ),
                AssetBundle(
                    id: "chars_omar",
                    url: "https://example.com/bundles/chars_omar.bundle",
                    type: .characters,
                    size: 31457280, // 30MB
                    hash: "def456"
                )
            ],
            artifacts: [
                Artifact(
                    id: "tabari_history",
                    type: .primarySource,
                    title: "History of al-Tabari",
                    uri: "gs://sources/tabari.pdf",
                    citation: "al-Tabari, The History of al-Tabari Vol. 12, SUNY Press, 1991"
                ),
                Artifact(
                    id: "covenant_omar",
                    type: .primarySource,
                    title: "Covenant of Omar",
                    uri: "gs://sources/covenant.pdf",
                    citation: "The Covenant of Omar, 637 CE, Multiple attestations"
                )
            ],
            npcs: [
                NPCConfig(
                    id: "patriarch_sophronius",
                    name: "Patriarch Sophronius",
                    persona: "Dignified, cautious, protective of Christian sites",
                    knowledgeBase: ["tabari_history", "covenant_omar"],
                    allowedTopics: ["terms", "sanctity", "governance"],
                    voiceProfile: "elder_male_formal"
                ),
                NPCConfig(
                    id: "commander_khalid",
                    name: "Khalid ibn al-Walid",
                    persona: "Strategic, direct, focused on military security",
                    knowledgeBase: ["tabari_history"],
                    allowedTopics: ["military", "logistics", "security"],
                    voiceProfile: "adult_male_commanding"
                )
            ],
            scenes: [
                SceneConfig(
                    id: "city_gates",
                    environment: "jerusalem_gates",
                    goals: ["Establish initial terms", "Build trust"],
                    beats: [
                        SceneBeat(
                            id: "negotiation",
                            mechanic: .debateMode,
                            evidence: ["tabari_history"],
                            constraints: ["diplomatic_protocol"]
                        )
                    ],
                    failStates: ["violence_erupts", "negotiation_breakdown"]
                ),
                SceneConfig(
                    id: "holy_sepulchre",
                    environment: "church_interior",
                    goals: ["Respect sanctity", "Set precedent"],
                    beats: [
                        SceneBeat(
                            id: "prayer_decision",
                            mechanic: .policyBoard,
                            evidence: ["covenant_omar"],
                            constraints: ["religious_law", "political_wisdom"]
                        )
                    ],
                    failStates: ["desecration", "precedent_conflict"]
                )
            ],
            constraints: ConstraintSet(
                techLimits: ["no_gunpowder", "no_printing", "medieval_siege"],
                legalBounds: ["islamic_law", "byzantine_custom"],
                resourceLimits: ResourceLimits(
                    maxTroops: 4000,
                    maxGold: 10000,
                    maxSupplies: 30,
                    timeLimit: nil
                ),
                socialNorms: ["honor_code", "religious_respect", "tribal_loyalty"]
            ),
            assessment: AssessmentConfig(
                rubrics: ["evidence_use", "ethical_reasoning", "constraint_respect"],
                insightCardTemplates: [
                    InsightCardTemplate(
                        id: "sanctity_principle",
                        competency: "religious_tolerance",
                        prompt: "How did respecting holy sites affect governance?",
                        triggerCondition: "completed_holy_sepulchre"
                    ),
                    InsightCardTemplate(
                        id: "power_restraint",
                        competency: "ethical_leadership",
                        prompt: "When is restraint more powerful than force?",
                        triggerCondition: "avoided_violence"
                    )
                ]
            )
        )
    }
    
    public func downloadEpisodeAssets(episodeId: String) async throws -> EpisodeAssets {
        // Simulate download delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        return EpisodeAssets(
            episodeId: episodeId,
            manifestURL: documentsPath.appendingPathComponent("manifest.json"),
            bundleURLs: [
                "env_jerusalem": documentsPath.appendingPathComponent("env.bundle"),
                "chars_omar": documentsPath.appendingPathComponent("chars.bundle")
            ]
        )
    }
    
    // MARK: - RAG & Dialogue
    
    public func queryRAG(episodeId: String, npcId: String, prompt: String, context: DialogueContext?) async throws -> RAGResponse {
        // Simulate RAG response based on NPC
        if npcId == "patriarch_sophronius" {
            return RAGResponse(
                response: "We seek assurances that our holy places will be protected and our people treated justly under your governance.",
                citations: [
                    Citation(from: [
                        "source": "al-Tabari",
                        "text": "Sophronius insisted on guarantees for Christian sites",
                        "confidence": 0.9,
                        "page": "Vol 12, p. 191"
                    ])!
                ],
                confidence: 0.85,
                contested: false
            )
        } else {
            return RAGResponse(
                response: "The military situation is secure. We await your orders on garrison placement.",
                citations: [
                    Citation(from: [
                        "source": "al-Tabari",
                        "text": "The Muslim army maintained discipline during the transition",
                        "confidence": 0.8
                    ])!
                ],
                confidence: 0.75,
                contested: false
            )
        }
    }
    
    // MARK: - Save Management
    
    private var mockSaves: [Int: SaveData] = [:]
    
    public func loadSave(slot: Int) async throws -> SaveData? {
        return mockSaves[slot]
    }
    
    public func saveMission(slot: Int, data: SaveData) async throws {
        mockSaves[slot] = data
    }
    
    public func deleteSave(slot: Int) async throws {
        mockSaves.removeValue(forKey: slot)
    }
    
    // MARK: - Telemetry
    
    public func logEvents(_ events: [TelemetryEvent]) async throws {
        print("Mock: Logged \(events.count) telemetry events")
        for event in events {
            print("  - \(event.type) at \(event.timestamp)")
        }
    }
    
    // MARK: - Assessment
    
    public func submitAssessment(episodeId: String, assessment: AssessmentData) async throws -> InsightCards {
        // Generate mock insight cards based on assessment
        var cards: [InsightCard] = []
        
        if assessment.score < 0.8 {
            cards.append(InsightCard(
                id: UUID().uuidString,
                competency: "evidence_analysis",
                prompt: "How do primary sources shape our understanding of historical events?",
                difficulty: .medium,
                nextReviewDate: Date().addingTimeInterval(86400)
            ))
        }
        
        if assessment.competencyScores["ethical_reasoning"] ?? 0 < 0.7 {
            cards.append(InsightCard(
                id: UUID().uuidString,
                competency: "ethical_reasoning",
                prompt: "What ethical principles guided your decisions?",
                difficulty: .hard,
                nextReviewDate: Date().addingTimeInterval(172800)
            ))
        }
        
        cards.append(InsightCard(
            id: UUID().uuidString,
            competency: "historical_context",
            prompt: "How did the political climate of 637 CE influence the negotiations?",
            difficulty: .easy,
            nextReviewDate: Date().addingTimeInterval(259200)
        ))
        
        return InsightCards(cards: cards, generatedAt: Date())
    }
}

// MissionResult is now defined in AITutorModels.swift