import SwiftUI
import MarketplaceService

/// Offer management system with negotiation support
/// Per Section 11 of implementation-plan.md
public struct OfferSheet: View {
    let listing: Listing
    @ObservedObject var viewModel: MarketplaceViewModel
    @State private var offerAmount = ""
    @State private var offerMessage = ""
    @State private var currentOffers: [Offer] = []
    @State private var isSubmitting = false
    @State private var showingNegotiationHelper = false
    @State private var negotiationSuggestion: NegotiationSuggestion?
    
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Listing summary
                    ListingSummaryCard(listing: listing)
                    
                    // Existing offers
                    if !currentOffers.isEmpty {
                        ExistingOffersSection(offers: currentOffers)
                    }
                    
                    // Make new offer
                    MakeOfferSection(
                        listing: listing,
                        offerAmount: $offerAmount,
                        offerMessage: $offerMessage,
                        negotiationSuggestion: $negotiationSuggestion,
                        onGetSuggestion: loadNegotiationSuggestion
                    )
                    
                    // Offer guidelines
                    OfferGuidelinesCard()
                }
                .padding()
            }
            .navigationTitle("Make Offer")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Submit") { submitOffer() }
                    .disabled(!canSubmitOffer || isSubmitting)
            )
        }
        .onAppear {
            loadExistingOffers()
        }
        .sheet(isPresented: $showingNegotiationHelper) {
            if let suggestion = negotiationSuggestion {
                NegotiationHelperView(
                    suggestion: suggestion,
                    onApply: { appliedSuggestion in
                        offerAmount = String(appliedSuggestion.suggestedPrice.amount / 100)
                        offerMessage = appliedSuggestion.draftMessage
                        showingNegotiationHelper = false
                    }
                )
            }
        }
    }
    
    private var canSubmitOffer: Bool {
        guard let amount = Double(offerAmount), amount > 0 else { return false }
        return amount <= Double(listing.price.amount / 100) * 1.2 // Max 120% of asking price
    }
    
    private func loadExistingOffers() {
        // Simulate loading existing offers
        let loadWork = DispatchWorkItem(block: {
            currentOffers = [
                Offer(
                    id: "1",
                    listingId: listing.id ?? "",
                    buyerId: "other_buyer",
                    amount: Money(amount: listing.price.amount - 50000, currency: listing.price.currency),
                    status: .pending,
                    createdAt: Date().addingTimeInterval(-3600),
                    updatedAt: nil
                )
            ]
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: loadWork)
    }
    
    private func loadNegotiationSuggestion() {
        guard let amount = Double(offerAmount), amount > 0 else { return }
        
        // Simulate AI negotiation helper
        let suggestWork = DispatchWorkItem(block: {
            negotiationSuggestion = NegotiationSuggestion(
                suggestedPrice: Money(
                    amount: Int(amount * 0.9 * 100), // Suggest 10% lower
                    currency: listing.price.currency
                ),
                reasoning: "Based on similar items and the seller's pricing history, this offer is likely to be accepted.",
                comparables: [listing.id ?? ""],
                draftMessage: "Hi! I'm very interested in this item. Would you consider \(Int(amount * 0.9)) \(listing.price.currency)? I can pick it up this week. Thanks!"
            )
            showingNegotiationHelper = true
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: suggestWork)
    }
    
    private func submitOffer() {
        guard let amount = Double(offerAmount), amount > 0 else { return }
        
        isSubmitting = true
        
        Task {
            do {
                let money = Money(amount: Int(amount * 100), currency: listing.price.currency)
                _ = try await viewModel.makeOffer(listingId: listing.id ?? "", amount: money)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    // Handle error
                }
            }
        }
    }
}

// MARK: - Listing Summary

struct ListingSummaryCard: View {
    let listing: Listing
    
    var body: some View {
        HStack(spacing: 12) {
            // Image
            AsyncImage(url: URL(string: listing.thumbnails.first ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.2))
            }
            .frame(width: 80, height: 80)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("Asking Price")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(listing.price.displayAmount)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                HStack {
                    Image(systemName: "location")
                        .font(.caption)
                    Text(listing.location.arrondissement ?? "")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Existing Offers

struct ExistingOffersSection: View {
    let offers: [Offer]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other Offers")
                .font(.headline)
            
            ForEach(offers) { offer in
                OfferRow(offer: offer)
            }
            
            Text("Be competitive to increase your chances")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct OfferRow: View {
    let offer: Offer
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(offer.amount.displayAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(offer.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StatusBadge(status: offer.status)
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: OfferStatus
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .accepted: return .green
        case .declined: return .red
        case .withdrawn: return .gray
        case .expired: return .gray
        }
    }
}

// MARK: - Make Offer Section

struct MakeOfferSection: View {
    let listing: Listing
    @Binding var offerAmount: String
    @Binding var offerMessage: String
    @Binding var negotiationSuggestion: NegotiationSuggestion?
    let onGetSuggestion: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Offer")
                .font(.headline)
            
            // Amount input
            VStack(alignment: .leading, spacing: 8) {
                Text("Offer Amount")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text(listing.price.currency)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    TextField("0", text: $offerAmount)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Price analysis
                if let amount = Double(offerAmount), amount > 0 {
                    OfferAnalysisView(
                        offerAmount: amount,
                        askingPrice: Double(listing.price.amount) / 100,
                        currency: listing.price.currency
                    )
                }
            }
            
            // AI suggestion button
            Button(action: onGetSuggestion) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Get Negotiation Suggestion")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(offerAmount.isEmpty)
            
            // Message
            VStack(alignment: .leading, spacing: 8) {
                Text("Message (Optional)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextEditor(text: $offerMessage)
                    .frame(minHeight: 80)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Text("Add a personal message to increase your chances")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Offer Analysis

struct OfferAnalysisView: View {
    let offerAmount: Double
    let askingPrice: Double
    let currency: String
    
    private var percentage: Double {
        (offerAmount / askingPrice) * 100
    }
    
    private var analysis: OfferAnalysis {
        switch percentage {
        case 0..<50:
            return OfferAnalysis(
                level: .veryLow,
                message: "This offer is significantly below asking price",
                likelihood: "Very low chance of acceptance",
                color: .red
            )
        case 50..<70:
            return OfferAnalysis(
                level: .low,
                message: "Low offer - consider increasing",
                likelihood: "Low chance of acceptance",
                color: .orange
            )
        case 70..<90:
            return OfferAnalysis(
                level: .reasonable,
                message: "Reasonable offer with negotiation room",
                likelihood: "Good chance of acceptance",
                color: .blue
            )
        case 90..<100:
            return OfferAnalysis(
                level: .competitive,
                message: "Competitive offer",
                likelihood: "High chance of acceptance",
                color: .green
            )
        case 100..<120:
            return OfferAnalysis(
                level: .full,
                message: "At or above asking price",
                likelihood: "Very high chance of acceptance",
                color: .green
            )
        default:
            return OfferAnalysis(
                level: .excessive,
                message: "Offer exceeds reasonable range",
                likelihood: "Consider offering asking price instead",
                color: .purple
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(Int(percentage))% of asking price")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(analysis.color)
                
                Spacer()
                
                Image(systemName: analysis.level.icon)
                    .foregroundColor(analysis.color)
            }
            
            ProgressView(value: min(percentage, 120), total: 120)
                .progressViewStyle(LinearProgressViewStyle(tint: analysis.color))
            
            Text(analysis.message)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(analysis.likelihood)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(analysis.color)
        }
        .padding()
        .background(analysis.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct OfferAnalysis {
    let level: OfferLevel
    let message: String
    let likelihood: String
    let color: Color
}

enum OfferLevel {
    case veryLow, low, reasonable, competitive, full, excessive
    
    var icon: String {
        switch self {
        case .veryLow: return "arrow.down.circle.fill"
        case .low: return "arrow.down.circle"
        case .reasonable: return "checkmark.circle"
        case .competitive: return "arrow.up.circle"
        case .full: return "checkmark.circle.fill"
        case .excessive: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Guidelines

struct OfferGuidelinesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Offer Guidelines", systemImage: "lightbulb")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                OfferGuidelineItem(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "Research similar items to make competitive offers"
                )
                OfferGuidelineItem(
                    icon: "message",
                    text: "Include a polite message explaining your interest"
                )
                OfferGuidelineItem(
                    icon: "clock",
                    text: "Be ready to complete the transaction quickly"
                )
                OfferGuidelineItem(
                    icon: "handshake",
                    text: "Be respectful in negotiations"
                )
                OfferGuidelineItem(
                    icon: "xmark.circle",
                    text: "Don't make multiple lowball offers"
                )
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct OfferGuidelineItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Negotiation Helper

struct NegotiationHelperView: View {
    let suggestion: NegotiationSuggestion
    let onApply: (NegotiationSuggestion) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // AI suggestion
                    VStack(alignment: .leading, spacing: 12) {
                        Label("AI Suggestion", systemImage: "sparkles")
                            .font(.headline)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommended Offer")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(suggestion.suggestedPrice.displayAmount)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Reasoning
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why This Amount")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(suggestion.reasoning)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Draft message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggested Message")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(suggestion.draftMessage)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Apply button
                    Button(action: { onApply(suggestion) }) {
                        Text("Use This Suggestion")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Negotiation Helper")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}