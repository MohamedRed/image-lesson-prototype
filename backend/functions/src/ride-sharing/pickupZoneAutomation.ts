import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";
import { RadarGeofenceService, CreateGeofenceParams } from "../services/location/radarService";
import { slackNotify } from "../shared/curbImport";

try { admin.app(); } catch { admin.initializeApp(); }

interface CurbSegmentData {
  id: string;
  geometry: {
    type: string;
    coordinates: number[][] | number[][][];
  };
  allowedUses: string[];
  maxStopSeconds: number;
  updatedAt: admin.firestore.Timestamp;
}

interface PickupZone {
  id: string;
  radarGeofenceId?: string;
  curbSegmentId: string;
  capacityCars: number;
  activePickups: number;
  geometry: any;
  isActive: boolean;
  lastOptimizedAt?: admin.firestore.Timestamp;
  createdAt: admin.firestore.Timestamp;
}

/**
 * Automated Pickup Zone Management Service
 * 
 * This service automatically creates and manages pickup zones based on:
 * 1. Legal curb segments from Mapbox
 * 2. Real-time demand patterns
 * 3. Congestion levels
 * 4. Driver utilization data
 */
export class PickupZoneAutomationService {

  /**
   * Creates pickup zones from curb segments that allow passenger pickup
   */
  static async createPickupZonesFromCurbSegments(
    db: admin.firestore.Firestore = admin.firestore()
  ): Promise<number> {
    let createdCount = 0;
    
    try {
      // Get all curb segments that allow passenger pickup
      const curbSegments = await db.collection('curbSegments')
        .where('allowedUses', 'array-contains', 'passenger-pickup')
        .get();

      logger.info("Processing curb segments for pickup zone creation", {
        segmentCount: curbSegments.size,
      });

      for (const segmentDoc of curbSegments.docs) {
        const segmentData = segmentDoc.data() as CurbSegmentData;
        segmentData.id = segmentDoc.id;

        // Check if pickup zone already exists for this segment
        const existingZone = await db.collection('pickupZones')
          .where('curbSegmentId', '==', segmentData.id)
          .limit(1)
          .get();

        if (!existingZone.empty) {
          logger.debug("Pickup zone already exists for curb segment", {
            segmentId: segmentData.id,
          });
          continue;
        }

        try {
          const zone = await this.createPickupZoneFromSegment(segmentData, db);
          if (zone) {
            createdCount++;
            logger.info("Created pickup zone from curb segment", {
              zoneId: zone.id,
              segmentId: segmentData.id,
              geofenceId: zone.radarGeofenceId,
            });
          }
        } catch (error: any) {
          logger.error("Failed to create pickup zone from segment", {
            segmentId: segmentData.id,
            error: error.message,
          });
        }
      }

      return createdCount;

    } catch (error: any) {
      logger.error("Failed to create pickup zones from curb segments", {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Creates a single pickup zone from a curb segment
   */
  private static async createPickupZoneFromSegment(
    segment: CurbSegmentData,
    db: admin.firestore.Firestore
  ): Promise<PickupZone | null> {
    
    try {
      // Calculate capacity based on curb segment properties
      const capacity = this.calculateCapacityFromSegment(segment);
      
      // Create Radar geofence for this pickup zone
      // Handle different geometry types
      let coordinates: number[] | number[][] | undefined;
      let geofenceType: 'circle' | 'polygon';
      
      if (segment.geometry.type === 'Point') {
        // For Point geometry, extract the coordinates array
        geofenceType = 'circle';
        // Point coordinates should be [longitude, latitude]
        const coords = segment.geometry.coordinates as number[][];
        coordinates = coords[0]; // Get the first coordinate pair
      } else {
        // For Polygon geometry
        geofenceType = 'polygon';
        coordinates = segment.geometry.coordinates as number[][];
      }
      
      const geofenceParams: CreateGeofenceParams = {
        description: `Pickup Zone - Segment ${segment.id}`,
        tag: `pickup_zone_${segment.id}`,
        externalId: segment.id,
        type: geofenceType,
        coordinates: coordinates,
        radius: geofenceType === 'circle' ? 50 : undefined, // 50m radius for point geometries
        metadata: {
          segmentId: segment.id,
          allowedUses: segment.allowedUses,
          maxStopSeconds: segment.maxStopSeconds,
          capacityCars: capacity,
          createdBy: 'pickup-zone-automation',
          createdAt: new Date().toISOString(),
        },
      };

      const radarGeofence = await RadarGeofenceService.createGeofence(geofenceParams);

      // Create corresponding Firestore pickup zone document
      const pickupZoneData: Omit<PickupZone, 'id'> = {
        radarGeofenceId: radarGeofence._id,
        curbSegmentId: segment.id,
        capacityCars: capacity,
        activePickups: 0,
        geometry: segment.geometry,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp() as admin.firestore.Timestamp,
      };

      const zoneRef = await db.collection('pickupZones').add(pickupZoneData);
      
      return {
        id: zoneRef.id,
        ...pickupZoneData,
      };

    } catch (error: any) {
      logger.error("Failed to create pickup zone from segment", {
        segmentId: segment.id,
        error: error.message,
      });
      return null;
    }
  }

  /**
   * Calculates vehicle capacity for a curb segment based on its properties
   */
  private static calculateCapacityFromSegment(segment: CurbSegmentData): number {
    // Base capacity calculation
    let capacity = 2; // Default minimum capacity

    // Increase capacity based on maximum stop time (longer stops = more capacity)
    if (segment.maxStopSeconds >= 300) { // 5+ minutes
      capacity = 4;
    } else if (segment.maxStopSeconds >= 180) { // 3+ minutes  
      capacity = 3;
    }

    // Adjust based on geometry type and size
    if (segment.geometry.type === 'Polygon') {
      // For polygons, estimate capacity based on area (rough approximation)
      const coordinates = segment.geometry.coordinates as number[][][];
      if (coordinates[0] && coordinates[0].length > 6) {
        capacity += 1; // Larger polygon areas get extra capacity
      }
    }

    // Cap maximum capacity for safety
    return Math.min(capacity, 6);
  }

  /**
   * Optimizes existing pickup zones based on usage patterns and demand
   */
  static async optimizePickupZones(
    db: admin.firestore.Firestore = admin.firestore()
  ): Promise<number> {
    let optimizedCount = 0;

    try {
      // Get pickup zones that haven't been optimized recently
      const cutoff = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 60 * 60 * 1000) // 1 hour ago
      );

      const zones = await db.collection('pickupZones')
        .where('isActive', '==', true)
        .where('lastOptimizedAt', '<', cutoff)
        .limit(50)
        .get();

      logger.info("Optimizing pickup zones", { zoneCount: zones.size });

      for (const zoneDoc of zones.docs) {
        const zoneData = zoneDoc.data() as PickupZone;
        zoneData.id = zoneDoc.id;

        try {
          const wasOptimized = await this.optimizePickupZone(zoneData, db);
          if (wasOptimized) {
            optimizedCount++;
            
            // Update last optimized timestamp
            await zoneDoc.ref.update({
              lastOptimizedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        } catch (error: any) {
          logger.error("Failed to optimize pickup zone", {
            zoneId: zoneData.id,
            error: error.message,
          });
        }
      }

      return optimizedCount;

    } catch (error: any) {
      logger.error("Failed to optimize pickup zones", {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Optimizes a single pickup zone based on recent usage patterns
   */
  private static async optimizePickupZone(
    zone: PickupZone,
    db: admin.firestore.Firestore
  ): Promise<boolean> {
    
    try {
      // Analyze recent ride activity for this zone
      const oneHourAgo = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 60 * 60 * 1000)
      );

      const recentRides = await db.collectionGroup('rideLegs')
        .where('pickupZoneId', '==', zone.id)
        .where('updatedAt', '>=', oneHourAgo)
        .get();

      const demandLevel = recentRides.size;
      const currentCapacity = zone.capacityCars;
      let newCapacity = currentCapacity;
      let shouldUpdateGeofence = false;

      // High demand: increase capacity and potentially expand radius
      if (demandLevel > currentCapacity * 2) {
        newCapacity = Math.min(currentCapacity + 2, 8); // Cap at 8 vehicles
        shouldUpdateGeofence = true;
        
        logger.info("High demand detected, increasing zone capacity", {
          zoneId: zone.id,
          demandLevel,
          oldCapacity: currentCapacity,
          newCapacity,
        });
      }
      // Low demand: decrease capacity to reduce congestion
      else if (demandLevel === 0 && currentCapacity > 2) {
        newCapacity = Math.max(currentCapacity - 1, 2); // Minimum 2 vehicles
        shouldUpdateGeofence = true;
        
        logger.info("Low demand detected, decreasing zone capacity", {
          zoneId: zone.id,
          demandLevel,
          oldCapacity: currentCapacity,
          newCapacity,
        });
      }

      // Update Firestore if capacity changed
      if (newCapacity !== currentCapacity) {
        await db.collection('pickupZones').doc(zone.id).update({
          capacityCars: newCapacity,
          optimizedAt: admin.firestore.FieldValue.serverTimestamp(),
          optimizationReason: demandLevel > currentCapacity * 2 ? 'high_demand' : 'low_demand',
        });
      }

      // Update Radar geofence metadata if needed
      if (shouldUpdateGeofence && zone.radarGeofenceId) {
        await RadarGeofenceService.updateGeofence(zone.radarGeofenceId, {
          metadata: {
            ...zone.geometry.metadata,
            capacityCars: newCapacity,
            lastOptimized: new Date().toISOString(),
            demandLevel,
          },
        });
      }

      return newCapacity !== currentCapacity;

    } catch (error: any) {
      logger.error("Failed to optimize pickup zone", {
        zoneId: zone.id,
        error: error.message,
      });
      return false;
    }
  }

  /**
   * Removes inactive or problematic pickup zones
   */
  static async cleanupPickupZones(
    db: admin.firestore.Firestore = admin.firestore()
  ): Promise<number> {
    let cleanedCount = 0;

    try {
      // Find zones that haven't been used in the last 7 days
      const cutoff = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
      );

      const inactiveZones = await db.collection('pickupZones')
        .where('isActive', '==', true)
        .where('createdAt', '<', cutoff)
        .limit(20)
        .get();

      for (const zoneDoc of inactiveZones.docs) {
        const zoneData = zoneDoc.data() as PickupZone;
        
        // Check if zone has been used recently
        const recentActivity = await db.collectionGroup('rideLegs')
          .where('pickupZoneId', '==', zoneDoc.id)
          .where('updatedAt', '>=', cutoff)
          .limit(1)
          .get();

        if (recentActivity.empty) {
          // No recent activity, mark as inactive
          await zoneDoc.ref.update({
            isActive: false,
            deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
            deactivationReason: 'no_recent_activity',
          });

          // Delete corresponding Radar geofence
          if (zoneData.radarGeofenceId) {
            try {
              await RadarGeofenceService.deleteGeofence(zoneData.radarGeofenceId);
            } catch (error: any) {
              logger.warn("Failed to delete Radar geofence during cleanup", {
                zoneId: zoneDoc.id,
                geofenceId: zoneData.radarGeofenceId,
                error: error.message,
              });
            }
          }

          cleanedCount++;
          logger.info("Deactivated inactive pickup zone", {
            zoneId: zoneDoc.id,
            daysSinceCreation: Math.floor((Date.now() - zoneData.createdAt.toMillis()) / (24 * 60 * 60 * 1000)),
          });
        }
      }

      return cleanedCount;

    } catch (error: any) {
      logger.error("Failed to cleanup pickup zones", {
        error: error.message,
      });
      throw error;
    }
  }
}

/**
 * Scheduled function to create pickup zones from new curb segments
 * Runs every 6 hours to process new curb data
 */
export const createPickupZones = withMetrics("createPickupZones", 
  onSchedule("0 */6 * * *", async () => {
    try {
      const createdCount = await PickupZoneAutomationService.createPickupZonesFromCurbSegments();
      
      logger.info("Pickup zone creation completed", { createdCount });
      
      if (createdCount > 0) {
        await slackNotify(
          `✅ Created ${createdCount} new pickup zones from curb segments`
        );
      }
    } catch (error: any) {
      logger.error("Pickup zone creation failed", { error: error.message });
      await slackNotify(
        `❌ Pickup zone creation failed: ${error.message}`
      );
    }
  })
);

/**
 * Scheduled function to optimize existing pickup zones
 * Runs every 15 minutes to adjust capacity based on demand
 */
export const optimizePickupZones = withMetrics("optimizePickupZones",
  onSchedule("*/15 * * * *", async () => {
    try {
      const optimizedCount = await PickupZoneAutomationService.optimizePickupZones();
      
      logger.info("Pickup zone optimization completed", { optimizedCount });
      
      if (optimizedCount > 5) {
        await slackNotify(
          `🔧 Optimized ${optimizedCount} pickup zones based on demand patterns`
        );
      }
    } catch (error: any) {
      logger.error("Pickup zone optimization failed", { error: error.message });
      await slackNotify(
        `❌ Pickup zone optimization failed: ${error.message}`
      );
    }
  })
);

/**
 * Scheduled function to cleanup inactive pickup zones
 * Runs daily at 2 AM to remove unused zones
 */
export const cleanupPickupZones = withMetrics("cleanupPickupZones",
  onSchedule("0 2 * * *", async () => {
    try {
      const cleanedCount = await PickupZoneAutomationService.cleanupPickupZones();
      
      logger.info("Pickup zone cleanup completed", { cleanedCount });
      
      if (cleanedCount > 0) {
        await slackNotify(
          `🧹 Cleaned up ${cleanedCount} inactive pickup zones`
        );
      }
    } catch (error: any) {
      logger.error("Pickup zone cleanup failed", { error: error.message });
      await slackNotify(
        `❌ Pickup zone cleanup failed: ${error.message}`
      );
    }
  })
);