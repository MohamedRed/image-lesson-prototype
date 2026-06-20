import SwiftUI
import FoodDeliveryService
import UserNotifications

/// Notification preferences and settings management
public struct NotificationSettingsView: View {
    @ObservedObject var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var preferences = UserNotificationPreferences(
        userId: "current_user",
        phoneNumber: "+212 6XX XXX XXX",
        email: "user@example.com"
    )
    
    @State private var showingQuietHoursEditor = false
    @State private var showingTestNotification = false
    @State private var isLoading = false
    
    public init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }
    
    public var body: some View {
        NavigationView {
            Form {
                // Permission status
                PermissionStatusSection(
                    notificationService: notificationService,
                    onRequestPermissions: {
                        notificationService.requestPermissions()
                    }
                )
                
                // General preferences
                GeneralPreferencesSection(preferences: $preferences)
                
                // Notification types
                NotificationTypesSection(preferences: $preferences)
                
                // Delivery preferences
                DeliveryPreferencesSection(preferences: $preferences)
                
                // Quiet hours
                QuietHoursSection(
                    preferences: $preferences,
                    onEdit: { showingQuietHoursEditor = true }
                )
                
                // Language and format
                LanguageFormatSection(preferences: $preferences)
                
                // Test notifications
                TestNotificationSection(
                    onSendTest: { sendTestNotification() }
                )
                
                // Advanced settings
                AdvancedSettingsSection()
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePreferences()
                    }
                    .disabled(isLoading)
                }
            }
        }
        .sheet(isPresented: $showingQuietHoursEditor) {
            QuietHoursEditor(preferences: $preferences)
        }
        .task {
            await loadPreferences()
        }
    }
    
    private func loadPreferences() async {
        isLoading = true
        
        do {
            preferences = try await notificationService.getUserNotificationPreferences(userId: "current_user")
        } catch {
            print("Failed to load preferences: \(error)")
        }
        
        isLoading = false
    }
    
    private func savePreferences() {
        isLoading = true
        
        Task {
            do {
                try await notificationService.updateNotificationPreferences(
                    userId: "current_user",
                    preferences: preferences
                )
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("Failed to save preferences: \(error)")
                }
            }
        }
    }
    
    private func sendTestNotification() {
        Task {
            do {
                try await notificationService.sendNotification(
                    to: "current_user",
                    event: .orderPlaced,
                    data: [
                        "orderId": "TEST123",
                        "total": "150",
                        "estimatedTime": "30 minutes"
                    ],
                    priority: .normal
                )
            } catch {
                print("Failed to send test notification: \(error)")
            }
        }
    }
}

// MARK: - Permission Status Section
struct PermissionStatusSection: View {
    @ObservedObject var notificationService: NotificationService
    let onRequestPermissions: () -> Void
    
    var body: some View {
        Section("Push Notification Permissions") {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Push Notifications")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(statusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if notificationService.pushNotificationPermissionStatus != .authorized {
                    Button("Enable") {
                        onRequestPermissions()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if let fcmToken = notificationService.fcmToken {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device Token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(fcmToken.prefix(32)) + "...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    private var statusIcon: String {
        switch notificationService.pushNotificationPermissionStatus {
        case .authorized, .provisional:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch notificationService.pushNotificationPermissionStatus {
        case .authorized, .provisional:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var statusDescription: String {
        switch notificationService.pushNotificationPermissionStatus {
        case .authorized:
            return "Push notifications are enabled"
        case .provisional:
            return "Quiet notifications are enabled"
        case .denied:
            return "Push notifications are disabled"
        case .notDetermined:
            return "Permission not requested yet"
        @unknown default:
            return "Unknown status"
        }
    }
}

// MARK: - General Preferences Section
struct GeneralPreferencesSection: View {
    @Binding var preferences: UserNotificationPreferences
    
    var body: some View {
        Section("General") {
            Toggle("Push Notifications", isOn: $preferences.pushEnabled)
            Toggle("SMS Notifications", isOn: $preferences.smsEnabled)
            Toggle("Email Notifications", isOn: $preferences.emailEnabled)
            
            if preferences.smsEnabled {
                HStack {
                    Text("Phone Number")
                    Spacer()
                    TextField("Phone", text: $preferences.phoneNumber)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.phonePad)
                }
            }
            
            if preferences.emailEnabled {
                HStack {
                    Text("Email Address")
                    Spacer()
                    TextField("Email", text: $preferences.email)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
        }
    }
}

// MARK: - Notification Types Section
struct NotificationTypesSection: View {
    @Binding var preferences: UserNotificationPreferences
    
    var body: some View {
        Section("Notification Types") {
            NotificationTypeRow(
                title: "Order Updates",
                description: "Order status changes, confirmations, and delivery updates",
                icon: "bag.fill",
                color: .blue,
                isEnabled: $preferences.orderUpdates
            )
            
            NotificationTypeRow(
                title: "Courier Updates",
                description: "Courier assignment, location, and delivery progress",
                icon: "car.fill",
                color: .green,
                isEnabled: $preferences.courierUpdates
            )
            
            NotificationTypeRow(
                title: "Promotions & Deals",
                description: "Special offers, discounts, and promotional campaigns",
                icon: "tag.fill",
                color: .orange,
                isEnabled: $preferences.promotions
            )
            
            if preferences.merchantUpdates != nil {
                NotificationTypeRow(
                    title: "Merchant Updates",
                    description: "New orders, cancellations, and business insights",
                    icon: "building.2.fill",
                    color: .purple,
                    isEnabled: $preferences.merchantUpdates
                )
            }
        }
    }
}

// MARK: - Notification Type Row
struct NotificationTypeRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Delivery Preferences Section
struct DeliveryPreferencesSection: View {
    @Binding var preferences: UserNotificationPreferences
    
    var body: some View {
        Section("Delivery Preferences") {
            HStack {
                Text("Notification Sound")
                Spacer()
                Text("Default")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Vibration")
                Spacer()
                Text("Enabled")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Badge Count")
                Spacer()
                Text("Show Unread")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Quiet Hours Section
struct QuietHoursSection: View {
    @Binding var preferences: UserNotificationPreferences
    let onEdit: () -> Void
    
    var body: some View {
        Section("Quiet Hours") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Do Not Disturb")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("No notifications during these hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(preferences.quietHours.start) - \(preferences.quietHours.end)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button("Edit Quiet Hours") {
                onEdit()
            }
            .foregroundColor(.blue)
        }
    }
}

// MARK: - Language Format Section
struct LanguageFormatSection: View {
    @Binding var preferences: UserNotificationPreferences
    
    private let languages = [
        ("fr-MA", "Français (Maroc)"),
        ("ar-MA", "العربية (المغرب)"),
        ("en-US", "English")
    ]
    
    var body: some View {
        Section("Language & Format") {
            Picker("Language", selection: $preferences.preferredLanguage) {
                ForEach(languages, id: \.0) { code, name in
                    Text(name).tag(code)
                }
            }
            
            HStack {
                Text("Time Format")
                Spacer()
                Text("24-hour")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Date Format")
                Spacer()
                Text("DD/MM/YYYY")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Test Notification Section
struct TestNotificationSection: View {
    let onSendTest: () -> Void
    
    var body: some View {
        Section("Test Notifications") {
            Button("Send Test Notification") {
                onSendTest()
            }
            .foregroundColor(.blue)
            
            Text("Send a test notification to verify your settings are working correctly")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Advanced Settings Section
struct AdvancedSettingsSection: View {
    var body: some View {
        Section("Advanced") {
            NavigationLink("Notification History") {
                NotificationHistoryView()
            }
            
            Button("Clear All Notifications") {
                // Handle clear all
            }
            .foregroundColor(.red)
            
            Button("Reset to Defaults") {
                // Handle reset
            }
            .foregroundColor(.blue)
        }
        
        Section("About") {
            HStack {
                Text("Notification Service")
                Spacer()
                Text("Firebase Cloud Messaging")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            HStack {
                Text("Privacy Policy")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Quiet Hours Editor
struct QuietHoursEditor: View {
    @Binding var preferences: UserNotificationPreferences
    @Environment(\.dismiss) private var dismiss
    
    @State private var startTime: Date
    @State private var endTime: Date
    
    init(preferences: Binding<UserNotificationPreferences>) {
        self._preferences = preferences
        
        // Convert string times to dates
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let start = formatter.date(from: preferences.wrappedValue.quietHours.start) ?? Date()
        let end = formatter.date(from: preferences.wrappedValue.quietHours.end) ?? Date()
        
        self._startTime = State(initialValue: start)
        self._endTime = State(initialValue: end)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Quiet Hours Schedule") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                
                Section {
                    Text("During quiet hours, you'll only receive urgent notifications like order cancellations or delivery issues.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Quiet Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveQuietHours()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveQuietHours() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        preferences.quietHours = QuietHours(
            start: formatter.string(from: startTime),
            end: formatter.string(from: endTime)
        )
    }
}

// MARK: - Notification History View
struct NotificationHistoryView: View {
    var body: some View {
        Text("Notification History")
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NotificationSettingsView(notificationService: NotificationService())
}