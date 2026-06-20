import SwiftUI
import NewsService

public struct CommentThreadView: View {
    let parentCollection: String
    let parentId: String
    let title: String
    private let service: NewsServicing?
    
    @StateObject private var viewModel: CommentThreadViewModel
    @State private var newComment = ""
    @State private var replyingTo: NewsComment?
    @Environment(\.dismiss) private var dismiss
    
    public init(parentCollection: String, parentId: String, title: String, service: NewsServicing? = nil) {
        self.parentCollection = parentCollection
        self.parentId = parentId
        self.title = title
        self.service = service
        self._viewModel = StateObject(wrappedValue: CommentThreadViewModel(
            parentCollection: parentCollection,
            parentId: parentId,
            service: service
        ))
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let summary = viewModel.commentSummary, !summary.isEmpty {
                    commentSummaryView(summary)
                }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.comments) { comment in
                                CommentRowView(
                                    comment: comment,
                                    currentUserId: viewModel.currentUserId,
                                    onReply: { replyingTo = comment },
                                    onReact: { value in
                                        Task { await viewModel.reactToComment(comment.id, value: value) }
                                    },
                                    onDelete: {
                                        Task { await viewModel.deleteComment(comment.id) }
                                    }
                                )
                                .id(comment.id)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.loadComments()
                    }
                }
                
                Divider()
                
                commentInputView
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                Task { await viewModel.loadComments() }
            }
        }
    }
    
    private func commentSummaryView(_ clusters: [CommentCluster]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Opinion Summary", systemImage: "chart.pie")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(clusters) { cluster in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cluster.label)
                                .font(.caption2)
                                .fontWeight(.medium)
                            HStack(spacing: 2) {
                                Image(systemName: "person.2")
                                    .font(.caption2)
                                Text("\(cluster.count)")
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    private var commentInputView: some View {
        HStack(spacing: 12) {
            if let replyingTo = replyingTo {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Replying to \(replyingTo.authorName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { self.replyingTo = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            
            HStack {
                TextField("Add a comment...", text: $newComment, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(8)
                
                Button(action: sendComment) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(newComment.isEmpty ? .gray : .accentColor)
                }
                .disabled(newComment.isEmpty || viewModel.isPosting)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private func sendComment() {
        let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        Task {
            await viewModel.postComment(text: text, replyTo: replyingTo?.id)
            newComment = ""
            replyingTo = nil
        }
    }
}

struct CommentRowView: View {
    let comment: NewsComment
    let currentUserId: String?
    let onReply: () -> Void
    let onReact: (Int) -> Void
    let onDelete: () -> Void
    
    @State private var showingActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(comment.authorName.prefix(1).uppercased())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.authorName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• \(formatDate(comment.createdAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if comment.authorUid == currentUserId {
                            Menu {
                                Button(role: .destructive, action: onDelete) {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if let replyTo = comment.replyTo {
                        Text("↳ Reply")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                    
                    Text(comment.text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 16) {
                        Button(action: { onReact(1) }) {
                            HStack(spacing: 4) {
                                Image(systemName: comment.userReaction == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .font(.caption)
                                if let count = comment.reactionCounts?.like, count > 0 {
                                    Text("\(count)")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(comment.userReaction == 1 ? .accentColor : .secondary)
                        }
                        
                        Button(action: { onReact(-1) }) {
                            HStack(spacing: 4) {
                                Image(systemName: comment.userReaction == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                    .font(.caption)
                                if let count = comment.reactionCounts?.dislike, count > 0 {
                                    Text("\(count)")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(comment.userReaction == -1 ? .red : .secondary)
                        }
                        
                        Button(action: onReply) {
                            Label("Reply", systemImage: "arrow.turn.down.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let sentiment = comment.sentiment {
                            sentimentIndicator(sentiment)
                        }
                    }
                }
            }
            
            if let replies = comment.replies, !replies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(replies) { reply in
                        CommentRowView(
                            comment: reply,
                            currentUserId: currentUserId,
                            onReply: onReply,
                            onReact: onReact,
                            onDelete: onDelete
                        )
                        .padding(.leading, 40)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func sentimentIndicator(_ sentiment: String) -> some View {
        let (icon, color) = sentimentIconAndColor(sentiment)
        return Image(systemName: icon)
            .font(.caption2)
            .foregroundColor(color)
    }
    
    private func sentimentIconAndColor(_ sentiment: String) -> (String, Color) {
        switch sentiment.lowercased() {
        case "positive": return ("face.smiling", .green)
        case "negative": return ("face.frowning", .red)
        default: return ("minus.circle", .secondary)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 {
            return "now"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))h"
        } else {
            return "\(Int(diff / 86400))d"
        }
    }
}