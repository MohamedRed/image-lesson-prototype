import SwiftUI
import ActivitiesService

struct SplitPaymentView: View {
    let booking: Booking
    @ObservedObject var viewModel: ActivitiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var splitIntent: SplitIntent?
    @State private var shareType: SplitShareType = .even
    @State private var customShares: [CustomShareInput] = []
    @State private var isLoading = true
    @State private var showingPayment = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading split payment...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let splitIntent = splitIntent {
                    existingSplitView(splitIntent)
                } else {
                    createSplitView
                }
            }
            .navigationTitle("Split Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadSplitIntent()
        }
        .sheet(isPresented: $showingPayment) {
            if let splitIntent = splitIntent,
               let userShare = splitIntent.shares.first(where: { $0.userId == getCurrentUserId() }) {
                PaymentView(
                    splitIntent: splitIntent,
                    userShare: userShare,
                    viewModel: viewModel
                )
            }
        }
    }
    
    private var createSplitView: some View {
        Form {
            Section("Split Details") {
                Picker("Split Type", selection: $shareType) {
                    Text("Split Evenly").tag(SplitShareType.even)
                    Text("Custom Amounts").tag(SplitShareType.custom)
                }
                .pickerStyle(.segmented)
            }
            
            Section("Total Amount") {
                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(booking.totalAmount)) MAD")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            if shareType == .even {
                evenSplitSection
            } else {
                customSplitSection
            }
            
            Section {
                Button("Create Split Payment") {
                    Task {
                        await createSplitPayment()
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .disabled(!isValidSplit())
            }
        }
    }
    
    private var evenSplitSection: some View {
        Section("Even Split") {
            let amountPerPerson = booking.totalAmount / Double(booking.participants.count)
            
            ForEach(booking.participants, id: \.userId) { participant in
                HStack {
                    VStack(alignment: .leading) {
                        Text(participant.userName)
                            .fontWeight(.medium)
                        Text("Participant")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(Int(amountPerPerson)) MAD")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var customSplitSection: some View {
        Section("Custom Split") {
            ForEach(Array(customShares.enumerated()), id: \.offset) { index, share in
                HStack {
                    Text(share.userName)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    TextField("Amount", value: $customShares[index].amount, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    
                    Text("MAD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            let totalCustom = customShares.reduce(0) { $0 + $1.amount }
            let remaining = booking.totalAmount - totalCustom
            
            HStack {
                Text("Remaining")
                    .fontWeight(.semibold)
                    .foregroundColor(remaining == 0 ? .green : .orange)
                
                Spacer()
                
                Text("\(Int(remaining)) MAD")
                    .fontWeight(.bold)
                    .foregroundColor(remaining == 0 ? .green : .orange)
            }
            
            if remaining != 0 {
                Text("Total must equal \(Int(booking.totalAmount)) MAD")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private func existingSplitView(_ splitIntent: SplitIntent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status Header
                statusHeader(splitIntent)
                
                // Shares List
                sharesSection(splitIntent)
                
                // Actions
                if splitIntent.status == .pending || splitIntent.status == .partial {
                    actionsSection(splitIntent)
                }
            }
            .padding()
        }
    }
    
    private func statusHeader(_ splitIntent: SplitIntent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Split Payment")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(splitIntent.status.displayName)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(splitIntent.status.color.opacity(0.15), in: Capsule())
                    .foregroundColor(splitIntent.status.color)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text("Total: \(Int(booking.totalAmount)) MAD")
                .font(.headline)
                .foregroundColor(.green)
            
            if splitIntent.status != .paid && splitIntent.status != .expired {
                Text("Expires: \(DateFormatter.displayDateTime.string(from: splitIntent.expiresAt))")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private func sharesSection(_ splitIntent: SplitIntent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Shares")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(splitIntent.shares, id: \.userId) { share in
                ShareCard(share: share, isCurrentUser: share.userId == getCurrentUserId())
            }
        }
    }
    
    private func actionsSection(_ splitIntent: SplitIntent) -> some View {
        VStack(spacing: 12) {
            if let userShare = splitIntent.shares.first(where: { $0.userId == getCurrentUserId() }),
               userShare.status == .pending {
                Button("Pay My Share (\(Int(userShare.amount)) MAD)") {
                    showingPayment = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            
            // TODO: Add cancel split option for organizer
        }
    }
    
    private func loadSplitIntent() async {
        // TODO: Check if split intent already exists for this booking
        // For now, assume no existing split
        setupCustomShares()
        isLoading = false
    }
    
    private func setupCustomShares() {
        customShares = booking.participants.map { participant in
            CustomShareInput(
                userId: participant.userId,
                userName: participant.userName,
                amount: booking.totalAmount / Double(booking.participants.count)
            )
        }
    }
    
    private func createSplitPayment() async {
        let customShareData: [CustomShare]? = shareType == .custom 
            ? customShares.map { CustomShare(userId: $0.userId, amount: $0.amount) }
            : nil
        
        await viewModel.createSplitPayment(
            bookingId: booking.id,
            shareType: shareType,
            customShares: customShareData
        )
        
        // Reload split intent
        await loadSplitIntent()
    }
    
    private func isValidSplit() -> Bool {
        if shareType == .even {
            return true
        } else {
            let total = customShares.reduce(0) { $0 + $1.amount }
            return abs(total - booking.totalAmount) < 0.01
        }
    }
    
    private func getCurrentUserId() -> String {
        // TODO: Get from auth service
        return "current_user_id"
    }
}

struct CustomShareInput {
    let userId: String
    let userName: String
    var amount: Double
}

struct ShareCard: View {
    let share: SplitShare
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(share.userName)
                        .fontWeight(.medium)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Text(share.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(share.status.color.opacity(0.15), in: Capsule())
                    .foregroundColor(share.status.color)
                
                if share.status == .paid, let paidAt = share.paidAt {
                    Text("Paid: \(DateFormatter.displayDate.string(from: paidAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(Int(share.amount)) MAD")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(share.status == .paid ? .green : .primary)
                
                if share.status == .pending && isCurrentUser {
                    Text("Payment Required")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(
            isCurrentUser ? Color.blue.opacity(0.05) : Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentUser ? .blue.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}

struct PaymentView: View {
    let splitIntent: SplitIntent
    let userShare: SplitShare
    @ObservedObject var viewModel: ActivitiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var paymentMethodId = "pm_test_card" // TODO: Implement payment method selection
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Payment Summary
                VStack(alignment: .leading, spacing: 16) {
                    Text("Payment Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("Your Share")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(userShare.amount)) MAD")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                
                // Payment Method Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Payment Method")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // TODO: Implement proper payment method selection
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundColor(.blue)
                        Text("•••• •••• •••• 1234")
                            .font(.subheadline)
                        Spacer()
                        Text("Visa")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15), in: Capsule())
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
                
                // Pay Button
                Button("Pay \(Int(userShare.amount)) MAD") {
                    Task {
                        await processPayment()
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .padding()
            .navigationTitle("Complete Payment")
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
    
    private func processPayment() async {
        await viewModel.paySplitShare(
            splitId: splitIntent.id,
            paymentMethodId: paymentMethodId
        )
        dismiss()
    }
}

// MARK: - Extensions
extension SplitStatus {
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .partial: return "Partially Paid"
        case .paid: return "Paid"
        case .expired: return "Expired"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .partial: return .blue
        case .paid: return .green
        case .expired: return .red
        case .cancelled: return .gray
        }
    }
}

extension SplitShareStatus {
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .paid: return "Paid"
        case .failed: return "Failed"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .paid: return .green
        case .failed: return .red
        }
    }
}

extension DateFormatter {
    static let displayDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    SplitPaymentView(
        booking: Booking(
            id: "booking1",
            groupId: "group1",
            activityId: "activity1",
            sessionId: "session1",
            organizerId: "user1",
            participants: [
                BookingParticipant(userId: "user1", userName: "Alice", role: .organizer, status: .accepted),
                BookingParticipant(userId: "user2", userName: "Bob", role: .participant, status: .invited)
            ],
            totalAmount: 200.0,
            currency: "MAD",
            status: .awaitingSplit,
            paymentIntentId: nil,
            settlement: nil,
            cancellation: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        viewModel: ActivitiesViewModel()
    )
}