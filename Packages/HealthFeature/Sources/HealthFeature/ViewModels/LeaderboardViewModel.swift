import Foundation
import Combine
import HealthService

// MARK: - Leaderboard ViewModel

@MainActor
public class LeaderboardViewModel: ObservableObject {
    @Published public var leaderboard: LeaderboardResponse?
    @Published public var userPosition: LeaderboardEntry?
    @Published public var challenges: [HealthChallenge] = []
    @Published public var selectedBucket: LeaderboardBucket.GeoLevel = .city
    @Published public var selectedCategory: LeaderboardBucket.CompetitionCategory = .overall
    @Published public var isLoading = false
    @Published public var error: String?
    
    private let healthService: HealthService
    private var cancellables = Set<AnyCancellable>()
    
    public init(healthService: HealthService) {
        self.healthService = healthService
    }
    
    public func loadLeaderboard() async {
        isLoading = true
        error = nil
        
        do {
            let leaderboard = try await healthService.getLeaderboard(
                bucket: selectedBucket,
                category: selectedCategory
            ).async()
            
            self.leaderboard = leaderboard
            self.userPosition = leaderboard.userPosition
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func changeBucket(_ bucket: LeaderboardBucket.GeoLevel) async {
        guard bucket != selectedBucket else { return }
        selectedBucket = bucket
        await loadLeaderboard()
    }
    
    public func changeCategory(_ category: LeaderboardBucket.CompetitionCategory) async {
        guard category != selectedCategory else { return }
        selectedCategory = category
        await loadLeaderboard()
    }
    
    public func loadChallenges() async {
        do {
            let challenges = try await healthService.getChallenges().async()
            self.challenges = challenges
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    public func joinChallenge(_ id: String) async {
        do {
            let updatedChallenge = try await healthService.joinChallenge(id).async()
            
            if let index = challenges.firstIndex(where: { $0.id == id }) {
                challenges[index] = updatedChallenge
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Computed Properties
    
    public var userRank: Int? {
        userPosition?.rank
    }
    
    public var userPercentile: Double? {
        userPosition?.percentile
    }
    
    public var topPerformers: [LeaderboardEntry] {
        leaderboard?.entries.prefix(10).map { $0 } ?? []
    }
    
    public var activeChallenges: [HealthChallenge] {
        challenges.filter { $0.status == .active }
    }
    
    public var upcomingChallenges: [HealthChallenge] {
        challenges.filter { $0.status == .upcoming }
    }
}

// MARK: - Professionals ViewModel

@MainActor
public class ProfessionalsViewModel: ObservableObject {
    @Published public var professionals: [HealthProfessional] = []
    @Published public var appointments: [HealthAppointment] = []
    @Published public var searchResults: ProfessionalSearchResponse?
    @Published public var selectedProfessional: HealthProfessional?
    @Published public var isLoading = false
    @Published public var isBookingAppointment = false
    @Published public var error: String?
    
    @Published public var searchFilters = SearchFilters()
    
    public struct SearchFilters {
        public var type: HealthProfessional.ProfessionalType?
        public var specialty: String?
        public var location: String?
        public var telehealthOnly: Bool = false
        
        public init() {}
    }
    
    private let healthService: HealthService
    private var cancellables = Set<AnyCancellable>()
    
    public init(healthService: HealthService) {
        self.healthService = healthService
    }
    
    // MARK: - Professional Search
    
    public func searchProfessionals() async {
        isLoading = true
        error = nil
        
        do {
            let results = try await healthService.searchProfessionals(
                type: searchFilters.type,
                specialty: searchFilters.specialty,
                location: searchFilters.location,
                telehealthOnly: searchFilters.telehealthOnly
            ).async()
            
            self.searchResults = results
            self.professionals = results.professionals
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func loadMoreProfessionals() async {
        guard let nextPageToken = searchResults?.nextPageToken,
              !isLoading else { return }
        
        isLoading = true
        
        do {
            let results = try await healthService.searchProfessionals(
                type: searchFilters.type,
                specialty: searchFilters.specialty,
                location: searchFilters.location,
                telehealthOnly: searchFilters.telehealthOnly,
                pageToken: nextPageToken
            ).async()
            
            // Append new professionals
            self.professionals.append(contentsOf: results.professionals)
            
            // Update search results with new page token
            self.searchResults = ProfessionalSearchResponse(
                professionals: professionals,
                totalCount: results.totalCount,
                hasMore: results.hasMore,
                nextPageToken: results.nextPageToken,
                filters: results.filters
            )
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func getProfessionalDetails(_ id: String) async {
        do {
            let professional = try await healthService.getProfessional(id).async()
            self.selectedProfessional = professional
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Appointments
    
    public func bookAppointment(
        professionalId: String,
        serviceId: String,
        dateTime: Date,
        type: HealthAppointment.AppointmentType,
        notes: String? = nil,
        paymentMethodId: String? = nil
    ) async -> BookAppointmentResponse? {
        isBookingAppointment = true
        error = nil
        
        let request = BookAppointmentRequest(
            professionalId: professionalId,
            serviceId: serviceId,
            dateTime: dateTime,
            type: type,
            notes: notes,
            paymentMethodId: paymentMethodId
        )
        
        do {
            let response = try await healthService.bookAppointment(request).async()
            
            // Add to appointments list
            appointments.append(response.appointment)
            
            isBookingAppointment = false
            return response
        } catch {
            self.error = error.localizedDescription
            isBookingAppointment = false
            return nil
        }
    }
    
    public func loadAppointments() async {
        do {
            let appointments = try await healthService.getAppointments().async()
            self.appointments = appointments
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    public func cancelAppointment(_ id: String) async {
        do {
            let updatedAppointment = try await healthService.cancelAppointment(id).async()
            
            if let index = appointments.firstIndex(where: { $0.id == id }) {
                appointments[index] = updatedAppointment
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Computed Properties
    
    public var upcomingAppointments: [HealthAppointment] {
        appointments
            .filter { $0.status == .confirmed && $0.dateTime > Date() }
            .sorted { $0.dateTime < $1.dateTime }
    }
    
    public var pastAppointments: [HealthAppointment] {
        appointments
            .filter { $0.status == .completed || ($0.dateTime < Date() && $0.status != .cancelled) }
            .sorted { $0.dateTime > $1.dateTime }
    }
    
    public var availableSpecialties: [String] {
        searchResults?.filters.availableSpecialties ?? []
    }
    
    public var availableTypes: [String] {
        searchResults?.filters.availableTypes ?? []
    }
}

// MARK: - News ViewModel

@MainActor
public class NewsViewModel: ObservableObject {
    @Published public var articles: [HealthNewsItem] = []
    @Published public var isLoading = false
    @Published public var error: String?
    @Published public var hasMore = true
    
    private var nextPageToken: String?
    private let healthService: HealthService
    
    public init(healthService: HealthService) {
        self.healthService = healthService
    }
    
    public func loadNews() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let response = try await healthService.getHealthNews().async()
            self.articles = response.articles
            self.nextPageToken = response.nextPageToken
            self.hasMore = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func loadMoreNews() async {
        guard let nextPageToken = nextPageToken,
              !isLoading,
              hasMore else { return }
        
        isLoading = true
        
        do {
            let response = try await healthService.getHealthNews(pageToken: nextPageToken).async()
            self.articles.append(contentsOf: response.articles)
            self.nextPageToken = response.nextPageToken
            self.hasMore = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func refreshNews() async {
        articles.removeAll()
        nextPageToken = nil
        hasMore = true
        await loadNews()
    }
    
    // MARK: - Computed Properties
    
    public var featuredArticles: [HealthNewsItem] {
        Array(articles.prefix(3))
    }
    
    public var recentArticles: [HealthNewsItem] {
        articles.filter { 
            Calendar.current.isDate($0.publishedAt, inSameDayAs: Date()) ||
            Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.contains($0.publishedAt) == true
        }
    }
    
    public var categorizedArticles: [String: [HealthNewsItem]] {
        Dictionary(grouping: articles) { article in
            article.tags.first ?? "General"
        }
    }
}

// MARK: - Extensions

// Publisher.async() helper is defined in HealthViewModel; avoid duplicate declarations here