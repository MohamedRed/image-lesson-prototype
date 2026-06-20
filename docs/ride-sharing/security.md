# Firestore Security Rules Overview

These rules lock down the database so that only safe client writes are allowed; all sensitive mutations happen via Cloud Functions or Planner.

## Client-Allowed Writes

| Collection            | Who  | Allowed Fields                     | Notes |
|-----------------------|------|------------------------------------|-------|
| `rideRequests`        | rider| create doc with origin, destination, passengerCount ≤6, riderGender (f/m/nb), luggageManifest (backpack/suitcase/bulky ≤2) | State must start as `searching` |
|                       | rider| update `state` (searching→cancelled/accepted, priced→accepted) | fareBreakdown immutable |
| `drivers/{driverId}`  | driver| `currentLocation`, `isMoving`, `isOnCurb`, `inventoryHash`, `lastSeenAt` | Only on own doc |

All other writes (payouts, legs, ledgers, pricing, fares, plans) are **server-only**.

## Critical Validations

* `riderGender` limited to `female | male | nb`  
* `passengerCount` 1-6  
* `fareBreakdown` immutable to client  
* State-machine enforced  
* Luggage / pet manifests keys whitelisted, values 0-2  
* Driver cannot change seat/cargo ledgers or `capacitySeats`  

## Testing

Unit tests in `backend/functions/test/firestoreRules.test.ts` run via `npm test` (Rules emulator). CI workflow executes these tests on every push. 