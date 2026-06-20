import SwiftUI
import AITutorService

struct SavesView: View {
    @ObservedObject var viewModel: AITutorViewModel
    @State private var showingDeleteAlert = false
    @State private var slotToDelete: Int?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved Games")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Continue your learning journey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Save slots
                VStack(spacing: 12) {
                    ForEach(1...3, id: \.self) { slot in
                        SaveSlotCard(
                            slot: slot,
                            save: viewModel.saves[slot],
                            onLoad: {
                                if let save = viewModel.saves[slot] {
                                    loadSave(save: save, slot: slot)
                                }
                            },
                            onDelete: {
                                slotToDelete = slot
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                // Cloud Save Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cloud Save")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.blue)
                        Text("Your saves are automatically synced across devices")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .onAppear {
            viewModel.loadSaves()
        }
        .alert("Delete Save", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let slot = slotToDelete {
                    viewModel.deleteSave(slot: slot)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this save? This action cannot be undone.")
        }
    }
    
    private func loadSave(save: SaveData, slot: Int) {
        // Find the episode for this save
        if let episode = viewModel.episodes.first(where: { $0.id == save.episodeId }) {
            viewModel.startEpisode(episode, slot: slot)
        }
    }
}

struct SaveSlotCard: View {
    let slot: Int
    let save: SaveData?
    let onLoad: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Slot \(slot)")
                    .font(.headline)
                
                Spacer()
                
                if save != nil {
                    Menu {
                        Button("Load Game", action: onLoad)
                        Button("Delete Save", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .padding()
            
            if let save = save {
                // Save info
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    HStack {
                        // Episode info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(episodeTitleFromId(save.episodeId))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("Checkpoint: \(save.checkpoint)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Progress
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(save.progress * 100))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            SwiftUI.ProgressView(value: save.progress)
                                .frame(width: 60)
                        }
                    }
                    
                    // Play time and date
                    HStack {
                        Label(formatPlayTime(save.playTime), systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Last played: \(save.lastPlayedAt, style: .relative)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                // Load button
                Button("Continue", action: onLoad)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(0)
                
            } else {
                // Empty slot
                VStack(spacing: 12) {
                    Divider()
                    
                    Image(systemName: "plus.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("Empty Slot")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Save your progress during any episode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func episodeTitleFromId(_ episodeId: String) -> String {
        // This would map episode IDs to titles
        switch episodeId {
        case "omar_jerusalem":
            return "Omar Enters Jerusalem"
        case "john_snow_cholera":
            return "John Snow & the Broad Street Pump"
        case "socrates_trial":
            return "Trial of Socrates"
        default:
            return "Unknown Episode"
        }
    }
    
    private func formatPlayTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}