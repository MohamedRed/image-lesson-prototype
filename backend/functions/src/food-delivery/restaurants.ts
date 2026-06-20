import { onDocumentWritten, onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";
import { withTrace } from "../shared/trace";
import { RadarGeofenceService, RadarUserService } from "../services/location/radarService";

/**
 * Restaurant Registration Handler
 * Processes new restaurant registrations and initiates KYC verification
 */
export const restaurantRegistrationHandler = withMetrics("restaurantRegistrationHandler", onDocumentCreated("restaurants/{restaurantId}", async (event) => {
  const restaurant = event.data?.data();
  if (!restaurant) return;

  const restaurantId = event.params.restaurantId!;

  try {
    // Initialize restaurant with default values
    await event.data!.ref.update({
      rating: 0.0,
      isOpen: false, // Start closed until KYC approved
      "kyc.status": "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Send welcome email and KYC instructions
    await sendRestaurantWelcomeNotification(restaurantId, restaurant);

    // Create initial menu structure
    await createDefaultMenuStructure(restaurantId);

    // Create delivery zone geofence in Radar
    await createRestaurantDeliveryZone(restaurantId, restaurant);

    logger.info("Restaurant registered successfully", {
      restaurantId,
      name: restaurant.name,
      city: restaurant.address.city
    });

  } catch (error: any) {
    logger.error("Restaurant registration failed", {
      restaurantId,
      error: error.message
    });
  }
}));

/**
 * Restaurant Status Manager
 * Handles opening/closing and availability updates
 */
export const restaurantStatusManager = withTrace(withMetrics("restaurantStatusManager", onDocumentWritten("restaurants/{restaurantId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  
  if (!after || !event.params.restaurantId) return;

  const restaurantId = event.params.restaurantId;
  const wasOpen = before?.isOpen;
  const isOpen = after.isOpen;

  // Handle opening/closing state changes
  if (wasOpen !== isOpen) {
    if (isOpen) {
      await handleRestaurantOpened(restaurantId, after);
    } else {
      await handleRestaurantClosed(restaurantId, after);
    }
  }

  // Handle KYC status changes
  const beforeKycStatus = before?.kyc?.status;
  const afterKycStatus = after.kyc?.status;
  
  if (beforeKycStatus !== afterKycStatus) {
    await handleKycStatusChange(restaurantId, afterKycStatus, after);
  }
})));

/**
 * Restaurant Management API
 * Handles restaurant operations like accepting orders, updating menu, etc.
 */
export const acceptOrder = onCall(async (request) => {
  try {
    const { orderId, prepTimeMinutes } = request.data || {};
    const restaurantId = request.auth?.uid; // assuming restaurant auth context or custom claims

    if (!orderId || !prepTimeMinutes || !restaurantId) throw new HttpsError("invalid-argument", "Missing required fields");

    const orderRef = admin.firestore().doc(`orders/${orderId}`);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) throw new HttpsError("not-found", "Order not found");

    const order = orderDoc.data()!;

    // Verify restaurant owns this order
    if (order.restaurantId !== restaurantId) throw new HttpsError("permission-denied", "Unauthorized");

    // Check if order can be accepted
    if (order.status !== "pending_restaurant") throw new HttpsError("failed-precondition", "Order cannot be accepted at this stage");

    // Update order status and prep time
    await orderRef.update({
      status: "restaurant_accepted",
      estimatedPrepTime: prepTimeMinutes,
      "timings.acceptedAt": admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, orderId, prepTimeMinutes };

  } catch (error: any) {
    logger.error("Order acceptance failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Order acceptance failed");
  }
});

export const markOrderReady = onCall(async (request) => {
  try {
    const { orderId } = request.data || {};
    const restaurantId = request.auth?.uid;

    if (!orderId || !restaurantId) throw new HttpsError("invalid-argument", "Missing required fields");

    const orderRef = admin.firestore().doc(`orders/${orderId}`);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) throw new HttpsError("not-found", "Order not found");

    const order = orderDoc.data()!;

    // Verify restaurant owns this order
    if (order.restaurantId !== restaurantId) throw new HttpsError("permission-denied", "Unauthorized");

    // Check if order can be marked ready
    if (order.status !== "preparing") throw new HttpsError("failed-precondition", "Order is not in preparing state");

    // Update order status
    await orderRef.update({
      status: "ready_for_pickup",
      "timings.readyAt": admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, orderId };

  } catch (error: any) {
    logger.error("Mark order ready failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Mark order ready failed");
  }
});

export const updateMenuItemAvailability = onCall(async (request) => {
  try {
    const { itemId, isAvailable } = request.data || {};
    const restaurantId = request.auth?.uid;

    if (itemId === undefined || isAvailable === undefined || !restaurantId) throw new HttpsError("invalid-argument", "Missing required fields");

    // Find the menu item
    const menuItemsQuery = await admin.firestore()
      .collection("menuItems")
      .where("restaurantId", "==", restaurantId)
      .where("id", "==", itemId)
      .limit(1)
      .get();

    if (menuItemsQuery.empty) throw new HttpsError("not-found", "Menu item not found");

    const menuItemRef = menuItemsQuery.docs[0].ref;
    await menuItemRef.update({
      isAvailable,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, itemId, isAvailable };

  } catch (error: any) {
    logger.error("Menu item availability update failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Menu item availability update failed");
  }
});

export const pauseRestaurant = onCall(async (request) => {
  try {
    const { pauseMinutes } = request.data || {};
    const restaurantId = request.auth?.uid;

    if (!restaurantId) throw new HttpsError("unauthenticated", "Authentication required");

    const restaurantRef = admin.firestore().doc(`restaurants/${restaurantId}`);
    const updateData: any = {
      isOpen: false,
      pausedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Set resume time if pause duration is specified
    if (pauseMinutes) {
      const resumeTime = new Date(Date.now() + pauseMinutes * 60 * 1000);
      updateData.resumeAt = admin.firestore.Timestamp.fromDate(resumeTime);
      
      // Schedule automatic resume (TODO: implement with Cloud Scheduler)
      await scheduleRestaurantResume(restaurantId, resumeTime);
    }

    await restaurantRef.update(updateData);

    return { success: true, restaurantId, pausedUntil: pauseMinutes ? updateData.resumeAt : null };

  } catch (error: any) {
    logger.error("Restaurant pause failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Restaurant pause failed");
  }
});

export const resumeRestaurant = onCall(async (request) => {
  try {
    const restaurantId = request.auth?.uid;

    if (!restaurantId) throw new HttpsError("unauthenticated", "Authentication required");

    const restaurantRef = admin.firestore().doc(`restaurants/${restaurantId}`);
    await restaurantRef.update({
      isOpen: true,
      pausedAt: admin.firestore.FieldValue.delete(),
      resumeAt: admin.firestore.FieldValue.delete(),
      resumedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, restaurantId };

  } catch (error: any) {
    logger.error("Restaurant resume failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Restaurant resume failed");
  }
});

// Cron task: auto-resume restaurants whose resumeAt has passed
export const autoResumeRestaurants = onSchedule("every 5 minutes", async () => {
  const now = admin.firestore.Timestamp.now();
  const snapshot = await admin.firestore()
    .collection("restaurants")
    .where("resumeAt", "<=", now)
    .get();

  for (const doc of snapshot.docs) {
    try {
      await doc.ref.update({
        isOpen: true,
        pausedAt: admin.firestore.FieldValue.delete(),
        resumeAt: admin.firestore.FieldValue.delete(),
        resumedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      logger.info("Auto-resumed restaurant", { restaurantId: doc.id });
    } catch (e: any) {
      logger.error("Failed to auto-resume restaurant", { restaurantId: doc.id, error: e.message });
    }
  }
});

/**
 * Get Restaurant Orders
 * Returns orders for a specific restaurant with filtering
 */
export const getRestaurantOrders = onCall(async (request) => {
  try {
    const restaurantId = request.auth?.uid;
    const status = request.data?.status as string | undefined;
    const limit = parseInt(String(request.data?.limit ?? "50"));

    if (!restaurantId) throw new HttpsError("unauthenticated", "Authentication required");

    let query = admin.firestore()
      .collection("orders")
      .where("restaurantId", "==", restaurantId);

    if (status) {
      query = query.where("status", "==", status);
    }

    query = query.orderBy("createdAt", "desc").limit(limit);

    const ordersSnapshot = await query.get();
    const orders = ordersSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    return { success: true, orders };

  } catch (error: any) {
    logger.error("Get restaurant orders failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Get restaurant orders failed");
  }
});

/**
 * Restaurant Analytics
 * Provides performance metrics for restaurants
 */
export const getRestaurantAnalytics = onCall(async (request) => {
  try {
    const restaurantId = request.auth?.uid;
    const timeframe = (request.data?.timeframe as string) || "week"; // day, week, month

    if (!restaurantId) throw new HttpsError("unauthenticated", "Authentication required");

    // Calculate date range
    const now = new Date();
    let startDate: Date;
    
    switch (timeframe) {
      case "day":
        startDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        break;
      case "month":
        startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        break;
      default: // week
        startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    }

    // Get orders in the timeframe
    const ordersSnapshot = await admin.firestore()
      .collection("orders")
      .where("restaurantId", "==", restaurantId)
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(startDate))
      .get();

    const orders = ordersSnapshot.docs.map(doc => doc.data());

    // Calculate metrics
    const analytics = calculateRestaurantMetrics(orders);

    return { success: true, timeframe, analytics: { ...analytics, period: { start: startDate.toISOString(), end: now.toISOString() } } };

  } catch (error: any) {
    logger.error("Get restaurant analytics failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Get restaurant analytics failed");
  }
});

// MARK: - Helper Functions

async function handleRestaurantOpened(restaurantId: string, restaurant: any) {
  logger.info("Restaurant opened", { restaurantId, name: restaurant.name });
  
  // Send notification to nearby customers (TODO: implement push notifications)
  await notifyNearbyCustomers(restaurantId, restaurant);
}

async function handleRestaurantClosed(restaurantId: string, restaurant: any) {
  logger.info("Restaurant closed", { restaurantId, name: restaurant.name });
  
  // Handle pending orders
  await handlePendingOrdersOnClosure(restaurantId);
}

async function handleKycStatusChange(restaurantId: string, status: string, restaurant: any) {
  logger.info("Restaurant KYC status changed", { restaurantId, status });

  switch (status) {
    case "approved":
      // Allow restaurant to go live
      await admin.firestore().doc(`restaurants/${restaurantId}`).update({
        canAcceptOrders: true
      });
      await sendKycApprovalNotification(restaurantId, restaurant);
      break;

    case "rejected":
      // Prevent restaurant from accepting orders
      await admin.firestore().doc(`restaurants/${restaurantId}`).update({
        canAcceptOrders: false,
        isOpen: false
      });
      await sendKycRejectionNotification(restaurantId, restaurant);
      break;
  }
}

async function createDefaultMenuStructure(restaurantId: string) {
  // Create default menu categories
  const defaultCategories = [
    { name: "Appetizers", order: 1 },
    { name: "Main Courses", order: 2 },
    { name: "Desserts", order: 3 },
    { name: "Beverages", order: 4 }
  ];

  const batch = admin.firestore().batch();

  for (const category of defaultCategories) {
    const categoryRef = admin.firestore().collection("menuCategories").doc();
    batch.set(categoryRef, {
      restaurantId,
      ...category,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }

  await batch.commit();
}

async function handlePendingOrdersOnClosure(restaurantId: string) {
  // Find pending orders for this restaurant
  const pendingOrdersSnapshot = await admin.firestore()
    .collection("orders")
    .where("restaurantId", "==", restaurantId)
    .where("status", "==", "pending_restaurant")
    .get();

  // Cancel pending orders
  const batch = admin.firestore().batch();

  for (const orderDoc of pendingOrdersSnapshot.docs) {
    batch.update(orderDoc.ref, {
      status: "cancelled_by_merchant",
      cancellation: {
        by: "merchant",
        reasonCode: "restaurant_closed",
        notes: "Restaurant closed unexpectedly"
      },
      "timings.cancelledAt": admin.firestore.FieldValue.serverTimestamp()
    });
  }

  await batch.commit();

  logger.info("Cancelled pending orders due to restaurant closure", {
    restaurantId,
    cancelledOrders: pendingOrdersSnapshot.size
  });
}

function calculateRestaurantMetrics(orders: any[]) {
  const totalOrders = orders.length;
  const completedOrders = orders.filter(o => o.status === "delivered").length;
  const cancelledOrders = orders.filter(o => o.status.startsWith("cancelled")).length;
  
  const totalRevenue = orders
    .filter(o => o.status === "delivered")
    .reduce((sum, o) => sum + (o.total || 0), 0);

  const averageOrderValue = completedOrders > 0 ? totalRevenue / completedOrders : 0;
  
  const completionRate = totalOrders > 0 ? (completedOrders / totalOrders) * 100 : 0;
  const cancellationRate = totalOrders > 0 ? (cancelledOrders / totalOrders) * 100 : 0;

  // Calculate average preparation time
  const prepTimes = orders
    .filter(o => o.timings?.acceptedAt && o.timings?.readyAt)
    .map(o => {
      const accepted = o.timings.acceptedAt.toDate();
      const ready = o.timings.readyAt.toDate();
      return (ready.getTime() - accepted.getTime()) / (1000 * 60); // minutes
    });

  const averagePrepTime = prepTimes.length > 0 
    ? prepTimes.reduce((sum, time) => sum + time, 0) / prepTimes.length 
    : 0;

  return {
    totalOrders,
    completedOrders,
    cancelledOrders,
    totalRevenue: Math.round(totalRevenue * 100) / 100,
    averageOrderValue: Math.round(averageOrderValue * 100) / 100,
    completionRate: Math.round(completionRate * 100) / 100,
    cancellationRate: Math.round(cancellationRate * 100) / 100,
    averagePrepTime: Math.round(averagePrepTime * 10) / 10
  };
}

async function scheduleRestaurantResume(restaurantId: string, resumeTime: Date) {
  // TODO: Implement with Cloud Scheduler or Pub/Sub
  logger.info("Scheduling restaurant resume", { restaurantId, resumeTime });
}

// Notification helper functions (to be implemented)
async function sendRestaurantWelcomeNotification(restaurantId: string, restaurant: any): Promise<void> {
  logger.info("Sending restaurant welcome notification", { restaurantId });
}

async function sendKycApprovalNotification(restaurantId: string, restaurant: any): Promise<void> {
  logger.info("Sending KYC approval notification", { restaurantId });
}

async function sendKycRejectionNotification(restaurantId: string, restaurant: any): Promise<void> {
  logger.info("Sending KYC rejection notification", { restaurantId });
}

async function notifyNearbyCustomers(restaurantId: string, restaurant: any): Promise<void> {
  logger.info("Notifying nearby customers", { restaurantId });
}

async function createRestaurantDeliveryZone(restaurantId: string, restaurant: any): Promise<void> {
  try {
    // Create a delivery zone geofence around the restaurant
    const deliveryRadiusKm = 5.0; // 5km delivery radius - should come from restaurant settings
    
    await RadarGeofenceService.createGeofence({
      description: `${restaurant.name} Delivery Zone`,
      tag: 'delivery_zone',
      externalId: `restaurant_${restaurantId}`,
      type: 'circle',
      coordinates: [restaurant.coordinates.longitude, restaurant.coordinates.latitude],
      radius: deliveryRadiusKm * 1000, // Convert to meters
      metadata: {
        restaurantId,
        restaurantName: restaurant.name,
        service: 'food_delivery',
        type: 'delivery_zone',
        maxDeliveryTime: 45 // minutes
      }
    });

    // Also create a pickup zone geofence for couriers
    await RadarGeofenceService.createGeofence({
      description: `${restaurant.name} Pickup Zone`,
      tag: 'pickup_zone',
      externalId: `pickup_${restaurantId}`,
      type: 'circle',
      coordinates: [restaurant.coordinates.longitude, restaurant.coordinates.latitude],
      radius: 100, // 100 meter pickup radius
      metadata: {
        restaurantId,
        restaurantName: restaurant.name,
        service: 'food_delivery',
        type: 'pickup_zone'
      }
    });

    logger.info("Restaurant delivery and pickup zones created in Radar", {
      restaurantId,
      name: restaurant.name,
      deliveryRadius: deliveryRadiusKm
    });

  } catch (error: any) {
    logger.error("Failed to create restaurant delivery zone in Radar", {
      restaurantId,
      error: error.message
    });
    // Continue without Radar geofences if it fails
  }
}