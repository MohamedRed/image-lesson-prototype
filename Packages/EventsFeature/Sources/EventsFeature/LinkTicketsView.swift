import SwiftUI
import EventsService

struct LinkTicketsView: View {
    let event: Event
    @ObservedObject var viewModel: EventsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var ticketUrl = ""
    @State private var selectedGroup: AttendanceGroup?
    @State private var isLinking = false
    
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
                
                Section("Select Group") {
                    let eventGroups = viewModel.myGroups.filter { $0.eventId == event.id }
                    
                    if eventGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No groups found for this event")
                                .foregroundColor(.secondary)
                            
                            Button("Create Group First") {
                                dismiss()
                                // TODO: Trigger group creation
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(eventGroups) { group in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("\(group.participantUserIds.count) members")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    selectedGroup = group
                                } label: {
                                    Image(systemName: selectedGroup?.id == group.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedGroup?.id == group.id ? .accentColor : .gray)
                                }
                            }
                        }
                    }
                }
                
                if selectedGroup != nil {
                    Section("Ticket Link") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Paste ticket link here", text: $ticketUrl, axis: .vertical)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .lineLimit(2...4)
                            
                            Text("Supported providers: Ticketmaster, Eventbrite, or direct venue links")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section {
                        Button {
                            linkTickets()
                        } label: {
                            HStack {
                                if isLinking {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "link")
                                }
                                
                                Text(isLinking ? "Linking..." : "Link Tickets")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(ticketUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLinking)
                    }
                }
            }
            .navigationTitle("Link Tickets")
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
    
    private func linkTickets() {
        guard let group = selectedGroup else { return }
        
        let url = ticketUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        
        isLinking = true
        
        Task {
            await viewModel.linkExternalTickets(
                groupId: group.id!,
                eventId: event.id!,
                url: url
            )
            
            await MainActor.run {
                self.isLinking = false
                dismiss()
            }
        }
    }
}

#if DEBUG
#Preview {
    LinkTicketsView(
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