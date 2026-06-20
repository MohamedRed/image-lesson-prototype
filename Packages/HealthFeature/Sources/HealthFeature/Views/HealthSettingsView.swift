import SwiftUI
import HealthService

struct HealthSettingsView: View {
    @EnvironmentObject private var healthViewModel: HealthViewModel
    @EnvironmentObject private var healthKitService: HealthKitService
    @Environment(\.dismiss) private var dismiss
    @State private var showingProfileEditor = false
    @State private var showingPrivacySettings = false
    
    var body: some View {
        NavigationStack {
            List {
                profileSection
                healthKitSection
                dataSection
                privacySection
                notificationsSection
                supportSection
            }
            .navigationTitle("Health Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingProfileEditor) {
                HealthProfileEditorView()
                    .environmentObject(healthViewModel)
            }
            .sheet(isPresented: $showingPrivacySettings) {
                PrivacySettingsView()
                    .environmentObject(healthViewModel)
            }
        }
    }
    
    private var profileSection: some View {
        Section("Profile") {
            Button("Edit Health Profile") {
                showingProfileEditor = true
            }
            
            if let profile = healthViewModel.profile {
                HStack {
                    Text("Age")
                    Spacer()
                    Text("\(profile.demographics?.age ?? 0)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Height")
                    Spacer()
                    if let height = profile.demographics?.height {
                        Text("\(height, specifier: "%.0f") cm")
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Active Goals")
                    Spacer()
                    Text("\(profile.goals.filter { $0.status == .active }.count)")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var healthKitSection: some View {
        Section("HealthKit Integration") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HealthKit Status")
                    Text(healthKitService.permissionStatus.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusIndicator
            }
            
            if healthKitService.permissionStatus != .authorized {
                Button("Grant HealthKit Permissions") {
                    Task {
                        await healthViewModel.requestHealthKitPermissions()
                    }
                }
            }
            
            if !healthKitService.authorizedDataTypes.isEmpty {
                NavigationLink("Manage Data Types") {
                    HealthKitDataTypesView()
                        .environmentObject(healthKitService)
                }
            }
            
            HStack {
                Text("Last Sync")
                Spacer()
                Text(healthKitService.lastSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                    .foregroundColor(.secondary)
            }
            
            Button("Sync Now") {
                // Manual sync trigger
            }
            .disabled(healthKitService.permissionStatus != .authorized)
        }
    }
    
    private var dataSection: some View {
        Section("Data Management") {
            NavigationLink("Export Health Data") {
                DataExportView()
                    .environmentObject(healthViewModel)
            }
            
            NavigationLink("Data Sources") {
                DataSourcesView()
            }
            
            Button("Clear Cache") {
                // Clear local cache
            }
            .foregroundColor(.orange)
        }
    }
    
    private var privacySection: some View {
        Section("Privacy & Security") {
            Button("Privacy Settings") {
                showingPrivacySettings = true
            }
            
            NavigationLink("Data Sharing") {
                DataSharingSettingsView()
                    .environmentObject(healthViewModel)
            }
            
            NavigationLink("Consent Management") {
                ConsentManagementView()
                    .environmentObject(healthViewModel)
            }
        }
    }
    
    private var notificationsSection: some View {
        Section("Notifications") {
            NavigationLink("Health Reminders") {
                NotificationSettingsView()
            }
            
            Toggle("Insight Notifications", isOn: .constant(true))
            Toggle("Program Updates", isOn: .constant(true))
            Toggle("Appointment Reminders", isOn: .constant(true))
        }
    }
    
    private var supportSection: some View {
        Section("Support") {
            NavigationLink("Help & FAQ") {
                HelpView()
            }
            
            Button("Contact Support") {
                // Open support contact
            }
            
            NavigationLink("About Health Feature") {
                AboutView()
            }
        }
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
    }
    
    private var statusColor: Color {
        switch healthKitService.permissionStatus {
        case .authorized: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        case .restricted: return .gray
        }
    }
}

struct HealthProfileEditorView: View {
    @EnvironmentObject private var healthViewModel: HealthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editableProfile: HealthProfile?
    
    var body: some View {
        NavigationStack {
            if let profile = editableProfile {
                ProfileEditorForm(profile: profile) { updatedProfile in
                    Task {
                        await healthViewModel.updateProfile(updatedProfile)
                        dismiss()
                    }
                }
            } else {
                ProgressView("Loading profile...")
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            editableProfile = healthViewModel.profile
        }
    }
}

struct ProfileEditorForm: View {
    let profile: HealthProfile
    let onSave: (HealthProfile) -> Void
    
    @State private var age: Int
    @State private var height: Double
    @State private var biologicalSex: BiologicalSex
    @State private var bloodType: BloodType?
    
    init(profile: HealthProfile, onSave: @escaping (HealthProfile) -> Void) {
        self.profile = profile
        self.onSave = onSave
        
        _age = State(initialValue: profile.demographics?.age ?? 25)
        _height = State(initialValue: profile.demographics?.height ?? 170)
        _biologicalSex = State(initialValue: profile.demographics?.biologicalSex ?? .notSet)
        _bloodType = State(initialValue: profile.demographics?.bloodType)
    }
    
    var body: some View {
        Form {
            Section("Basic Information") {
                HStack {
                    Text("Age")
                    Spacer()
                    TextField("Age", value: $age, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                
                HStack {
                    Text("Height (cm)")
                    Spacer()
                    TextField("Height", value: $height, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                
                Picker("Biological Sex", selection: $biologicalSex) {
                    Text("Not Set").tag(BiologicalSex.notSet)
                    Text("Female").tag(BiologicalSex.female)
                    Text("Male").tag(BiologicalSex.male)
                    Text("Other").tag(BiologicalSex.other)
                }
                
                Picker("Blood Type", selection: $bloodType) {
                    Text("Unknown").tag(Optional<BloodType>.none)
                    ForEach(BloodType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(Optional(type))
                    }
                }
            }
            
            Section {
                Button("Save Changes") {
                    saveProfile()
                }
                .disabled(age <= 0 || height <= 0)
            }
        }
    }
    
    private func saveProfile() {
        let updatedDemographics = Demographics(
            age: age,
            height: height,
            biologicalSex: biologicalSex,
            bloodType: bloodType
        )
        
        let updatedProfile = HealthProfile(
            id: profile.id,
            userId: profile.userId,
            demographics: updatedDemographics,
            consents: profile.consents,
            goals: profile.goals,
            measurementPreferences: profile.measurementPreferences,
            conditions: profile.conditions,
            emergencyContacts: profile.emergencyContacts,
            createdAt: profile.createdAt,
            updatedAt: Date()
        )
        
        onSave(updatedProfile)
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject private var healthViewModel: HealthViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Data Privacy") {
                    Toggle("Share data for research", isOn: .constant(false))
                    Toggle("Anonymous analytics", isOn: .constant(true))
                    Toggle("Personalized insights", isOn: .constant(true))
                }
                
                Section("Leaderboard") {
                    Toggle("Participate in leaderboards", isOn: .constant(true))
                    Toggle("Show real name", isOn: .constant(false))
                    Toggle("Show location", isOn: .constant(false))
                }
                
                Section("Data Retention") {
                    HStack {
                        Text("Keep data for")
                        Spacer()
                        Text("2 years")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Request Data Deletion") {
                        // Handle data deletion request
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HealthKitDataTypesView: View {
    @EnvironmentObject private var healthKitService: HealthKitService
    
    var body: some View {
        List {
            Section("Authorized Data Types") {
                ForEach(Array(healthKitService.authorizedDataTypes), id: \.self) { dataType in
                    HStack {
                        Image(systemName: iconForDataType(dataType))
                            .foregroundColor(.green)
                        
                        Text(displayNameForDataType(dataType))
                        
                        Spacer()
                        
                        Text("Authorized")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .navigationTitle("HealthKit Data")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func iconForDataType(_ dataType: String) -> String {
        switch dataType {
        case "steps": return "figure.walk"
        case "heartRate": return "heart.fill"
        case "weight": return "scalemass.fill"
        case "sleep": return "bed.double.fill"
        default: return "heart.text.square"
        }
    }
    
    private func displayNameForDataType(_ dataType: String) -> String {
        switch dataType {
        case "steps": return "Steps"
        case "heartRate": return "Heart Rate"
        case "weight": return "Body Weight"
        case "sleep": return "Sleep Analysis"
        default: return dataType.capitalized
        }
    }
}

struct DataExportView: View {
    @EnvironmentObject private var healthViewModel: HealthViewModel
    @State private var isExporting = false
    
    var body: some View {
        List {
            Section("Export Options") {
                HStack {
                    Text("Format")
                    Spacer()
                    Text("JSON")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Date Range")
                    Spacer()
                    Text("Last 30 days")
                        .foregroundColor(.secondary)
                }
                
                Toggle("Include HealthKit data", isOn: .constant(true))
                Toggle("Include program data", isOn: .constant(true))
                Toggle("Include insights", isOn: .constant(false))
            }
            
            Section {
                Button("Export Data") {
                    exportData()
                }
                .disabled(isExporting)
                
                if isExporting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Preparing export...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func exportData() {
        isExporting = true
        
        // Simulate export process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isExporting = false
            // Show share sheet or success message
        }
    }
}

struct DataSourcesView: View {
    var body: some View {
        List {
            Section("Connected Sources") {
                DataSourceRow(
                    name: "HealthKit",
                    icon: "heart.fill",
                    status: .connected,
                    lastSync: Date()
                )
                
                DataSourceRow(
                    name: "Manual Entry",
                    icon: "square.and.pencil",
                    status: .connected,
                    lastSync: Date()
                )
            }
            
            Section("Available Sources") {
                DataSourceRow(
                    name: "Fitbit",
                    icon: "watch",
                    status: .available,
                    lastSync: nil
                )
                
                DataSourceRow(
                    name: "MyFitnessPal",
                    icon: "fork.knife",
                    status: .available,
                    lastSync: nil
                )
            }
        }
        .navigationTitle("Data Sources")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataSourceRow: View {
    let name: String
    let icon: String
    let status: DataSourceStatus
    let lastSync: Date?
    
    enum DataSourceStatus {
        case connected, available, disconnected
        
        var color: Color {
            switch self {
            case .connected: return .green
            case .available: return .blue
            case .disconnected: return .red
            }
        }
        
        var text: String {
            switch self {
            case .connected: return "Connected"
            case .available: return "Available"
            case .disconnected: return "Disconnected"
            }
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(status.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                
                if let lastSync = lastSync {
                    Text("Last sync: \(lastSync.timeAgoDisplay)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(status.text)
                .font(.caption)
                .foregroundColor(status.color)
        }
    }
}

struct DataSharingSettingsView: View {
    @EnvironmentObject private var healthViewModel: HealthViewModel
    
    var body: some View {
        List {
            Section("Healthcare Providers") {
                Toggle("Share with primary care physician", isOn: .constant(false))
                Toggle("Share with specialists", isOn: .constant(false))
            }
            
            Section("Research") {
                Toggle("Contribute to health research", isOn: .constant(false))
                Toggle("Anonymous research participation", isOn: .constant(true))
            }
            
            Section("Family") {
                Toggle("Share with family members", isOn: .constant(false))
                Button("Manage family access") {
                    // Navigate to family sharing settings
                }
            }
        }
        .navigationTitle("Data Sharing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ConsentManagementView: View {
    @EnvironmentObject private var healthViewModel: HealthViewModel
    
    var body: some View {
        List {
            if let profile = healthViewModel.profile {
                ForEach(profile.consents, id: \.type) { consent in
                    ConsentRow(consent: consent) { updatedConsent in
                        Task {
                            await healthViewModel.updateConsent(updatedConsent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Consents")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ConsentRow: View {
    let consent: HealthConsent
    let onUpdate: (HealthConsent) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(consent.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { consent.granted },
                    set: { granted in
                        let updatedConsent = HealthConsent(
                            type: consent.type,
                            granted: granted,
                            grantedAt: granted ? Date() : consent.grantedAt,
                            version: consent.version
                        )
                        onUpdate(updatedConsent)
                    }
                ))
            }
            
            Text(consent.type.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if consent.granted, let grantedAt = consent.grantedAt {
                Text("Granted: \(grantedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

extension HealthConsent.ConsentType {
    var displayName: String {
        switch self {
        case .dataProcessing: return "Data Processing"
        case .research: return "Research Participation"
        case .marketing: return "Marketing Communications"
        case .thirdPartySharing: return "Third-party Sharing"
        }
    }
    
    var description: String {
        switch self {
        case .dataProcessing: return "Allow processing of health data for personalized insights"
        case .research: return "Participate in anonymous health research studies"
        case .marketing: return "Receive health tips and product recommendations"
        case .thirdPartySharing: return "Share anonymized data with partner organizations"
        }
    }
}

struct NotificationSettingsView: View {
    var body: some View {
        List {
            Section("Reminders") {
                Toggle("Daily health check-in", isOn: .constant(true))
                Toggle("Medication reminders", isOn: .constant(false))
                Toggle("Exercise reminders", isOn: .constant(true))
                Toggle("Sleep reminders", isOn: .constant(true))
            }
            
            Section("Insights") {
                Toggle("New insights available", isOn: .constant(true))
                Toggle("Weekly health summary", isOn: .constant(true))
                Toggle("Goal achievements", isOn: .constant(true))
            }
            
            Section("Programs") {
                Toggle("Program step reminders", isOn: .constant(true))
                Toggle("Program milestones", isOn: .constant(true))
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section("Getting Started") {
                NavigationLink("Setting up your health profile") {
                    Text("Help content here")
                }
                NavigationLink("Connecting HealthKit") {
                    Text("Help content here")
                }
                NavigationLink("Understanding your data") {
                    Text("Help content here")
                }
            }
            
            Section("Features") {
                NavigationLink("Health programs") {
                    Text("Help content here")
                }
                NavigationLink("Insights and recommendations") {
                    Text("Help content here")
                }
                NavigationLink("Leaderboards") {
                    Text("Help content here")
                }
            }
        }
        .navigationTitle("Help & FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section("Version") {
                HStack {
                    Text("Health Feature")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Privacy") {
                NavigationLink("Privacy Policy") {
                    Text("Privacy policy content")
                }
                NavigationLink("Terms of Service") {
                    Text("Terms of service content")
                }
            }
            
            Section("Open Source") {
                NavigationLink("Licenses") {
                    Text("Open source licenses")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension HealthKitService.PermissionStatus {
    var description: String {
        switch self {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        }
    }
}

#Preview {
    NavigationStack {
        HealthSettingsView()
    }
}