import SwiftUI

struct SettingsView: View {
    @AppStorage("useRealService") private var useRealService = false
    @AppStorage("userMode") private var userMode = "rider"
    @AppStorage("dashboardStyle") private var dashboardStyle = "list"
    @Environment(\.dismiss) private var dismiss
    
    var dashboardDescription: String {
        switch dashboardStyle {
        case "list":
            return "All categories visible in scrollable list"
        case "segmented":
            return "Horizontal tabs with category switching"
        case "hybrid":
            return "Scrollable list + quick-jump tab shortcuts"
        default:
            return "All categories visible in scrollable list"
        }
    }
    
    var dashboardDisplayName: String {
        switch dashboardStyle {
        case "list":
            return "Scrollable List"
        case "segmented":
            return "Tab Segments"
        case "hybrid":
            return "Hybrid View"
        default:
            return "Scrollable List"
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("User Type", selection: $userMode) {
                        Text("👤 Rider").tag("rider")
                        Text("🚗 Driver").tag("driver")
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Image(systemName: userMode == "driver" ? "car.fill" : "figure.walk")
                            .foregroundColor(userMode == "driver" ? .blue : .green)
                        Text("You are testing as a \(userMode)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("Testing Mode")
                } footer: {
                    Text("Select whether you want to test the driver or rider experience. Use this to run different modes on multiple simulators.")
                }
                
                Section {
                    Toggle("Use Real Service", isOn: $useRealService)
                    Text(useRealService ? "Connected to real backend" : "Using simulated data")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } header: {
                    Text("Backend Service")
                } footer: {
                    Text("When enabled, the app will connect to the real LiveKit backend. When disabled, it uses simulated driver movements and events.")
                }
                
                Section {
                    Picker("Dashboard Style", selection: $dashboardStyle) {
                        Text("📜 Scrollable List").tag("list")
                        Text("⭐ Tab Segments").tag("segmented")
                        Text("🔄 Hybrid View").tag("hybrid")
                    }
                    .pickerStyle(.navigationLink)
                    
                    Text(dashboardDescription)
                        .foregroundColor(.secondary)
                        .font(.caption)
                } header: {
                    Text("Dashboard Layout")
                } footer: {
                    Text("Choose your preferred navigation style. Hybrid combines both approaches for maximum flexibility.")
                }
                
                Section {
                    HStack {
                        Text("User Type")
                        Spacer()
                        Text(userMode.capitalized)
                            .foregroundColor(userMode == "driver" ? .blue : .green)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Service Mode")
                        Spacer()
                        Text(useRealService ? "Production" : "Demo")
                            .foregroundColor(useRealService ? .green : .orange)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Dashboard Style")
                        Spacer()
                        Text(dashboardDisplayName)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                } header: {
                    Text("Current Configuration")
                }
            }
            .navigationTitle("Settings")
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}