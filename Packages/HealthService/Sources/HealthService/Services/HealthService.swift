import Foundation
import Combine

/// Main health service for API communication
public class HealthService: ObservableObject {
    public static let shared = HealthService(baseURL: URL(string: "https://api.liive.app")!)
    
    private let baseURL: URL
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    // MARK: - Overview & Profile
    
    public func getHealthOverview() -> AnyPublisher<HealthOverviewResponse, Error> {
        request(endpoint: "health/overview", method: .GET)
    }
    
    public func updateHealthProfile(_ profile: HealthProfile) -> AnyPublisher<HealthProfile, Error> {
        request(endpoint: "health/profile", method: .PUT, body: profile)
    }
    
    public func updateConsent(_ consent: HealthConsent) -> AnyPublisher<HealthConsent, Error> {
        request(endpoint: "health/consents", method: .POST, body: consent)
    }
    
    // MARK: - Observations
    
    public func getObservations(
        type: HealthObservation.ObservationType? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        pageToken: String? = nil
    ) -> AnyPublisher<ObservationsResponse, Error> {
        var params: [String: String] = [:]
        if let type = type { params["type"] = type.rawValue }
        if let startDate = startDate { params["startDate"] = ISO8601DateFormatter().string(from: startDate) }
        if let endDate = endDate { params["endDate"] = ISO8601DateFormatter().string(from: endDate) }
        if let pageToken = pageToken { params["pageToken"] = pageToken }
        
        return request(endpoint: "health/observations", method: .GET, queryParams: params)
    }
    
    public func saveObservation(_ observation: HealthObservation) -> AnyPublisher<HealthObservation, Error> {
        request(endpoint: "health/observations", method: .POST, body: observation)
    }
    
    public func importHealthKitData(_ importRequest: HealthKitImportRequest) -> AnyPublisher<ImportResult, Error> {
        request(endpoint: "health/import/healthkit", method: .POST, body: importRequest)
    }
    
    // MARK: - Programs
    
    public func createProgram(_ payload: CreateProgramRequest) -> AnyPublisher<CreateProgramResponse, Error> {
        request(endpoint: "health/programs/create", method: .POST, body: payload)
    }
    
    public func getPrograms() -> AnyPublisher<[HealthProgram], Error> {
        request(endpoint: "health/programs", method: .GET)
    }
    
    public func getProgram(_ id: String) -> AnyPublisher<HealthProgram, Error> {
        request(endpoint: "health/programs/\(id)", method: .GET)
    }
    
    public func updateProgramProgress(_ programId: String, _ payload: ProgressUpdateRequest) -> AnyPublisher<HealthProgram, Error> {
        request(endpoint: "health/programs/\(programId)/progress", method: .POST, body: payload)
    }
    
    public func pauseProgram(_ id: String) -> AnyPublisher<HealthProgram, Error> {
        request(endpoint: "health/programs/\(id)/pause", method: .POST)
    }
    
    public func resumeProgram(_ id: String) -> AnyPublisher<HealthProgram, Error> {
        request(endpoint: "health/programs/\(id)/resume", method: .POST)
    }
    
    // MARK: - Insights
    
    public func getInsights(category: HealthInsight.InsightCategory? = nil) -> AnyPublisher<[HealthInsight], Error> {
        var params: [String: String] = [:]
        if let category = category { params["category"] = category.rawValue }
        
        return request(endpoint: "health/insights", method: .GET, queryParams: params)
    }
    
    public func markInsightRead(_ id: String) -> AnyPublisher<Void, Error> {
        request(endpoint: "health/insights/\(id)/read", method: .POST)
            .map { (_: EmptyResponse) in }
            .eraseToAnyPublisher()
    }
    
    public func dismissInsight(_ id: String) -> AnyPublisher<Void, Error> {
        request(endpoint: "health/insights/\(id)/dismiss", method: .POST)
            .map { (_: EmptyResponse) in }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Leaderboards
    
    public func getLeaderboard(
        bucket: LeaderboardBucket.GeoLevel = .city,
        category: LeaderboardBucket.CompetitionCategory = .overall
    ) -> AnyPublisher<LeaderboardResponse, Error> {
        let params = [
            "bucket": bucket.rawValue,
            "category": category.rawValue
        ]
        
        return request(endpoint: "health/leaderboard", method: .GET, queryParams: params)
    }
    
    public func getChallenges() -> AnyPublisher<[HealthChallenge], Error> {
        request(endpoint: "health/challenges", method: .GET)
    }
    
    public func joinChallenge(_ id: String) -> AnyPublisher<HealthChallenge, Error> {
        request(endpoint: "health/challenges/\(id)/join", method: .POST)
    }
    
    // MARK: - News
    
    public func getHealthNews(pageToken: String? = nil) -> AnyPublisher<NewsResponse, Error> {
        var params: [String: String] = [:]
        if let pageToken = pageToken { params["pageToken"] = pageToken }
        
        return request(endpoint: "health/news", method: .GET, queryParams: params)
    }
    
    // MARK: - Professionals
    
    public func searchProfessionals(
        type: HealthProfessional.ProfessionalType? = nil,
        specialty: String? = nil,
        location: String? = nil,
        telehealthOnly: Bool = false,
        pageToken: String? = nil
    ) -> AnyPublisher<ProfessionalSearchResponse, Error> {
        var params: [String: String] = [:]
        if let type = type { params["type"] = type.rawValue }
        if let specialty = specialty { params["specialty"] = specialty }
        if let location = location { params["location"] = location }
        if telehealthOnly { params["telehealthOnly"] = "true" }
        if let pageToken = pageToken { params["pageToken"] = pageToken }
        
        return request(endpoint: "health/professionals/search", method: .GET, queryParams: params)
    }
    
    public func getProfessional(_ id: String) -> AnyPublisher<HealthProfessional, Error> {
        request(endpoint: "health/professionals/\(id)", method: .GET)
    }
    
    public func bookAppointment(_ payload: BookAppointmentRequest) -> AnyPublisher<BookAppointmentResponse, Error> {
        request(endpoint: "health/appointments/book", method: .POST, body: payload)
    }
    
    public func getAppointments() -> AnyPublisher<[HealthAppointment], Error> {
        request(endpoint: "health/appointments", method: .GET)
    }
    
    public func cancelAppointment(_ id: String) -> AnyPublisher<HealthAppointment, Error> {
        request(endpoint: "health/appointments/\(id)/cancel", method: .POST)
    }
    
    // MARK: - Voice Assistant
    
    public func interpretVoiceInput(_ payload: VoiceInterpretRequest) -> AnyPublisher<VoiceInterpretResponse, Error> {
        request(endpoint: "health/voice/interpret", method: .POST, body: payload)
    }
    
    // MARK: - Medications & Incidents
    
    public func getMedications() -> AnyPublisher<[Medication], Error> {
        request(endpoint: "health/medications", method: .GET)
    }
    
    public func saveMedication(_ medication: Medication) -> AnyPublisher<Medication, Error> {
        request(endpoint: "health/medications", method: .POST, body: medication)
    }
    
    public func updateMedicationAdherence(_ medicationId: String, log: Medication.AdherenceLog) -> AnyPublisher<Medication, Error> {
        request(endpoint: "health/medications/\(medicationId)/adherence", method: .POST, body: log)
    }
    
    public func getIncidents() -> AnyPublisher<[HealthIncident], Error> {
        request(endpoint: "health/incidents", method: .GET)
    }
    
    public func saveIncident(_ incident: HealthIncident) -> AnyPublisher<HealthIncident, Error> {
        request(endpoint: "health/incidents", method: .POST, body: incident)
    }
    
    // MARK: - Private Request Helpers
    
    private func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        queryParams: [String: String]? = nil
    ) -> AnyPublisher<T, Error> {
        var url = baseURL.appendingPathComponent(endpoint)
        
        if let queryParams = queryParams, !queryParams.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            url = components.url!
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HealthServiceError.invalidResponse
                }
                guard 200...299 ~= httpResponse.statusCode else {
                    if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                        throw HealthServiceError.apiError(errorData.error, httpResponse.statusCode)
                    }
                    throw HealthServiceError.httpError(httpResponse.statusCode)
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    private func request<T: Decodable, B: Encodable>(
        endpoint: String,
        method: HTTPMethod,
        queryParams: [String: String]? = nil,
        body: B
    ) -> AnyPublisher<T, Error> {
        var url = baseURL.appendingPathComponent(endpoint)
        
        if let queryParams = queryParams, !queryParams.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            url = components.url!
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HealthServiceError.invalidResponse
                }
                guard 200...299 ~= httpResponse.statusCode else {
                    if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                        throw HealthServiceError.apiError(errorData.error, httpResponse.statusCode)
                    }
                    throw HealthServiceError.httpError(httpResponse.statusCode)
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func getAuthToken() -> String? {
        // This would integrate with Firebase Auth or your auth system
        return UserDefaults.standard.string(forKey: "health_auth_token")
    }
}

// MARK: - Supporting Types

public enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

public enum HealthServiceError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String, Int)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message, _):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

private struct ErrorResponse: Codable {
    let error: String
    let code: String?
}

private struct EmptyResponse: Codable {}

public struct ImportResult: Codable {
    public let processedCount: Int
    public let skippedCount: Int
    public let errorCount: Int
    public let warnings: [String]?
    
    public init(
        processedCount: Int,
        skippedCount: Int,
        errorCount: Int,
        warnings: [String]? = nil
    ) {
        self.processedCount = processedCount
        self.skippedCount = skippedCount
        self.errorCount = errorCount
        self.warnings = warnings
    }
}