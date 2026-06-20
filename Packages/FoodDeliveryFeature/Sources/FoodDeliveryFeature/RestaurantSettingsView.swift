import SwiftUI
import FoodDeliveryService

/// Restaurant settings and configuration interface
public struct RestaurantSettingsView: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    @State private var showingHoursEditor = false
    @State private var showingDeliverySettings = false
    @State private var showingNotificationSettings = false
    
    public var body: some View {
        Form {
            // Restaurant information
            RestaurantInfoSection(restaurant: viewModel.restaurant)
            
            // Operating hours
            OperatingHoursSection(
                restaurant: viewModel.restaurant,
                onEdit: { showingHoursEditor = true }
            )
            
            // Delivery settings
            DeliverySettingsSection(
                restaurant: viewModel.restaurant,
                onEdit: { showingDeliverySettings = true }
            )
            
            // Notification preferences
            NotificationSettingsSection(
                onEdit: { showingNotificationSettings = true }
            )
            
            // Account settings
            AccountSettingsSection(viewModel: viewModel)
            
            // Support and help
            SupportSection()
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingHoursEditor) {
            if let restaurant = viewModel.restaurant {
                OperatingHoursEditor(restaurant: restaurant)
            }
        }
        .sheet(isPresented: $showingDeliverySettings) {
            if let restaurant = viewModel.restaurant {
                DeliverySettingsEditor(restaurant: restaurant)
            }
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsEditor()
        }
    }
}

// MARK: - Restaurant Info Section
struct RestaurantInfoSection: View {
    let restaurant: Restaurant?
    
    var body: some View {
        Section("Restaurant Information") {
            HStack {
                Text("Name")
                Spacer()
                Text(restaurant?.name ?? "Loading...")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Phone")
                Spacer()
                Text(restaurant?.phone ?? "Not set")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Address")
                Spacer()
                Text(restaurant?.address.street ?? "Not set")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            
            HStack {
                Text("Cuisine Tags")
                Spacer()
                Text(restaurant?.cuisineTags.joined(separator: ", ") ?? "None")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            
            Button("Edit Restaurant Info") {
                // Handle edit restaurant info
            }
            .foregroundColor(.blue)
        }
    }
}

// MARK: - Operating Hours Section
struct OperatingHoursSection: View {
    let restaurant: Restaurant?
    let onEdit: () -> Void
    
    var body: some View {
        Section("Operating Hours") {
            if let hours = restaurant?.openingHours {
                ForEach(sortedDays(hours), id: \.key) { day, timeRanges in
                    HStack {
                        Text(day.capitalized)
                            .frame(width: 80, alignment: .leading)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            ForEach(timeRanges, id: \.start) { range in
                                Text("\(range.start) - \(range.end)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            Button("Edit Hours") {
                onEdit()
            }
            .foregroundColor(.blue)
        }
    }
    
    private func sortedDays(_ hours: [String: [Restaurant.TimeRange]]) -> [(key: String, value: [Restaurant.TimeRange])] {
        let dayOrder = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        return dayOrder.compactMap { day in
            if let timeRanges = hours[day] {
                return (key: day, value: timeRanges)
            }
            return nil
        }
    }
}

// MARK: - Delivery Settings Section
struct DeliverySettingsSection: View {
    let restaurant: Restaurant?
    let onEdit: () -> Void
    
    var body: some View {
        Section("Delivery Settings") {
            if let policy = restaurant?.deliveryFeePolicy {
                HStack {
                    Text("Base Delivery Fee")
                    Spacer()
                    Text("\(policy.baseMAD, specifier: "%.0f") MAD")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Per KM Fee")
                    Spacer()
                    Text("\(policy.perKmMAD, specifier: "%.2f") MAD")
                        .foregroundColor(.secondary)
                }
                
                if let minOrder = policy.minimumOrderMAD {
                    HStack {
                        Text("Minimum Order")
                        Spacer()
                        Text("\(minOrder, specifier: "%.0f") MAD")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let smallOrderFee = policy.smallOrderFeeMAD {
                    HStack {
                        Text("Small Order Fee")
                        Spacer()
                        Text("\(smallOrderFee, specifier: "%.0f") MAD")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                Text("Delivery Zones")
                Spacer()
                Text("\(restaurant?.deliveryZones.count ?? 0) zones")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Average Prep Time")
                Spacer()
                Text("\(restaurant?.avgPrepMinutes ?? 0) minutes")
                    .foregroundColor(.secondary)
            }
            
            Button("Edit Delivery Settings") {
                onEdit()
            }
            .foregroundColor(.blue)
        }
    }
}

// MARK: - Notification Settings Section
struct NotificationSettingsSection: View {
    let onEdit: () -> Void
    
    var body: some View {
        Section("Notification Preferences") {
            HStack {
                Text("New Orders")
                Spacer()
                Text("Push + Sound")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Order Updates")
                Spacer()
                Text("Push Only")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Customer Messages")
                Spacer()
                Text("Enabled")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Marketing Updates")
                Spacer()
                Text("Disabled")
                    .foregroundColor(.secondary)
            }
            
            Button("Edit Notifications") {
                onEdit()
            }
            .foregroundColor(.blue)
        }
    }
}

// MARK: - Account Settings Section
struct AccountSettingsSection: View {
    @ObservedObject var viewModel: MerchantConsoleViewModel
    @State private var isSubmittingKyc = false
    @State private var kycDocsCsv = ""
    @State private var kycStatusMessage: String?
    var body: some View {
        Section("Account") {
            NavigationLink("Payment & Billing") {
                PaymentBillingView()
            }
            
            NavigationLink("Tax Information") {
                TaxInformationView()
            }
            
            NavigationLink("Business Documents") { BusinessDocumentsView() }

            VStack(alignment: .leading, spacing: 8) {
                Text("KYC Verification")
                    .font(.headline)
                if let status = viewModel.restaurant?.kyc.status {
                    HStack(spacing: 8) {
                        Circle().fill(color(for: status)).frame(width: 8, height: 8)
                        Text("Status: \(status.rawValue.capitalized)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Refresh") {
                            Task {
                                await viewModel.refreshMerchantKycStatus()
                            }
                        }.font(.caption)
                    }
                }
                Text("Enter document URLs (comma-separated) and submit for review.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("https://...id1, https://...id2", text: $kycDocsCsv)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(isSubmittingKyc ? "Submitting..." : "Submit KYC") {
                    Task { await submitKyc() }
                }
                .disabled(isSubmittingKyc || kycDocsCsv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let msg = kycStatusMessage { Text(msg).font(.caption).foregroundColor(.green) }
            }
            
            Button("Change Password") {
                // Handle password change
            }
            .foregroundColor(.blue)
        }
    }

    private func color(for status: Restaurant.KYC.KYCStatus) -> Color {
        switch status {
        case .approved: return .green
        case .pending, .incomplete: return .orange
        case .rejected: return .red
        }
    }

    private func submitKyc() async {
        isSubmittingKyc = true
        defer { isSubmittingKyc = false }
        let docs = kycDocsCsv.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        await viewModel.submitRestaurantKyc(documents: docs)
        kycStatusMessage = viewModel.errorMessage == nil ? "Submitted" : ("Failed: \(viewModel.errorMessage!)")
    }
}

// MARK: - Support Section
struct SupportSection: View {
    var body: some View {
        Section("Support & Help") {
            Button("Contact Support") {
                // Handle contact support
            }
            .foregroundColor(.blue)
            
            Button("Help Center") {
                // Handle help center
            }
            .foregroundColor(.blue)
            
            Button("Report a Problem") {
                // Handle report problem
            }
            .foregroundColor(.blue)
            
            Button("Terms & Conditions") {
                // Handle terms
            }
            .foregroundColor(.blue)
            
            Button("Privacy Policy") {
                // Handle privacy policy
            }
            .foregroundColor(.blue)
        }
        
        Section("App Information") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text("2024.1")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Operating Hours Editor
struct OperatingHoursEditor: View {
    let restaurant: Restaurant
    @Environment(\.dismiss) private var dismiss
    
    @State private var hours: [String: [Restaurant.TimeRange]]
    
    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        self._hours = State(initialValue: restaurant.openingHours)
    }
    
    var body: some View {
        NavigationView {
            Form {
                ForEach(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"], id: \.self) { day in
                    Section(day.capitalized) {
                        if let dayHours = hours[day], !dayHours.isEmpty {
                            ForEach(dayHours.indices, id: \.self) { index in
                                HStack {
                                    TextField("Start", text: .constant(dayHours[index].start))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Text("to")
                                        .foregroundColor(.secondary)
                                    
                                    TextField("End", text: .constant(dayHours[index].end))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button("Remove") {
                                        hours[day]?.remove(at: index)
                                    }
                                    .foregroundColor(.red)
                                    .font(.caption)
                                }
                            }
                            
                            Button("Add Time Slot") {
                                hours[day]?.append(Restaurant.TimeRange(start: "09:00", end: "17:00"))
                            }
                            .foregroundColor(.blue)
                        } else {
                            Button("Add Operating Hours") {
                                hours[day] = [Restaurant.TimeRange(start: "09:00", end: "17:00")]
                            }
                            .foregroundColor(.blue)
                        }
                        
                        Button("Closed") {
                            hours[day] = []
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Operating Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Save hours
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Delivery Settings Editor
struct DeliverySettingsEditor: View {
    let restaurant: Restaurant
    @Environment(\.dismiss) private var dismiss
    
    @State private var baseDeliveryFee: String
    @State private var perKmFee: String
    @State private var minimumOrder: String
    @State private var smallOrderFee: String
    @State private var avgPrepTime: String
    @State private var deliveryZones: [String]
    
    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        self._baseDeliveryFee = State(initialValue: String(format: "%.0f", restaurant.deliveryFeePolicy.baseMAD))
        self._perKmFee = State(initialValue: String(format: "%.2f", restaurant.deliveryFeePolicy.perKmMAD))
        self._minimumOrder = State(initialValue: String(format: "%.0f", restaurant.deliveryFeePolicy.minimumOrderMAD ?? 0))
        self._smallOrderFee = State(initialValue: String(format: "%.0f", restaurant.deliveryFeePolicy.smallOrderFeeMAD ?? 0))
        self._avgPrepTime = State(initialValue: String(restaurant.avgPrepMinutes))
        self._deliveryZones = State(initialValue: restaurant.deliveryZones)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Delivery Fees") {
                    HStack {
                        Text("Base Delivery Fee")
                        Spacer()
                        TextField("0", text: $baseDeliveryFee)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("MAD")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Per KM Fee")
                        Spacer()
                        TextField("0.00", text: $perKmFee)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("MAD")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Minimum Order")
                        Spacer()
                        TextField("0", text: $minimumOrder)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("MAD")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Small Order Fee")
                        Spacer()
                        TextField("0", text: $smallOrderFee)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("MAD")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Preparation") {
                    HStack {
                        Text("Average Prep Time")
                        Spacer()
                        TextField("0", text: $avgPrepTime)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("minutes")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Delivery Zones") {
                    ForEach(deliveryZones.indices, id: \.self) { index in
                        HStack {
                            TextField("Zone name", text: $deliveryZones[index])
                            
                            Button("Remove") {
                                deliveryZones.remove(at: index)
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }
                    
                    Button("Add Zone") {
                        deliveryZones.append("")
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Delivery Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Save delivery settings
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Notification Settings Editor
struct NotificationSettingsEditor: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var newOrdersEnabled = true
    @State private var newOrdersSound = true
    @State private var orderUpdatesEnabled = true
    @State private var customerMessagesEnabled = true
    @State private var marketingEnabled = false
    @State private var emailNotifications = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Order Notifications") {
                    Toggle("New Orders", isOn: $newOrdersEnabled)
                    
                    if newOrdersEnabled {
                        Toggle("Sound for New Orders", isOn: $newOrdersSound)
                    }
                    
                    Toggle("Order Status Updates", isOn: $orderUpdatesEnabled)
                    Toggle("Customer Messages", isOn: $customerMessagesEnabled)
                }
                
                Section("Marketing & Promotions") {
                    Toggle("Marketing Updates", isOn: $marketingEnabled)
                    Toggle("Weekly Reports", isOn: $emailNotifications)
                }
                
                Section("Delivery Notifications") {
                    Toggle("Courier Assignments", isOn: .constant(true))
                    Toggle("Delivery Confirmations", isOn: .constant(true))
                }
                
                Section("Business Updates") {
                    Toggle("Payment Notifications", isOn: .constant(true))
                    Toggle("Policy Changes", isOn: .constant(true))
                    Toggle("Platform Updates", isOn: .constant(false))
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Save notification settings
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Placeholder Views
struct PaymentBillingView: View {
    var body: some View {
        Text("Payment & Billing")
            .navigationTitle("Payment & Billing")
    }
}

struct TaxInformationView: View {
    var body: some View {
        Text("Tax Information")
            .navigationTitle("Tax Information")
    }
}

struct BusinessDocumentsView: View {
    var body: some View {
        Text("Business Documents")
            .navigationTitle("Business Documents")
    }
}

#Preview {
    RestaurantSettingsView(viewModel: MerchantConsoleViewModel(restaurantId: "rest1", service: MockFoodDeliveryService()))
}