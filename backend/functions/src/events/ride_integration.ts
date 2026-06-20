import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { CallableContext } from "firebase-functions/v2/https";
import { addRideContextMessage } from "./chat";
import {
  Event,
  AttendanceGroup,
  RideQuote,
  RideBookingRequest,
  RideBookingResult
} from "./types";

const db = admin.firestore();

/**
 * Get ride quote for event
 */
export async function getRideQuote(
  data: {
    eventId: string;
    pickupLocation: {
      latitude: number;
      longitude: number;
      address?: string;
    };
    departureTime?: Date;
    passengerCount?: number;
  },
  context: CallableContext
): Promise<RideQuote> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }

    // Get event details
    const eventDoc = await db.collection("events").doc(data.eventId).get();
    if (!eventDoc.exists) {
      throw new Error("Event not found");
    }

    const event = eventDoc.data() as Event;
    const eventLocation = {
      latitude: event.location.latitude,
      longitude: event.location.longitude,
      address: event.venueName
    };

    // Calculate estimated travel time and fare
    const distance = calculateDistance(
      data.pickupLocation.latitude,
      data.pickupLocation.longitude,
      eventLocation.latitude,
      eventLocation.longitude
    );

    const estimatedDuration = Math.max(15, Math.round(distance * 2.5)); // minutes
    const baseFare = Math.max(20, distance * 8); // MAD base rate
    const passengerCount = data.passengerCount || 1;
    const totalFare = baseFare * Math.max(1, passengerCount * 0.8); // Group discount

    // Departure time (default to 30 minutes before event)
    const departureTime = data.departureTime || 
      new Date(event.startAt.toDate().getTime() - (30 * 60 * 1000));

    const quote: RideQuote = {
      id: `quote_${Date.now()}_${userId}`,
      eventId: data.eventId,
      pickupLocation: data.pickupLocation,
      dropoffLocation: eventLocation,
      departureTime,
      estimatedDuration,
      estimatedFare: Math.round(totalFare),
      passengerCount,
      vehicleType: passengerCount > 4 ? "suv" : "sedan",
      expiresAt: new Date(Date.now() + (15 * 60 * 1000)), // 15 minutes
      deepLinkUrl: generateRideDeepLink({
        pickup: data.pickupLocation,
        dropoff: eventLocation,
        time: departureTime,
        passengers: passengerCount,
        eventId: data.eventId
      })
    };

    // Store quote for tracking
    await db.collection("rideQuotes").doc(quote.id).set({
      ...quote,
      userId,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    logger.info("Ride quote generated", { 
      eventId: data.eventId, 
      userId,
      estimatedFare: quote.estimatedFare 
    });

    return quote;
  } catch (error: any) {
    logger.error("Failed to get ride quote", { error: error.message });
    throw error;
  }
}

/**
 * Book ride for event
 */
export async function bookEventRide(
  data: {
    quoteId: string;
    groupId?: string;
    shareRide?: boolean;
  },
  context: CallableContext
): Promise<RideBookingResult> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }

    // Get quote
    const quoteDoc = await db.collection("rideQuotes").doc(data.quoteId).get();
    if (!quoteDoc.exists) {
      throw new Error("Quote not found or expired");
    }

    const quote = quoteDoc.data() as RideQuote & { userId: string };
    
    if (quote.userId !== userId) {
      throw new Error("Not authorized to use this quote");
    }

    if (quote.expiresAt.toDate() < new Date()) {
      throw new Error("Quote has expired");
    }

    // Create booking request
    const bookingRequest: RideBookingRequest = {
      id: `booking_${Date.now()}_${userId}`,
      quoteId: data.quoteId,
      eventId: quote.eventId,
      userId,
      groupId: data.groupId,
      pickupLocation: quote.pickupLocation,
      dropoffLocation: quote.dropoffLocation,
      departureTime: quote.departureTime,
      passengerCount: quote.passengerCount,
      estimatedFare: quote.estimatedFare,
      status: "pending",
      shareRide: data.shareRide || false,
      createdAt: new Date()
    };

    // Store booking request
    await db.collection("rideBookings").doc(bookingRequest.id).set({
      ...bookingRequest,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // If sharing ride and has group, add to chat
    if (data.shareRide && data.groupId) {
      const groupDoc = await db.collection("attendanceGroups").doc(data.groupId).get();
      if (groupDoc.exists) {
        const group = groupDoc.data() as AttendanceGroup;
        if (group.chatId) {
          await addRideContextMessage(group.chatId, {
            pickupLocation: quote.pickupLocation.address || "Pickup location",
            dropoffLocation: quote.dropoffLocation.address || "Event venue",
            departureTime: quote.departureTime,
            estimatedFare: quote.estimatedFare,
            availableSeats: Math.max(0, quote.passengerCount - 1)
          });
        }
      }
    }

    // Generate different deep links for different providers
    const deepLinks = {
      uber: generateUberDeepLink(quote),
      careem: generateCareemDeepLink(quote),
      inDrive: generateInDriveDeepLink(quote),
      liiveRide: quote.deepLinkUrl
    };

    const result: RideBookingResult = {
      bookingId: bookingRequest.id,
      status: "pending",
      deepLinks,
      estimatedFare: quote.estimatedFare,
      departureTime: quote.departureTime,
      message: "Ride booking initiated. Choose your preferred provider."
    };

    logger.info("Ride booking created", { 
      bookingId: result.bookingId,
      eventId: quote.eventId,
      userId 
    });

    return result;
  } catch (error: any) {
    logger.error("Failed to book event ride", { error: error.message });
    throw error;
  }
}

/**
 * Update ride booking status
 */
export async function updateRideBookingStatus(
  bookingId: string,
  status: string,
  details?: any
): Promise<void> {
  try {
    const bookingRef = db.collection("rideBookings").doc(bookingId);
    const bookingDoc = await bookingRef.get();
    
    if (!bookingDoc.exists) {
      throw new Error("Booking not found");
    }

    const booking = bookingDoc.data() as RideBookingRequest;

    await bookingRef.update({
      status,
      statusDetails: details,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // If confirmed and part of group, notify group
    if (status === "confirmed" && booking.shareRide && booking.groupId) {
      const groupDoc = await db.collection("attendanceGroups").doc(booking.groupId).get();
      if (groupDoc.exists) {
        const group = groupDoc.data() as AttendanceGroup;
        if (group.chatId) {
          await addRideContextMessage(group.chatId, {
            pickupLocation: booking.pickupLocation.address || "Pickup location",
            dropoffLocation: booking.dropoffLocation.address || "Event venue", 
            departureTime: booking.departureTime,
            estimatedFare: booking.estimatedFare,
            availableSeats: Math.max(0, booking.passengerCount - 1)
          });
        }
      }
    }

    logger.info("Ride booking status updated", { bookingId, status });
  } catch (error: any) {
    logger.error("Failed to update ride booking status", { error: error.message });
  }
}

/**
 * Get user's ride bookings for event
 */
export async function getEventRideBookings(
  eventId: string,
  userId: string
): Promise<RideBookingRequest[]> {
  try {
    const bookingsSnapshot = await db.collection("rideBookings")
      .where("eventId", "==", eventId)
      .where("userId", "==", userId)
      .orderBy("createdAt", "desc")
      .limit(10)
      .get();

    return bookingsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt.toDate(),
      departureTime: doc.data().departureTime.toDate()
    })) as RideBookingRequest[];
  } catch (error: any) {
    logger.error("Failed to get event ride bookings", { error: error.message });
    return [];
  }
}

// Helper functions

function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Earth's radius in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
    
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

function generateRideDeepLink(params: {
  pickup: { latitude: number; longitude: number; address?: string };
  dropoff: { latitude: number; longitude: number; address?: string };
  time: Date;
  passengers: number;
  eventId: string;
}): string {
  const baseUrl = "liive://ride/book";
  const urlParams = new URLSearchParams({
    pickup_lat: params.pickup.latitude.toString(),
    pickup_lng: params.pickup.longitude.toString(),
    pickup_name: params.pickup.address || "Pickup Location",
    dropoff_lat: params.dropoff.latitude.toString(),
    dropoff_lng: params.dropoff.longitude.toString(),
    dropoff_name: params.dropoff.address || "Event Venue",
    departure_time: params.time.toISOString(),
    passengers: params.passengers.toString(),
    event_id: params.eventId,
    source: "events"
  });
  
  return `${baseUrl}?${urlParams.toString()}`;
}

function generateUberDeepLink(quote: RideQuote): string {
  const params = new URLSearchParams({
    action: "setPickup",
    pickup_latitude: quote.pickupLocation.latitude.toString(),
    pickup_longitude: quote.pickupLocation.longitude.toString(),
    pickup_nickname: quote.pickupLocation.address || "Pickup",
    dropoff_latitude: quote.dropoffLocation.latitude.toString(),
    dropoff_longitude: quote.dropoffLocation.longitude.toString(),
    dropoff_nickname: quote.dropoffLocation.address || "Event Venue",
  });
  
  return `uber://?${params.toString()}`;
}

function generateCareemDeepLink(quote: RideQuote): string {
  const params = new URLSearchParams({
    pickup_latitude: quote.pickupLocation.latitude.toString(),
    pickup_longitude: quote.pickupLocation.longitude.toString(),
    dropoff_latitude: quote.dropoffLocation.latitude.toString(),
    dropoff_longitude: quote.dropoffLocation.longitude.toString(),
  });
  
  return `careem://ride?${params.toString()}`;
}

function generateInDriveDeepLink(quote: RideQuote): string {
  const params = new URLSearchParams({
    start_latitude: quote.pickupLocation.latitude.toString(),
    start_longitude: quote.pickupLocation.longitude.toString(),
    end_latitude: quote.dropoffLocation.latitude.toString(),
    end_longitude: quote.dropoffLocation.longitude.toString(),
  });
  
  return `indrive://book?${params.toString()}`;
}