import SwiftUI
import GliteImageLessonService
import LiveKitComponents

/// The root view for the image lesson feature.
///
/// This view observes the `ImageLessonViewModel` and displays the appropriate
/// subview based on the current state of the lesson.
public struct ImageLessonView: View {
    
    @ObservedObject private var viewModel: ImageLessonViewModel
    
    /// Creates a new `ImageLessonView`.
    /// - Parameter viewModel: The view model that drives the view's state.
    public init(viewModel: ImageLessonViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            if viewModel.state.isLessonActive {
                LessonView(viewModel: viewModel)
            } else {
                StartLessonView {
                    viewModel.handle(event: .startLesson)
                }
            }

            if viewModel.state.connectionState == .connecting {
                ConnectingView()
            }

            if let error = viewModel.state.error {
                ErrorView(error: error) {
                    viewModel.handle(event: .dismissError)
                }
            }
        }
        .sheet(item: $viewModel.state.endLessonSummary) { summary in
            EndOfLessonSummaryView(summary: summary) {
                viewModel.handle(event: .dismissSummary)
            }
        }
    }
}