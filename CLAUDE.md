# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Liive iOS ride-sharing platform with two main features:
1. **Image Lesson**: LiveKit-based educational feature for image-based lessons
2. **Ride Sharing**: Full-featured ride-sharing service with gender-safe pools, multi-hop planning, and legal curb management

## Architecture

The project follows a modular Swift Package architecture:
- **iOS App**: SwiftUI + Combine, minimum iOS 16
- **Backend**: Firebase (Firestore, Auth, Functions) + GCP services
- **Real-time**: LiveKit for audio/video communication
- **Payments**: Stripe Connect with identity verification
- **Location**: Radar SDK for geofencing, Mapbox for navigation

Key architectural components:
- **Multi-Hop Planner** (Cloud Run - Go): Handles 2-3 leg journeys with transfer points
- **Single-Hop Matcher** (Cloud Function): Real-time matching with resource reservation
- **Resource Management**: Atomic seat/cargo/pet/child-seat reservations via Firestore transactions
- **Congestion Control**: Legal curb capacity management to prevent traffic violations

## Development Commands

### iOS Development
```bash
# Open project in Xcode
open image-lesson-prototype.xcodeproj

# Build and run: Cmd+R in Xcode
# Run tests: Cmd+U in Xcode
```

### Backend Functions
```bash
cd backend/functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Run tests
npm test

# Lint code
npm run lint

# Deploy functions
npm run deploy
```

### Infrastructure
```bash
cd infra

# Initialize Terraform backend
./bootstrap/setup-terraform-backend.sh

# Apply infrastructure changes
terraform apply -var-file=environments/dev.tfvars
```

## Key Configuration

### iOS App
- **API_BASE_URL**: Set in `image-lesson-prototype/Info.plist`
- **LiveKit credentials**: Fetched from backend via authenticated endpoints

### Backend Environment Variables
- Managed via Google Secret Manager
- Bootstrap scripts in `infra/bootstrap/`

## Testing Strategy

### iOS
- Unit tests for ViewModels in each package
- UI tests via SwiftUI Previews (see `ImageLessonView+Previews.swift`)

### Backend
- Jest for Cloud Functions: `npm test`
- Firestore rules testing via emulator
- Load testing: `backend/load-test/` (Locust)
- Performance testing: `backend/performance-tests/` (JMeter)

## Critical Business Logic

### Gender-Safe Pools
- Enforced at matching time via `reserveResourcesTx`
- Driver's current passenger genders tracked in `currentPassengerGenders[]`

### Multi-Hop Planning
- Time-expanded graph algorithm in `backend/planner/`
- Maximum 3 legs with legal transfer points
- Respects all constraints: seats, cargo, pets, child seats

### Curb Management
- Legal pickup zones from Mapbox data
- `activePickups < capacityCars` enforced atomically
- Stuck vehicle detection prevents lane blockage

## Common Development Tasks

### Adding a New Cloud Function
1. Add TypeScript source in `backend/functions/src/`
2. Export from `index.ts`
3. Add tests in `backend/functions/test/`
4. Deploy with `npm run deploy`

### Modifying iOS Features
1. Make changes in appropriate Package (`Packages/*/`)
2. Test via SwiftUI Previews
3. Run package tests
4. Verify in main app

### Database Schema Changes
1. Update Firestore rules in `firestore.rules`
2. Add indexes in `firestore.indexes.json`
3. Update TypeScript interfaces in backend
4. Update Swift models in iOS packages