import Foundation
import UIKit
import SceneKit
import AVFoundation

public class MockUnityBridge: UnityBridgeProtocol {
    
    // Callbacks to SwiftUI
    public var onMissionCompleted: ((MissionResult) -> Void)?
    public var onRAGQueryRequested: ((String, String) async -> RAGResponse)?
    public var onEventsLogged: (([TelemetryEvent]) -> Void)?
    
    // Mock Unity view controller
    private var unityViewController: UIViewController?
    private var currentEpisodeId: String?
    private var missionStartTime: Date?
    
    public init() {}
    
    // MARK: - UnityBridgeProtocol Implementation
    
    public func initialize(sessionToken: String, userId: String) {
        print("🎮 [Mock Unity] Initializing Unity with session: \(sessionToken)")
        // Simulate Unity initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🎮 [Mock Unity] Unity initialized successfully")
        }
    }
    
    public func startMission(episodeId: String, assets: EpisodeAssets) {
        print("🎮 [Mock Unity] Starting mission: \(episodeId)")
        currentEpisodeId = episodeId
        missionStartTime = Date()
        
        // Create mock Unity view controller
        createMockUnityView()
        
        // Simulate loading assets
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🎮 [Mock Unity] Assets loaded, rendering 3D scene...")
            self.simulateGameplay()
        }
    }
    
    public func pause() {
        print("🎮 [Mock Unity] Game paused")
    }
    
    public func resume() {
        print("🎮 [Mock Unity] Game resumed")
    }
    
    public func requestSave(slot: Int) {
        print("🎮 [Mock Unity] Saving to slot \(slot)")
        // Mock save functionality
    }
    
    public func quit() {
        print("🎮 [Mock Unity] Quitting Unity")
        unityViewController?.dismiss(animated: true)
        unityViewController = nil
    }
    
    // MARK: - Mock Unity Simulation
    
    private func createMockUnityView() {
        let real3DGameVC = Real3DJerusalemGameViewController()
        real3DGameVC.episodeId = currentEpisodeId ?? ""
        real3DGameVC.bridge = self
        
        // Present the real 3D game fullscreen
        if let topVC = getTopViewController() {
            real3DGameVC.modalPresentationStyle = .fullScreen
            topVC.present(real3DGameVC, animated: true)
            self.unityViewController = real3DGameVC
        }
    }
    
    private func simulateGameplay() {
        // Simulate various Unity events during gameplay
        simulateNPCInteraction()
        
        // Simulate mission completion after some time
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            self.simulateMissionCompletion()
        }
    }
    
    private func simulateNPCInteraction() {
        // Simulate Patriarch Sophronius dialogue after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            Task {
                print("🎮 [Mock Unity] NPC interaction triggered - Patriarch Sophronius")
                if let ragCallback = self.onRAGQueryRequested {
                    let response = await ragCallback("patriarch_sophronius", "How can we ensure the protection of Christian holy sites?")
                    print("🎮 [Mock Unity] Received RAG response: \(response.response)")
                }
            }
        }
        
        // Log some telemetry events
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            let events = [
                TelemetryEvent(
                    sessionId: UUID().uuidString,
                    episodeId: self.currentEpisodeId ?? "",
                    timestamp: Date().timeIntervalSince1970,
                    type: "npc_dialogue_started",
                    data: ["npc": "patriarch_sophronius", "scene": "city_gates"]
                )
            ]
            self.onEventsLogged?(events)
        }
    }
    
    private func simulateMissionCompletion() {
        guard let episodeId = currentEpisodeId,
              let startTime = missionStartTime else { return }
        
        let playTime = Date().timeIntervalSince1970 - startTime.timeIntervalSince1970
        
        // Create mock mission result
        let decisions = [
            Decision(id: "prayer_decision", choice: "Pray outside the church", timestamp: Date().timeIntervalSince1970),
            Decision(id: "negotiation_approach", choice: "Diplomatic approach", timestamp: Date().timeIntervalSince1970)
        ]
        
        let result = MissionResult(
            episodeId: episodeId,
            completed: true,
            score: 0.85, // Mock high score
            decisions: decisions,
            playTime: playTime
        )
        
        print("🎮 [Mock Unity] Mission completed! Score: \(result.score)")
        
        // Dismiss Unity view and notify completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.unityViewController?.dismiss(animated: true) {
                self.onMissionCompleted?(result)
                self.unityViewController = nil
                self.currentEpisodeId = nil
                self.missionStartTime = nil
            }
        }
    }
    
    // Helper to get top view controller
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var topVC = window.rootViewController
        while let presentedVC = topVC?.presentedViewController {
            topVC = presentedVC
        }
        return topVC
    }
}

