import Foundation
import Combine
import MealPlanningService

/// Service for coordinating cooking sessions with multiple people
public final class MultiCookCoordinationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentSession: MultiCookSession?
    @Published public var participants: [CookingParticipant] = []
    @Published public var taskAssignments: [TaskAssignment] = []
    @Published public var sharedTimers: [SharedTimer] = []
    @Published public var isCoordinating = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let communicationService = CookingCommunicationService()
    
    // MARK: - Session Management
    
    /// Start a new multi-cook session
    public func startMultiCookSession(recipe: Recipe, coordinatorName: String) async throws {
        let session = MultiCookSession(
            id: UUID().uuidString,
            recipe: recipe,
            coordinatorId: "current_user",
            coordinatorName: coordinatorName,
            startTime: Date()
        )
        
        // Analyze recipe and create task assignments
        let assignments = await analyzeRecipeForTaskAssignment(recipe)
        
        DispatchQueue.main.async {
            self.currentSession = session
            self.taskAssignments = assignments
            self.isCoordinating = true
            
            MealPlanningAnalytics.shared.trackFeatureUsage(
                feature: "multi_cook_session",
                usage: "started"
            )
        }
        
        // Setup communication
        await setupSessionCommunication(session)
    }
    
    /// Join an existing multi-cook session
    public func joinSession(sessionId: String, participantName: String) async throws {
        // In a real implementation, this would connect to a shared session
        // For now, we'll simulate joining a session
        
        let participant = CookingParticipant(
            id: UUID().uuidString,
            name: participantName,
            status: .ready,
            currentTask: nil,
            capabilities: ParticipantCapabilities.defaultCapabilities
        )
        
        DispatchQueue.main.async {
            self.participants.append(participant)
            
            MealPlanningAnalytics.shared.trackFeatureUsage(
                feature: "multi_cook_session",
                usage: "joined"
            )
        }
    }
    
    /// End the current session
    public func endSession() {
        guard let session = currentSession else { return }
        
        let duration = Date().timeIntervalSince(session.startTime)
        
        MealPlanningAnalytics.shared.logEvent("multi_cook_session_ended", parameters: [
            "session_id": session.id,
            "duration_minutes": String(Int(duration / 60)),
            "participants_count": String(participants.count),
            "tasks_completed": String(taskAssignments.filter { $0.status == .completed }.count),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        
        currentSession = nil
        participants.removeAll()
        taskAssignments.removeAll()
        sharedTimers.removeAll()
        isCoordinating = false
    }
    
    // MARK: - Task Management
    
    /// Assign a task to a participant
    public func assignTask(_ taskId: String, to participantId: String) {
        guard let taskIndex = taskAssignments.firstIndex(where: { $0.id == taskId }),
              let participantIndex = participants.firstIndex(where: { $0.id == participantId }) else {
            return
        }
        
        taskAssignments[taskIndex].assignedParticipantId = participantId
        taskAssignments[taskIndex].status = .assigned
        
        participants[participantIndex].currentTask = taskId
        
        // Send assignment notification
        communicationService.sendTaskAssignment(taskAssignments[taskIndex], to: participantId)
        
        MealPlanningAnalytics.shared.trackFeatureUsage(
            feature: "task_assignment",
            usage: "assigned"
        )
    }
    
    /// Mark a task as started
    public func startTask(_ taskId: String) {
        guard let taskIndex = taskAssignments.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        taskAssignments[taskIndex].status = .inProgress
        taskAssignments[taskIndex].actualStartTime = Date()
        
        // Notify other participants
        communicationService.broadcastTaskUpdate(taskAssignments[taskIndex])
        
        // Start any associated timers
        if let timerDuration = taskAssignments[taskIndex].estimatedDuration {
            startSharedTimer(for: taskId, duration: timerDuration)
        }
    }
    
    /// Mark a task as completed
    public func completeTask(_ taskId: String) {
        guard let taskIndex = taskAssignments.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        taskAssignments[taskIndex].status = .completed
        taskAssignments[taskIndex].completionTime = Date()
        
        // Update participant status
        if let participantId = taskAssignments[taskIndex].assignedParticipantId,
           let participantIndex = participants.firstIndex(where: { $0.id == participantId }) {
            participants[participantIndex].currentTask = nil
            participants[participantIndex].status = .ready
        }
        
        // Check for next available tasks
        checkForNextTasks()
        
        // Notify completion
        communicationService.broadcastTaskUpdate(taskAssignments[taskIndex])
        
        MealPlanningAnalytics.shared.trackFeatureUsage(
            feature: "task_completion",
            usage: "completed"
        )
    }
    
    // MARK: - Timer Management
    
    /// Start a shared timer for the cooking session
    public func startSharedTimer(for taskId: String, duration: TimeInterval, name: String = "Cooking Timer") {
        let timer = SharedTimer(
            id: UUID().uuidString,
            name: name,
            associatedTaskId: taskId,
            duration: duration,
            startTime: Date()
        )
        
        timer.onTick = { [weak self] remainingTime in
            DispatchQueue.main.async {
                self?.communicationService.broadcastTimerUpdate(timer, remainingTime: remainingTime)
            }
        }
        
        timer.onComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.handleTimerCompletion(timer)
            }
        }
        
        timer.start()
        sharedTimers.append(timer)
        
        // Notify all participants
        communicationService.broadcastTimerStart(timer)
    }
    
    private func handleTimerCompletion(_ timer: SharedTimer) {
        // Remove from active timers
        sharedTimers.removeAll { $0.id == timer.id }
        
        // Notify participants
        communicationService.broadcastTimerComplete(timer)
        
        // Check if this completes the associated task
        if let taskId = timer.associatedTaskId,
           let taskIndex = taskAssignments.firstIndex(where: { $0.id == taskId }),
           taskAssignments[taskIndex].autoCompleteOnTimer {
            completeTask(taskId)
        }
    }
    
    // MARK: - Communication
    
    private func setupSessionCommunication(_ session: MultiCookSession) async {
        // Setup real-time communication channel
        // In production, this would use WebSocket, SignalR, or Firebase Realtime Database
        
        communicationService.sessionId = session.id
        
        // Listen for participant updates
        communicationService.participantUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handleParticipantUpdate(update)
            }
            .store(in: &cancellables)
        
        // Listen for task updates
        communicationService.taskUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handleTaskUpdate(update)
            }
            .store(in: &cancellables)
    }
    
    private func handleParticipantUpdate(_ update: ParticipantUpdate) {
        guard let index = participants.firstIndex(where: { $0.id == update.participantId }) else {
            return
        }
        
        participants[index].status = update.status
        
        if let currentTask = update.currentTask {
            participants[index].currentTask = currentTask
        }
    }
    
    private func handleTaskUpdate(_ update: TaskUpdate) {
        guard let index = taskAssignments.firstIndex(where: { $0.id == update.taskId }) else {
            return
        }
        
        taskAssignments[index].status = update.status
        
        if let participantId = update.assignedParticipantId {
            taskAssignments[index].assignedParticipantId = participantId
        }
    }
    
    // MARK: - Recipe Analysis
    
    private func analyzeRecipeForTaskAssignment(_ recipe: Recipe) async -> [TaskAssignment] {
        var assignments: [TaskAssignment] = []
        
        // Analyze prep tasks
        let prepTasks = identifyPrepTasks(recipe)
        assignments.append(contentsOf: prepTasks)
        
        // Analyze cooking tasks that can be done in parallel
        let cookingTasks = identifyParallelCookingTasks(recipe)
        assignments.append(contentsOf: cookingTasks)
        
        // Add cleanup tasks
        let cleanupTasks = createCleanupTasks(recipe)
        assignments.append(contentsOf: cleanupTasks)
        
        return assignments
    }
    
    private func identifyPrepTasks(_ recipe: Recipe) -> [TaskAssignment] {
        var tasks: [TaskAssignment] = []
        
        // Group ingredients that can be prepped simultaneously
        let vegetablesToChop = recipe.ingredients.filter { ingredient in
            ingredient.name.lowercased().contains(anyOf: ["onion", "carrot", "celery", "pepper", "tomato"])
        }
        
        if !vegetablesToChop.isEmpty {
            tasks.append(TaskAssignment(
                id: UUID().uuidString,
                title: "Prep Vegetables",
                description: "Chop and prepare vegetables: \(vegetablesToChop.map { $0.name }.joined(separator: ", "))",
                type: .preparation,
                estimatedDuration: TimeInterval(vegetablesToChop.count * 3 * 60), // 3 minutes per vegetable
                difficulty: .easy,
                requiredTools: ["knife", "cutting board"],
                canBeParallel: true,
                priority: .high
            ))
        }
        
        // Meat preparation
        let meatIngredients = recipe.ingredients.filter { ingredient in
            ingredient.name.lowercased().contains(anyOf: ["chicken", "beef", "pork", "fish"])
        }
        
        if !meatIngredients.isEmpty {
            tasks.append(TaskAssignment(
                id: UUID().uuidString,
                title: "Prepare Protein",
                description: "Prepare and season protein: \(meatIngredients.map { $0.name }.joined(separator: ", "))",
                type: .preparation,
                estimatedDuration: 10 * 60, // 10 minutes
                difficulty: .medium,
                requiredTools: ["knife", "cutting board"],
                canBeParallel: false, // Usually needs attention
                priority: .high
            ))
        }
        
        return tasks
    }
    
    private func identifyParallelCookingTasks(_ recipe: Recipe) -> [TaskAssignment] {
        var tasks: [TaskAssignment] = []
        
        // Analyze recipe steps for parallel opportunities
        for (index, step) in recipe.steps.enumerated() {
            let instruction = (step.shortInstruction ?? step.instruction).lowercased()
            
            if instruction.contains("boil") || instruction.contains("simmer") {
                tasks.append(TaskAssignment(
                    id: UUID().uuidString,
                    title: "Monitor Cooking - Step \(index + 1)",
                    description: step.shortInstruction ?? step.instruction,
                    type: .cooking,
                    estimatedDuration: step.timerSeconds != nil ? TimeInterval(step.timerSeconds!) : nil,
                    difficulty: .medium,
                    requiredTools: step.utensilRefs,
                    canBeParallel: true,
                    priority: .medium,
                    autoCompleteOnTimer: (step.timerSeconds ?? 0) > 0
                ))
            } else if instruction.contains("mix") || instruction.contains("stir") {
                tasks.append(TaskAssignment(
                    id: UUID().uuidString,
                    title: "Mixing - Step \(index + 1)",
                    description: step.shortInstruction ?? step.instruction,
                    type: .preparation,
                    estimatedDuration: 5 * 60, // Default 5 minutes
                    difficulty: .easy,
                    requiredTools: step.utensilRefs,
                    canBeParallel: true,
                    priority: .low
                ))
            }
        }
        
        return tasks
    }
    
    private func createCleanupTasks(_ recipe: Recipe) -> [TaskAssignment] {
        var tasks: [TaskAssignment] = []
        
        // Get all unique utensils used
        let allUtensils = Set(recipe.utensils.map { $0.name })
        
        if allUtensils.count > 3 {
            tasks.append(TaskAssignment(
                id: UUID().uuidString,
                title: "Clean Cooking Utensils",
                description: "Wash and clean: \(Array(allUtensils).joined(separator: ", "))",
                type: .cleanup,
                estimatedDuration: TimeInterval(allUtensils.count * 2 * 60), // 2 minutes per utensil
                difficulty: .easy,
                requiredTools: [],
                canBeParallel: true,
                priority: .low
            ))
        }
        
        return tasks
    }
    
    private func checkForNextTasks() {
        // Find available participants
        let availableParticipants = participants.filter { $0.status == .ready && $0.currentTask == nil }
        
        // Find unassigned tasks
        let unassignedTasks = taskAssignments.filter { $0.status == .unassigned }
        
        // Auto-assign tasks based on capabilities and priority
        for task in unassignedTasks.sorted(by: { $0.priority.rawValue > $1.priority.rawValue }) {
            if let participant = findBestParticipant(for: task, from: availableParticipants) {
                assignTask(task.id, to: participant.id)
                break // Assign one task at a time
            }
        }
    }
    
    private func findBestParticipant(for task: TaskAssignment, from participants: [CookingParticipant]) -> CookingParticipant? {
        return participants
            .filter { participant in
                // Check if participant has required capabilities
                switch task.type {
                case .preparation:
                    return participant.capabilities.canPrepIngredients
                case .cooking:
                    return participant.capabilities.canCook
                case .cleanup:
                    return participant.capabilities.canCleanup
                case .monitoring:
                    return participant.capabilities.canMonitor
                }
            }
            .max { a, b in
                // Prefer participants with higher skill level for difficult tasks
                if task.difficulty == .hard {
                    return a.capabilities.skillLevel.rawValue < b.capabilities.skillLevel.rawValue
                }
                return false
            }
    }
}

// MARK: - Models

public struct MultiCookSession {
    public let id: String
    public let recipe: Recipe
    public let coordinatorId: String
    public let coordinatorName: String
    public let startTime: Date
}

public struct CookingParticipant: Identifiable {
    public let id: String
    public let name: String
    public var status: ParticipantStatus
    public var currentTask: String?
    public let capabilities: ParticipantCapabilities
}

public enum ParticipantStatus {
    case ready
    case busy
    case away
    case finished
}

public struct ParticipantCapabilities {
    public let canPrepIngredients: Bool
    public let canCook: Bool
    public let canCleanup: Bool
    public let canMonitor: Bool
    public let skillLevel: SkillLevel
    
    public static let defaultCapabilities = ParticipantCapabilities(
        canPrepIngredients: true,
        canCook: true,
        canCleanup: true,
        canMonitor: true,
        skillLevel: .beginner
    )
}

public enum SkillLevel: Int, CaseIterable {
    case beginner = 1
    case intermediate = 2
    case advanced = 3
}

public struct TaskAssignment: Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let type: TaskType
    public var status: TaskStatus = .unassigned
    public var assignedParticipantId: String?
    public let estimatedDuration: TimeInterval?
    public let difficulty: TaskDifficulty
    public let requiredTools: [String]
    public let canBeParallel: Bool
    public let priority: TaskPriority
    public let autoCompleteOnTimer: Bool
    public var actualStartTime: Date?
    public var completionTime: Date?
    
    public init(id: String, title: String, description: String, type: TaskType, estimatedDuration: TimeInterval? = nil, difficulty: TaskDifficulty, requiredTools: [String], canBeParallel: Bool, priority: TaskPriority, autoCompleteOnTimer: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.estimatedDuration = estimatedDuration
        self.difficulty = difficulty
        self.requiredTools = requiredTools
        self.canBeParallel = canBeParallel
        self.priority = priority
        self.autoCompleteOnTimer = autoCompleteOnTimer
    }
}

public enum TaskType {
    case preparation
    case cooking
    case monitoring
    case cleanup
}

public enum TaskStatus {
    case unassigned
    case assigned
    case inProgress
    case completed
}

public enum TaskDifficulty {
    case easy
    case medium
    case hard
}

public enum TaskPriority: Int {
    case low = 1
    case medium = 2
    case high = 3
}

public final class SharedTimer: ObservableObject, Identifiable {
    public let id: String
    public let name: String
    public let associatedTaskId: String?
    public let duration: TimeInterval
    public let startTime: Date
    
    @Published public var remainingTime: TimeInterval
    @Published public var isActive = false
    
    public var onTick: ((TimeInterval) -> Void)?
    public var onComplete: (() -> Void)?
    
    private var timer: Timer?
    
    public init(id: String, name: String, associatedTaskId: String?, duration: TimeInterval, startTime: Date) {
        self.id = id
        self.name = name
        self.associatedTaskId = associatedTaskId
        self.duration = duration
        self.startTime = startTime
        self.remainingTime = duration
    }
    
    public func start() {
        guard !isActive else { return }
        
        isActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    public func pause() {
        timer?.invalidate()
        timer = nil
    }
    
    public func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        remainingTime -= 1
        onTick?(remainingTime)
        
        if remainingTime <= 0 {
            stop()
            onComplete?()
        }
    }
}

// MARK: - Communication Service

final class CookingCommunicationService {
    var sessionId: String?
    
    let participantUpdates = PassthroughSubject<ParticipantUpdate, Never>()
    let taskUpdates = PassthroughSubject<TaskUpdate, Never>()
    
    func sendTaskAssignment(_ task: TaskAssignment, to participantId: String) {
        // Send task assignment notification
        print("📤 Assigning task '\(task.title)' to participant \(participantId)")
    }
    
    func broadcastTaskUpdate(_ task: TaskAssignment) {
        // Broadcast task status update to all participants
        print("📡 Broadcasting task update: \(task.title) - \(task.status)")
    }
    
    func broadcastTimerStart(_ timer: SharedTimer) {
        // Broadcast timer start to all participants
        print("⏰ Broadcasting timer start: \(timer.name)")
    }
    
    func broadcastTimerUpdate(_ timer: SharedTimer, remainingTime: TimeInterval) {
        // Broadcast timer update to all participants
        // Only broadcast every 10 seconds to avoid spam
        if Int(remainingTime) % 10 == 0 {
            print("⏰ Timer update: \(timer.name) - \(Int(remainingTime))s remaining")
        }
    }
    
    func broadcastTimerComplete(_ timer: SharedTimer) {
        // Broadcast timer completion to all participants
        print("✅ Timer completed: \(timer.name)")
    }
}

struct ParticipantUpdate {
    let participantId: String
    let status: ParticipantStatus
    let currentTask: String?
}

struct TaskUpdate {
    let taskId: String
    let status: TaskStatus
    let assignedParticipantId: String?
}

// MARK: - Extensions

extension String {
    func contains(anyOf substrings: [String]) -> Bool {
        return substrings.contains { self.contains($0) }
    }
}