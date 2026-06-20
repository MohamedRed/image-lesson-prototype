import SwiftUI
import HomeServicesService

public struct RFQDetailView: View {
    let rfq: RFQ
    @ObservedObject var viewModel: HomeServicesViewModel
    @State private var showingBidSheet = false
    @State private var selectedBid: Bid?
    @State private var showingNegotiation = false
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(rfq.scope.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        StatusBadge(status: rfq.status)
                    }
                    
                    Text(rfq.scope.description)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    // Location & Budget
                    HStack(spacing: 20) {
                        Label(rfq.location.city, systemImage: "location.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let budget = rfq.budgetRange {
                            Label("\(Int(budget.min))-\(Int(budget.max)) MAD", systemImage: "banknote")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        
                        if rfq.siteVisitRequested {
                            Label("Site visit", systemImage: "eye.fill")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Bids Section
                if rfq.status == .open {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Bids Received")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(viewModel.currentRFQBids.count)")
                                .font(.subheadline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        if viewModel.currentRFQBids.isEmpty {
                            EmptyStateView(
                                icon: "clock",
                                title: "No bids yet",
                                subtitle: "Professional service providers will submit bids soon"
                            )
                            .padding(.vertical)
                        } else {
                            ForEach(viewModel.currentRFQBids) { bid in
                                BidCard(bid: bid) {
                                    selectedBid = bid
                                    showingNegotiation = true
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Actions
                if rfq.status == .open {
                    HStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await viewModel.cancelRFQ(id: rfq.id!)
                            }
                        }) {
                            Label("Cancel Request", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        
                        if !viewModel.currentRFQBids.isEmpty {
                            Button(action: {
                                // Show bid selection
                                showingBidSheet = true
                            }) {
                                Label("Accept a Bid", systemImage: "checkmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Request Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let rfqId = rfq.id {
                await viewModel.loadBids(for: rfqId)
            }
        }
        .sheet(isPresented: $showingBidSheet) {
            BidSelectionSheet(bids: viewModel.currentRFQBids, viewModel: viewModel)
        }
        .sheet(item: $selectedBid) { bid in
            NegotiationView(bid: bid, viewModel: viewModel)
        }
    }
}

// MARK: - Bid Card
struct BidCard: View {
    let bid: Bid
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bid.proName ?? "Professional")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            Label("\(Int(bid.amountMAD)) MAD", systemImage: "banknote")
                                .font(.subheadline)
                                .foregroundColor(.green)
                            
                            Label("\(bid.timelineDays) days", systemImage: "calendar")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    if bid.counters.customerCount > 0 || bid.counters.proCount > 0 {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.caption)
                            Text("\(bid.counters.customerCount + bid.counters.proCount) counters")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                    }
                }
                
                if let message = bid.message, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 16) {
                    if bid.includesMaterials {
                        Label("Materials included", systemImage: "cube.box.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if bid.visitRequired {
                        Label("Visit required", systemImage: "eye.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bid Selection Sheet
struct BidSelectionSheet: View {
    let bids: [Bid]
    @ObservedObject var viewModel: HomeServicesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBid: Bid?
    @State private var depositPercent = 30
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Select a bid to accept")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(bids) { bid in
                        BidSelectionCard(
                            bid: bid,
                            isSelected: selectedBid?.id == bid.id
                        ) {
                            selectedBid = bid
                        }
                        .padding(.horizontal)
                    }
                    
                    if selectedBid != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Deposit Amount")
                                .font(.headline)
                            
                            Picker("Deposit", selection: $depositPercent) {
                                Text("20%").tag(20)
                                Text("30%").tag(30)
                                Text("40%").tag(40)
                                Text("50%").tag(50)
                            }
                            .pickerStyle(.segmented)
                            
                            Text("You'll pay \(Int(Double(depositPercent) * (selectedBid?.amountMAD ?? 0) / 100)) MAD upfront")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Accept Bid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Accept") {
                        Task {
                            if let bid = selectedBid {
                                if let _ = await viewModel.acceptBid(bid.id!, depositPercent: depositPercent) {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .disabled(selectedBid == nil || viewModel.isLoading)
                }
            }
        }
    }
}

struct BidSelectionCard: View {
    let bid: Bid
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                BidCard(bid: bid) {}
                    .disabled(true)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
                    .padding(.trailing)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}