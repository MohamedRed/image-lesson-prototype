import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { 
  Activity,
  ActivityGroup,
  ActivitySession
} from './models';
import { incrementCounter } from '../shared/metrics';
import { haversineKm } from '../shared/geoHelpers';
import { getSecret, secretPath, SECRET_IDS } from '../shared/secretManager';

const db = admin.firestore();

// Generate navigation routes to activity location
export const generateActivityRoute = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { activityId, userLocation, transportMode = 'driving' } = data;

  if (!activityId || !userLocation) {
    throw new functions.https.HttpsError('invalid-argument', 'Activity ID and user location required');
  }

  try {
    // Get activity details
    const activityDoc = await db.collection('activities').doc(activityId).get();
    if (!activityDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Activity not found');
    }

    const activity = activityDoc.data() as Activity;
    const destination = activity.location;

    // Get Mapbox access token
    const mapboxToken = await getSecret(secretPath(SECRET_IDS.MAPBOX_ACCESS_TOKEN));

    // Build Mapbox Directions API request
    const origin = `${userLocation.longitude},${userLocation.latitude}`;
    const dest = `${destination.lng},${destination.lat}`;
    const profile = getMapboxProfile(transportMode);

    const directionsUrl = `https://api.mapbox.com/directions/v5/mapbox/${profile}/${origin};${dest}` +
      `?geometries=geojson&steps=true&voice_instructions=true&banner_instructions=true&access_token=${mapboxToken}`;

    const response = await fetch(directionsUrl);
    const directionsData = await response.json();

    if (!response.ok || !directionsData.routes || directionsData.routes.length === 0) {
      throw new Error('No route found');
    }

    const route = directionsData.routes[0];
    
    // Extract route information
    const routeInfo = {
      distance: route.distance, // meters
      duration: route.duration, // seconds
      geometry: route.geometry,
      steps: route.legs[0]?.steps || [],
      voiceInstructions: extractVoiceInstructions(route),
      bannerInstructions: extractBannerInstructions(route)
    };

    // Generate alternative transport options
    const alternatives = await generateTransportAlternatives(userLocation, destination);

    // Create deep links for different navigation apps
    const navigationLinks = generateNavigationDeepLinks(userLocation, destination, activity.title);

    await incrementCounter('activities_navigation_routes_generated', 1);

    return {
      route: routeInfo,
      alternatives,
      navigationLinks,
      activity: {
        id: activity.id,
        title: activity.title,
        address: activity.location.address,
        coordinates: {
          lat: destination.lat,
          lng: destination.lng
        }
      }
    };

  } catch (error) {
    logger.error('Error generating activity route:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to generate route');
  }
});

// Get nearby transit options to activity
export const getNearbyTransit = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { activityId, userLocation } = data;

  if (!activityId || !userLocation) {
    throw new functions.https.HttpsError('invalid-argument', 'Activity ID and user location required');
  }

  try {
    // Get activity details
    const activityDoc = await db.collection('activities').doc(activityId).get();
    if (!activityDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Activity not found');
    }

    const activity = activityDoc.data() as Activity;
    const destination = activity.location;

    // Get nearby transit stations using Mapbox
    const mapboxToken = await getSecret(secretPath(SECRET_IDS.MAPBOX_ACCESS_TOKEN));
    
    // Search for transit stations near user
    const nearbyStationsUser = await findNearbyTransit(userLocation, mapboxToken);
    
    // Search for transit stations near destination
    const nearbyStationsDest = await findNearbyTransit(destination, mapboxToken);

    // Calculate walking distances and times
    const transitOptions = await calculateTransitOptions(
      userLocation,
      destination,
      nearbyStationsUser,
      nearbyStationsDest
    );

    return {
      transitOptions,
      walkingDistance: haversineKm(
        userLocation.latitude,
        userLocation.longitude,
        destination.lat,
        destination.lng
      ),
      activity: {
        id: activity.id,
        title: activity.title,
        address: activity.location.address
      }
    };

  } catch (error) {
    logger.error('Error getting nearby transit:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to get transit options');
  }
});

// Share location during group activity
export const shareLocationWithGroup = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { groupId, location, status = 'traveling' } = data;

  if (!groupId || !location) {
    throw new functions.https.HttpsError('invalid-argument', 'Group ID and location required');
  }

  try {
    // Verify user is in group
    const groupDoc = await db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const group = groupDoc.data() as ActivityGroup;
    if (!group.participantUserIds.includes(context.auth.uid)) {
      throw new functions.https.HttpsError('permission-denied', 'Not a group member');
    }

    // Update user's location share
    await db.collection('groupLocationShares').doc(`${groupId}_${context.auth.uid}`).set({
      groupId,
      userId: context.auth.uid,
      location: new admin.firestore.GeoPoint(location.latitude, location.longitude),
      status, // 'traveling', 'arrived', 'waiting'
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 2 * 60 * 60 * 1000) // 2 hours
      )
    });

    // Send location update to group chat if enabled
    if (group.chatThreadId && status === 'arrived') {
      await sendLocationUpdateMessage(group.chatThreadId, context.auth.uid, status);
    }

    await incrementCounter('activities_location_shares_updated', 1);

    return { success: true };

  } catch (error) {
    logger.error('Error sharing location with group:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to share location');
  }
});

// Get group members' locations
export const getGroupMemberLocations = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { groupId } = data;

  if (!groupId) {
    throw new functions.https.HttpsError('invalid-argument', 'Group ID required');
  }

  try {
    // Verify user is in group
    const groupDoc = await db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const group = groupDoc.data() as ActivityGroup;
    if (!group.participantUserIds.includes(context.auth.uid)) {
      throw new functions.https.HttpsError('permission-denied', 'Not a group member');
    }

    // Get active location shares
    const locationShares = await db.collection('groupLocationShares')
      .where('groupId', '==', groupId)
      .where('expiresAt', '>', admin.firestore.Timestamp.now())
      .get();

    const memberLocations = locationShares.docs.map(doc => {
      const data = doc.data();
      return {
        userId: data.userId,
        location: {
          latitude: data.location.latitude,
          longitude: data.location.longitude
        },
        status: data.status,
        timestamp: data.timestamp.toDate(),
        isCurrentUser: data.userId === context.auth!.uid
      };
    });

    return { memberLocations };

  } catch (error) {
    logger.error('Error getting group member locations:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to get member locations');
  }
});

// Helper functions
function getMapboxProfile(transportMode: string): string {
  switch (transportMode) {
    case 'walking':
      return 'walking';
    case 'cycling':
      return 'cycling';
    case 'driving':
    default:
      return 'driving';
  }
}

function extractVoiceInstructions(route: any): any[] {
  const instructions: any[] = [];
  
  if (route.legs) {
    route.legs.forEach((leg: any) => {
      if (leg.steps) {
        leg.steps.forEach((step: any) => {
          if (step.voiceInstructions) {
            instructions.push(...step.voiceInstructions);
          }
        });
      }
    });
  }
  
  return instructions;
}

function extractBannerInstructions(route: any): any[] {
  const instructions: any[] = [];
  
  if (route.legs) {
    route.legs.forEach((leg: any) => {
      if (leg.steps) {
        leg.steps.forEach((step: any) => {
          if (step.bannerInstructions) {
            instructions.push(...step.bannerInstructions);
          }
        });
      }
    });
  }
  
  return instructions;
}

async function generateTransportAlternatives(origin: any, destination: any): Promise<any[]> {
  const alternatives = [];
  
  // Calculate walking distance and time
  const walkingDistance = haversineKm(
    origin.latitude,
    origin.longitude,
    destination.lat,
    destination.lng
  );
  
  // Walking option
  alternatives.push({
    mode: 'walking',
    distance: walkingDistance,
    duration: Math.ceil(walkingDistance * 12 * 60), // 5 km/h walking speed in seconds
    emissions: 0,
    cost: 0,
    description: 'Walk to destination'
  });

  // Cycling option (if reasonable distance)
  if (walkingDistance <= 10) {
    alternatives.push({
      mode: 'cycling',
      distance: walkingDistance,
      duration: Math.ceil(walkingDistance * 4 * 60), // 15 km/h cycling speed in seconds
      emissions: 0,
      cost: 0,
      description: 'Cycle to destination'
    });
  }

  // Transit estimate (simplified)
  if (walkingDistance > 2) {
    alternatives.push({
      mode: 'transit',
      distance: walkingDistance * 1.3, // Add overhead for transit routes
      duration: Math.ceil(walkingDistance * 6 * 60), // Estimate including waiting
      emissions: walkingDistance * 50, // grams CO2
      cost: 5, // MAD estimate
      description: 'Take public transport'
    });
  }

  return alternatives;
}

function generateNavigationDeepLinks(origin: any, destination: any, activityTitle: string) {
  const destCoords = `${destination.lat},${destination.lng}`;
  const originCoords = `${origin.latitude},${origin.longitude}`;
  
  return {
    googleMaps: `https://www.google.com/maps/dir/?api=1&origin=${originCoords}&destination=${destCoords}&travelmode=driving`,
    appleMaps: `http://maps.apple.com/?saddr=${originCoords}&daddr=${destCoords}&dirflg=d`,
    waze: `https://waze.com/ul?ll=${destCoords}&navigate=yes&zoom=17`,
    citymapper: `https://citymapper.com/directions?endcoord=${destCoords}&startcoord=${originCoords}`,
    liiveInApp: `liive://navigation?destination=${destCoords}&title=${encodeURIComponent(activityTitle)}`
  };
}

async function findNearbyTransit(location: any, mapboxToken: string): Promise<any[]> {
  // Use Mapbox Geocoding API to find nearby transit stations
  const searchUrl = `https://api.mapbox.com/geocoding/v5/mapbox.places/transit.json` +
    `?proximity=${location.lng || location.longitude},${location.lat || location.latitude}` +
    `&limit=5&access_token=${mapboxToken}`;

  try {
    const response = await fetch(searchUrl);
    const data = await response.json();
    
    return data.features || [];
  } catch (error) {
    logger.warn('Error finding nearby transit:', error);
    return [];
  }
}

async function calculateTransitOptions(origin: any, destination: any, stationsNearOrigin: any[], stationsNearDest: any[]): Promise<any[]> {
  const options: any[] = [];
  
  for (const originStation of stationsNearOrigin.slice(0, 3)) {
    for (const destStation of stationsNearDest.slice(0, 3)) {
      // Calculate walking distances
      const walkToStation = haversineKm(
        origin.latitude,
        origin.longitude,
        originStation.center[1],
        originStation.center[0]
      );
      
      const walkFromStation = haversineKm(
        destStation.center[1],
        destStation.center[0],
        destination.lat,
        destination.lng
      );
      
      // Estimate transit time (simplified)
      const transitDistance = haversineKm(
        originStation.center[1],
        originStation.center[0],
        destStation.center[1],
        destStation.center[0]
      );
      
      const totalWalkingTime = (walkToStation + walkFromStation) * 12; // 5 km/h in minutes
      const transitTime = transitDistance * 2; // 30 km/h average in minutes
      const waitingTime = 10; // 10 minutes average wait
      
      options.push({
        originStation: {
          name: originStation.text,
          walkingDistance: walkToStation,
          walkingTime: walkToStation * 12
        },
        destStation: {
          name: destStation.text,
          walkingDistance: walkFromStation,
          walkingTime: walkFromStation * 12
        },
        totalTime: totalWalkingTime + transitTime + waitingTime,
        estimatedCost: 5 // MAD
      });
    }
  }
  
  return options.sort((a, b) => a.totalTime - b.totalTime).slice(0, 3);
}

async function sendLocationUpdateMessage(conversationId: string, userId: string, status: string): Promise<void> {
  const statusMessages = {
    arrived: '📍 I\'ve arrived at the activity location!',
    traveling: '🚶‍♂️ On my way to the activity',
    waiting: '⏰ Waiting at the meeting point'
  };

  const message = {
    conversationId,
    senderId: userId,
    text: statusMessages[status as keyof typeof statusMessages] || statusMessages.traveling,
    type: 'location_update',
    replyToId: null,
    attachments: [],
    reactions: {},
    editHistory: [],
    isDeleted: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('messages').add(message);
}

// Clean up expired location shares
export const cleanupExpiredLocationShares = functions.pubsub
  .schedule('every 30 minutes')
  .onRun(async (context) => {
    try {
      const cutoff = admin.firestore.Timestamp.now();
      const expiredShares = await db.collection('groupLocationShares')
        .where('expiresAt', '<', cutoff)
        .limit(100)
        .get();

      const batch = db.batch();
      expiredShares.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      logger.info(`Cleaned up ${expiredShares.size} expired location shares`);
      return { cleaned: expiredShares.size };
    } catch (error) {
      logger.error('Error cleaning up expired location shares:', error);
      throw error;
    }
  });