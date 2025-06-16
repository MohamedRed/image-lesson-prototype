import SwiftUI
import GliteImageLessonService

// The only public entry-point for the feature module.
public enum ImageLessonViewFactory {
    /// Builds the Image-lesson feature root view wrapped as `AnyView` so the host
    /// application can present it without knowing concrete types.
    ///
    /// - Parameter service: A concrete object that conforms to `GliteImageLessonServicing`.
    /// - Returns: An `AnyView` ready to be embedded in the host app's UI hierarchy.
    @MainActor public static func make(service: GliteImageLessonServicing) -> AnyView {
        let viewModel = ImageLessonViewModel(service: service)
        return AnyView(ImageLessonView(viewModel: viewModel))
    }
} 