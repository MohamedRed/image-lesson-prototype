import * as admin from 'firebase-admin';
import {
  VoiceInterpretRequest,
  VoiceInterpretResponse,
  SearchRequest,
  SearchIntent,
  IntentType,
  SearchLocation,
  AccommodationType,
  SortOption,
} from '../models/types';
import { logger } from '../../shared/utils/logger';

export class VoiceService {
  private db: admin.firestore.Firestore;
  
  constructor() {
    this.db = admin.firestore();
  }
  
  async interpret(request: VoiceInterpretRequest, userId?: string): Promise<VoiceInterpretResponse> {
    try {
      // Clean and normalize the transcript
      const transcript = this.normalizeTranscript(request.transcript);
      
      // Extract intent and entities
      const intent = await this.extractIntent(transcript);
      const entities = await this.extractEntities(transcript, request.context);
      
      // Build normalized search parameters
      const normalizedParams = this.buildSearchParams(intent, entities, request.context);
      
      // Generate next prompt for conversation flow
      const nextPrompt = this.generateNextPrompt(intent, entities, normalizedParams);
      
      // Calculate confidence score
      const confidence = this.calculateConfidence(intent, entities);
      
      // Log for training data
      if (userId) {
        await this.logVoiceInteraction(userId, request, intent, entities);
      }
      
      return {
        intent,
        normalizedParams,
        nextPrompt,
        confidence,
      };
    } catch (error) {
      logger.error('Voice interpretation failed:', error);
      throw error;
    }
  }
  
  private normalizeTranscript(transcript: string): string {
    return transcript
      .toLowerCase()
      .trim()
      .replace(/[^\w\s]/g, ' ')
      .replace(/\s+/g, ' ');
  }
  
  private async extractIntent(transcript: string): Promise<SearchIntent> {
    // Intent classification using keyword matching
    // In production, this would use a trained NLU model
    
    const searchKeywords = ['find', 'search', 'look for', 'show me', 'i need', 'book'];
    const filterKeywords = ['filter', 'narrow down', 'only show', 'exclude', 'include'];
    const sortKeywords = ['sort', 'order by', 'arrange', 'cheapest', 'most expensive', 'highest rated'];
    const bookKeywords = ['book', 'reserve', 'make reservation', 'confirm booking'];
    const detailKeywords = ['details', 'more info', 'tell me about', 'show details'];
    const helpKeywords = ['help', 'how to', 'what can', 'explain'];
    const cancelKeywords = ['cancel', 'stop', 'never mind', 'forget it'];
    
    let intentType = IntentType.SEARCH; // Default
    const entities: Record<string, any> = {};
    
    if (this.containsKeywords(transcript, searchKeywords)) {
      intentType = IntentType.SEARCH;
    } else if (this.containsKeywords(transcript, filterKeywords)) {
      intentType = IntentType.FILTER;
    } else if (this.containsKeywords(transcript, sortKeywords)) {
      intentType = IntentType.SORT;
    } else if (this.containsKeywords(transcript, bookKeywords)) {
      intentType = IntentType.BOOK;
    } else if (this.containsKeywords(transcript, detailKeywords)) {
      intentType = IntentType.DETAILS;
    } else if (this.containsKeywords(transcript, helpKeywords)) {
      intentType = IntentType.HELP;
    } else if (this.containsKeywords(transcript, cancelKeywords)) {
      intentType = IntentType.CANCEL;
    }
    
    return {
      type: intentType,
      entities,
    };
  }
  
  private async extractEntities(
    transcript: string,
    context?: any
  ): Promise<Record<string, any>> {
    const entities: Record<string, any> = {};
    
    // Extract location entities
    const location = this.extractLocation(transcript);
    if (location) {
      entities.location = location;
    }
    
    // Extract date entities
    const dates = this.extractDates(transcript);
    if (dates.checkIn || dates.checkOut) {
      entities.dates = dates;
    }
    
    // Extract guest information
    const guests = this.extractGuests(transcript);
    if (guests) {
      entities.guests = guests;
    }
    
    // Extract accommodation type preferences
    const types = this.extractAccommodationTypes(transcript);
    if (types.length > 0) {
      entities.types = types;
    }
    
    // Extract price/budget information
    const budget = this.extractBudget(transcript);
    if (budget) {
      entities.budget = budget;
    }
    
    // Extract amenities
    const amenities = this.extractAmenities(transcript);
    if (amenities.length > 0) {
      entities.amenities = amenities;
    }
    
    // Extract sort preference
    const sortBy = this.extractSortPreference(transcript);
    if (sortBy) {
      entities.sortBy = sortBy;
    }
    
    return entities;
  }
  
  private extractLocation(transcript: string): SearchLocation | null {
    // Simple location extraction using common patterns
    const locationPatterns = [
      /in ([a-z\s]+)/,
      /at ([a-z\s]+)/,
      /near ([a-z\s]+)/,
      /around ([a-z\s]+)/,
    ];
    
    for (const pattern of locationPatterns) {
      const match = transcript.match(pattern);
      if (match) {
        const locationText = match[1].trim();
        // In production, this would geocode the location
        return {
          type: 'address',
          address: locationText,
        };
      }
    }
    
    // Check for "here" or "current location"
    if (transcript.includes('here') || transcript.includes('current location') || transcript.includes('nearby')) {
      return {
        type: 'coordinates',
        lat: 0, // Would get from user's location
        lng: 0,
      };
    }
    
    return null;
  }
  
  private extractDates(transcript: string): { checkIn?: Date; checkOut?: Date } {
    const dates: { checkIn?: Date; checkOut?: Date } = {};
    
    // Simple date extraction patterns
    const datePatterns = [
      /(\w+day)/g,                    // today, tomorrow, monday, etc.
      /(\d{1,2}\/\d{1,2})/g,         // MM/dd
      /(\w+ \d{1,2})/g,              // March 15
      /(next \w+)/g,                 // next week, next month
    ];
    
    const dateMatches: string[] = [];
    datePatterns.forEach(pattern => {
      const matches = transcript.match(pattern);
      if (matches) {
        dateMatches.push(...matches);
      }
    });
    
    if (dateMatches.length >= 2) {
      dates.checkIn = this.parseRelativeDate(dateMatches[0]);
      dates.checkOut = this.parseRelativeDate(dateMatches[1]);
    } else if (dateMatches.length === 1) {
      dates.checkIn = this.parseRelativeDate(dateMatches[0]);
      // Default to 2 nights
      dates.checkOut = new Date(dates.checkIn.getTime() + 2 * 24 * 60 * 60 * 1000);
    }
    
    return dates;
  }
  
  private extractGuests(transcript: string): any | null {
    const guestPatterns = [
      /(\d+)\s+(?:people|guests|adults)/,
      /(\d+)\s+(?:person|adult)/,
      /(\d+)\s+(?:kids?|children)/,
    ];
    
    let adults = 1;
    let children = 0;
    
    for (const pattern of guestPatterns) {
      const match = transcript.match(pattern);
      if (match) {
        const count = parseInt(match[1], 10);
        if (transcript.includes('kid') || transcript.includes('child')) {
          children = count;
        } else {
          adults = count;
        }
      }
    }
    
    // Look for room count
    const roomMatch = transcript.match(/(\d+)\s+rooms?/);
    const rooms = roomMatch ? parseInt(roomMatch[1], 10) : 1;
    
    return {
      rooms,
      adults,
      children,
      childrenAges: [], // Could extract if specified
    };
  }
  
  private extractAccommodationTypes(transcript: string): AccommodationType[] {
    const typeMap: Record<string, AccommodationType> = {
      'hotel': AccommodationType.HOTEL,
      'motel': AccommodationType.HOTEL,
      'hostel': AccommodationType.HOSTEL,
      'apartment': AccommodationType.APARTMENT,
      'condo': AccommodationType.APARTMENT,
      'room': AccommodationType.ROOM,
      'homestay': AccommodationType.HOMESTAY,
      'bed and breakfast': AccommodationType.BED_AND_BREAKFAST,
      'bnb': AccommodationType.BED_AND_BREAKFAST,
      'b&b': AccommodationType.BED_AND_BREAKFAST,
      'vacation rental': AccommodationType.VACATION_RENTAL,
      'airbnb': AccommodationType.VACATION_RENTAL,
      'rental': AccommodationType.VACATION_RENTAL,
    };
    
    const types: AccommodationType[] = [];
    
    Object.entries(typeMap).forEach(([keyword, type]) => {
      if (transcript.includes(keyword)) {
        types.push(type);
      }
    });
    
    return types;
  }
  
  private extractBudget(transcript: string): any | null {
    const budgetPatterns = [
      /under \$?(\d+)/,
      /less than \$?(\d+)/,
      /below \$?(\d+)/,
      /maximum \$?(\d+)/,
      /max \$?(\d+)/,
      /budget of \$?(\d+)/,
      /around \$?(\d+)/,
      /about \$?(\d+)/,
      /\$?(\d+) to \$?(\d+)/,
      /between \$?(\d+) and \$?(\d+)/,
    ];
    
    for (const pattern of budgetPatterns) {
      const match = transcript.match(pattern);
      if (match) {
        if (match[2]) {
          // Range pattern
          return {
            min: parseInt(match[1], 10),
            max: parseInt(match[2], 10),
            currency: 'USD',
          };
        } else {
          // Single value pattern
          const amount = parseInt(match[1], 10);
          if (transcript.includes('under') || transcript.includes('less') || transcript.includes('max')) {
            return {
              max: amount,
              currency: 'USD',
            };
          } else {
            return {
              min: Math.max(0, amount - 50),
              max: amount + 50,
              currency: 'USD',
            };
          }
        }
      }
    }
    
    return null;
  }
  
  private extractAmenities(transcript: string): string[] {
    const amenityMap: Record<string, string> = {
      'wifi': 'Free WiFi',
      'internet': 'Free WiFi',
      'parking': 'Free Parking',
      'pool': 'Swimming Pool',
      'gym': 'Fitness Center',
      'fitness': 'Fitness Center',
      'spa': 'Spa',
      'restaurant': 'Restaurant',
      'breakfast': 'Breakfast',
      'kitchen': 'Kitchen',
      'kitchenette': 'Kitchenette',
      'air conditioning': 'Air Conditioning',
      'ac': 'Air Conditioning',
      'pet friendly': 'Pet Friendly',
      'pets allowed': 'Pet Friendly',
      'balcony': 'Balcony',
      'ocean view': 'Ocean View',
      'sea view': 'Ocean View',
    };
    
    const amenities: string[] = [];
    
    Object.entries(amenityMap).forEach(([keyword, amenity]) => {
      if (transcript.includes(keyword)) {
        amenities.push(amenity);
      }
    });
    
    return amenities;
  }
  
  private extractSortPreference(transcript: string): SortOption | null {
    if (transcript.includes('cheapest') || transcript.includes('lowest price')) {
      return SortOption.PRICE_ASC;
    }
    if (transcript.includes('most expensive') || transcript.includes('highest price')) {
      return SortOption.PRICE_DESC;
    }
    if (transcript.includes('highest rated') || transcript.includes('best rated')) {
      return SortOption.RATING;
    }
    if (transcript.includes('closest') || transcript.includes('nearest')) {
      return SortOption.DISTANCE;
    }
    if (transcript.includes('most popular')) {
      return SortOption.POPULARITY;
    }
    
    return null;
  }
  
  private buildSearchParams(
    intent: SearchIntent,
    entities: Record<string, any>,
    context?: any
  ): SearchRequest {
    const defaultLocation: SearchLocation = {
      type: 'coordinates',
      lat: 37.7749, // San Francisco as default
      lng: -122.4194,
    };
    
    const defaultDateRange = {
      startDate: new Date(),
      endDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000), // 2 days from now
    };
    
    const defaultGuests = {
      rooms: 1,
      adults: 1,
      children: 0,
      childrenAges: [],
    };
    
    return {
      location: entities.location || context?.previousSearch?.location || defaultLocation,
      dateRange: entities.dates ? {
        startDate: entities.dates.checkIn || new Date(),
        endDate: entities.dates.checkOut || new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
      } : context?.previousSearch?.dateRange || defaultDateRange,
      guests: entities.guests || context?.previousSearch?.guests || defaultGuests,
      filters: {
        budgetMin: entities.budget?.min,
        budgetMax: entities.budget?.max,
        types: entities.types,
        amenities: entities.amenities,
      },
      sortBy: entities.sortBy,
    };
  }
  
  private generateNextPrompt(
    intent: SearchIntent,
    entities: Record<string, any>,
    params: SearchRequest
  ): string | undefined {
    switch (intent.type) {
      case IntentType.SEARCH:
        if (!entities.location) {
          return "Where would you like to stay?";
        }
        if (!entities.dates) {
          return "When would you like to check in and check out?";
        }
        return "I found some great options for you. Would you like me to show the cheapest first or the highest rated?";
      
      case IntentType.FILTER:
        return "I'll apply those filters to your search. Any other preferences?";
      
      case IntentType.SORT:
        return "I'll sort the results that way for you.";
      
      case IntentType.HELP:
        return "I can help you search for accommodations. Just tell me where you want to stay and when, and I'll find great options for you!";
      
      case IntentType.CANCEL:
        return "No problem! Let me know if you'd like to search for accommodations later.";
      
      default:
        return undefined;
    }
  }
  
  private calculateConfidence(intent: SearchIntent, entities: Record<string, any>): number {
    let confidence = 0.5; // Base confidence
    
    // Boost confidence for recognized entities
    if (entities.location) confidence += 0.2;
    if (entities.dates) confidence += 0.1;
    if (entities.guests) confidence += 0.1;
    if (entities.types) confidence += 0.05;
    if (entities.amenities && entities.amenities.length > 0) confidence += 0.05;
    
    return Math.min(confidence, 1.0);
  }
  
  private containsKeywords(transcript: string, keywords: string[]): boolean {
    return keywords.some(keyword => transcript.includes(keyword));
  }
  
  private parseRelativeDate(dateText: string): Date {
    const now = new Date();
    
    if (dateText === 'today') {
      return now;
    }
    if (dateText === 'tomorrow') {
      return new Date(now.getTime() + 24 * 60 * 60 * 1000);
    }
    
    // Handle day names
    const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    const dayIndex = dayNames.indexOf(dateText);
    if (dayIndex !== -1) {
      const today = now.getDay();
      const daysUntilTarget = (dayIndex - today + 7) % 7 || 7; // Next occurrence of that day
      return new Date(now.getTime() + daysUntilTarget * 24 * 60 * 60 * 1000);
    }
    
    // Handle "next week", "next month", etc.
    if (dateText.startsWith('next ')) {
      const period = dateText.substring(5);
      if (period === 'week') {
        return new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
      }
      if (period === 'month') {
        const nextMonth = new Date(now);
        nextMonth.setMonth(nextMonth.getMonth() + 1);
        return nextMonth;
      }
    }
    
    // Try parsing as regular date
    const parsed = new Date(dateText);
    if (!isNaN(parsed.getTime())) {
      return parsed;
    }
    
    // Fallback to today
    return now;
  }
  
  private async logVoiceInteraction(
    userId: string,
    request: VoiceInterpretRequest,
    intent: SearchIntent,
    entities: Record<string, any>
  ): Promise<void> {
    try {
      const logEntry = {
        userId,
        transcript: request.transcript,
        intent: intent.type,
        entities,
        confidence: this.calculateConfidence(intent, entities),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        sessionId: request.context?.sessionId,
      };
      
      await this.db
        .collection('accommodations_voice_logs')
        .add(logEntry);
    } catch (error) {
      logger.error('Failed to log voice interaction:', error);
    }
  }
}