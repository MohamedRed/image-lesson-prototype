#if DEBUG

import SwiftUI
import LiveKit
import GliteImageLessonService

public struct ImageLessonView_Previews_Wrapper: View {
    @StateObject private var viewModel: ImageLessonViewModel
    private let mockService: MockImageLessonService
    @State private var colorScheme: ColorScheme = .light

    public init() {
        let service = MockImageLessonService()
        self.mockService = service
        _viewModel = StateObject(wrappedValue: ImageLessonViewModel(service: service))
    }

    public var body: some View {
        VStack {
            ImageLessonView(viewModel: viewModel)
            
            // Simplified controls for previewing different states
            if viewModel.state.isLessonActive {
                VStack {
                    Text("Preview Controls").font(.headline).padding(.top)
                    HStack {
                        Button("Agent Speaks") {
                            mockService.simulate(event: .agentSaid("This is a test sentence from the agent.", isFinal: true))
                            if !viewModel.state.isChatSheetPresented {
                                viewModel.handle(event: .toggleChatSheet)
                            }
                        }
                        Button("Show Image") {
                            mockService.simulate(event: .showLessonImage(url: URL(string: "https://picsum.photos/200")!))
                        }
                        Button("End Lesson") {
                            // In the new architecture, the service just signals that the lesson has ended.
                            // The ViewModel is responsible for creating the summary from its own state.
                            // To make this preview work, we pre-populate the state before ending.
                            viewModel.state.lessonImageUrl = URL(string: "https://picsum.photos/seed/lesson/400")
                            viewModel.state.bestUserImageUrl = URL(string: "https://picsum.photos/seed/user/400")
                            viewModel.state.bestUserScore = 0.88
                            
                            mockService.simulate(event: .lessonEnded(originalImageDescription: "A beautiful landscape with mountains and a lake."))
                        }
                    }
                    HStack {
                        Button("Add Chat Transcript") {
                            mockService.simulate(event: .agentSaid("Hello! Let's talk about this image.", isFinal: true))
                            mockService.simulate(event: .userSaid("Okay, what do you want to know?", isFinal: true))
                            mockService.simulate(event: .agentSaid("What is the main color of the object?", isFinal: true))
                            if !viewModel.state.isChatSheetPresented {
                                viewModel.handle(event: .toggleChatSheet)
                            }
                        }
                        Button("Toggle Dark Mode") {
                            colorScheme = (colorScheme == .light) ? .dark : .light
                        }
                    }
                }
            }
        }
        .preferredColorScheme(colorScheme)
        .onAppear {
            // On appear, provide a silent audio track for the agent to ensure the visualizer renders.
            let agentTrack = LocalAudioTrack.createTrack(name: "mock-agent-mic")
            mockService.simulate(agentAudioTrack: agentTrack)
            
            // Add mock chat messages for preview
            mockService.simulate(event: .agentSaid("Hello! Let's talk about this image.", isFinal: true))
            mockService.simulate(event: .userSaid("Okay, what do you want to know?", isFinal: true))
            mockService.simulate(event: .agentSaid("What is the main color of the object?", isFinal: true))
        }
    }
}

public struct ImageLessonView_Previews: PreviewProvider {
    public static var previews: some View {
        ImageLessonView_Previews_Wrapper()
    }
}

#Preview("Default State") {
    ImageLessonView_Previews_Wrapper()
}

#Preview("Connecting State") {
    // This preview demonstrates the view while it's in the connecting state.
    // We achieve this by creating a view model with a custom initial state.
    let viewModel: ImageLessonViewModel = {
        var initialState = ImageLessonViewModel.State()
        initialState.isLessonActive = true
        initialState.connectionState = .connecting
        
        return ImageLessonViewModel(
            initialState: initialState,
            service: MockImageLessonService()
        )
    }()
    
    return ImageLessonView(viewModel: viewModel)
}

#endif
