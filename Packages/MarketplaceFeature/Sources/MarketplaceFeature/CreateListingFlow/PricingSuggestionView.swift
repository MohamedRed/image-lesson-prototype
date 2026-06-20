import SwiftUI
import MarketplaceService

/// Price step with AI-powered pricing suggestions
/// Per Section 9 of implementation-plan.md
struct PriceStep: View {
    @Binding var price: String
    @Binding var currency: String
    let category: ListingCategory
    let condition: ItemCondition
    let title: String
    let cityId: String
    @Binding var priceSuggestion: PricingSuggestion?
    @ObservedObject var viewModel: MarketplaceViewModel
    
    @State private var isLoadingSuggestion = false
    @State private var showingSuggestionDetails = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Set Your Price")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // AI pricing suggestion
                if !title.isEmpty {
                    Button(action: loadPricingSuggestion) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Get AI Price Suggestion")
                            if isLoadingSuggestion {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoadingSuggestion)
                }
                
                // Pricing suggestion display
                if let suggestion = priceSuggestion {
                    PricingSuggestionCard(
                        suggestion: suggestion,
                        onApply: {
                            price = String(suggestion.suggestedPrice.amount / 100)
                            currency = suggestion.suggestedPrice.currency
                        },
                        onShowDetails: {
                            showingSuggestionDetails = true
                        }
                    )
                }
                
                // Manual price input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Price")
                        .font(.headline)
                    
                    HStack {
                        Picker("Currency", selection: $currency) {
                            Text("MAD").tag("MAD")
                            Text("USD").tag("USD")
                            Text("EUR").tag("EUR")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 80)
                        
                        TextField("0", text: $price)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Price guidance
                    if !price.isEmpty, let amount = Double(price) {
                        PriceGuidanceView(
                            amount: amount,
                            currency: currency,
                            category: category,
                            condition: condition
                        )
                    }
                }
                
                // Pricing tips
                PricingTipsView(category: category, condition: condition)
            }
            .padding()
        }
        .sheet(isPresented: $showingSuggestionDetails) {
            if let suggestion = priceSuggestion {
                PricingSuggestionDetailView(suggestion: suggestion)
            }
        }
    }
    
    private func loadPricingSuggestion() {
        isLoadingSuggestion = true
        
        Task {
            do {
                let suggestion = try await viewModel.suggestPrice(
                    for: category,
                    condition: condition,
                    title: title,
                    description: "",
                    cityId: cityId
                )
                
                await MainActor.run {
                    priceSuggestion = suggestion
                    isLoadingSuggestion = false
                }
            } catch {
                await MainActor.run {
                    isLoadingSuggestion = false
                }
            }
        }
    }
}

struct PricingSuggestionCard: View {
    let suggestion: PricingSuggestion
    let onApply: () -> Void
    let onShowDetails: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Price Suggestion", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundColor(.purple)
                
                Spacer()
                
                Button("Details", action: onShowDetails)
                    .font(.caption)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Suggested Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(suggestion.suggestedPrice.displayAmount)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Range")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(suggestion.priceRange.min.displayAmount) - \(suggestion.priceRange.max.displayAmount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Confidence indicator
            HStack {
                Text("Confidence: \(Int(suggestion.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: suggestion.confidence)
                    .progressViewStyle(LinearProgressViewStyle(tint: confidenceColor))
                    .frame(height: 4)
                
                Text("\(suggestion.comparables.count) comparables")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let reasoning = suggestion.reasoning {
                Text(reasoning)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            Button(action: onApply) {
                Text("Use This Price")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var confidenceColor: Color {
        if suggestion.confidence >= 0.8 {
            return .green
        } else if suggestion.confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

struct PriceGuidanceView: View {
    let amount: Double
    let currency: String
    let category: ListingCategory
    let condition: ItemCondition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Price feedback
            HStack {
                Image(systemName: priceIcon)
                    .foregroundColor(priceColor)
                Text(priceGuidance)
                    .font(.subheadline)
                    .foregroundColor(priceColor)
            }
            
            // Quick adjustments
            HStack {
                Button("-10%") {
                    // Decrease by 10%
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("-5%") {
                    // Decrease by 5%
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("+5%") {
                    // Increase by 5%
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("+10%") {
                    // Increase by 10%
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var priceGuidance: String {
        // Simplified logic - would use actual market data
        switch amount {
        case 0..<100:
            return "Very affordable - may sell quickly"
        case 100..<500:
            return "Competitive pricing for \(category.displayName)"
        case 500..<2000:
            return "Higher price - ensure good condition"
        default:
            return "Premium pricing - highlight unique features"
        }
    }
    
    private var priceIcon: String {
        switch amount {
        case 0..<100: return "arrow.down.circle.fill"
        case 100..<500: return "checkmark.circle.fill"
        case 500..<2000: return "arrow.up.circle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }
    
    private var priceColor: Color {
        switch amount {
        case 0..<100: return .green
        case 100..<500: return .blue
        case 500..<2000: return .orange
        default: return .red
        }
    }
}

struct PricingTipsView: View {
    let category: ListingCategory
    let condition: ItemCondition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pricing Tips", systemImage: "lightbulb")
                .font(.headline)
            
            ForEach(pricingTips, id: \.self) { tip in
                HStack(alignment: .top) {
                    Text("•")
                        .foregroundColor(.blue)
                    Text(tip)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var pricingTips: [String] {
        var tips = [
            "Research similar items to set competitive prices",
            "Factor in the item's age and condition",
            "Consider your urgency to sell"
        ]
        
        switch category {
        case .electronics:
            tips.append("Check current retail prices for depreciation")
            tips.append("Include original accessories for higher value")
        case .apparel:
            tips.append("Designer brands can command premium prices")
            tips.append("Seasonal items sell better at the right time")
        case .furniture:
            tips.append("Delivery availability affects pricing")
            tips.append("Antique or designer pieces may be worth more")
        default:
            break
        }
        
        return tips
    }
}

struct PricingSuggestionDetailView: View {
    let suggestion: PricingSuggestion
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Main suggestion
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggested Price")
                            .font(.headline)
                        Text(suggestion.suggestedPrice.displayAmount)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    // Confidence and range
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Price Range")
                            .font(.headline)
                        Text("\(suggestion.priceRange.min.displayAmount) - \(suggestion.priceRange.max.displayAmount)")
                            .font(.title3)
                        
                        HStack {
                            Text("Confidence: \(Int(suggestion.confidence * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: suggestion.confidence)
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                    }
                    
                    // Reasoning
                    if let reasoning = suggestion.reasoning {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Analysis")
                                .font(.headline)
                            Text(reasoning)
                                .font(.body)
                        }
                    }
                    
                    // Comparables
                    if !suggestion.comparables.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Similar Items")
                                .font(.headline)
                            
                            ForEach(suggestion.comparables.prefix(5), id: \.id) { comparable in
                                ComparableItemRow(comparable: comparable)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Price Analysis")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct ComparableItemRow: View {
    let comparable: ComparableListing
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(comparable.title)
                    .font(.subheadline)
                    .lineLimit(2)
                
                if let soldAt = comparable.soldAt {
                    Text("Sold \(soldAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Currently listed")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Text(comparable.price.displayAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}