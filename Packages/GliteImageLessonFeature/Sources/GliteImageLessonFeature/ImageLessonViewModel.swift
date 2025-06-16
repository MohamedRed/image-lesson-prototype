import Combine
import Dispatch
import GliteImageLessonService
import Foundation
import LiveKit

/// The view model for the image-based lesson, responsible for managing state and handling user events.
@MainActor
public final class ImageLessonViewModel: ObservableObject {

    // MARK: - State & Events

    /// Represents the complete state of the lesson view at any given time.
    public struct State {
        /// The current connection status to the LiveKit room.
        public var connectionState: GliteImageLessonService.ConnectionState = .disconnected
        /// The latest transcript from the agent.
        public var agentTranscript: String = ""
        /// The latest transcript from the user.
        public var userTranscript: String = ""
        
        // Lesson Content
        /// The URL for the main lesson image to be displayed.
        public var lessonImageUrl: URL?
        /// The URL for the user-generated image.
        public var userImageUrl: URL?
        /// A flag indicating if the user image is currently being generated.
        public var userImageIsLoading: Bool = false
        /// A word or phrase to be highlighted over the lesson image.
        public var highlightedWord: String?
        
        // Scoring
        /// The most recent similarity score received.
        public var currentScore: Double?
        /// The best similarity score received in the current session.
        public var bestScore: Double?
        /// A flag indicating if the last description was accepted.
        public var isAccepted: Bool = false
        
        // Controls
        /// A flag indicating if the user's microphone is enabled.
        public var isMicrophoneEnabled: Bool = false
        /// The user's audio track, used for visualization.
        public var audioTrack: Track?
        /// The agent's audio track, used for visualization.
        public var agentAudioTrack: Track?
        
        // End of Lesson
        /// The summary object to be displayed when the lesson ends.
        public var endLessonSummary: EndLessonSummary?
        /// The URL of the user's best-scoring image for the session.
        public var bestUserImageUrl: URL?
        /// The user's best score for the session.
        public var bestUserScore: Double?
        /// The original text description of the lesson image.
        public var originalImageDescription: String?
        
        // Flow Control
        /// A flag indicating if a lesson is currently in progress.
        public var isLessonActive: Bool = false
        /// An error object to be displayed to the user, if any.
        public var error: Error?
        /// A collection of all chat messages for the transcript view.
        public var chatMessages: [ChatMessage] = []
        /// A flag to control the presentation of the chat history sheet.
        public var isChatSheetPresented: Bool = false
        
        public init() {}
    }

    /// Represents all possible user actions that can be sent from the view to the view model.
    public enum Event {
        /// Initiates a new lesson session.
        case startLesson
        /// Disconnects from the current lesson session.
        case leaveLesson
        /// Toggles the user's microphone on or off.
        case toggleMicrophone
        /// Dismisses the end-of-lesson summary sheet.
        case dismissSummary
        /// Dismisses the error view.
        case dismissError
        /// Toggles the visibility of the chat history sheet.
        case toggleChatSheet
    }

    /// The published state that the view observes for all its updates.
    @Published public var state: State

    // MARK: - Private Properties

    private let service: GliteImageLessonServicing
    private var cancellables = Set<AnyCancellable>()
    
    // A fallback mechanism to ensure the loading spinner doesn't run indefinitely
    // if a final image response is missed.
    private var userImageLoadingTimeoutTask: Task<Void, Never>? = nil

    // MARK: - Lifecycle

    /// Initializes a new view model.
    /// - Parameters:
    ///   - initialState: The initial state for the view model. Defaults to a new `State` instance.
    ///   - service: The service object responsible for all backend and LiveKit communication.
    public init(
        initialState: State = State(),
        service: GliteImageLessonServicing
    ) {
        self.state = initialState
        self.service = service
    }

    // MARK: - Public Methods

    /// The single entry point for the view to send user actions to the view model.
    /// - Parameter event: The user event to be handled.
    public func handle(event: Event) {
        switch event {
        case .startLesson:
            resetStateForNewLesson()
            state.isLessonActive = true
            startService()
        case .leaveLesson:
            stopService()
            state.isLessonActive = false
        case .toggleMicrophone:
            // Delegate the action to the service, the true state will be updated via its publisher.
            Task { await service.toggleMicrophone() }
        case .dismissSummary:
            state.endLessonSummary = nil
            // Per requirements, dismissing the summary also ends the session completely.
            stopService()
            state.isLessonActive = false
        case .dismissError:
            state.error = nil
        case .toggleChatSheet:
            state.isChatSheetPresented.toggle()
        }
    }

    // MARK: - Private Methods

    private func resetStateForNewLesson() {
        // Clear all session-specific data to ensure a clean slate for the new lesson.
        state.agentTranscript = ""
        state.userTranscript = ""
        state.lessonImageUrl = nil
        state.userImageUrl = nil
        state.userImageIsLoading = false
        state.currentScore = nil
        state.bestScore = nil
        state.isAccepted = false
        state.endLessonSummary = nil
        state.chatMessages = []
        state.bestUserImageUrl = nil
        state.bestUserScore = nil
        state.originalImageDescription = nil
    }

    private func startService() {
        // Subscribe to all publishers from the service *before* starting it
        // to ensure no events are missed during the connection phase.
        service.connectionState
            .sink { [weak self] connectionState in
                self?.state.connectionState = connectionState
            }
            .store(in: &cancellables)
            
        service.lessonEvents
            .sink { [weak self] lessonEvent in
                self?.updateState(with: lessonEvent)
            }
            .store(in: &cancellables)

        service.isMicrophoneEnabled
            .sink { [weak self] isEnabled in
                self?.state.isMicrophoneEnabled = isEnabled
            }
            .store(in: &cancellables)
            
        service.audioTrack
            .sink { [weak self] track in
                self?.state.audioTrack = track
            }
            .store(in: &cancellables)

        service.agentAudioTrack
            .sink { [weak self] track in
                self?.state.agentAudioTrack = track
            }
            .store(in: &cancellables)

        // Start service **after** all subscriptions are in place**
        Task {
            do {
                try await service.start()
            } catch {
                state.error = error
                state.connectionState = .failed(error.localizedDescription)
            }
        }
    }
    
    private func stopService() {
        // Disconnect from the service and immediately cancel all subscriptions
        // to prevent any further state updates from lingering events.
        service.stop()
        cancellables.forEach { $0.cancel() }
    }
    
    private func updateState(with lessonEvent: LessonEvent) {
        switch lessonEvent {
        case .agentSaid(let text, isFinal: _):
            state.agentTranscript = text
            state.chatMessages.append(ChatMessage(role: .agent, text: text))
        case .userSaid(let text, isFinal: _):
            state.userTranscript = text
            state.chatMessages.append(ChatMessage(role: .user, text: text))
        case .showLessonImage(let url):
            state.lessonImageUrl = url
        case .showUserImage(let url, _):
            state.userImageUrl = url
            state.userImageIsLoading = false
            userImageLoadingTimeoutTask?.cancel()

            // The view model is responsible for tracking the user's best performance during the session.
            // When a new image is shown, we check its score against the current best.
            if let currentScore = state.currentScore {
                if state.bestUserScore == nil || currentScore > state.bestUserScore! {
                    state.bestUserScore = currentScore
                    state.bestUserImageUrl = url
                }
            }
        case .showUserImageLoading(_):
            state.userImageIsLoading = true
            
            // In case the final `showUserImage` event is missed, this task prevents
            // the spinner from running forever.
            userImageLoadingTimeoutTask?.cancel()
            userImageLoadingTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: Metrics.Timing.userImageTimeout)
                await MainActor.run {
                    self?.state.userImageIsLoading = false
                }
            }
        case .showSimilarityScore(let score, let bestScore, let accepted):
            state.currentScore = score
            state.bestScore = bestScore
            state.isAccepted = accepted
        case .highlightWord(let word):
            // Filter out common instructional phrases to avoid displaying them over the image.
            let lowercasedWord = word.lowercased()
            let forbiddenSubstrings = ["please describe", "describe the image"]
            
            if forbiddenSubstrings.contains(where: { lowercasedWord.contains($0) }) {
                // If a forbidden phrase is found, do nothing, or clear the existing word.
                // For now, we will just ignore the update.
                state.highlightedWord = nil
            } else {
                state.highlightedWord = word
            }
        case .lessonEnded(let originalImageDescription):
            // When the backend signals the end of the lesson, the view model is responsible
            // for constructing the final summary object from the state it has been tracking.
            state.originalImageDescription = originalImageDescription
            state.endLessonSummary = EndLessonSummary(
                originalImageUrl: state.lessonImageUrl,
                originalImageDescription: originalImageDescription,
                bestUserImageUrl: state.bestUserImageUrl,
                bestUserScore: state.bestUserScore
            )
        }
    }
} 
