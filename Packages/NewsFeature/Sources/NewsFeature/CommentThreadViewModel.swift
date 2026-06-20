import Foundation
import SwiftUI
import NewsService
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore

@MainActor
public class CommentThreadViewModel: ObservableObject {
    @Published var comments: [NewsComment] = []
    @Published var commentSummary: [CommentCluster]?
    @Published var isLoading = false
    @Published var isPosting = false
    @Published var error: String?
    
    let parentCollection: String
    let parentId: String
    let currentUserId: String?
    
    private let service: NewsServicing
    private var listener: ListenerRegistration?
    
    public init(parentCollection: String, parentId: String, service: NewsServicing? = nil) {
        self.parentCollection = parentCollection
        self.parentId = parentId
        self.service = service ?? FirestoreNewsService()
        if FirebaseApp.app() != nil {
            self.currentUserId = Auth.auth().currentUser?.uid
        } else {
            self.currentUserId = nil
        }
        setupListenerIfPossible()
    }
    
    deinit {
        listener?.remove()
    }
    
    private func setupListenerIfPossible() {
        guard FirebaseApp.app() != nil, !(service is MockNewsService) else {
            return
        }
        let db = Firestore.firestore()
        listener = db.collection(parentCollection)
            .document(parentId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.error = error.localizedDescription
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.comments = documents.compactMap { doc in
                        self.parseComment(from: doc)
                    }
                    self.organizeCommentThreads()
                }
            }
    }
    
    private func parseComment(from document: DocumentSnapshot) -> NewsComment? {
        guard let data = document.data() else { return nil }
        
        return NewsComment(
            id: document.documentID,
            authorUid: data["authorUid"] as? String ?? "",
            authorName: data["authorName"] as? String ?? "Anonymous",
            text: data["text"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            sentiment: data["sentiment"] as? String,
            clusterId: data["clusterId"] as? String,
            replyTo: data["replyTo"] as? String,
            reactionCounts: parseReactionCounts(data["reactionCounts"] as? [String: Any]),
            flags: data["flags"] as? [String: Bool],
            userReaction: nil,
            replies: nil
        )
    }
    
    private func parseReactionCounts(_ data: [String: Any]?) -> ReactionCounts? {
        guard let data = data else { return nil }
        return ReactionCounts(
            like: data["like"] as? Int ?? 0,
            dislike: data["dislike"] as? Int ?? 0
        )
    }
    
    private func organizeCommentThreads() {
        var rootComments: [NewsComment] = []
        var repliesMap: [String: [NewsComment]] = [:]
        
        for comment in comments {
            if let replyTo = comment.replyTo {
                repliesMap[replyTo, default: []].append(comment)
            } else {
                rootComments.append(comment)
            }
        }
        
        comments = rootComments.map { comment in
            var updatedComment = comment
            updatedComment.replies = repliesMap[comment.id]
            return updatedComment
        }
        
        loadUserReactions()
    }
    
    private func loadUserReactions() {
        guard let userId = currentUserId else { return }
        
        Task {
            let db = Firestore.firestore()
            
            for i in comments.indices {
                let commentId = comments[i].id
                let reactionDoc = try? await db.collection(parentCollection)
                    .document(parentId)
                    .collection("comments")
                    .document(commentId)
                    .collection("reactions")
                    .document(userId)
                    .getDocument()
                
                if let data = reactionDoc?.data(),
                   let value = data["value"] as? Int {
                    comments[i].userReaction = value
                }
            }
        }
    }
    
    func loadComments() async {
        isLoading = true
        error = nil
        
        do {
            comments = try await service.listComments(
                parentCollection: parentCollection,
                parentId: parentId
            )
            organizeCommentThreads()
            
            if let summary = try? await service.getCommentSummary(
                parentCollection: parentCollection,
                parentId: parentId
            ) {
                commentSummary = summary
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func postComment(text: String, replyTo: String?) async {
        isPosting = true
        error = nil
        
        do {
            _ = try await service.postComment(
                parentCollection: parentCollection,
                parentId: parentId,
                text: text,
                replyTo: replyTo
            )
        } catch {
            self.error = error.localizedDescription
        }
        
        isPosting = false
    }
    
    func reactToComment(_ commentId: String, value: Int) async {
        do {
            try await service.reactToComment(
                parentCollection: parentCollection,
                parentId: parentId,
                commentId: commentId,
                value: value
            )
            
            if let index = comments.firstIndex(where: { $0.id == commentId }) {
                comments[index].userReaction = value
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteComment(_ commentId: String) async {
        do {
            try await service.deleteComment(
                parentCollection: parentCollection,
                parentId: parentId,
                commentId: commentId
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}