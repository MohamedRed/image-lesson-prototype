# **Glite LiveKit Voice-Lesson Prototype iOS Styleguide**

### **Introduction**

Use this document as the sole reference for building iOS feature modules. It describes *how* we write code, not the code itself, so you can work without access to our main repository. Follow every section, and the feature you build will compile, lint-clean, match our look-and-feel, and require minimal glue code when we merge it.

### **1\. Project Topology**

* **Modular Design:** Each new feature must be delivered as two distinct Swift Package Manager (SPM) targets:  
  * **Feature Target:** Contains all SwiftUI views, ViewModels, navigation logic, and unit tests.  
  * **Service Target:** Contains all low-level platform or network interaction (e.g., SDKs, URLSession, Core Bluetooth, AVFoundation).  
* **Dependencies:** External dependencies may only be added via SPM and must be pre-approved. External services communication dependencies must be declared in GliteData and confirming common protocol from GliteCore.  
* **Entry Point:** The feature target must expose a factory that returns its root SwiftUI view as an AnyView. The host application will use this to present the feature. The `ViewFactory` must be the only public class available in the feature module.

### **2\. Architectural Patterns**

* **MVVM with Combine & Swift Concurrency:**  
  * A SwiftUI View renders its UI *solely* from a @Published state enum held by its ObservableObject ViewModel.  
  * The ViewModel exposes a single handle(event:) method that accepts cases from a nested Event enum sent by the View.  
  * All asynchronous work must use async/await or Combine framework. Results and streams are surfaced to the ViewModel through Combine Publishers or AsyncStream.  
* **Dependency Injection:**  
  * Wrap all platform, SDK, or network logic behind a Service protocol that lives in the \`GliteCore/Services\` folder.  
  * ViewModels must receive dependencies in their initializer. They must never construct or look up services themselves.  
* **Navigation Contract:**  
  * Do not call UIKit navigation APIs (e.g., pushViewController, present) from inside the feature.  
  * The feature's view factory provides the UI; a global coordinator owned by the host app will decide how and where it appears.  
  * Push navigation should be implemented by using GenericNavigationRouter while present navigation can be done inplace with .sheet or .fullscreen SwiftUI modifiers.  
  * 

### **3\. Coding Standards**

* **Formatting:** 2-space indentation; maximum 120-character lines. We will provide our .editorconfig file.  
* **Linting:** We will provide our .swiftlint.yml file. New code must build without any warnings, and you must treat all linter issues as build errors.  
* **Code Organization:** Mark classes final unless subclassing is intentional. Use // MARK: \- separators for logical code blocks and keep magic numbers or strings inside a private enum Constants.

### **4\. Theming & Assets**

* **Dark Mode First:** All UI must be designed and tested to look correct in Dark Mode. Do not assume light backgrounds.  
* **Design Tokens:** All colors, fonts, spacing, and corner radii must come from an injected design-token struct (e.g., Theme). We will provide this struct. **Never hard-code values** like Color.red or .font(.headline).  
* **Assets:** Images are defined in AppResources module and can be accessed via R.image property.. Do not use string literals. **SF Symbols** are ideal for temporary placeholders.

### **5\. Service Contract Template**

Your service protocols should be clean, focused, and asynchronous.

Swift

```

public protocol FeatureService: Sendable {
  // A stream of state updates
  var connectionState: AnyPublisher<ConnectionState, Never> { get }

  // A stream of data items
  var items: AnyPublisher<[Item], Never> { get }

  // Asynchronous actions
  @MainActor func start(with credentials: Credentials) async throws
  @MainActor func stop()
  @MainActor func setEnabled(_ enabled: Bool)
}

```

### **6\. Shared System Resource Etiquette**

The host app manages global system state. Your feature must act as a good citizen.

* If your feature needs access to the camera, microphone, AVAudioSession, Bluetooth, etc., it must declare this "intent" through its service protocol (e.g., a requestRecordingPermissions() function).  
* **Do not set global system state directly.** The host application will receive the intent and mediate potential conflicts with other features.

### **7\. Error Propagation**

* Report unrecoverable errors (e.g., invalid tokens, permission denied, server errors) through a global error-bus interface that we will provide.  
* For debugging purposes Logging can be used which uses OSLog implicitly

### **8\. Bridging UIKit (Edge Cases)**

If you must host a UIView from a third-party framework:

* Wrap it in a UIViewRepresentable to keep your feature's UI layer pure SwiftUI.  
* All UIKit wrapper code belongs in the Service target, not the Feature target.  
* If you need a UIKit container (like UINavigationController) for demonstration purposes, wrap your root view in a UIHostingController, but keep that setup code outside the feature module itself.

### **9\. Testing**

* Provide a **mock implementation** of your service protocol that simulates events without needing a network or hardware.  
* Provide **Unit Tests** for your ViewModel's state machine.  
* Use the mock service in **SwiftUI Previews** to enable fast, offline UI iteration.

### **10\. Deliverables Checklist**

The work is complete when this checklist is satisfied:

* \[ \] Feature and Service targets compile without warnings in the latest stable Xcode.  
* \[ \] swiftlint passes with zero violations.  
* \[ \] All unit tests pass.  
* \[ \] A README.md file includes build steps, dependency versions, and any known limitations.  
* \[ \] All public types, properties, and methods have concise Markdown documentation comments.

