import SwiftUI
import ActivitiesService

struct BookingFlowView: View {
    let activity: Activity
    let session: ActivitySession
    @ObservedObject var viewModel: ActivitiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedGroup: ActivityGroup?
    @State private var participants: [BookingParticipantInput] = []
    @State private var currentStep: BookingStep = .selectGroup
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Indicator
                BookingProgressView(currentStep: currentStep)
                
                // Step Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case .selectGroup:
                            selectGroupStep
                        case .selectParticipants:
                            selectParticipantsStep
                        case .review:
                            reviewStep
                        case .processing:
                            processingStep
                        case .confirmation:
                            confirmationStep
                        }
                    }
                    .padding()
                }
                
                // Action Buttons
                actionButtons
            }
            .navigationTitle("Book Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupInitialState()
        }
    }
    
    private var selectGroupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(
                title: "Select Group",
                subtitle: "Choose which group to book this activity for"
            )
            
            if viewModel.myGroups.isEmpty {
                EmptyStateView(
                    title: "No Groups",
                    message: "Create a group first to book activities",
                    systemImage: "person.3"
                )
                .frame(height: 200)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(eligibleGroups) { group in
                        GroupSelectionCard(
                            group: group,
                            isSelected: selectedGroup?.id == group.id
                        ) {
                            selectedGroup = group
                        }
                    }
                }
            }
        }
    }
    
    private var selectParticipantsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(
                title: "Select Participants",
                subtitle: "Choose who will participate in this activity"
            )
            
            if let group = selectedGroup {
                VStack(alignment: .leading, spacing: 12) {
                    Text("From \(group.name)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(Array(participants.enumerated()), id: \.offset) { index, participant in
                            ParticipantRow(
                                participant: participant,
                                maxParticipants: session.capacity
                            ) { updatedParticipant in
                                participants[index] = updatedParticipant
                            }
                        }
                    }
                    
                    // Session Info
                    sessionInfoCard
                }
            }
        }
    }
    
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                title: "Review Booking",
                subtitle: "Confirm your booking details"
            )
            
            // Activity Summary
            activitySummaryCard
            
            // Session Details
            sessionDetailsCard
            
            // Participants Summary
            participantsSummaryCard
            
            // Cost Breakdown
            costBreakdownCard
        }
    }
    
    private var processingStep: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Processing your booking...")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("This may take a few moments")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var confirmationStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("Booking Confirmed!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("You'll receive a confirmation email shortly")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let group = selectedGroup {
                VStack(spacing: 12) {
                    Text("Next Steps:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        NextStepRow(
                            icon: "creditcard",
                            title: "Payment",
                            description: "Split payment will be set up for your group"
                        )
                        
                        NextStepRow(
                            icon: "bell",
                            title: "Reminders",
                            description: "You'll get notified before the activity"
                        )
                        
                        NextStepRow(
                            icon: "location",
                            title: "Location",
                            description: "Check activity location and arrival instructions"
                        )
                    }
                }
            }
        }
        .padding(.top, 40)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            switch currentStep {
            case .selectGroup:
                Button("Continue") {
                    proceedToParticipants()
                }
                .disabled(selectedGroup == nil)
                
            case .selectParticipants:
                HStack(spacing: 12) {
                    Button("Back") {
                        currentStep = .selectGroup
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Continue") {
                        currentStep = .review
                    }
                    .disabled(selectedParticipants.isEmpty)
                    .frame(maxWidth: .infinity)
                }
                
            case .review:
                HStack(spacing: 12) {
                    Button("Back") {
                        currentStep = .selectParticipants
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Confirm Booking") {
                        Task {
                            await processBooking()
                        }
                    }
                    .disabled(isProcessing)
                    .frame(maxWidth: .infinity)
                }
                
            case .processing:
                EmptyView()
                
            case .confirmation:
                Button("Done") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Helper Views
    
    private var sessionInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(
                    title: "Date",
                    value: DateFormatter.sessionDate.string(from: session.startAt)
                )
                
                InfoRow(
                    title: "Time",
                    value: "\(DateFormatter.sessionTime.string(from: session.startAt)) - \(DateFormatter.sessionTime.string(from: session.endAt))"
                )
                
                // No venue field in ActivityLocation in current model
                
                InfoRow(
                    title: "Capacity",
                    value: "\(session.bookedCount)/\(session.capacity)"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var activitySummaryCard: some View {
        HStack(spacing: 12) {
            AsyncImage(url: activity.images.first.flatMap(URL.init)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.gray.opacity(0.3))
            }
            .frame(width: 60, height: 60)
            .clipped()
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(activity.category.displayName)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                // No venue field in ActivityLocation in current model
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var sessionDetailsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session")
                .font(.headline)
                .fontWeight(.semibold)
            
            InfoRow(
                title: "Date & Time",
                value: "\(DateFormatter.sessionDate.string(from: session.startAt)), \(DateFormatter.sessionTime.string(from: session.startAt))"
            )
            
            // No instructor field in ActivitySession in current model
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var participantsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Participants (\(selectedParticipants.count))")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(selectedParticipants, id: \.userId) { participant in
                HStack {
                    Text(participant.userName)
                        .fontWeight(.medium)
                    
                    if let skillLevel = participant.skillLevel {
                        Text("(\(skillLevel.displayName))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var costBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
            
            let pricePerPerson = activity.pricePerUnit
            let totalCost = pricePerPerson * Double(selectedParticipants.count)
            
            InfoRow(
                title: "\(selectedParticipants.count) × \(Int(pricePerPerson)) MAD",
                value: "\(Int(totalCost)) MAD"
            )
            
            Divider()
            
            HStack {
                Text("Total")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(Int(totalCost)) MAD")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Functions
    
    private var eligibleGroups: [ActivityGroup] {
        viewModel.myGroups.filter { group in
            // Filter groups that can book this activity
            group.status == .planning && 
            ((group.preferences.categories ?? []).isEmpty || (group.preferences.categories ?? []).contains(activity.category))
        }
    }
    
    private var selectedParticipants: [BookingParticipantInput] {
        participants.filter { $0.isSelected }
    }
    
    private func setupInitialState() {
        // Pre-select first eligible group
        if selectedGroup == nil && !eligibleGroups.isEmpty {
            selectedGroup = eligibleGroups.first
        }
    }
    
    private func proceedToParticipants() {
        guard let group = selectedGroup else { return }
        
        // Setup participants from group members
        participants = group.participantUserIds.map { userId in
            BookingParticipantInput(
                userId: userId,
                userName: userId, // TODO: Load actual user names
                isSelected: true, // Default to selected
                skillLevel: group.preferences.skillLevel.flatMap { SkillLevel(rawValue: $0) }
            )
        }
        
        currentStep = .selectParticipants
    }
    
    private func processBooking() async {
        guard let group = selectedGroup else { return }
        
        currentStep = .processing
        isProcessing = true
        
        let bookingParticipants = selectedParticipants.map { input in
            BookingParticipant(
                userId: input.userId,
                userName: input.userName,
                role: .participant,
                status: .invited
            )
        }
        
        await viewModel.createBooking(
            groupId: group.id,
            activityId: activity.id,
            sessionId: session.id,
            participants: bookingParticipants
        )
        
        isProcessing = false
        currentStep = .confirmation
    }
    
    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Types and Views

enum BookingStep: Int, CaseIterable {
    case selectGroup = 0
    case selectParticipants = 1
    case review = 2
    case processing = 3
    case confirmation = 4
    
    var title: String {
        switch self {
        case .selectGroup: return "Group"
        case .selectParticipants: return "Participants"
        case .review: return "Review"
        case .processing: return "Processing"
        case .confirmation: return "Confirmation"
        }
    }
}

struct BookingParticipantInput {
    let userId: String
    let userName: String
    var isSelected: Bool
    var skillLevel: SkillLevel?
}

struct BookingProgressView: View {
    let currentStep: BookingStep
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(BookingStep.allCases.enumerated()), id: \.offset) { index, step in
                if step == .processing || step == .confirmation {
                    EmptyView() // Don't show these in progress
                } else {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 24, height: 24)
                            .overlay {
                                if step.rawValue < currentStep.rawValue {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(step.rawValue + 1)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(step == currentStep ? .white : .primary)
                                }
                            }
                        
                        if index < BookingStep.allCases.count - 3 { // Exclude processing and confirmation
                            Rectangle()
                                .fill(step.rawValue < currentStep.rawValue ? .green : .gray.opacity(0.3))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    private func stepColor(for step: BookingStep) -> Color {
        if step.rawValue < currentStep.rawValue {
            return .green
        } else if step == currentStep {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }
}

struct GroupSelectionCard: View {
    let group: ActivityGroup
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(group.participantUserIds.count) members")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .blue : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ParticipantRow: View {
    let participant: BookingParticipantInput
    let maxParticipants: Int?
    let onUpdate: (BookingParticipantInput) -> Void
    
    var body: some View {
        HStack {
            Button {
                var updated = participant
                updated.isSelected.toggle()
                onUpdate(updated)
            } label: {
                Image(systemName: participant.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(participant.isSelected ? .blue : .gray)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading) {
                Text(participant.userName)
                    .fontWeight(.medium)
                
                if let skillLevel = participant.skillLevel {
                    Text(skillLevel.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(participant.isSelected ? 1.0 : 0.6)
    }
}

struct NextStepRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    BookingFlowView(
        activity: Activity(
            id: "1",
            providerId: "provider1",
            title: "Rock Climbing Basics",
            category: .fitness,
            description: "Learn rock climbing fundamentals",
            images: [],
            rules: [],
            minParticipants: 2,
            maxParticipants: 10,
            pricePerUnit: 150.0,
            unit: .person,
            durationMinutes: 120,
            location: ActivityLocation(lat: 33.5731, lng: -7.5898, address: "", neighborhood: nil),
            tags: [],
            ageRestrictions: nil,
            skillLevel: .any,
            equipmentNeeded: [],
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        session: ActivitySession(
            id: "session1",
            activityId: "1",
            startAt: Date(),
            endAt: Date().addingTimeInterval(7200),
            capacity: 10,
            bookedCount: 0,
            priceOverride: nil,
            bookingWindow: BookingWindow(opensAt: Date().addingTimeInterval(-86400*7), closesAt: Date().addingTimeInterval(-7200)),
            status: .open
        ),
        viewModel: ActivitiesViewModel()
    )
}