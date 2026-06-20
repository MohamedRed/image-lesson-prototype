import SwiftUI
import FoodDeliveryService

/// Settings view for courier configuration and preferences
public struct CourierSettingsView: View {
    @ObservedObject var viewModel: CourierViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEditingProfile = false
    @State private var workingHours = CourierWorkingHours()
    @State private var notificationSettings = NotificationSettings()
    @State private var vehicleInfo = VehicleInfo()
    
    public var body: some View {
        NavigationView {
            List {
                // Profile section
                Section("Profile") {
                    ProfileRow(viewModel: viewModel) {
                        isEditingProfile = true
                    }
                }
                
                // Vehicle information
                Section("Vehicle") {
                    VehicleInfoSection(vehicleInfo: $vehicleInfo)
                }
                
                // Working hours
                Section("Working Hours") {
                    WorkingHoursSection(workingHours: $workingHours)
                }
                
                // Notifications
                Section("Notifications") {
                    CourierNotificationSettingsSection(settings: $notificationSettings)
                }
                
                // Safety and support
                Section("Safety & Support") {
                    SafetySupportSection()
                }
                
                // Account actions
                Section {
                    AccountActionsSection()
                    // Minimal KYC submission stub
                    CourierKycSection(viewModel: viewModel)
                }
            }
            .navigationTitle("Courier Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $isEditingProfile) {
            EditProfileSheet(viewModel: viewModel)
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        // Load current settings from service or UserDefaults
        // For now, using default values
    }
}

// MARK: - Profile Row
struct ProfileRow: View {
    @ObservedObject var viewModel: CourierViewModel
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Profile image
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                
                // Profile info
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.courierProfile?.name ?? "Courier Name")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        
                        Text("\(viewModel.courierRating, specifier: "%.1f")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("• \(viewModel.todayDeliveries) deliveries today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(viewModel.isOnline ? .green : .gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusText: String {
        viewModel.isOnline ? "Online" : "Offline"
    }
}

// MARK: - Vehicle Info Section
struct VehicleInfoSection: View {
    @Binding var vehicleInfo: VehicleInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Vehicle Type", selection: $vehicleInfo.type) {
                ForEach(VehicleType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            
            HStack {
                Text("License Plate")
                Spacer()
                TextField("ABC-123", text: $vehicleInfo.licensePlate)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
            }
            
            HStack {
                Text("Model")
                Spacer()
                TextField("Vehicle Model", text: $vehicleInfo.model)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 120)
            }
            
            HStack {
                Text("Color")
                Spacer()
                TextField("Color", text: $vehicleInfo.color)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
            }
        }
    }
}

// MARK: - Working Hours Section
struct WorkingHoursSection: View {
    @Binding var workingHours: CourierWorkingHours
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Available 24/7", isOn: $workingHours.isAlwaysAvailable)
            
            if !workingHours.isAlwaysAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Working Hours")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("Start Time")
                        Spacer()
                        DatePicker("", selection: $workingHours.startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    
                    HStack {
                        Text("End Time")
                        Spacer()
                        DatePicker("", selection: $workingHours.endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Working Days")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(Weekday.allCases, id: \.self) { day in
                    Toggle(day.displayName, isOn: binding(for: day))
                }
            }
        }
    }
    
    private func binding(for day: Weekday) -> Binding<Bool> {
        Binding(
            get: { workingHours.workingDays.contains(day) },
            set: { isSelected in
                if isSelected {
                    workingHours.workingDays.insert(day)
                } else {
                    workingHours.workingDays.remove(day)
                }
            }
        )
    }
}

// MARK: - Notification Settings Section
struct CourierNotificationSettingsSection: View {
    @Binding var settings: NotificationSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("New Order Alerts", isOn: $settings.newOrderAlerts)
            Toggle("Order Status Updates", isOn: $settings.orderStatusUpdates)
            Toggle("Earnings Summary", isOn: $settings.earningsSummary)
            Toggle("Promotional Offers", isOn: $settings.promotionalOffers)
            
            if settings.newOrderAlerts {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alert Sound")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Alert Sound", selection: $settings.alertSound) {
                        ForEach(AlertSound.allCases, id: \.self) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
        }
    }
}

// MARK: - Safety Support Section
struct SafetySupportSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink("Emergency Contacts") {
                EmergencyContactsView()
            }
            
            NavigationLink("Safety Guidelines") {
                SafetyGuidelinesView()
            }
            
            NavigationLink("Report Issue") {
                ReportIssueView()
            }
            
            NavigationLink("Help & Support") {
                HelpSupportView()
            }
        }
    }
}

// MARK: - Account Actions Section
struct AccountActionsSection: View {
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Privacy Policy") {
                // Open privacy policy
            }
            .foregroundColor(.blue)
            
            Button("Terms of Service") {
                // Open terms of service
            }
            .foregroundColor(.blue)
            
            Button("Sign Out") {
                // Sign out
            }
            .foregroundColor(.orange)
            
            Button("Delete Account") {
                showingDeleteAlert = true
            }
            .foregroundColor(.red)
        }
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Handle account deletion
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
    }
}

// MARK: - Courier KYC Section
struct CourierKycSection: View {
    @ObservedObject var viewModel: CourierViewModel
    @State private var docUrlsCsv = ""
    @State private var isSubmitting = false
    @State private var statusMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KYC Verification")
                .font(.headline)
            if let status = viewModel.courierProfile?.kyc.status {
                HStack(spacing: 8) {
                    Circle().fill(kycColor(for: status)).frame(width: 8, height: 8)
                    Text("Status: \(status.rawValue.capitalized)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Refresh") {
                        Task { await viewModel.refreshKycStatus() }
                    }
                    .font(.caption)
                }
            }
            Text("Provide document URLs (comma-separated) and submit for review.")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("https://...id1, https://...id2", text: $docUrlsCsv)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(isSubmitting ? "Submitting..." : "Submit KYC") {
                Task { await submit() }
            }
            .disabled(isSubmitting || docUrlsCsv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let msg = statusMessage { Text(msg).font(.caption).foregroundColor(.green) }
        }
    }
    
    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let docs = docUrlsCsv.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        do {
            await viewModel.submitKyc(documents: docs)
            statusMessage = "Submitted"
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }
    }
}

private func kycColor(for status: Restaurant.KYC.KYCStatus) -> Color {
    switch status {
    case .approved: return .green
    case .pending, .incomplete: return .orange
    case .rejected: return .red
    }
}

// MARK: - Edit Profile Sheet
struct EditProfileSheet: View {
    @ObservedObject var viewModel: CourierViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var fullName = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var profileImageUrl = ""
    @State private var isUpdating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("Full Name", text: $fullName)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section("Profile Picture") {
                    TextField("Profile Image URL", text: $profileImageUrl)
                        .autocapitalization(.none)
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isUpdating || fullName.isEmpty)
                }
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
    }
    
    private func loadCurrentProfile() {
        if let profile = viewModel.courierProfile {
            fullName = profile.name
            phoneNumber = ""
            email = ""
            profileImageUrl = ""
        }
    }
    
    private func saveProfile() {
        guard let currentProfile = viewModel.courierProfile else { return }
        
        let updatedProfile = Courier(
            id: currentProfile.id,
            userId: currentProfile.userId,
            name: fullName.isEmpty ? currentProfile.name : fullName,
            vehicleType: currentProfile.vehicleType,
            rating: currentProfile.rating,
            isOnline: currentProfile.isOnline,
            currentOrderId: currentProfile.currentOrderId,
            location: currentProfile.location,
            kyc: currentProfile.kyc,
            payouts: currentProfile.payouts,
            createdAt: currentProfile.createdAt
        )
        
        Task {
            isUpdating = true
            await viewModel.updateProfile(updatedProfile)
            isUpdating = false
            dismiss()
        }
    }
}

// MARK: - Placeholder Views
struct EmergencyContactsView: View {
    var body: some View {
        Text("Emergency Contacts")
            .navigationTitle("Emergency Contacts")
    }
}

struct SafetyGuidelinesView: View {
    var body: some View {
        Text("Safety Guidelines")
            .navigationTitle("Safety Guidelines")
    }
}

struct ReportIssueView: View {
    var body: some View {
        Text("Report Issue")
            .navigationTitle("Report Issue")
    }
}

struct HelpSupportView: View {
    var body: some View {
        Text("Help & Support")
            .navigationTitle("Help & Support")
    }
}

// MARK: - Data Models
struct CourierWorkingHours {
    var isAlwaysAvailable = false
    var startTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    var endTime = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var workingDays: Set<Weekday> = Set(Weekday.allCases)
}

struct NotificationSettings {
    var newOrderAlerts = true
    var orderStatusUpdates = true
    var earningsSummary = true
    var promotionalOffers = false
    var alertSound: AlertSound = .default
}

struct VehicleInfo {
    var type: VehicleType = .motorcycle
    var licensePlate = ""
    var model = ""
    var color = ""
}

enum VehicleType: String, CaseIterable {
    case motorcycle = "motorcycle"
    case bicycle = "bicycle"
    case car = "car"
    case scooter = "scooter"
    
    var displayName: String {
        switch self {
        case .motorcycle: return "Motorcycle"
        case .bicycle: return "Bicycle"
        case .car: return "Car"
        case .scooter: return "Scooter"
        }
    }
}

enum Weekday: String, CaseIterable {
    case monday = "monday"
    case tuesday = "tuesday"
    case wednesday = "wednesday"
    case thursday = "thursday"
    case friday = "friday"
    case saturday = "saturday"
    case sunday = "sunday"
    
    var displayName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }
}

enum AlertSound: String, CaseIterable {
    case `default` = "default"
    case gentle = "gentle"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .gentle: return "Gentle"
        case .urgent: return "Urgent"
        }
    }
}

#Preview {
    let mockService = MockFoodDeliveryService()
    let viewModel = CourierViewModel(service: mockService)
    
    return CourierSettingsView(viewModel: viewModel)
}