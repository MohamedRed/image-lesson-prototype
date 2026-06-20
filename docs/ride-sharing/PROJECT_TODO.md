# 📌 Project To-Do List

> Generated from gap analysis against `docs/ride_sharing_full_plan.md` ({{date}})

---

## Legend
- [ ] pending / not started
- [>] in progress
- [x] completed / verified

---

## 1. Backend – Cloud Functions & Services

### 1.1 Forecasting (S8)
- [ ] Design BigQuery ML model (forecast 10-min driver/rider heat-map)
- [ ] Create `bigquery_forecast.sql` with model training + prediction queries
- [ ] Implement `forecastHeatMap.ts` scheduled Cloud Function
  - [ ] Query BigQuery ML prediction view
  - [ ] Write result docs to `heatMaps/{timestamp}`
  - [ ] Add custom latency / error metrics
- [ ] Write Jest unit test for Firestore writes
- [ ] Terraform scheduler + IAM bindings

### 1.2 Resource Reservation Transaction
- [ ] Implement `reserveResourcesTx.ts`
  - [ ] Atomic booking of `seats`, `cargo`, `pet`, `childSeat`, `gender pool`
  - [ ] Rollback on `ABORTED` retries
- [ ] Update `singleHopMatcher` to invoke reservation before proposal
- [ ] Unit tests covering seat overflow & race condition
- [ ] Extend Firestore rules to validate ledger consistency

### 1.3 Edge-Case Watchdogs
- [ ] **Stuck-Vehicle Watchdog** (`stuckVehicleWatch.ts`)
  - [ ] Trigger on driver location; detect `!isMoving && !isOnCurb`
  - [ ] Write `roadBlocks/*` doc; Slack alert
- [ ] **Gender-Pool Starvation KPI** (`genderPoolKpi.ts`)
  - [ ] Cloud Scheduler hourly; BigQuery aggregation ➜ Slack
- [ ] **Location Spoof Detector** (`locationSpoof.ts`)
  - [ ] Evaluate `CLLocationSourceInformation` jitter; flag suspicious
- [ ] **Inventory Hash Checker** (`inventoryHash.ts`)
  - [ ] Compare driver-reported hash vs stored; auto-cancel ride if mismatch

### 1.4 Stripe Enhancements
- [ ] Refund / dispute webhook handler
- [ ] Cron for webhook secret rotation reminder

---

## 2. Infrastructure-as-Code (Terraform)
- [ ] Module: Cloud Run `planner` service + IAM
- [ ] Module: BigQuery dataset `ride_sharing` & tables
- [ ] Module: Scheduler jobs (curb import, forecast, sweeper, congestion)
- [ ] Module: Pub/Sub topics (future event-bus)
- [ ] CI workflow to `terraform plan` on PR

---

## 3. iOS Frontend

### 3.1 Multi-Hop Journey UI
- [ ] Extend `RideSharingViewModel` to handle >1 leg
- [ ] Create `TransferPointView.swift` component (<100 LOC)
- [ ] Update `RideHUD` with leg progress indicators

### 3.2 SOS & Incident Reporting
- [ ] Add `SOSButton.swift` component
- [ ] Integrate voice recording opt-in with LiveKit

### 3.3 Payments UI
- [ ] Stripe card entry flow using `StripePaymentSheet`
- [ ] Display real-time `paymentStatus`

### 3.4 Codebase Hygiene
- [ ] Refactor SwiftUI views exceeding 100 LOC into sub-views/modules
- [ ] Add snapshot tests for new components

---

## 4. Data & Analytics
- [ ] BigQuery DDL in `infra/bigquery.sql`
- [ ] Define Looker dashboard source queries
- [ ] Export job coverage tests (mock BigQuery)

---

## 5. Documentation & Knowledge Base
- [ ] `docs/run_book.md` – on-call procedures, dashboards, escalation
- [ ] `docs/api.md` – HTTP & Pub/Sub message schemas
- [ ] Architecture diagram (`docs/architecture.mmd` Mermaid C4)
- [ ] Create `docs/common_error.md`; append fixes as they occur

---

## 6. House-Keeping
- [ ] `.gitignore` updates (build.log, DerivedData, *.xcresult)
- [ ] Remove legacy prototype views superseded by package modules
- [ ] Enable Dependabot + Renovate for JS / Go / Swift packages 