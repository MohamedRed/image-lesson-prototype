# Liive Ride Canonical Matching Algorithm

This is the canonical product/engineering spec for Liive Ride matching. If older docs or code disagree with this file, treat this file as the intended algorithm and update the code/docs.

## Source-of-truth order

1. Current user/product clarifications.
2. This canonical algorithm spec.
3. Existing ride-sharing docs.
4. Current code, which may lag behind the intended algorithm.

## Goal

Match an in-city rider with drivers already going in a compatible direction, while keeping driver detour minimal, rider walking/waiting low, pickup/dropoff legal, and vehicle resources safe/available.

The matcher must **not** be a simple nearest-driver algorithm.

## Core geometry model

### Rider geometry

For every ride request, compute and persist:

- `originWalkIso`: area the rider is willing/able to walk from current origin.
- `destinationWalkIso`: area the rider is willing/able to walk near destination.
- `originDriveGeo`: larger live geofence around origin, sized so a car entering it gives the rider enough time to walk to a legal pickup point.
- Optional `destinationDriveGeo`: larger destination-side driving/geofence area for dropoff planning.

The walking radius is user-configurable. Initial default can be small, e.g. 50m, then adjusted by market/testing.

### Driver geometry

For every available driver, compute and persist:

- `routePolyline`: driver's intended route from current position/origin to destination.
- `routeBuffer`: corridor around that route, with configurable width/detour tolerance.
- `routeEtaProfile`: estimated time along the route, ideally from Mapbox/OSRM/Radar routing.
- `resourceLedger`: seats/cargo/pets/child seats available per route segment/time window.

The system should adapt to the driver route. It should avoid forcing the driver to materially change destination or route.

## Single-hop candidate generation

A driver is a candidate only if all are true:

1. Driver is online, available, not blocked/stuck/spoof-flagged, and eligible for the ride type.
2. Driver route corridor intersects or passes sufficiently near `originWalkIso`.
3. Driver route corridor intersects or passes sufficiently near `destinationWalkIso`.
4. Driver's current/future position enters or is projected to enter `originDriveGeo` at a time that lets the rider reach the pickup point.
5. There is at least one legal pickup curb inside/near `originWalkIso` and along the driver-compatible route.
6. There is at least one legal dropoff curb inside/near `destinationWalkIso` and along the driver-compatible route.
7. Added driver detour is within threshold.
8. Rider wait time and walk time are within threshold.

## Hard filters

Apply before scoring:

- gender pool compatibility: no mixed-gender pools unless product policy changes
- available seats over the relevant route segment, not just `activePickups`
- luggage/cargo capacity
- pet constraints and allergy flags
- child-seat requirements
- premium/exclusive requirements
- legal curb pickup/dropoff availability
- pickup/dropoff zone capacity: `activePickups < capacityCars`
- driver identity/compliance status
- payment/identity requirements when needed

## Scoring

Rank valid candidates by weighted score:

```text
score = w1 * driverDetour
      + w2 * pickupETA
      + w3 * riderWalkTime
      + w4 * riderWaitTime
      + w5 * seatLoad
      + w6 * cargoLoad
      + w7 * curbLoad
      + w8 * transferPenalty
      + w9 * premiumPenalty
```

Lower is better. Reject candidates above configured thresholds.

Important: `driverDetour` must compare the original driver route against the route with pickup/dropoff inserted. It should not be straight-line distance only.

## Live/reactive matching

The system should support live matching when a vehicle enters the rider's `originDriveGeo`. This geofence is different from the walking isochrone: it exists to detect that a car is close enough to be useful while still giving the rider time to walk to pickup.

The system may also proactively plan matches from route predictions and historical patterns, but live geofence triggers are part of the intended UX.

## Multi-hop planning

If no acceptable single-hop exists, plan 2-hop or 3-hop journeys.

Rules:

1. Prefer single-hop.
2. Try 2-hop before 3-hop.
3. Avoid more than 3 hops except emergency/explicit fallback.
4. Transfer points must be legal, safe, and low-congestion.
5. Transfer walking should be very small.
6. Transfer wait should target near-zero; max target is about 10-15 seconds for a premium seamless feel.
7. Each leg must satisfy the same corridor, timing, gender, resource, curb, and detour constraints.
8. Use live data plus historical patterns to decide when proactive multi-hop is more likely than waiting for a direct driver.

Model multi-hop as a time-expanded graph:

- nodes: legal pickup/dropoff/transfer zones with time windows
- edges: driver route segments that can carry the rider between zones
- edge cost: ETA + detour + wait + walk + congestion + resource load
- path constraint: max 3 legs by default

## Reservation flow

Planning must be paired with resource reservation:

1. Generate ranked candidates.
2. Attempt atomic reservation for driver resources and curb capacity.
3. If reservation fails, retry the next candidate.
4. Return a proposal only after reservation succeeds.
5. For multi-hop, reserve all required legs or use a hold/saga flow with rollback/expiry.

Never return a driver as matched if required seats/cargo/curb/gender constraints were not reserved.

## Frontend responsibilities

The app should:

- capture origin, destination, walk radius, passengers, luggage, pets, child seats, gender/safety pool preference, premium preferences
- send these fields to backend in the ride request
- display backend-selected pickup/dropoff/transfer points, ETA, walking guidance, and driver/vehicle details
- track rider/driver location and geofence state
- show when a match is live/geofence-based vs planned

The app should not be the main source of matching truth. Candidate generation, scoring, and reservation belong on the backend.

## Current implementation gap summary

Current code has useful scaffolding but does not fully implement this algorithm yet:

- driver `routePolyline` and `bufferPolygon` are partially generated
- rider `oriWalkIso`, `destWalkIso`, and `oriDriveIso` are partially generated
- Go planner currently does not use these geometries for corridor/intersection matching
- current planner mostly scores filtered drivers by straight-line distance/ETA heuristics
- capacity accounting must move from `activePickups` to actual resource ledgers
- reservation must retry next candidates when the first reservation fails
