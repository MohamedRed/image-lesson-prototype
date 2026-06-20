import { logger } from "firebase-functions";
import { getSecret, secretPath, SECRET_IDS } from "../shared/secretManager";

const RADAR_BASE_URL = "https://api.radar.io/v1";

// Helper class to make Radar API requests
class RadarApiClient {
  private secretKey: string | null = null;

  async getSecretKey(): Promise<string> {
    if (!this.secretKey) {
      this.secretKey = await getSecret(secretPath(SECRET_IDS.RADAR_SECRET_KEY));
    }
    return this.secretKey;
  }

  async makeRequest(
    endpoint: string,
    method: string = "GET",
    body?: any,
    queryParams?: Record<string, string>
  ): Promise<any> {
    const secretKey = await this.getSecretKey();
    
    let url = `${RADAR_BASE_URL}${endpoint}`;
    
    // Add query parameters if provided
    if (queryParams && Object.keys(queryParams).length > 0) {
      const params = new URLSearchParams(queryParams);
      url += `?${params.toString()}`;
    }

    const options: RequestInit = {
      method,
      headers: {
        "Authorization": secretKey,
        "Content-Type": "application/json",
      },
    };

    if (body && method !== "GET") {
      options.body = JSON.stringify(body);
    }

    try {
      const response = await fetch(url, options);
      
      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Radar API error: ${response.status} - ${errorText}`);
      }

      return response.json();
    } catch (error: any) {
      logger.error("Radar API request failed", {
        endpoint,
        method,
        error: error.message,
      });
      throw error;
    }
  }
}

const radarClient = new RadarApiClient();

// Radar webhook event types
export interface RadarWebhookEvent {
  _id: string;
  live: boolean;
  type: string;
  createdAt: string;
  user?: {
    _id: string;
    userId: string;
    description?: string;
    metadata?: Record<string, any>;
  };
  geofence?: {
    _id: string;
    description: string;
    tag: string;
    externalId?: string;
    metadata?: Record<string, any>;
    geometry: {
      type: string;
      coordinates: number[][] | number[][][];
    };
  };
  location?: {
    type: string;
    coordinates: [number, number]; // [lng, lat]
  };
  confidence?: number;
  trip?: {
    _id: string;
    externalId: string;
    metadata?: Record<string, any>;
    status: string;
  };
}

// Geofence management
export interface CreateGeofenceParams {
  description: string;
  tag: string;
  externalId?: string;
  type: 'circle' | 'polygon';
  coordinates?: number[] | number[][];
  radius?: number; // meters, for circle type
  metadata?: Record<string, any>;
}

export interface GeofenceResponse {
  _id: string;
  description: string;
  tag: string;
  externalId?: string;
  type: string;
  geometry: {
    type: string;
    coordinates: number[][] | number[][][];
  };
  metadata?: Record<string, any>;
  createdAt: string;
  updatedAt: string;
}

export class RadarGeofenceService {
  
  static async createGeofence(params: CreateGeofenceParams): Promise<GeofenceResponse> {
    try {
      const body: any = {
        description: params.description,
        type: params.type,
        metadata: params.metadata || {},
      };

      if (params.type === 'circle') {
        if (!params.coordinates || !params.radius) {
          throw new Error("Circle geofences require coordinates and radius");
        }
        body.coordinates = params.coordinates;
        body.radius = params.radius;
      } else if (params.type === 'polygon') {
        if (!params.coordinates) {
          throw new Error("Polygon geofences require coordinates");
        }
        body.coordinates = params.coordinates;
      }

      const endpoint = `/geofences/${params.tag}/${params.externalId}`;
      const response = await radarClient.makeRequest(endpoint, "PUT", body);
      
      logger.info("Geofence created successfully", {
        geofenceId: response.geofence._id,
        tag: params.tag,
        description: params.description,
      });

      return response.geofence;
      
    } catch (error: any) {
      logger.error("Failed to create geofence", {
        error: error.message,
        params,
      });
      throw new Error(`Geofence creation failed: ${error.message}`);
    }
  }

  static async updateGeofence(geofenceId: string, updates: Partial<CreateGeofenceParams>): Promise<GeofenceResponse> {
    try {
      const body: any = {};
      
      if (updates.description) body.description = updates.description;
      if (updates.type) body.type = updates.type;
      if (updates.coordinates) body.coordinates = updates.coordinates;
      if (updates.radius) body.radius = updates.radius;
      if (updates.metadata) body.metadata = updates.metadata;

      const endpoint = `/geofences/${geofenceId}`;
      const response = await radarClient.makeRequest(endpoint, "PUT", body);
      
      logger.info("Geofence updated successfully", {
        geofenceId,
        updates,
      });

      return response.geofence;
      
    } catch (error: any) {
      logger.error("Failed to update geofence", {
        geofenceId,
        error: error.message,
        updates,
      });
      throw new Error(`Geofence update failed: ${error.message}`);
    }
  }

  static async deleteGeofence(geofenceId: string): Promise<void> {
    try {
      const endpoint = `/geofences/${geofenceId}`;
      await radarClient.makeRequest(endpoint, "DELETE");
      
      logger.info("Geofence deleted successfully", { geofenceId });
      
    } catch (error: any) {
      logger.error("Failed to delete geofence", {
        geofenceId,
        error: error.message,
      });
      throw new Error(`Geofence deletion failed: ${error.message}`);
    }
  }

  static async listGeofences(tag?: string, limit = 100): Promise<GeofenceResponse[]> {
    try {
      const queryParams: Record<string, string> = { limit: limit.toString() };
      if (tag) {
        queryParams.tag = tag;
      }

      const endpoint = `/geofences`;
      const response = await radarClient.makeRequest(endpoint, "GET", null, queryParams);
      
      logger.info("Geofences retrieved successfully", {
        count: response.geofences?.length || 0,
        tag,
      });

      return response.geofences || [];
      
    } catch (error: any) {
      logger.error("Failed to list geofences", {
        error: error.message,
        tag,
      });
      throw new Error(`Geofence listing failed: ${error.message}`);
    }
  }

  static async getGeofence(geofenceId: string): Promise<GeofenceResponse> {
    try {
      const endpoint = `/geofences/${geofenceId}`;
      const response = await radarClient.makeRequest(endpoint, "GET");
      
      logger.info("Geofence retrieved successfully", { geofenceId });

      return response.geofence;
      
    } catch (error: any) {
      logger.error("Failed to get geofence", {
        geofenceId,
        error: error.message,
      });
      throw new Error(`Geofence retrieval failed: ${error.message}`);
    }
  }
}

// User management for server-side operations
export class RadarUserService {
  
  static async updateUser(userId: string, updates: {
    description?: string;
    metadata?: Record<string, any>;
  }): Promise<any> {
    try {
      // Radar doesn't have a direct update user endpoint via REST API
      // We'll use the track endpoint to update user metadata
      const body = {
        userId,
        deviceId: userId, // Use userId as deviceId for server-side tracking
        latitude: 0, // Required but won't change location if accuracy is high
        longitude: 0,
        accuracy: 999999, // Very high accuracy means location won't be used
        description: updates.description,
        metadata: updates.metadata,
      };

      const endpoint = `/track`;
      const response = await radarClient.makeRequest(endpoint, "POST", body);
      
      logger.info("User updated successfully via track", {
        userId,
        updates,
      });

      return response.user;
      
    } catch (error: any) {
      logger.error("Failed to update user", {
        userId,
        error: error.message,
        updates,
      });
      throw new Error(`User update failed: ${error.message}`);
    }
  }

  static async deleteUser(userId: string): Promise<void> {
    try {
      const endpoint = `/users/${userId}`;
      await radarClient.makeRequest(endpoint, "DELETE");
      
      logger.info("User deleted successfully", { userId });
      
    } catch (error: any) {
      logger.error("Failed to delete user", {
        userId,
        error: error.message,
      });
      throw new Error(`User deletion failed: ${error.message}`);
    }
  }

  static async getUser(userId: string): Promise<any> {
    try {
      const endpoint = `/users/${userId}`;
      const response = await radarClient.makeRequest(endpoint, "GET");
      
      logger.info("User retrieved successfully", { userId });

      return response.user;
      
    } catch (error: any) {
      logger.error("Failed to get user", {
        userId,
        error: error.message,
      });
      throw new Error(`User retrieval failed: ${error.message}`);
    }
  }
}

// Trip tracking for ride-sharing
export interface TripOptions {
  externalId: string;
  metadata?: Record<string, any>;
  destinationGeofenceTag?: string;
  destinationGeofenceExternalId?: string;
  mode?: 'car' | 'foot' | 'bike';
  approachingThreshold?: number;
}

export class RadarTripService {
  
  static async startTrip(userId: string, options: TripOptions): Promise<any> {
    try {
      const body: any = {
        externalId: options.externalId,
        userId,
        mode: options.mode || 'car',
        metadata: options.metadata,
      };

      if (options.destinationGeofenceTag) {
        body.destinationGeofenceTag = options.destinationGeofenceTag;
      }
      if (options.destinationGeofenceExternalId) {
        body.destinationGeofenceExternalId = options.destinationGeofenceExternalId;
      }
      if (options.approachingThreshold) {
        body.approachingThreshold = options.approachingThreshold;
      }

      const endpoint = `/trips`;
      const response = await radarClient.makeRequest(endpoint, "POST", body);
      
      logger.info("Trip started successfully", {
        userId,
        tripId: response.trip._id,
        externalId: options.externalId,
      });

      return response.trip;
      
    } catch (error: any) {
      logger.error("Failed to start trip", {
        userId,
        error: error.message,
        options,
      });
      throw new Error(`Trip start failed: ${error.message}`);
    }
  }

  static async completeTrip(userId: string, tripExternalId: string): Promise<any> {
    try {
      const body = {
        status: 'completed',
      };

      const endpoint = `/trips/${tripExternalId}/update`;
      const response = await radarClient.makeRequest(endpoint, "PATCH", body);
      
      logger.info("Trip completed successfully", {
        userId,
        tripExternalId,
      });

      return response.trip;
      
    } catch (error: any) {
      logger.error("Failed to complete trip", {
        userId,
        tripExternalId,
        error: error.message,
      });
      throw new Error(`Trip completion failed: ${error.message}`);
    }
  }

  static async cancelTrip(userId: string, tripExternalId: string): Promise<any> {
    try {
      const body = {
        status: 'canceled',
      };

      const endpoint = `/trips/${tripExternalId}/update`;
      const response = await radarClient.makeRequest(endpoint, "PATCH", body);
      
      logger.info("Trip cancelled successfully", {
        userId,
        tripExternalId,
      });

      return response.trip;
      
    } catch (error: any) {
      logger.error("Failed to cancel trip", {
        userId,
        tripExternalId,
        error: error.message,
      });
      throw new Error(`Trip cancellation failed: ${error.message}`);
    }
  }

  static async getTrip(tripExternalId: string): Promise<any> {
    try {
      const endpoint = `/trips/${tripExternalId}`;
      const response = await radarClient.makeRequest(endpoint, "GET");
      
      logger.info("Trip retrieved successfully", {
        tripExternalId,
      });

      return response.trip;
      
    } catch (error: any) {
      logger.error("Failed to get trip", {
        tripExternalId,
        error: error.message,
      });
      throw new Error(`Trip retrieval failed: ${error.message}`);
    }
  }
}

// Location tracking
export class RadarTrackingService {
  
  static async trackLocation(params: {
    userId?: string;
    deviceId: string;
    latitude: number;
    longitude: number;
    accuracy: number;
    metadata?: Record<string, any>;
    foreground?: boolean;
    stopped?: boolean;
  }): Promise<any> {
    try {
      const body: any = {
        deviceId: params.deviceId,
        latitude: params.latitude,
        longitude: params.longitude,
        accuracy: params.accuracy,
        foreground: params.foreground,
        stopped: params.stopped,
        metadata: params.metadata,
      };

      if (params.userId) {
        body.userId = params.userId;
      }

      const endpoint = `/track`;
      const response = await radarClient.makeRequest(endpoint, "POST", body);
      
      logger.info("Location tracked successfully", {
        userId: params.userId,
        deviceId: params.deviceId,
        location: { lat: params.latitude, lng: params.longitude },
      });

      return response;
      
    } catch (error: any) {
      logger.error("Failed to track location", {
        params,
        error: error.message,
      });
      throw new Error(`Location tracking failed: ${error.message}`);
    }
  }
}

// Search functionality
export class RadarSearchService {
  
  static async searchGeofences(params: {
    near: string; // "latitude,longitude"
    radius?: number;
    tags?: string[];
    metadata?: Record<string, any>;
    limit?: number;
  }): Promise<GeofenceResponse[]> {
    try {
      const queryParams: Record<string, string> = {
        near: params.near,
      };

      if (params.radius) queryParams.radius = params.radius.toString();
      if (params.tags) queryParams.tags = params.tags.join(',');
      if (params.limit) queryParams.limit = params.limit.toString();
      
      // Add metadata filters
      if (params.metadata) {
        Object.entries(params.metadata).forEach(([key, value]) => {
          queryParams[`metadata[${key}]`] = String(value);
        });
      }

      const endpoint = `/search/geofences`;
      const response = await radarClient.makeRequest(endpoint, "GET", null, queryParams);
      
      logger.info("Geofences searched successfully", {
        near: params.near,
        count: response.geofences?.length || 0,
      });

      return response.geofences || [];
      
    } catch (error: any) {
      logger.error("Failed to search geofences", {
        params,
        error: error.message,
      });
      throw new Error(`Geofence search failed: ${error.message}`);
    }
  }

  static async searchUsers(params: {
    near: string; // "latitude,longitude"
    radius?: number;
    metadata?: Record<string, any>;
    limit?: number;
  }): Promise<any[]> {
    try {
      const queryParams: Record<string, string> = {
        near: params.near,
      };

      if (params.radius) queryParams.radius = params.radius.toString();
      if (params.limit) queryParams.limit = params.limit.toString();
      
      // Add metadata filters
      if (params.metadata) {
        Object.entries(params.metadata).forEach(([key, value]) => {
          queryParams[`metadata[${key}]`] = String(value);
        });
      }

      const endpoint = `/search/users`;
      const response = await radarClient.makeRequest(endpoint, "GET", null, queryParams);
      
      logger.info("Users searched successfully", {
        near: params.near,
        count: response.users?.length || 0,
      });

      return response.users || [];
      
    } catch (error: any) {
      logger.error("Failed to search users", {
        params,
        error: error.message,
      });
      throw new Error(`User search failed: ${error.message}`);
    }
  }
}