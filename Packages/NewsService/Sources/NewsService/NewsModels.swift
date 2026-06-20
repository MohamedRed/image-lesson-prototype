import Foundation

// MARK: - News Event Models

public struct NewsEventSummary: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let topicKey: String
    public let summary: String
    public let goodness: String
    public let tags: [String]
    public let regions: [String]
    public let lastUpdatedAt: Date
    public let thumbnailUrl: String?
    public let impact: NewsImpact?
    public let perspectives: [PerspectiveSummary]
    
    public init(
        id: String,
        title: String,
        topicKey: String,
        summary: String,
        goodness: String,
        tags: [String],
        regions: [String],
        lastUpdatedAt: Date,
        thumbnailUrl: String? = nil,
        impact: NewsImpact? = nil,
        perspectives: [PerspectiveSummary] = []
    ) {
        self.id = id
        self.title = title
        self.topicKey = topicKey
        self.summary = summary
        self.goodness = goodness
        self.tags = tags
        self.regions = regions
        self.lastUpdatedAt = lastUpdatedAt
        self.thumbnailUrl = thumbnailUrl
        self.impact = impact
        self.perspectives = perspectives
    }
}

public struct PerspectiveSummary: Codable, Hashable {
    public let id: String
    public let label: String
    
    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

public struct NewsEventDetail: Identifiable, Codable {
    public let id: String
    public let title: String
    public let topicKey: String
    public let clusterId: String?
    public let summary: String
    public let historicalContext: HistoricalContext?
    public let perspectives: [NewsPerspective]
    public let goodness: String
    public let solutions: [NewsSolution]
    public let impact: NewsImpact?
    public let tags: [String]
    public let regions: [String]
    public let languages: [String]
    public let firstSeenAt: Date
    public let lastUpdatedAt: Date
    public let provenance: NewsProvenance?
    
    public init(
        id: String,
        title: String,
        topicKey: String,
        clusterId: String? = nil,
        summary: String,
        historicalContext: HistoricalContext? = nil,
        perspectives: [NewsPerspective] = [],
        goodness: String,
        solutions: [NewsSolution] = [],
        impact: NewsImpact? = nil,
        tags: [String],
        regions: [String],
        languages: [String],
        firstSeenAt: Date,
        lastUpdatedAt: Date,
        provenance: NewsProvenance? = nil
    ) {
        self.id = id
        self.title = title
        self.topicKey = topicKey
        self.clusterId = clusterId
        self.summary = summary
        self.historicalContext = historicalContext
        self.perspectives = perspectives
        self.goodness = goodness
        self.solutions = solutions
        self.impact = impact
        self.tags = tags
        self.regions = regions
        self.languages = languages
        self.firstSeenAt = firstSeenAt
        self.lastUpdatedAt = lastUpdatedAt
        self.provenance = provenance
    }
}

public struct HistoricalContext: Codable {
    public let text: String
    public let citations: [Citation]
    public let generatedAt: Date
    public let model: String?
    public let confidence: Double?
    
    public init(
        text: String,
        citations: [Citation],
        generatedAt: Date,
        model: String? = nil,
        confidence: Double? = nil
    ) {
        self.text = text
        self.citations = citations
        self.generatedAt = generatedAt
        self.model = model
        self.confidence = confidence
    }
}

public struct NewsPerspective: Identifiable, Codable {
    public let id: String
    public let label: String
    public let axes: PerspectiveAxes?
    public let summary: String
    public let citations: [Citation]
    public let confidence: Double?
    
    public init(
        id: String,
        label: String,
        axes: PerspectiveAxes? = nil,
        summary: String,
        citations: [Citation],
        confidence: Double? = nil
    ) {
        self.id = id
        self.label = label
        self.axes = axes
        self.summary = summary
        self.citations = citations
        self.confidence = confidence
    }
}

public struct PerspectiveAxes: Codable {
    public let geography: String?
    public let ideology: String?
    public let stakeholder: String?
    
    public init(
        geography: String? = nil,
        ideology: String? = nil,
        stakeholder: String? = nil
    ) {
        self.geography = geography
        self.ideology = ideology
        self.stakeholder = stakeholder
    }
}

public struct Citation: Identifiable, Codable {
    public let id = UUID().uuidString
    public let title: String
    public let url: String
    
    public init(title: String, url: String) {
        self.title = title
        self.url = url
    }
}

public struct NewsSolution: Identifiable, Codable {
    public let id = UUID().uuidString
    public let title: String
    public let description: String
    public let feasibility: String?
    public let citations: [Citation]
    
    public init(
        title: String,
        description: String,
        feasibility: String? = nil,
        citations: [Citation] = []
    ) {
        self.title = title
        self.description = description
        self.feasibility = feasibility
        self.citations = citations
    }
}

public struct NewsImpact: Codable, Hashable {
    public let peopleAffected: Int?
    public let regions: [String]?
    public let domains: [String]?
    
    public init(
        peopleAffected: Int? = nil,
        regions: [String]? = nil,
        domains: [String]? = nil
    ) {
        self.peopleAffected = peopleAffected
        self.regions = regions
        self.domains = domains
    }
}

public struct NewsProvenance: Codable {
    public let connectors: [String]
    public let method: String
    public let safetyNotes: String?
    
    public init(
        connectors: [String],
        method: String,
        safetyNotes: String? = nil
    ) {
        self.connectors = connectors
        self.method = method
        self.safetyNotes = safetyNotes
    }
}

// MARK: - Article Models

public struct NewsArticle: Identifiable, Codable {
    public let id: String
    public let sourceId: String?
    public let sourceName: String
    public let author: String?
    public let title: String
    public let url: String
    public let publishedAt: Date
    public let language: String?
    public let country: String?
    public let imageUrl: String?
    public let summary: String?
    public let biasLabels: [String]?
    public let canonicalFingerprint: String?
    public let dedupeGroup: String?
    
    public init(
        id: String,
        sourceId: String? = nil,
        sourceName: String,
        author: String? = nil,
        title: String,
        url: String,
        publishedAt: Date,
        language: String? = nil,
        country: String? = nil,
        imageUrl: String? = nil,
        summary: String? = nil,
        biasLabels: [String]? = nil,
        canonicalFingerprint: String? = nil,
        dedupeGroup: String? = nil
    ) {
        self.id = id
        self.sourceId = sourceId
        self.sourceName = sourceName
        self.author = author
        self.title = title
        self.url = url
        self.publishedAt = publishedAt
        self.language = language
        self.country = country
        self.imageUrl = imageUrl
        self.summary = summary
        self.biasLabels = biasLabels
        self.canonicalFingerprint = canonicalFingerprint
        self.dedupeGroup = dedupeGroup
    }
}

// MARK: - Comment Models

public struct NewsComment: Identifiable {
    public let id: String
    public let authorUid: String
    public let authorName: String
    public let text: String
    public let createdAt: Date
    public let sentiment: String?
    public let clusterId: String?
    public let replyTo: String?
    public let reactionCounts: ReactionCounts?
    public let flags: [String: Bool]?
    public var userReaction: Int?
    public var replies: [NewsComment]?
    
    public init(
        id: String,
        authorUid: String,
        authorName: String,
        text: String,
        createdAt: Date,
        sentiment: String? = nil,
        clusterId: String? = nil,
        replyTo: String? = nil,
        reactionCounts: ReactionCounts? = nil,
        flags: [String: Bool]? = nil,
        userReaction: Int? = nil,
        replies: [NewsComment]? = nil
    ) {
        self.id = id
        self.authorUid = authorUid
        self.authorName = authorName
        self.text = text
        self.createdAt = createdAt
        self.sentiment = sentiment
        self.clusterId = clusterId
        self.replyTo = replyTo
        self.reactionCounts = reactionCounts
        self.flags = flags
        self.userReaction = userReaction
        self.replies = replies
    }
}

public struct ReactionCounts: Codable {
    public let like: Int
    public let dislike: Int
    
    public init(like: Int = 0, dislike: Int = 0) {
        self.like = like
        self.dislike = dislike
    }
}

public struct CommentCluster: Identifiable, Codable {
    public let id: String
    public let label: String
    public let count: Int
    public let sentiment: String?
    
    public init(
        id: String,
        label: String,
        count: Int,
        sentiment: String? = nil
    ) {
        self.id = id
        self.label = label
        self.count = count
        self.sentiment = sentiment
    }
}

// MARK: - Filter Models

public struct NewsFilter {
    public let goodness: GoodnessFilter?
    public let region: String?
    public let tags: [String]?
    public let limit: Int
    
    public init(
        goodness: GoodnessFilter? = nil,
        region: String? = nil,
        tags: [String]? = nil,
        limit: Int = 20
    ) {
        self.goodness = goodness
        self.region = region
        self.tags = tags
        self.limit = limit
    }
}

public enum GoodnessFilter: String {
    case good = "good"
    case challenging = "challenging"
    case neutral = "neutral"
    case all = "all"
}