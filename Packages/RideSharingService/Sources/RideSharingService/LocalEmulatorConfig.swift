import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

public struct LocalEmulatorConfig {
    public static let isLocalTesting = true
    
    public static func configureEmulators() {
        guard isLocalTesting else { return }
        
        // Configure Auth emulator
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)
        
        // Configure Firestore emulator
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings
        
        print("🔧 Firebase Emulators configured for local testing")
        print("📍 Auth: localhost:9099")
        print("📍 Firestore: localhost:8080")
        print("📍 Functions: localhost:5001")
    }
    
    public static func getLocalFunctionsURL() -> URL {
        return URL(string: "http://localhost:5001/liive-ios-local/us-central1")!
    }
}