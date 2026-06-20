import Foundation
import SwiftUI
import NewsService

@MainActor
class EventDetailViewModel: ObservableObject {
    @Published var event: NewsEventDetail?
    @Published var articles: [NewsArticle] = []
    @Published var isLoading = false
    @Published var isLoadingArticles = false
    @Published var error: String?
    
    private let eventId: String
    private let service: NewsServicing
    private var articlesCursor: String?
    
    init(eventId: String, service: NewsServicing? = nil) {
        self.eventId = eventId
        self.service = service ?? FirestoreNewsService()
    }
    
    func loadEvent() async {
        isLoading = true
        error = nil
        
        do {
            event = try await service.getEvent(id: eventId)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadArticles() async {
        isLoadingArticles = true
        
        do {
            let (articles, cursor) = try await service.listArticles(eventId: eventId, cursor: nil)
            self.articles = articles
            self.articlesCursor = cursor
        } catch {
            print("Failed to load articles: \(error)")
        }
        
        isLoadingArticles = false
    }
    
    func loadMoreArticles() async {
        guard !isLoadingArticles, let cursor = articlesCursor else { return }
        
        isLoadingArticles = true
        
        do {
            let (newArticles, nextCursor) = try await service.listArticles(eventId: eventId, cursor: cursor)
            articles.append(contentsOf: newArticles)
            articlesCursor = nextCursor
        } catch {
            print("Failed to load more articles: \(error)")
        }
        
        isLoadingArticles = false
    }
}