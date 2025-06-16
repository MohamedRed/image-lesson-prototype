import SwiftUI
import LiveKit
import LiveKitComponents

/// A button that toggles the user's microphone on and off.
///
/// This view displays a microphone icon and, when the microphone is enabled,
/// an audio visualizer that reflects the user's local audio track. It is
/// disabled when the lesson is not fully connected.
struct MicrophoneButton: View {
    
    // MARK: - Constants
    private enum Constants {
        static let enabledIcon = "microphone.fill"
        static let disabledIcon = "microphone.slash.fill"
        static let buttonSpacing: CGFloat = 8
        static let visualizerWidth: CGFloat = 20
        static let visualizerHeight: CGFloat = 15
        static let visualizerBarCount: Int = 3
        static let visualizerBarSpacing: CGFloat = 0.2
    }
    
    // MARK: - Properties
    @ObservedObject var viewModel: ImageLessonViewModel
    
    var body: some View {
        Button(action: {
            viewModel.handle(event: .toggleMicrophone)
        }) {
            HStack(spacing: Constants.buttonSpacing) {
                Image(systemName: viewModel.state.isMicrophoneEnabled ? Constants.enabledIcon : Constants.disabledIcon)
                    .symbolTransitionIfAvailable()
                
                if let track = viewModel.state.audioTrack as? LocalAudioTrack {
                    BarAudioVisualizer(
                        audioTrack: track,
                        barColor: .white,
                        barCount: Constants.visualizerBarCount,
                        barSpacingFactor: Constants.visualizerBarSpacing
                    )
                    .frame(
                        width: Constants.visualizerWidth,
                        height: Constants.visualizerHeight
                    )
                }
            }
            .padding()
            .background(viewModel.state.isMicrophoneEnabled ? Theme.accent : Theme.controlDisabled)
            .foregroundColor(.white)
            .cornerRadius(Theme.cornerRadius)
        }
        .disabled(viewModel.state.connectionState != .connected)
    }
}

#if DEBUG
#Preview("Microphone Off") {
    let viewModel: ImageLessonViewModel = {
        var initialState = ImageLessonViewModel.State()
        initialState.connectionState = .connected
        initialState.isMicrophoneEnabled = false
        return ImageLessonViewModel(initialState: initialState, service: MockImageLessonService())
    }()
    
    return MicrophoneButton(viewModel: viewModel)
        .padding()
        .background(Color.black)
}

#Preview("Microphone On") {
    let viewModel: ImageLessonViewModel = {
        var initialState = ImageLessonViewModel.State()
        initialState.connectionState = .connected
        initialState.isMicrophoneEnabled = true
        initialState.audioTrack = LocalAudioTrack.createTrack(name: "mock-mic")
        return ImageLessonViewModel(initialState: initialState, service: MockImageLessonService())
    }()
    
    return MicrophoneButton(viewModel: viewModel)
        .padding()
        .background(Color.black)
}

#Preview("Microphone On (No Track)") {
    let viewModel: ImageLessonViewModel = {
        var initialState = ImageLessonViewModel.State()
        initialState.connectionState = .connected
        initialState.isMicrophoneEnabled = true
        initialState.audioTrack = nil // Explicitly nil
        return ImageLessonViewModel(initialState: initialState, service: MockImageLessonService())
    }()
    
    return MicrophoneButton(viewModel: viewModel)
        .padding()
        .background(Color.black)
}
#endif

// Conditional symbolEffect transition wrapper
private extension View {
    /// Applies the `.symbolEffect` transition modifier if running on iOS 17 or later.
    /// On older systems, it returns the view unmodified.
    @ViewBuilder
    func symbolTransitionIfAvailable() -> some View {
        if #available(iOS 17, *) {
            self.transition(.symbolEffect)
        } else {
            self
        }
    }
} 