import Foundation

public class MockNewsService: NewsServicing {
    
    public init() {}
    
    public func listEvents(filter: NewsFilter, cursor: String?) async throws -> (events: [NewsEventSummary], nextCursor: String?) {
        let mockEvents = createMockEvents(filter: filter)
        
        if let cursor = cursor {
            return ([], nil)
        }
        
        return (mockEvents, mockEvents.isEmpty ? nil : "mock_cursor")
    }
    
    public func getEvent(id: String) async throws -> NewsEventDetail {
        return createMockEventDetail(id: id)
    }
    
    public func listArticles(eventId: String, cursor: String?) async throws -> (articles: [NewsArticle], nextCursor: String?) {
        let mockArticles = createMockArticles()
        
        if let cursor = cursor {
            return ([], nil)
        }
        
        return (mockArticles, nil)
    }
    
    public func listComments(parentCollection: String, parentId: String) async throws -> [NewsComment] {
        return createMockComments()
    }
    
    public func getCommentSummary(parentCollection: String, parentId: String) async throws -> [CommentCluster]? {
        return [
            CommentCluster(id: "1", label: "Support the initiative", count: 45, sentiment: "positive"),
            CommentCluster(id: "2", label: "Concerned about implementation", count: 23, sentiment: "neutral"),
            CommentCluster(id: "3", label: "Oppose the proposal", count: 12, sentiment: "negative")
        ]
    }
    
    public func postComment(parentCollection: String, parentId: String, text: String, replyTo: String?) async throws -> String {
        return UUID().uuidString
    }
    
    public func reactToComment(parentCollection: String, parentId: String, commentId: String, value: Int) async throws {
        // Mock implementation - no op
    }
    
    public func deleteComment(parentCollection: String, parentId: String, commentId: String) async throws {
        // Mock implementation - no op
    }
    
    // MARK: - Mock Data Creation
    
    private func createMockEvents(filter: NewsFilter) -> [NewsEventSummary] {
        let goodEvents = [
            NewsEventSummary(
                id: "mock_good_1",
                title: "Breakthrough in Renewable Energy Storage",
                topicKey: "renewable-energy-breakthrough",
                summary: "Scientists develop new battery technology that could store renewable energy for weeks, making solar and wind power more reliable.",
                goodness: "good",
                tags: ["Technology", "Environment", "Science"],
                regions: ["Global"],
                lastUpdatedAt: Date().addingTimeInterval(-3600),
                thumbnailUrl: nil,
                impact: NewsImpact(peopleAffected: 1000000, regions: ["North America", "Europe"], domains: ["Energy"]),
                perspectives: [
                    PerspectiveSummary(id: "1", label: "Industry"),
                    PerspectiveSummary(id: "2", label: "Environmental Groups"),
                    PerspectiveSummary(id: "3", label: "Government")
                ]
            ),
            NewsEventSummary(
                id: "mock_good_2",
                title: "Global Literacy Rates Reach Historic High",
                topicKey: "global-literacy-milestone",
                summary: "UNESCO reports that global literacy rates have reached 87%, the highest in human history, with significant gains in Sub-Saharan Africa.",
                goodness: "good",
                tags: ["Education", "Society", "Development"],
                regions: ["Global", "Africa"],
                lastUpdatedAt: Date().addingTimeInterval(-7200),
                thumbnailUrl: nil,
                impact: NewsImpact(peopleAffected: 500000000, regions: ["Africa", "Asia"], domains: ["Education"]),
                perspectives: [
                    PerspectiveSummary(id: "1", label: "UNESCO"),
                    PerspectiveSummary(id: "2", label: "Local Communities"),
                    PerspectiveSummary(id: "3", label: "Education Experts")
                ]
            )
        ]
        
        let challengingEvents = [
            NewsEventSummary(
                id: "mock_challenging_1",
                title: "Rising Sea Levels Threaten Coastal Cities",
                topicKey: "sea-level-rise-threat",
                summary: "New study shows sea levels rising faster than predicted, putting major coastal cities at risk within the next 30 years.",
                goodness: "challenging",
                tags: ["Environment", "Climate", "Urban"],
                regions: ["Global"],
                lastUpdatedAt: Date().addingTimeInterval(-1800),
                thumbnailUrl: nil,
                impact: NewsImpact(peopleAffected: 600000000, regions: ["Asia", "Americas"], domains: ["Environment", "Housing"]),
                perspectives: [
                    PerspectiveSummary(id: "1", label: "Climate Scientists"),
                    PerspectiveSummary(id: "2", label: "Coastal Communities"),
                    PerspectiveSummary(id: "3", label: "Urban Planners")
                ]
            ),
            NewsEventSummary(
                id: "mock_challenging_2",
                title: "Global Food Security Concerns Grow",
                topicKey: "food-security-crisis",
                summary: "UN warns of potential food shortages affecting millions as climate change and conflicts disrupt global supply chains.",
                goodness: "challenging",
                tags: ["Food", "Economy", "Climate"],
                regions: ["Global"],
                lastUpdatedAt: Date().addingTimeInterval(-5400),
                thumbnailUrl: nil,
                impact: NewsImpact(peopleAffected: 800000000, regions: ["Africa", "Asia", "Middle East"], domains: ["Agriculture", "Economy"]),
                perspectives: [
                    PerspectiveSummary(id: "1", label: "UN Agencies"),
                    PerspectiveSummary(id: "2", label: "Farmers"),
                    PerspectiveSummary(id: "3", label: "Economic Analysts")
                ]
            )
        ]
        
        switch filter.goodness {
        case .good:
            return goodEvents
        case .challenging:
            return challengingEvents
        case .neutral, .all, nil:
            return goodEvents + challengingEvents
        }
    }
    
    private func createMockEventDetail(id: String) -> NewsEventDetail {
        let isGood = id.contains("good")
        
        return NewsEventDetail(
            id: id,
            title: isGood ? "Breakthrough in Renewable Energy Storage" : "Rising Sea Levels Threaten Coastal Cities",
            topicKey: isGood ? "renewable-energy-breakthrough" : "sea-level-rise-threat",
            clusterId: "cluster_123",
            summary: isGood ?
                "Scientists at MIT have developed a revolutionary new battery technology that could store renewable energy for weeks at a time, potentially solving one of the biggest challenges facing solar and wind power adoption." :
                "A comprehensive new study from the International Panel on Climate Change shows that sea levels are rising 40% faster than previously predicted, putting major coastal cities at significant risk within the next three decades.",
            historicalContext: HistoricalContext(
                text: isGood ?
                    "Energy storage has been a critical challenge for renewable energy adoption since the 1970s. Previous technologies like pumped hydro storage and lithium-ion batteries have limitations in capacity and duration. This breakthrough builds on decades of materials science research and represents a potential paradigm shift in grid-scale energy storage." :
                    "Sea level rise has been documented since the late 19th century, with rates accelerating significantly since the 1990s. The current rate of rise is approximately 3.3mm per year globally, but varies significantly by region. Previous IPCC reports have consistently underestimated the rate of change.",
                citations: [
                    Citation(title: "Historical Energy Storage Methods", url: "https://example.com/energy-history"),
                    Citation(title: "Climate Science Timeline", url: "https://example.com/climate-timeline")
                ],
                generatedAt: Date(),
                model: "GPT-4",
                confidence: 0.85
            ),
            perspectives: [
                NewsPerspective(
                    id: "persp_1",
                    label: "Industry Perspective",
                    axes: PerspectiveAxes(stakeholder: "Industry"),
                    summary: isGood ?
                        "Energy industry leaders see this as a game-changer that could accelerate the transition to renewable energy and create new market opportunities worth billions." :
                        "Coastal development and real estate industries face significant challenges, with trillions in assets at risk. Adaptation measures will require massive investment.",
                    citations: [
                        Citation(title: "Industry Report", url: "https://example.com/industry")
                    ],
                    confidence: 0.82
                ),
                NewsPerspective(
                    id: "persp_2",
                    label: "Environmental Groups",
                    axes: PerspectiveAxes(stakeholder: "NGO"),
                    summary: isGood ?
                        "Environmental advocates celebrate this development but caution that it must be coupled with rapid deployment and policy support to meet climate goals." :
                        "Environmental groups emphasize this as evidence of the urgent need for immediate action on emissions reduction and climate adaptation.",
                    citations: [
                        Citation(title: "NGO Statement", url: "https://example.com/ngo")
                    ],
                    confidence: 0.79
                ),
                NewsPerspective(
                    id: "persp_3",
                    label: "Government Policy",
                    axes: PerspectiveAxes(stakeholder: "Government"),
                    summary: isGood ?
                        "Policymakers see opportunity for energy independence and job creation, but debate continues over subsidies and regulatory frameworks needed for deployment." :
                        "Governments face difficult decisions about coastal defense investments, managed retreat strategies, and support for affected communities.",
                    citations: [
                        Citation(title: "Policy Brief", url: "https://example.com/policy")
                    ],
                    confidence: 0.77
                )
            ],
            goodness: isGood ? "good" : "challenging",
            solutions: isGood ? [] : [
                NewsSolution(
                    title: "Coastal Defense Infrastructure",
                    description: "Build sea walls, storm surge barriers, and improved drainage systems in vulnerable cities.",
                    feasibility: "Medium",
                    citations: [Citation(title: "Engineering Solutions", url: "https://example.com/solutions")]
                ),
                NewsSolution(
                    title: "Managed Retreat Programs",
                    description: "Develop programs to help communities relocate from the most vulnerable coastal areas.",
                    feasibility: "Difficult",
                    citations: [Citation(title: "Relocation Strategies", url: "https://example.com/retreat")]
                ),
                NewsSolution(
                    title: "Natural Barriers Restoration",
                    description: "Restore mangroves, coral reefs, and wetlands that provide natural protection against sea level rise.",
                    feasibility: "High",
                    citations: [Citation(title: "Nature-Based Solutions", url: "https://example.com/nature")]
                )
            ],
            impact: NewsImpact(
                peopleAffected: isGood ? 1000000000 : 600000000,
                regions: ["Global"],
                domains: isGood ? ["Energy", "Technology"] : ["Environment", "Urban Planning"]
            ),
            tags: isGood ? ["Technology", "Environment", "Science"] : ["Environment", "Climate", "Urban"],
            regions: ["Global"],
            languages: ["en"],
            firstSeenAt: Date().addingTimeInterval(-86400),
            lastUpdatedAt: Date().addingTimeInterval(-3600),
            provenance: NewsProvenance(
                connectors: ["NewsAPI", "EventRegistry"],
                method: "llm_enrich_v1",
                safetyNotes: nil
            )
        )
    }
    
    private func createMockArticles() -> [NewsArticle] {
        return [
            NewsArticle(
                id: "article_1",
                sourceName: "MIT Technology Review",
                author: "Jane Smith",
                title: "Revolutionary Battery Could Transform Renewable Energy",
                url: "https://example.com/article1",
                publishedAt: Date().addingTimeInterval(-7200),
                language: "en",
                country: "US",
                summary: "MIT researchers announce breakthrough in long-duration energy storage technology.",
                biasLabels: ["Technology-focused"]
            ),
            NewsArticle(
                id: "article_2",
                sourceName: "The Guardian",
                author: "John Doe",
                title: "New Energy Storage Solution Promises Grid Stability",
                url: "https://example.com/article2",
                publishedAt: Date().addingTimeInterval(-10800),
                language: "en",
                country: "UK",
                summary: "Experts say new battery technology could solve renewable energy's biggest challenge."
            ),
            NewsArticle(
                id: "article_3",
                sourceName: "Reuters",
                title: "Scientists Develop Weeks-Long Battery Storage",
                url: "https://example.com/article3",
                publishedAt: Date().addingTimeInterval(-14400),
                language: "en",
                country: "Global",
                summary: "International team creates battery capable of storing energy for extended periods."
            )
        ]
    }
    
    private func createMockComments() -> [NewsComment] {
        return [
            NewsComment(
                id: "comment_1",
                authorUid: "user_1",
                authorName: "Alice Johnson",
                text: "This is exactly the kind of breakthrough we need to address climate change. Hope it can be scaled quickly!",
                createdAt: Date().addingTimeInterval(-1800),
                sentiment: "positive",
                reactionCounts: ReactionCounts(like: 23, dislike: 2)
            ),
            NewsComment(
                id: "comment_2",
                authorUid: "user_2",
                authorName: "Bob Smith",
                text: "I'm skeptical about the cost. These technologies often sound great but are too expensive for widespread adoption.",
                createdAt: Date().addingTimeInterval(-3600),
                sentiment: "neutral",
                reactionCounts: ReactionCounts(like: 15, dislike: 5)
            ),
            NewsComment(
                id: "comment_3",
                authorUid: "user_3",
                authorName: "Carol Davis",
                text: "As someone working in renewable energy, this could be a game-changer if the efficiency claims hold up.",
                createdAt: Date().addingTimeInterval(-5400),
                sentiment: "positive",
                reactionCounts: ReactionCounts(like: 31, dislike: 1),
                replies: [
                    NewsComment(
                        id: "comment_4",
                        authorUid: "user_4",
                        authorName: "David Wilson",
                        text: "What efficiency levels are they claiming? The article wasn't clear on that.",
                        createdAt: Date().addingTimeInterval(-4800),
                        replyTo: "comment_3",
                        reactionCounts: ReactionCounts(like: 8, dislike: 0)
                    )
                ]
            )
        ]
    }
}