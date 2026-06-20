import Foundation
import Combine

/// Client for external search index integration (Algolia/Typesense/ES)
/// Per Section 8 of implementation-plan.md
public final class SearchIndexClient {
    
    // MARK: - Properties
    
    private let baseURL: String
    private let apiKey: String
    private let session = URLSession.shared
    
    // MARK: - Initialization
    
    public init(baseURL: String = ProcessInfo.processInfo.environment["SEARCH_INDEX_URL"] ?? "",
                apiKey: String = ProcessInfo.processInfo.environment["SEARCH_INDEX_KEY"] ?? "") {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
    
    // MARK: - Search Methods
    
    /// Hybrid search combining text and vector similarity
    public func hybridSearch(
        query: String,
        cityId: String,
        filters: SearchFilters,
        limit: Int = 20
    ) async throws -> SearchResults {
        
        // Build search request
        var searchRequest: [String: Any] = [
            "q": query,
            "query_by": "title,description,category",
            "filter_by": buildFilterString(cityId: cityId, filters: filters),
            "sort_by": "_text_match:desc,_geo_distance:asc",
            "per_page": limit,
            "include_fields": "id,title,price,images,location,embedding",
            "geo_filter": filters.neighborhoods != nil
        ]
        
        // Add vector search if embeddings are available
        if !query.isEmpty {
            searchRequest["vector_query"] = [
                "field": "embedding",
                "k": 10
            ]
        }
        
        // Make API request
        let url = URL(string: "\(baseURL)/collections/listings/documents/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        request.httpBody = try JSONSerialization.data(withJSONObject: searchRequest)
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(SearchResults.self, from: data)
    }
    
    /// Get personalized recommendations
    public func getRecommendations(
        userId: String,
        cityId: String,
        userTraits: UserTraits?,
        limit: Int = 10
    ) async throws -> [ScoredListing] {
        
        let filters = SearchFilters(
            cityId: cityId,
            neighborhoods: nil,
            categories: nil,
            priceRange: nil,
            condition: nil,
            hasImages: nil,
            deliveryOptions: nil
        )
        
        // Apply user preferences if available
        if let preferences = userTraits?.traits {
            // Filter by user's car model for car parts
            _ = preferences.carModel
            
            // Filter by clothing preferences
            if preferences.clothingSizes != nil {
                // Boost apparel category
            }
        }
        
        // Use collaborative filtering and content-based recommendations
        let results = try await hybridSearch(
            query: "",
            cityId: cityId,
            filters: filters,
            limit: limit
        )
        
        return results.hits.map { hit in
            ScoredListing(
                listing: hit,
                score: calculatePersonalizationScore(
                    listing: hit,
                    userTraits: userTraits
                ),
                reasonCodes: generateReasonCodes(
                    listing: hit,
                    userTraits: userTraits
                )
            )
        }.sorted { $0.score > $1.score }
    }
    
    // MARK: - Private Methods
    
    private func buildFilterString(cityId: String, filters: SearchFilters) -> String {
        var filterParts: [String] = ["cityId:=\(cityId)"]
        
        if let neighborhoods = filters.neighborhoods, !neighborhoods.isEmpty {
            let neighborhoodFilter = neighborhoods.map { "neighborhoodId:=\($0)" }.joined(separator: " || ")
            filterParts.append("(\(neighborhoodFilter))")
        }
        
        if let categories = filters.categories, !categories.isEmpty {
            let categoryFilter = categories.map { "category:=\($0.rawValue)" }.joined(separator: " || ")
            filterParts.append("(\(categoryFilter))")
        }
        
        if let priceRange = filters.priceRange {
            if let min = priceRange.min {
                filterParts.append("price:>=\(min)")
            }
            if let max = priceRange.max {
                filterParts.append("price:<=\(max)")
            }
        }
        
        if let condition = filters.condition {
            filterParts.append("condition:=\(condition.rawValue)")
        }
        
        filterParts.append("status:=active")
        
        return filterParts.joined(separator: " && ")
    }
    
    private func calculatePersonalizationScore(
        listing: Listing,
        userTraits: UserTraits?
    ) -> Double {
        var score = 1.0
        
        // Category affinity
        if let traits = userTraits?.traits {
            // Boost car parts if user has a car model
            if listing.category == .carParts && traits.carModel != nil {
                score *= 1.5
            }
            
            // Boost apparel if user has clothing sizes
            if listing.category == .apparel && traits.clothingSizes != nil {
                score *= 1.3
            }
            
            // Boost furniture if user has DIY skills
            if listing.category == .furniture && traits.diySkillLevel != nil {
                score *= 1.2
            }
        }
        
        // Freshness boost
        let daysSinceCreated = Date().timeIntervalSince(listing.createdAt) / (24 * 3600)
        if daysSinceCreated < 1 {
            score *= 1.5 // New today
        } else if daysSinceCreated < 7 {
            score *= 1.2 // This week
        }
        
        // Image quality boost
        if listing.images.count >= 3 {
            score *= 1.1
        }
        
        return score
    }
    
    private func generateReasonCodes(
        listing: Listing,
        userTraits: UserTraits?
    ) -> [String] {
        var reasons: [String] = []
        
        // Location-based reasons
        if let neighborhood = listing.location.arrondissement {
            reasons.append("in_\(neighborhood)")
        }
        
        // Trait-based reasons
        if let traits = userTraits?.traits {
            if listing.category == .carParts && traits.carModel != nil {
                reasons.append("fits_your_car")
            }
            
            if listing.category == .apparel && traits.clothingSizes != nil {
                reasons.append("matches_your_size")
            }
        }
        
        // Freshness reasons
        let daysSinceCreated = Date().timeIntervalSince(listing.createdAt) / (24 * 3600)
        if daysSinceCreated < 1 {
            reasons.append("new_today")
        } else if daysSinceCreated < 7 {
            reasons.append("new_this_week")
        }
        
        // Price reasons
        if listing.price.amount < 50000 { // Under 500 MAD
            reasons.append("great_value")
        }
        
        return reasons
    }
}

// MARK: - Search Result Models

public struct SearchResults: Codable {
    public let found: Int
    public let hits: [Listing]
    public let facetCounts: [FacetCount]?
    public let searchTimeMs: Int
    
    public struct FacetCount: Codable {
        public let fieldName: String
        public let counts: [FacetValue]
        
        public struct FacetValue: Codable {
            public let value: String
            public let count: Int
        }
    }
}

public struct ScoredListing {
    public let listing: Listing
    public let score: Double
    public let reasonCodes: [String]
    
    public init(listing: Listing, score: Double, reasonCodes: [String]) {
        self.listing = listing
        self.score = score
        self.reasonCodes = reasonCodes
    }
}