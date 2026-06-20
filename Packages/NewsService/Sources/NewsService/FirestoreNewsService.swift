import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import FirebaseCore

public class FirestoreNewsService: NewsServicing {
    private let db: Firestore
    private let functions: Functions
    private let auth: Auth
    
    public init() {
        if FirebaseApp.app() == nil {
            // No-op in mock/demo environment. The first call below would crash otherwise.
            // Consumers should inject MockNewsService in demo mode.
        }
        self.db = Firestore.firestore()
        self.functions = Functions.functions()
        self.auth = Auth.auth()
    }
    
    // MARK: - Event Operations
    
    public func listEvents(filter: NewsFilter, cursor: String?) async throws -> (events: [NewsEventSummary], nextCursor: String?) {
        var query = db.collection("newsEvents")
            .order(by: "lastUpdatedAt", descending: true)
            .limit(to: filter.limit)
        
        if let goodness = filter.goodness, goodness != .all {
            query = query.whereField("goodness", isEqualTo: goodness.rawValue)
        }
        
        if let region = filter.region {
            query = query.whereField("regions", arrayContains: region)
        }
        
        if let tags = filter.tags, !tags.isEmpty {
            for tag in tags.prefix(1) {
                query = query.whereField("tags", arrayContains: tag)
            }
        }
        
        if let cursor = cursor {
            let lastDoc = try await db.collection("newsEvents").document(cursor).getDocument()
            query = query.start(afterDocument: lastDoc)
        }
        
        let snapshot = try await query.getDocuments()
        
        let events = snapshot.documents.compactMap { doc -> NewsEventSummary? in
            parseEventSummary(from: doc)
        }
        
        let nextCursor = snapshot.documents.last?.documentID
        
        return (events, nextCursor)
    }
    
    public func getEvent(id: String) async throws -> NewsEventDetail {
        let doc = try await db.collection("newsEvents").document(id).getDocument()
        
        guard let data = doc.data() else {
            throw NewsServiceError.eventNotFound
        }
        
        return parseEventDetail(from: doc)
    }
    
    // MARK: - Article Operations
    
    public func listArticles(eventId: String, cursor: String?) async throws -> (articles: [NewsArticle], nextCursor: String?) {
        var query = db.collection("newsEvents").document(eventId)
            .collection("articles")
            .order(by: "publishedAt", descending: true)
            .limit(to: 20)
        
        if let cursor = cursor {
            let lastDoc = try await db.collection("newsEvents").document(eventId)
                .collection("articles").document(cursor).getDocument()
            query = query.start(afterDocument: lastDoc)
        }
        
        let snapshot = try await query.getDocuments()
        
        let articles = snapshot.documents.compactMap { doc -> NewsArticle? in
            parseArticle(from: doc)
        }
        
        let nextCursor = snapshot.documents.last?.documentID
        
        return (articles, nextCursor)
    }
    
    // MARK: - Comment Operations
    
    public func listComments(parentCollection: String, parentId: String) async throws -> [NewsComment] {
        let snapshot = try await db.collection(parentCollection).document(parentId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            parseComment(from: doc)
        }
    }
    
    public func getCommentSummary(parentCollection: String, parentId: String) async throws -> [CommentCluster]? {
        let doc = try await db.collection(parentCollection).document(parentId).getDocument()
        
        guard let data = doc.data(),
              let summaryData = data["commentSummary"] as? [[String: Any]] else {
            return nil
        }
        
        return summaryData.compactMap { clusterData in
            guard let id = clusterData["id"] as? String,
                  let label = clusterData["label"] as? String,
                  let count = clusterData["count"] as? Int else { return nil }
            
            return CommentCluster(
                id: id,
                label: label,
                count: count,
                sentiment: clusterData["sentiment"] as? String
            )
        }
    }
    
    public func postComment(parentCollection: String, parentId: String, text: String, replyTo: String?) async throws -> String {
        guard let user = auth.currentUser else {
            throw NewsServiceError.notAuthenticated
        }
        
        let callable = functions.httpsCallable("submitComment")
        let result = try await callable.call([
            "parentCollection": parentCollection,
            "parentId": parentId,
            "text": text,
            "replyTo": replyTo as Any
        ])
        
        guard let data = result.data as? [String: Any],
              let commentId = data["commentId"] as? String else {
            throw NewsServiceError.invalidResponse
        }
        
        return commentId
    }
    
    public func reactToComment(parentCollection: String, parentId: String, commentId: String, value: Int) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NewsServiceError.notAuthenticated
        }
        
        let reactionRef = db.collection(parentCollection).document(parentId)
            .collection("comments").document(commentId)
            .collection("reactions").document(userId)
        
        if value == 0 {
            try await reactionRef.delete()
        } else {
            try await reactionRef.setData([
                "value": value,
                "timestamp": FieldValue.serverTimestamp()
            ])
        }
        
        let commentRef = db.collection(parentCollection).document(parentId)
            .collection("comments").document(commentId)
        
        try await db.runTransaction { transaction, errorPointer in
            let doc: DocumentSnapshot
            do {
                doc = try transaction.getDocument(commentRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            
            var reactionCounts = doc.data()?["reactionCounts"] as? [String: Int] ?? [:]
            
            let currentReaction = try? transaction.getDocument(reactionRef).data()?["value"] as? Int
            
            if let current = currentReaction {
                if current == 1 {
                    reactionCounts["like"] = max(0, (reactionCounts["like"] ?? 0) - 1)
                } else if current == -1 {
                    reactionCounts["dislike"] = max(0, (reactionCounts["dislike"] ?? 0) - 1)
                }
            }
            
            if value == 1 {
                reactionCounts["like"] = (reactionCounts["like"] ?? 0) + 1
            } else if value == -1 {
                reactionCounts["dislike"] = (reactionCounts["dislike"] ?? 0) + 1
            }
            
            transaction.updateData(["reactionCounts": reactionCounts], forDocument: commentRef)
            return nil
        }
    }
    
    public func deleteComment(parentCollection: String, parentId: String, commentId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NewsServiceError.notAuthenticated
        }
        
        let commentRef = db.collection(parentCollection).document(parentId)
            .collection("comments").document(commentId)
        
        let doc = try await commentRef.getDocument()
        
        guard let data = doc.data(),
              let authorUid = data["authorUid"] as? String,
              authorUid == userId else {
            throw NewsServiceError.unauthorized
        }
        
        try await commentRef.delete()
    }
    
    // MARK: - Parsing Helpers
    
    private func parseEventSummary(from doc: DocumentSnapshot) -> NewsEventSummary? {
        guard let data = doc.data() else { return nil }
        
        let perspectives = (data["perspectives"] as? [[String: Any]] ?? []).compactMap { perspData -> PerspectiveSummary? in
            guard let id = perspData["id"] as? String,
                  let label = perspData["label"] as? String else { return nil }
            return PerspectiveSummary(id: id, label: label)
        }
        
        return NewsEventSummary(
            id: doc.documentID,
            title: data["title"] as? String ?? "",
            topicKey: data["topicKey"] as? String ?? "",
            summary: data["summary"] as? String ?? "",
            goodness: data["goodness"] as? String ?? "neutral",
            tags: data["tags"] as? [String] ?? [],
            regions: data["regions"] as? [String] ?? [],
            lastUpdatedAt: (data["lastUpdatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            thumbnailUrl: data["thumbnailUrl"] as? String,
            impact: parseImpact(data["impact"] as? [String: Any]),
            perspectives: perspectives
        )
    }
    
    private func parseEventDetail(from doc: DocumentSnapshot) -> NewsEventDetail {
        let data = doc.data() ?? [:]
        
        return NewsEventDetail(
            id: doc.documentID,
            title: data["title"] as? String ?? "",
            topicKey: data["topicKey"] as? String ?? "",
            clusterId: data["clusterId"] as? String,
            summary: data["summary"] as? String ?? "",
            historicalContext: parseHistoricalContext(data["historicalContext"] as? [String: Any]),
            perspectives: parsePerspectives(data["perspectives"] as? [[String: Any]] ?? []),
            goodness: data["goodness"] as? String ?? "neutral",
            solutions: parseSolutions(data["solutions"] as? [[String: Any]] ?? []),
            impact: parseImpact(data["impact"] as? [String: Any]),
            tags: data["tags"] as? [String] ?? [],
            regions: data["regions"] as? [String] ?? [],
            languages: data["languages"] as? [String] ?? [],
            firstSeenAt: (data["firstSeenAt"] as? Timestamp)?.dateValue() ?? Date(),
            lastUpdatedAt: (data["lastUpdatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            provenance: parseProvenance(data["provenance"] as? [String: Any])
        )
    }
    
    private func parseHistoricalContext(_ data: [String: Any]?) -> HistoricalContext? {
        guard let data = data else { return nil }
        
        return HistoricalContext(
            text: data["text"] as? String ?? "",
            citations: parseCitations(data["citations"] as? [[String: Any]] ?? []),
            generatedAt: (data["generatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            model: data["model"] as? String,
            confidence: data["confidence"] as? Double
        )
    }
    
    private func parsePerspectives(_ data: [[String: Any]]) -> [NewsPerspective] {
        return data.compactMap { perspData in
            guard let id = perspData["id"] as? String,
                  let label = perspData["label"] as? String,
                  let summary = perspData["summary"] as? String else { return nil }
            
            return NewsPerspective(
                id: id,
                label: label,
                axes: parsePerspectiveAxes(perspData["axes"] as? [String: Any]),
                summary: summary,
                citations: parseCitations(perspData["citations"] as? [[String: Any]] ?? []),
                confidence: perspData["confidence"] as? Double
            )
        }
    }
    
    private func parsePerspectiveAxes(_ data: [String: Any]?) -> PerspectiveAxes? {
        guard let data = data else { return nil }
        
        return PerspectiveAxes(
            geography: data["geography"] as? String,
            ideology: data["ideology"] as? String,
            stakeholder: data["stakeholder"] as? String
        )
    }
    
    private func parseCitations(_ data: [[String: Any]]) -> [Citation] {
        return data.compactMap { citData in
            guard let title = citData["title"] as? String,
                  let url = citData["url"] as? String else { return nil }
            return Citation(title: title, url: url)
        }
    }
    
    private func parseSolutions(_ data: [[String: Any]]) -> [NewsSolution] {
        return data.compactMap { solData in
            guard let title = solData["title"] as? String,
                  let description = solData["description"] as? String else { return nil }
            
            return NewsSolution(
                title: title,
                description: description,
                feasibility: solData["feasibility"] as? String,
                citations: parseCitations(solData["citations"] as? [[String: Any]] ?? [])
            )
        }
    }
    
    private func parseImpact(_ data: [String: Any]?) -> NewsImpact? {
        guard let data = data else { return nil }
        
        return NewsImpact(
            peopleAffected: data["peopleAffected"] as? Int,
            regions: data["regions"] as? [String],
            domains: data["domains"] as? [String]
        )
    }
    
    private func parseProvenance(_ data: [String: Any]?) -> NewsProvenance? {
        guard let data = data else { return nil }
        
        return NewsProvenance(
            connectors: data["connectors"] as? [String] ?? [],
            method: data["method"] as? String ?? "",
            safetyNotes: data["safetyNotes"] as? String
        )
    }
    
    private func parseArticle(from doc: DocumentSnapshot) -> NewsArticle? {
        guard let data = doc.data() else { return nil }
        
        return NewsArticle(
            id: doc.documentID,
            sourceId: data["sourceId"] as? String,
            sourceName: data["sourceName"] as? String ?? "",
            author: data["author"] as? String,
            title: data["title"] as? String ?? "",
            url: data["url"] as? String ?? "",
            publishedAt: (data["publishedAt"] as? Timestamp)?.dateValue() ?? Date(),
            language: data["language"] as? String,
            country: data["country"] as? String,
            imageUrl: data["imageUrl"] as? String,
            summary: data["summary"] as? String,
            biasLabels: data["biasLabels"] as? [String],
            canonicalFingerprint: data["canonicalFingerprint"] as? String,
            dedupeGroup: data["dedupeGroup"] as? String
        )
    }
    
    private func parseComment(from doc: DocumentSnapshot) -> NewsComment? {
        guard let data = doc.data() else { return nil }
        
        return NewsComment(
            id: doc.documentID,
            authorUid: data["authorUid"] as? String ?? "",
            authorName: data["authorName"] as? String ?? "Anonymous",
            text: data["text"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            sentiment: data["sentiment"] as? String,
            clusterId: data["clusterId"] as? String,
            replyTo: data["replyTo"] as? String,
            reactionCounts: parseReactionCounts(data["reactionCounts"] as? [String: Any]),
            flags: data["flags"] as? [String: Bool]
        )
    }
    
    private func parseReactionCounts(_ data: [String: Any]?) -> ReactionCounts? {
        guard let data = data else { return nil }
        return ReactionCounts(
            like: data["like"] as? Int ?? 0,
            dislike: data["dislike"] as? Int ?? 0
        )
    }
}

public enum NewsServiceError: LocalizedError {
    case eventNotFound
    case notAuthenticated
    case unauthorized
    case invalidResponse
    
    public var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return "News event not found"
        case .notAuthenticated:
            return "User not authenticated"
        case .unauthorized:
            return "Unauthorized operation"
        case .invalidResponse:
            return "Invalid server response"
        }
    }
}