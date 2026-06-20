import Foundation
import Combine

/// Protocol defining the interface for health service implementations
public protocol HealthServiceProtocol: ObservableObject {
    // MARK: - Overview & Profile
    func getHealthOverview() -> AnyPublisher<HealthOverviewResponse, Error>
    func updateHealthProfile(_ profile: HealthProfile) -> AnyPublisher<HealthProfile, Error>
    func updateConsent(_ consent: HealthConsent) -> AnyPublisher<HealthConsent, Error>
    
    // MARK: - Observations
    func getObservations(
        type: HealthObservation.ObservationType?,
        startDate: Date?,
        endDate: Date?,
        pageToken: String?
    ) -> AnyPublisher<ObservationsResponse, Error>
    
    func saveObservation(_ observation: HealthObservation) -> AnyPublisher<HealthObservation, Error>
    func importHealthKitData(_ request: HealthKitImportRequest) -> AnyPublisher<HealthKitImportResponse, Error>
    
    // MARK: - Programs
    func getPrograms() -> AnyPublisher<[HealthProgram], Error>
    func createProgram(_ request: CreateProgramRequest) -> AnyPublisher<CreateProgramResponse, Error>
    func updateProgramProgress(_ programId: String, _ request: ProgressUpdateRequest) -> AnyPublisher<HealthProgram, Error>
    func pauseProgram(_ id: String) -> AnyPublisher<HealthProgram, Error>
    func resumeProgram(_ id: String) -> AnyPublisher<HealthProgram, Error>
    
    // MARK: - Insights
    func getInsights(category: HealthInsight.InsightCategory?) -> AnyPublisher<[HealthInsight], Error>
    func markInsightRead(_ id: String) -> AnyPublisher<Void, Error>
    func dismissInsight(_ id: String) -> AnyPublisher<Void, Error>
    
    // MARK: - Voice Assistant
    func interpretVoiceInput(_ request: VoiceInterpretRequest) -> AnyPublisher<VoiceInterpretResponse, Error>
}