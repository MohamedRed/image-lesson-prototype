import SwiftUI
import EventsService
import FriendsService

struct CreateGroupView: View {
    let event: Event
    @ObservedObject var viewModel: EventsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupName = ""
    @State private var selectedFriends: Set<String> = []
    @State private var friends: [String] = [] // TODO: Replace with actual Friend models
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event") {
                    HStack {
                        AsyncImage(url: URL(string: event.images.first ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                        .clipped()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.headline)
                                .lineLimit(2)
                            
                            Text(event.startAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                Section("Group Details") {
                    TextField("Group name", text: $groupName)
                        .textInputAutocapitalization(.words)
                    
                    if groupName.isEmpty {
                        Text("e.g., \"Jazz Night Crew\" or \"Weekend Warriors\"")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Invite Friends") {
                    if friends.isEmpty {
                        HStack {
                            Image(systemName: "person.2")
                                .foregroundColor(.secondary)
                            Text("Connect with friends to invite them")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Find Friends") {
                                // TODO: Navigate to friends feature
                            }
                            .font(.subheadline)
                        }
                    } else {
                        ForEach(friends, id: \.self) { friendId in
                            HStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.3))
                                    .frame(width: 30, height: 30)
                                
                                Text("Friend \(friendId.prefix(8))")
                                
                                Spacer()
                                
                                Button {
                                    if selectedFriends.contains(friendId) {
                                        selectedFriends.remove(friendId)
                                    } else {
                                        selectedFriends.insert(friendId)
                                    }
                                } label: {
                                    Image(systemName: selectedFriends.contains(friendId) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedFriends.contains(friendId) ? .accentColor : .gray)
                                }
                            }
                        }
                        
                        if !selectedFriends.isEmpty {
                            Text("Inviting \(selectedFriends.count) friend\(selectedFriends.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            await loadFriends()
        }
    }
    
    private func createGroup() {
        let finalGroupName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            await viewModel.createGroup(
                for: event,
                name: finalGroupName,
                invitedFriends: Array(selectedFriends)
            )
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func loadFriends() async {
        // TODO: Load actual friends from FriendsService
        // For now, using mock data
        await MainActor.run {
            self.friends = [] // Empty for MVP
        }
    }
}

#if DEBUG
#Preview {
    CreateGroupView(
        event: Event(
            promoterId: "test",
            title: "Jazz Night at Blue Note",
            category: .music,
            description: "An evening of smooth jazz",
            priceTiers: [PriceTier(name: "General", priceMAD: 150)],
            location: .init(latitude: 33.5731, longitude: -7.5898),
            venueName: "Blue Note Casablanca",
            startAt: Date(),
            endAt: Date().addingTimeInterval(3600 * 3),
            seating: SeatingInfo()
        ),
        viewModel: EventsViewModel()
    )
}
#endif