# GliteImageLessonFeature

This Swift Package delivers the **Image-Lesson** prototype feature as a
self-contained module that follows the Glite iOS style-guide.

## Public API

```swift
import GliteImageLessonFeature
import GliteImageLessonService

let view = ImageLessonViewFactory.make(service: LiveKitService())
```

`ImageLessonViewFactory.make(service:) -> AnyView` is the *only* public
symbol.  Supply any object that conforms to `GliteImageLessonServicing`
and embed the returned `AnyView` anywhere in your SwiftUI hierarchy.

## Architecture (MVVM)

```
View           ← state   ┌──────────────┐
│  ┌──────────────┐      │    Service   │
│  │  ViewModel   │──▸   │ (LiveKit etc)│
│  └──────────────┘      └──────────────┘
│        ▲   │  events
└────────┘   └───────────────────────────
```

* **View** — SwiftUI; renders exclusively from `@Published state`.
* **ViewModel** — pure logic; exposes `handle(event:)` for the view and
  subscribes to publishers supplied by the Service.
* **Service** — concrete implementation of `GliteImageLessonServicing`
  (e.g. `LiveKitService`) wraps all SDK/network details.

## Design Constants

Visual style is centralised in `Theme.swift` and numeric "magic numbers"
in `Metrics.swift`.  *Never hard-code colours or layout constants inside
views.*

## Testing

A lightweight `MockImageLessonService` lives inside the package and can
simulate all lesson events. Use it in unit tests or Xcode previews:

```swift
let mock = MockImageLessonService()
let view  = ImageLessonViewFactory.make(service: mock)
```

## Linting

Run `swiftlint` from the repository root. The package is configured to
be warning-free. If you add code, fix or suppress new violations before
committing.
