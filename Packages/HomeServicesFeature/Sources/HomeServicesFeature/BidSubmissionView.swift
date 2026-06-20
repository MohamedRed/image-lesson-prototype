import SwiftUI
import HomeServicesService

public struct BidSubmissionView: View {
    let rfq: RFQ
    @ObservedObject var viewModel: HomeServicesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount = ""
    @State private var timelineDays = ""
    @State private var includesMaterials = false
    @State private var visitRequired = false
    @State private var message = ""
    @State private var autoAcceptAbove = ""
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // RFQ Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Job Details")
                            .font(.headline)
                        
                        Text(rfq.scope.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(rfq.scope.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                        
                        HStack {
                            Label(rfq.location.city, systemImage: "location.fill")
                            
                            if let budget = rfq.budgetRange {
                                Spacer()
                                Text("Budget: \(Int(budget.min))-\(Int(budget.max)) MAD")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Bid Form
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Bid")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Amount (MAD)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("0", text: $amount)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Timeline (days)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("0", text: $timelineDays)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        Toggle("Materials Included", isOn: $includesMaterials)
                        
                        Toggle("Site Visit Required", isOn: $visitRequired)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Message to Customer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $message)
                                .frame(minHeight: 80)
                                .padding(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-accept if counter above (MAD) - Optional")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("Leave empty to disable", text: $autoAcceptAbove)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tips for winning bids", systemImage: "lightbulb.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Text("• Be competitive but realistic with pricing\n• Provide clear timeline expectations\n• Explain what's included in your price\n• Mention your relevant experience")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Submit Bid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        Task {
                            await submitBid()
                        }
                    }
                    .disabled(!isFormValid || viewModel.isLoading)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        guard let amountValue = Double(amount),
              let timelineValue = Int(timelineDays),
              amountValue > 0,
              timelineValue > 0 else {
            return false
        }
        return true
    }
    
    private func submitBid() async {
        guard let rfqId = rfq.id,
              let amountValue = Double(amount),
              let timelineValue = Int(timelineDays) else {
            return
        }
        
        let newBid = NewBid(
            rfqId: rfqId,
            amountMAD: amountValue,
            timelineDays: timelineValue,
            includesMaterials: includesMaterials,
            visitRequired: visitRequired,
            message: message.isEmpty ? nil : message,
            autoAcceptAbove: autoAcceptAbove.isEmpty ? nil : Double(autoAcceptAbove)
        )
        
        if let _ = await viewModel.submitBid(newBid) {
            dismiss()
        }
    }
}

// MARK: - Negotiation View
public struct NegotiationView: View {
    let bid: Bid
    @ObservedObject var viewModel: HomeServicesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var counterAmount = ""
    @State private var counterTimeline = ""
    @State private var showingAcceptConfirmation = false
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Current Bid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Offer")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Amount")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(bid.amountMAD)) MAD")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Timeline")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(bid.timelineDays) days")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        if bid.includesMaterials {
                            Label("Materials included", systemImage: "cube.box.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let message = bid.message, !message.isEmpty {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Counter History
                    if bid.counters.customerCount > 0 || bid.counters.proCount > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Negotiation Progress")
                                .font(.headline)
                            
                            HStack {
                                Text("Customer counters: \(bid.counters.customerCount)/3")
                                Spacer()
                                Text("Pro counters: \(bid.counters.proCount)/3")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            ProgressView(value: Double(bid.counters.customerCount + bid.counters.proCount), total: 6)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Counter Offer Form
                    if canCounter {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Make Counter Offer")
                                .font(.headline)
                            
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("New Amount (MAD)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("\(Int(bid.amountMAD))", text: $counterAmount)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("New Timeline (days)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("\(bid.timelineDays)", text: $counterTimeline)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            
                            Button(action: submitCounter) {
                                Label("Send Counter Offer", systemImage: "arrow.left.arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(counterAmount.isEmpty && counterTimeline.isEmpty)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    } else {
                        Text("Maximum counter offers reached (3 per side)")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await viewModel.withdrawBid(id: bid.id!)
                                dismiss()
                            }
                        }) {
                            Label("Reject", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        
                        Button(action: {
                            showingAcceptConfirmation = true
                        }) {
                            Label("Accept", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Negotiation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Accept this bid?", isPresented: $showingAcceptConfirmation) {
                Button("Accept with 30% deposit") {
                    Task {
                        if let _ = await viewModel.acceptBid(bid.id!, depositPercent: 30) {
                            dismiss()
                        }
                    }
                }
                Button("Accept with 50% deposit") {
                    Task {
                        if let _ = await viewModel.acceptBid(bid.id!, depositPercent: 50) {
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    private var canCounter: Bool {
        // Assuming we're the customer for this view
        return bid.counters.customerCount < 3
    }
    
    private func submitCounter() {
        Task {
            let counter = Counter(
                bidId: bid.id!,
                newAmountMAD: counterAmount.isEmpty ? nil : Double(counterAmount),
                newTimelineDays: counterTimeline.isEmpty ? nil : Int(counterTimeline)
            )
            
            await viewModel.counterBid(counter)
            counterAmount = ""
            counterTimeline = ""
        }
    }
}