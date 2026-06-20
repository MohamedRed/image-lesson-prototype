import Foundation
import PushKit
import CallKit
import UserNotifications
import AVFoundation
import UIKit
import Combine
import FirebaseAuth
import FirebaseFirestore

/// Service for handling VoIP push notifications and background wake
@MainActor
public class VoIPNotificationService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isRegistered: Bool = false
    @Published public var voipToken: String?
    @Published public var lastError: Error?
    
    // MARK: - Private Properties
    private let pushRegistry = PKPushRegistry(queue: DispatchQueue.main)
    private let callController = CXCallController()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public override init() {
        super.init()
        setupVoIPPushNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Registers for VoIP push notifications
    public func registerForVoIPNotifications() {
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
        
        print("📱 Registering for VoIP push notifications...")
    }
    
    /// Unregisters from VoIP push notifications
    public func unregisterFromVoIPNotifications() {
        pushRegistry.desiredPushTypes = []
        isRegistered = false
        voipToken = nil
        
        print("📱 Unregistered from VoIP push notifications")
    }
    
    /// Uploads VoIP token to Firestore for the current user
    private func uploadVoIPToken(_ token: String) {
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user to upload VoIP token")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUser.uid)
        
        let tokenData: [String: Any] = [
            "voipToken": token,
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "platform": "ios",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        userRef.setData(tokenData, merge: true) { [weak self] error in
            if let error = error {
                print("❌ Failed to upload VoIP token: \(error)")
                self?.lastError = error
            } else {
                print("✅ VoIP token uploaded successfully")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupVoIPPushNotifications() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Notification permissions granted")
                } else {
                    print("❌ Notification permissions denied: \(error?.localizedDescription ?? "Unknown error")")
                    self.lastError = error
                }
            }
        }
    }
    
    private func handleIncomingCall(payload: [AnyHashable: Any]) {
        guard let rideId = payload["rideId"] as? String,
              let driverName = payload["driverName"] as? String,
              let callUUID = UUID(uuidString: payload["callUUID"] as? String ?? "") else {
            print("❌ Invalid VoIP payload format")
            return
        }
        
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = CXHandle(type: .generic, value: driverName)
        callUpdate.localizedCallerName = "Ride from \(driverName)"
        callUpdate.hasVideo = false
        callUpdate.supportsHolding = false
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.supportsDTMF = false
        
        // Report incoming call to CallKit
        let callProvider = CXProvider(configuration: createCallKitConfiguration())
        callProvider.reportNewIncomingCall(with: callUUID, update: callUpdate) { error in
            if let error = error {
                print("❌ Failed to report incoming call: \(error)")
            } else {
                print("✅ Incoming call reported to CallKit")
            }
        }
    }
    
    private func createCallKitConfiguration() -> CXProviderConfiguration {
        let configuration = CXProviderConfiguration(localizedName: "Liive Ride Sharing")
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportsVideo = false
        configuration.supportedHandleTypes = [.generic]
        
        // Audio session is managed by the app; no assignment on configuration
        
        return configuration
    }
    
    private func handleRideUpdate(payload: [AnyHashable: Any]) {
        guard let rideId = payload["rideId"] as? String,
              let status = payload["status"] as? String else {
            print("❌ Invalid ride update payload")
            return
        }
        
        // Post notification for ride status update
        NotificationCenter.default.post(
            name: .rideStatusUpdated,
            object: nil,
            userInfo: [
                "rideId": rideId,
                "status": status,
                "payload": payload
            ]
        )
        
        // Show local notification if app is in background
        if UIApplication.shared.applicationState != .active {
            showLocalNotification(for: payload)
        }
    }
    
    private func showLocalNotification(for payload: [AnyHashable: Any]) {
        let content = UNMutableNotificationContent()
        content.title = "Ride Update"
        content.body = payload["message"] as? String ?? "Your ride status has been updated"
        content.sound = .default
        content.badge = 1
        content.userInfo = payload
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to show local notification: \(error)")
            } else {
                print("✅ Local notification scheduled")
            }
        }
    }
}

// MARK: - PKPushRegistryDelegate

extension VoIPNotificationService: PKPushRegistryDelegate {
    
    public func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        guard type == .voIP else { return }
        
        let tokenString = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        
        DispatchQueue.main.async {
            self.voipToken = tokenString
            self.isRegistered = true
            
            print("✅ VoIP token received: \(tokenString.prefix(20))...")
            
            // Upload token to backend
            self.uploadVoIPToken(tokenString)
        }
    }
    
    public func pushRegistry(
        _ registry: PKPushRegistry,
        didInvalidatePushTokenFor type: PKPushType
    ) {
        guard type == .voIP else { return }
        
        DispatchQueue.main.async {
            self.voipToken = nil
            self.isRegistered = false
            
            print("⚠️ VoIP token invalidated")
        }
    }
    
    public func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }
        
        print("📱 Received VoIP push notification: \(payload.dictionaryPayload)")
        
        let payloadDict = payload.dictionaryPayload
        
        // Determine notification type
        if let notificationType = payloadDict["type"] as? String {
            switch notificationType {
            case "incoming_ride":
                handleIncomingCall(payload: payloadDict)
            case "ride_update":
                handleRideUpdate(payload: payloadDict)
            default:
                print("⚠️ Unknown VoIP notification type: \(notificationType)")
            }
        }
        
        // Always call completion to indicate we handled the notification
        completion()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    public static let rideStatusUpdated = Notification.Name("rideStatusUpdated")
    public static let voipTokenUpdated = Notification.Name("voipTokenUpdated")
}

// MARK: - VoIP Payload Models

public struct VoIPRideNotification: Codable {
    let type: String
    let rideId: String
    let driverName: String?
    let message: String
    let callUUID: String?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case type, rideId, driverName, message, callUUID, timestamp
    }
}

public struct VoIPRideUpdate: Codable {
    let type: String
    let rideId: String
    let status: String
    let message: String
    let driverLocation: [String: Double]?
    let estimatedArrival: Date?
    
    enum CodingKeys: String, CodingKey {
        case type, rideId, status, message, driverLocation, estimatedArrival
    }
} 