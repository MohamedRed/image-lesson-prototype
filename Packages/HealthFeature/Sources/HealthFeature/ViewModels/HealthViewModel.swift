import Foundation
import Combine
import HealthKit
import HealthService

/// Main health feature view model
@MainActor
public class HealthViewModel: ObservableObject {
    @Published public var healthOverview: HealthOverviewResponse?
    @Published public var profile: HealthProfile?
    @Published public var isLoading = false
    @Published public var error: String?
    
    @Published public var todaySteps: Int = 0
    @Published public var activeMinutes: Int = 0
    @Published public var sleepHours: Double = 0
    @Published public var heartRate: Int = 0
    
    private let healthService: HealthService
    private let healthKitService: HealthKitService
    private var cancellables = Set<AnyCancellable>()
    
    public init(healthService: HealthService, healthKitService: HealthKitService) {
        self.healthService = healthService
        self.healthKitService = healthKitService
        setupBindings()
    }
    
    private func setupBindings() {
        // Refresh data when HealthKit permissions change
        healthKitService.$authorizedDataTypes
            .dropFirst()
            .sink { [weak self] _ in
                Task {
                    await self?.refreshHealthData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    public func loadInitialData() async {
        isLoading = true
        error = nil
        
        do {
            // Request HealthKit permissions first
            if !healthKitService.authorizedDataTypes.isEmpty {
                await syncHealthKitData()
            }
            
            // Load health overview from backend
            let overview = try await healthService.getHealthOverview().async()
            self.healthOverview = overview
            self.profile = overview.profile
            
            updateTodayMetrics(from: overview.todaySummary)
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func refreshHealthData() async {
        await loadInitialData()
    }
    
    private func updateTodayMetrics(from summary: HealthOverviewResponse.DaySummary) {
        todaySteps = summary.steps
        activeMinutes = summary.activeMinutes
        sleepHours = summary.sleepHours ?? 0
        heartRate = summary.heartRateAvg ?? 0
    }
    
    // MARK: - HealthKit Integration
    
    public func requestHealthKitPermissions() async -> Bool {
        do {
            let granted = try await healthKitService.requestPermissions().async()
            if granted {
                await syncHealthKitData()
            }
            return granted
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
    
    private func syncHealthKitData() async {
        guard healthKitService.permissionStatus == .authorized else { return }
        
        do {
            // Read recent observations
            let observations = try await healthKitService.readLatestObservations(
                for: [.stepCount, .heartRate, .bodyMass, .activeEnergyBurned],
                limit: 50
            ).async()
            
            // Import to backend
            let importRequest = HealthKitImportRequest(
                observations: observations,
                manifest: HealthKitImportRequest.ImportManifest(
                    startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
                    endDate: Date(),
                    dataTypes: ["steps", "heartRate", "weight", "calories"],
                    recordCount: observations.count
                )
            )
            
            _ = try await healthService.importHealthKitData(importRequest).async()
            
        } catch {
            print("HealthKit sync error: \(error)")
        }
    }
    
    // MARK: - Profile Management
    
    public func updateProfile(_ updatedProfile: HealthProfile) async {
        isLoading = true
        
        do {
            let profile = try await healthService.updateHealthProfile(updatedProfile).async()
            self.profile = profile
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func updateConsent(_ consent: HealthConsent) async {
        do {
            _ = try await healthService.updateConsent(consent).async()
            // Refresh profile to get updated consents
            await refreshHealthData()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Manual Data Entry
    
    public func saveObservation(_ observation: HealthObservation) async {
        do {
            _ = try await healthService.saveObservation(observation).async()
            await refreshHealthData()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    public func saveWeight(_ weight: Double) async {
        // Save to HealthKit
        do {
            _ = try await healthKitService.saveBodyWeight(weight).async()
        } catch {
            print("Failed to save to HealthKit: \(error)")
        }
        
        // Save to backend
        let observation = HealthObservation(
            userId: profile?.userId ?? "unknown",
            type: .weight,
            value: .numeric(weight, "kg"),
            source: .manual
        )
        
        await saveObservation(observation)
    }
    
    // MARK: - Voice Assistant
    
    public func processVoiceInput(_ transcript: String) async -> VoiceInterpretResponse? {
        let context = VoiceInterpretRequest.VoiceContext(
            activePrograms: healthOverview?.activeProgramSteps.map { $0.id } ?? [],
            currentGoals: profile?.goals.map { $0.title } ?? [],
            recentInsights: healthOverview?.insights.map { $0.title } ?? []
        )
        
        let request = VoiceInterpretRequest(transcript: transcript, context: context)
        
        do {
            return try await healthService.interpretVoiceInput(request).async()
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
}

// MARK: - Programs ViewModel

@MainActor
public class ProgramsViewModel: ObservableObject {
    @Published public var programs: [HealthProgram] = []
    @Published public var availablePrograms: [HealthProgram] = []
    @Published public var isLoading = false
    @Published public var error: String?
    
    private let healthService: HealthService
    private var cancellables = Set<AnyCancellable>()
    
    public init(healthService: HealthService) {
        self.healthService = healthService
    }
    
    public func loadPrograms() async {
        isLoading = true
        error = nil
        
        do {
            let programs = try await healthService.getPrograms().async()
            self.programs = programs
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func createProgram(for goal: HealthGoal) async -> HealthProgram? {
        isLoading = true
        
        do {
            let request = CreateProgramRequest(goal: goal)
            let response = try await healthService.createProgram(request).async()
            
            programs.append(response.program)
            return response.program
        } catch {
            self.error = error.localizedDescription
            return nil
        }
        
        isLoading = false
    }
    
    public func updateProgress(programId: String, stepId: String, completed: Bool, feedback: String? = nil) async {
        let request = ProgressUpdateRequest(
            stepId: stepId,
            completed: completed,
            feedback: feedback
        )
        
        do {
            let updatedProgram = try await healthService.updateProgramProgress(programId, request).async()
            
            if let index = programs.firstIndex(where: { $0.id == programId }) {
                programs[index] = updatedProgram
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    public func pauseProgram(_ id: String) async {
        do {
            let updatedProgram = try await healthService.pauseProgram(id).async()
            
            if let index = programs.firstIndex(where: { $0.id == id }) {
                programs[index] = updatedProgram
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    public func resumeProgram(_ id: String) async {
        do {
            let updatedProgram = try await healthService.resumeProgram(id).async()
            
            if let index = programs.firstIndex(where: { $0.id == id }) {
                programs[index] = updatedProgram
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Insights ViewModel

@MainActor
public class InsightsViewModel: ObservableObject {
    @Published public var insights: [HealthInsight] = []
    @Published public var unreadCount: Int = 0
    @Published public var isLoading = false
    @Published public var error: String?
    
    private let healthService: HealthService
    
    public init(healthService: HealthService) {
        self.healthService = healthService
    }
    
    public func loadInsights(category: HealthInsight.InsightCategory? = nil) async {
        isLoading = true
        error = nil
        
        do {
            let insights = try await healthService.getInsights(category: category).async()
            self.insights = insights
            self.unreadCount = insights.filter { !$0.isRead }.count
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func markInsightRead(_ id: String) async {
        do {
            try await healthService.markInsightRead(id).async()
            
            if let index = insights.firstIndex(where: { $0.id == id }) {
                insights[index] = HealthInsight(
                    id: insights[index].id,
                    userId: insights[index].userId,
                    type: insights[index].type,
                    category: insights[index].category,
                    title: insights[index].title,
                    description: insights[index].description,
                    trigger: insights[index].trigger,
                    evidenceLinks: insights[index].evidenceLinks,
                    severity: insights[index].severity,
                    recommendedActions: insights[index].recommendedActions,
                    createdAt: insights[index].createdAt,
                    isRead: true,
                    isDismissed: insights[index].isDismissed
                )
                updateUnreadCount()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    public func dismissInsight(_ id: String) async {
        do {
            try await healthService.dismissInsight(id).async()
            insights.removeAll { $0.id == id }
            updateUnreadCount()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func updateUnreadCount() {
        unreadCount = insights.filter { !$0.isRead }.count
    }
}

// MARK: - Extensions

extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = self.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                },
                receiveValue: { value in
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
            )
        }
    }
}