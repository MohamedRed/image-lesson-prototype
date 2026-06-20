import Foundation
import SwiftUI
import Speech
import AVFoundation
import Combine

/// Voice command service for meal planning
public final class VoiceCommandService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isListening = false
    @Published public var isAuthorized = false
    @Published public var lastRecognizedText = ""
    @Published public var error: VoiceError?
    
    // MARK: - Private Properties
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Command Processing
    
    private let commandProcessor = VoiceCommandProcessor()
    
    // MARK: - Publishers
    
    private let commandSubject = PassthroughSubject<VoiceCommand, Never>()
    public var recognizedCommands: AnyPublisher<VoiceCommand, Never> {
        commandSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init() {
        requestPermissions()
    }
    
    // MARK: - Permission Management
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.requestMicrophonePermission()
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                    self?.error = .permissionDenied
                @unknown default:
                    self?.isAuthorized = false
                    self?.error = .unknown
                }
            }
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if !granted {
                    self?.error = .microphonePermissionDenied
                }
            }
        }
    }
    
    // MARK: - Voice Recognition
    
    public func startListening() throws {
        guard isAuthorized else {
            throw VoiceError.permissionDenied
        }
        
        guard !isListening else { return }
        
        try startRecognition()
        isListening = true
        error = nil
    }
    
    public func stopListening() {
        guard isListening else { return }
        
        stopRecognition()
        isListening = false
    }
    
    private func startRecognition() throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.recognitionUnavailable
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true // Privacy-focused
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
    }
    
    private func stopRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.error = .recognitionError(error.localizedDescription)
                self.stopListening()
            }
            return
        }
        
        guard let result = result else { return }
        
        let recognizedText = result.bestTranscription.formattedString
        
        DispatchQueue.main.async {
            self.lastRecognizedText = recognizedText
            
            // Process command if final
            if result.isFinal {
                self.processVoiceCommand(recognizedText)
                self.stopListening()
            }
        }
    }
    
    // MARK: - Command Processing
    
    private func processVoiceCommand(_ text: String) {
        if let command = commandProcessor.parseCommand(from: text) {
            commandSubject.send(command)
            
            // Provide audio feedback
            speakResponse(for: command)
        }
    }
    
    // MARK: - Text-to-Speech
    
    public func speak(_ text: String, rate: Float = 0.5, pitch: Float = 1.0) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        
        speechSynthesizer.speak(utterance)
    }
    
    public func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    private func speakResponse(for command: VoiceCommand) {
        let response = generateResponse(for: command)
        speak(response)
    }
    
    private func generateResponse(for command: VoiceCommand) -> String {
        switch command.type {
        case .startTimer:
            return "Starting timer for \(command.parameters["duration"] ?? "unknown") minutes"
        case .replaceMeal:
            return "I'll help you replace that meal"
        case .searchRecipe:
            return "Searching for \(command.parameters["query"] ?? "recipes")"
        case .addToShoppingList:
            return "Added \(command.parameters["ingredient"] ?? "item") to your shopping list"
        case .getNutrition:
            return "Here's the nutrition information you requested"
        case .askAI:
            return "Let me check that for you"
        case .unknown:
            return "I didn't understand that command. Try again."
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopListening()
    }
}

// MARK: - Voice Command Models

public enum VoiceCommandType {
    case startTimer
    case replaceMeal
    case searchRecipe
    case addToShoppingList
    case getNutrition
    case askAI
    case unknown
}

public struct VoiceCommand {
    public let type: VoiceCommandType
    public let originalText: String
    public let parameters: [String: String]
    public let confidence: Float
}

public enum VoiceError: LocalizedError {
    case permissionDenied
    case microphonePermissionDenied
    case recognitionUnavailable
    case recognitionError(String)
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission denied"
        case .microphonePermissionDenied:
            return "Microphone access denied"
        case .recognitionUnavailable:
            return "Speech recognition is not available"
        case .recognitionError(let message):
            return "Recognition error: \(message)"
        case .unknown:
            return "Unknown voice error occurred"
        }
    }
}

// MARK: - Command Parser

final class VoiceCommandProcessor {
    
    // Command patterns for recognition
    private let patterns: [(pattern: String, type: VoiceCommandType)] = [
        ("start timer for (\\d+) minutes?", .startTimer),
        ("set timer (\\d+) minutes?", .startTimer),
        ("timer (\\d+)", .startTimer),
        ("replace (.*) meal", .replaceMeal),
        ("change (.*) meal", .replaceMeal),
        ("swap (.*) meal", .replaceMeal),
        ("search for (.*)", .searchRecipe),
        ("find (.*) recipe", .searchRecipe),
        ("look for (.*)", .searchRecipe),
        ("add (.*) to shopping list", .addToShoppingList),
        ("buy (.*)", .addToShoppingList),
        ("what.*nutrition", .getNutrition),
        ("how many calories", .getNutrition),
        ("nutritional information", .getNutrition),
        ("hey assistant", .askAI),
        ("ask ai", .askAI)
    ]
    
    func parseCommand(from text: String) -> VoiceCommand? {
        let cleanText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        for (pattern, commandType) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(cleanText.startIndex..., in: cleanText)
                if let match = regex.firstMatch(in: cleanText, options: [], range: range) {
                    
                    var parameters: [String: String] = [:]
                    
                    // Extract parameters based on command type
                    switch commandType {
                    case .startTimer:
                        if match.numberOfRanges > 1 {
                            let durationRange = match.range(at: 1)
                            if let range = Range(durationRange, in: cleanText) {
                                parameters["duration"] = String(cleanText[range])
                            }
                        }
                    case .replaceMeal, .searchRecipe:
                        if match.numberOfRanges > 1 {
                            let queryRange = match.range(at: 1)
                            if let range = Range(queryRange, in: cleanText) {
                                parameters["query"] = String(cleanText[range])
                            }
                        }
                    case .addToShoppingList:
                        if match.numberOfRanges > 1 {
                            let ingredientRange = match.range(at: 1)
                            if let range = Range(ingredientRange, in: cleanText) {
                                parameters["ingredient"] = String(cleanText[range])
                            }
                        }
                    default:
                        break
                    }
                    
                    return VoiceCommand(
                        type: commandType,
                        originalText: text,
                        parameters: parameters,
                        confidence: 0.8 // Simplified confidence score
                    )
                }
            }
        }
        
        return VoiceCommand(
            type: .unknown,
            originalText: text,
            parameters: [:],
            confidence: 0.1
        )
    }
}

// MARK: - SwiftUI Integration

public struct VoiceCommandButton: View {
    @StateObject private var voiceService = VoiceCommandService()
    let onCommand: (VoiceCommand) -> Void
    
    public init(onCommand: @escaping (VoiceCommand) -> Void) {
        self.onCommand = onCommand
    }
    
    public var body: some View {
        Button {
            if voiceService.isListening {
                voiceService.stopListening()
            } else {
                try? voiceService.startListening()
            }
        } label: {
            Image(systemName: voiceService.isListening ? "mic.fill" : "mic")
                .font(.title2)
                .foregroundColor(voiceService.isListening ? .red : .blue)
                .scaleEffect(voiceService.isListening ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: voiceService.isListening)
        }
        .voiceCommandAccessibility()
        .disabled(!voiceService.isAuthorized)
        .onReceive(voiceService.recognizedCommands) { command in
            onCommand(command)
        }
        .alert("Voice Error", isPresented: .constant(voiceService.error != nil)) {
            Button("OK") {
                voiceService.error = nil
            }
        } message: {
            if let error = voiceService.error {
                Text(error.localizedDescription)
            }
        }
    }
}