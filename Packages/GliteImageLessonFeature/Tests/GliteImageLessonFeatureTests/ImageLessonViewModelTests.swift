import XCTest
import GliteImageLessonService
import Combine
@testable import GliteImageLessonFeature

// MARK: - ImageLessonViewModel unit tests

// NOTE: Test class is NOT @MainActor isolated.
// This is crucial because we use `wait(for:timeout:)`, which blocks the current thread.
// If this test ran on the main thread, it would deadlock with the view model,
// which needs the main thread to update its state.
final class ImageLessonViewModelTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        super.tearDown()
    }

    func testStartLessonSetsActiveAndConnected() async throws {
        // Given a fresh view-model wired to the mock service
        let mockService = await MockImageLessonService()
        let viewModel   = await ImageLessonViewModel(service: mockService)

        // Prepare expectation BEFORE triggering the event to ensure we don't miss the value.
        let expectation = XCTestExpectation(description: "Connection state becomes .connected")
        
        // Subscription must be set up on the main actor because the view model is isolated to it.
        await MainActor.run {
            viewModel.$state
                .map(\.connectionState)
                .first(where: { $0 == .connected })
                .sink { _ in
                    expectation.fulfill()
                }
                .store(in: &cancellables)
        }

        // When the user starts a lesson
        await viewModel.handle(event: .startLesson)
        
        // Wait for the published connection state to update.
        await fulfillment(of: [expectation], timeout: 2)

        // Then state reflects an active session flag
        let isActive = await viewModel.state.isLessonActive
        XCTAssertTrue(isActive, "Lesson should be marked active after start event")
    }

    func testLeaveLessonResetsLessonActiveFlag() async throws {
        let mockService = await MockImageLessonService()
        let viewModel   = await ImageLessonViewModel(service: mockService)
        
        // Given the lesson is active
        await viewModel.handle(event: .startLesson)
        
        // We need to wait for the connection to be established before proceeding
        let expectation = XCTestExpectation(description: "Connection state becomes .connected")
        await MainActor.run {
            viewModel.$state
                .map(\.connectionState)
                .first(where: { $0 == .connected })
                .sink { _ in
                    expectation.fulfill()
                }
                .store(in: &cancellables)
        }
        await fulfillment(of: [expectation], timeout: 2)
        
        let isInitiallyActive = await viewModel.state.isLessonActive
        XCTAssertTrue(isInitiallyActive)

        // When the user disconnects
        await viewModel.handle(event: .leaveLesson)

        // Then the lesson is no longer active
        let isFinallyActive = await viewModel.state.isLessonActive
        XCTAssertFalse(isFinallyActive, "LessonActive should be false after disconnect")
    }

    func testToggleChatSheetChangesPresentationState() async {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        
        // Initial state is false
        let isInitiallyPresented = await viewModel.state.isChatSheetPresented
        XCTAssertFalse(isInitiallyPresented, "Chat sheet should initially be hidden.")
        
        // When
        await viewModel.handle(event: .toggleChatSheet)
        
        // Then
        let isPresentedAfterFirstToggle = await viewModel.state.isChatSheetPresented
        XCTAssertTrue(isPresentedAfterFirstToggle, "Chat sheet should be presented after first toggle.")
        
        // When
        await viewModel.handle(event: .toggleChatSheet)
        
        // Then
        let isPresentedAfterSecondToggle = await viewModel.state.isChatSheetPresented
        XCTAssertFalse(isPresentedAfterSecondToggle, "Chat sheet should be hidden after second toggle.")
    }

    func testDismissErrorNilifiesErrorState() async {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        
        // Given an error is present
        let sampleError = URLError(.badServerResponse)
        await MainActor.run {
            viewModel.state.error = sampleError
        }
        let isErrorInitiallyPresent = await viewModel.state.error
        XCTAssertNotNil(isErrorInitiallyPresent, "Error should be present before dismissing.")
        
        // When
        await viewModel.handle(event: .dismissError)
        
        // Then
        let isErrorFinallyPresent = await viewModel.state.error
        XCTAssertNil(isErrorFinallyPresent, "Error should be nil after dismissing.")
    }
    
    func testDismissSummaryResetsState() async {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        
        // Given a summary is present and lesson is active
        let summary = EndLessonSummary(originalImageUrl: nil, originalImageDescription: "", bestUserImageUrl: nil, bestUserScore: nil)
        await MainActor.run {
            viewModel.state.isLessonActive = true
            viewModel.state.endLessonSummary = summary
        }
        
        let initialSummary = await viewModel.state.endLessonSummary
        XCTAssertNotNil(initialSummary, "Summary should be present before dismissing.")
        let initialIsActive = await viewModel.state.isLessonActive
        XCTAssertTrue(initialIsActive, "Lesson should be active before dismissing summary.")
        
        // When
        await viewModel.handle(event: .dismissSummary)
        
        // Then
        let finalSummary = await viewModel.state.endLessonSummary
        XCTAssertNil(finalSummary, "Summary should be nil after dismissing.")
        let finalIsActive = await viewModel.state.isLessonActive
        XCTAssertFalse(finalIsActive, "Lesson should become inactive after dismissing summary.")
    }

    // MARK: - Service Event Handling Tests
    
    func testAgentSaidEventUpdatesTranscriptAndChat() async throws {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        await viewModel.handle(event: .startLesson) // Start the service listeners
        let testMessage = "This is the agent speaking."
        
        // When
        await mockService.simulate(event: .agentSaid(testMessage, isFinal: true))
        
        // Then
        await Task.yield() // Allow the async sink to update the main actor state
        let state = await viewModel.state
        XCTAssertEqual(state.agentTranscript, testMessage, "The agent transcript should be updated.")
        XCTAssertEqual(state.chatMessages.last?.text, testMessage)
        XCTAssertEqual(state.chatMessages.last?.role, .agent)
    }

    func testUserSaidEventUpdatesTranscriptAndChat() async throws {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        await viewModel.handle(event: .startLesson)
        let testMessage = "This is the user speaking."
        
        // When
        await mockService.simulate(event: .userSaid(testMessage, isFinal: true))
        
        // Then
        await Task.yield()
        let state = await viewModel.state
        XCTAssertEqual(state.userTranscript, testMessage, "The user transcript should be updated.")
        XCTAssertEqual(state.chatMessages.last?.text, testMessage)
        XCTAssertEqual(state.chatMessages.last?.role, .user)
    }

    func testShowLessonImageEventUpdatesState() async throws {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        await viewModel.handle(event: .startLesson)
        let testUrl = URL(string: "https://example.com/lesson.jpg")!
        
        // When
        await mockService.simulate(event: .showLessonImage(url: testUrl))
        
        // Then
        await Task.yield()
        let state = await viewModel.state
        XCTAssertEqual(state.lessonImageUrl, testUrl)
    }

    func testShowUserImageEventUpdatesState() async throws {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        await viewModel.handle(event: .startLesson)
        let testUrl = URL(string: "https://example.com/user.jpg")!
        
        // When
        await mockService.simulate(event: .showUserImage(url: testUrl, id: "image-1"))
        
        // Then
        await Task.yield()
        let state = await viewModel.state
        XCTAssertEqual(state.userImageUrl, testUrl)
        XCTAssertFalse(state.userImageIsLoading, "Loading indicator should be turned off.")
    }

    func testShowUserImageEventUpdatesBestScore() async throws {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        await viewModel.handle(event: .startLesson)
        
        // Given a score has already been received
        await mockService.simulate(event: .showSimilarityScore(score: 0.8, bestScore: 0.9, accepted: true))
        await Task.yield() // Allow state to update

        // When a new user image is shown
        let newUserImage = URL(string: "https://example.com/best.jpg")!
        await mockService.simulate(event: .showUserImage(url: newUserImage, id: "image-2"))
        await Task.yield() // Allow state to update

        // Then the best score and image URL should be updated in the state
        let state = await viewModel.state
        XCTAssertEqual(state.bestUserScore, 0.8)
        XCTAssertEqual(state.bestUserImageUrl, newUserImage)
    }

    func testShowSimilarityScoreEventUpdatesState() async throws {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        await viewModel.handle(event: .startLesson)
        
        // When
        await mockService.simulate(event: .showSimilarityScore(score: 0.75, bestScore: 0.9, accepted: true))
        
        // Then
        await Task.yield()
        let state = await viewModel.state
        XCTAssertEqual(state.currentScore, 0.75)
        XCTAssertEqual(state.bestScore, 0.9)
        XCTAssertTrue(state.isAccepted)
    }

    func testShowUserImageLoadingEventUpdatesState() async throws {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        await viewModel.handle(event: .startLesson)
        
        // When
        await mockService.simulate(event: .showUserImageLoading(id: "image-1"))
        
        // Then
        await Task.yield()
        let state = await viewModel.state
        XCTAssertTrue(state.userImageIsLoading, "Loading indicator should be turned on.")
    }

    func testHighlightWordEventUpdatesState() async throws {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        await viewModel.handle(event: .startLesson)
        let testWord = "testing"
        
        // When
        await mockService.simulate(event: .highlightWord(testWord))
        
        // Then
        await Task.yield()
        let state = await viewModel.state
        XCTAssertEqual(state.highlightedWord, testWord)
    }

    func testHighlightWordEventFiltersForbiddenPhrases() async throws {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        await viewModel.handle(event: .startLesson)
        
        // When an allowed word is received
        let allowedWord = "Mountains"
        await mockService.simulate(event: .highlightWord(allowedWord))
        await Task.yield()
        
        // Then the state is updated
        var state = await viewModel.state
        XCTAssertEqual(state.highlightedWord, allowedWord, "An allowed word should be displayed.")

        // When a forbidden phrase is received
        let forbiddenPhrase = "please describe the image"
        await mockService.simulate(event: .highlightWord(forbiddenPhrase))
        await Task.yield()

        // Then the highlighted word should be cleared (nil)
        state = await viewModel.state
        XCTAssertNil(state.highlightedWord, "A forbidden phrase should clear the highlighted word.")
    }

    func testLessonEndedEventCreatesSummaryFromState() async throws {
        // Given
        let mockService = await MockImageLessonService()
        let viewModel = await ImageLessonViewModel(service: mockService)
        await viewModel.handle(event: .startLesson)
        
        // Given the view model has been tracking state throughout a lesson
        let lessonUrl = URL(string: "https://example.com/lesson.jpg")!
        let bestUserUrl = URL(string: "https://example.com/best-user.jpg")!
        await MainActor.run {
            viewModel.state.lessonImageUrl = lessonUrl
            viewModel.state.bestUserImageUrl = bestUserUrl
            viewModel.state.bestUserScore = 0.95
        }
        
        // When the lesson ended event is received with the final piece of info
        let description = "The final description"
        await mockService.simulate(event: .lessonEnded(originalImageDescription: description))
        
        // Then a summary object should be created in the state from the tracked properties
        await Task.yield()
        let state = await viewModel.state
        XCTAssertNotNil(state.endLessonSummary)
        XCTAssertEqual(state.endLessonSummary?.originalImageUrl, lessonUrl)
        XCTAssertEqual(state.endLessonSummary?.bestUserImageUrl, bestUserUrl)
        XCTAssertEqual(state.endLessonSummary?.bestUserScore, 0.95)
        XCTAssertEqual(state.endLessonSummary?.originalImageDescription, description)
    }
} 
