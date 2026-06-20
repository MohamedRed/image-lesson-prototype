import SwiftUI
import HomeServicesService

public struct ContractDetailView: View {
    let contract: Contract
    @ObservedObject var viewModel: HomeServicesViewModel
    let isPro: Bool
    
    @State private var showingChat = false
    @State private var showingPayment = false
    @State private var showingReview = false
    @State private var showingDispute = false
    
    public init(contract: Contract, viewModel: HomeServicesViewModel, isPro: Bool = false) {
        self.contract = contract
        self.viewModel = viewModel
        self.isPro = isPro
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Contract Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(contract.agreedScope.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("\(Int(contract.priceMAD)) MAD")
                                .font(.title3)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        StatusBadge(contractStatus: contract.status)
                    }
                    
                    Text(contract.agreedScope.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let startDate = contract.startAt {
                        Label("Start: \(startDate, style: .date)", systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Milestones
                if !contract.milestones.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Milestones")
                            .font(.headline)
                        
                        ForEach(contract.milestones) { milestone in
                            MilestoneCard(milestone: milestone, isPro: isPro) {
                                // Handle milestone completion
                                if isPro && milestone.status == .completed {
                                    // Pro marks as complete, waiting for customer approval
                                } else if !isPro && milestone.status == .completed {
                                    // Customer approves and releases payment
                                    Task {
                                        // await viewModel.releaseMilestone()
                                    }
                                }
                            }
                        }
                        
                        // Overall Progress
                        ProgressView(value: completionProgress)
                            .tint(.blue)
                        
                        Text("\(Int(completionProgress * 100))% Complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Actions
                VStack(spacing: 12) {
                    Button(action: { showingChat = true }) {
                        Label("Message", systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    if contract.status == .active {
                        if !isPro {
                            Button(action: { showingPayment = true }) {
                                Label("Manage Payment", systemImage: "creditcard.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.completeContract(contract.id!)
                            }
                        }) {
                            Label("Mark Complete", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    
                    if contract.status == .completed && !hasReviewed {
                        Button(action: { showingReview = true }) {
                            Label("Leave Review", systemImage: "star.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    
                    Button(action: { showingDispute = true }) {
                        Label("Report Issue", systemImage: "exclamationmark.triangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle("Contract Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingChat) {
            ChatView(contractId: contract.id!, viewModel: viewModel)
        }
        .sheet(isPresented: $showingPayment) {
            PaymentView(contract: contract, viewModel: viewModel)
        }
        .sheet(isPresented: $showingReview) {
            ReviewView(contract: contract, viewModel: viewModel)
        }
        .sheet(isPresented: $showingDispute) {
            DisputeView(contract: contract, viewModel: viewModel)
        }
    }
    
    private var completionProgress: Double {
        let completed = contract.milestones.filter { 
            $0.status == .completed || $0.status == .approved 
        }.count
        guard !contract.milestones.isEmpty else { return 0 }
        return Double(completed) / Double(contract.milestones.count)
    }
    
    private var hasReviewed: Bool {
        // Check if user has already reviewed this contract
        // This would typically check against a local state or database
        return false
    }
}

// MARK: - Milestone Card
struct MilestoneCard: View {
    let milestone: Contract.Milestone
    let isPro: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("\(Int(milestone.amountMAD)) MAD")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if let dueDate = milestone.dueDate {
                        Text("Due: \(dueDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            MilestoneStatusView(status: milestone.status, isPro: isPro, action: action)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct MilestoneStatusView: View {
    let status: Contract.Milestone.MilestoneStatus
    let isPro: Bool
    let action: () -> Void
    
    var body: some View {
        switch status {
        case .pending:
            Text("Pending")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
        
        case .inProgress:
            if isPro {
                Button("Complete", action: action)
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else {
                Text("In Progress")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)
            }
        
        case .completed:
            if !isPro {
                Button("Approve & Pay", action: action)
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
            } else {
                Text("Awaiting Approval")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(6)
            }
        
        case .approved:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

// MARK: - Supporting Views

struct ChatView: View {
    let contractId: String
    @ObservedObject var viewModel: HomeServicesViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Chat Coming Soon")
                .navigationTitle("Messages")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}

struct PaymentView: View {
    let contract: Contract
    @ObservedObject var viewModel: HomeServicesViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Payment Management Coming Soon")
                .navigationTitle("Payment")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}

struct ReviewView: View {
    let contract: Contract
    @ObservedObject var viewModel: HomeServicesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var rating = 5
    @State private var reviewText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("How was your experience?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.title)
                            .foregroundColor(.yellow)
                            .onTapGesture {
                                rating = star
                            }
                    }
                }
                
                TextEditor(text: $reviewText)
                    .frame(minHeight: 100)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                Spacer()
                
                Button(action: {
                    Task {
                        await viewModel.submitReview(
                            for: contract.id!,
                            rating: rating,
                            text: reviewText.isEmpty ? nil : reviewText
                        )
                        dismiss()
                    }
                }) {
                    Text("Submit Review")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Leave Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct DisputeView: View {
    let contract: Contract
    @ObservedObject var viewModel: HomeServicesViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Dispute System Coming Soon")
                .navigationTitle("Report Issue")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}