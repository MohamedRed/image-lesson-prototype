# GliteImageLessonService

This Swift Package provides the networking and backend service layer for the **Image-Lesson** prototype feature. It conforms to the `GliteImageLessonServicing` protocol defined in the `GliteImageLessonFeature` package.

## Purpose

The primary role of this package is to encapsulate all interactions with the LiveKit SDK and any other backend services. It handles:

-   Connecting and disconnecting from a LiveKit room.
-   Publishing and subscribing to audio tracks.
-   Sending and receiving all RPC messages and data packets.
-   Decoding backend payloads into concrete types.

By isolating this logic, the main feature package (`GliteImageLessonFeature`) remains completely independent of the underlying network implementation.

## Public API

The package's public interface is the `GliteImageLessonServicing` protocol. A concrete implementation, `LiveKitService`, is provided.

```swift
public protocol GliteImageLessonServicing {
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
    var lessonEvents: AnyPublisher<LessonEvent, Never> { get }
    // ... other publishers and methods
    
    func start() async throws
    func stop()
}
```

This allows for easy mocking and testing, as any object conforming to the protocol can be injected into the feature's ViewModel.
