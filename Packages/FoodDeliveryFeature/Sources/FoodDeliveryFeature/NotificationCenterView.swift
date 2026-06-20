import SwiftUI
import FoodDeliveryService

/// Notification center view for managing user notifications
public struct NotificationCenterView: View {
    @StateObject private var notificationService = NotificationService()
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showingSettings = false
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter tabs
                NotificationFilterBar(selectedFilter: $selectedFilter)
                
                // Notifications list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredNotifications, id: \.id) { notification in
                            NotificationCard(
                                notification: notification,
                                onTap: {
                                    handleNotificationTap(notification)
                                },
                                onMarkAsRead: {
                                    notificationService.markAsRead(notificationId: notification.id)
                                }
                            )
                        }
                        
                        if filteredNotifications.isEmpty {
                            EmptyNotificationsView(filter: selectedFilter)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !notificationService.unreadNotifications.isEmpty {
                            Button("Mark All Read") {
                                notificationService.markAllAsRead()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NotificationSettingsView(notificationService: notificationService)
        }
        .onAppear {
            setupNotificationHandlers()
        }
    }
    
    private var filteredNotifications: [AppNotification] {
        let allNotifications = notificationService.unreadNotifications + notificationService.notificationHistory
        
        switch selectedFilter {
        case .all:
            return allNotifications.sorted { $0.createdAt > $1.createdAt }
        case .unread:
            return notificationService.unreadNotifications.sorted { $0.createdAt > $1.createdAt }
        case .orders:
            return allNotifications.filter { notification in
                [.orderPlaced, .orderAccepted, .orderReady, .orderPickedUp, .orderDelivered, .orderCancelled].contains(notification.event)
            }.sorted { $0.createdAt > $1.createdAt }
        case .promotions:
            return allNotifications.filter { notification in
                [.newPromotion, .discountAvailable].contains(notification.event)
            }.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        // Mark as read
        notificationService.markAsRead(notificationId: notification.id)
        
        // Handle navigation based on notification type
        switch notification.event {
        case .orderPlaced, .orderAccepted, .orderReady, .orderPickedUp, .orderDelivered:
            // Navigate to order tracking
            if let orderId = notification.data["orderId"] as? String {
                NotificationCenter.default.post(
                    name: .navigateToOrder,
                    object: nil,
                    userInfo: ["orderId": orderId]
                )
            }
            
        case .newPromotion, .discountAvailable:
            // Navigate to promotions
            NotificationCenter.default.post(
                name: .navigateToPromotions,
                object: nil
            )
            
        case .courierAssigned, .courierEnRoute, .courierArrived:
            // Navigate to tracking
            if let orderId = notification.data["orderId"] as? String {
                NotificationCenter.default.post(
                    name: .navigateToTracking,
                    object: nil,
                    userInfo: ["orderId": orderId]
                )
            }
            
        default:
            break
        }
    }
    
    private func setupNotificationHandlers() {
        // Listen for notification navigation requests
        NotificationCenter.default.addObserver(
            forName: .navigateToOrder,
            object: nil,
            queue: .main
        ) { notification in
            // Handle order navigation
            print("Navigate to order: \(notification.userInfo ?? [:])")
        }
        
        NotificationCenter.default.addObserver(
            forName: .navigateToTracking,
            object: nil,
            queue: .main
        ) { notification in
            // Handle tracking navigation
            print("Navigate to tracking: \(notification.userInfo ?? [:])")
        }
    }
}

// MARK: - Notification Filter
enum NotificationFilter: String, CaseIterable {
    case all = "All"
    case unread = "Unread"
    case orders = "Orders"
    case promotions = "Promotions"
    
    var icon: String {
        switch self {
        case .all: return "bell.fill"
        case .unread: return "bell.badge"
        case .orders: return "bag.fill"
        case .promotions: return "tag.fill"
        }
    }
}

// MARK: - Notification Filter Bar
struct NotificationFilterBar: View {
    @Binding var selectedFilter: NotificationFilter
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(NotificationFilter.allCases, id: \.self) { filter in
                Button(action: {
                    selectedFilter = filter
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: filter.icon)
                            .font(.subheadline)
                        
                        Text(filter.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(selectedFilter == filter ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - Notification Card
struct NotificationCard: View {
    let notification: AppNotification
    let onTap: () -> Void
    let onMarkAsRead: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Event icon
                NotificationIcon(event: notification.event, priority: notification.priority)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title and time
                    HStack {
                        Text(notification.title)
                            .font(.subheadline)
                            .fontWeight(notification.isRead ? .medium : .semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(notification.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Body
                    Text(notification.body)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Priority badge
                    if notification.priority == .high || notification.priority == .urgent {
                        PriorityBadge(priority: notification.priority)
                    }
                }
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .opacity(notification.isRead ? 0.8 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if !notification.isRead {
                Button("Mark as Read", systemImage: "checkmark") {
                    onMarkAsRead()
                }
            }
            
            Button("Delete", systemImage: "trash", role: .destructive) {
                // Handle delete
            }
        }
    }
}

// MARK: - Notification Icon
struct NotificationIcon: View {
    let event: NotificationEvent
    let priority: NotificationPriority
    
    private var iconName: String {
        switch event {
        case .orderPlaced, .orderAccepted, .orderReady, .orderPickedUp, .orderDelivered:
            return "bag.fill"
        case .orderCancelled:
            return "xmark.circle.fill"
        case .courierAssigned, .courierEnRoute, .courierArrived:
            return "car.fill"
        case .newPromotion, .discountAvailable:
            return "tag.fill"
        case .merchantNewOrder, .merchantOrderCancelled:
            return "building.2.fill"
        case .courierNewOrderAvailable, .courierOrderAssigned:
            return "truck.box.fill"
        default:
            return "bell.fill"
        }
    }
    
    private var iconColor: Color {
        switch priority {
        case .urgent:
            return .red
        case .high:
            return .orange
        case .normal:
            return .blue
        case .low:
            return .gray
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.1))
                .frame(width: 40, height: 40)
            
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
        }
    }
}

// MARK: - Priority Badge
struct PriorityBadge: View {
    let priority: NotificationPriority
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priority == .urgent ? "exclamationmark.2" : "exclamationmark")
                .font(.caption2)
            
            Text(priority.rawValue.capitalized)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(priority == .urgent ? Color.red : Color.orange)
        .cornerRadius(4)
    }
}

// MARK: - Empty Notifications View
struct EmptyNotificationsView: View {
    let filter: NotificationFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No \(filter.rawValue.lowercased()) notifications")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var emptyMessage: String {
        switch filter {
        case .all:
            return "You have no notifications yet. We'll notify you about order updates and special offers."
        case .unread:
            return "All caught up! You have no unread notifications."
        case .orders:
            return "No order notifications yet. Place your first order to get started!"
        case .promotions:
            return "No promotions available at the moment. Check back later for special deals!"
        }
    }
}

// MARK: - Extensions
extension Notification.Name {
    static let navigateToPromotions = Notification.Name("navigateToPromotions")
}

#Preview {
    NotificationCenterView()
}