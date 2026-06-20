import SwiftUI
import FriendsService

struct SettingsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var currentPresence: PresenceStatus.Status = .online
    
    var body: some View {
        List {
            Section("Presence") {
                Picker("Status", selection: $currentPresence) {
                    ForEach(PresenceStatus.Status.allCases, id: \.self) { status in
                        HStack {
                            Circle()
                                .fill(status.color)
                                .frame(width: 12, height: 12)
                            Text(status.rawValue.capitalized)
                        }
                        .tag(status)
                    }
                }
                .onChange(of: currentPresence) { newValue in
                    Task {
                        try? await viewModel.updatePresence(newValue)
                    }
                }
            }
            
            Section("Privacy & Safety") {
                NavigationLink("Privacy Settings") {
                    PrivacySettingsView(viewModel: viewModel)
                }
                
                NavigationLink("Blocked Users") {
                    BlockedUsersView(viewModel: viewModel)
                }
                
                NavigationLink("Report a Problem") {
                    ReportProblemView()
                }
            }
            
            Section("Notifications") {
                NavigationLink("Notification Settings") {
                    NotificationSettingsView()
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                NavigationLink("Privacy Policy") {
                    // TODO: Privacy policy view
                    Text("Privacy Policy")
                }
                
                NavigationLink("Terms of Service") {
                    // TODO: Terms of service view
                    Text("Terms of Service")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReportProblemView: View {
    @State private var problemDescription = ""
    @State private var selectedCategory = ProblemCategory.spam
    @State private var isSubmitting = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Problem Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ProblemCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Description") {
                    TextField("Please describe the problem...", text: $problemDescription, axis: .vertical)
                        .lineLimit(5...10)
                }
                
                Section {
                    Text("Your report will be reviewed by our safety team. We may contact you for additional information.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Report Problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitReport()
                    }
                    .disabled(problemDescription.isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        
        // TODO: Submit report to backend
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            dismiss()
        }
    }
}

enum ProblemCategory: String, CaseIterable {
    case spam = "spam"
    case harassment = "harassment"
    case inappropriateContent = "inappropriate_content"
    case technicalIssue = "technical_issue"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Harassment"
        case .inappropriateContent: return "Inappropriate Content"
        case .technicalIssue: return "Technical Issue"
        case .other: return "Other"
        }
    }
}

struct NotificationSettingsView: View {
    @State private var messageNotifications = true
    @State private var friendRequestNotifications = true
    @State private var groupInviteNotifications = true
    @State private var soundEnabled = true
    @State private var vibrationEnabled = true
    
    var body: some View {
        List {
            Section("Message Notifications") {
                Toggle("Messages", isOn: $messageNotifications)
                Toggle("Friend Requests", isOn: $friendRequestNotifications)
                Toggle("Group Invites", isOn: $groupInviteNotifications)
            }
            
            Section("Alert Style") {
                Toggle("Sound", isOn: $soundEnabled)
                Toggle("Vibration", isOn: $vibrationEnabled)
            }
            
            Section("Quiet Hours") {
                NavigationLink("Schedule Quiet Hours") {
                    // TODO: Quiet hours configuration
                    Text("Quiet Hours")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: messageNotifications) { _ in saveSettings() }
        .onChange(of: friendRequestNotifications) { _ in saveSettings() }
        .onChange(of: groupInviteNotifications) { _ in saveSettings() }
        .onChange(of: soundEnabled) { _ in saveSettings() }
        .onChange(of: vibrationEnabled) { _ in saveSettings() }
    }
    
    private func saveSettings() {
        // TODO: Save notification preferences
    }
}