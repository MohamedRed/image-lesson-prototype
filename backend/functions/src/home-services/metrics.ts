import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { BigQuery } from "@google-cloud/bigquery";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();
const bigquery = new BigQuery();

// BigQuery dataset and table names
const DATASET_ID = 'home_services_analytics';
const TABLES = {
  rfqs: 'rfqs',
  bids: 'bids', 
  contracts: 'contracts',
  escrows: 'escrows',
  reviews: 'reviews',
  daily_metrics: 'daily_metrics'
};

/**
 * Export RFQ data to BigQuery when created
 */
export const exportRfqToBigQuery = withMetrics("exportRfqToBigQuery",
  onDocumentCreated("rfqs/{rfqId}", async (event) => {
    const rfqData = event.data?.data();
    if (!rfqData) return;

    try {
      const bigQueryRow = {
        rfq_id: event.params.rfqId,
        customer_id: rfqData.customerId,
        category_id: rfqData.categoryId,
        location_city: rfqData.location?.city,
        location_region: rfqData.location?.region,
        budget_min_mad: rfqData.budgetRange?.minMAD || null,
        budget_max_mad: rfqData.budgetRange?.maxMAD || null,
        urgency: rfqData.scope?.urgency,
        site_visit_requested: rfqData.siteVisitRequested || false,
        status: rfqData.status,
        created_at: rfqData.createdAt?.toDate()?.toISOString(),
        expires_at: rfqData.expiresAt?.toDate()?.toISOString(),
        exported_at: new Date().toISOString()
      };

      await insertToBigQuery(TABLES.rfqs, [bigQueryRow]);
      
      logger.info("RFQ exported to BigQuery", { rfqId: event.params.rfqId });
    } catch (error: any) {
      logger.error("Failed to export RFQ to BigQuery", { 
        rfqId: event.params.rfqId, 
        error: error.message 
      });
    }
  })
);

/**
 * Export bid data to BigQuery when created
 */
export const exportBidToBigQuery = withMetrics("exportBidToBigQuery",
  onDocumentCreated("bids/{bidId}", async (event) => {
    const bidData = event.data?.data();
    if (!bidData) return;

    try {
      const bigQueryRow = {
        bid_id: event.params.bidId,
        rfq_id: bidData.rfqId,
        pro_id: bidData.proId,
        customer_id: bidData.customerId,
        amount_mad: bidData.priceMAD,
        timeline_days: bidData.timeline?.estimatedDays || null,
        includes_materials: bidData.proposal?.includesMaterials || false,
        visit_required: bidData.proposal?.visitRequired || false,
        status: bidData.status,
        negotiation_round: bidData.negotiationRound || 0,
        created_at: bidData.createdAt?.toDate()?.toISOString(),
        exported_at: new Date().toISOString()
      };

      await insertToBigQuery(TABLES.bids, [bigQueryRow]);
      
      logger.info("Bid exported to BigQuery", { bidId: event.params.bidId });
    } catch (error: any) {
      logger.error("Failed to export bid to BigQuery", { 
        bidId: event.params.bidId, 
        error: error.message 
      });
    }
  })
);

/**
 * Export contract data to BigQuery when created or status updated
 */
export const exportContractToBigQuery = withMetrics("exportContractToBigQuery",
  onDocumentUpdated("contracts/{contractId}", async (event) => {
    const afterData = event.data?.after.data();
    const beforeData = event.data?.before.data();
    if (!afterData) return;

    // Only export on creation or status change
    if (beforeData && beforeData.status === afterData.status) return;

    try {
      const bigQueryRow = {
        contract_id: event.params.contractId,
        rfq_id: afterData.rfqId,
        bid_id: afterData.bidId,
        customer_id: afterData.customerId,
        pro_id: afterData.proId,
        price_mad: afterData.priceMAD,
        deposit_amount: afterData.depositAmount || null,
        deposit_percent: afterData.depositPercent || null,
        status: afterData.status,
        auto_accepted: afterData.autoAccepted || false,
        milestone_count: afterData.milestones?.length || 0,
        created_at: afterData.createdAt?.toDate()?.toISOString(),
        started_at: afterData.startAt?.toDate()?.toISOString() || null,
        completed_at: afterData.completedAt?.toDate()?.toISOString() || null,
        exported_at: new Date().toISOString()
      };

      await insertToBigQuery(TABLES.contracts, [bigQueryRow]);
      
      logger.info("Contract exported to BigQuery", { contractId: event.params.contractId });
    } catch (error: any) {
      logger.error("Failed to export contract to BigQuery", { 
        contractId: event.params.contractId, 
        error: error.message 
      });
    }
  })
);

/**
 * Export escrow data to BigQuery when status changes
 */
export const exportEscrowToBigQuery = withMetrics("exportEscrowToBigQuery",
  onDocumentUpdated("escrows/{escrowId}", async (event) => {
    const afterData = event.data?.after.data();
    const beforeData = event.data?.before.data();
    if (!afterData) return;

    // Only export on status change
    if (beforeData && beforeData.status === afterData.status) return;

    try {
      const bigQueryRow = {
        escrow_id: event.params.escrowId,
        contract_id: afterData.contractId,
        customer_id: afterData.customerId,
        pro_id: afterData.proId,
        total_amount: afterData.totalAmount,
        deposit_amount: afterData.depositAmount,
        currency: afterData.currency,
        payment_method: afterData.paymentMethod?.type,
        status: afterData.status,
        milestone_payments_count: afterData.milestonePayments?.length || 0,
        created_at: afterData.createdAt?.toDate()?.toISOString(),
        paid_at: afterData.paidAt?.toDate()?.toISOString() || null,
        completed_at: afterData.completedAt?.toDate()?.toISOString() || null,
        exported_at: new Date().toISOString()
      };

      await insertToBigQuery(TABLES.escrows, [bigQueryRow]);
      
      logger.info("Escrow exported to BigQuery", { escrowId: event.params.escrowId });
    } catch (error: any) {
      logger.error("Failed to export escrow to BigQuery", { 
        escrowId: event.params.escrowId, 
        error: error.message 
      });
    }
  })
);

/**
 * Export review data to BigQuery when created
 */
export const exportReviewToBigQuery = withMetrics("exportReviewToBigQuery",
  onDocumentCreated("reviews/{reviewId}", async (event) => {
    const reviewData = event.data?.data();
    if (!reviewData) return;

    try {
      const bigQueryRow = {
        review_id: event.params.reviewId,
        contract_id: reviewData.contractId,
        rfq_id: reviewData.rfqId,
        reviewer_id: reviewData.reviewerId,
        reviewee_id: reviewData.revieweeId,
        reviewer_role: reviewData.reviewerRole,
        reviewee_role: reviewData.revieweeRole,
        rating: reviewData.rating,
        contract_value: reviewData.contractValue,
        service_category: reviewData.serviceCategory,
        is_suspicious: reviewData.isSuspicious || false,
        created_at: reviewData.createdAt?.toDate()?.toISOString(),
        exported_at: new Date().toISOString()
      };

      await insertToBigQuery(TABLES.reviews, [bigQueryRow]);
      
      logger.info("Review exported to BigQuery", { reviewId: event.params.reviewId });
    } catch (error: any) {
      logger.error("Failed to export review to BigQuery", { 
        reviewId: event.params.reviewId, 
        error: error.message 
      });
    }
  })
);

/**
 * Calculate and export daily business metrics
 * Runs every day at 1 AM
 */
export const exportDailyMetrics = withMetrics("exportDailyMetrics",
  onSchedule("0 1 * * *", async () => {
    try {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);
      
      const today = new Date(yesterday);
      today.setDate(today.getDate() + 1);

      const yesterdayTimestamp = admin.firestore.Timestamp.fromDate(yesterday);
      const todayTimestamp = admin.firestore.Timestamp.fromDate(today);

      // Calculate daily metrics
      const metrics = await calculateDailyMetrics(yesterdayTimestamp, todayTimestamp);

      const bigQueryRow = {
        date: yesterday.toISOString().split('T')[0],
        ...metrics,
        calculated_at: new Date().toISOString()
      };

      await insertToBigQuery(TABLES.daily_metrics, [bigQueryRow]);

      logger.info("Daily metrics exported to BigQuery", { 
        date: bigQueryRow.date,
        metrics 
      });

    } catch (error: any) {
      logger.error("Failed to export daily metrics", { error: error.message });
      throw error;
    }
  })
);

/**
 * Create BigQuery tables if they don't exist
 * Runs once on deployment
 */
export const createBigQueryTables = withMetrics("createBigQueryTables",
  onSchedule("0 0 1 1 *", async () => { // Runs once a year as a placeholder
    try {
      await ensureBigQueryTablesExist();
      logger.info("BigQuery tables verified/created");
    } catch (error: any) {
      logger.error("Failed to create BigQuery tables", { error: error.message });
    }
  })
);

// Helper Functions

async function insertToBigQuery(tableName: string, rows: any[]) {
  try {
    const dataset = bigquery.dataset(DATASET_ID);
    const table = dataset.table(tableName);

    await table.insert(rows, {
      ignoreUnknownValues: true,
      skipInvalidRows: false
    });

  } catch (error: any) {
    logger.error("BigQuery insert failed", { 
      table: tableName, 
      rowCount: rows.length,
      error: error.message 
    });
    throw error;
  }
}

async function calculateDailyMetrics(startTime: admin.firestore.Timestamp, endTime: admin.firestore.Timestamp) {
  const [
    rfqsSnapshot,
    bidsSnapshot,
    contractsSnapshot,
    escrowsSnapshot,
    reviewsSnapshot
  ] = await Promise.all([
    db.collection('rfqs')
      .where('createdAt', '>=', startTime)
      .where('createdAt', '<', endTime)
      .get(),
    db.collection('bids')
      .where('createdAt', '>=', startTime)
      .where('createdAt', '<', endTime)
      .get(),
    db.collection('contracts')
      .where('createdAt', '>=', startTime)
      .where('createdAt', '<', endTime)
      .get(),
    db.collection('escrows')
      .where('createdAt', '>=', startTime)
      .where('createdAt', '<', endTime)
      .get(),
    db.collection('reviews')
      .where('createdAt', '>=', startTime)
      .where('createdAt', '<', endTime)
      .get()
  ]);

  const rfqs = rfqsSnapshot.docs.map(doc => doc.data());
  const bids = bidsSnapshot.docs.map(doc => doc.data());
  const contracts = contractsSnapshot.docs.map(doc => doc.data());
  const escrows = escrowsSnapshot.docs.map(doc => doc.data());
  const reviews = reviewsSnapshot.docs.map(doc => doc.data());

  // Calculate key business metrics
  const totalRfqs = rfqs.length;
  const totalBids = bids.length;
  const totalContracts = contracts.length;
  const totalEscrows = escrows.length;
  const totalReviews = reviews.length;

  const avgBidsPerRfq = totalRfqs > 0 ? totalBids / totalRfqs : 0;
  const rfqToHireRate = totalRfqs > 0 ? totalContracts / totalRfqs : 0;

  const totalContractValue = contracts.reduce((sum, contract) => sum + (contract.priceMAD || 0), 0);
  const avgContractValue = totalContracts > 0 ? totalContractValue / totalContracts : 0;

  const escrowAdoptionRate = totalContracts > 0 ? totalEscrows / totalContracts : 0;

  const avgRating = reviews.length > 0 
    ? reviews.reduce((sum, review) => sum + review.rating, 0) / reviews.length 
    : 0;

  // Time to first bid calculation
  const rfqsWithBids = rfqs.filter(rfq => 
    bids.some(bid => bid.rfqId === rfq.id)
  );

  let avgTimeToFirstBidHours = 0;
  if (rfqsWithBids.length > 0) {
    const timeToFirstBids = rfqsWithBids.map(rfq => {
      const rfqBids = bids.filter(bid => bid.rfqId === rfq.id);
      const firstBid = rfqBids.reduce((earliest, bid) => 
        bid.createdAt < earliest.createdAt ? bid : earliest
      );
      return (firstBid.createdAt.toMillis() - rfq.createdAt.toMillis()) / (1000 * 60 * 60);
    });
    avgTimeToFirstBidHours = timeToFirstBids.reduce((sum, time) => sum + time, 0) / timeToFirstBids.length;
  }

  // Category breakdown
  const categoryStats = rfqs.reduce((acc, rfq) => {
    const category = rfq.categoryId;
    if (!acc[category]) {
      acc[category] = { rfqs: 0, contracts: 0 };
    }
    acc[category].rfqs++;
    
    const categoryContracts = contracts.filter(c => c.rfqId === rfq.id);
    acc[category].contracts += categoryContracts.length;
    
    return acc;
  }, {} as Record<string, {rfqs: number, contracts: number}>);

  return {
    total_rfqs: totalRfqs,
    total_bids: totalBids,
    total_contracts: totalContracts,
    total_escrows: totalEscrows,
    total_reviews: totalReviews,
    avg_bids_per_rfq: Math.round(avgBidsPerRfq * 100) / 100,
    rfq_to_hire_rate: Math.round(rfqToHireRate * 100) / 100,
    total_contract_value_mad: totalContractValue,
    avg_contract_value_mad: Math.round(avgContractValue),
    escrow_adoption_rate: Math.round(escrowAdoptionRate * 100) / 100,
    avg_rating: Math.round(avgRating * 100) / 100,
    avg_time_to_first_bid_hours: Math.round(avgTimeToFirstBidHours * 100) / 100,
    category_stats: JSON.stringify(categoryStats)
  };
}

async function ensureBigQueryTablesExist() {
  const dataset = bigquery.dataset(DATASET_ID);
  
  // Create dataset if it doesn't exist
  try {
    await dataset.create();
  } catch (error: any) {
    if (!error.message.includes('already exists')) {
      throw error;
    }
  }

  // Table schemas
  const schemas = {
    [TABLES.rfqs]: [
      { name: 'rfq_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'customer_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'category_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'location_city', type: 'STRING', mode: 'NULLABLE' },
      { name: 'location_region', type: 'STRING', mode: 'NULLABLE' },
      { name: 'budget_min_mad', type: 'FLOAT', mode: 'NULLABLE' },
      { name: 'budget_max_mad', type: 'FLOAT', mode: 'NULLABLE' },
      { name: 'urgency', type: 'STRING', mode: 'NULLABLE' },
      { name: 'site_visit_requested', type: 'BOOLEAN', mode: 'NULLABLE' },
      { name: 'status', type: 'STRING', mode: 'REQUIRED' },
      { name: 'created_at', type: 'TIMESTAMP', mode: 'REQUIRED' },
      { name: 'expires_at', type: 'TIMESTAMP', mode: 'NULLABLE' },
      { name: 'exported_at', type: 'TIMESTAMP', mode: 'REQUIRED' }
    ],
    [TABLES.bids]: [
      { name: 'bid_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'rfq_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'pro_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'customer_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'amount_mad', type: 'FLOAT', mode: 'REQUIRED' },
      { name: 'timeline_days', type: 'INTEGER', mode: 'NULLABLE' },
      { name: 'includes_materials', type: 'BOOLEAN', mode: 'NULLABLE' },
      { name: 'visit_required', type: 'BOOLEAN', mode: 'NULLABLE' },
      { name: 'status', type: 'STRING', mode: 'REQUIRED' },
      { name: 'negotiation_round', type: 'INTEGER', mode: 'NULLABLE' },
      { name: 'created_at', type: 'TIMESTAMP', mode: 'REQUIRED' },
      { name: 'exported_at', type: 'TIMESTAMP', mode: 'REQUIRED' }
    ],
    [TABLES.contracts]: [
      { name: 'contract_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'rfq_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'bid_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'customer_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'pro_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'price_mad', type: 'FLOAT', mode: 'REQUIRED' },
      { name: 'deposit_amount', type: 'FLOAT', mode: 'NULLABLE' },
      { name: 'deposit_percent', type: 'INTEGER', mode: 'NULLABLE' },
      { name: 'status', type: 'STRING', mode: 'REQUIRED' },
      { name: 'auto_accepted', type: 'BOOLEAN', mode: 'NULLABLE' },
      { name: 'milestone_count', type: 'INTEGER', mode: 'NULLABLE' },
      { name: 'created_at', type: 'TIMESTAMP', mode: 'REQUIRED' },
      { name: 'started_at', type: 'TIMESTAMP', mode: 'NULLABLE' },
      { name: 'completed_at', type: 'TIMESTAMP', mode: 'NULLABLE' },
      { name: 'exported_at', type: 'TIMESTAMP', mode: 'REQUIRED' }
    ],
    [TABLES.escrows]: [
      { name: 'escrow_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'contract_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'customer_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'pro_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'total_amount', type: 'FLOAT', mode: 'REQUIRED' },
      { name: 'deposit_amount', type: 'FLOAT', mode: 'REQUIRED' },
      { name: 'currency', type: 'STRING', mode: 'REQUIRED' },
      { name: 'payment_method', type: 'STRING', mode: 'NULLABLE' },
      { name: 'status', type: 'STRING', mode: 'REQUIRED' },
      { name: 'milestone_payments_count', type: 'INTEGER', mode: 'NULLABLE' },
      { name: 'created_at', type: 'TIMESTAMP', mode: 'REQUIRED' },
      { name: 'paid_at', type: 'TIMESTAMP', mode: 'NULLABLE' },
      { name: 'completed_at', type: 'TIMESTAMP', mode: 'NULLABLE' },
      { name: 'exported_at', type: 'TIMESTAMP', mode: 'REQUIRED' }
    ],
    [TABLES.reviews]: [
      { name: 'review_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'contract_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'rfq_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'reviewer_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'reviewee_id', type: 'STRING', mode: 'REQUIRED' },
      { name: 'reviewer_role', type: 'STRING', mode: 'REQUIRED' },
      { name: 'reviewee_role', type: 'STRING', mode: 'REQUIRED' },
      { name: 'rating', type: 'INTEGER', mode: 'REQUIRED' },
      { name: 'contract_value', type: 'FLOAT', mode: 'NULLABLE' },
      { name: 'service_category', type: 'STRING', mode: 'NULLABLE' },
      { name: 'is_suspicious', type: 'BOOLEAN', mode: 'NULLABLE' },
      { name: 'created_at', type: 'TIMESTAMP', mode: 'REQUIRED' },
      { name: 'exported_at', type: 'TIMESTAMP', mode: 'REQUIRED' }
    ],
    [TABLES.daily_metrics]: [
      { name: 'date', type: 'DATE', mode: 'REQUIRED' },
      { name: 'total_rfqs', type: 'INTEGER', mode: 'REQUIRED' },
      { name: 'total_bids', type: 'INTEGER', mode: 'REQUIRED' },
      { name: 'total_contracts', type: 'INTEGER', mode: 'REQUIRED' },
      { name: 'total_escrows', type: 'INTEGER', mode: 'REQUIRED' },
      { name: 'total_reviews', type: 'INTEGER', mode: 'REQUIRED' },
      { name: 'avg_bids_per_rfq', type: 'FLOAT', mode: 'NULLABLE' },
      { name: 'rfq_to_hire_rate', type: 'FLOAT', mode: 'NULLABLE' },
      { name: 'total_contract_value_mad', type: 'FLOAT', mode: 'NULLABLE' },
      { name: 'avg_contract_value_mad', type: 'FLOAT', mode: 'NULLABLE' },
      { name: 'escrow_adoption_rate', type: 'FLOAT', mode: 'NULLABLE' },
      { name: 'avg_rating', type: 'FLOAT', mode: 'NULLABLE' },
      { name: 'avg_time_to_first_bid_hours', type: 'FLOAT', mode: 'NULLABLE' },
      { name: 'category_stats', type: 'STRING', mode: 'NULLABLE' },
      { name: 'calculated_at', type: 'TIMESTAMP', mode: 'REQUIRED' }
    ]
  };

  // Create tables
  for (const [tableName, schema] of Object.entries(schemas)) {
    const table = dataset.table(tableName);
    
    try {
      await table.create({ schema });
      logger.info(`Created BigQuery table: ${tableName}`);
    } catch (error: any) {
      if (!error.message.includes('already exists')) {
        logger.error(`Failed to create table ${tableName}`, { error: error.message });
      }
    }
  }
}