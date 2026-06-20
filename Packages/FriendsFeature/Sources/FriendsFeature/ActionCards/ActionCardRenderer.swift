import SwiftUI
import FriendsService

// MARK: - Action Card Renderer

public struct ActionCardRenderer: View {
    let actionCard: Message.ActionCard
    @ObservedObject var viewModel: FriendsViewModel
    let onAction: (ActionCardAction) -> Void
    
    public init(actionCard: Message.ActionCard, viewModel: FriendsViewModel, onAction: @escaping (ActionCardAction) -> Void) {
        self.actionCard = actionCard
        self.viewModel = viewModel
        self.onAction = onAction
    }
    
    public var body: some View {
        Group {
            switch actionCard.kind {
            case "ride_sharing":
                RideShareActionCard(actionCard: actionCard, onAction: onAction)
            case "food_delivery":
                FoodDeliveryActionCard(actionCard: actionCard, onAction: onAction)
            case "marketplace":
                MarketplaceActionCard(actionCard: actionCard, onAction: onAction)
            case "home_services":
                HomeServicesActionCard(actionCard: actionCard, onAction: onAction)
            case "debate":
                DebateActionCard(actionCard: actionCard, onAction: onAction)
            case "ai_tutor":
                AITutorActionCard(actionCard: actionCard, onAction: onAction)
            case "watch_party":
                WatchPartyActionCard(actionCard: actionCard, onAction: onAction)
            case "event":
                EventActionCard(actionCard: actionCard, onAction: onAction)
            case "trip_plan":
                TripPlanActionCard(actionCard: actionCard, onAction: onAction)
            case "meal_plan":
                MealPlanActionCard(actionCard: actionCard, onAction: onAction)
            case "location_share":
                LocationActionCard(actionCard: actionCard, onAction: onAction)
            default:
                GenericActionCard(actionCard: actionCard, onAction: onAction)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 1)
                .foregroundColor(colorForActionKind(actionCard.kind))
        )
    }
    
    private func colorForActionKind(_ kind: String) -> Color {
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
        case "location_share": return .blue
        default: return .gray
        }
    }
}

// MARK: - Action Card Types

public enum ActionCardAction {
    case openFeature(featureId: String, referenceId: String?, metadata: [String: Any]?)
    case joinSession(sessionId: String)
    case acceptInvite(inviteId: String)
    case viewDetails(itemId: String)
    case shareLocation
    case custom(action: String, data: [String: Any])
}

// MARK: - Specific Action Cards

struct RideShareActionCard: View {
    let actionCard: Message.ActionCard
    let onAction: (ActionCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(.blue)
                Text("Ride Share")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let pickup = actionCard.meta["pickup"]?.value as? String,
               let destination = actionCard.meta["destination"]?.value as? String {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("From: \(pickup)")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("To: \(destination)")
                            .font(.caption)
                    }
                }
            }
            
            if let etaMin = actionCard.meta["etaMin"]?.value as? Int {
                Text("ETA: \(etaMin) minutes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Join Ride") {
                    onAction(.openFeature(
                        featureId: "ride_sharing",
                        referenceId: actionCard.refId,
                        metadata: actionCard.meta.mapValues { $0.value }
                    ))
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("View Details") {
                    onAction(.viewDetails(itemId: actionCard.refId))
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct FoodDeliveryActionCard: View {
    let actionCard: Message.ActionCard
    let onAction: (ActionCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bag.fill")
                    .foregroundColor(.orange)
                Text("Food Order")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let restaurant = actionCard.meta["restaurant"]?.value as? String {
                Text("From: \(restaurant)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if let items = actionCard.meta["items"]?.value as? [String] {
                Text("\(items.count) item(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let total = actionCard.meta["total"]?.value as? Double {
                Text("Total: $\(String(format: "%.2f", total))")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                Button("Join Order") {
                    onAction(.openFeature(
                        featureId: "food_delivery",
                        referenceId: actionCard.refId,
                        metadata: actionCard.meta.mapValues { $0.value }
                    ))
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("View Menu") {
                    onAction(.viewDetails(itemId: actionCard.refId))
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct MarketplaceActionCard: View {
    let actionCard: Message.ActionCard
    let onAction: (ActionCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundColor(.green)
                Text("Marketplace Item")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let itemName = actionCard.meta["itemName"]?.value as? String {
                Text(itemName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                if let price = actionCard.meta["price"]?.value as? Double {
                    Text("$\(String(format: "%.2f", price))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                if let condition = actionCard.meta["condition"]?.value as? String {
                    Text(condition)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            
            HStack {
                Button("View Item") {
                    onAction(.openFeature(
                        featureId: "marketplace",
                        referenceId: actionCard.refId,
                        metadata: actionCard.meta.mapValues { $0.value }
                    ))
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("Message Seller") {
                    onAction(.custom(action: "message_seller", data: ["itemId": actionCard.refId]))
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct HomeServicesActionCard: View {
    let actionCard: Message.ActionCard
    let onAction: (ActionCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "hammer.fill")
                    .foregroundColor(.indigo)
                Text("Home Service")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let service = actionCard.meta["service"]?.value as? String {
                Text(service)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if let date = actionCard.meta["scheduledDate"]?.value as? String {
                Text("Scheduled: \(date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("View Booking") {
                    onAction(.openFeature(
                        featureId: "home_services",
                        referenceId: actionCard.refId,
                        metadata: actionCard.meta.mapValues { $0.value }
                    ))
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("Contact Pro") {
                    onAction(.custom(action: "contact_professional", data: ["bookingId": actionCard.refId]))
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct DebateActionCard: View {
    let actionCard: Message.ActionCard
    let onAction: (ActionCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundColor(.orange)
                Text("Live Debate")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let topic = actionCard.meta["topic"]?.value as? String {
                Text(topic)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }
            
            HStack {
                if let participants = actionCard.meta["participants"]?.value as? Int {
                    Label("\(participants)", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let status = actionCard.meta["status"]?.value as? String {
                    Text(status.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(status == "live" ? .red : .orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill((status == "live" ? Color.red : Color.orange).opacity(0.2))
                        )
                }
            }
            
            Button("Join Debate") {
                onAction(.openFeature(
                    featureId: "debate",
                    referenceId: actionCard.refId,
                    metadata: actionCard.meta.mapValues { $0.value }
                ))
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
}

struct AITutorActionCard: View {
    let actionCard: Message.ActionCard
    let onAction: (ActionCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("AI Tutor Session")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let subject = actionCard.meta["subject"]?.value as? String {
                Text("Subject: \(subject)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if let difficulty = actionCard.meta["difficulty"]?.value as? String {
                Text("Level: \(difficulty)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Join Study Session") {
                onAction(.openFeature(
                    featureId: "ai_tutor",
                    referenceId: actionCard.refId,
                    metadata: actionCard.meta.mapValues { $0.value }
                ))
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
}

struct WatchPartyActionCard: View {
    let actionCard: Message.ActionCard
    let onAction: (ActionCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "play.tv.fill")
                    .foregroundColor(.pink)
                Text("Watch Party")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let title = actionCard.meta["title"]?.value as? String {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }
            
            if let participants = actionCard.meta["participants"]?.value as? Int {
                Text("\(participants) watching")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Join Watch Party") {
                onAction(.joinSession(sessionId: actionCard.refId))
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
}

struct EventActionCard: View {
    let actionCard: Message.ActionCard
    let onAction: (ActionCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(.red)
                Text("Event")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let eventName = actionCard.meta["eventName"]?.value as? String {
                Text(eventName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }
            
            if let date = actionCard.meta["date"]?.value as? String {
                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Join Event") {
                    onAction(.acceptInvite(inviteId: actionCard.refId))
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("View Details") {
                    onAction(.viewDetails(itemId: actionCard.refId))
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct TripPlanActionCard: View {
    let actionCard: Message.ActionCard
    let onAction: (ActionCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.cyan)
                Text("Trip Plan")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let destination = actionCard.meta["destination"]?.value as? String {
                Text("To: \(destination)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if let dates = actionCard.meta["dates"]?.value as? String {
                Text(dates)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("View Trip Plan") {
                onAction(.openFeature(
                    featureId: "trip_planner",
                    referenceId: actionCard.refId,
                    metadata: actionCard.meta.mapValues { $0.value }
                ))
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
}

struct MealPlanActionCard: View {
    let actionCard: Message.ActionCard
    let onAction: (ActionCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(.mint)
                Text("Meal Plan")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let mealType = actionCard.meta["mealType"]?.value as? String {
                Text(mealType)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if let calories = actionCard.meta["calories"]?.value as? Int {
                Text("\(calories) calories")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("View Meal Plan") {
                onAction(.openFeature(
                    featureId: "meal_planner",
                    referenceId: actionCard.refId,
                    metadata: actionCard.meta.mapValues { $0.value }
                ))
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
}

struct LocationActionCard: View {
    let actionCard: Message.ActionCard
    let onAction: (ActionCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                Text("Shared Location")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let address = actionCard.meta["address"]?.value as? String {
                Text(address)
                    .font(.caption)
                    .lineLimit(2)
            }
            
            Button("View on Map") {
                onAction(.shareLocation)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
}

struct GenericActionCard: View {
    let actionCard: Message.ActionCard
    let onAction: (ActionCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "app.fill")
                    .foregroundColor(.gray)
                Text(actionCard.kind.capitalized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text("Tap to open")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Open") {
                onAction(.openFeature(
                    featureId: actionCard.kind,
                    referenceId: actionCard.refId,
                    metadata: actionCard.meta.mapValues { $0.value }
                ))
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
}