
### Runtime: "Failed to get FirebaseApp instance" when opening Event details with mock

- Symptom: App crashes with `Failed to get FirebaseApp instance. Please call FirebaseApp.configure() before using Firestore` when tapping an event in Events (mock mode).
- Cause: `EventDetailView` directly instantiated `FirestoreEventsService()` to fetch sessions, bypassing the mock service and touching Firestore without `FirebaseApp.configure()`.
- Fix: Route all service calls through `EventsViewModel` (which injects `EventsServiceFactory.createService()`), and add `EventsViewModel.getEventSessions(eventId:)`. Updated `EventDetailView.loadEventSessions()` to call the view-model method instead of creating `FirestoreEventsService`.
- Files:
  - `Packages/EventsFeature/Sources/EventsFeature/EventsViewModel.swift` – added `getEventSessions(eventId:)`
  - `Packages/EventsFeature/Sources/EventsFeature/EventDetailView.swift` – replaced direct `FirestoreEventsService()` with `viewModel.getEventSessions(...)`
- Notes: Keep all Firebase usage inside service implementations. Views should not instantiate backend services directly.


