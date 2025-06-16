# Glite iOS Image Lesson Prototype

This repository contains the standalone iOS prototype for the "Image Lesson" feature. It is a self-contained Xcode project with all necessary dependencies included as local Swift Packages.

## How to Run

1.  **Configure the API Endpoint:**
    *   In the Xcode Project Navigator, find the `image-lesson-prototype` folder and open the `Info.plist` file within it.
    *   Add a new key (or row) with the name **`API_BASE_URL`**.
    *   Set its value (as a `String`) to the URL of your backend server.

2.  **Build and Run:**
    *   Open `image-lesson-prototype.xcodeproj` in Xcode (version 15.3 or later is recommended).
    *   Select a target iOS Simulator (e.g., iPhone 15 Pro).
    *   Build and run the project (Cmd+R).

**Note:** If the `API_BASE_URL` is missing from the `Info.plist`, the app will display a specific configuration error on launch.

## Development & Previews

For rapid UI development, the project is set up with comprehensive SwiftUI Previews.

To see the main interactive preview with controls for simulating different app states, open the following file in Xcode:
`Packages/GliteImageLessonFeature/Sources/GliteImageLessonFeature/ImageLessonView+Previews.swift`

This is the best place to visualize and test individual components without running the full application. This modular design allows the UI to be developed and tested independently of the live backend.

## Project Structure

The project is designed to be the root of a Git repository.

-   **/image-lesson-prototype.xcodeproj**: The Xcode project file.
-   **/Packages**: This folder contains local Swift Packages.
    -   **GliteImageLessonFeature**: Contains all UI (SwiftUI) and view model logic for the lesson.
    -   **GliteImageLessonService**: Contains the networking layer and mock service for the lesson.

This structure separates the main application from its feature and service dependencies, promoting modularity. 