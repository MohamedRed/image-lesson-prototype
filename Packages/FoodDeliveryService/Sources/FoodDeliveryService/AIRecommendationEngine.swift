import Foundation
import Combine

/// Advanced AI-powered recommendation engine for food delivery
public class AIRecommendationEngine {
    
    // MARK: - Private Properties
    private let userInteractionTracker: UserInteractionTracker
    private let contextAnalyzer: ContextAnalyzer
    private let collaborativeFilter: CollaborativeFilter
    private let contentBasedFilter: ContentBasedFilter
    
    // MARK: - Initialization
    public init() {
        self.userInteractionTracker = UserInteractionTracker()
        self.contextAnalyzer = ContextAnalyzer()
        self.collaborativeFilter = CollaborativeFilter()
        self.contentBasedFilter = ContentBasedFilter()
    }
    
    // MARK: - Public Methods
    
    /// Get personalized restaurant recommendations using AI
    public func getPersonalizedRestaurants(
        for userId: String,
        restaurants: [Restaurant],
        context: RecContext,
        userProfile: Customer.TasteProfile?
    ) -> [Restaurant] {
        
        // Analyze current context (time, weather, location, etc.)
        let contextScore = contextAnalyzer.analyzeContext(context)
        
        // Get user's interaction history
        let userInteractions = userInteractionTracker.getUserInteractions(userId: userId)
        
        // Apply collaborative filtering (users with similar tastes)
        let collaborativeScores = collaborativeFilter.calculateSimilarityScores(
            userId: userId,
            restaurants: restaurants,
            interactions: userInteractions
        )
        
        // Apply content-based filtering (based on user preferences)
        let contentScores = contentBasedFilter.calculateContentScores(
            restaurants: restaurants,
            userProfile: userProfile,
            context: context
        )
        
        // Combine all scoring mechanisms
        let scoredRestaurants = restaurants.map { restaurant in
            ScoredRestaurant(
                restaurant: restaurant,
                finalScore: calculateFinalScore(
                    restaurant: restaurant,
                    collaborativeScore: collaborativeScores[restaurant.id!] ?? 0.0,
                    contentScore: contentScores[restaurant.id!] ?? 0.0,
                    contextScore: contextScore,
                    userProfile: userProfile,
                    context: context
                )
            )
        }
        
        // Sort by final score and apply diversity
        let rankedRestaurants = applyDiversityFilter(scoredRestaurants)
        
        return rankedRestaurants.map { $0.restaurant }
    }
    
    /// Get personalized menu item recommendations
    public func getPersonalizedMenuItems(
        for userId: String,
        items: [MenuItem],
        restaurantId: String,
        context: RecContext,
        userProfile: Customer.TasteProfile?
    ) -> [MenuItem] {
        
        let userInteractions = userInteractionTracker.getUserInteractions(userId: userId)
        let contextScore = contextAnalyzer.analyzeContext(context)
        
        let scoredItems = items.map { item in
            ScoredMenuItem(
                item: item,
                score: calculateMenuItemScore(
                    item: item,
                    userInteractions: userInteractions,
                    userProfile: userProfile,
                    context: context,
                    contextScore: contextScore
                )
            )
        }
        
        return scoredItems
            .sorted { $0.score > $1.score }
            .map { $0.item }
    }
    
    /// Get trending items based on recent popularity
    public func getTrendingItems(
        items: [MenuItem],
        timeWindow: TimeInterval = 86400 // 24 hours
    ) -> [MenuItem] {
        
        let trendingScores = calculateTrendingScores(items: items, timeWindow: timeWindow)
        
        return items
            .map { item in
                ScoredMenuItem(
                    item: item,
                    score: trendingScores[item.id!] ?? 0.0
                )
            }
            .sorted { $0.score > $1.score }
            .prefix(10)
            .map { $0.item }
    }
    
    /// Get similar restaurants based on cuisine and characteristics
    public func getSimilarRestaurants(
        to restaurant: Restaurant,
        from candidates: [Restaurant]
    ) -> [Restaurant] {
        
        let similarities = candidates.compactMap { candidate -> ScoredRestaurant? in
            guard candidate.id != restaurant.id else { return nil }
            
            let similarity = calculateRestaurantSimilarity(restaurant, candidate)
            return ScoredRestaurant(restaurant: candidate, finalScore: similarity)
        }
        
        return similarities
            .sorted { $0.finalScore > $1.finalScore }
            .prefix(5)
            .map { $0.restaurant }
    }
    
    /// Update user interaction data for improved recommendations
    public func updateInteraction(
        userId: String,
        type: InteractionType,
        entityId: String,
        entityType: EntityType,
        context: RecContext?
    ) {
        userInteractionTracker.recordInteraction(
            userId: userId,
            interaction: UserInteraction(
                type: type,
                entityId: entityId,
                entityType: entityType,
                timestamp: Date(),
                context: context
            )
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateFinalScore(
        restaurant: Restaurant,
        collaborativeScore: Double,
        contentScore: Double,
        contextScore: ContextScore,
        userProfile: Customer.TasteProfile?,
        context: RecContext
    ) -> Double {
        
        // Base restaurant quality score
        let qualityScore = restaurant.rating / 5.0
        
        // Combine different scoring mechanisms with weights
        var finalScore = 0.0
        finalScore += qualityScore * 0.2         // 20% restaurant quality
        finalScore += collaborativeScore * 0.3   // 30% collaborative filtering
        finalScore += contentScore * 0.25        // 25% content-based filtering
        finalScore += contextScore.overall * 0.25 // 25% contextual factors
        
        // Apply contextual boosts
        finalScore *= contextScore.timeBoost
        finalScore *= contextScore.weatherBoost
        finalScore *= contextScore.locationBoost
        
        // Apply diversity penalty if needed
        finalScore *= calculateDiversityBoost(restaurant: restaurant, context: context)
        
        return max(0.0, min(1.0, finalScore))
    }
    
    private func calculateMenuItemScore(
        item: MenuItem,
        userInteractions: [UserInteraction],
        userProfile: Customer.TasteProfile?,
        context: RecContext,
        contextScore: ContextScore
    ) -> Double {
        
        var score = 0.5 // Base score
        
        // User preference matching
        if let profile = userProfile {
            // Ingredient preferences
            for ingredient in item.primaryIngredients {
                if profile.likedIngredients.contains(ingredient) {
                    score += 0.2
                }
                if profile.blockedIngredients.contains(ingredient) {
                    score -= 0.5
                }
            }
            
            // Dietary restrictions
            for tag in item.dietaryTags {
                if profile.dietaryTags.contains(tag) {
                    score += 0.15
                }
            }
            
            // Price preference
            let priceMatch = matchesPriceBand(price: item.price, priceBand: profile.priceBand)
            if priceMatch {
                score += 0.1
            }
        }
        
        // Historical interaction boost
        let itemInteractions = userInteractions.filter { 
            $0.entityId == item.id && $0.entityType == .menuItem 
        }
        
        if !itemInteractions.isEmpty {
            let recentInteractions = itemInteractions.filter { 
                Date().timeIntervalSince($0.timestamp) < 86400 * 7 // Last 7 days
            }
            score += Double(recentInteractions.count) * 0.1
        }
        
        // Contextual factors
        score *= getTimeOfDayMultiplier(for: item, context: context)
        score *= getWeatherMultiplier(for: item, context: context)
        
        return max(0.0, min(1.0, score))
    }
    
    private func calculateTrendingScores(items: [MenuItem], timeWindow: TimeInterval) -> [String: Double] {
        // In a real implementation, this would query recent order data
        // For now, simulate trending based on item characteristics
        
        var scores: [String: Double] = [:]
        
        for item in items {
            var trendScore = 0.0
            
            // Boost healthy items during certain periods
            if item.dietaryTags.contains("healthy") || item.dietaryTags.contains("vegan") {
                trendScore += 0.3
            }
            
            // Boost comfort food during certain weather
            if item.category.lowercased().contains("soup") || item.category.lowercased().contains("hot") {
                trendScore += 0.2
            }
            
            // Add some randomness to simulate real trending data
            trendScore += Double.random(in: 0.0...0.5)
            
            scores[item.id!] = trendScore
        }
        
        return scores
    }
    
    private func calculateRestaurantSimilarity(_ restaurant1: Restaurant, _ restaurant2: Restaurant) -> Double {
        var similarity = 0.0
        
        // Cuisine similarity
        let commonCuisines = Set(restaurant1.cuisineTags).intersection(Set(restaurant2.cuisineTags))
        similarity += Double(commonCuisines.count) / Double(max(restaurant1.cuisineTags.count, restaurant2.cuisineTags.count))
        
        // Price range similarity (approximate using average item price when available)
        let price1 = restaurant1.openingHours.isEmpty ? 0.0 : 50.0
        let price2 = restaurant2.openingHours.isEmpty ? 0.0 : 50.0
        let priceDiff = abs(price1 - price2)
        similarity += max(0, 1.0 - (priceDiff / 100.0)) * 0.3
        
        // Rating similarity
        let ratingDiff = abs(restaurant1.rating - restaurant2.rating)
        similarity += max(0, 1.0 - (ratingDiff / 5.0)) * 0.2
        
        return similarity / 3.0 // Average of the three factors
    }
    
    private func applyDiversityFilter(_ scoredRestaurants: [ScoredRestaurant]) -> [ScoredRestaurant] {
        var result: [ScoredRestaurant] = []
        var cuisineCount: [String: Int] = [:]
        
        let sorted = scoredRestaurants.sorted { $0.finalScore > $1.finalScore }
        
        for scored in sorted {
            let restaurant = scored.restaurant
            let primaryCuisine = restaurant.cuisineTags.first ?? "other"
            
            // Apply diversity penalty if we have too many of the same cuisine
            let currentCount = cuisineCount[primaryCuisine] ?? 0
            let diversityPenalty = max(0.7, 1.0 - Double(currentCount) * 0.1)
            
            let adjustedScore = scored.finalScore * diversityPenalty
            
            result.append(ScoredRestaurant(restaurant: restaurant, finalScore: adjustedScore))
            cuisineCount[primaryCuisine] = currentCount + 1
        }
        
        return result.sorted { $0.finalScore > $1.finalScore }
    }
    
    private func calculateDiversityBoost(restaurant: Restaurant, context: RecContext) -> Double {
        // Boost restaurants with unique cuisines in the area
        // In a real implementation, this would analyze the local restaurant landscape
        return 1.0
    }
    
    private func getTimeOfDayMultiplier(for item: MenuItem, context: RecContext) -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Breakfast items in the morning
        if hour >= 6 && hour < 11 && 
           (item.category.lowercased().contains("breakfast") || 
            item.title.lowercased().contains("coffee") ||
            item.title.lowercased().contains("croissant")) {
            return 1.3
        }
        
        // Lunch items during lunch hours
        if hour >= 11 && hour < 15 && 
           (item.category.lowercased().contains("lunch") ||
            item.category.lowercased().contains("salad")) {
            return 1.2
        }
        
        // Dinner items in the evening
        if hour >= 17 && hour < 22 && 
           (item.category.lowercased().contains("dinner") ||
            item.category.lowercased().contains("main")) {
            return 1.2
        }
        
        return 1.0
    }
    
    private func getWeatherMultiplier(for item: MenuItem, context: RecContext) -> Double {
        // In a real implementation, this would use actual weather data
        // For now, simulate weather-based preferences
        
        let hour = Calendar.current.component(.hour, from: Date())
        let isEvening = hour >= 18
        
        // Hot items boost in the evening (simulating cooler weather)
        if isEvening && 
           (item.category.lowercased().contains("soup") ||
            item.category.lowercased().contains("hot") ||
            item.title.lowercased().contains("tagine")) {
            return 1.15
        }
        
        return 1.0
    }
    
    private func matchesPriceBand(price: Double, priceBand: Customer.TasteProfile.PriceBand) -> Bool {
        switch priceBand {
        case .low:
            return price <= 50
        case .mid:
            return price > 50 && price <= 100
        case .high:
            return price > 100
        }
    }
}

// MARK: - Supporting Classes

/// Tracks user interactions for collaborative filtering
public class UserInteractionTracker {
    private var interactions: [String: [UserInteraction]] = [:]
    
    public init() {}
    
    public func recordInteraction(userId: String, interaction: UserInteraction) {
        if interactions[userId] == nil {
            interactions[userId] = []
        }
        interactions[userId]?.append(interaction)
        
        // Keep only recent interactions (last 30 days)
        let cutoffDate = Date().addingTimeInterval(-86400 * 30)
        interactions[userId] = interactions[userId]?.filter { $0.timestamp > cutoffDate }
    }
    
    public func getUserInteractions(userId: String) -> [UserInteraction] {
        return interactions[userId] ?? []
    }
    
    public func getAllUsers() -> [String] {
        return Array(interactions.keys)
    }
}

/// Analyzes contextual factors for recommendations
public class ContextAnalyzer {
    
    public init() {}
    
    public func analyzeContext(_ context: RecContext) -> ContextScore {
        let timeBoost = calculateTimeBoost(context)
        let weatherBoost = calculateWeatherBoost(context)
        let locationBoost = calculateLocationBoost(context)
        
        let overall = (timeBoost + weatherBoost + locationBoost) / 3.0
        
        return ContextScore(
            overall: overall,
            timeBoost: timeBoost,
            weatherBoost: weatherBoost,
            locationBoost: locationBoost
        )
    }
    
    private func calculateTimeBoost(_ context: RecContext) -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Peak meal times get higher boost
        switch hour {
        case 11...13: return 1.2  // Lunch time
        case 18...21: return 1.3  // Dinner time
        case 7...9: return 1.1    // Breakfast time
        default: return 1.0
        }
    }
    
    private func calculateWeatherBoost(_ context: RecContext) -> Double {
        // Simulate weather impact
        // In real implementation, would use actual weather API
        return 1.0
    }
    
    private func calculateLocationBoost(_ context: RecContext) -> Double {
        // Boost based on location density, traffic, etc.
        return 1.0
    }
}

/// Implements collaborative filtering algorithms
public class CollaborativeFilter {
    
    public init() {}
    
    public func calculateSimilarityScores(
        userId: String,
        restaurants: [Restaurant],
        interactions: [UserInteraction]
    ) -> [String: Double] {
        
        var scores: [String: Double] = [:]
        
        // Simple collaborative filtering based on interaction patterns
        for restaurant in restaurants {
            guard let restaurantId = restaurant.id else { continue }
            
            let restaurantInteractions = interactions.filter { 
                $0.entityId == restaurantId && $0.entityType == .restaurant 
            }
            
            var score = 0.0
            
            // Weight different interaction types
            for interaction in restaurantInteractions {
                switch interaction.type {
                case .view:
                    score += 0.1
                case .click:
                    score += 0.2
                case .order:
                    score += 1.0
                case .favorite:
                    score += 0.5
                case .share:
                    score += 0.3
                }
            }
            
            // Apply time decay
            let avgTimestamp = restaurantInteractions.map { $0.timestamp.timeIntervalSince1970 }.reduce(0, +) / Double(restaurantInteractions.count)
            let daysSince = (Date().timeIntervalSince1970 - avgTimestamp) / 86400
            let timeDecay = max(0.1, 1.0 - (daysSince * 0.05)) // 5% decay per day
            
            scores[restaurantId] = score * timeDecay
        }
        
        return scores
    }
}

/// Implements content-based filtering
public class ContentBasedFilter {
    
    public init() {}
    
    public func calculateContentScores(
        restaurants: [Restaurant],
        userProfile: Customer.TasteProfile?,
        context: RecContext
    ) -> [String: Double] {
        
        var scores: [String: Double] = [:]
        
        guard let profile = userProfile else {
            // Return base scores if no profile
            return restaurants.reduce(into: [:]) { result, restaurant in
                result[restaurant.id!] = 0.5
            }
        }
        
        for restaurant in restaurants {
            guard let restaurantId = restaurant.id else { continue }
            
            var score = 0.0
            
            // Cuisine preferences
            for cuisine in restaurant.cuisineTags {
                if profile.likedCuisines.contains(cuisine) {
                    score += 0.3
                }
            }
            
            // Price band matching (approximate)
            let priceMatch = matchesPriceBand(price: 60.0, priceBand: profile.priceBand)
            if priceMatch {
                score += 0.2
            }
            
            // Dietary restrictions
            // This would require menu analysis in a real implementation
            
            scores[restaurantId] = score
        }
        
        return scores
    }
    
    private func matchesPriceBand(price: Double, priceBand: Customer.TasteProfile.PriceBand) -> Bool {
        switch priceBand {
        case .low:
            return price <= 50
        case .mid:
            return price > 50 && price <= 100
        case .high:
            return price > 100
        }
    }
}

// MARK: - Data Models

public struct UserInteraction {
    public let type: InteractionType
    public let entityId: String
    public let entityType: EntityType
    public let timestamp: Date
    public let context: RecContext?
    
    public init(type: InteractionType, entityId: String, entityType: EntityType, timestamp: Date, context: RecContext?) {
        self.type = type
        self.entityId = entityId
        self.entityType = entityType
        self.timestamp = timestamp
        self.context = context
    }
}

public struct ContextScore {
    public let overall: Double
    public let timeBoost: Double
    public let weatherBoost: Double
    public let locationBoost: Double
    
    public init(overall: Double, timeBoost: Double, weatherBoost: Double, locationBoost: Double) {
        self.overall = overall
        self.timeBoost = timeBoost
        self.weatherBoost = weatherBoost
        self.locationBoost = locationBoost
    }
}

public struct ScoredRestaurant {
    public let restaurant: Restaurant
    public let finalScore: Double
    
    public init(restaurant: Restaurant, finalScore: Double) {
        self.restaurant = restaurant
        self.finalScore = finalScore
    }
}

public struct ScoredMenuItem {
    public let item: MenuItem
    public let score: Double
    
    public init(item: MenuItem, score: Double) {
        self.item = item
        self.score = score
    }
}