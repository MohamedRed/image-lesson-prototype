import SwiftUI
import Speech
import AVFoundation
import AccommodationsService

struct VoiceInputView: View {
    @EnvironmentObject private var viewModel: AccommodationsViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceManager = VoiceInputManager()
    @State private var transcript = ""
    @State private var isListening = false
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                headerSection
                visualizerSection
                transcriptSection
                actionButtons
                
                Spacer()
            }
            .padding()
            .navigationTitle("Voice Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                voiceManager.requestPermissions { granted in
                    if !granted {
                        showingPermissionAlert = true
                    }
                }
            }
            .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Please enable microphone access in Settings to use voice search.")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Tell me what you're looking for")
                .font(.title2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
            
            Text("Try saying: \"Find a hotel in Paris for next weekend\" or \"Show me apartments with a pool\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var visualizerSection: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: isListening ? [.accentColor.opacity(0.3), .accentColor.opacity(0.1)] : [.gray.opacity(0.2)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(isListening ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isListening)
            
            Button {
                if isListening {
                    stopListening()
                } else {
                    startListening()
                }
            } label: {
                Image(systemName: isListening ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(isListening ? .red : .accentColor)
            }
            .scaleEffect(isListening ? 1.1 : 1.0)
            .animation(.spring(), value: isListening)
        }
    }
    
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !transcript.isEmpty {
                Text("You said:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(transcript)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            } else if isListening {
                Text("Listening...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                Text("Tap the microphone to start")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut, value: transcript)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !transcript.isEmpty {
                Button("Search") {
                    processTranscript()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Try Again") {
                    transcript = ""
                    startListening()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func startListening() {
        isListening = true
        
        voiceManager.startRecording { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transcriptText):
                    transcript = transcriptText
                    isListening = false
                case .failure(let error):
                    print("Voice recognition error: \(error)")
                    isListening = false
                }
            }
        }
    }
    
    private func stopListening() {
        isListening = false
        voiceManager.stopRecording()
    }
    
    private func processTranscript() {
        viewModel.processVoiceInput(transcript)
        dismiss()
    }
}

// MARK: - Voice Input Manager

@MainActor
class VoiceInputManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var completion: ((Result<String, Error>) -> Void)?
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            completion(granted)
                        }
                    }
                default:
                    completion(false)
                }
            }
        }
    }
    
    func startRecording(completion: @escaping (Result<String, Error>) -> Void) {
        guard speechRecognizer?.isAvailable == true else {
            completion(.failure(VoiceError.speechRecognizerUnavailable))
            return
        }
        
        self.completion = completion
        
        do {
            try setupAudioSession()
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else {
                completion(.failure(VoiceError.recognitionRequestFailed))
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            if #available(iOS 16, *) {
                recognitionRequest.addsPunctuation = true
            }
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let error = error {
                    completion(.failure(error))
                    self.stopRecording()
                    return
                }
                
                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        completion(.success(transcript))
                        self.stopRecording()
                    }
                }
            }
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
        } catch {
            completion(.failure(error))
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
}

enum VoiceError: LocalizedError {
    case speechRecognizerUnavailable
    case recognitionRequestFailed
    case microphoneAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .speechRecognizerUnavailable:
            return "Speech recognizer is not available"
        case .recognitionRequestFailed:
            return "Failed to create recognition request"
        case .microphoneAccessDenied:
            return "Microphone access denied"
        }
    }
}

#Preview {
    VoiceInputView()
        .environmentObject(AccommodationsViewModel())
}