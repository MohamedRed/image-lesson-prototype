# Ride Sharing Platform - API Documentation

> Complete API reference for HTTP endpoints, Pub/Sub messages, and data schemas.

---

## 🌐 HTTP API Endpoints

### Base URL
- **Development**: `https://us-central1-ride-sharing-dev.cloudfunctions.net`
- **Production**: `https://us-central1-ride-sharing-prod.cloudfunctions.net`

### Authentication
All API endpoints require Firebase Authentication tokens in the `Authorization` header:
```
Authorization: Bearer <firebase-id-token>
```

---

## 🚗 Ride Management

### Create Ride Request
**POST** `/createRideRequest`

Creates a new ride request and starts the matching process.

#### Request Body
```json
{
  "origin": {
    "latitude": 37.7749,
    "longitude": -122.4194
  },
  "destination": {
    "latitude": 37.7849,
    "longitude": -122.4094
  },
  "passengerCount": 2,
  "riderGender": "female",
  "walkRadiusM": 200,
  "luggageManifest": {
    "suitcase": 1,
    "backpack": 2
  },
  "pet": {
    "small": 1
  },
  "childPassengers": [
    {
      "ageYears": 5,
      "weightKg": 18
    }
  ],
  "premiumRequested": {
    "vehicleBrand": "luxury",
    "hasAC": true
  }
}
```

#### Response

**Single-Leg Journey:**
```json
{
  "success": true,
  "rideRequestId": "ride_12345",
  "state": "searching",
  "estimatedMatchTime": 30,
  "message": "Searching for drivers...",
  "journey": {
    "legs": [
      {
        "driverId": "driver_abc123",
        "pickup": {"latitude": 37.7749, "longitude": -122.4194},
        "dropoff": {"latitude": 37.7849, "longitude": -122.4094},
        "estimatedTimeSeconds": 900
      }
    ],
    "totalEstimatedTimeSeconds": 900
  }
}
```

**Multi-Leg Journey:**
```json
{
  "success": true,
  "rideRequestId": "ride_12345",
  "state": "searching",
  "estimatedMatchTime": 45,
  "message": "Planning multi-hop journey...",
  "journey": {
    "legs": [
      {
        "driverId": "driver_abc123",
        "pickup": {"latitude": 37.7749, "longitude": -122.4194},
        "dropoff": {"latitude": 37.7799, "longitude": -122.4144},
        "estimatedTimeSeconds": 600
      },
      {
        "driverId": "driver_def456", 
        "pickup": {"latitude": 37.7799, "longitude": -122.4144},
        "dropoff": {"latitude": 37.7849, "longitude": -122.4094},
        "estimatedTimeSeconds": 480
      }
    ],
    "totalEstimatedTimeSeconds": 1260,
    "transferPoints": [
      {
        "location": {"latitude": 37.7799, "longitude": -122.4144},
        "transferTimeSeconds": 180,
        "curbSegmentId": "curb_xyz789"
      }
    ],
    "isMultiLeg": true,
    "legsCount": 2
  }
}
```

---

### Multi-Hop Journey Planning (Internal Service)

The multi-hop journey planning is handled by a separate Cloud Run service written in Go. This endpoint is called internally by the `singleHopMatcher` function when direct routes are not available.

**Service URL**: Set via `PLANNER_URL` environment variable  
**Authentication**: Google Cloud IAM (Cloud Run Invoker role required)

#### Planner Service API

**POST** `{PLANNER_URL}/plan`

Plans an optimal journey for a ride request, attempting single-hop first and falling back to multi-hop (2-3 legs) if necessary.

#### Request Body
```json
{
  "origin": {
    "latitude": 37.7749,
    "longitude": -122.4194
  },
  "destination": {
    "latitude": 37.7849,
    "longitude": -122.4094
  },
  "passengerCount": 2,
  "riderGender": "female",
  "luggageManifest": {
    "suitcase": 1,
    "backpack": 1
  },
  "pet": {
    "small": 1
  },
  "childPassengers": [
    {
      "ageYears": 3,
      "weightKg": 15
    }
  ],
  "premiumRequested": {
    "hasAC": true,
    "luxurySeats": true
  },
  "walkRadiusM": 500
}
```

#### Response
```json
{
  "success": true,
  "journey": {
    "legs": [
      {
        "legNumber": 1,
        "driverId": "driver_abc123",
        "pickup": {"latitude": 37.7749, "longitude": -122.4194},
        "dropoff": {"latitude": 37.7799, "longitude": -122.4144},
        "estimatedTimeSeconds": 600,
        "reservedResources": {
          "seats": 2,
          "cargo": {"suitcase": 1},
          "childSeats": {"booster": 1}
        }
      },
      {
        "legNumber": 2,
        "driverId": "driver_def456",
        "pickup": {"latitude": 37.7799, "longitude": -122.4144},
        "dropoff": {"latitude": 37.7849, "longitude": -122.4094},
        "estimatedTimeSeconds": 480,
        "reservedResources": {
          "seats": 2,
          "cargo": {"suitcase": 1},
          "childSeats": {"booster": 1}
        }
      }
    ],
    "totalEstimatedTimeSeconds": 1260,
    "transferPoints": [
      {
        "id": "curb_xyz789",
        "location": {"latitude": 37.7799, "longitude": -122.4144},
        "transferTimeSeconds": 180,
        "congestionFactor": 1.2,
        "availableCapacity": 3
      }
    ],
    "genderPoolConsistent": true,
    "resourcesReserved": true
  }
}
```

#### Planner Algorithm Details

**Single-Hop Matching:**
- Hard filters: capacity, gender pool, luggage, pets, child seats, premium features
- Scoring: `score = w1·detourKm + w2·(etaSeconds/60) + curbLoadFactor^w3`
- Weights configurable via env vars: `WEIGHT_DETOUR=0.7`, `WEIGHT_ETA=0.3`, `WEIGHT_CURB=1.0`

**Multi-Hop Planning (2-3 legs):**
- Transfer points: Legal curb segments with passenger pickup allowed
- Detour limit: 1.5x direct distance
- Transfer time: 3 minutes default
- Journey score: `totalTime + (numLegs-1)×300 + (avgCongestion-1)×600`

**Performance:**
- Query timeout: 5 seconds
- Max drivers queried: 50
- Max transfer points: 20
- Response SLA: <1s single-hop, <2s multi-hop

#### Error Responses
```json
{
  "success": false,
  "error": "INVALID_LOCATION",
  "message": "Origin and destination must be valid coordinates"
}
```

### Cancel Ride Request
**POST** `/cancelRideRequest`

Cancels an active ride request.

#### Request Body
```json
{
  "rideRequestId": "ride_12345",
  "reason": "user_cancelled"
}
```

#### Response
```json
{
  "success": true,
  "message": "Ride request cancelled successfully"
}
```

### Accept Ride
**POST** `/acceptRide`

Accepts a proposed ride match.

#### Request Body
```json
{
  "rideRequestId": "ride_12345"
}
```

#### Response
```json
{
  "success": true,
  "livekitToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "roomName": "ride_12345",
  "driverInfo": {
    "name": "John Driver",
    "rating": 4.8,
    "vehicle": {
      "make": "Toyota",
      "model": "Camry",
      "licensePlate": "ABC123",
      "color": "Blue"
    }
  }
}
```

---

## 🎯 Driver Endpoints

### Update Driver Status
**POST** `/updateDriverStatus`

Updates driver availability and location.

#### Request Body
```json
{
  "isAvailable": true,
  "currentLocation": {
    "latitude": 37.7749,
    "longitude": -122.4194
  },
  "bearing": 45.5,
  "speed": 25.3,
  "accuracy": 5.0,
  "inventoryHash": "abc123def456"
}
```

#### Response
```json
{
  "success": true,
  "message": "Driver status updated"
}
```

### Complete Ride Leg
**POST** `/completeRideLeg`

Marks a ride leg as completed.

#### Request Body
```json
{
  "rideRequestId": "ride_12345",
  "legIndex": 0
}
```

---

## 💳 Payment Endpoints

### Create Payment Intent
**POST** `/createPaymentIntent`

Creates a Stripe PaymentIntent for a ride.

#### Request Body
```json
{
  "rideRequestId": "ride_12345"
}
```

#### Response
```json
{
  "success": true,
  "clientSecret": "pi_1234_secret_5678",
  "amount": 1250,
  "currency": "usd"
}
```

### Stripe Webhook
**POST** `/stripeWebhook`

Handles Stripe webhook events (internal use only).

---

## 🔧 Admin Endpoints

### Generate LiveKit Token
**POST** `/livekitToken`

Generates a LiveKit access token for a ride room.

#### Request Body
```json
{
  "rideRequestId": "ride_12345",
  "participantType": "rider"
}
```

#### Response
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "roomName": "ride_12345"
}
```

---

## 📊 Analytics Endpoints

### Get Ride Metrics
**GET** `/getRideMetrics`

Retrieves ride metrics for dashboards.

#### Query Parameters
- `timeRange`: `1h`, `24h`, `7d`, `30d`
- `zoneId`: Optional zone filter

#### Response
```json
{
  "success": true,
  "metrics": {
    "totalRides": 1250,
    "completedRides": 1100,
    "completionRate": 0.88,
    "averageWaitTime": 180,
    "averageFare": 12.50
  }
}
```

---

## 📨 Pub/Sub Message Schemas

### Ride Events Topic
**Topic**: `ride-events-{environment}`

#### Ride Created Event
```json
{
  "eventType": "RIDE_CREATED",
  "timestamp": "2024-01-15T10:30:00Z",
  "rideId": "ride_12345",
  "riderId": "user_67890",
  "pickupLocation": {
    "lat": 37.7749,
    "lng": -122.4194
  },
  "dropoffLocation": {
    "lat": 37.7849,
    "lng": -122.4094
  },
  "passengerCount": 2,
  "riderGender": "female",
  "estimatedFare": 12.50
}
```

#### Ride Matched Event
```json
{
  "eventType": "RIDE_MATCHED",
  "timestamp": "2024-01-15T10:31:30Z",
  "rideId": "ride_12345",
  "riderId": "user_67890",
  "driverId": "driver_11111",
  "estimatedPickupTime": 300,
  "fareBreakdown": {
    "baseFare": 10.00,
    "surcharges": 2.50,
    "total": 12.50
  }
}
```

#### Ride Completed Event
```json
{
  "eventType": "RIDE_COMPLETED",
  "timestamp": "2024-01-15T11:15:00Z",
  "rideId": "ride_12345",
  "riderId": "user_67890",
  "driverId": "driver_11111",
  "actualFare": 12.50,
  "duration": 1800,
  "distance": 5.2,
  "rating": {
    "riderRating": 5,
    "driverRating": 4
  }
}
```

### Driver Events Topic
**Topic**: `driver-events-{environment}`

#### Driver Status Change
```json
{
  "eventType": "DRIVER_STATUS_CHANGED",
  "timestamp": "2024-01-15T10:30:00Z",
  "driverId": "driver_11111",
  "previousStatus": "offline",
  "newStatus": "available",
  "location": {
    "lat": 37.7749,
    "lng": -122.4194
  },
  "pickupZoneId": "zone_downtown"
}
```

#### Driver Location Update
```json
{
  "eventType": "DRIVER_LOCATION_UPDATED",
  "timestamp": "2024-01-15T10:30:15Z",
  "driverId": "driver_11111",
  "location": {
    "lat": 37.7749,
    "lng": -122.4194
  },
  "bearing": 45.5,
  "speed": 25.3,
  "accuracy": 5.0
}
```

### Pricing Events Topic
**Topic**: `pricing-events-{environment}`

#### Surge Pricing Update
```json
{
  "eventType": "SURGE_PRICING_UPDATED",
  "timestamp": "2024-01-15T10:30:00Z",
  "zoneId": "zone_downtown",
  "previousMultiplier": 1.0,
  "newMultiplier": 1.5,
  "demandScore": 85,
  "supplyScore": 45,
  "reason": "high_demand"
}
```

### Alert Events Topic
**Topic**: `alert-events-{environment}`

#### Security Alert
```json
{
  "eventType": "SECURITY_ALERT",
  "timestamp": "2024-01-15T10:30:00Z",
  "alertType": "LOCATION_SPOOFING",
  "severity": "HIGH",
  "driverId": "driver_11111",
  "details": {
    "spoofingScore": 85.5,
    "suspiciousMetrics": {
      "rapidJumps": 50.0,
      "impossibleSpeed": 35.5
    }
  }
}
```

#### System Alert
```json
{
  "eventType": "SYSTEM_ALERT",
  "timestamp": "2024-01-15T10:30:00Z",
  "alertType": "HIGH_ERROR_RATE",
  "severity": "CRITICAL",
  "service": "singleHopMatcher",
  "metrics": {
    "errorRate": 0.15,
    "threshold": 0.05
  }
}
```

---

## 📋 Data Models

### Ride Request Document
**Collection**: `rideRequests/{rideId}`

```json
{
  "id": "ride_12345",
  "state": "completed",
  "riderId": "user_67890",
  "assignedDriverId": "driver_11111",
  "pickupZoneId": "zone_downtown",
  "origin": {
    "_latitude": 37.7749,
    "_longitude": -122.4194
  },
  "destination": {
    "_latitude": 37.7849,
    "_longitude": -122.4094
  },
  "passengerCount": 2,
  "riderGender": "female",
  "walkRadiusM": 200,
  "luggageManifest": {
    "suitcase": 1,
    "backpack": 2
  },
  "pet": {
    "small": 1
  },
  "childPassengers": [
    {
      "ageYears": 5,
      "weightKg": 18
    }
  ],
  "premiumRequested": {
    "vehicleBrand": "luxury",
    "hasAC": true
  },
  "fareBreakdown": {
    "baseFare": 10.00,
    "surcharges": 2.50,
    "premiumMultiplier": 1.0,
    "total": 12.50,
    "currency": "USD",
    "distanceKm": 5.2
  },
  "reservedResources": {
    "seats": 2,
    "cargo": {
      "suitcase": 1,
      "backpack": 2
    },
    "pets": {
      "small": 1
    },
    "childSeats": {
      "booster": 1
    }
  },
  "journey": {
    "legs": [
      {
        "driverId": "driver_11111",
        "pickup": {
          "_latitude": 37.7749,
          "_longitude": -122.4194
        },
        "dropoff": {
          "_latitude": 37.7849,
          "_longitude": -122.4094
        },
        "estimatedTimeSeconds": 1800
      }
    ],
    "totalEstimatedTimeSeconds": 1800
  },
  "paymentIntentId": "pi_1234567890",
  "paymentClientSecret": "pi_1234_secret_5678",
  "createdAt": "2024-01-15T10:30:00Z",
  "proposedAt": "2024-01-15T10:31:30Z",
  "pricedAt": "2024-01-15T10:31:45Z",
  "acceptedAt": "2024-01-15T10:32:00Z",
  "completedAt": "2024-01-15T11:15:00Z"
}
```

### Driver Document
**Collection**: `drivers/{driverId}`

```json
{
  "id": "driver_11111",
  "name": "John Driver",
  "email": "john@example.com",
  "phone": "+1-555-0123",
  "gender": "male",
  "isAvailable": true,
  "isActive": true,
  "currentLocation": {
    "_latitude": 37.7749,
    "_longitude": -122.4194
  },
  "bearing": 45.5,
  "currentSpeed": 25.3,
  "locationAccuracy": 5.0,
  "locationSource": "gps",
  "pickupZoneId": "zone_downtown",
  "capacitySeats": 4,
  "activePickups": 1,
  "luggageCapacity": {
    "suitcase": 2,
    "backpack": 4,
    "bulky": 1
  },
  "petLimits": {
    "small": 2,
    "large": 1
  },
  "childSeatInventory": {
    "infant": 1,
    "forward": 1,
    "booster": 2
  },
  "premiumCapabilities": {
    "vehicleBrand": "luxury",
    "hasAC": true,
    "hasWifi": false
  },
  "vehicle": {
    "make": "Toyota",
    "model": "Camry",
    "year": 2022,
    "licensePlate": "ABC123",
    "color": "Blue"
  },
  "legs": [
    {
      "reservedAt": "2024-01-15T10:31:30Z",
      "seats": 2,
      "riderGender": "female"
    }
  ],
  "cargoLedger": [
    {
      "reservedAt": "2024-01-15T10:31:30Z",
      "items": {
        "suitcase": 1,
        "backpack": 2
      }
    }
  ],
  "petLedger": [
    {
      "reservedAt": "2024-01-15T10:31:30Z",
      "pets": {
        "small": 1
      }
    }
  ],
  "childSeatLedger": [
    {
      "reservedAt": "2024-01-15T10:31:30Z",
      "seats": {
        "booster": 1
      }
    }
  ],
  "currentPassengerGenders": ["female"],
  "rating": 4.8,
  "totalRides": 1250,
  "inventoryHash": "abc123def456",
  "stripeAccountId": "acct_1234567890",
  "lastSeenAt": "2024-01-15T10:35:00Z",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### Pickup Zone Document
**Collection**: `pickupZones/{zoneId}`

```json
{
  "id": "zone_downtown",
  "name": "Downtown Financial District",
  "location": {
    "_latitude": 37.7749,
    "_longitude": -122.4194
  },
  "capacityCars": 15,
  "activePickups": 8,
  "city": "San Francisco",
  "zoneType": "downtown",
  "curbLoadFactor": 1.2,
  "driveIsoShrinkMeters": 50,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

---

## 🔐 Error Codes

### HTTP Status Codes
- `200` - Success
- `400` - Bad Request (invalid parameters)
- `401` - Unauthorized (invalid/missing auth token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found (resource doesn't exist)
- `429` - Too Many Requests (rate limited)
- `500` - Internal Server Error

### Custom Error Codes
```json
{
  "INVALID_LOCATION": "Origin or destination coordinates are invalid",
  "NO_DRIVERS_AVAILABLE": "No drivers available in the requested area",
  "RIDE_NOT_FOUND": "Ride request not found",
  "RIDE_ALREADY_ACCEPTED": "Ride has already been accepted",
  "RIDE_CANCELLED": "Ride has been cancelled",
  "PAYMENT_FAILED": "Payment processing failed",
  "INVENTORY_MISMATCH": "Driver inventory doesn't match requirements",
  "GENDER_POOL_VIOLATION": "Driver doesn't match gender pool requirements",
  "CAPACITY_EXCEEDED": "Requested passenger count exceeds driver capacity",
  "LOCATION_SPOOFING_DETECTED": "Suspicious location activity detected",
  "RATE_LIMIT_EXCEEDED": "Too many requests, please try again later"
}
```

---

## 📝 Rate Limits

### Per User Limits
- **Ride Creation**: 10 requests per minute
- **Status Updates**: 60 requests per minute
- **Driver Location**: 12 requests per minute (every 5 seconds)

### Per IP Limits
- **General API**: 1000 requests per hour
- **Webhook Endpoints**: No limit (authenticated)

### Rate Limit Headers
```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1642262400
```

---

## 🧪 Testing

### Test Environment
- **Base URL**: `https://us-central1-ride-sharing-dev.cloudfunctions.net`
- **Test User Tokens**: Available in development Firebase project
- **Sample Data**: Pre-populated with test drivers and zones

### Postman Collection
Import the API collection: `https://api.postman.com/collections/ride-sharing-api`

### cURL Examples

#### Create Ride Request
```bash
curl -X POST https://us-central1-ride-sharing-dev.cloudfunctions.net/createRideRequest \
  -H "Authorization: Bearer $FIREBASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"latitude": 37.7749, "longitude": -122.4194},
    "destination": {"latitude": 37.7849, "longitude": -122.4094},
    "passengerCount": 1
  }'
```

#### Update Driver Status
```bash
curl -X POST https://us-central1-ride-sharing-dev.cloudfunctions.net/updateDriverStatus \
  -H "Authorization: Bearer $FIREBASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "isAvailable": true,
    "currentLocation": {"latitude": 37.7749, "longitude": -122.4194}
  }'
```

---

## 📚 SDK Examples

### JavaScript/TypeScript
```typescript
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

class RideSharingAPI {
  private baseUrl = 'https://us-central1-ride-sharing-prod.cloudfunctions.net';
  
  async createRideRequest(request: RideRequest): Promise<RideResponse> {
    const token = await getAuth().currentUser?.getIdToken();
    
    const response = await fetch(`${this.baseUrl}/createRideRequest`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(request)
    });
    
    return response.json();
  }
}
```

### Swift
```swift
import FirebaseAuth

class RideSharingAPI {
    private let baseURL = "https://us-central1-ride-sharing-prod.cloudfunctions.net"
    
    func createRideRequest(_ request: RideRequest) async throws -> RideResponse {
        guard let user = Auth.auth().currentUser else {
            throw APIError.notAuthenticated
        }
        
        let token = try await user.getIDToken()
        
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/createRideRequest")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        return try JSONDecoder().decode(RideResponse.self, from: data)
    }
}
```

---

## 📍 Radar SDK Integration

The platform uses Radar SDK for precise location services and walk isochrone calculations:

### Location Services
- **Real-time location tracking** with background support
- **Geofence monitoring** for pickup zones
- **Walk isochrone calculation** for optimal pickup point selection
- **Location permission management** with user-friendly prompts

### Swift API Reference
```swift
import RadarSDK

// Initialize Radar service
let radarService = RadarLocationService()

// Request location permissions
radarService.requestLocationPermission()

// Calculate walk isochrone
radarService.getWalkIsochronePolygon(
    from: origin,
    radiusMeters: 400
) { result in
    switch result {
    case .success(let polygon):
        // Upload to Firestore
        radarService.uploadWalkIsochrone(
            userId: userId,
            polygon: polygon
        ) { uploadResult in
            // Handle upload completion
        }
    case .failure(let error):
        // Handle error
    }
}
```

### Configuration
- **Publishable Key**: Set via `Radar.initialize(publishableKey:)`
- **User Identification**: Automatic user ID assignment
- **Background Location**: Enabled for continuous tracking
- **Geofence Events**: Automatic handling of enter/exit events

### Data Models
```swift
public struct RadarLocationError: LocalizedError {
    case noCurrentLocation
    case noRoutesFound
    case noMatrixResult
    case permissionDenied
}

public struct VoIPRideNotification: Codable {
    let type: String
    let rideId: String
    let driverName: String?
    let message: String
    let callUUID: String?
    let timestamp: Date
}
```

---

*Last Updated: {{date}}*

*This API documentation is automatically generated from the source code and should be kept in sync with implementation changes.* 