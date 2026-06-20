import SwiftUI
import AITutorService

struct EpisodeDetailView: View {
    let episode: Episode
    @ObservedObject var viewModel: AITutorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingStartOptions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero Image
                    ZStack(alignment: .bottomLeading) {
                        Rectangle()
                            .fill(episode.domain.color.opacity(0.3))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: episode.domain.icon)
                                    .font(.system(size: 60))
                                    .foregroundColor(episode.domain.color.opacity(0.5))
                            )
                        
                        // Title overlay
                        VStack(alignment: .leading, spacing: 4) {
                            Text(episode.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(episode.era)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.7), Color.clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Summary
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Summary", systemImage: "text.alignleft")
                                .font(.headline)
                            
                            Text(episode.summary)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Learning Objectives
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Learning Objectives", systemImage: "target")
                                .font(.headline)
                            
                            ForEach(episode.learningObjectives, id: \.self) { objective in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .padding(.top, 2)
                                    
                                    Text(objective)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Mechanics
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Gameplay Mechanics", systemImage: "gamecontroller.fill")
                                .font(.headline)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(episode.mechanics, id: \.self) { mechanic in
                                    MechanicBadge(mechanic: mechanic)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Meta Info
                        HStack(spacing: 20) {
                            // Duration
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Duration")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Label("\(episode.duration) min", systemImage: "clock.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            // Difficulty
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Difficulty")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    ForEach(0..<3) { index in
                                        Image(systemName: index < episode.difficulty.level ? "star.fill" : "star")
                                            .font(.subheadline)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            
                            // Domain
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Domain")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Label(episode.domain.displayName, systemImage: episode.domain.icon)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(episode.domain.color)
                            }
                        }
                    }
                    .padding()
                    
                    // Start Button
                    Button(action: { showingStartOptions = true }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Episode")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(episode.domain.color)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingStartOptions) {
                StartOptionsView(episode: episode, viewModel: viewModel)
            }
        }
    }
}

struct MechanicBadge: View {
    let mechanic: MechanicType
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: mechanic.icon)
                .font(.caption)
            Text(mechanic.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}

struct StartOptionsView: View {
    let episode: Episode
    @ObservedObject var viewModel: AITutorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSlot: Int?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose Start Option")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // New Mission
                Button(action: startNewMission) {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        Text("New Mission")
                            .font(.headline)
                        
                        Text("Start from the beginning")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Divider()
                
                // Load Save
                Text("Or Continue From Save")
                    .font(.headline)
                
                ForEach(1...3, id: \.self) { slot in
                    SaveSlotButton(
                        slot: slot,
                        save: viewModel.saves[slot],
                        isSelected: selectedSlot == slot,
                        action: {
                            selectedSlot = slot
                            loadSave(slot: slot)
                        }
                    )
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Start Episode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startNewMission() {
        // Launch Unity (mock)
        viewModel.startEpisode(episode)
        dismiss()
    }
    
    private func loadSave(slot: Int) {
        // Load the save data first, then launch Unity
        viewModel.startEpisode(episode, slot: slot)
        dismiss()
    }
}

struct SaveSlotButton: View {
    let slot: Int
    let save: SaveData?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Slot \(slot)")
                        .font(.headline)
                    
                    if let save = save {
                        Text("Progress: \(Int(save.progress * 100))%")
                            .font(.caption)
                        Text("Played: \(formatPlayTime(save.playTime))")
                            .font(.caption)
                        Text("Last: \(save.lastPlayedAt, style: .date)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Empty")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if save != nil {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatPlayTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

extension MechanicType {
    var displayName: String {
        switch self {
        case .debateMode: return "Debate"
        case .commandMap: return "Command"
        case .experimentBuilder: return "Experiment"
        case .policyBoard: return "Policy"
        case .courtroom: return "Trial"
        case .fieldwork: return "Field Work"
        case .evidenceBoard: return "Evidence"
        }
    }
}