import * as admin from 'firebase-admin';
import fetch from 'node-fetch';
import * as cheerio from 'cheerio';
import {
  ImportRecord,
  ImportStatus,
  Booking,
  AccommodationProperty,
} from '../models/types';
import { logger } from '../../shared/utils/logger';
import { v4 as uuidv4 } from 'uuid';

export class ImportService {
  private db: admin.firestore.Firestore;
  
  constructor() {
    this.db = admin.firestore();
  }
  
  async importBooking(userId: string, request: ImportRequest): Promise<ImportResult> {
    const importId = uuidv4();
    
    try {
      // Create import record
      const importRecord: ImportRecord = {
        id: importId,
        userId,
        sourceUrl: request.url,
        confirmationCode: request.confirmationCode,
        parsedAttributes: {},
        status: ImportStatus.PROCESSING,
        provenance: this.determineProvenance(request),
        createdAt: new Date(),
      };
      
      await this.db
        .collection('accommodations_imports')
        .doc(importId)
        .set(importRecord);
      
      let result: ImportResult;
      
      if (request.url) {
        result = await this.importFromUrl(importId, request.url);
      } else if (request.confirmationCode && request.provider) {
        result = await this.importFromConfirmation(
          importId,
          request.provider,
          request.confirmationCode,
          request.lastName
        );
      } else {
        throw new Error('Either URL or confirmation details required');
      }
      
      // Update import record with results
      await this.db
        .collection('accommodations_imports')
        .doc(importId)
        .update({
          status: result.success ? ImportStatus.SUCCESS : ImportStatus.FAILED,
          parsedAttributes: result.booking || {},
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      
      return result;
    } catch (error) {
      logger.error(`Import failed for ${importId}:`, error);
      
      // Update import record with error
      await this.db
        .collection('accommodations_imports')
        .doc(importId)
        .update({
          status: ImportStatus.FAILED,
          error: (error as Error).message,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      
      return {
        importId,
        success: false,
        error: (error as Error).message,
      };
    }
  }
  
  private async importFromUrl(importId: string, url: string): Promise<ImportResult> {
    try {
      // Validate URL
      if (!this.isAllowedUrl(url)) {
        throw new Error('URL not supported for import');
      }
      
      // Fetch page content
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; LiiveApp/1.0)',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
        timeout: 10000,
      });
      
      if (!response.ok) {
        throw new Error(`Failed to fetch URL: ${response.statusText}`);
      }
      
      const html = await response.text();
      const booking = await this.parseBookingFromHtml(html, url);
      
      if (booking) {
        return {
          importId,
          success: true,
          booking,
          deepLink: url,
        };
      } else {
        return {
          importId,
          success: false,
          error: 'Could not extract booking details from page',
          deepLink: url,
        };
      }
    } catch (error) {
      logger.error(`URL import failed for ${importId}:`, error);
      throw error;
    }
  }
  
  private async importFromConfirmation(
    importId: string,
    provider: string,
    confirmationCode: string,
    lastName?: string
  ): Promise<ImportResult> {
    try {
      const booking = await this.fetchBookingByConfirmation(
        provider,
        confirmationCode,
        lastName
      );
      
      if (booking) {
        return {
          importId,
          success: true,
          booking,
        };
      } else {
        return {
          importId,
          success: false,
          error: 'Booking not found with provided confirmation details',
        };
      }
    } catch (error) {
      logger.error(`Confirmation import failed for ${importId}:`, error);
      throw error;
    }
  }
  
  private isAllowedUrl(url: string): boolean {
    const allowedDomains = [
      'booking.com',
      'expedia.com',
      'hotels.com',
      'airbnb.com',
      'vrbo.com',
      'agoda.com',
      'kayak.com',
    ];
    
    try {
      const urlObj = new URL(url);
      return allowedDomains.some(domain => 
        urlObj.hostname.includes(domain)
      );
    } catch {
      return false;
    }
  }
  
  private async parseBookingFromHtml(html: string, url: string): Promise<Partial<Booking> | null> {
    const $ = cheerio.load(html);
    
    try {
      const urlObj = new URL(url);
      
      if (urlObj.hostname.includes('booking.com')) {
        return this.parseBookingCom($);
      } else if (urlObj.hostname.includes('expedia.com')) {
        return this.parseExpedia($);
      } else if (urlObj.hostname.includes('airbnb.com')) {
        return this.parseAirbnb($);
      }
      
      // Generic parsing fallback
      return this.parseGeneric($);
    } catch (error) {
      logger.error('HTML parsing failed:', error);
      return null;
    }
  }
  
  private parseBookingCom($: cheerio.CheerioAPI): Partial<Booking> | null {
    try {
      // Extract structured data
      const jsonLd = $('script[type="application/ld+json"]').html();
      if (jsonLd) {
        const data = JSON.parse(jsonLd);
        if (data['@type'] === 'LodgingReservation') {
          return this.mapJsonLdToBooking(data);
        }
      }
      
      // Fallback to DOM parsing
      const property: Partial<AccommodationProperty> = {
        name: $('.hp__hotel-name').text().trim() || 
              $('[data-testid="title"]').text().trim(),
        address: {
          formattedAddress: $('.hp_address_subtitle').text().trim(),
          city: '',
          country: '',
        },
        photos: [],
        amenities: [],
        safetyFeatures: [],
        checkInTime: '15:00',
        checkOutTime: '11:00',
        policies: {
          cancellationPolicy: {
            type: 'FLEXIBLE',
            description: 'Standard cancellation policy',
          },
          childrenAllowed: true,
          petsAllowed: false,
          smokingAllowed: false,
          partyEventsAllowed: false,
          additionalRules: [],
        },
        rating: parseFloat($('[data-testid="review-score-badge"]').text()) || undefined,
        reviewsCount: 0,
        coordinates: { latitude: 0, longitude: 0 },
        type: 'HOTEL',
        id: '',
        providerRefs: [],
      };
      
      // Extract dates
      const checkIn = this.parseDate($('.checkin').text() || $('.bui-date__display').first().text());
      const checkOut = this.parseDate($('.checkout').text() || $('.bui-date__display').last().text());
      
      if (!checkIn || !checkOut) {
        return null;
      }
      
      return {
        propertyRef: property as AccommodationProperty,
        dateRange: {
          startDate: checkIn,
          endDate: checkOut,
        },
        guests: [{
          firstName: 'Imported',
          lastName: 'Guest',
          isLead: true,
        }],
      };
    } catch (error) {
      logger.error('Booking.com parsing failed:', error);
      return null;
    }
  }
  
  private parseExpedia($: cheerio.CheerioAPI): Partial<Booking> | null {
    // Similar parsing logic for Expedia
    return null;
  }
  
  private parseAirbnb($: cheerio.CheerioAPI): Partial<Booking> | null {
    // Similar parsing logic for Airbnb
    return null;
  }
  
  private parseGeneric($: cheerio.CheerioAPI): Partial<Booking> | null {
    // Generic parsing using common patterns
    try {
      // Look for structured data
      const jsonLd = $('script[type="application/ld+json"]').html();
      if (jsonLd) {
        const data = JSON.parse(jsonLd);
        if (data['@type'] === 'LodgingReservation' || data['@type'] === 'Hotel') {
          return this.mapJsonLdToBooking(data);
        }
      }
      
      // Look for microdata
      const property = $('[itemtype*="Hotel"]').first();
      if (property.length) {
        return this.parseMicrodata(property);
      }
      
      return null;
    } catch (error) {
      logger.error('Generic parsing failed:', error);
      return null;
    }
  }
  
  private mapJsonLdToBooking(data: any): Partial<Booking> | null {
    try {
      const lodgingBusiness = data.reservationFor;
      
      if (!lodgingBusiness) {
        return null;
      }
      
      const property: Partial<AccommodationProperty> = {
        name: lodgingBusiness.name,
        address: lodgingBusiness.address ? {
          formattedAddress: this.formatAddress(lodgingBusiness.address),
          city: lodgingBusiness.address.addressLocality || '',
          state: lodgingBusiness.address.addressRegion || '',
          country: lodgingBusiness.address.addressCountry || '',
          street: lodgingBusiness.address.streetAddress,
          postalCode: lodgingBusiness.address.postalCode,
        } : {
          formattedAddress: '',
          city: '',
          country: '',
        },
        photos: [],
        amenities: [],
        safetyFeatures: [],
        checkInTime: '15:00',
        checkOutTime: '11:00',
        policies: {
          cancellationPolicy: {
            type: 'FLEXIBLE',
            description: 'Standard cancellation policy',
          },
          childrenAllowed: true,
          petsAllowed: false,
          smokingAllowed: false,
          partyEventsAllowed: false,
          additionalRules: [],
        },
        coordinates: { latitude: 0, longitude: 0 },
        type: 'HOTEL',
        id: '',
        providerRefs: [],
        reviewsCount: 0,
      };
      
      const checkIn = new Date(data.checkinDate || data.checkinTime);
      const checkOut = new Date(data.checkoutDate || data.checkoutTime);
      
      return {
        propertyRef: property as AccommodationProperty,
        dateRange: {
          startDate: checkIn,
          endDate: checkOut,
        },
        guests: [{
          firstName: 'Imported',
          lastName: 'Guest',
          isLead: true,
        }],
        providerConfirmation: {
          provider: 'imported',
          confirmationCode: data.reservationNumber || data.confirmationNumber || '',
        },
      };
    } catch (error) {
      logger.error('JSON-LD mapping failed:', error);
      return null;
    }
  }
  
  private parseMicrodata(element: cheerio.Cheerio): Partial<Booking> | null {
    // Parse microdata format
    return null;
  }
  
  private async fetchBookingByConfirmation(
    provider: string,
    confirmationCode: string,
    lastName?: string
  ): Promise<Partial<Booking> | null> {
    // This would integrate with provider APIs to fetch booking details
    // For now, return null as most providers don't support this
    logger.info(`Attempted to fetch booking ${confirmationCode} from ${provider}`);
    return null;
  }
  
  private parseDate(dateText: string): Date | null {
    if (!dateText) return null;
    
    // Try various date formats
    const formats = [
      /(\d{1,2})\/(\d{1,2})\/(\d{4})/,  // MM/dd/yyyy
      /(\d{4})-(\d{1,2})-(\d{1,2})/,    // yyyy-mm-dd
      /(\d{1,2})\s+(\w+)\s+(\d{4})/,    // dd Month yyyy
    ];
    
    for (const format of formats) {
      const match = dateText.match(format);
      if (match) {
        try {
          const date = new Date(dateText);
          if (!isNaN(date.getTime())) {
            return date;
          }
        } catch {
          continue;
        }
      }
    }
    
    return null;
  }
  
  private formatAddress(address: any): string {
    const parts = [
      address.streetAddress,
      address.addressLocality,
      address.addressRegion,
      address.postalCode,
      address.addressCountry,
    ].filter(Boolean);
    
    return parts.join(', ');
  }
  
  private determineProvenance(request: ImportRequest): string {
    if (request.url) {
      try {
        const urlObj = new URL(request.url);
        return `url:${urlObj.hostname}`;
      } catch {
        return 'url:unknown';
      }
    } else if (request.provider) {
      return `confirmation:${request.provider}`;
    }
    return 'unknown';
  }
}

// Types for import service
interface ImportRequest {
  url?: string;
  provider?: string;
  confirmationCode?: string;
  lastName?: string;
}

interface ImportResult {
  importId: string;
  success: boolean;
  booking?: Partial<Booking>;
  error?: string;
  deepLink?: string;
}