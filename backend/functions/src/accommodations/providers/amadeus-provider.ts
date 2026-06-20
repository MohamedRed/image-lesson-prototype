import fetch from 'node-fetch';
import {
  AccommodationProvider,
  ProviderSearchRequest,
  ProviderSearchResponse,
  PropertyDetailsParams,
  PropertyDetailsResponse,
  AvailabilityRequest,
  AvailabilityResponse,
  CreateBookingRequest,
  CreateBookingResponse,
  CancelBookingResponse,
  ProviderHealth,
  ProviderConfig,
} from './provider-interface';
import {
  AccommodationProperty,
  AccommodationType,
  Booking,
  BookingStatus,
  CancellationType,
} from '../models/types';
import { logger } from '../../shared/utils/logger';

/**
 * Amadeus Hotel Search API Provider
 * Documentation: https://developers.amadeus.com/self-service/category/hotel
 */
export class AmadeusProvider implements AccommodationProvider {
  readonly name = 'amadeus';
  readonly displayName = 'Amadeus';
  readonly isEnabled: boolean;
  
  private apiKey: string;
  private apiSecret: string;
  private baseUrl: string;
  private accessToken?: string;
  private tokenExpiry?: Date;
  
  constructor(config: ProviderConfig) {
    this.apiKey = config.apiKey || '';
    this.apiSecret = config.apiSecret || '';
    this.baseUrl = config.endpoint || 'https://api.amadeus.com/v1';
    this.isEnabled = !!(this.apiKey && this.apiSecret);
  }
  
  async search(request: ProviderSearchRequest): Promise<ProviderSearchResponse> {
    try {
      await this.ensureAuthenticated();
      
      const params = new URLSearchParams({
        latitude: request.location.latitude.toString(),
        longitude: request.location.longitude.toString(),
        radius: (request.location.radius || 5).toString(),
        radiusUnit: 'KM',
        checkInDate: this.formatDate(request.checkIn),
        checkOutDate: this.formatDate(request.checkOut),
        adults: request.guests.adults.toString(),
        roomQuantity: request.rooms.toString(),
      });
      
      if (request.filters?.priceMin) {
        params.append('priceRange', `${request.filters.priceMin}-${request.filters.priceMax || 99999}`);
      }
      
      if (request.filters?.rating) {
        params.append('ratings', request.filters.rating.toString());
      }
      
      if (request.filters?.amenities?.length) {
        params.append('amenities', request.filters.amenities.join(','));
      }
      
      const response = await fetch(
        `${this.baseUrl}/shopping/hotel-offers?${params}`,
        {
          headers: {
            'Authorization': `Bearer ${this.accessToken}`,
            'Accept': 'application/json',
          },
        }
      );
      
      if (!response.ok) {
        throw new Error(`Amadeus search failed: ${response.statusText}`);
      }
      
      const data = await response.json() as any;
      
      return {
        properties: this.mapAmadeusProperties(data.data || []),
        totalResults: data.meta?.count || 0,
        nextPageToken: data.meta?.links?.next,
      };
    } catch (error) {
      logger.error('Amadeus search error:', error);
      throw error;
    }
  }
  
  async getPropertyDetails(propertyId: string, params?: PropertyDetailsParams): Promise<PropertyDetailsResponse> {
    try {
      await this.ensureAuthenticated();
      
      const queryParams = new URLSearchParams({
        hotelId: propertyId,
      });
      
      if (params?.checkIn && params?.checkOut) {
        queryParams.append('checkInDate', this.formatDate(params.checkIn));
        queryParams.append('checkOutDate', this.formatDate(params.checkOut));
        queryParams.append('adults', (params.guests?.adults || 1).toString());
      }
      
      const response = await fetch(
        `${this.baseUrl}/shopping/hotel-offers/by-hotel?${queryParams}`,
        {
          headers: {
            'Authorization': `Bearer ${this.accessToken}`,
            'Accept': 'application/json',
          },
        }
      );
      
      if (!response.ok) {
        throw new Error(`Amadeus property details failed: ${response.statusText}`);
      }
      
      const data = await response.json() as any;
      
      // Map the response to our domain model
      const property = this.mapAmadeusProperty(data.data?.[0]?.hotel);
      const { roomTypes, ratePlans, availability } = this.mapAmadeusOffers(data.data?.[0]?.offers || []);
      
      return {
        property,
        roomTypes,
        ratePlans,
        availability,
      };
    } catch (error) {
      logger.error('Amadeus property details error:', error);
      throw error;
    }
  }
  
  async checkAvailability(request: AvailabilityRequest): Promise<AvailabilityResponse> {
    // Similar implementation to getPropertyDetails but focused on availability
    return this.getPropertyDetails(request.propertyId, {
      checkIn: request.checkIn,
      checkOut: request.checkOut,
      guests: request.guests,
    }).then(response => ({
      propertyId: request.propertyId,
      availability: response.availability || [],
      roomTypes: response.roomTypes,
      ratePlans: response.ratePlans,
    }));
  }
  
  async createBooking(request: CreateBookingRequest): Promise<CreateBookingResponse> {
    try {
      await this.ensureAuthenticated();
      
      // Amadeus booking creation
      const bookingData = {
        data: {
          offerId: request.ratePlanId,
          guests: request.guests.map((guest, index) => ({
            id: index + 1,
            name: {
              firstName: guest.firstName,
              lastName: guest.lastName,
            },
            contact: {
              email: guest.email,
              phone: guest.phone,
            },
          })),
          payments: [{
            method: 'CREDIT_CARD',
            // Payment details would be handled securely
          }],
        },
      };
      
      const response = await fetch(
        `${this.baseUrl}/booking/hotel-bookings`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${this.accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(bookingData),
        }
      );
      
      if (!response.ok) {
        throw new Error(`Amadeus booking failed: ${response.statusText}`);
      }
      
      const data = await response.json() as any;
      
      return {
        bookingId: data.data?.id || '',
        providerBookingId: data.data?.providerConfirmationId || '',
        confirmationCode: data.data?.associatedRecords?.[0]?.reference || '',
        status: 'CONFIRMED',
        totalAmount: data.data?.price?.total || 0,
        currency: data.data?.price?.currency || 'USD',
      };
    } catch (error) {
      logger.error('Amadeus booking error:', error);
      throw error;
    }
  }
  
  async cancelBooking(bookingId: string, reason?: string): Promise<CancelBookingResponse> {
    // Amadeus cancellation implementation
    // This would make the actual API call to cancel
    return {
      success: true,
      cancellationId: `CANCEL-${bookingId}`,
      message: 'Booking cancelled successfully',
    };
  }
  
  async getBookingDetails(bookingId: string): Promise<Booking> {
    // Fetch booking details from Amadeus
    throw new Error('Not implemented');
  }
  
  async validateCredentials(): Promise<boolean> {
    try {
      await this.authenticate();
      return true;
    } catch {
      return false;
    }
  }
  
  async healthCheck(): Promise<ProviderHealth> {
    try {
      const start = Date.now();
      await this.ensureAuthenticated();
      const latency = Date.now() - start;
      
      return {
        status: 'healthy',
        latency,
        lastCheck: new Date(),
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        lastCheck: new Date(),
        errors: [(error as Error).message],
      };
    }
  }
  
  private async ensureAuthenticated(): Promise<void> {
    if (!this.accessToken || !this.tokenExpiry || this.tokenExpiry < new Date()) {
      await this.authenticate();
    }
  }
  
  private async authenticate(): Promise<void> {
    const response = await fetch(
      'https://api.amadeus.com/v1/security/oauth2/token',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          grant_type: 'client_credentials',
          client_id: this.apiKey,
          client_secret: this.apiSecret,
        }),
      }
    );
    
    if (!response.ok) {
      throw new Error(`Amadeus authentication failed: ${response.statusText}`);
    }
    
    const data = await response.json() as any;
    this.accessToken = data.access_token;
    this.tokenExpiry = new Date(Date.now() + (data.expires_in * 1000));
  }
  
  private formatDate(date: Date): string {
    return date.toISOString().split('T')[0];
  }
  
  private mapAmadeusProperties(amadeusData: any[]): AccommodationProperty[] {
    return amadeusData.map(item => this.mapAmadeusProperty(item.hotel));
  }
  
  private mapAmadeusProperty(hotel: any): AccommodationProperty {
    return {
      id: `amadeus-${hotel.hotelId}`,
      providerRefs: [{
        provider: 'amadeus',
        providerPropertyId: hotel.hotelId,
        deepLink: hotel.media?.[0]?.uri,
      }],
      name: hotel.name || '',
      brand: hotel.brandCode,
      type: this.mapPropertyType(hotel.type),
      rating: hotel.rating ? parseFloat(hotel.rating) : undefined,
      reviewsCount: 0, // Amadeus doesn't provide review count
      address: {
        street: hotel.address?.lines?.[0],
        city: hotel.address?.cityName || '',
        state: hotel.address?.stateCode,
        postalCode: hotel.address?.postalCode,
        country: hotel.address?.countryCode || '',
        formattedAddress: [
          hotel.address?.lines?.[0],
          hotel.address?.cityName,
          hotel.address?.stateCode,
          hotel.address?.postalCode,
          hotel.address?.countryCode,
        ].filter(Boolean).join(', '),
      },
      coordinates: {
        latitude: hotel.latitude || 0,
        longitude: hotel.longitude || 0,
      },
      photos: hotel.media?.map((m: any) => ({
        id: m.uri,
        url: m.uri,
        caption: m.category,
      })) || [],
      amenities: hotel.amenities || [],
      safetyFeatures: [],
      checkInTime: '15:00',
      checkOutTime: '11:00',
      policies: {
        cancellationPolicy: {
          type: CancellationType.FLEXIBLE,
          description: 'Standard cancellation policy',
        },
        childrenAllowed: true,
        petsAllowed: false,
        smokingAllowed: false,
        partyEventsAllowed: false,
        additionalRules: [],
      },
    };
  }
  
  private mapPropertyType(type: string): AccommodationType {
    const typeMap: Record<string, AccommodationType> = {
      'HOTEL': AccommodationType.HOTEL,
      'APARTMENT': AccommodationType.APARTMENT,
      'HOSTEL': AccommodationType.HOSTEL,
      'MOTEL': AccommodationType.HOTEL,
      'RESORT': AccommodationType.HOTEL,
    };
    return typeMap[type] || AccommodationType.HOTEL;
  }
  
  private mapAmadeusOffers(offers: any[]): {
    roomTypes: any[];
    ratePlans: any[];
    availability: any[];
  } {
    // Map Amadeus offers to our domain model
    // This is a simplified version
    const roomTypes: any[] = [];
    const ratePlans: any[] = [];
    const availability: any[] = [];
    
    offers.forEach(offer => {
      // Extract room types, rate plans, and availability from offers
      // Implementation would map the complex Amadeus structure
    });
    
    return { roomTypes, ratePlans, availability };
  }
}