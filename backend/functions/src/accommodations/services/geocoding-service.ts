import fetch from "node-fetch";
import { getSecretValue } from "../../shared/secretManager.js";

export interface GeocodeResult {
  placeName: string;
  coordinates: {
    latitude: number;
    longitude: number;
  };
  context: {
    address?: string;
    neighborhood?: string;
    locality?: string;
    region?: string;
    country?: string;
    postcode?: string;
  };
}

export interface ReverseGeocodeResult {
  address: string;
  coordinates: {
    latitude: number;
    longitude: number;
  };
  context: {
    neighborhood?: string;
    locality?: string;
    region?: string;
    country?: string;
    postcode?: string;
  };
}

export interface AutocompleteResult {
  id: string;
  placeName: string;
  coordinates?: {
    latitude: number;
    longitude: number;
  };
  context: {
    address?: string;
    neighborhood?: string;
    locality?: string;
    region?: string;
    country?: string;
  };
}

export class MapboxGeocodingService {
  private accessToken: string | null = null;

  async initialize(): Promise<void> {
    if (!this.accessToken) {
      this.accessToken = await getSecretValue("MAPBOX_ACCESS_TOKEN");
    }
  }

  async geocode(query: string, options: {
    types?: string[];
    countryBias?: string[];
    proximityBias?: { latitude: number; longitude: number };
    bbox?: [number, number, number, number];
    language?: string;
  } = {}): Promise<GeocodeResult[]> {
    await this.initialize();

    const params = new URLSearchParams({
      access_token: this.accessToken!,
      limit: "10",
    });

    // Add type filters for accommodations-specific places
    if (options.types && options.types.length > 0) {
      params.append("types", options.types.join(","));
    } else {
      // Default types for accommodation searches
      params.append("types", "place,locality,address,poi");
    }

    if (options.countryBias && options.countryBias.length > 0) {
      params.append("country", options.countryBias.join(","));
    }

    if (options.proximityBias) {
      params.append("proximity", `${options.proximityBias.longitude},${options.proximityBias.latitude}`);
    }

    if (options.bbox && options.bbox.length === 4) {
      params.append("bbox", options.bbox.join(","));
    }

    if (options.language) {
      params.append("language", options.language);
    }

    const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(query)}.json?${params}`;

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Mapbox Geocoding API error: ${response.status} ${response.statusText}`);
    }

    const data: any = await response.json();
    
    return data.features.map((feature: any) => ({
      placeName: feature.place_name,
      coordinates: {
        longitude: feature.center[0],
        latitude: feature.center[1],
      },
      context: this.parseContext(feature.context || []),
    }));
  }

  async reverseGeocode(
    latitude: number,
    longitude: number,
    options: {
      types?: string[];
      language?: string;
    } = {}
  ): Promise<ReverseGeocodeResult[]> {
    await this.initialize();

    const params = new URLSearchParams({
      access_token: this.accessToken!,
      limit: "5",
    });

    if (options.types && options.types.length > 0) {
      params.append("types", options.types.join(","));
    } else {
      params.append("types", "address,place,locality");
    }

    if (options.language) {
      params.append("language", options.language);
    }

    const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${longitude},${latitude}.json?${params}`;

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Mapbox Reverse Geocoding API error: ${response.status} ${response.statusText}`);
    }

    const data: any = await response.json();
    
    return data.features.map((feature: any) => ({
      address: feature.place_name,
      coordinates: {
        longitude: feature.center[0],
        latitude: feature.center[1],
      },
      context: this.parseContext(feature.context || []),
    }));
  }

  async autocomplete(
    query: string,
    options: {
      types?: string[];
      countryBias?: string[];
      proximityBias?: { latitude: number; longitude: number };
      language?: string;
      sessionToken?: string;
    } = {}
  ): Promise<AutocompleteResult[]> {
    await this.initialize();

    const params = new URLSearchParams({
      access_token: this.accessToken!,
      limit: "10",
      autocomplete: "true",
    });

    if (options.types && options.types.length > 0) {
      params.append("types", options.types.join(","));
    } else {
      // Optimized for accommodation searches - cities, hotels, airports, etc.
      params.append("types", "place,locality,poi,address");
    }

    if (options.countryBias && options.countryBias.length > 0) {
      params.append("country", options.countryBias.join(","));
    }

    if (options.proximityBias) {
      params.append("proximity", `${options.proximityBias.longitude},${options.proximityBias.latitude}`);
    }

    if (options.language) {
      params.append("language", options.language);
    }

    const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(query)}.json?${params}`;

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Mapbox Autocomplete API error: ${response.status} ${response.statusText}`);
    }

    const data: any = await response.json();
    
    return data.features.map((feature: any) => ({
      id: feature.id,
      placeName: feature.place_name,
      coordinates: feature.center ? {
        longitude: feature.center[0],
        latitude: feature.center[1],
      } : undefined,
      context: this.parseContext(feature.context || []),
    }));
  }

  async getPlaceDetails(placeId: string): Promise<GeocodeResult> {
    await this.initialize();

    const params = new URLSearchParams({
      access_token: this.accessToken!,
    });

    const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${placeId}.json?${params}`;

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Mapbox Place Details API error: ${response.status} ${response.statusText}`);
    }

    const data: any = await response.json();
    const feature = data.features[0];
    
    if (!feature) {
      throw new Error(`Place not found: ${placeId}`);
    }

    return {
      placeName: feature.place_name,
      coordinates: {
        longitude: feature.center[0],
        latitude: feature.center[1],
      },
      context: this.parseContext(feature.context || []),
    };
  }

  private parseContext(contextArray: any[]): any {
    const context: any = {};
    
    for (const item of contextArray) {
      const id = item.id || "";
      if (id.startsWith("address.")) {
        context.address = item.text;
      } else if (id.startsWith("neighborhood.")) {
        context.neighborhood = item.text;
      } else if (id.startsWith("locality.") || id.startsWith("place.")) {
        context.locality = item.text;
      } else if (id.startsWith("region.")) {
        context.region = item.text;
      } else if (id.startsWith("country.")) {
        context.country = item.text;
      } else if (id.startsWith("postcode.")) {
        context.postcode = item.text;
      }
    }
    
    return context;
  }
}

// Singleton instance
export const mapboxGeocodingService = new MapboxGeocodingService();

// Utility functions for common geocoding needs
export async function searchDestinations(query: string, userLocation?: { latitude: number; longitude: number }): Promise<AutocompleteResult[]> {
  return mapboxGeocodingService.autocomplete(query, {
    types: ["place", "locality", "poi"],
    proximityBias: userLocation,
  });
}

export async function getLocationFromCoordinates(latitude: number, longitude: number): Promise<string> {
  const results = await mapboxGeocodingService.reverseGeocode(latitude, longitude, {
    types: ["place", "locality", "address"],
  });
  
  if (results.length === 0) {
    throw new Error("Location not found");
  }
  
  return results[0].address;
}

export async function validateAddress(address: string): Promise<GeocodeResult | null> {
  const results = await mapboxGeocodingService.geocode(address, {
    types: ["address"],
  });
  
  return results.length > 0 ? results[0] : null;
}