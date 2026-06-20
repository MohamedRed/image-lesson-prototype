import Foundation
import Combine
import UserNotifications
// FirebaseMessaging is optional; guard the import to allow building without the SDK
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Comprehensive notification service for push notifications, SMS, and email
public class NotificationService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public var pushNotificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published public var fcmToken: String?
    @Published public var unreadNotifications: [AppNotification] = []
    @Published public var notificationHistory: [AppNotification] = []
    
    // MARK: - Private Properties
    private let userNotificationCenter = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    private let notificationTemplates = NotificationTemplates()
    
    // Mock services - in production these would be real implementations
    private let smsService = SMSService()
    private let emailService = EmailService()
    private let pushService = PushNotificationService()
    
    public override init() {
        super.init()
        setupNotificationCenter()
        requestPermissions()
        setupFCM()
    }
    
    // MARK: - Public Methods
    
    /// Send notification to user based on event and user preferences
    public func sendNotification(
        to userId: String,
        event: NotificationEvent,
        data: [String: Any] = [:],
        priority: NotificationPriority = .normal
    ) async throws {
        
        let userPreferences = try await getUserNotificationPreferences(userId: userId)
        let notification = createNotification(event: event, data: data, priority: priority)
        
        // Send push notification if enabled
        if userPreferences.pushEnabled && shouldSendPush(for: event, preferences: userPreferences) {
            try await pushService.sendPushNotification(
                to: userId,
                notification: notification
            )
        }
        
        // Send SMS if enabled and event supports SMS
        if userPreferences.smsEnabled && shouldSendSMS(for: event, preferences: userPreferences) {
            try await smsService.sendSMS(
                to: userPreferences.phoneNumber,
                message: notificationTemplates.getSMSTemplate(for: event, data: data)
            )
        }
        
        // Send email if enabled and event supports email
        if userPreferences.emailEnabled && shouldSendEmail(for: event, preferences: userPreferences) {
            try await emailService.sendEmail(
                to: userPreferences.email,
                subject: notificationTemplates.getEmailSubject(for: event),
                body: notificationTemplates.getEmailTemplate(for: event, data: data)
            )
        }
        
        // Store notification in history
        await storeNotification(notification, userId: userId)
    }
    
    /// Send notification to multiple users
    public func sendBulkNotification(
        to userIds: [String],
        event: NotificationEvent,
        data: [String: Any] = [:],
        priority: NotificationPriority = .normal
    ) async throws {
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for userId in userIds {
                group.addTask {
                    try await self.sendNotification(
                        to: userId,
                        event: event,
                        data: data,
                        priority: priority
                    )
                }
            }
            
            try await group.waitForAll()
        }
    }
    
    /// Request notification permissions from user
    public func requestPermissions() {
        Task {
            do {
                let granted = try await userNotificationCenter.requestAuthorization(
                    options: [.alert, .badge, .sound, .provisional]
                )
                
                await MainActor.run {
                    pushNotificationPermissionStatus = granted ? .authorized : .denied
                }
                
                #if canImport(UIKit)
                if granted {
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
                #endif
                
            } catch {
                print("Failed to request notification permissions: \(error)")
            }
        }
    }
    
    /// Mark notification as read
    public func markAsRead(notificationId: String) {
        if let index = unreadNotifications.firstIndex(where: { $0.id == notificationId }) {
            var notification = unreadNotifications.remove(at: index)
            notification.isRead = true
            notification.readAt = Date()
            notificationHistory.append(notification)
        }
    }
    
    /// Mark all notifications as read
    public func markAllAsRead() {
        let readNotifications = unreadNotifications.map { notification in
            var updated = notification
            updated.isRead = true
            updated.readAt = Date()
            return updated
        }
        
        notificationHistory.append(contentsOf: readNotifications)
        unreadNotifications.removeAll()
    }
    
    /// Get notification preferences for user
    public func getUserNotificationPreferences(userId: String) async throws -> UserNotificationPreferences {
        // In production, this would fetch from database
        return UserNotificationPreferences(
            userId: userId,
            pushEnabled: true,
            smsEnabled: true,
            emailEnabled: true,
            phoneNumber: "+212 6XX XXX XXX",
            email: "user@example.com",
            orderUpdates: true,
            promotions: true,
            courierUpdates: true,
            merchantUpdates: true,
            quietHours: QuietHours(start: "22:00", end: "08:00"),
            preferredLanguage: "fr-MA"
        )
    }
    
    /// Update notification preferences for user
    public func updateNotificationPreferences(
        userId: String,
        preferences: UserNotificationPreferences
    ) async throws {
        // In production, this would update database
        // For now, just simulate success
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationCenter() {
        userNotificationCenter.delegate = self
        
        // Register notification categories
        registerNotificationCategories()
        
        // Check current permission status
        Task {
            let settings = await userNotificationCenter.notificationSettings()
            await MainActor.run {
                pushNotificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
    
    private func setupFCM() {
        // Configure Firebase Cloud Messaging if available
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        
        // Get FCM token
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("Error fetching FCM token: \(error)")
            } else if let token = token {
                self?.fcmToken = token
                print("FCM token: \(token)")
            }
        }
        #else
        // No-op when FirebaseMessaging is not integrated
        #endif
    }
    
    private func registerNotificationCategories() {
        let orderActions = [
            UNNotificationAction(
                identifier: "VIEW_ORDER",
                title: "View Order",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "TRACK_ORDER",
                title: "Track Order",
                options: [.foreground]
            )
        ]
        
        let courierActions = [
            UNNotificationAction(
                identifier: "ACCEPT_ORDER",
                title: "Accept",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "DECLINE_ORDER",
                title: "Decline",
                options: []
            )
        ]
        
        let merchantActions = [
            UNNotificationAction(
                identifier: "ACCEPT_ORDER",
                title: "Accept",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "DECLINE_ORDER",
                title: "Decline",
                options: []
            )
        ]
        
        let categories = [
            UNNotificationCategory(
                identifier: "ORDER_UPDATE",
                actions: orderActions,
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "COURIER_REQUEST",
                actions: courierActions,
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "MERCHANT_ORDER",
                actions: merchantActions,
                intentIdentifiers: [],
                options: []
            )
        ]
        
        userNotificationCenter.setNotificationCategories(Set(categories))
    }
    
    private func createNotification(
        event: NotificationEvent,
        data: [String: Any],
        priority: NotificationPriority
    ) -> AppNotification {
        
        let template = notificationTemplates.getTemplate(for: event)
        
        return AppNotification(
            id: UUID().uuidString,
            title: template.formatTitle(with: data),
            body: template.formatBody(with: data),
            event: event,
            priority: priority,
            data: data,
            createdAt: Date(),
            scheduledFor: nil,
            category: template.category
        )
    }
    
    private func shouldSendPush(
        for event: NotificationEvent,
        preferences: UserNotificationPreferences
    ) -> Bool {
        switch event {
        case .orderPlaced, .orderAccepted, .orderReady, .orderPickedUp, .orderDelivered, .orderCancelled:
            return preferences.orderUpdates
        case .courierAssigned, .courierEnRoute, .courierArrived:
            return preferences.courierUpdates
        case .newPromotion, .discountAvailable:
            return preferences.promotions
        case .merchantNewOrder, .merchantOrderCancelled:
            return preferences.merchantUpdates
        default:
            return true
        }
    }
    
    private func shouldSendSMS(
        for event: NotificationEvent,
        preferences: UserNotificationPreferences
    ) -> Bool {
        // SMS only for critical events
        switch event {
        case .orderPlaced, .orderDelivered, .orderCancelled, .merchantNewOrder:
            return true
        default:
            return false
        }
    }
    
    private func shouldSendEmail(
        for event: NotificationEvent,
        preferences: UserNotificationPreferences
    ) -> Bool {
        // Email for order confirmations and receipts
        switch event {
        case .orderPlaced, .orderDelivered, .newPromotion, .weeklyReport:
            return true
        default:
            return false
        }
    }
    
    private func storeNotification(_ notification: AppNotification, userId: String) async {
        // In production, this would store in database
        await MainActor.run {
            unreadNotifications.append(notification)
            
            // Keep only last 100 unread notifications
            if unreadNotifications.count > 100 {
                unreadNotifications = Array(unreadNotifications.suffix(100))
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        
        let notification = response.notification
        let actionIdentifier = response.actionIdentifier
        
        // Handle notification actions
        handleNotificationAction(
            actionIdentifier: actionIdentifier,
            notification: notification
        )
        
        completionHandler()
    }
    
    private func handleNotificationAction(
        actionIdentifier: String,
        notification: UNNotification
    ) {
        let userInfo = notification.request.content.userInfo
        
        switch actionIdentifier {
        case "VIEW_ORDER":
            // Navigate to order details
            NotificationCenter.default.post(
                name: .navigateToOrder,
                object: nil,
                userInfo: userInfo
            )
            
        case "TRACK_ORDER":
            // Navigate to order tracking
            NotificationCenter.default.post(
                name: .navigateToTracking,
                object: nil,
                userInfo: userInfo
            )
            
        case "ACCEPT_ORDER":
            // Handle order acceptance
            NotificationCenter.default.post(
                name: .acceptOrder,
                object: nil,
                userInfo: userInfo
            )
            
        case "DECLINE_ORDER":
            // Handle order decline
            NotificationCenter.default.post(
                name: .declineOrder,
                object: nil,
                userInfo: userInfo
            )
            
        default:
            // Default action (tap notification)
            NotificationCenter.default.post(
                name: .handleNotificationTap,
                object: nil,
                userInfo: userInfo
            )
        }
    }
}

// MARK: - MessagingDelegate
#if canImport(FirebaseMessaging)
extension NotificationService: MessagingDelegate {
    public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        self.fcmToken = fcmToken
        
        // Send token to server
        if let token = fcmToken {
            Task {
                // In production, send token to backend
                print("FCM token received: \(token)")
            }
        }
    }
}
#endif

// MARK: - Notification Names
extension Notification.Name {
    public static let navigateToOrder = Notification.Name("navigateToOrder")
    public static let navigateToTracking = Notification.Name("navigateToTracking")
    public static let acceptOrder = Notification.Name("acceptOrder")
    public static let declineOrder = Notification.Name("declineOrder")
    public static let handleNotificationTap = Notification.Name("handleNotificationTap")
}

// MARK: - Supporting Models

public struct AppNotification: Identifiable, Codable {
    public let id: String
    public let title: String
    public let body: String
    public let event: NotificationEvent
    public let priority: NotificationPriority
    public let data: [String: Any]
    public let createdAt: Date
    public let scheduledFor: Date?
    public let category: String?
    public var isRead: Bool = false
    public var readAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title, body, event, priority, createdAt, scheduledFor, category, isRead, readAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        event = try container.decode(NotificationEvent.self, forKey: .event)
        priority = try container.decode(NotificationPriority.self, forKey: .priority)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        scheduledFor = try container.decodeIfPresent(Date.self, forKey: .scheduledFor)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
        data = [:] // Would need custom decoding for Any type
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(event, forKey: .event)
        try container.encode(priority, forKey: .priority)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(scheduledFor, forKey: .scheduledFor)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encode(isRead, forKey: .isRead)
        try container.encodeIfPresent(readAt, forKey: .readAt)
    }
    
    public init(
        id: String,
        title: String,
        body: String,
        event: NotificationEvent,
        priority: NotificationPriority,
        data: [String: Any],
        createdAt: Date,
        scheduledFor: Date? = nil,
        category: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.event = event
        self.priority = priority
        self.data = data
        self.createdAt = createdAt
        self.scheduledFor = scheduledFor
        self.category = category
    }
}

public enum NotificationEvent: String, Codable, CaseIterable {
    // Customer notifications
    case orderPlaced = "order_placed"
    case orderAccepted = "order_accepted"
    case orderReady = "order_ready"
    case orderPickedUp = "order_picked_up"
    case orderDelivered = "order_delivered"
    case orderCancelled = "order_cancelled"
    case courierAssigned = "courier_assigned"
    case courierEnRoute = "courier_en_route"
    case courierArrived = "courier_arrived"
    case newPromotion = "new_promotion"
    case discountAvailable = "discount_available"
    
    // Merchant notifications
    case merchantNewOrder = "merchant_new_order"
    case merchantOrderCancelled = "merchant_order_cancelled"
    case merchantLowStock = "merchant_low_stock"
    case merchantDailySummary = "merchant_daily_summary"
    case merchantWeeklyReport = "merchant_weekly_report"
    
    // Courier notifications
    case courierNewOrderAvailable = "courier_new_order_available"
    case courierOrderAssigned = "courier_order_assigned"
    case courierEarningsUpdate = "courier_earnings_update"
    case courierShiftReminder = "courier_shift_reminder"
    
    // System notifications
    case systemMaintenance = "system_maintenance"
    case appUpdate = "app_update"
    case weeklyReport = "weekly_report"
}

public enum NotificationPriority: String, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
}

public struct UserNotificationPreferences: Codable {
    public let userId: String
    public var pushEnabled: Bool
    public var smsEnabled: Bool
    public var emailEnabled: Bool
    public var phoneNumber: String
    public var email: String
    
    // Granular preferences
    public var orderUpdates: Bool
    public var promotions: Bool
    public var courierUpdates: Bool
    public var merchantUpdates: Bool
    
    public var quietHours: QuietHours
    public var preferredLanguage: String
    
    public init(
        userId: String,
        pushEnabled: Bool = true,
        smsEnabled: Bool = true,
        emailEnabled: Bool = true,
        phoneNumber: String,
        email: String,
        orderUpdates: Bool = true,
        promotions: Bool = true,
        courierUpdates: Bool = true,
        merchantUpdates: Bool = true,
        quietHours: QuietHours = QuietHours(),
        preferredLanguage: String = "fr-MA"
    ) {
        self.userId = userId
        self.pushEnabled = pushEnabled
        self.smsEnabled = smsEnabled
        self.emailEnabled = emailEnabled
        self.phoneNumber = phoneNumber
        self.email = email
        self.orderUpdates = orderUpdates
        self.promotions = promotions
        self.courierUpdates = courierUpdates
        self.merchantUpdates = merchantUpdates
        self.quietHours = quietHours
        self.preferredLanguage = preferredLanguage
    }
}

public struct QuietHours: Codable {
    public let start: String
    public let end: String
    
    public init(start: String = "22:00", end: String = "08:00") {
        self.start = start
        self.end = end
    }
}