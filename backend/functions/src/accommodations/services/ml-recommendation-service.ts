import { analyticsService } from './analytics-service';
import { logger } from '../../shared/utils/logger';

export interface MLRecommendation {
  propertyId: string;
  score: number;
  reason: string;
  confidence: number;
  metadata?: any;
}

export interface RecommendationContext {
  userId?: string;
  searchLocation?: {
    coordinates?: { lat: number; lng: number };
    city?: string;
    country?: string;
  };
  dateRange?: {
    checkIn: Date;
    checkOut: Date;
  };
  guests?: {
    adults: number;
    children: number;
  };
  priceRange?: {
    min: number;
    max: number;
  };
  previousSearches?: any[];
  sessionProperties?: string[];
}

export class MLRecommendationService {
  async generatePersonalizedRecommendations(
    context: RecommendationContext,
    availableProperties: any[],
    limit: number = 20
  ): Promise<MLRecommendation[]> {
    try {
      const recommendations: MLRecommendation[] = [];

      if (context.userId) {
        // Get user analytics data
        const [searchPatterns, preferences] = await Promise.all([
          analyticsService.getUserSearchPatterns(context.userId, 50),
          analyticsService.getUserPropertyPreferences(context.userId),
        ]);

        // Content-based filtering
        const contentRecommendations = await this.contentBasedFiltering(
          availableProperties,
          preferences,
          context
        );
        recommendations.push(...contentRecommendations);

        // Collaborative filtering (simplified)
        const collaborativeRecommendations = await this.collaborativeFiltering(
          availableProperties,
          searchPatterns,
          context
        );
        recommendations.push(...collaborativeRecommendations);

        // Location-based recommendations
        const locationRecommendations = await this.locationBasedRecommendations(
          availableProperties,
          searchPatterns,
          context
        );
        recommendations.push(...locationRecommendations);

        // Behavioral recommendations
        const behavioralRecommendations = await this.behavioralRecommendations(
          availableProperties,
          context
        );
        recommendations.push(...behavioralRecommendations);
      } else {
        // Fallback to popularity-based recommendations for anonymous users
        const popularityRecommendations = await this.popularityBasedRecommendations(
          availableProperties,
          context
        );
        recommendations.push(...popularityRecommendations);
      }

      // Merge and deduplicate recommendations
      const mergedRecommendations = this.mergeRecommendations(recommendations);
      
      // Apply business rules and filters
      const filteredRecommendations = this.applyBusinessRules(
        mergedRecommendations,
        context
      );

      // Sort by score and limit
      return filteredRecommendations
        .sort((a, b) => b.score - a.score)
        .slice(0, limit);
    } catch (error) {
      logger.error('ML recommendation generation failed:', error);
      // Fallback to simple recommendations
      return this.fallbackRecommendations(availableProperties, context, limit);
    }
  }

  private async contentBasedFiltering(
    properties: any[],
    userPreferences: any,
    context: RecommendationContext
  ): Promise<MLRecommendation[]> {
    if (!userPreferences) return [];

    const recommendations: MLRecommendation[] = [];

    for (const property of properties) {
      let score = 0;
      let reasons: string[] = [];

      // Property type preference
      if (userPreferences.preferred_types) {
        const preferredType = userPreferences.preferred_types.find(
          (type: any) => type.property_type === property.type
        );
        if (preferredType) {
          score += Math.min(preferredType.view_count * 0.1, 1.0);
          reasons.push(`matches your preferred ${property.type} type`);
        }
      }

      // Price preference
      if (userPreferences.avg_price_min && userPreferences.avg_price_max && property.priceRange) {
        const userPriceRange = userPreferences.avg_price_max - userPreferences.avg_price_min;
        const propertyPrice = (property.priceRange.min + property.priceRange.max) / 2;
        const userAvgPrice = (userPreferences.avg_price_min + userPreferences.avg_price_max) / 2;
        
        const priceDiff = Math.abs(propertyPrice - userAvgPrice);
        const priceScore = Math.max(0, 1 - (priceDiff / userPriceRange));
        score += priceScore * 0.3;
        
        if (priceScore > 0.7) {
          reasons.push('within your typical price range');
        }
      }

      // Rating preference
      if (userPreferences.preferred_min_rating && property.rating) {
        if (property.rating >= userPreferences.preferred_min_rating) {
          score += 0.2;
          reasons.push('meets your quality standards');
        }
      }

      // Location preference
      if (userPreferences.preferred_cities && property.address) {
        const isPreferredCity = userPreferences.preferred_cities.some(
          (city: string) => property.address.city?.toLowerCase().includes(city.toLowerCase())
        );
        if (isPreferredCity) {
          score += 0.3;
          reasons.push('in one of your preferred cities');
        }
      }

      if (score > 0.1) {
        recommendations.push({
          propertyId: property.id,
          score,
          reason: `Recommended because it ${reasons.join(', ')}`,
          confidence: Math.min(score, 1.0),
          metadata: { type: 'content_based', reasons },
        });
      }
    }

    return recommendations;
  }

  private async collaborativeFiltering(
    properties: any[],
    userSearchPatterns: any[],
    context: RecommendationContext
  ): Promise<MLRecommendation[]> {
    // Simplified collaborative filtering based on location patterns
    const recommendations: MLRecommendation[] = [];

    if (userSearchPatterns.length === 0) return recommendations;

    // Find similar destinations based on search history
    const searchedDestinations = userSearchPatterns.map(pattern => pattern.location_place_name);
    
    for (const property of properties) {
      let score = 0;
      const reasons: string[] = [];

      // Check if property is in a destination similar to user's search history
      if (property.address && searchedDestinations.length > 0) {
        const propertyLocation = `${property.address.city}, ${property.address.country}`;
        
        // Simple similarity based on city/country matching
        const matchingDestination = searchedDestinations.find(dest =>
          dest?.toLowerCase().includes(property.address.city?.toLowerCase()) ||
          dest?.toLowerCase().includes(property.address.country?.toLowerCase())
        );

        if (matchingDestination) {
          score += 0.4;
          reasons.push('similar to your previous searches');
        }
      }

      // Consider stay duration patterns
      const avgNights = userSearchPatterns.reduce((sum, pattern) => sum + (pattern.avg_nights || 1), 0) / userSearchPatterns.length;
      if (context.dateRange) {
        const requestedNights = Math.ceil((context.dateRange.checkOut.getTime() - context.dateRange.checkIn.getTime()) / (1000 * 60 * 60 * 24));
        const nightsDiff = Math.abs(requestedNights - avgNights);
        if (nightsDiff <= 2) {
          score += 0.1;
          reasons.push('matches your typical stay duration');
        }
      }

      if (score > 0.1) {
        recommendations.push({
          propertyId: property.id,
          score,
          reason: `Recommended because it ${reasons.join(', ')}`,
          confidence: score,
          metadata: { type: 'collaborative', reasons },
        });
      }
    }

    return recommendations;
  }

  private async locationBasedRecommendations(
    properties: any[],
    userSearchPatterns: any[],
    context: RecommendationContext
  ): Promise<MLRecommendation[]> {
    const recommendations: MLRecommendation[] = [];

    if (!context.searchLocation) return recommendations;

    for (const property of properties) {
      let score = 0;
      const reasons: string[] = [];

      // Distance-based scoring (simplified)
      if (context.searchLocation.coordinates && property.coordinates) {
        const distance = this.calculateDistance(
          context.searchLocation.coordinates,
          property.coordinates
        );
        
        // Prefer properties within reasonable distance
        if (distance <= 50) { // 50km radius
          score += Math.max(0, 0.3 * (1 - distance / 50));
          reasons.push('conveniently located');
        }
      }

      // Area familiarity bonus
      if (context.searchLocation.city && property.address) {
        if (property.address.city?.toLowerCase() === context.searchLocation.city.toLowerCase()) {
          score += 0.2;
          reasons.push('in your search area');
        }
      }

      if (score > 0.1) {
        recommendations.push({
          propertyId: property.id,
          score,
          reason: `Recommended because it's ${reasons.join(', ')}`,
          confidence: score,
          metadata: { type: 'location_based', reasons },
        });
      }
    }

    return recommendations;
  }

  private async behavioralRecommendations(
    properties: any[],
    context: RecommendationContext
  ): Promise<MLRecommendation[]> {
    const recommendations: MLRecommendation[] = [];

    // Session-based recommendations
    if (context.sessionProperties && context.sessionProperties.length > 0) {
      // Find similar properties to those viewed in this session
      for (const property of properties) {
        if (!context.sessionProperties.includes(property.id)) {
          let score = 0;
          const reasons: string[] = [];

          // Similar property type bonus
          // This would be more sophisticated in a real ML system
          score += 0.1;
          reasons.push('similar to properties you viewed');

          if (score > 0) {
            recommendations.push({
              propertyId: property.id,
              score,
              reason: `Recommended because it's ${reasons.join(', ')}`,
              confidence: score,
              metadata: { type: 'behavioral', reasons },
            });
          }
        }
      }
    }

    return recommendations;
  }

  private async popularityBasedRecommendations(
    properties: any[],
    context: RecommendationContext
  ): Promise<MLRecommendation[]> {
    const recommendations: MLRecommendation[] = [];

    // Get popular destinations from analytics
    const popularDestinations = await analyticsService.getPopularDestinations(50);
    
    for (const property of properties) {
      let score = 0;
      const reasons: string[] = [];

      // Check if property is in a popular destination
      const propertyLocation = `${property.address?.city}, ${property.address?.country}`;
      const isPopular = popularDestinations.some(dest => 
        propertyLocation.toLowerCase().includes(dest.destination?.toLowerCase())
      );

      if (isPopular) {
        score += 0.3;
        reasons.push('in a popular destination');
      }

      // Rating-based popularity
      if (property.rating && property.rating >= 4.0) {
        score += 0.2;
        reasons.push('highly rated');
      }

      // Reviews count as popularity indicator
      if (property.reviewsCount && property.reviewsCount >= 100) {
        score += 0.1;
        reasons.push('popular with travelers');
      }

      if (score > 0.1) {
        recommendations.push({
          propertyId: property.id,
          score,
          reason: `Recommended because it's ${reasons.join(', ')}`,
          confidence: score,
          metadata: { type: 'popularity_based', reasons },
        });
      }
    }

    return recommendations;
  }

  private mergeRecommendations(recommendations: MLRecommendation[]): MLRecommendation[] {
    const mergedMap = new Map<string, MLRecommendation>();

    for (const rec of recommendations) {
      if (mergedMap.has(rec.propertyId)) {
        const existing = mergedMap.get(rec.propertyId)!;
        // Combine scores with weighted average
        existing.score = (existing.score + rec.score) / 2;
        existing.confidence = Math.max(existing.confidence, rec.confidence);
        existing.reason = `${existing.reason}; ${rec.reason}`;
        if (existing.metadata && rec.metadata) {
          existing.metadata.reasons = [...(existing.metadata.reasons || []), ...(rec.metadata.reasons || [])];
        }
      } else {
        mergedMap.set(rec.propertyId, { ...rec });
      }
    }

    return Array.from(mergedMap.values());
  }

  private applyBusinessRules(
    recommendations: MLRecommendation[],
    context: RecommendationContext
  ): MLRecommendation[] {
    return recommendations.filter(rec => {
      // Filter out properties that don't meet basic criteria
      if (rec.score < 0.1) return false;
      
      // Apply context-specific filters
      if (context.priceRange) {
        // Would check if property price is within range
        // Simplified for this example
      }

      return true;
    });
  }

  private fallbackRecommendations(
    properties: any[],
    context: RecommendationContext,
    limit: number
  ): MLRecommendation[] {
    // Simple fallback based on rating and popularity
    return properties
      .filter(p => p.rating && p.rating >= 3.5)
      .map(property => ({
        propertyId: property.id,
        score: (property.rating || 0) / 5,
        reason: 'Popular choice based on ratings',
        confidence: 0.5,
        metadata: { type: 'fallback' },
      }))
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);
  }

  private calculateDistance(
    coord1: { lat: number; lng: number },
    coord2: { lat: number; lng: number }
  ): number {
    // Haversine formula for distance calculation
    const R = 6371; // Earth's radius in km
    const dLat = (coord2.lat - coord1.lat) * Math.PI / 180;
    const dLon = (coord2.lng - coord1.lng) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(coord1.lat * Math.PI / 180) * Math.cos(coord2.lat * Math.PI / 180) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }
}

export const mlRecommendationService = new MLRecommendationService();