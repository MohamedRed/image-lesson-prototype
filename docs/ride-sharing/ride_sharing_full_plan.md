# Live, In-City Ride-Sharing – Full Architecture & Algorithm Plan

> Canonical matching source: [`canonical_algorithm.md`](./canonical_algorithm.md). If this older plan or code disagrees with the canonical algorithm, update them to match the canonical spec.

A blueprint for an iOS-first, Firebase-backed, LiveKit-enabled platform that guarantees:
• legal curb-side pick-ups / drop-offs (no congestion)
• single-gender safety pools
• real-time seat, luggage, pet & child-seat constraints
• premium ride options, cost-share pricing
• single- or multi-hop journeys (≤3 legs) selected in <1 s.

---

## 0. High-Level Flow

1. **Driver** publishes route & location → backend updates `drivers/*`.
2. **Matcher** filters drivers by gender, curb capacity, seats, etc.
3. If single-hop impossible → Multi-hop planner finds 2- or 3-leg path.
4. Proposal sent; on accept LiveKit room opens for voice.
5. Driver stops at **legal curb with free capacity**; rider walks (isochrone).
6. Ledger releases seats/cargo when leg completes; Stripe captures fare.

---

## 1. Tech Stack

| Layer                  | MVP Choice                    | Scale-up Inspiration |
|------------------------|-------------------------------|----------------------|
| Mobile runtime         | SwiftUI + Combine             | – |
| Realtime media         | LiveKit (audio/data)          | – |
| Maps / nav / curb data | Mapbox Navigator + Curb       | – |
| Geofence / isochrones  | Radar SDK + Mapbox API        | – |
| Auth                   | Firebase Auth                 | – |
| OLTP DB                | Firestore                     | Bigtable (later) |
| Functions (light)      | Cloud Functions v2 (TS)       | – |
| Match-Planner (heavy)  | Cloud Run (Go)                | GKE Autopilot |
| Event bus              | Pub/Sub                       | Kafka-style TTL |
| Analytics              | BigQuery + Data Connect       | Vertex AI |
| Payments / ID verify   | Stripe Connect + Identity     | – |

---

## 2. Firestore Schema (online)

```text
 drivers/<id>
   capacitySeats: Int
   bufferPolygon: GeoJSON
   currentLocation: GeoPoint
   gender: "female"|"male"|"nb"
   luggageCapacity: {backpack,suitcase,bulky}
   childSeatInventory: {infant,forward,booster}
   petLimits: {small,large}
   premiumCapabilities: {vehicleBrand,hasAC,...}
   routePolyline: String
   activePickups: Int
   legs[]            // seat ledger
   cargoLedger[]     // trunk ledger
   petLedger[]
   childSeatLedger[]
   currentPassengerGenders[]

 rideRequests/<id>
   origin,destination: GeoPoint
   geohash: String
   walkRadiusM: Int
   passengerCount: Int
   luggageManifest: {backpack,suitcase,bulky}
   pet: {class,count}|null
   childPassengers: [{ageYears,weightKg}]
   riderGender: "female"|"male"|"nb"
   premiumRequested: {...}
   oriWalkIso,destWalkIso,oriDriveIso: GeoJSON
   state: searching|proposed|accepted|...
   assignedDriverId: String?
   fareBreakdown: {...}
   fareMultiplier: Float
   createdAt: Timestamp

 pickupZones/<zoneId>   capacityCars, activePickups, queuedPickups[]
 curbSegments/<segId>   geometry, allowedUses, maxStopSeconds
 rideLegs/<rid>/<n>     pickupZoneId, dropZoneId, driverId, resources, status
```

---

## 3. Real-Time Services

| ID | Service (Cloud Fn / Run) | Job |
|----|--------------------------|-----|
| S1 | Driver-Watcher           | Buffer recompute ➜ single-hop matcher |
| S2 | Single-Hop Matcher       | Hard filters ➜ `reserveResourcesTx` |
| S3 | Multi-Hop Planner        | Time-expanded graph, ≤3 hops, same filters |
| S4 | Congestion Cron          | Maintain `activePickups`, shrink drive-iso |
| S5 | Pricing Engine           | Distance + surcharges × multiplier |
| S6 | Resource Sweeper         | Frees seats/cargo/pet/child after leg |
| S7 | Nightly Curb Import      | Mapbox ➜ `curbSegments/*` |
| S8 | Forecast Job             | BigQuery ML ➜ 10-min supply/demand heat-map |

Transactions in `reserveResourcesTx` atomically book seats, cargo, pets, child seats, **and genders**.

---

## 4. Matching Logic

**Hard filters**  
1. Gender pool consistent (driver & passengers).  
2. Legal curb + `activePickups < capacityCars`.  
3. Seats, child seats, luggage, pets fit inventory.  
4. Premium exclusivity (if requested).  
5. Required premium traits (brand, AC, etc.).

**Soft score**  
`score = w1·detour + w2·pickupETA + w3·seatLoad + w4·cargoLoad + w5·curbLoad + w6·premiumPenalty`

Accept if `score < threshold`.

---

## 5. Congestion-Avoidance

* Each curb seg mapped to `pickupZone` with `capacityCars`.
* `reserveResourcesTx` increments `activePickups`; sweeper decrements on departure.
* `curbZoneLoad` soft-penalises crowded curbs.
* If all curbs full, planner expands radius or retries.

---

## 6. Pricing

```
fare = ceil(
        distanceKm × costPerKm
      + seatSurcharge
      + luggageSurcharge
      + petSurcharge
      + childSeatSurcharge
     ) × premiumMultiplier
```

Breakdown stored in doc; Stripe PaymentIntent created up-front.

---

## 7. Safety & Compliance

* Gender-only pools, government-ID drivers.  
* Child-seat class enforced.  
* Legal curb data (Mapbox) + time windows.  
* Audio recording opt-in (LiveKit).  
* GDPR: purge GPS >30 days.

---

## 8. Observability & SLAs

* KPIs per zone: driver-accept <30 s P95, pickup ETA <2 min P80.  
* Cloud Trace IDs, RED dashboards, Slack alerts.

---

## 9. Test Matrix

* Unit ≥80 %: filters, pricing, curb legality, reservations.  
* Integration (emulator): single-hop, female-only with child seat, 2-hop transfer.  
* Load: 5 k drivers + 20 k riders → match <2 s.

---

## 10. Roll-Out Timeline

| Phase | Weeks | Milestone |
|-------|-------|-----------|
| 0     | 1-2   | LiveKitCore extract, Cloud Run skeleton |
| 1     | 3-4   | Firestore schema, curb import, single-hop matcher |
| 2     | 5-6   | Multi-hop planner, reserveTx, pricing, Stripe flow |
| 3     | 7-8   | Gender filter, seats/luggage/pet/child logic, iOS UI |
| 4     | 9-10  | Heat-map forecast, driver incentives, dashboards |
| 5     | 11-12 | Beta city launch, iterate curb & ML |

### iOS App Architecture Notes

**Development Mode Toggle Implementation:**
- `SettingsView.swift`: Contains toggle switch using `@AppStorage("useRealService")` for persistent preference
- `AppRootView.swift`: Floating gear button (top-right) opens settings sheet, passes mode to `RideMapContainerView`
- `RideMapContainerView`: Accepts `useRealService` boolean, initializes appropriate service:
  - Demo Mode: `MockRideSharingService` with simulated driver "Alice" moving diagonally
  - Live Mode: `RideLiveKitService` connecting to real backend (requires backend setup)
- `RideHUD`: Visual indicator badge showing "Demo" (orange) or "Live" (green) with appropriate icons
- Xcode project must include `SettingsView.swift` in build sources

This allows developers and testers to easily switch between simulated and production environments without rebuilding the app, crucial for development workflow and demos.

---

## 11. Deliverables Checklist

☐ Firestore rules & indexes  
☐ Cloud Functions repo (S1-S6)  
☐ Cloud Run Match-Planner (S3)  
☐ Nightly curb import + Terraform infra  
☐ iOS modules: LiveKitCore, RideSharingService, RideSharingFeature  
☐ **iOS Demo/Live Mode Toggle**: Settings view with `@AppStorage("useRealService")` toggle, allowing users to switch between `MockRideSharingService` (simulated driver movements) and `RideLiveKitService` (real backend). Visual indicator in HUD showing current mode (Demo/Live)  
☐ Stripe webhooks & payout scheduler  
☐ BigQuery schema + exports  
☐ Run-book, API docs, architecture diagram

---

## 12. Success Criteria

* ≥80 % of requests matched ≤30 s, pickup ETA ≤3 min.  
* Zero curb fines; regulators accept cost-share status.  
* Backend supports 10 k concurrent drivers, Cloud Run CPU <70 %.  
* Rider CSAT ≥4.7/5.

---

*This document is the canonical specification for developers and for AI Cursor to implement.* 

---

## 13. Appendix – Edge Cases & Unexpected Conditions

This appendix captures real-world scenarios that the platform must detect and mitigate. Each row pairs the condition with the mitigation already planned (or newly added).

| # | Scenario | Mitigation |
|---|----------|------------|
| 1 | **Gender-pool starvation** (no female drivers online) | Forecast gap KPI, app suggests schedule later or widen walk radius. |
| 2 | **Inventory mismatch** (driver removed child seat) | Driver app sends `inventoryHash`; mismatch auto-cancels & rematches. |
| 3 | **Transaction race** (two Fns reserve same curb) | Firestore transaction & retry on `ABORTED`. |
| 4 | **Curb overstay** (legal curb but > maxStopSeconds) | Sweeper flags `curbBlocked`, reduces `capacityCars`, planner reroutes. |
| 5 | **Lane blockage** (stalled in travel lane) | *Stuck-vehicle watchdog*: detects `!isMoving && !isOnCurb`; after 45 s writes `roadBlocks/*`; planner avoids edge; ops alerted. |
| 6 | **GPS drift urban canyon** | 50 m fallback geofence, UI arrow guidance. |
| 7 | **Curb data outdated** | Driver “Report curb usable” → nightly import diff. |
| 8 | **Push lost** | App listener fallback; driver auto-cancel after 30 s. |
| 9 | **LiveKit join fails** | TURN retry, fall back to text chat. |
| 10 | **App killed (iOS)** | Radar geofence + silent push to wake; driver countdown. |
| 11 | **Battery dies mid-trip** | Driver completes leg, fares settled; dispute flow. |
| 12 | **Card decline** | In-flight incremental auth; wallet balance fallback. |
| 13 | **Driver payout blocked** | Pre-check Stripe `requirements.pending` before going online. |
| 14 | **DST / currency rounding** | Pricing engine UTC + BigDecimal. |
| 15 | **Mis-gendered signup** | ID selfie vs doc gender, periodic reverify. |
| 16 | **Harassment despite pool** | In-app SOS, audio recording, incident report. |
| 17 | **Wrong child-seat install** | Photo verification / checklist. |
| 18 | **Pet allergy after pet ride** | Driver flag `petsCarried24h`; rider opt-out. |
| 19 | **Car breakdown mid-trip** | Driver "Breakdown" flow; auto-dispatch rematch. |
| 20 | **Firestore outage** | Multi-region; cached matches; Pub/Sub replay. |
| 21 | **Cold-start storm** | min-instances; move hot paths to Cloud Run. |
| 22 | **Unexpected surge while solo on-call** | Autoscaling limits; show queue estimate to users. |
| 23 | **Quota exhaustion** | Alerts at 70 %; script to request quota bump. |
| 24 | **Location spoofing** | GPS jitter detection, iOS `CLLocationSourceInformation`. |
| 25 | **Driver–rider collusion** | Trip distance vs expected; ML flag. |
| 26 | **Multi-account farming** | Device fingerprint + ID uniqueness. |
| 27 | **Metric DST skew** | Store UTC; BigQuery `TIMESTAMP_TRUNC`. |
| 28 | **GDPR deletion pre-settlement** | Pseudonymize keys; hard delete post-settlement. |

These mitigations are either already reflected in previous sections (curb capacity, lane blockage, sweeper, pricing, identity) or require the small additions noted here (`roadBlocks/*`, stuck-vehicle watchdog, etc.). 