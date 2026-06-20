import SwiftUI
import ActivitiesService

struct BookingsView: View {
    @ObservedObject var viewModel: ActivitiesViewModel
    @State private var selectedFilter: BookingFilter = .all
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Tabs
            filterTabs
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Header
                    headerSection
                    
                    // Bookings List
                    if filteredBookings.isEmpty {
                        EmptyStateView(
                            title: "No Bookings",
                            message: selectedFilter == .all 
                                ? "Your activity bookings will appear here"
                                : "No \(selectedFilter.displayName.lowercased()) bookings found",
                            systemImage: "calendar"
                        )
                        .frame(height: 300)
                    } else {
                        bookingsList
                    }
                }
                .padding()
            }
        }
        .refreshable {
            await viewModel.loadMyBookings()
        }
        .sheet(isPresented: $viewModel.showingBookingDetail) {
            if let booking = viewModel.selectedBooking {
                BookingDetailView(booking: booking, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showingSplitPayment) {
            if let booking = viewModel.selectedBooking {
                SplitPaymentView(booking: booking, viewModel: viewModel)
            }
        }
    }
    
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(BookingFilter.allCases, id: \.self) { filter in
                    FilterTab(
                        title: filter.displayName,
                        count: bookingsCount(for: filter),
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .foregroundColor(.blue)
                Text("My Bookings")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Text("Track your activity reservations and payments")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var bookingsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredBookings) { booking in
                BookingCard(booking: booking) {
                    viewModel.selectBooking(booking)
                }
            }
        }
    }
    
    private var filteredBookings: [Booking] {
        switch selectedFilter {
        case .all:
            return viewModel.myBookings
        case .upcoming:
            return viewModel.myBookings.filter { booking in
                // TODO: Compare with session date when available
                [.confirmed, .pending].contains(booking.status)
            }
        case .pending:
            return viewModel.myBookings.filter { $0.status == .pending || $0.status == .awaitingSplit }
        case .confirmed:
            return viewModel.myBookings.filter { $0.status == .confirmed }
        case .completed:
            return viewModel.myBookings.filter { $0.status == .completed }
        case .cancelled:
            return viewModel.myBookings.filter { $0.status == .cancelled }
        }
    }
    
    private func bookingsCount(for filter: BookingFilter) -> Int {
        switch filter {
        case .all:
            return viewModel.myBookings.count
        case .upcoming:
            return viewModel.myBookings.filter { 
                [.confirmed, .pending].contains($0.status) 
            }.count
        case .pending:
            return viewModel.myBookings.filter { 
                $0.status == .pending || $0.status == .awaitingSplit 
            }.count
        case .confirmed:
            return viewModel.myBookings.filter { $0.status == .confirmed }.count
        case .completed:
            return viewModel.myBookings.filter { $0.status == .completed }.count
        case .cancelled:
            return viewModel.myBookings.filter { $0.status == .cancelled }.count
        }
    }
}

enum BookingFilter: CaseIterable {
    case all, upcoming, pending, confirmed, completed, cancelled
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .upcoming: return "Upcoming"
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

struct FilterTab: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? .white : .gray.opacity(0.3), in: Capsule())
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? .blue : .clear, in: Capsule())
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct BookingCard: View {
    let booking: Booking
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Booking #\(booking.id.prefix(8))")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(booking.status.displayName)
                            .font(.subheadline)
                            .foregroundColor(booking.status.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(booking.status.color.opacity(0.15), in: Capsule())
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(booking.totalAmount)) MAD")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        // Payment status moved to split status; not displayed here
                    }
                }
                
                // Participants
                HStack {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(booking.participants.count) participants")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Quick actions based on status
                    if booking.status == .awaitingSplit {
                        Text("Payment Required")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    } else if booking.status == .pending {
                        Text("Awaiting Confirmation")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // Action buttons
                HStack(spacing: 8) {
                    if booking.status == .awaitingSplit {
                        Button("Pay Share") {
                            // Handle split payment
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    if [.pending, .confirmed].contains(booking.status) {
                        Button("Cancel") {
                            // Handle cancellation
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct BookingDetailView: View {
    let booking: Booking
    @ObservedObject var viewModel: ActivitiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCancellation = false
    @State private var cancellationReason = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Booking Info
                    bookingInfoSection
                    
                    // Participants
                    participantsSection
                    
                    // Payment Info
                    paymentSection
                    
                    // Actions
                    if [.pending, .confirmed].contains(booking.status) {
                        actionsSection
                    }
                    
                    // Cancellation Info
                    if let cancellation = booking.cancellation {
                        cancellationSection(cancellation)
                    }
                }
                .padding()
            }
            .navigationTitle("Booking Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCancellation) {
            CancellationView(
                reason: $cancellationReason,
                onCancel: {
                    showingCancellation = false
                },
                onConfirm: {
                    Task {
                        await viewModel.cancelBooking(
                            bookingId: booking.id,
                            reason: cancellationReason
                        )
                        showingCancellation = false
                        dismiss()
                    }
                }
            )
        }
    }
    
    private var bookingInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Booking Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(booking.status.displayName)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(booking.status.color.opacity(0.15), in: Capsule())
                    .foregroundColor(booking.status.color)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(title: "Booking ID", value: String(booking.id.prefix(12)))
                InfoRow(title: "Activity ID", value: String(booking.activityId.prefix(12)))
                InfoRow(title: "Session ID", value: String(booking.sessionId.prefix(12)))
                InfoRow(title: "Total Amount", value: "\(Int(booking.totalAmount)) MAD")
                
                InfoRow(title: "Created", value: DateFormatter.displayDate.string(from: booking.createdAt))
            }
        }
    }
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Participants (\(booking.participants.count))")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(booking.participants, id: \.userId) { participant in
                HStack {
                    Image(systemName: "person.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(participant.userName)
                            .fontWeight(.medium)
                        Text(participant.role.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(title: "Total Amount", value: "\(Int(booking.totalAmount)) MAD")
                
                // Payment status handled via split intents; omitted
                
                if booking.status == .awaitingSplit {
                    Button("Manage Split Payment") {
                        viewModel.showingSplitPayment = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if booking.status == .pending {
                Button("Cancel Booking") {
                    showingCancellation = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func cancellationSection(_ cancellation: BookingCancellation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cancellation Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(title: "Reason", value: cancellation.reason)
                InfoRow(title: "Cancelled At", value: DateFormatter.displayDate.string(from: cancellation.cancelledAt))
                
                if let refundAmount = cancellation.refundAmount {
                    InfoRow(title: "Refund Amount", value: "\(Int(refundAmount)) MAD")
                }
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct CancellationView: View {
    @Binding var reason: String
    let onCancel: () -> Void
    let onConfirm: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Cancellation Reason") {
                    TextEditor(text: $reason)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Text("This action cannot be undone. Refund policies may apply.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Cancel Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        onConfirm()
                    }
                    .disabled(reason.isEmpty)
                }
            }
        }
    }
}

// MARK: - Extensions
extension BookingStatus {
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .awaitingSplit: return "Payment Required"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .refunded: return "Refunded"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .confirmed: return .green
        case .awaitingSplit: return .blue
        case .completed: return .gray
        case .cancelled: return .red
        case .refunded: return .purple
        }
    }
}

extension DateFormatter {
    static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    NavigationView {
        BookingsView(viewModel: ActivitiesViewModel())
    }
}