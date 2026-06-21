import { onDocumentWritten, onDocumentCreated } from "firebase-functions/v2/firestore";
import Stripe from "stripe";
import { getStripeClient, StripeWebhookService } from "./services/payments/stripeService";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { GeoPoint } from "firebase-admin/firestore";
import { onDocumentWritten as onRideRequestWritten } from "firebase-functions/v2/firestore";
import { incrementCounter, withMetrics } from "./shared/metrics";
import { withTrace } from "./shared/trace";
import { reserveResourcesTransaction, ResourceRequirements, reserveMultiLegResources } from "./ride-sharing/reserveResourcesTx";
import { getSecret, secretPath, SECRET_IDS } from "./shared/secretManager";
import { 
  hasLocationChangedSignificantly, 
  createBufferPolygon, 
  generateRoutePolyline, 
  checkIfOnCurb,
  haversineKm,
  createIsochrone,
  encodeGeohash
} from "./shared/geoHelpers";
import { RadarTripService, RadarUserService } from "./services/location/radarService";
import { planJourneyWithSingleLegReservationRetry, buildMultiLegReservationRequirements, buildResourceRequirements } from "./ride-sharing/plannerClient";

// Events functions
export * from "./events/index";

// Trips functions
export * from "./trips/trips-service";
export * from "./trips/search-service";
export * from "./trips/ai-orchestrator";

admin.initializeApp();

// Stripe client now handled by service layer

/**
 * S1 – Driver-Watcher
 * Listens to any write on drivers/{driverId} and computes buffer polygon for matching.
 * Also updates route polyline if driver's location has changed significantly.
 */
export const driverWatcher = withTrace(withMetrics("driverWatcher", onDocumentWritten("drivers/{driverId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  
  if (!after || !event.params.driverId) return;

  const updates: any = {
    lastSeenAt: admin.firestore.FieldValue.serverTimestamp()
  };

  // Check if location changed significantly (>50m)
  const beforeLoc = before?.currentLocation as GeoPoint | undefined;
  const afterLoc = after.currentLocation as GeoPoint | undefined;
  
  if (afterLoc && (!beforeLoc || hasLocationChangedSignificantly(beforeLoc, afterLoc))) {
    // Compute buffer polygon around current location
    const bufferRadiusMeters = after.walkRadiusM || 500;
    updates.bufferPolygon = createBufferPolygon(
      afterLoc.latitude,
      afterLoc.longitude,
      bufferRadiusMeters
    );
    
    // Update route polyline if destination is set
    if (after.destinationLocation) {
      updates.routePolyline = await generateRoutePolyline(
        afterLoc,
        after.destinationLocation as GeoPoint
      );
    }
    
    // Update movement status
    updates.isMoving = after.speedKmh > 5;
    updates.isOnCurb = await checkIfOnCurb(afterLoc);
    
    // Sync metadata with Radar - fail fast to detect issues
    try {
      await RadarUserService.updateUser(`driver_${event.params.driverId}`, {
        metadata: {
          isAvailable: after.isAvailable || false,
          capacitySeats: after.capacitySeats || 4,
          activePickups: after.activePickups || 0,
          pickupZoneId: after.pickupZoneId,
          vehicleMake: after.vehicle?.make,
          vehicleModel: after.vehicle?.model,
          isMoving: updates.isMoving,
          isOnCurb: updates.isOnCurb,
          lastUpdate: new Date().toISOString(),
        }
      });
    } catch (radarError: any) {
      logger.error("CRITICAL: Radar sync failed for driver metadata", {
        driverId: event.params.driverId,
        error: radarError.message,
        stack: radarError.stack
      });
      
      // Re-throw to trigger alerts and fail the function
      throw new Error(`Radar driver sync failed: ${radarError.message}`);
    }
    
    logger.info("Driver location updated", {
      driverId: event.params.driverId,
      location: afterLoc,
      bufferRadius: bufferRadiusMeters,
      isMoving: updates.isMoving,
      isOnCurb: updates.isOnCurb
    });
  }

  // Update driver document
  await admin
    .firestore()
    .doc(`drivers/${event.params.driverId}`)
    .update(updates);
})));

/**
 * S2 – Single-Hop Matcher (Enhanced with Resource Reservation)
 * Triggered when a new rideRequests/{reqId} doc is created with state=="searching".
 * Now includes atomic resource reservation before proposal.
 */
export const singleHopMatcher = withMetrics("singleHopMatcher", onDocumentCreated("rideRequests/{reqId}", async (event) => {
  const req = event.data?.data() as any;
  if (!req || req.state !== "searching") return;

  // Add missing geospatial fields if not present
  const updates: any = {};
  
  if (!req.geohash && req.origin) {
    updates.geohash = encodeGeohash(req.origin.latitude, req.origin.longitude);
  }
  
  if (!req.oriWalkIso && req.origin) {
    updates.oriWalkIso = createIsochrone(
      req.origin.latitude,
      req.origin.longitude,
      req.walkRadiusM || 500,
      "walk"
    );
  }
  
  if (!req.destWalkIso && req.destination) {
    updates.destWalkIso = createIsochrone(
      req.destination.latitude,
      req.destination.longitude,
      req.walkRadiusM || 500,
      "walk"
    );
  }
  
  if (!req.oriDriveIso && req.origin) {
    updates.oriDriveIso = createIsochrone(
      req.origin.latitude,
      req.origin.longitude,
      5000, // 5km drive radius
      "drive"
    );
  }
  
  // Update request with geospatial fields if needed
  if (Object.keys(updates).length > 0) {
    await event.data!.ref.update(updates);
  }

  // Call external planner service (Cloud Run) to get journey
  try {
    const plannerUrl = process.env.PLANNER_URL;
    if (!plannerUrl) throw new Error("PLANNER_URL env var not set");

    const resourceRequirements: ResourceRequirements = buildResourceRequirements(req);

    const planned = await planJourneyWithSingleLegReservationRetry({
      plannerUrl,
      rideRequest: req,
      geoUpdates: updates,
      resourceRequirements,
      reserveResources: (driverId, pickupZoneId, dropoffZoneId, requirements) =>
        reserveResourcesTransaction(driverId, pickupZoneId, requirements, undefined, dropoffZoneId),
      fetchImpl: fetch as any,
      maxAttempts: Number(process.env.PLANNER_RESERVATION_MAX_ATTEMPTS || 3),
    });

    const journey = planned.journey as any;
    if (!journey.legs || journey.legs.length === 0) {
      throw new Error("Planner returned no journey legs");
    }

    // Handle both single-leg and multi-leg journeys
    if (journey.legs.length === 1) {
      const firstLeg = journey.legs[0];
      const driverId = firstLeg.driverId;
      const pickupZoneId = planned.pickupZoneId || firstLeg.pickupZoneId;
      const reservation = planned.reservation;

      if (!reservation?.success) {
        throw new Error("Single-leg planner returned without a successful reservation");
      }

      // Update ride request with single-leg match
      await event.data!.ref.update({
        assignedDriverId: driverId,
        pickupZoneId,
        state: "proposed",
        proposedAt: admin.firestore.FieldValue.serverTimestamp(),
        journey,
        reservedResources: reservation.reservedResources,
        attemptedDriverIds: planned.attemptedDriverIds,
      });

    } else {
      // Multi-leg journey - use multi-leg resource reservation
      const multiLegRequirements = buildMultiLegReservationRequirements(
        journey,
        req,
        event.params.reqId!
      );

      const multiLegReservation = await reserveMultiLegResources(multiLegRequirements);

      if (!multiLegReservation.success) {
        throw new Error(`Multi-leg reservation failed: ${multiLegReservation.error}`);
      }

      // Update ride request with multi-leg match
      await event.data!.ref.update({
        assignedDriverIds: journey.legs.map((leg: any) => leg.driverId),
        pickupZoneIds: multiLegRequirements.legs.map((leg) => leg.pickupZoneId),
        state: "proposed",
        proposedAt: admin.firestore.FieldValue.serverTimestamp(),
        journey,
        reservedLegs: multiLegReservation.reservedLegs,
        isMultiLeg: true,
        legsCount: journey.legs.length,
      });
    }

    logger.info("Proposed driver with reserved resources", { 
      driverId: journey.legs.length === 1 ? journey.legs[0].driverId : journey.legs.map((l: any) => l.driverId), 
      requestId: event.params.reqId,
      isMultiLeg: journey.legs.length > 1,
      legsCount: journey.legs.length,
    });

  } catch (err: any) {
    logger.error("Single hop matcher failed", err);
    await incrementCounter("singleHopMatcher/unmatched");
    // mark as no-driver
    await event.data?.ref.update({ 
      state: "no-driver", 
      plannerError: err.message,
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}));

/**
 * S5 – Pricing Engine
 * When a rideRequest transitions to `proposed`, compute fare and set state="priced".
 */
export const pricingEngine = withMetrics("pricingEngine", onRideRequestWritten("rideRequests/{reqId}", async (event) => {
  const afterData = event.data?.after.data() as any;
  if (!afterData) return;

  if (afterData.state !== "proposed" || afterData.fareBreakdown) return; // already priced or wrong state

  const origin = afterData.origin as admin.firestore.GeoPoint;
  const destination = afterData.destination as admin.firestore.GeoPoint;

  if (!origin || !destination) return;

  const distanceKm = haversineKm(origin.latitude, origin.longitude, destination.latitude, destination.longitude);
  const baseFare = Math.max(2.5, distanceKm * 1.2); // $1.20/km, min $2.50

  // Add surcharges based on reserved resources
  let surcharges = 0;
  const reserved = afterData.reservedResources || {};
  
  // Seat surcharge
  const extraSeats = Math.max(0, (reserved.seats || 1) - 1);
  surcharges += extraSeats * 0.5;

  // Luggage surcharge
  if (reserved.cargo) {
    surcharges += Object.values(reserved.cargo).reduce((sum: number, count: any) => sum + (count * 0.75), 0);
  }

  // Pet surcharge
  if (reserved.pets) {
    surcharges += Object.values(reserved.pets).reduce((sum: number, count: any) => sum + (count * 2.0), 0);
  }

  // Child seat surcharge
  if (reserved.childSeats) {
    surcharges += Object.values(reserved.childSeats).reduce((sum: number, count: any) => sum + (count * 1.5), 0);
  }

  // Premium multiplier
  const premiumMultiplier = afterData.premiumRequested ? 1.5 : 1.0;

  const total = Math.ceil((baseFare + surcharges) * premiumMultiplier * 100) / 100;

  const fareBreakdown = {
    baseFare: Math.round(baseFare * 100) / 100,
    surcharges: Math.round(surcharges * 100) / 100,
    premiumMultiplier,
    total,
    currency: "USD",
    distanceKm: Math.round(distanceKm * 100) / 100,
  };

  await event.data!.after.ref.update({
    fareBreakdown,
    state: "priced",
    pricedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info("Fare calculated", { requestId: event.params.reqId, fareBreakdown });
}));

/**
 * S6 – Pickup Soon notifier
 * When rider accepts (`state == accepted`) immediately set `state = riderPickupSoon` and `etaSeconds`.
 */
export const pickupSoonEngine = withMetrics("pickupSoonEngine", onRideRequestWritten("rideRequests/{reqId}", async (event) => {
  const after = event.data?.after.data() as any;
  if (!after || after.state !== "accepted") return;

  try {
    // Start Radar trip tracking for both rider and driver
    const rideRequestId = event.params.reqId!;
    
    if (after.creatorUid) {
      await RadarTripService.startTrip(`rider_${after.creatorUid}`, {
        externalId: rideRequestId,
        metadata: {
          rideType: 'rider',
          passengerCount: after.passengerCount || 1,
          isMultiLeg: after.isMultiLeg || false
        },
        mode: 'foot' // Rider walks to pickup
      });
    }
    
    if (after.assignedDriverId) {
      await RadarTripService.startTrip(`driver_${after.assignedDriverId}`, {
        externalId: rideRequestId,
        metadata: {
          rideType: 'driver',
          passengerCount: after.passengerCount || 1,
          isMultiLeg: after.isMultiLeg || false
        },
        mode: 'car' // Driver drives to pickup
      });
    }

    await event.data?.after.ref.update({
      state: "riderPickupSoon",
      etaSeconds: 120,
      radarTripsStarted: true,
    });

    logger.info("Rider pickup soon with Radar trip tracking", { 
      reqId: rideRequestId,
      riderId: after.creatorUid,
      driverId: after.assignedDriverId
    });
    
  } catch (error: any) {
    logger.error("Failed to start Radar trip tracking", {
      reqId: event.params.reqId,
      error: error.message
    });
    
    // Continue without Radar if it fails
    await event.data?.after.ref.update({
      state: "riderPickupSoon",
      etaSeconds: 120,
    });
  }
}));

/**
 * Radar Trip Completion
 * Complete Radar trips when ride reaches final state
 */
export const radarTripCompleter = withMetrics("radarTripCompleter", onRideRequestWritten("rideRequests/{reqId}", async (event) => {
  const after = event.data?.after.data() as any;
  if (!after || !after.radarTripsStarted) return;
  
  const completionStates = ["completed", "cancelled"];
  if (!completionStates.includes(after.state)) return;

  try {
    const rideRequestId = event.params.reqId!;
    
    // Complete rider trip
    if (after.creatorUid) {
      await RadarTripService.completeTrip(`rider_${after.creatorUid}`, rideRequestId);
    }
    
    // Complete driver trip(s)
    if (after.assignedDriverId) {
      await RadarTripService.completeTrip(`driver_${after.assignedDriverId}`, rideRequestId);
    } else if (after.assignedDriverIds) {
      // Multi-leg: complete all driver trips
      for (const driverId of after.assignedDriverIds) {
        await RadarTripService.completeTrip(`driver_${driverId}`, rideRequestId);
      }
    }

    await event.data?.after.ref.update({
      radarTripsCompleted: true,
      radarCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Radar trips completed", { 
      reqId: rideRequestId,
      state: after.state,
      riderId: after.creatorUid,
      driverIds: after.assignedDriverIds || [after.assignedDriverId]
    });
    
  } catch (error: any) {
    logger.error("Failed to complete Radar trips", {
      reqId: event.params.reqId,
      error: error.message
    });
  }
}));

/**
 * S-StuckVehicleWatch – detects drivers who are stationary in travel lane for >45s.
 * If a driver document has `isMoving == false` AND `isOnCurb == false` for more than
 * thresholdSeconds, create/refresh a roadBlocks/{driverId} document so planner can avoid.
 */
const STUCK_THRESHOLD_SEC = 45;

export const stuckVehicleWatch = withMetrics("stuckVehicleWatch", onDocumentWritten("drivers/{driverId}", async (event) => {
  const before = event.data?.before.data() as any | undefined;
  const after = event.data?.after.data() as any | undefined;
  if (!after) return;

  const now = admin.firestore.Timestamp.now();

  const wasMoving = before?.isMoving ?? true;
  const wasOnCurb = before?.isOnCurb ?? true;

  const isMoving = after.isMoving ?? true;
  const isOnCurb = after.isOnCurb ?? true;

  // Only track when stationary in lane
  if (!isMoving && !isOnCurb) {
    const stuckSince: admin.firestore.Timestamp | undefined = after.stuckSince;
    if (!stuckSince) {
      // First time becoming stuck: set marker timestamp
      await event.data!.after.ref.update({ stuckSince: now });
    } else {
      const diffSec = now.seconds - stuckSince.seconds;
      if (diffSec >= STUCK_THRESHOLD_SEC) {
        // Write / refresh roadBlocks/{driverId}
        await admin.firestore().collection("roadBlocks").doc(event.params.driverId).set({
          driverId: event.params.driverId,
          location: after.currentLocation ?? null,
          detectedAt: now,
          active: true,
        });
      }
    }
  } else if ((wasMoving === false || wasOnCurb === false) && (isMoving || isOnCurb)) {
    // Vehicle started moving again or reached curb – clear stuckSince and roadBlock
    await Promise.all([
      event.data!.after.ref.update({ stuckSince: admin.firestore.FieldValue.delete() }),
      admin.firestore().collection("roadBlocks").doc(event.params.driverId).delete().catch(() => {}),
    ]);
  }
}));

/**
 * S7 – Nightly Curb Import
 * Runs at 03:00 UTC every night. Fetches latest curb data from Mapbox API and
 * upserts Firestore curbSegments/* collection. For MVP we write a stub segment.
 */
export * from "./shared/curbImport";

/**
 * Stripe webhook – listens for payment_intent events and updates rideRequest docs.
 */
export const stripeWebhook = onRequest({ cors: true }, async (req, res) => {
  const sig = req.headers["stripe-signature"] as string | undefined;
  if (!sig) {
    res.status(400).send("Missing signature");
    return;
  }

  let evt: Stripe.Event;
  try {
    evt = await StripeWebhookService.constructEvent(req.rawBody as Buffer, sig);
  } catch (err: any) {
    logger.error("⚠️  Webhook signature verification failed", err);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  if (evt.type === "payment_intent.succeeded" || evt.type === "payment_intent.payment_failed") {
    const intent = evt.data.object as Stripe.PaymentIntent;
    const rideRequestId = intent.metadata?.rideRequestId;
    if (rideRequestId) {
      const status = intent.status; // succeeded, requires_payment_method, etc.
      await admin.firestore().doc(`rideRequests/${rideRequestId}`).update({ paymentStatus: status });
      logger.info("Updated rideRequest paymentStatus", { rideRequestId, status });
    }
  }

  res.json({ received: true });
}); 

// Feature-specific exports
export * from "./ride-sharing/congestion";
export * from "./ride-sharing/payoutScheduler"; 
export * from "./ride-sharing/genderPoolKpi";
export * from "./ride-sharing/locationSpoof";
export * from "./ride-sharing/stuckVehicleWatch";
export * from "./ride-sharing/radarWebhook";
export * from "./ride-sharing/pickupZoneAutomation";

export * from "./debate/debateFunctions";
export * from "./debate/factCheckerWorker";

// Home Services – Callables + triggers only (HTTP endpoints removed)
export * from "./home-services/callables";
export * from "./home-services/matching";
export * from "./home-services/reviewTriggers";
export * from "./home-services/tasks";
export * from "./home-services/metrics";
export * from "./home-services/wallet";
export * from "./home-services/webhooks";
export * from "./home-services/ai";

export * from "./shared/sweeper";
export * from "./shared/bigQueryExport";
export * from "./services/livekit/livekitService"; 
export * from "./shared/forecastHeatMap";
export * from "./shared/inventoryHash";

export * from "./food-delivery/orders";
export * from "./food-delivery/restaurants";
export * from "./food-delivery/dispatch";
export * from "./food-delivery/payments";
export * from "./food-delivery/recommendations";
export * from "./food-delivery/livekit";
export * from "./food-delivery/kyc";
export * from "./food-delivery/stripeConnect";

// Marketplace exports - using explicit names to avoid conflicts
export { 
  createListing, 
  updateListing, 
  markReserved, 
  markSold 
} from "./marketplace/listings";

export { 
  search as marketplaceSearch, 
  listNearby, 
  getRecommendations as getMarketplaceRecommendations 
} from "./marketplace/search";

export { 
  openConversation as openMarketplaceConversation, 
  sendMessage as sendMarketplaceMessage, 
  markMessagesRead as markMarketplaceMessagesRead, 
  reportConversation, 
  onMessageCreated as onMarketplaceMessageCreated 
} from "./marketplace/messaging";

export { 
  makeOffer, 
  respondToOffer, 
  withdrawOffer, 
  acceptCounterOffer, 
  onOfferCreated, 
  onOfferUpdated, 
  expireOffers 
} from "./marketplace/offers";

export { 
  createReservation, 
  updateMeetup, 
  confirmMeetup, 
  completeMeetup, 
  cancelReservation, 
  reportNoShow, 
  onReservationCreated, 
  sendMeetupReminders 
} from "./marketplace/reservations";

export { 
  initializeCODPayment, 
  initializeEscrowPayment, 
  confirmCODPayment, 
  releaseEscrowPayment, 
  disputePayment, 
  onPaymentCreated as onMarketplacePaymentCreated, 
  autoReleaseEscrowPayments 
} from "./marketplace/payments";

export { 
  reportContent, 
  blockUser, 
  verifyUserIdentity, 
  calculateTrustScore, 
  moderateContent, 
  onContentCreated as onMarketplaceContentCreated, 
  reviewFlaggedContent 
} from "./marketplace/moderation";

export { 
  aiAnswer, 
  createWatcher as createMarketplaceWatcher, 
  suggestNegotiation, 
  invokePlugin as invokeMarketplacePlugin 
} from "./marketplace/ai_orchestrator";

// Friends system functions
export { 
  requestFriend, 
  respondToFriendRequest, 
  blockUser, 
  unblockUser 
} from "./friends/graph";

export { 
  openConversation as openFriendsConversation, 
  updateGroup, 
  leaveConversation 
} from "./friends/conversations";

export { 
  sendMessage as sendFriendsMessage, 
  updateMessage, 
  deleteMessage, 
  markMessagesRead as markFriendsMessagesRead 
} from "./friends/messages";

export { 
  setPresence, 
  setTyping, 
  getFriendsPresence, 
  updatePresenceActivity 
} from "./friends/presence";

export { 
  createInvite, 
  resolveInvite, 
  importContacts, 
  getInviteStats 
} from "./friends/invites";

export { 
  hashContacts, 
  findUsersByHashedPhone, 
  searchUsers, 
  getMutualFriends 
} from "./friends/contacts";

export { 
  createWatchParty, 
  joinWatchParty, 
  leaveWatchParty, 
  updatePlayback, 
  getWatchParty 
} from "./friends/watchParty";

// AI Tutor exports
export { 
  listEpisodesHttp, 
  getEpisodeConfigHttp, 
  ragQueryHttp, 
  logTelemetryHttp, 
  validateEpisodeCallable 
} from "./ai-tutor";

// News exports
export { 
  ingestNews
} from "./news/ingest";

export { 
  enrichmentWorker, 
  enrichEvent
} from "./news/enrich";

export { 
  newsApi 
} from "./news/api";

export { 
  submitComment,
  deleteComment, 
  reactToComment
} from "./services/comments/comments";

// Activities exports
export {
  createProvider,
  updateProvider,
  getProvider,
  createActivity,
  updateActivity,
  getActivity,
  createSession,
  listAvailability,
  ingestFromUrl
} from "./activities/catalog";

export {
  searchActivities,
  searchWithAI,
  getSearchSuggestions,
  getPopularActivities
} from "./activities/search";

export {
  createGroup,
  inviteToGroup,
  respondToInvitation,
  getUserGroups,
  updateGroupStatus,
  getGroup
} from "./activities/groups";

export {
  createPartnerRequest,
  listPartnerRequests,
  expressInterest,
  matchPartners,
  acceptPartner,
  closePartnerRequest
} from "./activities/partner";

export {
  createBooking,
  confirmBooking,
  cancelBooking,
  getBooking,
  completeBooking
} from "./activities/booking";

export {
  createSplitIntent,
  paySplitShare,
  getSplitIntent,
  cancelSplitIntent,
  handleExpiredSplits
} from "./activities/splitPayments";

export {
  getActivityPerspectives,
  generateGroupSuggestions,
  updateUserTraits,
  enrichActivityDescription,
  getPersonalizedRecommendations
} from "./activities/aiOrchestrator";

export {
  activitiesStripeWebhook,
  bookingStatusNotifier,
  groupInvitationNotifier,
  partnerInterestNotifier,
  sessionReminders
} from "./activities/webhooks";

export {
  submitProviderApplication,
  getProviderApplicationStatus,
  updateProviderProfile,
  createProviderActivity,
  updateProviderActivity,
  createProviderSession,
  getProviderDashboard,
  createProviderStripeAccount,
  reviewProviderApplication
} from "./activities/providersOnboarding";

export {
  createActivityGroupChat,
  updateActivityGroupChat,
  sendBookingConfirmationToChat,
  getActivityGroupChat,
  sendActivityGroupMessage
} from "./activities/groupChat";

export {
  suggestMeetupPoints,
  createActivityGroupRide,
  getActivityRideOptions,
  createRideSharingDeepLink,
  notifyActivityGroupRideMatched
} from "./activities/rideIntegration";

export {
  createActivityDeepLink,
  createGroupInviteDeepLink,
  joinGroupFromInvite,
  handleWebLinkRedirect,
  trackDeepLinkUsage
} from "./activities/deepLinking";

export {
  generateActivityRoute,
  getNearbyTransit,
  shareLocationWithGroup,
  getGroupMemberLocations,
  cleanupExpiredLocationShares
} from "./activities/navigation";

export {
  moderateActivityContent,
  moderateProviderApplication,
  submitModerationReview,
  getModerationTasks,
  cleanupModerationTasks
} from "./activities/moderation";

// Meal Planning exports
export {
  importRecipe,
  getRecipe,
  searchRecipes,
  getMyRecipes,
  saveRecipe,
  deleteRecipe,
  getRecipeSuggestions,
  recipeImportProgress,
  processRecipeImport
} from "./meal-planning/recipes";

export {
  generateMealPlan,
  getMealPlan,
  getMyMealPlans,
  replaceMeal,
  updateMealServing,
  getMealRecommendations,
  deleteMealPlan,
  processMealPlanGeneration
} from "./meal-planning/meal-plans";

export {
  getShoppingList,
  priceCompare,
  updateItemPurchased,
  createShoppingOrder,
  getShoppingOrder
} from "./meal-planning/shopping";

export {
  aiChat as mealPlanningAiChat,
  getNutritionAdvice,
  getHealthProfile,
  updateHealthProfile,
  syncNutritionToHealth
} from "./meal-planning/ai-assistant";

// Meal Planning - Schedulers
export {
  refreshPriceCaches,
  optimizeWeeklyMealPlans,
  cleanupTempAssets,
  aggregateAnalytics
} from "./meal-planning/scheduler";

// Meal Planning - Nutrition Database
export {
  searchFoods,
  getFoodDetails,
  matchIngredients,
  calculateRecipeNutrition
} from "./meal-planning/nutrition-database";

// Accommodations API
export {
  searchAccommodations,
  getRecommendations,
  getPropertyDetails,
  createBooking,
  importBooking,
  interpretVoiceSearch,
  getUserBookings,
  cancelBooking,
  cleanExpiredCache,
  warmCache,
  autocompleteDestinations,
  geocodeAddress,
  reverseGeocode,
  trackPropertyView,
  trackBookingAnalytics,
  getAnalyticsRecommendations,
  getPropertyMetrics,
  cleanupRateLimits,
  getAggregatedSearchResults,
} from "./accommodations/api";

// Cloud Tasks handlers for accommodations
export { 
  providerSearchTask,
  batchProcessingTask 
} from "./accommodations/handlers/provider-search-task";

// Monitoring and observability endpoints
export {
  healthCheck,
  getDashboard,
  createAlert,
  recordMetrics,
  scheduledHealthCheck,
  scheduledAlertCheck,
  getDebugInfo
} from "./accommodations/handlers/monitoring-api";

/**
 * Config endpoint – provides client configuration including API keys
 */
export const config = onRequest({ cors: true }, async (_req, res) => {
  try {
    const radarKey = await getSecret(secretPath(SECRET_IDS.RADAR_PUBLISHABLE_KEY));
    const mapboxToken = await getSecret(secretPath(SECRET_IDS.MAPBOX_ACCESS_TOKEN));
    const stripePublicKey = await getSecret(secretPath(SECRET_IDS.STRIPE_PUBLISHABLE_KEY));
    
    res.json({
      radarPublishableKey: radarKey,
      mapboxAccessToken: mapboxToken,
      stripePublishableKey: stripePublicKey,
      livekitWsUrl: await getSecret(secretPath(SECRET_IDS.LIVEKIT_RIDE_SHARING_WS_URL))
    });
  } catch (error) {
    logger.error("Failed to fetch config", error);
    res.status(500).json({ error: "Failed to fetch configuration" });
  }
}); 