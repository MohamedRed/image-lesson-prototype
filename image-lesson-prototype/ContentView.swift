//
//  ContentView.swift
//  image-lesson-prototype
//
//  Created by MRR on 2025-06-12.
//

import SwiftUI
import GliteImageLessonService
import GliteImageLessonFeature

struct ContentView: View {
    
    // MARK: - View State
    
    // The host application is responsible for managing the initialization of the feature.
    // This enum represents the possible states: loading the configuration, successfully
    // creating the feature's view, or failing due to a configuration error.
    private enum ViewState {
        case loading
        case ready(AnyView)
        case error(Error)
    }
    
    @State private var state: ViewState = .loading
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            switch state {
            case .loading:
                ProgressView() // Show a loading indicator while preparing the service.
            case .ready(let lessonView):
                lessonView
            case .error(let error):
                // The host app is responsible for handling its own initialization errors.
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    
                    Text("Initialization Failed")
                        .font(.headline)
                    
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        self.state = .loading
                        initializeLesson()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                }
                .padding(32)
            }
        }
        .onAppear {
            if case .loading = state {
                initializeLesson()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Initializes the lesson service and creates the lesson view.
    /// This method is called once when the view appears.
    private func initializeLesson() {
        // Define custom errors for better diagnostics
        enum ConfigurationError: LocalizedError {
            case missingApiUrlKey
            case invalidApiUrl(String)
            
            var errorDescription: String? {
                switch self {
                case .missingApiUrlKey:
                    return "Configuration Error: The 'API_BASE_URL' key is missing from Info.plist."
                case .invalidApiUrl(let url):
                    return "Configuration Error: The API URL '\(url)' found in Info.plist is invalid."
                }
            }
        }
        
        // Read the API endpoint from the Info.plist for better configuration management.
        guard let apiUrlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String else {
            self.state = .error(ConfigurationError.missingApiUrlKey)
            return
        }
        
        guard let url = URL(string: apiUrlString) else {
            self.state = .error(ConfigurationError.invalidApiUrl(apiUrlString))
            return
        }
        
        // Create the service with the configurable URL.
        let service = LiveKitService(apiBaseURL: url)
        let lessonView = ImageLessonViewFactory.make(service: service)
        self.state = .ready(lessonView)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
