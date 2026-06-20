# Common Error Solutions

> A knowledge base of hard problems and their solutions for the ride sharing platform.

---

## Secret Management Implementation (2024-12)

### Problem
Third-party service API keys were inconsistently managed - some using Google Cloud Secret Manager (LiveKit), others using environment variables (Stripe, Mapbox, Slack).

### Solution
- **Created shared secret manager utility** (`backend/functions/src/secretManager.ts`)
- **Updated all services** to use Secret Manager consistently:
  - Stripe: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
  - Mapbox: `MAPBOX_ACCESS_TOKEN`
  - Slack: `SLACK_WEBHOOK_URL`
  - LiveKit: `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_WS_URL`
- **Updated infrastructure** to properly define all secrets
- **Consistent secret naming** using kebab-case (e.g., `stripe-secret-key`)

### Key Implementation Details
- Implemented caching for secret retrieval to avoid repeated API calls
- Used async initialization patterns for Stripe client
- Added proper error handling for secret retrieval failures
- Updated infrastructure to include missing LiveKit WebSocket URL secret

### Files Modified
- `backend/functions/src/secretManager.ts` (new shared utility)
- `backend/functions/src/index.ts` (Stripe webhook updates)
- `backend/functions/src/payoutScheduler.ts` (Stripe payout updates)
- `backend/functions/src/curbImport.ts` (Mapbox and Slack updates)
- `backend/functions/src/livekitToken.ts` (refactored to use shared utility)
- `infra/main.tf` (added LiveKit secrets)
- `infra/modules/secrets/main.tf` (added missing LiveKit WS URL)
- `infra/bootstrap/seed-secrets.sh` (added LiveKit WS URL seeding)

---

## Performance Testing Issues

### Error: "JMeter test fails with timeout errors"

**Problem**: JMeter reports high response times (>10s), many requests timeout with 504 Gateway Timeout, load test fails to complete.

**Root Cause**: Cloud Functions cold starts under load, insufficient concurrency limits, database connection pool exhaustion.

**Solution**:
```bash
# Increase Cloud Function timeout and memory
gcloud functions deploy myFunction \
  --timeout=540s \
  --memory=2GB \
  --min-instances=5

# Update Firestore connection pooling
export FIRESTORE_MAX_CONNECTIONS=100

# Run test with gradual ramp-up
./run-performance-tests.sh staging load 100 300
```

### Error: "P95 latency exceeds SLA (>2000ms)"

**Problem**: Performance tests show P95 > 2000ms, SLA violation alerts triggered, user complaints about slow matching.

**Root Cause**: Inefficient database queries, missing Firestore indexes, network latency to external APIs.

**Solution**:
```bash
# Check for missing indexes
firebase firestore:indexes

# Optimize query patterns - use composite indexes for complex queries
# Implement query result caching

# Profile external API calls
curl -w "@curl-format.txt" -s -o /dev/null \
  https://api.stripe.com/v1/payment_intents
```

### Error: "Load test shows high error rate (>5%)"

**Problem**: Many 500 Internal Server Error responses, function execution errors in logs, database write conflicts.

**Root Cause**: Race conditions in resource reservation, insufficient error handling, database transaction conflicts.

**Solution**:
```typescript
// Implement retry logic with exponential backoff
const retry = async (fn: () => Promise<any>, retries = 3): Promise<any> => {
  try {
    return await fn();
  } catch (error: any) {
    if (retries > 0 && error.code === 'aborted') {
      await new Promise(resolve => setTimeout(resolve, Math.random() * 1000));
      return retry(fn, retries - 1);
    }
    throw error;
  }
};

// Use transactions for atomic operations
await db.runTransaction(async (transaction) => {
  // Atomic resource reservation logic
});
```

---

## Backend Issues

### Cloud Functions

#### Error: "ABORTED" Firestore Transaction
**Problem**: Firestore transactions fail with ABORTED status during high concurrency.

**Solution**:
```typescript
// Implement exponential backoff retry
async function runTransactionWithRetry<T>(
  db: admin.firestore.Firestore,
  updateFunction: (transaction: admin.firestore.Transaction) => Promise<T>,
  maxRetries = 5
): Promise<T> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await db.runTransaction(updateFunction);
    } catch (error: any) {
      if (error.code === 'aborted' && attempt < maxRetries - 1) {
        const delay = Math.min(1000 * Math.pow(2, attempt), 10000);
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }
      throw error;
    }
  }
  throw new Error('Transaction failed after maximum retries');
}
```

#### Error: BigQuery ML Model Not Found
**Problem**: `forecastHeatMap` function fails with "Model not found" error.

**Solution**:
1. Ensure BigQuery dataset exists: `bq ls ride_sharing_dev`
2. Create model manually if missing:
```sql
-- Run this in BigQuery console
CREATE OR REPLACE MODEL `ride_sharing_dev.demand_supply_forecast_model`
OPTIONS (
  model_type = 'BOOSTED_TREE_REGRESSOR',
  input_label_cols = ['demand_count', 'supply_count']
) AS
SELECT * FROM `ride_sharing_dev.ml_training_features`
WHERE hour_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
LIMIT 1000;
```

#### Error: Stripe Webhook Signature Verification Failed
**Problem**: `stripeWebhook` function returns 400 with signature mismatch.

**Solution**:
```typescript
// Ensure raw body is preserved
export const stripeWebhook = onRequest({ 
  maxBodySize: "2mb", 
  cors: true,
  preserveRawBody: true  // Add this
}, async (req, res) => {
  const sig = req.headers["stripe-signature"] as string;
  const rawBody = req.rawBody as Buffer;  // Use rawBody, not body
  
  const evt = stripe.webhooks.constructEvent(
    rawBody, 
    sig, 
    process.env.STRIPE_WEBHOOK_SECRET!
  );
  // ... rest of handler
});
```

### Cloud Run Issues

#### Error: Go Planner Service Memory Exhaustion
**Problem**: Planner service crashes with "out of memory" during complex multi-hop planning.

**Solution**:
1. Increase memory limit in Terraform:
```hcl
module "planner" {
  memory = "1Gi"  # Increase from 512Mi
  cpu    = "2000m"  # Also increase CPU
}
```

2. Add memory optimization in Go:
```go
// Add periodic garbage collection
func (p *Planner) cleanupMemory() {
    ticker := time.NewTicker(5 * time.Minute)
    for range ticker.C {
        runtime.GC()
        debug.FreeOSMemory()
    }
}
```

---

## Infrastructure Issues

### Terraform

#### Error: "google_bigquery_routine" Resource Timeout
**Problem**: BigQuery procedure creation times out during `terraform apply`.

**Solution**:
```hcl
# Split procedure creation into separate apply
resource "google_bigquery_routine" "refresh_hourly_aggregation" {
  # Add explicit dependency and timeout
  depends_on = [google_bigquery_table.hourly_demand_supply]
  
  timeouts {
    create = "10m"
    update = "10m"
    delete = "5m"
  }
}
```

#### Error: Cloud Scheduler Job "Function Not Found"
**Problem**: Scheduler jobs fail because Cloud Functions aren't deployed yet.

**Solution**:
1. Deploy functions first: `firebase deploy --only functions`
2. Then apply Terraform: `terraform apply`
3. Or add explicit dependency:
```hcl
# In scheduler module
data "google_cloudfunctions_function" "functions" {
  for_each = local.scheduler_jobs
  name     = each.value.function
  region   = var.functions_location
}
```

### Secret Manager

#### Error: "Permission Denied" Accessing Secrets
**Problem**: Cloud Functions can't access Secret Manager secrets.

**Solution**:
```hcl
# Add Secret Manager accessor role
resource "google_project_iam_member" "functions_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_functions.email}"
}
```

---

## iOS Issues

### LiveKit Connection

#### Error: "Failed to Connect to Room"
**Problem**: iOS app can't connect to LiveKit room, shows connection timeout.

**Solution**:
1. Check token generation in backend:
```typescript
// Ensure correct room name and participant identity
const token = new AccessToken(apiKey, apiSecret, {
  identity: `rider_${userId}`,
  name: `Rider ${userName}`,
  ttl: '1h'
});
token.addGrant({ roomJoin: true, room: `ride_${rideId}` });
```

2. Add network debugging in iOS:
```swift
// In LiveKitService
private func setupRoom() {
    room.delegate = self
    
    // Add connection debugging
    room.connectionState
        .sink { state in
            print("LiveKit connection state: \(state)")
            if case .disconnected(let reason) = state {
                print("Disconnect reason: \(reason)")
            }
        }
        .store(in: &cancellables)
}
```

#### Error: Audio Not Working on Device
**Problem**: Audio works in simulator but not on physical device.

**Solution**:
```swift
// Configure audio session properly
func configureAudioSession() {
    do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try audioSession.setActive(true)
    } catch {
        print("Audio session configuration failed: \(error)")
    }
}
```

### SwiftUI Issues

#### Error: "View Update Causing Infinite Loop"
**Problem**: SwiftUI view updates cause infinite rendering loop.

**Solution**:
```swift
// Use @StateObject instead of @ObservedObject for root view models
struct RideSharingView: View {
    @StateObject private var viewModel = RideSharingViewModel()  // Not @ObservedObject
    
    var body: some View {
        // ... view content
    }
}

// Avoid computed properties that change frequently
struct RideHUD: View {
    @ObservedObject var viewModel: RideSharingViewModel
    
    // Cache expensive computations
    private var formattedETA: String {
        guard let eta = viewModel.state.etaSeconds else { return "—" }
        return DateComponentsFormatter.positional.string(from: TimeInterval(eta)) ?? "—"
    }
}
```

---

## Database Issues

### Firestore

#### Error: "Index Not Ready" Query Failures
**Problem**: Queries fail with "The query requires an index" error.

**Solution**:
1. Check `firestore.indexes.json`:
```json
{
  "indexes": [
    {
      "collectionGroup": "rideRequests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "assignedDriverId", "order": "ASCENDING" },
        { "fieldPath": "state", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

2. Deploy indexes: `firebase deploy --only firestore:indexes`

#### Error: "Document Write Rate Exceeded"
**Problem**: High-frequency driver location updates hit write limits.

**Solution**:
```typescript
// Implement client-side throttling
class LocationThrottler {
  private lastUpdate = 0;
  private readonly minInterval = 5000; // 5 seconds
  
  shouldUpdate(location: GeoPoint): boolean {
    const now = Date.now();
    if (now - this.lastUpdate < this.minInterval) {
      return false;
    }
    this.lastUpdate = now;
    return true;
  }
}
```

### BigQuery

#### Error: "Quota Exceeded" During ML Training
**Problem**: BigQuery ML model training fails with quota exceeded.

**Solution**:
1. Request quota increase in Google Cloud Console
2. Reduce training data size:
```sql
-- Use sampling for large datasets
CREATE OR REPLACE MODEL `ride_sharing.demand_supply_forecast_model`
OPTIONS (model_type = 'BOOSTED_TREE_REGRESSOR')
AS
SELECT * FROM `ride_sharing.ml_training_features`
WHERE hour_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND MOD(ABS(FARM_FINGERPRINT(zone_id)), 10) < 8  -- Use 80% sample
```

---

## Monitoring & Alerts

### Cloud Monitoring

#### Error: Custom Metrics Not Appearing
**Problem**: Custom metrics from Cloud Functions don't show up in monitoring.

**Solution**:
```typescript
// Ensure proper metric descriptor creation
import { Monitoring } from '@google-cloud/monitoring';

const monitoring = new Monitoring.MetricServiceClient();

async function createCustomMetric(metricType: string) {
  const descriptor = {
    type: `custom.googleapis.com/${metricType}`,
    metricKind: 'GAUGE',
    valueType: 'DOUBLE',
    description: 'Custom metric description',
    displayName: 'Custom Metric Display Name'
  };
  
  await monitoring.createMetricDescriptor({
    name: `projects/${projectId}`,
    metricDescriptor: descriptor
  });
}
```

#### Error: Alert Policy Not Triggering
**Problem**: Alert policies don't send notifications despite conditions being met.

**Solution**:
1. Check notification channel configuration
2. Verify metric filters:
```hcl
# Ensure filter matches actual metric labels
condition_threshold {
  filter = "resource.type=\"cloud_function\" AND metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" AND metric.labels.status!=\"ok\""
  # Check that status label exists and has expected values
}
```

---

## Deployment Issues

### Firebase

#### Error: "Function Deployment Timeout"
**Problem**: Large Cloud Function deployments timeout.

**Solution**:
```bash
# Increase timeout and use parallel deployment
firebase deploy --only functions --force --timeout=1200s

# Or deploy functions individually
firebase deploy --only functions:singleHopMatcher
firebase deploy --only functions:pricingEngine
```

### Docker

#### Error: "Go Binary Not Found" in Cloud Run
**Problem**: Multi-stage Docker build doesn't copy binary correctly.

**Solution**:
```dockerfile
# Ensure binary is executable and in correct location
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o planner ./main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/planner ./
RUN chmod +x ./planner  # Ensure executable
CMD ["./planner"]
```

---

## Performance Issues

### High Latency

#### Problem: Slow Firestore Queries
**Solution**:
```typescript
// Use composite indexes and limit results
const query = db.collection('drivers')
  .where('isAvailable', '==', true)
  .where('gender', '==', requiredGender)
  .orderBy('lastSeenAt', 'desc')
  .limit(10);  // Always limit results

// Use batch reads for multiple documents
const driverRefs = matchedDriverIds.map(id => db.doc(`drivers/${id}`));
const driverDocs = await db.getAll(...driverRefs);
```

#### Problem: Cold Start Latency
**Solution**:
```hcl
# Set minimum instances for critical functions
resource "google_cloudfunctions2_function" "critical_function" {
  service_config {
    min_instance_count = 1  # Keep warm
    max_instance_count = 100
  }
}
```

---

## Security Issues

### Authentication

#### Error: "Invalid JWT Token"
**Problem**: Firebase Auth tokens expire or become invalid.

**Solution**:
```swift
// Implement automatic token refresh
class AuthManager: ObservableObject {
    func refreshTokenIfNeeded() async {
        guard let user = Auth.auth().currentUser else { return }
        
        do {
            // Force token refresh if close to expiry
            let token = try await user.getIDToken(forcingRefresh: true)
            // Update headers for API calls
        } catch {
            // Handle token refresh failure
            await signOut()
        }
    }
}
```

---

## Testing Issues

### Unit Tests

#### Error: "Firestore Emulator Not Starting"
**Problem**: Jest tests fail because Firestore emulator won't start.

**Solution**:
```bash
# Kill existing emulator processes
pkill -f firestore-emulator
lsof -ti:8080 | xargs kill -9

# Start with explicit configuration
firebase emulators:start --only firestore --port 8080

# In test setup
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
```

---

---

## Multi-Hop Journey Issues

### Multi-Hop Planning

#### Error: "No valid transfer points found"

**Problem**: Multi-hop planner cannot find suitable curb segments for passenger transfers between legs.

**Root Cause**: Limited curb segment data, all transfer points overcrowded, or route too complex for available infrastructure.

**Solution**:
```typescript
// Check curb segment coverage
const curbQuery = db.collection('curbSegments')
  .where('allowedUses', 'array-contains', 'passenger-pickup')
  .where('geometry', '!=', null);

// Verify pickup zones have capacity
const zonesQuery = db.collection('pickupZones')
  .where('activePickups', '<', db.collection('pickupZones').doc().get().capacityCars);

// Increase search radius in planner
const transferPoints = await getAvailableTransferPoints(ctx, origin, destination, {
  maxDetourFactor: 2.0, // Allow more detour
  maxTransferWalkTime: 300 // 5 minutes walk
});
```

#### Error: "Gender pool inconsistency on leg X"

**Problem**: Multi-leg journey cannot maintain consistent gender pools across different drivers.

**Root Cause**: Insufficient drivers of required gender available for all legs of the journey.

**Solution**:
```typescript
// Pre-validate gender consistency during planning
function validateGenderConsistency(riderGender: string, driverIDs: string[]): boolean {
  // Query all driver gender pools
  const driverQueries = driverIDs.map(id => 
    db.doc(`drivers/${id}`).get()
  );
  
  const drivers = await Promise.all(driverQueries);
  return drivers.every(driver => 
    driver.data()?.gender === riderGender ||
    driver.data()?.currentPassengerGenders?.includes(riderGender)
  );
}

// Fallback: suggest alternative time or relaxed constraints
if (!genderConsistent) {
  return {
    error: "GENDER_POOL_UNAVAILABLE",
    suggestion: "Try again in 10-15 minutes or consider mixed-gender pool",
    alternativeOptions: await findMixedGenderAlternatives(req)
  };
}
```

#### Error: "Multi-leg reservation failed: Resource validation failed for leg X"

**Problem**: One or more legs in multi-hop journey cannot reserve required resources (seats, cargo, pets, child seats).

**Root Cause**: Resource availability changed between planning and reservation, or calculation mismatch.

**Solution**:
```typescript
// Implement retry logic with resource recalculation
async function retryMultiLegReservation(requirements: MultiLegResourceRequirements, maxRetries = 3) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      // Re-validate all driver resources before each attempt
      for (const leg of requirements.legs) {
        const driver = await db.doc(`drivers/${leg.driverId}`).get();
        const validation = validateDriverResources(driver.data(), leg.requirements);
        if (!validation.valid) {
          throw new Error(`Leg ${leg.legNumber} validation failed: ${validation.error}`);
        }
      }
      
      return await reserveMultiLegResources(requirements);
    } catch (error) {
      if (attempt === maxRetries - 1) throw error;
      
      // Wait before retry with exponential backoff
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
    }
  }
}
```

### Multi-Hop UI Issues

#### Error: "Transfer point map rendering fails"

**Problem**: iOS app crashes or shows blank map when displaying multi-leg journey with transfer points.

**Root Cause**: Invalid coordinate data or too many annotations for MapBox to render.

**Solution**:
```swift
// Validate coordinates before rendering
func validateTransferPoints(_ points: [(Double, Double)]) -> [(Double, Double)] {
    return points.filter { point in
        let lat = point.0
        let lng = point.1
        return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
    }
}

// Limit annotation count for performance
func addTransferAnnotations(_ points: [(Double, Double)]) {
    let validPoints = validateTransferPoints(points)
    let limitedPoints = Array(validPoints.prefix(10)) // Max 10 transfer points
    
    for (index, point) in limitedPoints.enumerated() {
        let annotation = PointAnnotation(coordinate: CLLocationCoordinate2D(
            latitude: point.0, 
            longitude: point.1
        ))
        annotation.image = .init(image: transferIcon, name: "transfer-\(index)")
        pointAnnotationManager.annotations.append(annotation)
    }
}
```

#### Error: "Journey progress gets stuck at transfer point"

**Problem**: Multi-leg progress indicator doesn't update when rider reaches transfer point.

**Root Cause**: Missing leg completion events or state synchronization issues.

**Solution**:
```swift
// Add robust leg completion detection
class MultiLegJourneyTracker: ObservableObject {
    @Published var currentLeg: Int = 1
    @Published var legStatus: [Int: LegStatus] = [:]
    
    func updateLegProgress(legNumber: Int, status: LegStatus) {
        legStatus[legNumber] = status
        
        if status == .completed && legNumber == currentLeg {
            currentLeg = min(currentLeg + 1, totalLegs)
        }
        
        // Persist state for app backgrounding
        UserDefaults.standard.set(currentLeg, forKey: "currentLeg")
        UserDefaults.standard.set(try? JSONEncoder().encode(legStatus), 
                                forKey: "legStatus")
    }
}
```

---

*Last updated: {{date}}*

*Add new solutions as you encounter and solve hard problems.* 