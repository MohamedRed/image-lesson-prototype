import SwiftUI
import EventsService
import FirebaseFirestore

// MARK: - Preview Providers

struct EventsRootView_Previews: PreviewProvider {
    static var previews: some View {
        EventsRootView()
            .environmentObject(EventsViewModel(eventsService: MockEventsService()))
    }
}

struct DiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = EventsViewModel(eventsService: MockEventsService())
        DiscoveryView(viewModel: viewModel)
    }
}

struct EventDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = MockEventsService()
        let viewModel = EventsViewModel(eventsService: mockService)
        
        // Use a mock event for preview
        EventDetailView(event: createMockEvent(), viewModel: viewModel)
    }
    
    static func createMockEvent() -> Event {
        Event(
            id: "preview_event",
            promoterId: "promoter_1",
            title: "Jazz Night Preview",
            category: .music,
            description: "An amazing jazz event for preview",
            images: ["https://picsum.photos/400/300"],
            rules: ["No outside food", "18+ only"],
            priceTiers: [
                PriceTier(name: "General", priceMAD: 150, description: "General admission"),
                PriceTier(name: "VIP", priceMAD: 300, description: "VIP experience")
            ],
            location: GeoPoint(latitude: 33.5731, longitude: -7.5898),
            venueName: "Blue Note Casablanca",
            neighborhood: "Gauthier",
            startAt: Date().addingTimeInterval(86400 * 3),
            endAt: Date().addingTimeInterval(86400 * 3 + 10800),
            indoor: true,
            tags: ["jazz", "live music", "nightlife"],
            seating: SeatingInfo(hasSeatMap: false, generalAdmission: true),
            status: .published
        )
    }
}

struct MyEventsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = EventsViewModel(eventsService: MockEventsService())
        MyEventsView(viewModel: viewModel)
    }
}

struct MyGroupsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = EventsViewModel(eventsService: MockEventsService())
        MyGroupsView(viewModel: viewModel)
    }
}

struct EventSearchView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = EventsViewModel(eventsService: MockEventsService())
        EventSearchView(viewModel: viewModel)
    }
}

struct AIAssistantView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = EventsViewModel(eventsService: MockEventsService())
        AIAssistantView(viewModel: viewModel)
    }
}

struct CreateGroupView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = MockEventsService()
        let viewModel = EventsViewModel(eventsService: mockService)
        
        CreateGroupView(event: createMockEvent(), viewModel: viewModel)
    }
    
    static func createMockEvent() -> Event {
        EventDetailView_Previews.createMockEvent()
    }
}

struct LinkTicketsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = MockEventsService()
        let viewModel = EventsViewModel(eventsService: mockService)
        
        LinkTicketsView(
            event: createMockEvent(),
            viewModel: viewModel
        )
    }
    
    static func createMockEvent() -> Event {
        EventDetailView_Previews.createMockEvent()
    }
    
    static func createMockGroup() -> AttendanceGroup {
        AttendanceGroup(
            id: "preview_group",
            organizerId: "current_user",
            eventId: "preview_event",
            sessionId: nil,
            name: "Preview Group",
            status: .planning,
            invitedUserIds: ["friend_1", "friend_2"],
            participantUserIds: ["current_user"],
            chatThreadId: "chat_preview"
        )
    }
}

struct InviteFriendsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = MockEventsService()
        let viewModel = EventsViewModel(eventsService: mockService)
        
        InviteFriendsView(
            group: createMockGroup(),
            viewModel: viewModel
        )
    }
    
    static func createMockEvent() -> Event {
        EventDetailView_Previews.createMockEvent()
    }
    
    static func createMockGroup() -> AttendanceGroup {
        LinkTicketsView_Previews.createMockGroup()
    }
}