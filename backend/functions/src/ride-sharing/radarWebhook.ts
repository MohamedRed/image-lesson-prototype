import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { RadarWebhookEvent } from "../services/location/radarService";

try { admin.app(); } catch { admin.initializeApp(); }

/**
 * Radar Webhook Handler
 * Processes Radar events for geofence entries/exits, location updates, and trip events
 */
export const radarWebhook = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method not allowed");
    return;
  }

  try {
    const event = req.body as RadarWebhookEvent;
    
    logger.info("Radar webhook received", {
      eventType: event.type,
      userId: event.user?.userId,
      live: event.live,
    });

    // Only process live events in production
    if (!event.live && process.env.NODE_ENV === "production") {
      logger.info("Ignoring test event in production");
      res.json({ received: true });
      return;
    }

    switch (event.type) {
      case "user.entered_geofence":
        await handleGeofenceEntry(event);
        break;
        
      case "user.exited_geofence":
        await handleGeofenceExit(event);
        break;
        
      case "user.approaching_trip_destination":
        await handleTripDestinationApproach(event);
        break;
        
      case "user.arrived_at_trip_destination":
        await handleTripDestinationArrival(event);
        break;
        
      case "user.stopped_trip":
        await handleTripStopped(event);
        break;
        
      case "user.updated_location":
        await handleLocationUpdate(event);
        break;
        
      default:
        logger.info("Unhandled Radar event type", { type: event.type });
    }

    res.json({ received: true });
    
  } catch (error: any) {
    logger.error("Radar webhook processing failed", {
      error: error.message,
      body: req.body,
    });
    res.status(500).json({ error: "Webhook processing failed" });
  }
});

/**
 * Handle user entering a geofence (pickup zone)
 */
async function handleGeofenceEntry(event: RadarWebhookEvent): Promise<void> {
  if (!event.user?.userId || !event.geofence) return;

  const db = admin.firestore();
  
  try {
    // Check if this is a pickup zone geofence
    if (event.geofence.tag === "pickup_zone") {
      const userId = event.user.userId;
      const pickupZoneId = event.geofence.externalId;
      
      logger.info("User entered pickup zone", {
        userId,
        pickupZoneId,
        geofenceId: event.geofence._id,
      });
      
      // Update active rides where this user is involved
      const activeRidesQuery = await db.collection("rideRequests")
        .where("state", "in", ["riderPickupSoon", "driverEnroute"])
        .where("creatorUid", "==", userId.replace("rider_", "").replace("driver_", ""))
        .get();
      
      for (const rideDoc of activeRidesQuery.docs) {
        await rideDoc.ref.update({
          [`radarEvents.${userId}_entered_pickup`]: {
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            geofenceId: event.geofence._id,
            pickupZoneId,
          }
        });
      }
    }
  } catch (error: any) {
    logger.error("Failed to handle geofence entry", {
      error: error.message,
      userId: event.user.userId,
      geofenceId: event.geofence._id,
    });
  }
}

/**
 * Handle user exiting a geofence
 */
async function handleGeofenceExit(event: RadarWebhookEvent): Promise<void> {
  if (!event.user?.userId || !event.geofence) return;

  logger.info("User exited geofence", {
    userId: event.user.userId,
    geofenceId: event.geofence._id,
    tag: event.geofence.tag,
  });
  
  // Could be used to track when drivers leave pickup zones
  // or when riders move away from their intended pickup point
}

/**
 * Handle trip destination approach
 */
async function handleTripDestinationApproach(event: RadarWebhookEvent): Promise<void> {
  if (!event.user?.userId || !event.trip) return;

  const db = admin.firestore();
  const rideRequestId = event.trip.externalId;
  
  try {
    const rideRef = db.doc(`rideRequests/${rideRequestId}`);
    const rideSnap = await rideRef.get();
    
    if (!rideSnap.exists) {
      logger.warn("Ride not found for trip destination approach", { rideRequestId });
      return;
    }

    await rideRef.update({
      [`radarEvents.${event.user.userId}_approaching`]: {
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        tripId: event.trip._id,
      }
    });

    logger.info("Trip destination approach recorded", {
      userId: event.user.userId,
      rideRequestId,
      tripId: event.trip._id,
    });
    
  } catch (error: any) {
    logger.error("Failed to handle trip destination approach", {
      error: error.message,
      userId: event.user.userId,
      tripId: event.trip._id,
    });
  }
}

/**
 * Handle trip destination arrival
 */
async function handleTripDestinationArrival(event: RadarWebhookEvent): Promise<void> {
  if (!event.user?.userId || !event.trip) return;

  const db = admin.firestore();
  const rideRequestId = event.trip.externalId;
  
  try {
    const rideRef = db.doc(`rideRequests/${rideRequestId}`);
    const rideSnap = await rideRef.get();
    
    if (!rideSnap.exists) {
      logger.warn("Ride not found for trip destination arrival", { rideRequestId });
      return;
    }

    const rideData = rideSnap.data()!;
    
    // Determine next state based on who arrived
    let nextState = rideData.state;
    const userId = event.user.userId;
    
    if (userId.startsWith("driver_") && rideData.state === "riderPickupSoon") {
      nextState = "driverArrived";
    } else if (userId.startsWith("rider_") && rideData.state === "driverArrived") {
      nextState = "inProgress";
    }

    await rideRef.update({
      state: nextState,
      [`radarEvents.${userId}_arrived`]: {
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        tripId: event.trip._id,
      }
    });

    logger.info("Trip destination arrival handled", {
      userId,
      rideRequestId,
      previousState: rideData.state,
      nextState,
      tripId: event.trip._id,
    });
    
  } catch (error: any) {
    logger.error("Failed to handle trip destination arrival", {
      error: error.message,
      userId: event.user.userId,
      tripId: event.trip._id,
    });
  }
}

/**
 * Handle trip stopped event
 */
async function handleTripStopped(event: RadarWebhookEvent): Promise<void> {
  if (!event.user?.userId || !event.trip) return;

  logger.info("Trip stopped", {
    userId: event.user.userId,
    tripId: event.trip._id,
    externalId: event.trip.externalId,
    status: event.trip.status,
  });
  
  // This could be used to detect if a trip was cancelled or completed
  // Additional logic could be added to update ride state accordingly
}

/**
 * Handle location update events
 */
async function handleLocationUpdate(event: RadarWebhookEvent): Promise<void> {
  if (!event.user?.userId || !event.location) return;

  // Only log significant location updates to avoid spam
  logger.debug("Location update received", {
    userId: event.user.userId,
    coordinates: event.location.coordinates,
    confidence: event.confidence,
  });
  
  // Could be used for real-time location tracking
  // or to update driver positions in Firestore
}