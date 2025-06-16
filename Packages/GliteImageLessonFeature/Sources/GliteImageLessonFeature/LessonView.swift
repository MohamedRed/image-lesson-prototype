import SwiftUI
import GliteImageLessonService
import LiveKit
import LiveKitComponents

/// The main view for an active image-based lesson.
///
/// This view is responsible for displaying the agent's audio visualizer, the lesson image,
/// the user's captured image, and the primary user controls for interacting with the lesson.
struct LessonView: View {
    
    // MARK: - Constants
    private enum Constants {
        static let connectionStatusFont: Font = .caption
        static let highlightedWordFont: Font = .largeTitle.weight(.semibold)
        static let chatButtonIcon = "bubble.left.and.bubble.right"
        static let leaveButtonText = "Leave"
    }
    
    @ObservedObject var viewModel: ImageLessonViewModel
    
    var body: some View {
        VStack(spacing: Theme.mainSpacing) {
            topContent
            middleContent
            bottomControls
        }
        .padding()
        .sheet(isPresented: $viewModel.state.isChatSheetPresented) {
            ChatView(messages: viewModel.state.chatMessages) {
                viewModel.handle(event: .toggleChatSheet)
            }
        }
    }

    // MARK: - Private View Components

    private var topContent: some View {
        Text(viewModel.state.connectionState.description)
            .font(Constants.connectionStatusFont)
            .foregroundColor(.secondary)
    }

    private var middleContent: some View {
        VStack(spacing: Theme.mainSpacing) {
            GeometryReader { middleStackGeometry in
                VStack(spacing: Theme.mainSpacing) {
                    BarAudioVisualizer(audioTrack: viewModel.state.agentAudioTrack as? AudioTrack)
                        .frame(height: middleStackGeometry.size.height * Theme.visualizerHeightRatio)

                    ImagePlaceholderView(url: viewModel.state.lessonImageUrl, title: "Lesson Image")
                        .frame(maxHeight: .infinity)
                        .overlay(
                            VStack {
                                if let word = viewModel.state.highlightedWord {
                                    Text(word)
                                        .font(Constants.highlightedWordFont)
                                        .bold()
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Theme.overlay)
                                        .cornerRadius(Theme.cornerRadius)
                                }
                            }
                        )
                    ImagePlaceholderView(url: viewModel.state.userImageUrl, title: "Your Image", isLoading: viewModel.state.userImageIsLoading)
                        .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(maxHeight: .infinity) // Ensure the group fills available space
        .padding(.bottom, Theme.contentControlSpacing)
    }

    private var bottomControls: some View {
        HStack(spacing: Theme.controlButtonSpacing) {
            MicrophoneButton(viewModel: viewModel)

            Button(action: {
                viewModel.handle(event: .toggleChatSheet)
            }) {
                Image(systemName: Constants.chatButtonIcon)
                    .padding()
                    .background(Theme.accent)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }

            Button(action: {
                viewModel.handle(event: .leaveLesson)
            }) {
                Text(Constants.leaveButtonText)
                    .padding()
                    .background(Theme.destructive)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.cornerRadius)
            }
        }
    }
}

#if DEBUG
#Preview {
    let viewModel: ImageLessonViewModel = {
        var initialState = ImageLessonViewModel.State()
        initialState.isLessonActive = true
        initialState.connectionState = .connected
        initialState.lessonImageUrl = URL(string: "https://picsum.photos/seed/lesson/400")
        initialState.userImageUrl = URL(string: "https://picsum.photos/seed/user/400")
        initialState.highlightedWord = "Mountains"
        
        let service = MockImageLessonService()
        let agentTrack = LocalAudioTrack.createTrack(name: "mock-agent-mic")
        service.simulate(agentAudioTrack: agentTrack)
        
        return ImageLessonViewModel(
            initialState: initialState,
            service: service
        )
    }()
    
    return LessonView(viewModel: viewModel)
}
#endif 