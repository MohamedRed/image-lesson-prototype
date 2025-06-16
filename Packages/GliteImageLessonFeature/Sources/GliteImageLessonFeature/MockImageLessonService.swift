#if DEBUG

import Combine
import Foundation
import GliteImageLessonService
import LiveKit

// Disambiguate our connection state from LiveKit.ConnectionState
typealias LessonConnState = GliteImageLessonService.ConnectionState

/// A test double that fulfils `GliteImageLessonServicing` without touching the network.
final class MockImageLessonService: GliteImageLessonServicing {
    // MARK: - Subjects
    private let _connectionState = CurrentValueSubject<LessonConnState, Never>(.disconnected)
    private let _lessonEvents    = PassthroughSubject<LessonEvent, Never>()
    private let _isMicEnabled    = CurrentValueSubject<Bool, Never>(false)
    private let _audioTrack      = CurrentValueSubject<Track?, Never>(nil)
    private let _agentAudioTrack = CurrentValueSubject<Track?, Never>(nil)

    /// Initializes a new mock service instance.
    init() {}

    // MARK: - GliteImageLessonServicing
    var connectionState: AnyPublisher<LessonConnState, Never> { _connectionState.eraseToAnyPublisher() }
    var lessonEvents: AnyPublisher<LessonEvent, Never>      { _lessonEvents.eraseToAnyPublisher() }
    var isMicrophoneEnabled: AnyPublisher<Bool, Never>      { _isMicEnabled.eraseToAnyPublisher() }
    var audioTrack: AnyPublisher<Track?, Never>             { _audioTrack.eraseToAnyPublisher() }
    var agentAudioTrack: AnyPublisher<Track?, Never>        { _agentAudioTrack.eraseToAnyPublisher() }

    func start() async throws {
        // Give callers a chance to attach their Combine subscriptions first.
        await Task.yield()
        _connectionState.send(.connected)
    }

    func stop() {
        _connectionState.send(.disconnected)
    }

    func toggleMicrophone() async {
        let isEnabled = !_isMicEnabled.value
        _isMicEnabled.send(isEnabled)
        
        if isEnabled {
            // When enabling the microphone in the mock, create a mock audio track
            // so that the UI can display the user's audio visualizer.
            let track = LocalAudioTrack.createTrack(name: "mock-user-mic")
            _audioTrack.send(track)
        } else {
            // When disabling, remove the track.
            _audioTrack.send(nil)
        }
    }

    // MARK: - Simulation Methods

    /// Injects a `LessonEvent` into the service, simulating an event received from the backend.
    /// - Parameter event: The `LessonEvent` to simulate.
    func simulate(event: LessonEvent) {
        _lessonEvents.send(event)
    }

    /// Injects a `ConnectionState` into the service, simulating a change in the connection status.
    /// - Parameter connectionState: The `ConnectionState` to simulate.
    func simulate(connectionState: LessonConnState) {
        _connectionState.send(connectionState)
    }
    
    /// Injects a microphone state into the service.
    /// - Parameter isMicrophoneEnabled: The microphone state to simulate.
    func simulate(isMicrophoneEnabled: Bool) {
        _isMicEnabled.send(isMicrophoneEnabled)
    }

    /// Injects a new `Track` for the agent's audio, used for UI previews of the visualizer.
    /// - Parameter agentAudioTrack: The `Track` to simulate for the agent.
    func simulate(agentAudioTrack: Track) {
        _agentAudioTrack.send(agentAudioTrack)
    }
}

#endif
