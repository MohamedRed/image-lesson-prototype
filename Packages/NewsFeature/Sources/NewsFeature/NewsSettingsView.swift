import SwiftUI
import NewsService

struct NewsSettingsView: View {
    @ObservedObject var viewModel: NewsViewModel
    @Environment(\.dismiss) private var dismiss
    
    let availableRegions = [
        "Global",
        "North America",
        "Europe",
        "Asia",
        "Middle East",
        "Africa",
        "Latin America",
        "Oceania"
    ]
    
    let availableTags = [
        "Politics",
        "Economy",
        "Technology",
        "Health",
        "Environment",
        "Science",
        "Sports",
        "Culture",
        "Education",
        "Business"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Region Filter") {
                    Picker("Region", selection: Binding(
                        get: { viewModel.selectedRegion ?? "Global" },
                        set: { viewModel.selectedRegion = $0 == "Global" ? nil : $0 }
                    )) {
                        ForEach(availableRegions, id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }
                }
                
                Section("Topic Filters") {
                    ForEach(availableTags, id: \.self) { tag in
                        Toggle(isOn: Binding(
                            get: { viewModel.selectedTags.contains(tag) },
                            set: { isOn in
                                if isOn {
                                    viewModel.selectedTags.insert(tag)
                                } else {
                                    viewModel.selectedTags.remove(tag)
                                }
                            }
                        )) {
                            Label(tag, systemImage: iconForTag(tag))
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await viewModel.applyFilters()
                            dismiss()
                        }
                    }) {
                        Text("Apply Filters")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        viewModel.selectedRegion = nil
                        viewModel.selectedTags.removeAll()
                        Task {
                            await viewModel.applyFilters()
                            dismiss()
                        }
                    }) {
                        Text("Clear All Filters")
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(.red)
                }
                
                Section("Perspective Preferences") {
                    Text("Configure which perspectives you'd like to see prominently")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    NavigationLink(destination: PerspectivePreferencesView()) {
                        Label("Manage Perspectives", systemImage: "person.3")
                    }
                }
                
                Section("About") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("News & Perspectives")
                            .font(.headline)
                        Text("Get balanced news coverage with multiple perspectives, historical context, and constructive solutions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("News Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func iconForTag(_ tag: String) -> String {
        switch tag {
        case "Politics": return "building.columns"
        case "Economy": return "chart.line.uptrend.xyaxis"
        case "Technology": return "cpu"
        case "Health": return "heart"
        case "Environment": return "leaf"
        case "Science": return "atom"
        case "Sports": return "sportscourt"
        case "Culture": return "theatermasks"
        case "Education": return "book"
        case "Business": return "briefcase"
        default: return "tag"
        }
    }
}

struct PerspectivePreferencesView: View {
    @AppStorage("preferredPerspectives") private var preferredPerspectivesData: Data = Data()
    @State private var selectedPerspectives: Set<String> = []
    
    let geographicPerspectives = [
        "Western",
        "East Asia",
        "Middle East & North Africa",
        "Sub-Saharan Africa",
        "Latin America",
        "Global South"
    ]
    
    let ideologicalPerspectives = [
        "Liberal",
        "Conservative",
        "Libertarian",
        "Socialist",
        "Centrist"
    ]
    
    let stakeholderPerspectives = [
        "Government",
        "Industry",
        "NGO/Civil Society",
        "Local Community",
        "Academic/Expert"
    ]
    
    var body: some View {
        Form {
            Section("Geographic Perspectives") {
                ForEach(geographicPerspectives, id: \.self) { perspective in
                    Toggle(isOn: Binding(
                        get: { selectedPerspectives.contains(perspective) },
                        set: { isOn in
                            if isOn {
                                selectedPerspectives.insert(perspective)
                            } else {
                                selectedPerspectives.remove(perspective)
                            }
                            savePreferences()
                        }
                    )) {
                        Text(perspective)
                    }
                }
            }
            
            Section("Ideological Perspectives") {
                ForEach(ideologicalPerspectives, id: \.self) { perspective in
                    Toggle(isOn: Binding(
                        get: { selectedPerspectives.contains(perspective) },
                        set: { isOn in
                            if isOn {
                                selectedPerspectives.insert(perspective)
                            } else {
                                selectedPerspectives.remove(perspective)
                            }
                            savePreferences()
                        }
                    )) {
                        Text(perspective)
                    }
                }
            }
            
            Section("Stakeholder Perspectives") {
                ForEach(stakeholderPerspectives, id: \.self) { perspective in
                    Toggle(isOn: Binding(
                        get: { selectedPerspectives.contains(perspective) },
                        set: { isOn in
                            if isOn {
                                selectedPerspectives.insert(perspective)
                            } else {
                                selectedPerspectives.remove(perspective)
                            }
                            savePreferences()
                        }
                    )) {
                        Text(perspective)
                    }
                }
            }
            
            Section {
                Text("Select perspectives you want to see prominently. If none selected, all perspectives will be shown equally.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Perspective Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPreferences()
        }
    }
    
    private func loadPreferences() {
        if let array = try? JSONDecoder().decode([String].self, from: preferredPerspectivesData) {
            selectedPerspectives = Set(array)
        }
    }
    
    private func savePreferences() {
        if let data = try? JSONEncoder().encode(Array(selectedPerspectives)) {
            preferredPerspectivesData = data
        }
    }
}