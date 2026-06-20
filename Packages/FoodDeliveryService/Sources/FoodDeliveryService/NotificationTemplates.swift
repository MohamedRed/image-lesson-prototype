import Foundation

/// Notification templates for different events and languages
public class NotificationTemplates {
    
    private let templates: [NotificationEvent: NotificationTemplate]
    
    public init() {
        self.templates = Self.createTemplates()
    }
    
    public func getTemplate(for event: NotificationEvent) -> NotificationTemplate {
        return templates[event] ?? NotificationTemplate.default
    }
    
    public func getSMSTemplate(for event: NotificationEvent, data: [String: Any]) -> String {
        let template = getTemplate(for: event)
        return template.formatSMS(with: data)
    }
    
    public func getEmailSubject(for event: NotificationEvent) -> String {
        let template = getTemplate(for: event)
        return template.emailSubject
    }
    
    public func getEmailTemplate(for event: NotificationEvent, data: [String: Any]) -> String {
        let template = getTemplate(for: event)
        return template.formatEmail(with: data)
    }
    
    private static func createTemplates() -> [NotificationEvent: NotificationTemplate] {
        return [
            // Customer notifications
            .orderPlaced: NotificationTemplate(
                titleTemplate: "Order Confirmed! 🎉",
                bodyTemplate: "Your order #{orderId} has been placed successfully. Total: {total} MAD",
                smsTemplate: "Liive: Your order #{orderId} for {total} MAD has been confirmed. Track your order in the app.",
                emailSubject: "Order Confirmation - #{orderId}",
                emailTemplate: """
                <h2>Order Confirmed!</h2>
                <p>Thank you for your order. Your food will be prepared and delivered soon.</p>
                <p><strong>Order ID:</strong> #{orderId}</p>
                <p><strong>Total:</strong> {total} MAD</p>
                <p><strong>Estimated Delivery:</strong> {estimatedTime}</p>
                <p>Track your order in the Liive app.</p>
                """,
                category: "ORDER_UPDATE"
            ),
            
            .orderAccepted: NotificationTemplate(
                titleTemplate: "Order Accepted by Restaurant 👨‍🍳",
                bodyTemplate: "Your order #{orderId} has been accepted and is being prepared. Estimated time: {prepTime} minutes",
                smsTemplate: "Liive: Your order #{orderId} is being prepared. Estimated time: {prepTime} minutes.",
                emailSubject: "Your Order is Being Prepared",
                emailTemplate: """
                <h2>Order Accepted!</h2>
                <p>Great news! The restaurant has accepted your order and started preparation.</p>
                <p><strong>Order ID:</strong> #{orderId}</p>
                <p><strong>Estimated Preparation Time:</strong> {prepTime} minutes</p>
                """,
                category: "ORDER_UPDATE"
            ),
            
            .orderReady: NotificationTemplate(
                titleTemplate: "Order Ready for Pickup! 🛍️",
                bodyTemplate: "Your order #{orderId} is ready and waiting for courier pickup",
                smsTemplate: "Liive: Your order #{orderId} is ready for pickup. A courier will collect it shortly.",
                emailSubject: "Order Ready for Pickup",
                emailTemplate: """
                <h2>Order Ready!</h2>
                <p>Your order is ready and waiting for courier pickup.</p>
                <p><strong>Order ID:</strong> #{orderId}</p>
                """,
                category: "ORDER_UPDATE"
            ),
            
            .courierAssigned: NotificationTemplate(
                titleTemplate: "Courier Assigned! 🚗",
                bodyTemplate: "Courier {courierName} has been assigned to deliver your order #{orderId}",
                smsTemplate: "Liive: Courier {courierName} will deliver your order #{orderId}. Track in app.",
                emailSubject: "Courier Assigned to Your Order",
                emailTemplate: """
                <h2>Courier Assigned!</h2>
                <p>A courier has been assigned to deliver your order.</p>
                <p><strong>Courier:</strong> {courierName}</p>
                <p><strong>Order ID:</strong> #{orderId}</p>
                """,
                category: "ORDER_UPDATE"
            ),
            
            .orderPickedUp: NotificationTemplate(
                titleTemplate: "Order Picked Up! 📦",
                bodyTemplate: "Your order #{orderId} has been picked up and is on its way to you",
                smsTemplate: "Liive: Your order #{orderId} is on its way! Estimated delivery: {estimatedTime}",
                emailSubject: "Order Picked Up - On Its Way!",
                emailTemplate: """
                <h2>Order Picked Up!</h2>
                <p>Your order is now on its way to you.</p>
                <p><strong>Order ID:</strong> #{orderId}</p>
                <p><strong>Estimated Delivery:</strong> {estimatedTime}</p>
                """,
                category: "ORDER_UPDATE"
            ),
            
            .courierEnRoute: NotificationTemplate(
                titleTemplate: "Courier En Route! 🛵",
                bodyTemplate: "Your courier is heading to the restaurant to pick up order #{orderId}",
                smsTemplate: "Liive: Your courier is heading to the restaurant for order #{orderId}.",
                emailSubject: "Courier En Route to Restaurant",
                emailTemplate: """
                <h2>Courier En Route!</h2>
                <p>Your courier is heading to the restaurant to pick up your order.</p>
                <p><strong>Order ID:</strong> #{orderId}</p>
                """,
                category: "ORDER_UPDATE"
            ),
            
            .courierArrived: NotificationTemplate(
                titleTemplate: "Courier Arriving Soon! 📍",
                bodyTemplate: "Your courier is approaching your delivery location for order #{orderId}",
                smsTemplate: "Liive: Your courier is approaching your location with order #{orderId}. Be ready!",
                emailSubject: "Courier Approaching Your Location",
                emailTemplate: """
                <h2>Courier Arriving Soon!</h2>
                <p>Your courier is approaching your delivery location.</p>
                <p><strong>Order ID:</strong> #{orderId}</p>
                <p>Please be ready to receive your order.</p>
                """,
                category: "ORDER_UPDATE"
            ),
            
            .orderDelivered: NotificationTemplate(
                titleTemplate: "Order Delivered! ✅",
                bodyTemplate: "Your order #{orderId} has been delivered successfully. Enjoy your meal!",
                smsTemplate: "Liive: Order #{orderId} delivered! Enjoy your meal. Rate your experience in the app.",
                emailSubject: "Order Delivered Successfully - Receipt",
                emailTemplate: """
                <h2>Order Delivered!</h2>
                <p>Your order has been delivered successfully. We hope you enjoy your meal!</p>
                <p><strong>Order ID:</strong> #{orderId}</p>
                <p><strong>Total Paid:</strong> {total} MAD</p>
                <p>Please rate your experience in the Liive app.</p>
                """,
                category: "ORDER_UPDATE"
            ),
            
            .orderCancelled: NotificationTemplate(
                titleTemplate: "Order Cancelled ❌",
                bodyTemplate: "Order #{orderId} has been cancelled. {reason}",
                smsTemplate: "Liive: Order #{orderId} cancelled. {reason} Refund will be processed if applicable.",
                emailSubject: "Order Cancellation - #{orderId}",
                emailTemplate: """
                <h2>Order Cancelled</h2>
                <p>We're sorry to inform you that your order has been cancelled.</p>
                <p><strong>Order ID:</strong> #{orderId}</p>
                <p><strong>Reason:</strong> {reason}</p>
                <p>Any applicable refunds will be processed within 3-5 business days.</p>
                """,
                category: "ORDER_UPDATE"
            ),
            
            .newPromotion: NotificationTemplate(
                titleTemplate: "New Deal Available! 🎉",
                bodyTemplate: "{title} - Save up to {discount}% on your next order",
                smsTemplate: "Liive: {title} Save {discount}% on your next order. Use code: {code}",
                emailSubject: "Special Offer Just for You!",
                emailTemplate: """
                <h2>{title}</h2>
                <p>We have a special offer just for you!</p>
                <p><strong>Discount:</strong> {discount}%</p>
                <p><strong>Promo Code:</strong> {code}</p>
                <p>Valid until {expiryDate}</p>
                """,
                category: nil
            ),
            
            // Merchant notifications
            .merchantNewOrder: NotificationTemplate(
                titleTemplate: "New Order Received! 📋",
                bodyTemplate: "Order #{orderId} for {total} MAD. {itemCount} items. Accept within 5 minutes.",
                smsTemplate: "Liive Merchant: New order #{orderId} for {total} MAD. Check app to accept.",
                emailSubject: "New Order - #{orderId}",
                emailTemplate: """
                <h2>New Order Received!</h2>
                <p>You have received a new order.</p>
                <p><strong>Order ID:</strong> #{orderId}</p>
                <p><strong>Total:</strong> {total} MAD</p>
                <p><strong>Items:</strong> {itemCount}</p>
                <p>Please check your merchant app to accept or decline this order.</p>
                """,
                category: "MERCHANT_ORDER"
            ),
            
            .merchantOrderCancelled: NotificationTemplate(
                titleTemplate: "Order Cancelled by Customer",
                bodyTemplate: "Order #{orderId} has been cancelled by the customer",
                smsTemplate: "Liive Merchant: Order #{orderId} cancelled by customer.",
                emailSubject: "Order Cancellation - #{orderId}",
                emailTemplate: """
                <h2>Order Cancelled</h2>
                <p>Order #{orderId} has been cancelled by the customer.</p>
                <p>No further action is required.</p>
                """,
                category: nil
            ),
            
            .merchantDailySummary: NotificationTemplate(
                titleTemplate: "Daily Summary Report 📊",
                bodyTemplate: "Today: {orderCount} orders, {revenue} MAD revenue. Rating: {rating}★",
                smsTemplate: "Liive Merchant: Daily summary - {orderCount} orders, {revenue} MAD revenue.",
                emailSubject: "Daily Sales Summary",
                emailTemplate: """
                <h2>Daily Summary Report</h2>
                <p>Here's your restaurant's performance for today:</p>
                <ul>
                    <li><strong>Orders:</strong> {orderCount}</li>
                    <li><strong>Revenue:</strong> {revenue} MAD</li>
                    <li><strong>Average Rating:</strong> {rating}★</li>
                    <li><strong>Average Prep Time:</strong> {prepTime} minutes</li>
                </ul>
                """,
                category: nil
            ),
            
            // Courier notifications
            .courierNewOrderAvailable: NotificationTemplate(
                titleTemplate: "New Delivery Available! 🛵",
                bodyTemplate: "Order #{orderId} - {distance} km, {earnings} MAD. Accept now!",
                smsTemplate: "Liive Courier: New delivery #{orderId} - {distance}km, {earnings} MAD. Check app.",
                emailSubject: "New Delivery Opportunity",
                emailTemplate: """
                <h2>New Delivery Available!</h2>
                <p>A new delivery opportunity is available for you.</p>
                <p><strong>Order ID:</strong> #{orderId}</p>
                <p><strong>Distance:</strong> {distance} km</p>
                <p><strong>Estimated Earnings:</strong> {earnings} MAD</p>
                """,
                category: "COURIER_REQUEST"
            ),
            
            .courierOrderAssigned: NotificationTemplate(
                titleTemplate: "Order Assigned to You! 📦",
                bodyTemplate: "You've been assigned order #{orderId}. Head to {restaurantName} for pickup.",
                smsTemplate: "Liive Courier: Order #{orderId} assigned. Go to {restaurantName} for pickup.",
                emailSubject: "Order Assignment - #{orderId}",
                emailTemplate: """
                <h2>Order Assigned!</h2>
                <p>You have been assigned a delivery order.</p>
                <p><strong>Order ID:</strong> #{orderId}</p>
                <p><strong>Pickup Location:</strong> {restaurantName}</p>
                <p><strong>Delivery Address:</strong> {deliveryAddress}</p>
                """,
                category: nil
            ),
            
            .courierEarningsUpdate: NotificationTemplate(
                titleTemplate: "Earnings Update 💰",
                bodyTemplate: "Today's earnings: {earnings} MAD from {deliveries} deliveries. Great work!",
                smsTemplate: "Liive Courier: Today's earnings - {earnings} MAD from {deliveries} deliveries.",
                emailSubject: "Daily Earnings Summary",
                emailTemplate: """
                <h2>Daily Earnings Summary</h2>
                <p>Here's your earnings summary for today:</p>
                <ul>
                    <li><strong>Total Earnings:</strong> {earnings} MAD</li>
                    <li><strong>Deliveries Completed:</strong> {deliveries}</li>
                    <li><strong>Average per Delivery:</strong> {averageEarnings} MAD</li>
                    <li><strong>Tips Received:</strong> {tips} MAD</li>
                </ul>
                """,
                category: nil
            )
        ]
    }
}

// MARK: - Notification Template
public struct NotificationTemplate {
    let titleTemplate: String
    let bodyTemplate: String
    let smsTemplate: String
    let emailSubject: String
    let emailTemplate: String
    let category: String?
    
    static let `default` = NotificationTemplate(
        titleTemplate: "Notification",
        bodyTemplate: "You have a new notification",
        smsTemplate: "You have a new notification from Liive",
        emailSubject: "Notification from Liive",
        emailTemplate: "<p>You have a new notification from Liive.</p>",
        category: nil
    )
    
    func formatTitle(with data: [String: Any]) -> String {
        return formatTemplate(titleTemplate, with: data)
    }
    
    func formatBody(with data: [String: Any]) -> String {
        return formatTemplate(bodyTemplate, with: data)
    }
    
    func formatSMS(with data: [String: Any]) -> String {
        return formatTemplate(smsTemplate, with: data)
    }
    
    func formatEmail(with data: [String: Any]) -> String {
        return formatTemplate(emailTemplate, with: data)
    }
    
    private func formatTemplate(_ template: String, with data: [String: Any]) -> String {
        var result = template
        
        for (key, value) in data {
            let placeholder = "{\(key)}"
            let stringValue = String(describing: value)
            result = result.replacingOccurrences(of: placeholder, with: stringValue)
        }
        
        return result
    }
}

// MARK: - Mock Services
class SMSService {
    func sendSMS(to phoneNumber: String, message: String) async throws {
        // Mock SMS sending - in production would use Twilio, AWS SNS, etc.
        print("📱 SMS to \(phoneNumber): \(message)")
        try await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
    }
}

class EmailService {
    func sendEmail(to email: String, subject: String, body: String) async throws {
        // Mock email sending - in production would use SendGrid, AWS SES, etc.
        print("📧 Email to \(email): \(subject)")
        try await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
    }
}

class PushNotificationService {
    func sendPushNotification(to userId: String, notification: AppNotification) async throws {
        // Mock push notification - in production would use FCM, APNs, etc.
        print("🔔 Push to \(userId): \(notification.title)")
        try await Task.sleep(nanoseconds: 200_000_000) // Simulate network delay
    }
}