import {
  AccommodationProperty,
  Availability,
  SearchRequest,
  Booking,
  RoomType,
  RatePlan,
} from '../models/types';

/**
 * Base interface for all accommodation providers
 * Each provider (Booking.com, Expedia, Amadeus, etc.) implements this interface
 */
export interface AccommodationProvider {
  /**
   * Provider identifier
   */
  readonly name: string;
  
  /**
   * Provider display name
   */
  readonly displayName: string;
  
  /**
   * Whether this provider is currently enabled
   */
  readonly isEnabled: boolean;
  
  /**
   * Search for properties based on criteria
   */
  search(request: ProviderSearchRequest): Promise<ProviderSearchResponse>;
  
  /**
   * Get detailed information about a property
   */
  getPropertyDetails(propertyId: string, params?: PropertyDetailsParams): Promise<PropertyDetailsResponse>;
  
  /**
   * Check availability for specific dates
   */
  checkAvailability(request: AvailabilityRequest): Promise<AvailabilityResponse>;
  
  /**
   * Create a booking
   */
  createBooking(request: CreateBookingRequest): Promise<CreateBookingResponse>;
  
  /**
   * Cancel a booking
   */
  cancelBooking(bookingId: string, reason?: string): Promise<CancelBookingResponse>;
  
  /**
   * Get booking details
   */
  getBookingDetails(bookingId: string): Promise<Booking>;
  
  /**
   * Validate provider credentials/API keys
   */
  validateCredentials(): Promise<boolean>;
  
  /**
   * Get provider health status
   */
  healthCheck(): Promise<ProviderHealth>;
}

export interface ProviderSearchRequest {
  location: {
    latitude: number;
    longitude: number;
    radius?: number;
  };
  checkIn: Date;
  checkOut: Date;
  guests: {
    adults: number;
    children: number;
    childrenAges?: number[];
  };
  rooms: number;
  filters?: {
    priceMin?: number;
    priceMax?: number;
    rating?: number;
    amenities?: string[];
    propertyTypes?: string[];
  };
  currency?: string;
  locale?: string;
}

export interface ProviderSearchResponse {
  properties: AccommodationProperty[];
  totalResults: number;
  nextPageToken?: string;
  metadata?: Record<string, any>;
}

export interface PropertyDetailsParams {
  checkIn?: Date;
  checkOut?: Date;
  guests?: {
    adults: number;
    children: number;
  };
  currency?: string;
  locale?: string;
}

export interface PropertyDetailsResponse {
  property: AccommodationProperty;
  roomTypes: RoomType[];
  ratePlans: RatePlan[];
  availability?: Availability[];
}

export interface AvailabilityRequest {
  propertyId: string;
  checkIn: Date;
  checkOut: Date;
  guests: {
    adults: number;
    children: number;
    childrenAges?: number[];
  };
  rooms: number;
  currency?: string;
}

export interface AvailabilityResponse {
  propertyId: string;
  availability: Availability[];
  roomTypes: RoomType[];
  ratePlans: RatePlan[];
}

export interface CreateBookingRequest {
  propertyId: string;
  roomTypeId: string;
  ratePlanId: string;
  checkIn: Date;
  checkOut: Date;
  guests: Array<{
    firstName: string;
    lastName: string;
    email?: string;
    phone?: string;
    dateOfBirth?: Date;
  }>;
  payment: {
    method: string;
    token?: string;
  };
  specialRequests?: string;
}

export interface CreateBookingResponse {
  bookingId: string;
  providerBookingId: string;
  confirmationCode: string;
  status: string;
  totalAmount: number;
  currency: string;
  deepLink?: string;
}

export interface CancelBookingResponse {
  success: boolean;
  cancellationId?: string;
  refundAmount?: number;
  cancellationFee?: number;
  message?: string;
}

export interface ProviderHealth {
  status: 'healthy' | 'degraded' | 'unhealthy';
  latency?: number;
  lastCheck: Date;
  errors?: string[];
}

/**
 * Provider configuration
 */
export interface ProviderConfig {
  apiKey?: string;
  apiSecret?: string;
  endpoint?: string;
  timeout?: number;
  retryAttempts?: number;
  rateLimits?: {
    requestsPerSecond?: number;
    requestsPerMinute?: number;
    requestsPerHour?: number;
  };
}

/**
 * Provider factory to create provider instances
 */
export interface ProviderFactory {
  create(config: ProviderConfig): AccommodationProvider;
}

/**
 * Provider registry to manage multiple providers
 */
export class ProviderRegistry {
  private providers: Map<string, AccommodationProvider> = new Map();
  
  register(provider: AccommodationProvider): void {
    this.providers.set(provider.name, provider);
  }
  
  get(name: string): AccommodationProvider | undefined {
    return this.providers.get(name);
  }
  
  getAll(): AccommodationProvider[] {
    return Array.from(this.providers.values());
  }
  
  getEnabled(): AccommodationProvider[] {
    return this.getAll().filter(p => p.isEnabled);
  }
}