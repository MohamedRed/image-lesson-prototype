# Local Testing Guide for Ride-Sharing Feature

This guide explains how to run and test the ride-sharing feature locally using Firebase emulators.

## Prerequisites

1. **Firebase CLI**: Install globally if not already installed
   ```bash
   npm install -g firebase-tools
   ```

2. **Xcode**: Ensure you have Xcode installed for iOS development

3. **Node.js**: Required for running Firebase functions locally

## Quick Start

Run the complete local environment with one command:

```bash
./scripts/start-local.sh
```

This script will:
- Install dependencies
- Build TypeScript functions
- Start Firebase emulators (Firestore, Auth, Functions)
- Seed test data (drivers, riders, pickup zones)
- Display connection information

## Manual Setup (Alternative)

If you prefer to run components separately:

### 1. Start Firebase Emulators
```bash
firebase emulators:start
```

### 2. Seed Test Data
In a new terminal:
```bash
cd backend/functions
node scripts/seed-local-data.js
```

### 3. Run iOS App
1. Open `image-lesson-prototype.xcodeproj` in Xcode
2. Select a simulator (iPhone 14 Pro recommended)
3. Press `Cmd+R` to build and run

## Configuration

### iOS App
The app automatically detects DEBUG mode and connects to local emulators:
- Firestore: `localhost:8080`
- Auth: `localhost:9099`
- Functions: `localhost:5001`

### Test Accounts

**Riders:**
- Email: `rider1@example.com` Password: `testpass123` (Alice - Female)
- Email: `rider2@example.com` Password: `testpass123` (Bob - Male)

**Drivers (pre-seeded):**
- John Driver - Available, 4 seats, Toyota Camry
- Sarah Driver - Available, 4 seats, Honda Accord
- Mike Driver - Busy, 6 seats, Ford Explorer

## Testing Flow

1. **Start the app** and navigate to Ride Sharing feature
2. **Request a ride** - The app will:
   - Create a ride request in Firestore
   - Show nearby drivers on the map
   - Display driver location updates in real-time

3. **Monitor in Emulator UI** (http://localhost:4000):
   - View Firestore documents
   - Check Auth users
   - See function logs

## Features to Test

- [x] Driver location tracking
- [x] Ride request creation
- [x] Real-time driver updates
- [x] Multi-leg journey support
- [x] Gender-safe pool matching
- [x] Pickup zone management

## Troubleshooting

### Emulators won't start
- Check port conflicts: `lsof -i :8080` (Firestore), `lsof -i :5001` (Functions)
- Kill existing processes: `pkill -f "firebase emulators"`

### App can't connect to emulators
- Ensure you're running in DEBUG mode
- Check that emulators are running: http://localhost:4000
- Verify Info.plist has correct localhost URLs

### No data showing
- Run the seed script: `node backend/functions/scripts/seed-local-data.js`
- Check Firestore emulator UI for data: http://localhost:4000/firestore

## Development Tips

1. **Hot Reload**: Functions automatically reload when you modify and rebuild
2. **Data Persistence**: Use `--import` and `--export-on-exit` flags to save emulator data
3. **Debugging**: Use Xcode console for iOS logs, terminal for function logs

## Next Steps

Once local testing is working:
1. Deploy functions to Firebase: `firebase deploy --only functions`
2. Configure production secrets in Google Secret Manager
3. Update Info.plist with production URLs
4. Test with real Firebase project