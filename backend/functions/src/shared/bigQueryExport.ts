import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { BigQuery } from "@google-cloud/bigquery";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const bq = new BigQuery();

interface RideRequestRow {
  ride_request_id: string;
  created_at: string;
  state: string;
  passenger_count: number;
  fare_total: number | null;
}

interface MarketplaceAnalyticsRow {
  event_id: string;
  user_id: string | null;
  event_name: string;
  category: string;
  source: string;
  platform: string;
  created_at: string;
  metadata: string; // JSON string
}

interface MarketplaceListingRow {
  listing_id: string;
  seller_id: string;
  city_id: string;
  category: string;
  price_amount: number;
  price_currency: string;
  status: string;
  created_at: string;
  sold_at: string | null;
}

interface MarketplaceTransactionRow {
  transaction_id: string;
  listing_id: string;
  buyer_id: string;
  seller_id: string;
  amount: number;
  currency: string;
  payment_method: string;
  status: string;
  created_at: string;
  completed_at: string | null;
}

const DATASET = process.env.BQ_DATASET || "ride_sharing";
const TABLE_RR = "ride_requests";
const TABLE_MARKETPLACE_ANALYTICS = "marketplace_analytics";
const TABLE_MARKETPLACE_LISTINGS = "marketplace_listings";
const TABLE_MARKETPLACE_TRANSACTIONS = "marketplace_transactions";

export async function exportRideRequestsOnce(db = admin.firestore(), bigQuery: BigQuery = bq) {
  // Retrieve last export timestamp
  const cfgRef = db.collection("_internal").doc("bqExport");
  const cfgSnap = await cfgRef.get();
  const lastTs = cfgSnap.exists ? (cfgSnap.data()?.lastExport?.toDate() as Date) : new Date(0);

  const querySnap = await db
    .collection("rideRequests")
    .where("createdAt", ">", admin.firestore.Timestamp.fromDate(lastTs))
    .limit(5000)
    .get();

  if (querySnap.empty) {
    logger.info("No new rideRequests to export");
    return 0;
  }

  const rows: RideRequestRow[] = [];
  let maxDate = lastTs;
  querySnap.forEach((doc: any) => {
    const d = doc.data();
    const created = d.createdAt?.toDate() as Date;
    if (created > maxDate) maxDate = created;
    rows.push({
      ride_request_id: doc.id,
      created_at: created.toISOString(),
      state: d.state ?? "",
      passenger_count: d.passengerCount ?? 1,
      fare_total: d.fareBreakdown?.total ?? null,
    });
  });

  const table = bigQuery.dataset(DATASET).table(TABLE_RR);
  await table.insert(rows, { ignoreUnknownValues: true });
  await cfgRef.set({ lastExport: admin.firestore.Timestamp.fromDate(maxDate) }, { merge: true });
  logger.info("Exported rideRequests", { count: rows.length });
  return rows.length;
}

export const exportRideRequests = withMetrics("exportRideRequests", onSchedule("*/10 * * * *", async () => {
  await exportRideRequestsOnce();
}));

// Marketplace Analytics Export
export async function exportMarketplaceAnalyticsOnce(db = admin.firestore(), bigQuery: BigQuery = bq) {
  const cfgRef = db.collection("_internal").doc("bqExportMarketplace");
  const cfgSnap = await cfgRef.get();
  const lastTs = cfgSnap.exists ? (cfgSnap.data()?.lastAnalyticsExport?.toDate() as Date) : new Date(0);

  const querySnap = await db
    .collection("analyticsEvents")
    .where("source", "==", "marketplace")
    .where("createdAt", ">", admin.firestore.Timestamp.fromDate(lastTs))
    .limit(5000)
    .get();

  if (querySnap.empty) {
    logger.info("No new marketplace analytics events to export");
    return 0;
  }

  const rows: MarketplaceAnalyticsRow[] = [];
  let maxDate = lastTs;
  querySnap.forEach((doc: any) => {
    const d = doc.data();
    const created = d.createdAt?.toDate() as Date;
    if (created > maxDate) maxDate = created;
    rows.push({
      event_id: doc.id,
      user_id: d.userId || null,
      event_name: d.name,
      category: d.category || 'general',
      source: d.source || 'marketplace',
      platform: d.platform || 'ios',
      created_at: created.toISOString(),
      metadata: JSON.stringify(d.metadata || {}),
    });
  });

  const table = bigQuery.dataset(DATASET).table(TABLE_MARKETPLACE_ANALYTICS);
  await table.insert(rows, { ignoreUnknownValues: true });
  await cfgRef.set({ lastAnalyticsExport: admin.firestore.Timestamp.fromDate(maxDate) }, { merge: true });
  logger.info("Exported marketplace analytics events", { count: rows.length });
  return rows.length;
}

// Marketplace Listings Export
export async function exportMarketplaceListingsOnce(db = admin.firestore(), bigQuery: BigQuery = bq) {
  const cfgRef = db.collection("_internal").doc("bqExportMarketplace");
  const cfgSnap = await cfgRef.get();
  const lastTs = cfgSnap.exists ? (cfgSnap.data()?.lastListingsExport?.toDate() as Date) : new Date(0);

  const querySnap = await db
    .collection("listings")
    .where("createdAt", ">", admin.firestore.Timestamp.fromDate(lastTs))
    .limit(5000)
    .get();

  if (querySnap.empty) {
    logger.info("No new marketplace listings to export");
    return 0;
  }

  const rows: MarketplaceListingRow[] = [];
  let maxDate = lastTs;
  querySnap.forEach((doc: any) => {
    const d = doc.data();
    const created = d.createdAt?.toDate() as Date;
    if (created > maxDate) maxDate = created;
    rows.push({
      listing_id: doc.id,
      seller_id: d.sellerId,
      city_id: d.cityId,
      category: d.category,
      price_amount: d.price?.amount || 0,
      price_currency: d.price?.currency || 'MAD',
      status: d.status,
      created_at: created.toISOString(),
      sold_at: d.soldAt?.toDate()?.toISOString() || null,
    });
  });

  const table = bigQuery.dataset(DATASET).table(TABLE_MARKETPLACE_LISTINGS);
  await table.insert(rows, { ignoreUnknownValues: true });
  await cfgRef.set({ lastListingsExport: admin.firestore.Timestamp.fromDate(maxDate) }, { merge: true });
  logger.info("Exported marketplace listings", { count: rows.length });
  return rows.length;
}

// Marketplace Transactions Export
export async function exportMarketplaceTransactionsOnce(db = admin.firestore(), bigQuery: BigQuery = bq) {
  const cfgRef = db.collection("_internal").doc("bqExportMarketplace");
  const cfgSnap = await cfgRef.get();
  const lastTs = cfgSnap.exists ? (cfgSnap.data()?.lastTransactionsExport?.toDate() as Date) : new Date(0);

  const querySnap = await db
    .collection("payments")
    .where("createdAt", ">", admin.firestore.Timestamp.fromDate(lastTs))
    .limit(5000)
    .get();

  if (querySnap.empty) {
    logger.info("No new marketplace transactions to export");
    return 0;
  }

  const rows: MarketplaceTransactionRow[] = [];
  let maxDate = lastTs;
  querySnap.forEach((doc: any) => {
    const d = doc.data();
    const created = d.createdAt?.toDate() as Date;
    if (created > maxDate) maxDate = created;
    rows.push({
      transaction_id: doc.id,
      listing_id: d.listingId,
      buyer_id: d.buyerId,
      seller_id: d.sellerId,
      amount: d.amount?.amount || 0,
      currency: d.amount?.currency || 'MAD',
      payment_method: d.paymentMethod,
      status: d.status,
      created_at: created.toISOString(),
      completed_at: d.completedAt?.toDate()?.toISOString() || null,
    });
  });

  const table = bigQuery.dataset(DATASET).table(TABLE_MARKETPLACE_TRANSACTIONS);
  await table.insert(rows, { ignoreUnknownValues: true });
  await cfgRef.set({ lastTransactionsExport: admin.firestore.Timestamp.fromDate(maxDate) }, { merge: true });
  logger.info("Exported marketplace transactions", { count: rows.length });
  return rows.length;
}

// Scheduled export functions
export const exportMarketplaceAnalytics = withMetrics("exportMarketplaceAnalytics", onSchedule("*/15 * * * *", async () => {
  await exportMarketplaceAnalyticsOnce();
}));

export const exportMarketplaceListings = withMetrics("exportMarketplaceListings", onSchedule("0 */2 * * *", async () => {
  await exportMarketplaceListingsOnce();
}));

export const exportMarketplaceTransactions = withMetrics("exportMarketplaceTransactions", onSchedule("*/30 * * * *", async () => {
  await exportMarketplaceTransactionsOnce();
})); 