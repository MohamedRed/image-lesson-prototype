# Radar Location Service Migration Guide

## Overview
The Food Delivery feature has been migrated from using direct `CLLocationManager` to the centralized Radar SDK location service, ensuring consistency with the ride-sharing feature and providing enhanced location capabilities.

## What Changed

### Removed Legacy Components
- **Direct CLLocationManager usage** - Replaced with `FoodDeliveryRadarLocationService`
- **Manual location permission handling** - Now handled by Radar service
- **Custom location tracking timers** - Radar handles optimized tracking

### New Radar-Based Components

#### 1. FoodDeliveryRadarLocationService
Located in: `FoodDeliveryService/Sources/FoodDeliveryService/RadarLocationService.swift`

Key features:
- Automatic courier tracking with appropriate presets
- Delivery zone management (geofences)
- Trip tracking for deliveries
- Optimized battery usage based on user type (customer/courier/restaurant)

#### 2. Updated ViewModels
- `CourierTrackingViewModel.swift` - Now uses Radar for all location operations
- `CourierViewModel.swift` - Integrated with Radar for courier operations

### Legacy Files (Preserved for Reference)
- `CourierTrackingViewModel.legacy.swift`
- `CourierViewModel.legacy.swift`

## Key Improvements

### 1. Unified Location Platform
- Single location service across ride-sharing and food delivery
- Consistent API and behavior
- Shared backend infrastructure

### 2. Enhanced Capabilities
- **Delivery Zones**: Automatic geofence detection for delivery areas
- **Trip Tracking**: End-to-end delivery tracking with ETAs
- **Smart Location Updates**: Battery-optimized tracking presets
- **Real-time Events**: Geofence enter/exit notifications

### 3. Better Performance
- **Efficient Tracking**: Less battery drain with smart tracking modes
- **Automatic Optimization**: Different presets for customers vs couriers
- **Background Support**: Proper background location handling

## Migration Steps for Developers

### 1. Update Package Dependencies
The `FoodDeliveryService` Package.swift has been updated to include:
```swift
.package(url: "https://github.com/radarlabs/radar-sdk-ios", from: "3.9.0")
```

### 2. Initialize Radar Service
```swift
// Old way
private let locationManager = CLLocationManager()
locationManager.requestWhenInUseAuthorization()

// New way
private let radarService = FoodDeliveryRadarLocationService()
radarService.requestLocationPermission()
```

### 3. Setup Courier Tracking
```swift
// Old way
locationManager.startUpdatingLocation()

// New way
radarService.setupCourierTracking(
    courierId: "courier123",
    metadata: ["vehicleType": "bicycle"]
)
```

### 4. Track Deliveries
```swift
// New capability - not available in legacy
radarService.startDeliveryTracking(
    orderId: orderId,
    pickupLocation: restaurantCoordinate,
    deliveryLocation: customerCoordinate
)
```

### 5. Handle Delivery Zones
```swift
// New capability - check if location is deliverable
radarService.isLocationInDeliveryZone(location: coordinate) { result in
    switch result {
    case .success(let isDeliverable):
        // Handle deliverability
    case .failure(let error):
        // Handle error
    }
}
```

## Backend Integration

The backend already uses Radar services comprehensively:
- `RadarTripService` for delivery tracking
- `RadarGeofenceService` for delivery zones
- `RadarUserService` for courier metadata

## Configuration

### Backend Config Endpoint
The `/config` endpoint provides:
```json
{
  "radarPublishableKey": "...",
  "mapboxAccessToken": "...",
  "stripePublishableKey": "..."
}
```

### iOS App Configuration
Radar SDK is initialized automatically with the publishable key from the backend config.

## Testing

### 1. Verify Location Permissions
- App should request location permission on first launch
- Different permission levels for customers (when-in-use) vs couriers (always)

### 2. Test Courier Tracking
- Go online as courier
- Accept an order
- Verify location updates are sent
- Check delivery tracking works

### 3. Test Delivery Zones
- Create restaurant with delivery zone
- Verify zone detection works
- Test order deliverability checks

### 4. Monitor Battery Usage
- Compare battery drain between customer and courier modes
- Verify background tracking works properly

## Troubleshooting

### Location Permission Issues
- Ensure Info.plist has proper location usage descriptions
- Check Radar SDK initialization in app delegate

### Tracking Not Working
- Verify Radar publishable key is correct
- Check network connectivity
- Ensure courier is "online" in the app

### Geofence Events Not Firing
- Verify geofences are created in Radar dashboard
- Check geofence tags match expected values
- Ensure location accuracy is sufficient

## Benefits Summary

1. **Consistency**: Same location service as ride-sharing
2. **Reliability**: Battle-tested Radar SDK
3. **Features**: Geofences, trips, and advanced tracking
4. **Performance**: Optimized battery usage
5. **Scalability**: Ready for growth
6. **Maintenance**: Single location service to maintain

## Next Steps

1. Remove legacy files after testing period
2. Add more Radar features (arrival detection, place detection)
3. Implement customer location sharing for live tracking
4. Add route optimization using Radar's routing API

## Support

For issues or questions:
- Check Radar documentation: https://radar.com/documentation
- Review ride-sharing implementation for reference
- Contact the platform team for assistance