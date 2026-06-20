import SwiftUI
import FriendsService

// MARK: - Share to Friends Interface

public struct ShareToFriendsView: View {
    let actionCardPayload: ActionCardPayload
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedConversations = Set<String>()
    @State private var messageText = ""
    @State private var isSharing = false
    
    public init(actionCardPayload: ActionCardPayload, viewModel: FriendsViewModel) {
        self.actionCardPayload = actionCardPayload
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Preview of what will be shared
                VStack(alignment: .leading, spacing: 12) {
                    Text("Share with friends:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Action card preview
                    ActionCardPreview(payload: actionCardPayload)
                        .padding(.horizontal)
                    
                    // Optional message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add a message (optional):")
                            .font(.subheadline)
                            .padding(.horizontal)
                        
                        TextField("Say something about this...", text: $messageText, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.systemGray6))
                
                // Conversation selection
                List {
                    Section("Select conversations") {
                        ForEach(viewModel.conversations) { conversation in
                            ConversationSelectionRow(
                                conversation: conversation,
                                viewModel: viewModel,
                                isSelected: selectedConversations.contains(conversation.id)
                            ) {
                                if selectedConversations.contains(conversation.id) {
                                    selectedConversations.remove(conversation.id)
                                } else {
                                    selectedConversations.insert(conversation.id)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Share to Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        shareToSelected()
                    }
                    .disabled(selectedConversations.isEmpty || isSharing)
                }
            }
        }
    }
    
    private func shareToSelected() {
        isSharing = true
        
        Task {
            do {
                for conversationId in selectedConversations {
                    let content = messageText.isEmpty ? "Check this out!" : messageText
                    try await viewModel.sendActionCard(
                        to: conversationId,
                        content: content,
                        actionCard: actionCardPayload
                    )
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSharing = false
                    // TODO: Show error alert
                }
            }
        }
    }
}

// MARK: - Action Card Preview

struct ActionCardPreview: View {
    let payload: ActionCardPayload
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                iconForKind(payload.kind)
                    .foregroundColor(colorForKind(payload.kind))
                
                Text(titleForKind(payload.kind))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Show key metadata
            ForEach(Array(payload.meta.keys.prefix(3).sorted()), id: \.self) { key in
                if let value = payload.meta[key] {
                    HStack {
                        Text("\(key.capitalized):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(describing: value.value))
                            .font(.caption)
                        Spacer()
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForKind(payload.kind), lineWidth: 1)
        )
    }
    
    private func iconForKind(_ kind: String) -> Image {
        switch kind {
        case "ride_sharing": return Image(systemName: "car.fill")
        case "food_delivery": return Image(systemName: "bag.fill")
        case "marketplace": return Image(systemName: "cart.fill")
        case "home_services": return Image(systemName: "hammer.fill")
        case "debate": return Image(systemName: "bubble.left.and.bubble.right")
        case "ai_tutor": return Image(systemName: "brain.head.profile")
        case "watch_party": return Image(systemName: "play.tv.fill")
        case "event": return Image(systemName: "calendar.badge.plus")
        case "trip_plan": return Image(systemName: "map.fill")
        case "meal_plan": return Image(systemName: "fork.knife")
        default: return Image(systemName: "app.fill")
        }
    }
    
    private func colorForKind(_ kind: String) -> Color {
        switch kind {
        case "ride_sharing": return .blue
        case "food_delivery": return .orange
        case "marketplace": return .green
        case "home_services": return .indigo
        case "debate": return .orange
        case "ai_tutor": return .purple
        case "watch_party": return .pink
        case "event": return .red
        case "trip_plan": return .cyan
        case "meal_plan": return .mint
        default: return .gray
        }
    }
    
    private func titleForKind(_ kind: String) -> String {
        switch kind {
        case "ride_sharing": return "Ride Share"
        case "food_delivery": return "Food Delivery"
        case "marketplace": return "Marketplace Item"
        case "home_services": return "Home Service"
        case "debate": return "Live Debate"
        case "ai_tutor": return "AI Tutor Session"
        case "watch_party": return "Watch Party"
        case "event": return "Event"
        case "trip_plan": return "Trip Plan"
        case "meal_plan": return "Meal Plan"
        default: return kind.capitalized
        }
    }
}

// MARK: - Conversation Selection Row

struct ConversationSelectionRow: View {
    let conversation: Conversation
    @ObservedObject var viewModel: FriendsViewModel
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            // Conversation avatar
            ConversationAvatarView(conversation: conversation, size: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(conversationTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(conversation.participants.count) participant(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var conversationTitle: String {
        if let title = conversation.title {
            return title
        } else if conversation.type == .direct {
            let otherParticipantId = conversation.participants.first { $0 != viewModel.friendsService.currentUserId }
            if let otherParticipantId = otherParticipantId,
               let friend = viewModel.getFriend(by: otherParticipantId) {
                return friend.displayName
            }
            return "Direct Message"
        } else {
            return "Group Chat"
        }
    }
}

// MARK: - Public Factory

public enum ShareToFriendsFactory {
    @MainActor
    public static func makeShareView(
        for actionCard: ActionCardPayload,
        with friendsViewModel: FriendsViewModel
    ) -> ShareToFriendsView {
        ShareToFriendsView(actionCardPayload: actionCard, viewModel: friendsViewModel)
    }
}

// MARK: - Helper for other features

public struct ShareToFriendsHelper {
    public static func createRideShareActionCard(
        rideId: String,
        pickup: String,
        destination: String,
        etaMinutes: Int
    ) -> ActionCardPayload {
        ActionCardPayload(
            kind: "ride_sharing",
            refId: rideId,
            meta: [
                "pickup": AnyCodable(pickup),
                "destination": AnyCodable(destination),
                "etaMin": AnyCodable(etaMinutes)
            ]
        )
    }
    
    public static func createFoodDeliveryActionCard(
        orderId: String,
        restaurant: String,
        items: [String],
        total: Double
    ) -> ActionCardPayload {
        ActionCardPayload(
            kind: "food_delivery",
            refId: orderId,
            meta: [
                "restaurant": AnyCodable(restaurant),
                "items": AnyCodable(items),
                "total": AnyCodable(total)
            ]
        )
    }
    
    public static func createMarketplaceActionCard(
        itemId: String,
        itemName: String,
        price: Double,
        condition: String
    ) -> ActionCardPayload {
        ActionCardPayload(
            kind: "marketplace",
            refId: itemId,
            meta: [
                "itemName": AnyCodable(itemName),
                "price": AnyCodable(price),
                "condition": AnyCodable(condition)
            ]
        )
    }
    
    public static func createHomeServiceActionCard(
        bookingId: String,
        service: String,
        scheduledDate: String
    ) -> ActionCardPayload {
        ActionCardPayload(
            kind: "home_services",
            refId: bookingId,
            meta: [
                "service": AnyCodable(service),
                "scheduledDate": AnyCodable(scheduledDate)
            ]
        )
    }
    
    public static func createDebateActionCard(
        debateId: String,
        topic: String,
        participants: Int,
        status: String
    ) -> ActionCardPayload {
        ActionCardPayload(
            kind: "debate",
            refId: debateId,
            meta: [
                "topic": AnyCodable(topic),
                "participants": AnyCodable(participants),
                "status": AnyCodable(status)
            ]
        )
    }
    
    public static func createAITutorActionCard(
        sessionId: String,
        subject: String,
        difficulty: String
    ) -> ActionCardPayload {
        ActionCardPayload(
            kind: "ai_tutor",
            refId: sessionId,
            meta: [
                "subject": AnyCodable(subject),
                "difficulty": AnyCodable(difficulty)
            ]
        )
    }
    
    public static func createEventActionCard(
        eventId: String,
        eventName: String,
        date: String
    ) -> ActionCardPayload {
        ActionCardPayload(
            kind: "event",
            refId: eventId,
            meta: [
                "eventName": AnyCodable(eventName),
                "date": AnyCodable(date)
            ]
        )
    }
    
    public static func createLocationActionCard(
        locationId: String,
        address: String,
        latitude: Double,
        longitude: Double
    ) -> ActionCardPayload {
        ActionCardPayload(
            kind: "location_share",
            refId: locationId,
            meta: [
                "address": AnyCodable(address),
                "latitude": AnyCodable(latitude),
                "longitude": AnyCodable(longitude)
            ]
        )
    }
}

#if DEBUG
struct ShareToFriendsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockPayload = ActionCardPayload(
            kind: "ride_sharing",
            refId: "ride123",
            meta: [
                "pickup": AnyCodable("Current Location"),
                "destination": AnyCodable("Airport"),
                "etaMin": AnyCodable(15)
            ]
        )
        
        ShareToFriendsView(actionCardPayload: mockPayload, viewModel: FriendsViewModel())
    }
}
#endif