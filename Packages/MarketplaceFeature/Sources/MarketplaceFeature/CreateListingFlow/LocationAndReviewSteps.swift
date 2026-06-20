import SwiftUI
import MarketplaceService

// MARK: - Location Step

struct LocationStep: View {
    let cityId: String
    @Binding var neighborhood: String
    @Binding var addressLine: String
    @Binding var enableMeetup: Bool
    @Binding var enableCourier: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Location & Delivery")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Neighborhood selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Neighborhood")
                        .font(.headline)
                    
                    Picker("Neighborhood", selection: $neighborhood) {
                        Text("Select neighborhood").tag("")
                        ForEach(neighborhoods, id: \.self) { hood in
                            Text(hood).tag(hood)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Optional address
                VStack(alignment: .leading, spacing: 12) {
                    Text("Address (Optional)")
                        .font(.headline)
                    Text("This helps buyers understand the exact location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Street address", text: $addressLine)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Divider()
                
                // Delivery options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Delivery Options")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        DeliveryOptionCard(
                            icon: "figure.walk",
                            title: "Meet-up",
                            description: "Meet the buyer at a safe public location",
                            isEnabled: $enableMeetup,
                            benefits: ["Free", "Immediate exchange", "Safe locations suggested"]
                        )
                        
                        DeliveryOptionCard(
                            icon: "car",
                            title: "Courier Delivery",
                            description: "Professional delivery via our ride-sharing network",
                            isEnabled: $enableCourier,
                            benefits: ["Door-to-door", "Insured", "Real-time tracking"],
                            comingSoon: true
                        )
                    }
                }
                
                // Safety tips
                if enableMeetup {
                    SafetyTipsCard()
                }
            }
            .padding()
        }
    }
    
    private var neighborhoods: [String] {
        switch cityId {
        case "casablanca":
            return ["Maarif", "Gauthier", "Racine", "Bourgogne", "Ain Diab", "Anfa", "Sidi Belyout", "Hay Hassani", "Ain Sebaa", "Sidi Bernoussi"]
        case "rabat":
            return ["Agdal", "Hassan", "Hay Riad", "Souissi", "Temara", "Salé"]
        default:
            return []
        }
    }
}

struct DeliveryOptionCard: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    let benefits: [String]
    let comingSoon: Bool
    
    init(icon: String, title: String, description: String, isEnabled: Binding<Bool>, benefits: [String], comingSoon: Bool = false) {
        self.icon = icon
        self.title = title
        self.description = description
        self._isEnabled = isEnabled
        self.benefits = benefits
        self.comingSoon = comingSoon
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle(isOn: $isEnabled) {
                    HStack {
                        Image(systemName: icon)
                            .foregroundColor(isEnabled ? .blue : .gray)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if comingSoon {
                                    Text("Soon")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(comingSoon)
            }
            
            if isEnabled && !comingSoon {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(benefit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SafetyTipsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Safety Tips for Meet-ups", systemImage: "shield.checkered")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                SafetyTip(icon: "mappin.and.ellipse", text: "Meet in busy, public places like malls or cafes")
                SafetyTip(icon: "sun.max", text: "Choose daytime meetings when possible")
                SafetyTip(icon: "person.2", text: "Bring a friend if you feel more comfortable")
                SafetyTip(icon: "creditcard", text: "Count cash carefully and check for counterfeit bills")
                SafetyTip(icon: "checkmark.shield", text: "Trust your instincts - cancel if something feels wrong")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SafetyTip: View {
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

// MARK: - Review Step

struct ReviewStep: View {
    let photos: [UIImage]
    let title: String
    let description: String
    let category: ListingCategory
    let condition: ItemCondition
    let price: String
    let currency: String
    let neighborhood: String
    let enableMeetup: Bool
    let enableCourier: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Review Your Listing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Preview card
                ListingPreviewCard(
                    photos: photos,
                    title: title,
                    description: description,
                    category: category,
                    condition: condition,
                    price: price,
                    currency: currency,
                    neighborhood: neighborhood,
                    enableMeetup: enableMeetup,
                    enableCourier: enableCourier
                )
                
                // Publishing guidelines
                PublishingGuidelinesCard()
                
                // Expected outcomes
                ExpectedOutcomesCard(category: category, condition: condition, price: price)
            }
            .padding()
        }
    }
}

struct ListingPreviewCard: View {
    let photos: [UIImage]
    let title: String
    let description: String
    let category: ListingCategory
    let condition: ItemCondition
    let price: String
    let currency: String
    let neighborhood: String
    let enableMeetup: Bool
    let enableCourier: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                // Main image
                if let firstPhoto = photos.first {
                    Image(uiImage: firstPhoto)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                        .overlay(
                            HStack {
                                Spacer()
                                VStack {
                                    Text("\(photos.count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("photos")
                                        .font(.caption2)
                                }
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .padding()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        )
                }
                
                // Price
                Text("\(currency) \(price)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                // Title
                Text(title)
                    .font(.headline)
                
                // Category and condition
                HStack {
                    Text(category.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    
                    Text(condition.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(conditionColor.opacity(0.2))
                        .foregroundColor(conditionColor)
                        .cornerRadius(6)
                }
                
                // Location
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(neighborhood)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Description preview
                Text(description)
                    .font(.subheadline)
                    .lineLimit(3)
                    .foregroundColor(.secondary)
                
                // Delivery options
                HStack {
                    if enableMeetup {
                        Label("Meet-up", systemImage: "figure.walk")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if enableCourier {
                        Label("Courier", systemImage: "car")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var conditionColor: Color {
        switch condition {
        case .new: return .green
        case .likeNew: return .blue
        case .good: return .orange
        case .fair: return .red
        }
    }
}

struct PublishingGuidelinesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Publishing Guidelines", systemImage: "checkmark.shield")
                .font(.headline)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 8) {
                PublishingGuidelineItem(icon: "photo", text: "High-quality photos increase views by 40%")
                PublishingGuidelineItem(icon: "text.alignleft", text: "Detailed descriptions help buyers make decisions")
                PublishingGuidelineItem(icon: "tag", text: "Fair pricing based on condition and market value")
                PublishingGuidelineItem(icon: "person.2", text: "Respond to messages within 24 hours")
                PublishingGuidelineItem(icon: "clock", text: "Items typically sell within 7-14 days")
            }
            
            Text("By publishing, you agree to our Community Guidelines and Terms of Service.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

struct PublishingGuidelineItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ExpectedOutcomesCard: View {
    let category: ListingCategory
    let condition: ItemCondition
    let price: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Expected Outcomes", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                OutcomeMetric(
                    label: "Expected views in first week",
                    value: expectedViews,
                    icon: "eye"
                )
                
                OutcomeMetric(
                    label: "Average time to first message",
                    value: expectedTimeToMessage,
                    icon: "bubble.left"
                )
                
                OutcomeMetric(
                    label: "Estimated time to sale",
                    value: expectedTimeToSale,
                    icon: "clock"
                )
                
                OutcomeMetric(
                    label: "Price competitiveness",
                    value: priceCompetitiveness,
                    icon: "tag",
                    color: priceCompetitivenessColor
                )
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var expectedViews: String {
        // Simplified algorithm based on category popularity
        switch category {
        case .electronics, .apparel: return "25-40 views"
        case .furniture, .carParts: return "15-30 views"
        default: return "10-25 views"
        }
    }
    
    private var expectedTimeToMessage: String {
        switch condition {
        case .new, .likeNew: return "2-3 days"
        case .good: return "3-5 days"
        case .fair: return "5-7 days"
        }
    }
    
    private var expectedTimeToSale: String {
        guard let priceValue = Double(price) else { return "7-14 days" }
        
        // Simplified pricing analysis
        if priceValue < 500 {
            return "3-7 days"
        } else if priceValue < 2000 {
            return "7-14 days"
        } else {
            return "14-30 days"
        }
    }
    
    private var priceCompetitiveness: String {
        guard let priceValue = Double(price) else { return "Fair" }
        
        // Simplified competitive analysis
        switch category {
        case .electronics:
            return priceValue < 1000 ? "Very Competitive" : "Premium"
        case .apparel:
            return priceValue < 300 ? "Competitive" : "Premium"
        default:
            return "Fair"
        }
    }
    
    private var priceCompetitivenessColor: Color {
        switch priceCompetitiveness {
        case "Very Competitive": return .green
        case "Competitive": return .blue
        case "Fair": return .orange
        case "Premium": return .red
        default: return .gray
        }
    }
}

struct OutcomeMetric: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    init(label: String, value: String, icon: String, color: Color = .blue) {
        self.label = label
        self.value = value
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            Spacer()
        }
    }
}