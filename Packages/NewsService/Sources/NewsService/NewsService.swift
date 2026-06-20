import Foundation

public protocol NewsServicing {
    // Event operations
    func listEvents(filter: NewsFilter, cursor: String?) async throws -> (events: [NewsEventSummary], nextCursor: String?)
    func getEvent(id: String) async throws -> NewsEventDetail
    
    // Article operations
    func listArticles(eventId: String, cursor: String?) async throws -> (articles: [NewsArticle], nextCursor: String?)
    
    // Comment operations
    func listComments(parentCollection: String, parentId: String) async throws -> [NewsComment]
    func getCommentSummary(parentCollection: String, parentId: String) async throws -> [CommentCluster]?
    func postComment(parentCollection: String, parentId: String, text: String, replyTo: String?) async throws -> String
    func reactToComment(parentCollection: String, parentId: String, commentId: String, value: Int) async throws
    func deleteComment(parentCollection: String, parentId: String, commentId: String) async throws
}