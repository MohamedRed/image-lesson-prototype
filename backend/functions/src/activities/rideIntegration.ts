import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { 
  ActivityGroup,
  Booking,
  Activity,
  ActivitySession
} from './models';
import { incrementCounter } from '../shared/metrics';
import { haversineKm } from '../shared/geoHelpers';

const db = admin.firestore();

// Generate meet-up point suggestions for activity groups
export const suggestMeetupPoints = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { groupId, activityLocation } = data;

  if (!groupId || !activityLocation) {
    throw new functions.https.HttpsError('invalid-argument', 'Group ID and activity location required');
  }

  try {
    // Verify user is in the group
    const groupDoc = await db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const group = groupDoc.data() as ActivityGroup;
    if (!group.participantUserIds.includes(context.auth.uid)) {
      throw new functions.https.HttpsError('permission-denied', 'Not a group member');
    }

    // Get participant locations (if available and consented)
    const participantLocations = await getParticipantLocations(group.participantUserIds);

    // Generate meet-up suggestions
    const meetupPoints = await generateMeetupSuggestions(
      activityLocation,
      participantLocations,
      group.cityId
    );

    await incrementCounter('activities_meetup_suggestions_generated', 1);

    return { meetupPoints };

  } catch (error) {
    logger.error('Error generating meetup suggestions:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to generate meetup suggestions');
  }
});

// Create group ride quote for activity
export const createActivityGroupRide = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { 
    groupId, 
    bookingId, 
    pickupLocation, 
    dropoffLocation, 
    scheduledTime, 
    passengerCount 
  } = data;

  if (!groupId || !bookingId || !pickupLocation || !dropoffLocation) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    // Verify user is group organizer
    const groupDoc = await db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const group = groupDoc.data() as ActivityGroup;
    if (group.organizerId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Only group organizer can create rides');
    }

    // Verify booking exists and belongs to group
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Booking not found');
    }

    const booking = bookingDoc.data() as Booking;
    if (booking.groupId !== groupId) {
      throw new functions.https.HttpsError('permission-denied', 'Booking does not belong to group');
    }

    // Create ride request for the group
    const rideRequestData = {
      creatorUid: context.auth.uid,
      origin: new admin.firestore.GeoPoint(pickupLocation.latitude, pickupLocation.longitude),
      destination: new admin.firestore.GeoPoint(dropoffLocation.latitude, dropoffLocation.longitude),
      passengerCount: passengerCount || booking.participants.length,
      scheduledTime: scheduledTime ? admin.firestore.Timestamp.fromDate(new Date(scheduledTime)) : null,
      state: 'searching',
      activityGroupId: groupId,
      activityBookingId: bookingId,
      groupRide: true,
      participants: booking.participants.map(p => ({
        userId: p.userId,
        userName: p.userName
      })),
      rideType: 'activity_group',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const rideRequestRef = await db.collection('rideRequests').add(rideRequestData);

    // Update booking with ride request
    await db.collection('bookings').doc(bookingId).update({
      rideRequestId: rideRequestRef.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await incrementCounter('activities_group_rides_created', 1);

    logger.info('Activity group ride created', {
      groupId,
      bookingId,
      rideRequestId: rideRequestRef.id,
      passengerCount: passengerCount || booking.participants.length
    });

    return { 
      rideRequestId: rideRequestRef.id,
      estimatedArrival: calculateEstimatedArrival(pickupLocation, dropoffLocation)
    };

  } catch (error) {
    logger.error('Error creating activity group ride:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to create group ride');
  }
});

// Get ride sharing options for activity
export const getActivityRideOptions = functions.https.onCall(async (data, context) => {
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
    const activityLocation = activity.location;

    // Calculate distance and estimated travel time
    const distance = haversineKm(
      userLocation.latitude, 
      userLocation.longitude,
      activityLocation.latitude, 
      activityLocation.longitude
    );

    // Determine if ride sharing is recommended
    const walkingTimeMinutes = distance * 15; // Rough estimate: 4km/h walking speed
    const drivingTimeMinutes = distance * 2; // Rough estimate: 30km/h average in city

    const rideRecommended = distance > 1.5 || walkingTimeMinutes > 20;

    // Generate ride options
    const rideOptions = [];

    if (rideRecommended) {
      // Standard ride
      rideOptions.push({
        type: 'standard',
        estimatedPrice: Math.max(8, distance * 4), // MAD, minimum 8 MAD
        estimatedTime: Math.ceil(drivingTimeMinutes + 5), // Add pickup wait time
        recommended: distance < 5
      });

      // Shared ride (if available)
      rideOptions.push({
        type: 'shared',
        estimatedPrice: Math.max(5, distance * 2.5), // MAD, cheaper than standard
        estimatedTime: Math.ceil(drivingTimeMinutes + 10), // Add extra time for sharing
        recommended: distance > 2
      });

      // Premium ride (for longer distances)
      if (distance > 3) {
        rideOptions.push({
          type: 'premium',
          estimatedPrice: Math.max(12, distance * 6), // MAD
          estimatedTime: Math.ceil(drivingTimeMinutes + 3),
          recommended: false
        });
      }
    }

    // Walking option (always available)
    const walkingOption = {
      type: 'walking',
      estimatedTime: Math.ceil(walkingTimeMinutes),
      distance: distance,
      recommended: distance <= 1.5
    };

    return {
      rideRecommended,
      distance,
      walkingOption,
      rideOptions,
      meetupSuggestions: await generateNearbyMeetupPoints(activityLocation)
    };

  } catch (error) {
    logger.error('Error getting activity ride options:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to get ride options');
  }
});

// Create deep link to ride sharing feature
export const createRideSharingDeepLink = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { 
    origin, 
    destination, 
    scheduledTime, 
    passengerCount = 1,
    activityId,
    groupId 
  } = data;

  if (!origin || !destination) {
    throw new functions.https.HttpsError('invalid-argument', 'Origin and destination required');
  }

  try {
    // Create deep link URL for ride sharing
    const deepLinkParams = new URLSearchParams({
      origin_lat: origin.latitude.toString(),
      origin_lng: origin.longitude.toString(),
      origin_address: origin.address || '',
      dest_lat: destination.latitude.toString(),
      dest_lng: destination.longitude.toString(), 
      dest_address: destination.address || '',
      passenger_count: passengerCount.toString(),
      ...(scheduledTime && { scheduled_time: new Date(scheduledTime).toISOString() }),
      ...(activityId && { activity_id: activityId }),
      ...(groupId && { group_id: groupId }),
      source: 'activities'
    });

    const deepLink = `liive://ride-sharing/request?${deepLinkParams.toString()}`;

    await incrementCounter('activities_ride_deeplinks_created', 1);

    return { deepLink };

  } catch (error) {
    logger.error('Error creating ride sharing deep link:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create deep link');
  }
});

// Helper functions
async function getParticipantLocations(participantIds: string[]): Promise<Array<{ userId: string; location?: admin.firestore.GeoPoint }>> {
  const locations = [];
  
  for (const userId of participantIds) {
    try {
      // Check if user has consented to location sharing for activities
      const consentDoc = await db.collection('consentGrants')
        .where('userId', '==', userId)
        .where('scope', '==', 'activities:location_share')
        .where('status', '==', 'granted')
        .limit(1)
        .get();

      if (!consentDoc.empty) {
        // Get user's last known location (would be from their profile or recent activity)
        const userDoc = await db.collection('users').doc(userId).get();
        const userData = userDoc.data();
        
        locations.push({
          userId,
          location: userData?.lastKnownLocation as admin.firestore.GeoPoint
        });
      } else {
        locations.push({ userId });
      }
    } catch (error) {
      logger.warn(`Failed to get location for user ${userId}:`, error);
      locations.push({ userId });
    }
  }
  
  return locations;
}

async function generateMeetupSuggestions(
  activityLocation: any,
  participantLocations: Array<{ userId: string; location?: admin.firestore.GeoPoint }>,
  cityId: string
): Promise<Array<any>> {
  // In a real implementation, this would use Mapbox/Google Places to find:
  // - Safe public locations (metro stations, landmarks, shopping centers)
  // - Locations that are convenient for the majority of participants
  // - Locations with good transportation links to the activity venue

  const suggestions = [
    {
      id: 'activity_venue',
      name: 'Activity Venue',
      description: 'Meet directly at the activity location',
      location: activityLocation,
      type: 'venue',
      convenience: 'high',
      safety: 'high'
    }
  ];

  // Add some generic suggestions based on city
  if (cityId === 'casablanca') {
    suggestions.push(
      {
        id: 'casa_port_station',
        name: 'Casa Port Train Station',
        description: 'Central location with good transport links',
        location: new admin.firestore.GeoPoint(33.5927, -7.6166),
        type: 'transport_hub',
        convenience: 'high',
        safety: 'high'
      },
      {
        id: 'morocco_mall',
        name: 'Morocco Mall',
        description: 'Large shopping center with parking',
        location: new admin.firestore.GeoPoint(33.5007, -7.7098),
        type: 'shopping_center',
        convenience: 'medium',
        safety: 'high'
      }
    );
  }

  return suggestions;
}

async function generateNearbyMeetupPoints(activityLocation: any): Promise<Array<any>> {
  // Generate some nearby meeting points around the activity location
  return [
    {
      id: 'nearby_1',
      name: 'Near Activity Venue',
      description: 'Public area close to the activity location',
      location: activityLocation,
      distance: 0.05, // 50m
      type: 'nearby'
    }
  ];
}

function calculateEstimatedArrival(origin: any, destination: any): Date {
  const distance = haversineKm(
    origin.latitude,
    origin.longitude,
    destination.latitude,
    destination.longitude
  );
  
  // Estimate: 5 minutes waiting + travel time at 25 km/h average
  const estimatedMinutes = 5 + (distance / 25) * 60;
  
  return new Date(Date.now() + estimatedMinutes * 60 * 1000);
}

// Notification when ride is matched for activity group
export const notifyActivityGroupRideMatched = functions.firestore
  .document('rideRequests/{rideRequestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Only handle activity group rides that just got matched
    if (
      before?.state !== 'matched' && 
      after?.state === 'matched' && 
      after?.rideType === 'activity_group'
    ) {
      try {
        const groupId = after.activityGroupId;
        const bookingId = after.activityBookingId;
        
        if (!groupId || !bookingId) return;

        // Get group details
        const groupDoc = await db.collection('groups').doc(groupId).get();
        if (!groupDoc.exists) return;

        const group = groupDoc.data() as ActivityGroup;
        
        // Send notifications to all participants
        if (group.chatThreadId) {
          await sendRideMatchedMessage(group.chatThreadId, after);
        }

        logger.info('Activity group ride matched notification sent', {
          rideRequestId: context.params.rideRequestId,
          groupId,
          bookingId
        });

      } catch (error) {
        logger.error('Error sending ride matched notification:', error);
      }
    }
  });

async function sendRideMatchedMessage(conversationId: string, rideRequest: any): Promise<void> {
  const message = {
    conversationId,
    senderId: 'system',
    text: `🚗 Great news! Your group ride has been matched! Your driver will arrive shortly.`,
    type: 'ride_update',
    replyToId: null,
    attachments: [],
    metadata: {
      rideRequestId: rideRequest.id,
      driverId: rideRequest.assignedDriverId,
      estimatedArrival: rideRequest.etaSeconds
    },
    reactions: {},
    editHistory: [],
    isDeleted: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('messages').add(message);
}