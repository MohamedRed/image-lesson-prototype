import Foundation

/// Mock implementation of MarketplaceAI for testing and development
public final class MockMarketplaceAI: MarketplaceAI {
    
    public init() {}
    
    // MARK: - AI Assistant
    
    public func answer(_ query: String, context: RecContext) async throws -> AIResponse {
        // Simulate AI processing time
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        let response = generateAIResponse(for: query, context: context)
        
        return AIResponse(
            answer: response.answer,
            confidence: response.confidence,
            sources: response.sources,
            followUpSuggestions: response.followUpSuggestions,
            actionButtons: response.actionButtons
        )
    }
    
    // MARK: - Watchers/Alerts
    
    public func createWatcher(criteria: AlertCriteria) async throws -> Alert {
        // Simulate processing
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        let query = criteria.query
        return Alert(
            id: UUID().uuidString,
            userId: "current_user",
            queryDSL: query,
            cityId: criteria.cityId,
            neighborhoods: criteria.neighborhoods,
            priceRange: criteria.priceRange,
            categories: criteria.categories.map { $0.rawValue },
            createdAt: Date(),
            isActive: true
        )
    }
    
    // MARK: - Negotiation Assistance
    
    public func suggestNegotiation(listingId: String, targetPrice: Money?) async throws -> NegotiationSuggestion {
        // Simulate AI analysis
        try await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 seconds
        
        guard let targetPrice = targetPrice else {
            throw AIError.invalidInput("Target price is required")
        }
        
        // Generate realistic negotiation suggestion
        let suggestedAmount = Int(Double(targetPrice.amount) * Double.random(in: 0.85...0.95))
        
        return NegotiationSuggestion(
            suggestedPrice: Money(amount: suggestedAmount, currency: targetPrice.currency),
            reasoning: generateNegotiationReasoning(targetPrice: targetPrice),
            comparables: ["listing_1", "listing_3", "listing_7"],
            draftMessage: generateNegotiationMessage(suggestedAmount: suggestedAmount, currency: targetPrice.currency)
        )
    }
    
    // MARK: - Try Lab Plugins
    
    public func invokePlugin(category: String, action: String, input: PluginInput) async throws -> PluginOutput {
        // Simulate plugin processing
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        switch category {
        case "apparel":
            return try await processApparelPlugin(action: action, input: input)
        case "automotive":
            return try await processAutomotivePlugin(action: action, input: input)
        case "furniture":
            return try await processFurniturePlugin(action: action, input: input)
        default:
            throw AIError.unsupportedPlugin("Plugin not available for category: \(category)")
        }
    }
}

// MARK: - AI Response Generation

private extension MockMarketplaceAI {
    
    func generateAIResponse(for query: String, context: RecContext) -> (answer: String, confidence: Double, sources: [String], followUpSuggestions: [String], actionButtons: [AIActionButton]) {
        let lowercaseQuery = query.lowercased()
        
        // Detect query intent and generate appropriate response
        if lowercaseQuery.contains("price") || lowercaseQuery.contains("cost") || lowercaseQuery.contains("expensive") {
            return generatePriceResponse(query: query, context: context)
        } else if lowercaseQuery.contains("quality") || lowercaseQuery.contains("condition") {
            return generateQualityResponse(query: query)
        } else if lowercaseQuery.contains("meet") || lowercaseQuery.contains("pickup") || lowercaseQuery.contains("delivery") {
            return generateDeliveryResponse(query: query)
        } else if lowercaseQuery.contains("negotiate") || lowercaseQuery.contains("offer") {
            return generateNegotiationResponse(query: query)
        } else if lowercaseQuery.contains("similar") || lowercaseQuery.contains("alternative") {
            return generateSimilarItemsResponse(query: query)
        } else {
            return generateGeneralResponse(query: query)
        }
    }
    
    func generatePriceResponse(query: String, context: RecContext) -> (String, Double, [String], [String], [AIActionButton]) {
        let responses = [
            "Based on similar items in Casablanca, this price is competitive. I found 3 comparable listings ranging from 380-520 MAD.",
            "This item is priced 15% below the average for this category in your area. It's a good deal!",
            "The asking price seems fair based on the condition and local market rates. You could try negotiating 10-15% lower."
        ]
        
        let actionButtons = [
            AIActionButton(title: "See Similar Items", action: "search_similar"),
            AIActionButton(title: "Price History", action: "view_price_trends"),
            AIActionButton(title: "Make Offer", action: "create_offer")
        ]
        
        return (
            responses.randomElement()!,
            Double.random(in: 0.85...0.95),
            ["marketplace_analysis", "price_comparison"],
            ["What's a reasonable offer?", "Show me similar items", "Is this a good deal?"],
            actionButtons
        )
    }
    
    func generateQualityResponse(query: String) -> (String, Double, [String], [String], [AIActionButton]) {
        let responses = [
            "Based on the photos and description, this item appears to be in good condition. Look for any wear signs in the detailed photos.",
            "The seller has marked this as 'excellent condition' and has a 4.8 star rating. Photos show minimal wear.",
            "This item looks well-maintained. I'd recommend asking about any warranty or return policy before purchasing."
        ]
        
        return (
            responses.randomElement()!,
            Double.random(in: 0.8...0.9),
            ["image_analysis", "seller_rating"],
            ["What should I check when viewing?", "Any red flags to watch for?"],
            []
        )
    }
    
    func generateDeliveryResponse(query: String) -> (String, Double, [String], [String], [AIActionButton]) {
        let responses = [
            "The seller offers meetup in Maarif area. I can help you find a safe public location for the exchange.",
            "Both meetup and courier delivery are available. Meetup is recommended for valuable items like this.",
            "The seller is located in Gautier. I suggest meeting at City Center or a nearby café for safety."
        ]
        
        let actionButtons = [
            AIActionButton(title: "Find Safe Meetup Spot", action: "suggest_meetup_location"),
            AIActionButton(title: "Schedule Meetup", action: "create_reservation")
        ]
        
        return (
            responses.randomElement()!,
            Double.random(in: 0.9...0.95),
            ["location_analysis", "safety_guidelines"],
            ["What are safe meetup locations?", "How does courier delivery work?"],
            actionButtons
        )
    }
    
    func generateNegotiationResponse(query: String) -> (String, Double, [String], [String], [AIActionButton]) {
        let responses = [
            "Based on the item's age and condition, you could reasonably offer 10-15% below asking price. Would you like me to draft a polite message?",
            "The seller seems motivated - the listing has been up for 5 days. You have good negotiation leverage.",
            "Similar items have sold for 15-20% less than this asking price. I can help you craft a competitive offer."
        ]
        
        let actionButtons = [
            AIActionButton(title: "Draft Offer Message", action: "draft_negotiation"),
            AIActionButton(title: "Suggest Offer Price", action: "suggest_price")
        ]
        
        return (
            responses.randomElement()!,
            Double.random(in: 0.85...0.92),
            ["negotiation_analysis", "market_trends"],
            ["What's a fair offer?", "How should I phrase my message?"],
            actionButtons
        )
    }
    
    func generateSimilarItemsResponse(query: String) -> (String, Double, [String], [String], [AIActionButton]) {
        let responses = [
            "I found 7 similar items in Casablanca. 3 are priced lower, 2 are comparable, and 2 are higher. Would you like to see them?",
            "There are several alternatives available. One in Anfa is 20% cheaper but in 'good' condition instead of 'excellent'.",
            "Based on your search history, you might also like these 4 similar items I found in your area."
        ]
        
        let actionButtons = [
            AIActionButton(title: "Show Similar Items", action: "search_similar"),
            AIActionButton(title: "Compare Prices", action: "price_comparison")
        ]
        
        return (
            responses.randomElement()!,
            Double.random(in: 0.88...0.94),
            ["similarity_matching", "search_results"],
            ["Show me alternatives", "What makes this one different?"],
            actionButtons
        )
    }
    
    func generateGeneralResponse(query: String) -> (String, Double, [String], [String], [AIActionButton]) {
        let responses = [
            "I'm here to help with your marketplace questions! You can ask me about prices, quality, negotiations, or finding similar items.",
            "That's an interesting question! Let me help you make an informed decision about this item.",
            "I can assist with various aspects of your purchase - from price analysis to scheduling meetups safely."
        ]
        
        return (
            responses.randomElement()!,
            Double.random(in: 0.7...0.85),
            ["general_knowledge"],
            ["What should I know about this item?", "Is this a good deal?", "Help me negotiate"],
            []
        )
    }
    
    func generateNegotiationReasoning(targetPrice: Money) -> String {
        let reasonings = [
            "Based on similar items sold in the past 30 days, your target price is within the typical negotiation range. The item's condition and seller's rating support this valuation.",
            "Market analysis shows comparable items selling 10-20% below initial asking prices. Your target aligns with recent transaction patterns in Casablanca.",
            "The seller has been active for 6 months with good reviews. Given the item's age and local competition, your price point is reasonable for negotiation."
        ]
        
        return reasonings.randomElement()!
    }
    
    func generateNegotiationMessage(suggestedAmount: Int, currency: String) -> String {
        let amount = suggestedAmount / 100
        
        let messages = [
            "Hi! I'm very interested in this item. I've been looking for exactly this for a while. Would you consider \(amount) \(currency)? I can meet this week at your convenience. Thank you!",
            "Hello! Great listing - the item looks perfect for what I need. Based on my research of similar items, would \(amount) \(currency) work for you? Happy to arrange a quick meetup. Thanks!",
            "Hi there! I'm a serious buyer and can meet soon. The item looks great in the photos. Would you be open to \(amount) \(currency)? I understand if that's too low, but thought I'd ask. Best regards!"
        ]
        
        return messages.randomElement()!
    }
}

// MARK: - Plugin Processing

private extension MockMarketplaceAI {
    
    func processApparelPlugin(action: String, input: PluginInput) async throws -> PluginOutput {
        switch action {
        case "try_on":
            let fitAnalysis = [
                "shoulder_fit": "good",
                "chest_fit": "excellent",
                "length": "perfect",
                "overall_rating": "85"
            ]
            let fitJson = (try? String(data: JSONSerialization.data(withJSONObject: fitAnalysis), encoding: .utf8)) ?? "{}"
            return PluginOutput(
                success: true,
                result: [
                    "preview_url": "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400",
                    "fit_analysis": fitJson,
                    "size_recommendation": "This item fits true to size based on your measurements"
                ],
                error: nil
            )
            
        case "size_check":
            let alts = ["S for fitted look", "L for relaxed fit"]
            let altsJson = (try? String(data: JSONSerialization.data(withJSONObject: alts), encoding: .utf8)) ?? "[]"
            return PluginOutput(
                success: true,
                result: [
                    "recommended_size": "M",
                    "confidence": "0.92",
                    "size_analysis": "Based on your body measurements, size M should fit comfortably",
                    "alternatives": altsJson
                ],
                error: nil
            )
            
        default:
            throw AIError.unsupportedAction("Action '\(action)' not supported for apparel plugin")
        }
    }
    
    func processAutomotivePlugin(action: String, input: PluginInput) async throws -> PluginOutput {
        switch action {
        case "compatibility_check":
            let tools = ["Phillips screwdriver", "Socket wrench set"]
            let toolsJson = (try? String(data: JSONSerialization.data(withJSONObject: tools), encoding: .utf8)) ?? "[]"
            return PluginOutput(
                success: true,
                result: [
                    "compatible": "true",
                    "confidence": "0.96",
                    "vehicle_match": "Perfect fit for your 2019 Toyota Camry",
                    "installation_difficulty": "Easy - 15 minutes",
                    "tools_required": toolsJson,
                    "warnings": "[]"
                ],
                error: nil
            )
            
        case "installation_guide":
            let steps = [
                "Disconnect battery negative terminal",
                "Remove old part using socket wrench",
                "Clean mounting surface",
                "Install new part with provided bolts",
                "Reconnect battery and test"
            ]
            let stepsJson = (try? String(data: JSONSerialization.data(withJSONObject: steps), encoding: .utf8)) ?? "[]"
            return PluginOutput(
                success: true,
                result: [
                    "steps": stepsJson,
                    "estimated_time": "15-20 minutes",
                    "difficulty": "Beginner",
                    "video_tutorial": "https://youtube.com/watch?v=example"
                ],
                error: nil
            )
            
        default:
            throw AIError.unsupportedAction("Action '\(action)' not supported for automotive plugin")
        }
    }
    
    func processFurniturePlugin(action: String, input: PluginInput) async throws -> PluginOutput {
        switch action {
        case "room_visualization":
            let suggestions = [
                "Add a throw pillow in accent color",
                "Consider a side table to complete the look"
            ]
            let suggestionsJson = (try? String(data: JSONSerialization.data(withJSONObject: suggestions), encoding: .utf8)) ?? "[]"
            return PluginOutput(
                success: true,
                result: [
                    "room_fit": "excellent",
                    "style_match": "92",
                    "space_utilization": "Optimal placement near the window",
                    "color_harmony": "Complements your existing decor",
                    "suggestions": suggestionsJson,
                    "visual_preview": "https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400"
                ],
                error: nil
            )
            
        case "dimension_check":
            return PluginOutput(
                success: true,
                result: [
                    "fits_space": "true",
                    "clearance": "60cm on all sides - perfect!",
                    "door_clearance": "Will fit through your doorway",
                    "assembly_required": "false",
                    "delivery_considerations": "Standard delivery truck access needed"
                ],
                error: nil
            )
            
        default:
            throw AIError.unsupportedAction("Action '\(action)' not supported for furniture plugin")
        }
    }
}

// MARK: - Mock AI Errors

public enum AIError: Error, LocalizedError {
    case invalidInput(String)
    case unsupportedPlugin(String)
    case unsupportedAction(String)
    case processingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .unsupportedPlugin(let message):
            return "Unsupported plugin: \(message)"
        case .unsupportedAction(let message):
            return "Unsupported action: \(message)"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        }
    }
}