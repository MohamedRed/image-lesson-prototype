import * as admin from 'firebase-admin';
import { BigQuery } from '@google-cloud/bigquery';
import {
  RecommendationRequest,
  RecommendationResponse,
  RecommendedProperty,
  AccommodationProperty,
  RecommendationContext,
  UserPreferences,
} from '../models/types';
import { SearchService } from './search-service';
import { logger } from '../../shared/utils/logger';
import { mlRecommendationService, RecommendationContext as MLContext } from './ml-recommendation-service';

const bigquery = new BigQuery();

export class RecommendationService {
  private db: admin.firestore.Firestore;
  private searchService: SearchService;
  
  constructor() {
    this.db = admin.firestore();
    this.searchService = new SearchService();
  }
  
  async getRecommendations(
    userId: string,
    context: RecommendationContext
  ): Promise<RecommendationResponse> {
    try {
      // Get user preferences and history
      const userProfile = await this.getUserProfile(userId);
      const bookingHistory = await this.getUserBookingHistory(userId);
      const searchHistory = await this.getUserSearchHistory(userId);
      
      // Build recommendation query
      const query = this.buildRecommendationQuery(
        userProfile,
        bookingHistory,
        searchHistory,
        context
      );
      
      // Get candidate properties
      const candidates = await this.getCandidateProperties(query, context);
      
      // Use ML recommendations for enhanced scoring
      const mlContext: MLContext = {
        userId,
        searchLocation: context.location ? {
          coordinates: context.location.type === 'coordinates' 
            ? { lat: context.location.lat, lng: context.location.lng }
            : undefined,
          city: context.location.type === 'address' ? context.location.city : undefined,
        } : undefined,
        dateRange: context.dateRange,
        guests: context.guests,
        priceRange: context.priceRange,
        previousSearches: searchHistory,
      };

      const mlRecommendations = await mlRecommendationService.generatePersonalizedRecommendations(
        mlContext,
        candidates,
        50
      );

      // Combine traditional scoring with ML recommendations
      const scoredProperties = await this.combineMLWithTraditionalScoring(
        candidates,
        mlRecommendations,
        userProfile,
        context
      );
      
      // Apply diversity constraints
      const diversifiedProperties = this.applyDiversity(scoredProperties);
      
      // Generate explanations
      const recommendations = diversifiedProperties.map(prop => 
        this.generateExplanation(prop, userProfile, context)
      );
      
      // Log recommendations for future learning
      await this.logRecommendations(userId, recommendations, context);
      
      return {
        recommendations,
        explanations: this.generateGlobalExplanations(recommendations),
      };
    } catch (error) {
      logger.error('Recommendation service error:', error);
      throw error;
    }
  }
  
  private async getUserProfile(userId: string): Promise<UserProfile> {
    try {
      const userDoc = await this.db
        .collection('users')
        .doc(userId)
        .get();
      
      if (!userDoc.exists) {
        return this.getDefaultProfile();
      }
      
      const userData = userDoc.data();
      
      // Get aggregated preferences from BigQuery
      const preferences = await this.getAggregatedPreferences(userId);
      
      return {
        userId,
        preferences: preferences || {},
        demographics: userData?.demographics || {},
        travelStyle: userData?.travelStyle || 'balanced',
        budgetTier: userData?.budgetTier || 'medium',
      };
    } catch (error) {
      logger.error('Failed to get user profile:', error);
      return this.getDefaultProfile();
    }
  }
  
  private async getUserBookingHistory(userId: string): Promise<BookingHistory> {
    try {
      const snapshot = await this.db
        .collection('accommodations_bookings')
        .where('userId', '==', userId)
        .where('status', '==', 'COMPLETED')
        .orderBy('createdAt', 'desc')
        .limit(10)
        .get();
      
      const bookings = snapshot.docs.map(doc => doc.data());
      
      return {
        count: bookings.length,
        averagePrice: this.calculateAveragePrice(bookings),
        favoriteTypes: this.extractFavoriteTypes(bookings),
        favoriteAmenities: this.extractFavoriteAmenities(bookings),
        typicalStayLength: this.calculateTypicalStayLength(bookings),
      };
    } catch (error) {
      logger.error('Failed to get booking history:', error);
      return {
        count: 0,
        averagePrice: 0,
        favoriteTypes: [],
        favoriteAmenities: [],
        typicalStayLength: 2,
      };
    }
  }
  
  private async getUserSearchHistory(userId: string): Promise<SearchHistory> {
    try {
      const query = `
        SELECT 
          location,
          filters,
          COUNT(*) as search_count
        FROM \`${process.env.GCLOUD_PROJECT}.analytics.accommodation_searches\`
        WHERE userId = @userId
          AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
        GROUP BY location, filters
        ORDER BY search_count DESC
        LIMIT 20
      `;
      
      const options = {
        query,
        params: { userId },
      };
      
      const [rows] = await bigquery.query(options);
      
      return {
        recentSearches: rows,
        searchPatterns: this.extractSearchPatterns(rows),
      };
    } catch (error) {
      logger.error('Failed to get search history:', error);
      return {
        recentSearches: [],
        searchPatterns: {},
      };
    }
  }
  
  private buildRecommendationQuery(
    userProfile: UserProfile,
    bookingHistory: BookingHistory,
    searchHistory: SearchHistory,
    context: RecommendationContext
  ): RecommendationQuery {
    return {
      location: context.location,
      dateRange: context.dateRange,
      budget: context.budget || {
        min: bookingHistory.averagePrice * 0.7,
        max: bookingHistory.averagePrice * 1.3,
        currency: 'USD',
      },
      preferences: {
        ...userProfile.preferences,
        ...context.preferences,
      },
      constraints: {
        types: bookingHistory.favoriteTypes.slice(0, 3),
        amenities: bookingHistory.favoriteAmenities.slice(0, 10),
      },
    };
  }
  
  private async getCandidateProperties(
    query: RecommendationQuery,
    context: RecommendationContext
  ): Promise<AccommodationProperty[]> {
    // Use search service to get initial candidates
    const searchRequest = {
      location: query.location || { type: 'coordinates' as const, lat: 0, lng: 0 },
      dateRange: query.dateRange || {
        startDate: new Date(),
        endDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
      guests: {
        rooms: 1,
        adults: 2,
        children: 0,
        childrenAges: [],
      },
      filters: {
        budgetMin: query.budget?.min,
        budgetMax: query.budget?.max,
        types: query.constraints?.types,
        amenities: query.constraints?.amenities,
      },
    };
    
    const searchResults = await this.searchService.search(searchRequest);
    return searchResults.properties;
  }
  
  private async scoreProperties(
    properties: AccommodationProperty[],
    userProfile: UserProfile,
    context: RecommendationContext
  ): Promise<ScoredProperty[]> {
    return properties.map(property => {
      let score = 0;
      const features: Record<string, number> = {};
      
      // Price score (normalized)
      if (context.budget) {
        const priceScore = this.calculatePriceScore(
          property.priceRange?.min || 0,
          context.budget
        );
        score += priceScore * 0.3;
        features.price = priceScore;
      }
      
      // Rating score
      const ratingScore = (property.rating || 0) / 5;
      score += ratingScore * 0.25;
      features.rating = ratingScore;
      
      // Amenity match score
      const amenityScore = this.calculateAmenityScore(
        property.amenities,
        userProfile.preferences?.favoriteAmenities || []
      );
      score += amenityScore * 0.2;
      features.amenities = amenityScore;
      
      // Type preference score
      const typeScore = this.calculateTypeScore(
        property.type,
        userProfile.preferences?.favoriteTypes || []
      );
      score += typeScore * 0.15;
      features.type = typeScore;
      
      // Popularity score
      const popularityScore = Math.min(property.reviewsCount / 100, 1);
      score += popularityScore * 0.1;
      features.popularity = popularityScore;
      
      return {
        property,
        score,
        features,
      };
    }).sort((a, b) => b.score - a.score);
  }
  
  private calculatePriceScore(price: number, budget: any): number {
    const midpoint = (budget.min + budget.max) / 2;
    const range = budget.max - budget.min;
    
    if (price < budget.min || price > budget.max) {
      return 0;
    }
    
    // Prefer prices closer to midpoint
    const distance = Math.abs(price - midpoint);
    return 1 - (distance / (range / 2));
  }
  
  private calculateAmenityScore(
    propertyAmenities: string[],
    preferredAmenities: string[]
  ): number {
    if (preferredAmenities.length === 0) {
      return 0.5; // Neutral score if no preferences
    }
    
    const matches = propertyAmenities.filter(a => 
      preferredAmenities.includes(a)
    ).length;
    
    return matches / preferredAmenities.length;
  }
  
  private calculateTypeScore(
    propertyType: string,
    preferredTypes: string[]
  ): number {
    if (preferredTypes.length === 0) {
      return 0.5; // Neutral score if no preferences
    }
    
    if (preferredTypes.includes(propertyType)) {
      // Higher score for exact match, with preference order
      const index = preferredTypes.indexOf(propertyType);
      return 1 - (index * 0.2);
    }
    
    return 0.2; // Low score for non-preferred types
  }
  
  private async combineMLWithTraditionalScoring(
    properties: AccommodationProperty[],
    mlRecommendations: any[],
    userProfile: any,
    context: RecommendationContext
  ): Promise<any[]> {
    // Create ML score lookup
    const mlScores = new Map();
    mlRecommendations.forEach(rec => {
      mlScores.set(rec.propertyId, rec);
    });

    // Score all properties with combined approach
    return properties.map(property => {
      // Get traditional scores
      const traditionalScored = this.scoreProperties([property], userProfile, context)[0];
      
      // Get ML scores if available
      const mlRec = mlScores.get(property.id);
      const mlScore = mlRec ? mlRec.score : 0.3; // Default neutral score
      const mlReason = mlRec ? mlRec.reason : 'Based on general preferences';
      
      // Combine scores (weighted average)
      const combinedScore = (traditionalScored.score * 0.4) + (mlScore * 0.6);
      
      return {
        property,
        score: combinedScore,
        features: {
          ...traditionalScored.features,
          ml_score: mlScore,
          ml_confidence: mlRec ? mlRec.confidence : 0.3,
        },
        explanation: mlReason,
      };
    }).sort((a, b) => b.score - a.score);
  }
  
  private applyDiversity(
    scoredProperties: any[]
  ): any[] {
    const diversified: ScoredProperty[] = [];
    const typeCount: Record<string, number> = {};
    const priceRanges = new Set<string>();
    
    for (const prop of scoredProperties) {
      const type = prop.property.type;
      const priceRange = this.getPriceRange(prop.property.priceRange?.min || 0);
      
      // Limit same type to 3
      if ((typeCount[type] || 0) >= 3) {
        continue;
      }
      
      // Ensure price diversity
      if (priceRanges.size >= 2 && !priceRanges.has(priceRange)) {
        continue;
      }
      
      diversified.push(prop);
      typeCount[type] = (typeCount[type] || 0) + 1;
      priceRanges.add(priceRange);
      
      if (diversified.length >= 20) {
        break;
      }
    }
    
    return diversified;
  }
  
  private getPriceRange(price: number): string {
    if (price < 100) return 'budget';
    if (price < 200) return 'mid';
    if (price < 500) return 'premium';
    return 'luxury';
  }
  
  private generateExplanation(
    scoredProperty: ScoredProperty,
    userProfile: UserProfile,
    context: RecommendationContext
  ): RecommendedProperty {
    const reasons: string[] = [];
    const features = scoredProperty.features;
    
    // Build explanation based on top features
    if (features.rating > 0.8) {
      reasons.push('Highly rated by guests');
    }
    
    if (features.price > 0.7) {
      reasons.push('Great value for your budget');
    }
    
    if (features.amenities > 0.6) {
      reasons.push('Has amenities you prefer');
    }
    
    if (features.type > 0.8) {
      reasons.push(`Matches your preferred ${scoredProperty.property.type.toLowerCase()}`);
    }
    
    const explanation = reasons.length > 0
      ? reasons.join(' • ')
      : 'Recommended based on your preferences';
    
    return {
      property: scoredProperty.property,
      score: scoredProperty.score,
      explanation,
      matchReasons: reasons,
    };
  }
  
  private generateGlobalExplanations(
    recommendations: RecommendedProperty[]
  ): Record<string, string> {
    return {
      methodology: 'Recommendations are personalized based on your search history, past bookings, and stated preferences',
      diversity: 'We show a mix of property types and price ranges to give you options',
      freshness: 'Availability and prices are updated in real-time',
    };
  }
  
  private async logRecommendations(
    userId: string,
    recommendations: RecommendedProperty[],
    context: RecommendationContext
  ): Promise<void> {
    const timestamp = new Date();
    
    const logEntry = {
      userId,
      timestamp,
      context,
      recommendations: recommendations.map(r => ({
        propertyId: r.property.id,
        score: r.score,
        explanation: r.explanation,
      })),
    };
    
    await this.db
      .collection('accommodations_recommendations')
      .doc(userId)
      .collection('items')
      .add(logEntry);
  }
  
  private async getAggregatedPreferences(userId: string): Promise<UserPreferences> {
    // Aggregate preferences from BigQuery
    // This is a placeholder implementation
    return {
      favoriteTypes: [],
      favoriteAmenities: ['WiFi', 'Parking', 'Air conditioning'],
      favoriteBrands: [],
      accessibilityNeeds: [],
    };
  }
  
  private getDefaultProfile(): UserProfile {
    return {
      userId: '',
      preferences: {},
      demographics: {},
      travelStyle: 'balanced',
      budgetTier: 'medium',
    };
  }
  
  private calculateAveragePrice(bookings: any[]): number {
    if (bookings.length === 0) return 150; // Default
    
    const total = bookings.reduce((sum, b) => 
      sum + (b.priceSnapshot?.totalPrice || 0), 0
    );
    
    return total / bookings.length;
  }
  
  private extractFavoriteTypes(bookings: any[]): string[] {
    const typeCounts: Record<string, number> = {};
    
    bookings.forEach(b => {
      const type = b.propertyRef?.type;
      if (type) {
        typeCounts[type] = (typeCounts[type] || 0) + 1;
      }
    });
    
    return Object.entries(typeCounts)
      .sort((a, b) => b[1] - a[1])
      .map(([type]) => type);
  }
  
  private extractFavoriteAmenities(bookings: any[]): string[] {
    const amenityCounts: Record<string, number> = {};
    
    bookings.forEach(b => {
      const amenities = b.propertyRef?.amenities || [];
      amenities.forEach((amenity: string) => {
        amenityCounts[amenity] = (amenityCounts[amenity] || 0) + 1;
      });
    });
    
    return Object.entries(amenityCounts)
      .sort((a, b) => b[1] - a[1])
      .map(([amenity]) => amenity);
  }
  
  private calculateTypicalStayLength(bookings: any[]): number {
    if (bookings.length === 0) return 2; // Default
    
    const lengths = bookings.map(b => {
      const start = new Date(b.dateRange?.startDate);
      const end = new Date(b.dateRange?.endDate);
      return Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
    });
    
    return Math.round(lengths.reduce((a, b) => a + b, 0) / lengths.length);
  }
  
  private extractSearchPatterns(searches: any[]): Record<string, any> {
    // Extract patterns from search history
    return {
      preferredLocations: searches.slice(0, 5).map(s => s.location),
      commonFilters: searches[0]?.filters || {},
    };
  }
}

// Type definitions for internal use
interface UserProfile {
  userId: string;
  preferences: UserPreferences;
  demographics: Record<string, any>;
  travelStyle: string;
  budgetTier: string;
}

interface BookingHistory {
  count: number;
  averagePrice: number;
  favoriteTypes: string[];
  favoriteAmenities: string[];
  typicalStayLength: number;
}

interface SearchHistory {
  recentSearches: any[];
  searchPatterns: Record<string, any>;
}

interface RecommendationQuery {
  location?: any;
  dateRange?: any;
  budget?: any;
  preferences?: UserPreferences;
  constraints?: {
    types?: string[];
    amenities?: string[];
  };
}

interface ScoredProperty {
  property: AccommodationProperty;
  score: number;
  features: Record<string, number>;
}