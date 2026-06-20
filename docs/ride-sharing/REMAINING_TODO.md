# 📌 Remaining To-Do List (Post-Audit)

> Scope: ONLY the gaps still outstanding after the 95 %-complete implementation audit.
> Updated {{date}}

Legend —
- [ ] pending / not started  
- [>] in progress  
- [x] completed / verified

---

## 1. Backend & Cloud Functions

### 1.1 GDPR & Data-Retention
- [ ] Extend *GDPR purge* window from **24 h ➜ 30 days** in `sweeper.ts`
  - [ ] Make retention period configurable via environment variable `RETENTION_DAYS`
  - [ ] Unit test to verify TTL query range
  - [ ] Update run-book section “GDPR purge”

### 1.2 Load-Test Harness
- [ ] Create k-Driver / 20 k-Rider load-test script
  - [ ] Cloud Run **locust** image or k6 scenario
  - [ ] Synthetic driver publisher → `drivers/*`
  - [ ] Synthetic rider generator → `rideRequests/*`
  - [ ] Export latency metrics & compare SLA (<2 s match)
- [ ] GitHub Action to run nightly in staging project

### 1.3 Multi-Hop Journey Planning ✅ COMPLETED
- [x] Basic two-hop fallback implemented in Go planner
- [x] Extend to support 3-leg journeys (plan requirement: ≤3 hops)
- [x] Replace midpoint transfer with intelligent curb selection using `curbSegments` data
- [x] Implement time-expanded graph algorithm for optimal multi-hop planning
- [x] Add resource reservation across multiple legs via `reserveMultiLegResources`
- [x] Handle gender pool consistency across transfer points
- [x] Update iOS UI with sophisticated `MultiLegProgressView` component

### 1.4 BigQuery Aggregation Procedure CI
- [ ] Cloud Build step to run `CALL refresh_hourly_aggregation()` after every Terraform apply
- [ ] Alert on procedure failure via custom metric `custom.googleapis.com/bq/aggregation_failure`

---

## 2. Infrastructure-as-Code

### 2.1 Secret Seeding Pipeline
- [ ] Populate Secret-Manager versions for: `slack-webhook-url`, `mapbox-access-token`, `stripe-secret-key`, `stripe-webhook-secret` in all environments via Terraform `google_secret_manager_secret_version` *OR* bootstrap script
- [ ] Terraform Cloud/CI var-file templates for **dev**, **staging**, **prod**

### 2.2 Remote State & CI
- [ ] Enable Terraform remote backend (GCS bucket + state-lock) — *currently local*
- [ ] GitHub Actions workflow: `terraform fmt → validate → plan → apply (manual)`

---

## 3. iOS Application

### 3.1 Radar SDK & Walk Isochrones
- [ ] Integrate **Radar iOS SDK** for on-device geofences & walk-radius calculations
  - [ ] Request fine-location permission prompt flow
  - [ ] Upload device-side walk-iso to Firestore field `oriWalkIso`
  - [ ] Unit/UI tests for permission edge-cases
- [ ] Remove provisional placeholder in planner (currently assumes 200 m constant)

### 3.2 Payments UI Polishing
- [ ] Stripe **PaymentSheet** integration with test cards
- [ ] Error-state handling (network, 3-D Secure)
- [ ] Snapshot tests for PaymentSheet flow

### 3.3 Push-Notification Reliability
- [ ] Add APNS VoIP token registration for background wake
- [ ] Fallback reconnection if rider app killed (edge-case #10)

---

## 4. Load & Performance Tests
- [ ] JMeter / Locust scenario for function P95 latency under 5 k concurrent drivers
- [ ] BigQuery ML prediction latency benchmark (<3 s per query)

---

## 5. Documentation / Ops
- [ ] Insert **Radar SDK** section into `docs/api.md` & `architecture.mmd`
- [ ] Add **load-test handbook** section into `docs/run_book.md`
- [ ] Update `docs/common_error.md` with any new issues found during load test

---

## 6. Nice-to-Have / Stretch
- [ ] Automated “driver incentives” pipeline (forecast gap ➜ SMS incentives) — plan §4 note
- [ ] Vertex-AI uplift for demand forecasting after launch

---

> **Next audit gate**: All above items must be [x] before Beta city launch (Road-map Phase 5). 