import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";
import { reserveCommission, captureCommission, releaseCommission } from "./wallet";
import { StripePaymentService } from "../services/payments/stripeService";
import { DlocalService } from "../services/payments/dlocalService";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();

// Utility
function requireAuth(context: any): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new Error("Authentication required");
  }
  return uid;
}

// ----- Categories (Admin) -----

export const createCategory = withMetrics("createCategory:onCall",
  onCall(async (request) => {
    const uid = requireAuth(request);
    // Require admin custom claim
    if (!request.auth?.token?.admin) {
      throw new Error("Admin access required");
    }

    const { name, nameAr, nameFr, icon, attributesSchema, displayOrder } = request.data || {};
    if (!name || !icon) {
      throw new Error("Name and icon are required");
    }

    const categoryData = {
      name,
      nameAr: nameAr || null,
      nameFr: nameFr || null,
      icon,
      attributesSchema: attributesSchema || {},
      isActive: true,
      displayOrder: displayOrder || 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: uid,
    };

    const docRef = await db.collection('serviceCategories').add(categoryData);
    logger.info("Callable:createCategory", { categoryId: docRef.id, name });
    return { categoryId: docRef.id };
  })
);

export const updateCategory = withMetrics("updateCategory:onCall",
  onCall(async (request) => {
    requireAuth(request);
    if (!request.auth?.token?.admin) {
      throw new Error("Admin access required");
    }

    const { categoryId, ...updates } = request.data || {};
    if (!categoryId) throw new Error("Category ID is required");

    delete (updates as any).createdAt;
    (updates as any).updatedAt = admin.firestore.FieldValue.serverTimestamp();

    await db.collection('serviceCategories').doc(categoryId).update(updates);
    logger.info("Callable:updateCategory", { categoryId });
    return { success: true };
  })
);

// ----- RFQs -----

export const createRfq = withMetrics("createRfq:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { categoryId, scope, location, budgetRange, siteVisitRequested, media } = request.data || {};
    if (!categoryId || !scope || !location) {
      throw new Error("Category, scope, and location are required");
    }

    // Validate category exists
    const categoryDoc = await db.collection('serviceCategories').doc(categoryId).get();
    if (!categoryDoc.exists) throw new Error("Invalid category");

    const rfqData = {
      customerId: userId,
      categoryId,
      scope: {
        title: scope.title,
        description: scope.description,
        urgency: scope.urgency || 'flexible',
        serviceDate: scope.serviceDate ? admin.firestore.Timestamp.fromDate(new Date(scope.serviceDate)) : null,
        timeWindow: scope.timeWindow || null,
        requirements: scope.requirements || [],
        photos: scope.photos || media || [],
      },
      location: (
        location.lat != null && location.lng != null
      ) ? {
        address: location.address || null,
        coordinates: new admin.firestore.GeoPoint(location.lat, location.lng),
        city: location.city,
        region: location.arrondissement || location.region || null,
      } : {
        address: location.address,
        coordinates: new admin.firestore.GeoPoint(location.coordinates.latitude, location.coordinates.longitude),
        city: location.city,
        region: location.region,
      },
      budgetRange: budgetRange ? {
        minMAD: budgetRange.min ?? budgetRange.minMAD,
        maxMAD: budgetRange.max ?? budgetRange.maxMAD,
        currency: 'MAD'
      } : null,
      siteVisitRequested: !!siteVisitRequested,
      status: 'open',
      bidCount: 0,
      viewCount: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)),
    };

    const docRef = await db.collection('rfqs').add(rfqData);
    logger.info("Callable:createRfq", { rfqId: docRef.id, customerId: userId });
    return { rfqId: docRef.id };
  })
);

export const updateRfq = withMetrics("updateRfq:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { rfqId, updates } = request.data || {};
    if (!rfqId) throw new Error("RFQ ID is required");

    const rfqRef = db.collection('rfqs').doc(rfqId);
    const rfqDoc = await rfqRef.get();
    if (!rfqDoc.exists) throw new Error("RFQ not found");
    const rfqData = rfqDoc.data()!;
    if (rfqData.customerId !== userId) throw new Error("Only the RFQ owner can update it");
    if (rfqData.status !== 'open') throw new Error("Cannot update RFQ that is not open");

    const safeUpdates = { ...updates } as any;
    delete safeUpdates.customerId;
    delete safeUpdates.createdAt;
    delete safeUpdates.bidCount;
    delete safeUpdates.viewCount;
    safeUpdates.updatedAt = admin.firestore.FieldValue.serverTimestamp();

    await rfqRef.update(safeUpdates);
    logger.info("Callable:updateRfq", { rfqId, userId });
    return { success: true };
  })
);

export const listAvailableRfqs = withMetrics("listAvailableRfqs:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { city, limit = 20 } = request.data || {};

    // Load pro profile for skills and service radius/area
    const profileDoc = await db.collection('proProfiles').doc(userId).get();
    if (!profileDoc.exists) throw new Error("Pro profile not found");
    const profile = profileDoc.data() as any;

    const skills: string[] = Array.isArray(profile.skills) ? profile.skills : [];
    const serviceCity: string = city || profile.serviceArea?.city;
    if (!serviceCity || skills.length === 0) return { rfqs: [] };

    // Basic feed: open RFQs in city, recently created; server-side filter by skills
    let query = db.collection('rfqs')
      .where('status', '==', 'open')
      .where('location.city', '==', serviceCity)
      .orderBy('createdAt', 'desc')
      .limit(Number(limit));

    const snap = await query.get();
    const filtered = snap.docs
      .map(d => ({ id: d.id, ...(d.data() as any) }))
      .filter(r => skills.includes(r.categoryId));

    // Cooldown: de-duplicate same customer RFQs recently contacted (optional)
    // Future: exclude RFQs where this pro has already bid
    const alreadyBidIds = new Set(
      (await db.collection('bids').where('proId', '==', userId).where('status', 'in', ['submitted','negotiating','accepted']).limit(100).get())
        .docs.map(b => (b.data() as any).rfqId)
    );

    const rfqs = filtered.filter(r => !alreadyBidIds.has(r.id));
    return { rfqs };
  })
);

// ----- Bids -----

export const submitBid = withMetrics("submitBid:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { rfqId, amountMAD, timelineDays, includesMaterials, visitRequired, message, autoAcceptAbove } = request.data || {};
    if (!rfqId || amountMAD == null) throw new Error("RFQ ID and amountMAD are required");

    const rfqDoc = await db.collection('rfqs').doc(rfqId).get();
    if (!rfqDoc.exists) throw new Error("RFQ not found");
    const rfq = rfqDoc.data()!;
    if (rfq.status !== 'open') throw new Error("RFQ is not open for bidding");
    if (rfq.customerId === userId) throw new Error("Cannot bid on your own RFQ");

    const existing = await db.collection('bids')
      .where('rfqId', '==', rfqId)
      .where('proId', '==', userId)
      .limit(1)
      .get();
    if (!existing.empty) throw new Error("You have already submitted a bid for this RFQ");

    const now = admin.firestore.FieldValue.serverTimestamp();
    const bidData = {
      rfqId,
      proId: userId,
      customerId: rfq.customerId,
      proposal: {
        description: message || '',
        includesMaterials: !!includesMaterials,
        visitRequired: !!visitRequired,
      },
      priceMAD: Number(amountMAD),
      milestones: [],
      timeline: timelineDays ? { estimatedDays: timelineDays, startDate: null, details: null } : null,
      status: 'submitted',
      negotiationRound: 0,
      maxNegotiationRounds: 3,
      autoAcceptAbove: autoAcceptAbove || null,
      createdAt: now,
      updatedAt: now,
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 48 * 60 * 60 * 1000)),
    } as any;

    const bidRef = await db.collection('bids').add(bidData);
    await rfqRefIncrement(rfqId, { bidCount: 1 });

    logger.info("Callable:submitBid", { rfqId, proId: userId, bidId: bidRef.id });
    return { bidId: bidRef.id };
  })
);

export const counterBid = withMetrics("counterBid:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { bidId, newAmountMAD, newTimelineDays, action } = request.data || {};
    if (!bidId) throw new Error("Bid ID is required");

    const bidRef = db.collection('bids').doc(bidId);
    const bidDoc = await bidRef.get();
    if (!bidDoc.exists) throw new Error("Bid not found");
    const bid = bidDoc.data()!;

    const isCustomer = bid.customerId === userId;
    const isPro = bid.proId === userId;
    if (!isCustomer && !isPro) throw new Error("Access denied");
    if (!['submitted', 'negotiating'].includes(bid.status)) throw new Error("Bid cannot be negotiated in current state");

    // Pro can accept/decline the customer's counter
    if (isPro && typeof action === 'string') {
      if (action === 'accept') {
        const last = (bid as any).lastCounterOffer;
        if (!last) throw new Error("No counter-offer to accept");
        await bidRef.update({
          priceMAD: last.priceMAD,
          milestones: last.milestones || bid.milestones,
          status: 'submitted',
          counterOfferAccepted: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        logger.info("Callable:counterBid:proAccept", { bidId, userId });
        return { bidId };
      } else if (action === 'decline') {
        await bidRef.update({
          status: 'declined',
          declinedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        logger.info("Callable:counterBid:proDecline", { bidId, userId });
        return { bidId };
      }
      // if action === 'counter', fall through to counter section
    }

    // Counter from either side
    if (newAmountMAD == null) throw new Error("newAmountMAD is required for counter");
    if ((bid.negotiationRound || 0) >= (bid.maxNegotiationRounds || 3)) throw new Error("Maximum negotiation rounds reached");

    const counterOffer = {
      priceMAD: Number(newAmountMAD),
      milestones: bid.milestones || [],
      message: null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      round: (bid.negotiationRound || 0) + 1,
      from: isCustomer ? 'customer' : 'professional',
      timelineDays: newTimelineDays ?? null,
    };

    await bidRef.update({
      status: 'negotiating',
      negotiationRound: admin.firestore.FieldValue.increment(1),
      lastCounterOffer: counterOffer,
      counterOffers: admin.firestore.FieldValue.arrayUnion(counterOffer),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Callable:counterBid", { bidId, userId, from: counterOffer.from });
    return { bidId };
  })
);

export const withdrawBid = withMetrics("withdrawBid:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { bidId } = request.data || {};
    if (!bidId) throw new Error("Bid ID is required");
    const bidRef = db.collection('bids').doc(bidId);
    const bidDoc = await bidRef.get();
    if (!bidDoc.exists) throw new Error("Bid not found");
    const bid = bidDoc.data()!;
    if (bid.proId !== userId) throw new Error("Access denied");
    if (bid.status === 'accepted') throw new Error("Cannot withdraw accepted bid");
    await bidRef.update({ status: 'withdrawn', withdrawnAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    logger.info("Callable:withdrawBid", { bidId, userId });
    return { success: true };
  })
);

export const getBid = withMetrics("getBid:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { bidId } = request.data || {};
    if (!bidId) throw new Error("Bid ID is required");
    const bidDoc = await db.collection('bids').doc(bidId).get();
    if (!bidDoc.exists) throw new Error("Bid not found");
    const bid = bidDoc.data()!;
    if (bid.proId !== userId && bid.customerId !== userId) throw new Error("Access denied");
    return { id: bidDoc.id, ...bid };
  })
);

export const acceptBid = withMetrics("acceptBid:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { bidId, depositPercent = 20 } = request.data || {};
    if (!bidId) throw new Error("Bid ID is required");

    const result = await db.runTransaction(async (transaction) => {
      const bidRef = db.collection('bids').doc(bidId);
      const bidDoc = await transaction.get(bidRef);
      if (!bidDoc.exists) throw new Error("Bid not found");
      const bid = bidDoc.data()!;
      if (bid.customerId !== userId) throw new Error("Access denied");
      if (!['submitted', 'negotiating'].includes(bid.status)) throw new Error("Bid is no longer available");

      const rfqRef = db.collection('rfqs').doc(bid.rfqId);
      const rfqDoc = await transaction.get(rfqRef);
      if (!rfqDoc.exists) throw new Error("RFQ not found");
      const rfq = rfqDoc.data()!;
      if (rfq.status !== 'open') throw new Error("RFQ is no longer open");

      const contractRef = db.collection('contracts').doc();
      const contractData = {
        rfqId: bid.rfqId,
        bidId: bidId,
        customerId: bid.customerId,
        proId: bid.proId,
        agreedScope: rfq.scope,
        priceMAD: bid.priceMAD,
        milestones: bid.milestones || [],
        status: 'pending_payment',
        depositAmount: Math.round(bid.priceMAD * (depositPercent / 100)),
        depositPercent,
        paymentMethod: rfq.paymentMethod || 'card', // 'card' | 'cash'
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        startAt: null,
        completedAt: null,
      };
      transaction.set(contractRef, contractData);

      transaction.update(bidRef, { status: 'accepted', acceptedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      transaction.update(rfqRef, { status: 'awarded', awardedBidId: bidId, updatedAt: admin.firestore.FieldValue.serverTimestamp() });

      // Reject other bids
      const others = await db.collection('bids').where('rfqId', '==', bid.rfqId).where('status', 'in', ['submitted', 'negotiating']).get();
      others.docs.forEach(d => {
        if (d.id !== bidId) transaction.update(d.ref, { status: 'rejected', rejectedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      });

      return { contractId: contractRef.id, paymentMethod: contractData.paymentMethod };
    });

    // If cash job, reserve expected commission from wallet now
    if (result.paymentMethod === 'cash') {
      const commissionMAD = Math.max(5, Math.round((await estimateCommissionForContract(result.contractId))));
      try {
        await reserveCommission((await getContractById(result.contractId)).proId, commissionMAD);
      } catch (e:any) {
        logger.warn("Wallet reserve failed at acceptBid", { contractId: result.contractId, error: e?.message });
        throw new Error("WALLET_TOPUP_REQUIRED");
      }
    }

    logger.info("Callable:acceptBid", { bidId, userId, contractId: result.contractId });
    return result;
  })
);

// ----- RFQ management -----

export const cancelRfq = withMetrics("cancelRfq:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { rfqId, reason } = request.data || {};
    if (!rfqId) throw new Error("RFQ ID is required");

    const rfqRef = db.collection('rfqs').doc(rfqId);
    const rfqDoc = await rfqRef.get();
    if (!rfqDoc.exists) throw new Error("RFQ not found");
    const rfq = rfqDoc.data() as any;
    if (rfq.customerId !== userId) throw new Error("Only the RFQ owner can cancel it");
    if (!['open','draft'].includes(rfq.status)) throw new Error("RFQ cannot be cancelled in its current state");

    await rfqRef.update({
      status: 'cancelled',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledBy: userId,
      cancelReason: reason || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Callable:cancelRfq", { rfqId, userId });
    return { success: true };
  })
);

export const listBidsForRfq = withMetrics("listBidsForRfq:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { rfqId } = request.data || {};
    if (!rfqId) throw new Error("RFQ ID is required");

    const rfqDoc = await db.collection('rfqs').doc(rfqId).get();
    if (!rfqDoc.exists) throw new Error("RFQ not found");
    const rfq = rfqDoc.data() as any;

    const isCustomer = rfq.customerId === userId;
    let query = db.collection('bids').where('rfqId', '==', rfqId);
    if (!isCustomer) {
      // Only allow professional to view their own bid on this RFQ
      query = query.where('proId', '==', userId);
    }
    const snap = await query.orderBy('createdAt', 'desc').limit(50).get();
    const bids = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    return { bids };
  })
);

// ----- Contracts -----

export const completeContract = withMetrics("completeContract:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { contractId } = request.data || {};
    if (!contractId) throw new Error("Contract ID is required");
    const contractRef = db.collection('contracts').doc(contractId);
    const contractDoc = await contractRef.get();
    if (!contractDoc.exists) throw new Error("Contract not found");
    const contract = contractDoc.data()!;
    if (contract.customerId !== userId && contract.proId !== userId) throw new Error("Access denied");
    if (contract.status !== 'active') throw new Error("Contract must be active to complete");
    await contractRef.update({ status: 'completed', completedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });

    // Capture commission from wallet for cash jobs
    if (contract.paymentMethod === 'cash') {
      const commissionMAD = Math.max(5, Math.round(await estimateCommissionForContract(contractId)));
      try {
        await captureCommission(contract.proId, commissionMAD);
      } catch (e:any) {
        logger.error("Wallet capture failed on completion", { contractId, error: e?.message });
      }
    }
    logger.info("Callable:completeContract", { contractId, userId });
    return { success: true };
  })
);

export const cancelContract = withMetrics("cancelContract:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { contractId, reason } = request.data || {};
    if (!contractId) throw new Error("Contract ID is required");
    const ref = db.collection('contracts').doc(contractId);
    const doc = await ref.get();
    if (!doc.exists) throw new Error("Contract not found");
    const contract = doc.data()!;
    const isCustomer = contract.customerId === userId;
    const isProfessional = contract.proId === userId;
    if (!isCustomer && !isProfessional) throw new Error("Access denied");
    if (contract.status !== 'pending_payment') throw new Error("Can only cancel contracts before they start");
    await ref.update({ status: 'cancelled', cancelledBy: userId, cancelledRole: isCustomer ? 'customer' : 'professional', cancellationReason: reason || null, cancelledAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });

    if (contract.paymentMethod === 'cash') {
      const commissionMAD = Math.max(5, Math.round(await estimateCommissionForContract(contractId)));
      try {
        await releaseCommission(contract.proId, commissionMAD);
      } catch {}
    }
    logger.info("Callable:cancelContract", { contractId, userId });
    return { success: true };
  })
);

// Helpers for commission estimation and contract fetch
async function estimateCommissionForContract(contractId: string): Promise<number> {
  const doc = await db.collection('contracts').doc(contractId).get();
  if (!doc.exists) return 0;
  const c = doc.data() as any;
  const rate = 0.12; // 12% default commission; make configurable per category later
  return c?.priceMAD ? c.priceMAD * rate : 0;
}

async function getContractById(contractId: string): Promise<any> {
  const doc = await db.collection('contracts').doc(contractId).get();
  return { id: doc.id, ...(doc.data() || {}) };
}

// ----- Payments / Escrow -----

export const createEscrow = withMetrics("createEscrow:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { contractId, method, milestones } = request.data || {};
    if (!contractId || !method) throw new Error("Contract ID and method are required");
    const contractDoc = await db.collection('contracts').doc(contractId).get();
    if (!contractDoc.exists) throw new Error("Contract not found");
    const contract = contractDoc.data()!;
    if (contract.customerId !== userId) throw new Error("Only customer can create escrow payment");
    if (contract.status !== 'pending_payment') throw new Error("Contract is not awaiting payment");

    const existing = await db.collection('escrows').where('contractId', '==', contractId).where('status', 'in', ['pending', 'held']).get();
    if (!existing.empty) throw new Error("Escrow payment already exists for this contract");

    const escrowData = {
      contractId,
      customerId: contract.customerId,
      proId: contract.proId,
      totalAmount: contract.priceMAD,
      depositAmount: contract.depositAmount,
      remainingAmount: contract.priceMAD - (contract.depositAmount || 0),
      currency: 'MAD',
      paymentMethod: { type: method, provider: null, last4: null },
      status: 'pending',
      milestonePayments: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentIntentId: null,
      transactionId: null,
    } as any;

    if (Array.isArray(milestones)) escrowData.milestonePayments = milestones;
    // Initialize payment with provider
    if (method === 'card') {
      const intent = await StripePaymentService.createPaymentIntent({
        amount: Math.round((contract.depositAmount || contract.priceMAD) * 100),
        currency: 'mad',
        metadata: { contractId },
        captureMethod: 'manual',
      });
      escrowData.paymentMethod.provider = 'stripe';
      escrowData.paymentIntentId = intent.id;
      escrowData.clientSecret = intent.client_secret || null;
    } else if (method === 'cash') {
      const init = await DlocalService.initPayment({
        amount: contract.depositAmount || contract.priceMAD,
        currency: 'MAD',
        orderId: `escrow_${contractId}`,
        description: `Home Services deposit for contract ${contractId}`,
        method: 'CASH',
        channel: 'WAFACASH',
      });
      escrowData.paymentMethod.provider = 'dlocal';
      escrowData.transactionId = init.id;
      escrowData.redirectUrl = init.redirectUrl || null;
    }

    const ref = await db.collection('escrows').add(escrowData);
    logger.info("Callable:createEscrow", { escrowId: ref.id, contractId, provider: escrowData.paymentMethod.provider });
    return { escrowId: ref.id, clientSecret: escrowData.clientSecret, redirectUrl: escrowData.redirectUrl };
  })
);

export const releaseMilestone = withMetrics("releaseMilestone:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { escrowId, milestoneId } = request.data || {};
    if (!escrowId || !milestoneId) throw new Error("Escrow ID and milestone ID are required");
    const escrowRef = db.collection('escrows').doc(escrowId);
    const escrowDoc = await escrowRef.get();
    if (!escrowDoc.exists) throw new Error("Escrow not found");
    const escrow = escrowDoc.data()!;
    if (escrow.customerId !== userId) throw new Error("Only customer can release payments");
    if (escrow.status !== 'held') throw new Error("Escrow is not in held status");

    // Try to derive milestone amount from contract
    let amount = 0;
    const contractDoc = await db.collection('contracts').doc(escrow.contractId).get();
    if (contractDoc.exists) {
      const contract = contractDoc.data() as any;
      const m = (contract.milestones || []).find((x: any) => x.id === milestoneId);
      if (m && typeof m.amountMAD === 'number') amount = m.amountMAD;
    }

    const payment = { milestoneId, amount, releasedAt: admin.firestore.FieldValue.serverTimestamp(), transactionId: `txn_milestone_${Date.now()}` };
    await escrowRef.update({ milestonePayments: admin.firestore.FieldValue.arrayUnion(payment), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    logger.info("Callable:releaseMilestone", { escrowId, milestoneId, amount });
    return { transactionId: payment.transactionId };
  })
);

// ----- Reviews -----

export const createReview = withMetrics("createReview:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { contractId, rating, text } = request.data || {};
    if (!contractId || rating == null) throw new Error("Contract ID and rating are required");
    if (rating < 1 || rating > 5) throw new Error("Rating must be between 1 and 5");
    const contractDoc = await db.collection('contracts').doc(contractId).get();
    if (!contractDoc.exists) throw new Error("Contract not found");
    const contract = contractDoc.data()!;
    const isCustomer = contract.customerId === userId;
    const isProfessional = contract.proId === userId;
    if (!isCustomer && !isProfessional) throw new Error("Access denied");
    if (contract.status !== 'completed') throw new Error("Can only review completed contracts");
    const existing = await db.collection('reviews').where('contractId', '==', contractId).where('reviewerId', '==', userId).limit(1).get();
    if (!existing.empty) throw new Error("Review already exists for this contract");
    const review = {
      contractId,
      rfqId: contract.rfqId,
      reviewerId: userId,
      revieweeId: isCustomer ? contract.proId : contract.customerId,
      reviewerRole: isCustomer ? 'customer' : 'professional',
      revieweeRole: isCustomer ? 'professional' : 'customer',
      rating: Number(rating),
      text: text || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    const ref = await db.collection('reviews').add(review);
    logger.info("Callable:createReview", { reviewId: ref.id, contractId, rating });
    return { reviewId: ref.id };
  })
);

// ----- Messaging -----

export const sendMessage = withMetrics("sendMessage:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { conversationId, conversationType, text, attachments } = request.data || {};
    if (!conversationId || !conversationType || !text) throw new Error("Conversation ID, type, and text are required");

    const hasAccess = await validateConversationAccess(userId, conversationId, conversationType);
    if (!hasAccess) throw new Error("Access denied to this conversation");

    const redactedText = redactPII(String(text));

    const messageData = {
      conversationId,
      conversationType,
      senderId: userId,
      text: redactedText,
      originalText: text !== redactedText ? text : null,
      attachments: Array.isArray(attachments) ? attachments : [],
      type: 'chat',
      piiRedacted: text !== redactedText,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      readBy: [userId],
    };

    const messageRef = await db.collection('messages').add(messageData);
    await updateConversationMetadata(conversationId, conversationType, messageData);

    logger.info("Callable:sendMessage", { messageId: messageRef.id, conversationId, conversationType });
    return { messageId: messageRef.id, text: redactedText, piiRedacted: messageData.piiRedacted };
  })
);

export const markMessagesRead = withMetrics("markMessagesRead:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { conversationId, conversationType, lastMessageId } = request.data || {};
    if (!conversationId || !conversationType) throw new Error("Conversation ID and type are required");

    const hasAccess = await validateConversationAccess(userId, conversationId, conversationType);
    if (!hasAccess) throw new Error("Access denied to this conversation");

    let query = db.collection('messages')
      .where('conversationId', '==', conversationId)
      .where('conversationType', '==', conversationType)
      .orderBy('createdAt', 'desc')
      .limit(100);

    if (lastMessageId) {
      const lastDoc = await db.collection('messages').doc(String(lastMessageId)).get();
      if (lastDoc.exists) query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    const unread = snap.docs.filter(d => {
      const m = d.data() as any;
      return m.senderId !== userId && !(m.readBy || []).includes(userId);
    });
    if (unread.length > 0) {
      const batch = db.batch();
      unread.forEach(d => batch.update(d.ref, { readBy: admin.firestore.FieldValue.arrayUnion(userId) }));
      await batch.commit();
    }
    return { marked: unread.length };
  })
);

// ----- Admin -----

export const verifyProfessional = withMetrics("verifyProfessional:onCall",
  onCall(async (request) => {
    const uid = requireAuth(request);
    if (!request.auth?.token?.admin) {
      throw new Error("Admin access required");
    }
    const { proId } = request.data || {};
    if (!proId) throw new Error("proId is required");

    const profileRef = db.collection('proProfiles').doc(proId);
    await profileRef.set({
      verification: {
        isVerified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        verifiedBy: uid,
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Write audit log
    await db.collection('auditLogs').add({
      actorId: uid,
      action: 'verifyProfessional',
      proId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      feature: 'home-services',
    }).catch(() => {});

    logger.info("Callable:verifyProfessional", { proId, adminId: uid });
    return { success: true };
  })
);

export const getMessages = withMetrics("getMessages:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { conversationId, conversationType, limit = 50, lastMessageId } = request.data || {};
    if (!conversationId || !conversationType) throw new Error("Conversation ID and type are required");

    const hasAccess = await validateConversationAccess(userId, conversationId, conversationType);
    if (!hasAccess) throw new Error("Access denied to this conversation");

    let query = db.collection('messages')
      .where('conversationId', '==', conversationId)
      .where('conversationType', '==', conversationType)
      .orderBy('createdAt', 'desc')
      .limit(Number(limit));

    if (lastMessageId) {
      const lastDoc = await db.collection('messages').doc(String(lastMessageId)).get();
      if (lastDoc.exists) query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    const messages = snap.docs.map(d => ({ id: d.id, ...d.data() }));

    // Mark as read
    const unread = messages.filter((m: any) => m.senderId !== userId && !(m.readBy || []).includes(userId));
    if (unread.length > 0) {
      const batch = db.batch();
      unread.forEach(m => batch.update(db.collection('messages').doc(m.id), { readBy: admin.firestore.FieldValue.arrayUnion(userId) }));
      await batch.commit();
    }

    return { messages: messages.reverse(), hasMore: snap.size === Number(limit) };
  })
);

// ----- Disputes -----

export const createDispute = withMetrics("createDispute:onCall",
  onCall(async (request) => {
    const userId = requireAuth(request);
    const { contractId, reason, description, evidence, requestedResolution } = request.data || {};
    if (!contractId || !reason || !description) throw new Error("Contract ID, reason, and description are required");

    const contractDoc = await db.collection('contracts').doc(contractId).get();
    if (!contractDoc.exists) throw new Error("Contract not found");
    const contract = contractDoc.data()!;
    const isCustomer = contract.customerId === userId;
    const isProfessional = contract.proId === userId;
    if (!isCustomer && !isProfessional) throw new Error("Access denied to this contract");

    const active = await db.collection('disputes')
      .where('contractId', '==', contractId)
      .where('status', 'in', ['open', 'investigating', 'mediation'])
      .limit(1)
      .get();
    if (!active.empty) throw new Error("Active dispute already exists for this contract");

    const disputeData = {
      contractId,
      rfqId: contract.rfqId,
      customerId: contract.customerId,
      proId: contract.proId,
      reporterId: userId,
      reporterRole: isCustomer ? 'customer' : 'professional',
      respondentId: isCustomer ? contract.proId : contract.customerId,
      respondentRole: isCustomer ? 'professional' : 'customer',
      reason,
      description,
      evidence: Array.isArray(evidence) ? evidence : [],
      requestedResolution: requestedResolution || null,
      status: 'open',
      priority: (contract.priceMAD > 5000 || ['payment_dispute','safety_concern'].includes(String(reason))) ? 'high' : 'low',
      escalationLevel: 1,
      assignedTo: null,
      internalNotes: [],
      timeline: [{ action: 'created', timestamp: admin.firestore.FieldValue.serverTimestamp(), userId, role: isCustomer ? 'customer' : 'professional', details: 'Dispute created' }],
      responses: [],
      resolution: null,
      resolutionType: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      dueDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)),
    } as any;

    const ref = await db.collection('disputes').add(disputeData);
    await contractDoc.ref.update({ status: 'disputed', disputeId: ref.id, updatedAt: admin.firestore.FieldValue.serverTimestamp() });

    logger.info("Callable:createDispute", { disputeId: ref.id, contractId });
    return { disputeId: ref.id, status: 'open' };
  })
);

// --- helpers (copied from HTTP messages logic) ---
async function validateConversationAccess(userId: string, conversationId: string, conversationType: string): Promise<boolean> {
  try {
    if (conversationType === 'rfq') {
      const rfqDoc = await db.collection('rfqs').doc(conversationId).get();
      if (!rfqDoc.exists) return false;
      const rfq = rfqDoc.data()!;
      if (rfq.customerId === userId) return true;
      const bid = await db.collection('bids').where('rfqId', '==', conversationId).where('proId', '==', userId).limit(1).get();
      return !bid.empty;
    } else if (conversationType === 'contract') {
      const cDoc = await db.collection('contracts').doc(conversationId).get();
      if (!cDoc.exists) return false;
      const c = cDoc.data()!;
      return c.customerId === userId || c.proId === userId;
    }
    return false;
  } catch (e) {
    logger.error("validateConversationAccess error", { e, userId, conversationId, conversationType });
    return false;
  }
}

function redactPII(text: string): string {
  let t = text;
  t = t.replace(/(\+212|0)[5-7]\d{8}/g, '[PHONE_REDACTED]');
  t = t.replace(/\+\d{1,3}[-.\s]?\d{6,14}/g, '[PHONE_REDACTED]');
  t = t.replace(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, '[EMAIL_REDACTED]');
  t = t.replace(/https?:\/\/[^\s]+/g, '[LINK_REDACTED]');
  t = t.replace(/whatsapp|wa\.me/gi, '[WHATSAPP_REDACTED]');
  return t;
}

async function updateConversationMetadata(conversationId: string, conversationType: string, messageData: any) {
  try {
    const coll = conversationType === 'rfq' ? 'rfqs' : 'contracts';
    await db.collection(coll).doc(conversationId).update({
      lastMessageAt: messageData.createdAt,
      lastMessageFrom: messageData.senderId,
      lastMessagePreview: String(messageData.text || '').substring(0, 100),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    logger.warn("updateConversationMetadata failed", { e, conversationId, conversationType });
  }
}

// Helpers
async function rfqRefIncrement(rfqId: string, increments: { bidCount?: number }) {
  const rfqRef = db.collection('rfqs').doc(rfqId);
  const inc: any = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
  if (typeof increments.bidCount === 'number') inc.bidCount = admin.firestore.FieldValue.increment(increments.bidCount);
  await rfqRef.update(inc).catch(async () => {
    // if rfq removed, ignore
  });
}


