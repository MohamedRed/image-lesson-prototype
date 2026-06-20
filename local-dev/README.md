# Local Development Setup Guide

## Prerequisites

1. **Docker Desktop** - Running and available
2. **Google Cloud Project** - For BigQuery test dataset
3. **Service Account Key** - For BigQuery access

## Quick Setup

### 1. Google Cloud Setup

```bash
# Create a test project (or use existing)
gcloud projects create liive-ios-test --name="Liive iOS Test"

# Enable BigQuery API
gcloud services enable bigquery.googleapis.com --project=liive-ios-test

# Create service account
gcloud iam service-accounts create liive-local-dev \
  --display-name="Liive Local Development" \
  --project=liive-ios-test

# Grant BigQuery permissions
gcloud projects add-iam-policy-binding liive-ios-test \
  --member="serviceAccount:liive-local-dev@liive-ios-test.iam.gserviceaccount.com" \
  --role="roles/bigquery.admin"

# Download service account key
gcloud iam service-accounts keys create ./local-dev/service-account-key.json \
  --iam-account=liive-local-dev@liive-ios-test.iam.gserviceaccount.com \
  --project=liive-ios-test
```

### 2. BigQuery Test Dataset

```bash
# Create test dataset
bq mk --project_id=liive-ios-test --dataset liive_test

# Apply schema from backend/bigquery.sql
bq query --project_id=liive-ios-test --use_legacy_sql=false < backend/bigquery.sql
```

### 3. Start Full Stack

```bash
# Make sure you have all test keys in backend/functions/.env.local
./scripts/start-full-local-stack.sh
```

## Service URLs

- **Firebase Emulators UI**: http://localhost:4000
- **Go Planner API**: http://localhost:8081
- **Grafana Dashboard**: http://localhost:3000 (admin/admin)
- **Prometheus Metrics**: http://localhost:9090

## External Services (Test Mode)

All external services use **real test environments**:

- ✅ **Stripe**: Test mode with `sk_test_*` keys
- ✅ **Radar**: Test mode with `prj_test_*` keys  
- ✅ **LiveKit**: Real cloud instance (test room)
- ✅ **BigQuery**: Real BigQuery with test dataset
- ✅ **Mapbox**: Test token

## BigQuery Operations

```bash
# Query test data
docker-compose exec bigquery-cli bq query --use_legacy_sql=false \
  "SELECT * FROM liive_test.rides LIMIT 10"

# Run analytics queries
docker-compose exec bigquery-cli bq query --use_legacy_sql=false \
  "$(cat backend/bigquery_procedures.sql)"
```

## Useful Commands

```bash
# View service logs
docker-compose logs -f [service_name]

# Restart specific service
docker-compose restart planner

# Stop all services
docker-compose down

# Rebuild and restart
docker-compose up --build
```

## iOS App Configuration

Use the new service mode in your iOS app:

```swift
// Full local development with real external services
RideMapContainerView(mode: .localDev(.default))

// Minimal local (emulators only)
RideMapContainerView(mode: .localDev(.minimal))
```

## Cost Management

- **BigQuery**: Use free tier (1TB queries/month)
- **Stripe**: Test mode (no charges)
- **Radar**: Test API (generous free tier)
- **LiveKit**: Monitor usage in dashboard

## Troubleshooting

### BigQuery Access Issues
```bash
# Verify service account
docker-compose exec bigquery-cli gcloud auth list

# Test BigQuery access
docker-compose exec bigquery-cli bq ls --project_id=liive-ios-test
```

### Firestore Connection Issues
```bash
# Check emulator status
curl http://localhost:8080

# Reset emulator data
docker-compose down
rm -rf emulator-data
docker-compose up
```