import SwiftUI
import EventsService

struct MyEventsView: View {
    @ObservedObject var viewModel: EventsViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Selection
            Picker("Events Tab", selection: $selectedTab) {
                Text("Attending").tag(0)
                Text("Orders").tag(1)
                Text("Saved").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            TabView(selection: $selectedTab) {
                // Attending Events
                AttendingEventsView(viewModel: viewModel)
                    .tag(0)
                
                // My Orders
                MyOrdersView(viewModel: viewModel)
                    .tag(1)
                
                // Saved Events
                SavedEventsView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

struct AttendingEventsView: View {
    @ObservedObject var viewModel: EventsViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.myGroups.filter { $0.status != .cancelled }) { group in
                    AttendingEventCard(group: group) {
                        viewModel.selectedGroup = group
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadMyGroups()
        }
    }
}

struct MyOrdersView: View {
    @ObservedObject var viewModel: EventsViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.myOrders) { order in
                    OrderCard(order: order)
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadMyOrders()
        }
    }
}

struct SavedEventsView: View {
    // TODO: Implement saved events functionality
    var body: some View {
        VStack {
            Image(systemName: "bookmark")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("Saved Events")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Events you save will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct AttendingEventCard: View {
    let group: AttendanceGroup
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("\(group.participantUserIds.count) attending")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    StatusBadge(status: group.status.rawValue)
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Group")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(group.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    Button("View Details") {
                        onTap()
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct OrderCard: View {
    let order: TicketOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order #\(order.id?.suffix(8) ?? "")")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(Int(order.totalAmount)) \(order.currency)")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                StatusBadge(status: order.status.rawValue)
            }
            
            if !order.tickets.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tickets")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(order.tickets, id: \Ticket.code) { (ticket: Ticket) in
                        HStack {
                            Text(ticket.seat ?? "General Admission")
                                .font(.caption)
                            
                            Spacer()
                            
                            Text(ticket.code)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                Text("Created")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let createdAt = order.createdAt {
                    Text(createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        switch status.lowercased() {
        case "confirmed", "paid": return .green.opacity(0.2)
        case "pending", "planning": return .orange.opacity(0.2)
        case "cancelled", "expired": return .red.opacity(0.2)
        case "ordering", "awaiting_split": return .blue.opacity(0.2)
        default: return .gray.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch status.lowercased() {
        case "confirmed", "paid": return .green
        case "pending", "planning": return .orange
        case "cancelled", "expired": return .red
        case "ordering", "awaiting_split": return .blue
        default: return .gray
        }
    }
}

#if DEBUG
#Preview {
    MyEventsView(viewModel: EventsViewModel())
}
#endif