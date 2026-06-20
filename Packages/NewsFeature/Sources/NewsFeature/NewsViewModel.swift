import Foundation
import SwiftUI
import NewsService

@MainActor
class NewsViewModel: ObservableObject {
    @Published var goodNews: [NewsEventSummary] = []
    @Published var challengingNews: [NewsEventSummary] = []
    @Published var isLoadingGood = false
    @Published var isLoadingChallenging = false
    @Published var error: String?
    @Published var showingSettings = false
    
    @Published var selectedRegion: String?
    @Published var selectedTags: Set<String> = []
    
    private let service: NewsServicing
    private var goodNewsCursor: String?
    private var challengingNewsCursor: String?
    
    init(service: NewsServicing) {
        self.service = service
    }
    
    func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadGoodNews() }
            group.addTask { await self.loadChallengingNews() }
        }
    }
    
    func loadGoodNews() async {
        isLoadingGood = true
        error = nil
        
        do {
            let filter = NewsFilter(
                goodness: .good,
                region: selectedRegion,
                tags: Array(selectedTags),
                limit: 20
            )
            
            let (events, cursor) = try await service.listEvents(filter: filter, cursor: nil)
            goodNews = events
            goodNewsCursor = cursor
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoadingGood = false
    }
    
    func loadMoreGoodNews() async {
        guard !isLoadingGood, let cursor = goodNewsCursor else { return }
        
        isLoadingGood = true
        
        do {
            let filter = NewsFilter(
                goodness: .good,
                region: selectedRegion,
                tags: Array(selectedTags),
                limit: 20
            )
            
            let (events, nextCursor) = try await service.listEvents(filter: filter, cursor: cursor)
            goodNews.append(contentsOf: events)
            goodNewsCursor = nextCursor
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoadingGood = false
    }
    
    func loadChallengingNews() async {
        isLoadingChallenging = true
        error = nil
        
        do {
            let filter = NewsFilter(
                goodness: .challenging,
                region: selectedRegion,
                tags: Array(selectedTags),
                limit: 20
            )
            
            let (events, cursor) = try await service.listEvents(filter: filter, cursor: nil)
            challengingNews = events
            challengingNewsCursor = cursor
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoadingChallenging = false
    }
    
    func loadMoreChallengingNews() async {
        guard !isLoadingChallenging, let cursor = challengingNewsCursor else { return }
        
        isLoadingChallenging = true
        
        do {
            let filter = NewsFilter(
                goodness: .challenging,
                region: selectedRegion,
                tags: Array(selectedTags),
                limit: 20
            )
            
            let (events, nextCursor) = try await service.listEvents(filter: filter, cursor: cursor)
            challengingNews.append(contentsOf: events)
            challengingNewsCursor = nextCursor
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoadingChallenging = false
    }
    
    func applyFilters() async {
        goodNews.removeAll()
        challengingNews.removeAll()
        goodNewsCursor = nil
        challengingNewsCursor = nil
        await loadInitialData()
    }
}