package main

import (
	"encoding/json"
	"math"
	"reflect"
	"strings"
	"testing"
)

func TestComputeDriverScore_LuggageReject(t *testing.T) {
	req := RideRequest{
		Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 1,
		LuggageManifest: map[string]int{"suitcase": 2},
	}

	driver := DriverProfile{
		CapacitySeats:   4,
		LuggageCapacity: map[string]int{"suitcase": 1},
		CurrentLocation: GeoPoint{0, 0},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected luggage filter to reject driver")
	}
}

func TestComputeDriverScore_RejectsStuckDriver(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("stuck-driver", 0, 0, routeCorridor())
	driver.IsStuck = true

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected stuck driver to be rejected before scoring")
	}
}

func TestComputeDriverScore_RejectsSuspiciousLocationDriver(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("spoof-flagged-driver", 0, 0, routeCorridor())
	driver.IsSuspiciousLocation = true

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected spoof-flagged driver to be rejected before scoring")
	}
}

func TestComputeDriverScore_RejectsBlockedDriver(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("blocked-driver", 0, 0, routeCorridor())
	driver.IsBlocked = true

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected blocked driver to be rejected before scoring")
	}
}

func TestComputeDriverScore_RejectsExplicitOfflineDriver(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("offline-driver", 0, 0, routeCorridor())
	driver.HasAvailabilityState = true
	driver.IsOnline = false
	driver.IsAvailable = true

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected explicitly offline driver to be rejected before scoring")
	}
}

func TestComputeDriverScore_RejectsExplicitUnavailableDriver(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("unavailable-driver", 0, 0, routeCorridor())
	driver.HasAvailabilityState = true
	driver.IsOnline = true
	driver.IsAvailable = false

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected explicitly unavailable driver to be rejected before scoring")
	}
}

func TestComputeDriverScore_RejectsUnverifiedDriverLicense(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("unverified-license-driver", 0, 0, routeCorridor())
	driver.HasLicenseVerification = true
	driver.LicenseVerified = false

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected explicitly unverified driver license to be rejected before scoring")
	}
}

func TestComputeDriverScore_RejectsPendingDriverVerificationStatus(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("pending-verification-driver", 0, 0, routeCorridor())
	driver.VerificationStatus = "pending"

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected pending driver verification status to be rejected before scoring")
	}
}

func TestComputeDriverScore_RejectsPendingReviewDriverVerificationStatus(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("pending-review-verification-driver", 0, 0, routeCorridor())
	driver.VerificationStatus = "pending_review"

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected pending_review driver verification status to be rejected before scoring")
	}
}

func TestComputeDriverScore_NormalizesSerializedPendingReviewStatus(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("pending-review-hyphen-verification-driver", 0, 0, routeCorridor())
	driver.VerificationStatus = " Pending-Review "

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected hyphenated pending-review verification status to be normalized and rejected")
	}
}

func TestComputeDriverScore_NormalizesCamelCasePendingReviewStatus(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("pending-review-camel-verification-driver", 0, 0, routeCorridor())
	driver.VerificationStatus = "pendingReview"

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected camelCase pendingReview verification status to be normalized and rejected")
	}
}

func TestComputeDriverScore_RejectsFailedDriverBackgroundCheck(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("failed-background-check-driver", 0, 0, routeCorridor())
	driver.HasBackgroundCheckPassed = true
	driver.BackgroundCheckPassed = false

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected failed driver background check to be rejected before scoring")
	}
}

func TestComputeDriverScore_RejectsSuspendedComplianceStatus(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("suspended-compliance-driver", 0, 0, routeCorridor())
	driver.ComplianceStatus = "suspended"

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected suspended compliance status to be rejected before scoring")
	}
}

func TestComputeDriverScore_RejectsUnverifiedRiderIdentityWhenRequired(t *testing.T) {
	req := corridorRequest()
	req.RequiresRiderIdentity = true
	req.RiderIdentityVerified = false
	driver := corridorDriver("identity-required-driver", 0, 0, routeCorridor())

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected missing required rider identity verification to reject before scoring")
	}
}

func TestComputeDriverScore_RejectsUnauthorizedPaymentWhenRequired(t *testing.T) {
	req := corridorRequest()
	req.RequiresPaymentAuthorization = true
	req.PaymentAuthorized = false
	driver := corridorDriver("payment-required-driver", 0, 0, routeCorridor())

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected missing required payment authorization to reject before scoring")
	}
}

func TestComputeDriverScore_RejectsMixedGenderPool(t *testing.T) {
	req := corridorRequest()
	req.RiderGender = "female"
	driver := corridorDriver("male-passenger-pool", 0, 0, routeCorridor())
	driver.CurrentPassengerGenders = []string{"male"}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected existing male passenger pool to reject female rider")
	}
}

func TestComputeDriverScore_TrimsRiderGenderBeforePoolCompatibility(t *testing.T) {
	req := corridorRequest()
	req.RiderGender = " female "
	driver := corridorDriver("female-passenger-pool", 0, 0, routeCorridor())
	driver.CurrentPassengerGenders = []string{"female"}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected riderGender whitespace to be normalized before gender-pool compatibility")
	}
}

func TestComputeDriverScore_NormalizesGenderCaseBeforePoolCompatibility(t *testing.T) {
	req := corridorRequest()
	req.RiderGender = " Female "
	driver := corridorDriver("female-passenger-pool-case", 0, 0, routeCorridor())
	driver.CurrentPassengerGenders = []string{"female"}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected riderGender case to be normalized before gender-pool compatibility")
	}
}

func TestRiderGenderFilterTrimsWhitespaceForFirestoreQuery(t *testing.T) {
	if got := riderGenderFilter(" Female "); got != "female" {
		t.Fatalf("expected rider gender Firestore filter to be trimmed and lowercased, got %q", got)
	}
	if got := riderGenderFilter("   "); got != "" {
		t.Fatalf("expected blank rider gender filter to be omitted, got %q", got)
	}
}

func TestComputeDriverScore_RejectsExclusiveRequestWithExistingReservedSeats(t *testing.T) {
	req := corridorRequest()
	req.RiderGender = "female"
	req.PremiumRequested = map[string]any{"exclusive": true}
	driver := corridorDriver("exclusive-capable-but-occupied", 0, 0, routeCorridor())
	driver.PremiumCapabilities = map[string]any{"exclusive": true}
	driver.ReservedSeats = 1
	driver.CurrentPassengerGenders = []string{"female"}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected exclusive request to reject a driver with existing reserved passengers")
	}
}

func TestComputeDriverScore_ExclusiveRequestUsesSeatLedgerNotStaleActivePickups(t *testing.T) {
	req := corridorRequest()
	req.PremiumRequested = map[string]any{"exclusive": true}
	driver := corridorDriver("exclusive-empty-ledger-stale-active-pickups", 0, 0, routeCorridor())
	driver.PremiumCapabilities = map[string]any{"exclusive": true}
	driver.HasSeatLedger = true
	driver.ReservedSeats = 0
	driver.ActivePickups = 4

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected explicit empty seat ledger to override stale activePickups for exclusive occupancy")
	}
}

func TestComputeDriverScore_ExclusiveRequestIgnoresEmptyPassengerGenderPlaceholders(t *testing.T) {
	req := corridorRequest()
	req.PremiumRequested = map[string]any{"exclusive": true}
	driver := corridorDriver("exclusive-empty-gender-placeholders", 0, 0, routeCorridor())
	driver.PremiumCapabilities = map[string]any{"exclusive": true}
	driver.HasSeatLedger = true
	driver.ReservedSeats = 0
	driver.CurrentPassengerGenders = []string{"", "   "}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected blank currentPassengerGenders placeholders not to count as existing passengers")
	}
}

func TestComputeDriverScore_IgnoresFalsePremiumRequirement(t *testing.T) {
	req := corridorRequest()
	req.PremiumRequested = map[string]any{"exclusive": false}
	driver := corridorDriver("standard-driver", 0, 0, routeCorridor())

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected false premium flag to be ignored instead of requiring an explicit false capability")
	}
}

func TestComputeDriverScore_UsesLuggageLedgerForCapacity(t *testing.T) {
	req := RideRequest{
		Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 1,
		LuggageManifest: map[string]int{"suitcase": 1},
	}

	driver := DriverProfile{
		CapacitySeats:   4,
		LuggageCapacity: map[string]int{"suitcase": 2},
		ReservedLuggage: map[string]int{"suitcase": 2},
		CurrentLocation: GeoPoint{0, 0},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected luggage ledger usage to reject a driver with no suitcase capacity left")
	}
}

func TestComputeDriverScore_UsesPetLedgerForCapacity(t *testing.T) {
	req := RideRequest{
		Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 1,
		Pet: map[string]int{"small": 1},
	}

	driver := DriverProfile{
		CapacitySeats:   4,
		PetLimits:       map[string]int{"small": 1},
		ReservedPets:    map[string]int{"small": 1},
		CurrentLocation: GeoPoint{0, 0},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected pet ledger usage to reject a driver with no small-pet capacity left")
	}
}

func TestComputeDriverScore_UsesChildSeatLedgerForCapacity(t *testing.T) {
	req := RideRequest{
		Origin:         GeoPoint{0, 0},
		Destination:    GeoPoint{1, 1},
		PassengerCount: 1,
		ChildPassengers: []struct {
			AgeYears int `json:"ageYears"`
			WeightKg int `json:"weightKg"`
		}{{AgeYears: 3, WeightKg: 15}},
	}

	driver := DriverProfile{
		CapacitySeats:      4,
		ChildSeatInventory: map[string]int{"forward": 1},
		ReservedChildSeats: map[string]int{"forward": 1},
		CurrentLocation:    GeoPoint{0, 0},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected child-seat ledger usage to reject a driver with no forward seats left")
	}
}

func TestComputeDriverScore_CurbPenalty(t *testing.T) {
	req := RideRequest{Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 1}
	driver := DriverProfile{CapacitySeats: 4, CurrentLocation: GeoPoint{0, 0}}

	score1, _, ok1 := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok1 {
		t.Fatalf("driver should be accepted")
	}
	score2, _, ok2 := computeDriverScore(req, driver, 2, 0.7, 0.3, 1)
	if !ok2 {
		t.Fatalf("driver should be accepted even with curb factor")
	}
	if score2 <= score1 {
		t.Fatalf("expected score with curb penalty to be higher (worse) got %f <= %f", score2, score1)
	}
}

func TestComputeDriverScore_DefaultsMissingCapacitySeatsToReservationDefault(t *testing.T) {
	req := RideRequest{Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 1}
	driver := DriverProfile{CurrentLocation: GeoPoint{0, 0}}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected missing capacitySeats to default to reservation runtime capacity")
	}
}

func TestComputeDriverScore_UsesReservedSeatLedgerForCapacity(t *testing.T) {
	req := RideRequest{Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 2}
	driver := DriverProfile{
		CapacitySeats:   4,
		ActivePickups:   1,
		ReservedSeats:   3,
		CurrentLocation: GeoPoint{0, 0},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected driver with only one seat left to reject a two-passenger request")
	}
}

func TestComputeDriverScore_SeatLedgerOverridesActivePickupCount(t *testing.T) {
	req := RideRequest{Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 2}
	driver := DriverProfile{
		CapacitySeats:   6,
		ActivePickups:   3,
		ReservedSeats:   2,
		CurrentLocation: GeoPoint{0, 0},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected reserved seat ledger, not active pickup count, to decide remaining capacity")
	}
}

func TestComputeDriverScore_EmptySeatLedgerDoesNotFallBackToActivePickupCount(t *testing.T) {
	req := RideRequest{Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 4}
	driver := DriverProfile{
		CapacitySeats:   4,
		ActivePickups:   3,
		HasSeatLedger:   true,
		ReservedSeats:   0,
		CurrentLocation: GeoPoint{0, 0},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected an empty seat ledger to mean zero reserved seats, not legacy active-pickup fallback")
	}
}

func TestComputeDriverScore_ToddlerRequiresForwardChildSeat(t *testing.T) {
	req := RideRequest{
		Origin:         GeoPoint{0, 0},
		Destination:    GeoPoint{1, 1},
		PassengerCount: 1,
		ChildPassengers: []struct {
			AgeYears int `json:"ageYears"`
			WeightKg int `json:"weightKg"`
		}{{AgeYears: 3, WeightKg: 15}},
	}

	driver := DriverProfile{
		CapacitySeats:      4,
		CurrentLocation:    GeoPoint{0, 0},
		ChildSeatInventory: map[string]int{"forward": 1},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected toddler child passenger to use forward child-seat inventory")
	}
}

func TestComputeDriverScore_RejectsToddlerWhenOnlyBoosterAvailable(t *testing.T) {
	req := RideRequest{
		Origin:         GeoPoint{0, 0},
		Destination:    GeoPoint{1, 1},
		PassengerCount: 1,
		ChildPassengers: []struct {
			AgeYears int `json:"ageYears"`
			WeightKg int `json:"weightKg"`
		}{{AgeYears: 3, WeightKg: 15}},
	}

	driver := DriverProfile{
		CapacitySeats:      4,
		CurrentLocation:    GeoPoint{0, 0},
		ChildSeatInventory: map[string]int{"booster": 1},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected toddler child passenger to reject booster-only inventory")
	}
}

func TestComputeDriverScore_DoesNotInferLowWeightWhenChildWeightMissing(t *testing.T) {
	req := RideRequest{
		Origin:         GeoPoint{0, 0},
		Destination:    GeoPoint{1, 1},
		PassengerCount: 1,
		ChildPassengers: []struct {
			AgeYears int `json:"ageYears"`
			WeightKg int `json:"weightKg"`
		}{{AgeYears: 9, WeightKg: 0}},
	}

	driver := DriverProfile{
		CapacitySeats:   4,
		CurrentLocation: GeoPoint{0, 0},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected missing child weight to be treated as unknown, not as low-weight booster requirement")
	}
}

func TestComputeDriverScore_CorridorIntersectsOriginWalkZone(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("route-match", 0.05, 0, routeCorridor())

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected driver route corridor intersecting origin and destination walk zones to be accepted")
	}
}

func TestComputeDriverScore_CorridorIntersectsDestinationWalkZone(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.OriWalkIso = GeoJSONGeometry{}
	req.OriginWalkIso = GeoJSONGeometry{}
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("destination-route-match", 0.05, 1, rectPolygon(-0.005, 0.90, 0.005, 1.01))

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected driver route corridor intersecting destination walk zone to be accepted")
	}
}

func TestComputeDriverScore_CorridorIntersectsMultiPolygonWalkZone(t *testing.T) {
	req := corridorRequest()
	req.OriWalkIso = multiPolygon(
		rectRing(10, 10, 11, 11),
		rectRing(-0.01, -0.01, 0.01, 0.01),
	)
	driver := corridorDriver("multipolygon-route-match", 0.05, 0, routeCorridor())

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected driver route corridor intersecting a later MultiPolygon walk-zone part to be accepted")
	}
}

func TestComputeDriverScore_AllowsRoutePassingNearWalkZonesWithinWalkRadius(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "100")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	req := corridorRequest()
	req.WalkRadiusM = 100
	req.OriWalkIso = rectPolygon(-0.0002, -0.0002, 0.0002, 0.0002)
	req.DestWalkIso = rectPolygon(-0.0002, 0.9998, 0.0002, 1.0002)
	req.OriDriveIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	driver := corridorDriver("route-near-walk-zones", 0.0006, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.0006, Longitude: -0.10},
		{Latitude: 0.0006, Longitude: 0},
		{Latitude: 0.0006, Longitude: 1},
		{Latitude: 0.0006, Longitude: 1.10},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route passing near origin and destination walk zones within walk radius to be accepted")
	}
}

func TestDriverRouteIntersectsOrPassesNearGeometry_NormalizesRoutePolyline(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "100")
	req := corridorRequest()
	req.WalkRadiusM = 100
	geometry := rectPolygon(-0.0002, -0.0002, 0.0002, 0.0002)
	driver := corridorDriver("near-helper-whitespace-route", 0.0006, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = " \n" + encodePolyline([]GeoPoint{
		{Latitude: 0.0006, Longitude: -0.10},
		{Latitude: 0.0006, Longitude: 0},
		{Latitude: 0.0006, Longitude: 1},
	}) + "\t "

	if !driverRouteIntersectsOrPassesNearGeometry(req, driver, geometry, req.Origin) {
		t.Fatalf("expected near-corridor helper to normalize whitespace-padded routePolyline before near-walk fallback")
	}
}

func TestDriverRouteIntersectsOrPassesNearGeometry_RejectsNearProjectionInsideWalkZoneHole(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "100")
	req := corridorRequest()
	req.WalkRadiusM = 100
	geometry := polygonWithHole(
		rectRing(-0.05, 0.95, 0.05, 1.05),
		rectRing(-0.01, 0.99, 0.01, 1.01),
	)
	driver := corridorDriver("near-helper-hole-route", 0, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	if driverRouteIntersectsOrPassesNearGeometry(req, driver, geometry, req.Destination) {
		t.Fatalf("expected near-corridor helper to reject route snap inside destination walk-zone hole")
	}
}

func TestComputeDriverScore_UsesLaterNearOriginProjectionWhenEarlierSegmentIsOutsideWalkRadius(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "200")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(-0.0001, -0.0001, 0.0001, 0.0001)
	req.DestWalkIso = rectPolygon(-0.0001, 0.9999, 0.0001, 1.0001)
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("later-near-origin-route", 0.05, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.05, Longitude: -0.10}, // earlier segment is outside the rider walk radius
		{Latitude: 0.05, Longitude: 0.50},
		{Latitude: 0.002, Longitude: 0}, // later usable pickup snap within the effective walk radius
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route-order fallback to skip earlier outside-walk projections and use the later near-origin pickup")
	}
}

func TestComputeDriverScore_GlobalWalkLimitCapsBroadStaleOriginWalkPolygon(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "200")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(-0.10, -0.20, 0.10, 0.60)
	req.DestWalkIso = rectPolygon(-0.0001, 0.9999, 0.0001, 1.0001)
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("global-walk-limit-origin-route", 0.05, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.05, Longitude: -0.10},
		{Latitude: 0.05, Longitude: 0.50}, // inside stale walk polygon but outside global walk limit
		{Latitude: 0.002, Longitude: 0},   // later pickup candidate inside global walk limit
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected global MAX_SINGLE_HOP_WALK_METERS to skip stale broad origin polygon points and allow the later walk-feasible pickup")
	}
}

func TestComputeDriverScore_RiderWalkRadiusCapsBroadStaleWalkPolygon(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "1000")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "200")
	req := corridorRequest()
	req.WalkRadiusM = 300
	req.OriWalkIso = rectPolygon(-0.10, -0.20, 0.10, 0.60) // stale/broad polygon contains the early far route segment
	req.DestWalkIso = rectPolygon(-0.0001, 0.9999, 0.0001, 1.0001)
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("broad-walk-radius-cap-route", 0.05, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.05, Longitude: -0.10},
		{Latitude: 0.05, Longitude: 0.50}, // inside stale walk polygon but outside rider walkRadiusM
		{Latitude: 0.002, Longitude: 0},   // first pickup candidate inside rider walkRadiusM
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected rider walkRadiusM to cap stale broad walk polygon and allow the later walk-feasible pickup")
	}
}

func TestComputeDriverScore_GlobalWalkLimitCapsBroadStaleDestinationWalkPolygon(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "200")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(-0.0001, -0.0001, 0.0001, 0.0001)
	req.DestWalkIso = rectPolygon(-0.10, 0.40, 0.10, 1.10)
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("global-walk-limit-destination-route", 0, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0.05, Longitude: 0.50}, // inside stale destination walk polygon but outside global walk limit
		{Latitude: 0.002, Longitude: 1},   // later dropoff candidate inside global walk limit
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected global MAX_SINGLE_HOP_WALK_METERS to skip stale broad destination polygon points and allow the later walk-feasible dropoff")
	}
}

func TestComputeDriverScore_GlobalWalkLimitRejectsBufferOnlyStaleBroadWalkPolygons(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	req := corridorRequest()
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriWalkIso = rectPolygon(0.045, -0.01, 0.055, 0.01)
	req.DestWalkIso = rectPolygon(0.045, 0.99, 0.055, 1.01)
	driver := corridorDriver("buffer-only-stale-broad-walk-polygons", 0.05, 0, rectPolygon(0.045, -0.01, 0.055, 1.01))

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected explicit walk cap to reject buffer-only stale walk-polygon intersections far from rider endpoints")
	}
}

func TestComputeDriverScore_GlobalWalkLimitAllowsBufferOnlyEdgeWithinWalkCap(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	req := corridorRequest()
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriWalkIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	driver := corridorDriver("buffer-only-edge-within-walk-cap", 0.002, 0, rectPolygon(0.002, -0.01, 0.003, 1.01))

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected buffer-only corridor to match when an overlapping edge point is within explicit walk cap even though no common vertex is")
	}
}

func TestComputeDriverScore_GlobalWalkLimitRejectsBufferOnlyOriginWalkAndDriveCommonPointOutsideCap(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(-0.01, -0.01, 0.06, 0.01)
	req.OriDriveIso = rectPolygon(0.049, -0.01, 0.051, 0.01)
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	driver := corridorDriver("buffer-only-origin-drive-common-point-too-far", 0.002, 0, rectPolygon(0.002, -0.01, 0.051, 1.01))

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected buffer-only origin walk+drive common point outside explicit walk cap to be rejected")
	}
}

func TestRoutePolylineTravelsOriginBeforeDestinationSkipsDestinationOutsideExplicitWalkCap(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(-0.0001, -0.0001, 0.0001, 0.0001)
	req.DestWalkIso = rectPolygon(-0.10, 0.40, 0.10, 1.10)
	route := encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0.05, Longitude: 0.50}, // inside stale destination walk polygon but outside explicit walk cap
		{Latitude: 0.002, Longitude: 1},   // later destination projection inside explicit walk cap
	})

	if !routePolylineTravelsOriginBeforeDestination(req, route) {
		t.Fatalf("expected route-order check to skip stale destination polygon points outside explicit walk cap and use the later walk-feasible dropoff")
	}
}

func TestRoutePolylineTravelsOriginBeforeDestinationRejectsEarlyOriginOutsideExplicitWalkCap(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(-0.10, -0.10, 0.10, 0.10)
	req.DestWalkIso = rectPolygon(-0.0001, 0.9999, 0.0001, 1.0001)
	route := encodePolyline([]GeoPoint{
		{Latitude: 0.05, Longitude: 0}, // inside stale origin walk polygon but outside explicit walk cap
		{Latitude: 0, Longitude: 1},    // destination before legal pickup
		{Latitude: 0.002, Longitude: 0}, // later legal pickup, with no later destination
	})

	if routePolylineTravelsOriginBeforeDestination(req, route) {
		t.Fatalf("expected route-order check to reject a destination-before-pickup route when the earlier origin hit exceeds explicit walk cap")
	}
}

func TestComputeDriverScore_RiderWalkRadiusCapsBroadStaleDestinationWalkPolygon(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "1000")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "200")
	req := corridorRequest()
	req.WalkRadiusM = 300
	req.OriWalkIso = rectPolygon(-0.0001, -0.0001, 0.0001, 0.0001)
	req.DestWalkIso = rectPolygon(-0.10, 0.40, 0.10, 1.10) // stale/broad polygon contains an early far dropoff candidate
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("broad-destination-walk-radius-cap-route", 0, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0.05, Longitude: 0.50}, // inside stale dest walk polygon but outside rider walkRadiusM
		{Latitude: 0.002, Longitude: 1},   // later dropoff inside rider walkRadiusM
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected rider walkRadiusM to cap stale broad destination walk polygon and allow the later walk-feasible dropoff")
	}
}

func TestComputeDriverScore_RiderWalkRadiusCapsBroadStaleDestinationWalkPolygonWithDestinationDriveGeo(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "1000")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "200")
	req := corridorRequest()
	req.WalkRadiusM = 300
	req.OriWalkIso = rectPolygon(-0.0001, -0.0001, 0.0001, 0.0001)
	req.DestWalkIso = rectPolygon(-0.10, 0.40, 0.10, 1.10)
	req.DestinationDriveGeo = multiPolygon(
		rectRing(0.04, 0.49, 0.06, 0.51), // early legal drive area, but outside rider walk radius
		rectRing(-0.01, 0.99, 0.01, 1.01), // later legal drive area inside rider walk radius
	)
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("broad-destination-walk-radius-cap-with-drive-route", 0, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0.05, Longitude: 0.50},
		{Latitude: 0.002, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected rider walkRadiusM to skip early destinationDriveGeo dropoff outside walk radius and allow the later legal dropoff")
	}
}

func TestComputeDriverScore_AllowsNearDestinationWalkPointInsideDestinationDriveGeo(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "100")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	req := corridorRequest()
	req.WalkRadiusM = 100
	req.OriWalkIso = rectPolygon(-0.0002, -0.0002, 0.0002, 0.0002)
	req.DestWalkIso = rectPolygon(-0.0002, 0.9998, 0.0002, 1.0002)
	req.OriDriveIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.DestinationDriveGeo = rectPolygon(-0.001, 0.9998, 0.001, 1.0002)
	driver := corridorDriver("route-near-destination-walk-inside-drive", 0.0006, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.0006, Longitude: -0.10},
		{Latitude: 0.0006, Longitude: 0},
		{Latitude: 0.0006, Longitude: 1},
		{Latitude: 0.0006, Longitude: 1.10},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected destinationDriveGeo to allow a route point near the destination walk zone within walk radius")
	}
}

func TestComputeDriverScore_AllowsRoutePointInsideDestinationDriveGeoNearButOutsideTinyWalkZone(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "100")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	req := corridorRequest()
	req.WalkRadiusM = 100
	req.OriWalkIso = rectPolygon(-0.0002, -0.0002, 0.0002, 0.0002)
	req.DestWalkIso = rectPolygon(-0.0002, 0.9998, 0.0002, 1.0002)
	req.OriDriveIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.DestinationDriveGeo = rectPolygon(0.0005, 0.9998, 0.0007, 1.0002)
	driver := corridorDriver("route-near-destination-walk-inside-disjoint-drive", 0.0006, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.0006, Longitude: -0.10},
		{Latitude: 0.0006, Longitude: 0},
		{Latitude: 0.0006, Longitude: 1},
		{Latitude: 0.0006, Longitude: 1.10},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route point inside destinationDriveGeo and within rider walk radius to satisfy tiny disjoint destination walk zone")
	}
}

func TestComputeDriverScore_AllowsLaterNearDestinationAfterEarlierDestinationWalkPass(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "100")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	req := corridorRequest()
	req.WalkRadiusM = 100
	req.OriWalkIso = rectPolygon(-0.0002, -0.0002, 0.0002, 0.0002)
	req.DestWalkIso = rectPolygon(-0.0002, 0.9998, 0.0002, 1.0002)
	req.OriDriveIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	driver := corridorDriver("later-near-destination-after-early-dest", 0, 1, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 1},      // destination walk zone before pickup; not a valid dropoff
		{Latitude: 0, Longitude: 0},      // legal pickup
		{Latitude: 0.0006, Longitude: 1}, // later dropoff near destination walk zone within walk radius
		{Latitude: 0.0006, Longitude: 1.1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected later near-destination projection after pickup to be accepted despite an earlier destination walk-zone pass")
	}
}

func TestComputeDriverScore_RejectsCorridorMissingOriginWalkZone(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("miss-origin", 0, 0.1, rectPolygon(-0.005, 0.20, 0.005, 1.01))

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected driver route corridor that misses origin walk zone to be rejected")
	}
}

func TestComputeDriverScore_RejectsCorridorMissingDestinationWalkZone(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("miss-destination", 0, 0, rectPolygon(-0.005, -0.01, 0.005, 0.50))

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected driver route corridor that misses destination walk zone to be rejected")
	}
}

func TestDriverSatisfiesSingleHopCorridor_TreatsWhitespaceRoutePolylineAsMissing(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("whitespace-route-falls-back-to-buffer", 0, 0, routeCorridor())
	driver.RoutePolyline = "  \n	  "

	if !driverSatisfiesSingleHopCorridor(req, driver) {
		t.Fatalf("expected whitespace routePolyline to be treated as missing so valid bufferPolygon corridor can match")
	}
}

func TestComputeDriverScore_TreatsInvalidRoutePolylineAsMissingAndUsesBuffer(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("invalid-route-polyline-buffer-fallback", 0.05, 0, routeCorridor())
	driver.RoutePolyline = "not-a-valid-polyline"

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected invalid routePolyline to be treated as unusable so valid bufferPolygon corridor can match")
	}
}

func TestDriverRouteIntersectsGeometry_TreatsInvalidRoutePolylineAsMissing(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("invalid-route-polyline-helper-fallback", 0.05, 0, routeCorridor())
	driver.RoutePolyline = "not-a-valid-polyline"

	if !driverRouteIntersectsGeometry(driver, req.originWalkGeometry()) {
		t.Fatalf("expected route-intersection helper to ignore unusable routePolyline and use bufferPolygon fallback")
	}
}

func TestComputeDriverScore_UsesCanonicalRouteBufferWhenRoutePolylineInvalid(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("invalid-route-polyline-route-buffer-fallback", 0.05, 0, GeoJSONGeometry{})
	driver.RoutePolyline = "not-a-valid-polyline"
	driver.RouteBuffer = routeCorridor()

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected invalid routePolyline to fall back to canonical routeBuffer corridor")
	}
}

func TestDriverEntersOriginDriveGeo_TreatsInvalidRoutePolylineAsMissing(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("invalid-route-polyline-origin-drive-buffer-fallback", 0.20, 0, routeCorridor())
	driver.RoutePolyline = "not-a-valid-polyline"

	if !driverEntersOriginDriveGeo(req, driver) {
		t.Fatalf("expected origin-drive helper to ignore unusable routePolyline and use bufferPolygon fallback")
	}
}

func TestDriverEntersDestinationDriveGeo_TreatsInvalidRoutePolylineAsMissing(t *testing.T) {
	req := corridorRequest()
	req.DestinationDriveGeo = rectPolygon(-0.05, 0.95, 0.05, 1.05)
	driver := corridorDriver("invalid-route-polyline-destination-drive-buffer-fallback", 0, -0.10, routeCorridor())
	driver.RoutePolyline = "not-a-valid-polyline"

	if !driverEntersDestinationDriveGeo(req, driver) {
		t.Fatalf("expected destination-drive helper to ignore unusable routePolyline and use bufferPolygon fallback")
	}
}

func TestComputeDriverScore_RejectsRouteThatHitsDestinationBeforeOrigin(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("reverse-route", 0, 1, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 1},
		{Latitude: 0, Longitude: 0},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected reverse-direction route to be rejected even when its corridor intersects both walk zones")
	}
}

func TestRoutePolylineTravelsOriginBeforeDestination_TrimsRoutePolyline(t *testing.T) {
	req := corridorRequest()
	encoded := encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	if !routePolylineTravelsOriginBeforeDestination(req, "  \n"+encoded+"	  ") {
		t.Fatalf("expected route-order helper to trim a valid routePolyline before decoding")
	}
}

func TestComputeDriverScore_RejectsReverseRouteWhenOnlyDriveGeoAvailable(t *testing.T) {
	allowLongPickupETA(t)
	req := RideRequest{
		Origin:         GeoPoint{Latitude: 0, Longitude: 0},
		Destination:    GeoPoint{Latitude: 0, Longitude: 1},
		PassengerCount: 1,
		OriDriveIso:    rectPolygon(-0.05, -0.05, 0.05, 0.05),
	}
	driver := corridorDriver("reverse-route-drive-geo-only", 0, 1, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 1},
		{Latitude: 0, Longitude: 0},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected reverse-direction route to be rejected even when only originDriveGeo is available")
	}
}

func TestComputeDriverScore_RejectsDestinationDriveGeoOnlyBeforeOrigin(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "200000")
	req := RideRequest{
		Origin:              GeoPoint{Latitude: 0, Longitude: 0},
		Destination:         GeoPoint{Latitude: 0, Longitude: 1},
		PassengerCount:      1,
		OriDriveIso:         rectPolygon(-0.05, -0.05, 0.05, 0.05),
		DestinationDriveGeo: rectPolygon(-0.05, 0.95, 0.05, 1.05),
	}
	driver := corridorDriver("destination-drive-before-origin", 0, 1, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 1},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.5},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected destinationDriveGeo reached only before origin to be rejected")
	}
}

func TestComputeDriverScore_AllowsRouteOnWalkZoneBoundaries(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "2000")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	req := corridorRequest()
	driver := corridorDriver("route-on-walk-zone-boundaries", -0.01, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: -0.01, Longitude: -0.10},
		{Latitude: -0.01, Longitude: 1.10},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route touching origin and destination walk-zone boundaries in order to be accepted")
	}
}

func TestComputeDriverScore_AllowsRouteThatContinuesAfterDestinationNearOrigin(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	driver := corridorDriver("continues-after-destination", 0, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 1.10},
		{Latitude: 0, Longitude: 0.005},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route that reaches origin before destination to remain valid even if it later continues near origin")
	}
}

func TestComputeDriverScore_AllowsRouteOrderWhenDestinationWalkZoneMissing(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.DestWalkIso = GeoJSONGeometry{}
	req.DestinationWalkIso = GeoJSONGeometry{}
	driver := corridorDriver("origin-zone-with-destination-projection", 0, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 1.10},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route order to use destination projection when destination walk-zone geometry is missing")
	}
}

func TestComputeDriverScore_UsesLaterDestinationProjectionWhenEarlierDestinationPrecedesOrigin(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.DestWalkIso = GeoJSONGeometry{}
	req.DestinationWalkIso = GeoJSONGeometry{}
	driver := corridorDriver("later-destination-after-origin", 0, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 1.00},
		{Latitude: 0, Longitude: 0.00},
		{Latitude: 0, Longitude: 1.10},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route order to ignore destination projections before pickup and use the later destination pass")
	}
}

func TestComputeDriverScore_UsesEarlierOriginProjectionWhenOriginWalkZoneMissing(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0.004, Longitude: 0}
	req.OriWalkIso = GeoJSONGeometry{}
	req.OriginWalkIso = GeoJSONGeometry{}
	driver := corridorDriver("earlier-origin-projection", 0, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 1.00},
		{Latitude: 0.004, Longitude: 0.00},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route order to ignore later origin projections when an earlier origin projection reaches destination")
	}
}

func TestComputeDriverScore_RejectsRouteThatNeverEntersOriginDriveGeo(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("never-enters-origin-drive-geo", 0, 0.20, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.20},
		{Latitude: 0, Longitude: 1.20},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected route that never enters rider origin drive geofence to be rejected")
	}
}

func TestComputeDriverScore_AllowsRouteCrossingOriginDriveGeoWhenNearestProjectionOutside(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "20000")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "20000")
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0.05, Longitude: 0.05}
	req.OriWalkIso = rectPolygon(-0.10, -0.10, 0.10, 0.10)
	req.OriDriveIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.Destination = GeoPoint{Latitude: 0, Longitude: 1}
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	driver := corridorDriver("crosses-origin-drive-away-from-raw-origin", 0, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0.10},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route segment crossing originDriveGeo to satisfy pickup geofence even when raw-origin projection is outside")
	}
}

func TestComputeDriverScore_RejectsDestinationDriveGeoOnlyBeforePickup(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.Destination = GeoPoint{Latitude: 0.02, Longitude: 1}
	req.DestWalkIso = rectPolygon(0.01, 0.99, 0.03, 1.01)
	req.DestinationWalkIso = GeoJSONGeometry{}
	req.DestinationDriveGeo = rectPolygon(-0.005, 0.895, 0.005, 0.905)
	driver := corridorDriver("destination-drive-before-pickup", 0, 0.90, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.90},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0.02, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected route that enters destinationDriveGeo only before pickup to be rejected")
	}
}

func TestComputeDriverScore_AllowsLaterDestinationDriveGeoAfterEarlierOutsideWalkZone(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "20000")
	req := corridorRequest()
	req.Destination = GeoPoint{Latitude: 0.05, Longitude: 0.95}
	req.DestWalkIso = rectPolygon(-0.10, 0.90, 0.10, 1.10)
	req.DestinationDriveGeo = multiPolygon(
		rectRing(-0.01, 0.49, 0.01, 0.51), // earlier drive pass outside destination walk zone
		rectRing(-0.01, 0.99, 0.01, 1.01), // legal dropoff drive pass inside destination walk zone
	)
	driver := corridorDriver("later-destination-drive-inside-walk", 0, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1.10},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected destinationDriveGeo before the walk zone to be skipped in favor of the later legal dropoff pass")
	}
}

func TestComputeDriverScore_RejectsOriginDriveGeoOnlyAfterDropoff(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.OriDriveIso = rectPolygon(-0.005, 1.195, 0.005, 1.205)
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("origin-drive-after-dropoff", 0, -0.10, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
		{Latitude: 0, Longitude: 1.20},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected originDriveGeo reached only after dropoff to be rejected")
	}
}

func TestRouteOrderUsesOriginDriveGeoWhenWalkZoneIsBroad(t *testing.T) {
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0, Longitude: 0.05}
	req.Destination = GeoPoint{Latitude: 0, Longitude: 0.15}
	req.OriWalkIso = rectPolygon(-0.01, -0.01, 0.01, 0.21)
	req.OriDriveIso = rectPolygon(-0.01, 0.195, 0.01, 0.205)
	req.DestWalkIso = rectPolygon(-0.01, 0.145, 0.01, 0.155)
	polyline := encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.15},
		{Latitude: 0, Longitude: 0.20},
	})

	if routePolylineTravelsOriginBeforeDestination(req, polyline) {
		t.Fatalf("expected route order to use legal origin-drive pickup projection, not an earlier broad walk-zone point")
	}
}

func TestComputeDriverScore_RejectsSeparateOriginWalkAndDriveRoutePasses(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "200000")
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "200000")
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0.02, Longitude: 0.02}
	req.OriWalkIso = rectPolygon(0, 0, 0.10, 0.10)
	req.OriDriveIso = rectPolygon(0.05, 0.05, 0.15, 0.15)
	req.Destination = GeoPoint{Latitude: 0, Longitude: 1}
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	driver := corridorDriver("separate-origin-walk-drive-passes", 0.12, 0.12, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.12, Longitude: 0.12}, // inside origin drive geo only
		{Latitude: 0.12, Longitude: -0.05},
		{Latitude: 0.02, Longitude: 0.02}, // inside origin walk zone only
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected route that separately visits origin drive and walk zones without a common pickup point to be rejected")
	}
}

func TestComputeDriverScore_RejectsBufferSeparateOriginWalkAndDriveIntersections(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0.02, Longitude: 0.02}
	req.OriWalkIso = rectPolygon(0, 0, 0.10, 0.10)
	req.OriDriveIso = rectPolygon(0.05, 0.05, 0.15, 0.15)
	req.Destination = GeoPoint{Latitude: 0, Longitude: 1}
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	driver := corridorDriver("buffer-separate-origin-walk-drive", 0.12, 0.12, multiPolygon(
		rectRing(0.01, 0.01, 0.03, 0.03), // origin walk only
		rectRing(0.12, 0.12, 0.14, 0.14), // origin drive only
		rectRing(-0.005, 0.995, 0.005, 1.005),
	))

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected buffer-only route with separate origin walk/drive intersections and no common pickup point to be rejected")
	}
}

func TestDriverBufferIntersectsCommonEndpoint_TreatsInvalidRoutePolylineAsMissing(t *testing.T) {
	walk := rectPolygon(0, 0, 0.10, 0.10)
	drive := rectPolygon(0.05, 0.05, 0.15, 0.15)
	driver := corridorDriver("invalid-route-buffer-common-point", 0.12, 0.12, multiPolygon(
		rectRing(0.01, 0.01, 0.03, 0.03), // walk only
		rectRing(0.12, 0.12, 0.14, 0.14), // drive only
	))
	driver.RoutePolyline = "not-a-valid-polyline"

	if driverBufferIntersectsCommonEndpoint(corridorRequest(), driver, walk, drive, GeoPoint{Latitude: 0, Longitude: 0}) {
		t.Fatalf("expected common-endpoint helper to treat invalid routePolyline as missing and reject separate buffer walk/drive intersections")
	}
}

func TestComputeDriverScore_RejectsRouteInsideDestinationDriveGeoHole(t *testing.T) {
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0, Longitude: 0.999}
	req.Destination = GeoPoint{Latitude: 0, Longitude: 1}
	req.OriWalkIso = GeoJSONGeometry{}
	req.OriginWalkIso = GeoJSONGeometry{}
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	req.DestinationDriveGeo = polygonWithHole(
		rectRing(-0.05, 0.95, 0.05, 1.05),
		rectRing(-0.01, 0.99, 0.01, 1.01),
	)
	driver := corridorDriver("inside-destination-drive-hole", 0, 0.999, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.999},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected route only inside a destinationDriveGeo interior hole to be rejected")
	}
}

func TestComputeDriverScore_EnforcesOriginDriveGeoWithoutWalkZones(t *testing.T) {
	req := RideRequest{
		Origin:         GeoPoint{Latitude: 0, Longitude: 0},
		Destination:    GeoPoint{Latitude: 0, Longitude: 1},
		PassengerCount: 1,
		OriDriveIso:    rectPolygon(-0.05, -0.05, 0.05, 0.05),
	}
	driver := corridorDriver("outside-origin-drive-only", 0, 0.20, GeoJSONGeometry{})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected origin drive geofence to be enforced even when walk-zone geometry is unavailable")
	}
}

func TestComputeDriverScore_RejectsDriverInsideOriginDriveGeoHole(t *testing.T) {
	req := RideRequest{
		Origin:         GeoPoint{Latitude: 0, Longitude: 0},
		Destination:    GeoPoint{Latitude: 0, Longitude: 1},
		PassengerCount: 1,
		OriDriveIso: polygonWithHole(
			rectRing(-0.05, -0.05, 0.05, 0.05),
			rectRing(-0.01, -0.01, 0.01, 0.01),
		),
	}
	driver := corridorDriver("inside-origin-drive-hole", 0, 0, GeoJSONGeometry{})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected driver inside an originDriveGeo interior hole to be rejected")
	}
}

func TestComputeDriverScore_RejectsRouteOnlyInsideOriginDriveGeoHole(t *testing.T) {
	req := RideRequest{
		Origin:         GeoPoint{Latitude: 0, Longitude: 0},
		Destination:    GeoPoint{Latitude: 0, Longitude: 1},
		PassengerCount: 1,
		OriDriveIso: polygonWithHole(
			rectRing(-0.05, -0.05, 0.05, 0.05),
			rectRing(-0.01, -0.01, 0.01, 0.01),
		),
	}
	driver := corridorDriver("route-inside-origin-drive-hole", 0.20, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.005},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected routePolyline entirely inside an originDriveGeo interior hole to be rejected")
	}
}

func TestComputeDriverScore_RejectsRouteOnlyOnOriginDriveGeoHoleBoundary(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "200000")
	req := RideRequest{
		Origin:         GeoPoint{Latitude: 0, Longitude: 0},
		Destination:    GeoPoint{Latitude: 0, Longitude: 1},
		PassengerCount: 1,
		OriDriveIso: polygonWithHole(
			rectRing(-0.05, -0.05, 0.05, 0.05),
			rectRing(-0.01, -0.01, 0.01, 0.01),
		),
	}
	driver := corridorDriver("route-on-origin-drive-hole-boundary", 0.20, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: -0.01, Longitude: -0.005},
		{Latitude: -0.01, Longitude: 0.005},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected routePolyline only on an originDriveGeo hole boundary to be rejected")
	}
}

func TestComputeDriverScore_RejectsRouteOnlyInsideOriginWalkZoneHole(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.OriWalkIso = polygonWithHole(
		rectRing(-0.05, -0.05, 0.05, 0.05),
		rectRing(-0.01, -0.01, 0.01, 0.01),
	)
	req.OriginWalkIso = req.OriWalkIso
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("route-in-origin-walk-hole", 0, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected routePolyline entirely inside an origin walk-zone interior hole at pickup to be rejected")
	}
}

func TestComputeDriverScore_RejectsRouteOnlyInsideDestinationWalkZoneHole(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "100")
	req := corridorRequest()
	req.WalkRadiusM = 100
	req.DestWalkIso = polygonWithHole(
		rectRing(-0.05, 0.95, 0.05, 1.05),
		rectRing(-0.01, 0.99, 0.01, 1.01),
	)
	req.DestinationWalkIso = req.DestWalkIso
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("route-in-destination-walk-hole", 0, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected routePolyline whose only walk-feasible dropoff is inside a destination walk-zone interior hole to be rejected")
	}
}

func TestComputeDriverScore_RejectsBufferOnlyInsideOriginWalkZoneHole(t *testing.T) {
	req := corridorRequest()
	req.OriWalkIso = polygonWithHole(
		rectRing(-0.05, -0.05, 0.05, 0.05),
		rectRing(-0.01, -0.01, 0.01, 0.01),
	)
	req.OriginWalkIso = req.OriWalkIso
	req.DestWalkIso = GeoJSONGeometry{}
	req.DestinationWalkIso = GeoJSONGeometry{}
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("buffer-in-origin-walk-hole", 0, 0, rectPolygon(-0.005, -0.005, 0.005, 0.005))

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected bufferPolygon entirely inside an origin walk-zone interior hole to be rejected")
	}
}

func TestComputeDriverScore_RejectsBufferOnlyOnOriginWalkZoneHoleBoundary(t *testing.T) {
	req := corridorRequest()
	req.OriWalkIso = polygonWithHole(
		rectRing(-0.05, -0.05, 0.05, 0.05),
		rectRing(-0.01, -0.01, 0.01, 0.01),
	)
	req.OriginWalkIso = req.OriWalkIso
	req.DestWalkIso = GeoJSONGeometry{}
	req.DestinationWalkIso = GeoJSONGeometry{}
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("buffer-on-origin-walk-hole-boundary", 0, 0, rectPolygon(-0.010, -0.005, -0.009, 0.005))

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected bufferPolygon only on an origin walk-zone hole boundary to be rejected")
	}
}

func TestComputeDriverScore_RejectsPolylineMissingWalkZoneDespiteBroadBuffer(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("stale-broad-buffer", 0, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.50},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected routePolyline that misses destination walk zone to be rejected even when broad bufferPolygon intersects it")
	}
}

func TestComputeDriverScore_AcceptsCanonicalRouteBufferAlias(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("canonical-route-buffer", 0.05, 0, GeoJSONGeometry{})
	driver.RouteBuffer = routeCorridor()

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected canonical routeBuffer corridor to be accepted like legacy bufferPolygon")
	}
}

func TestComputeDriverScore_TreatsBlankRoutePolylineAsMissingAndUsesBuffer(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("blank-route-polyline-buffer-fallback", 0.05, 0, routeCorridor())
	driver.RoutePolyline = "   \n	  "

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected blank routePolyline to be treated as missing so buffer corridor can be used")
	}
}

func TestPickBestDriverFromProfiles_RanksCorridorMatchAboveNearestWrongDirection(t *testing.T) {
	req := corridorRequest()
	drivers := []DriverProfile{
		corridorDriverWithPickupZone("nearest-wrong-direction", 0, 0.001, rectPolygon(-0.005, -0.01, 0.005, 0.20), "zone-wrong-direction"),
		corridorDriverWithPickupZone("farther-valid-corridor", 0.10, 0, routeCorridor(), "zone-valid-corridor"),
	}

	driverID, _, err := pickBestDriverFromProfiles(req, drivers, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected valid corridor driver, got error: %v", err)
	}
	if driverID != "farther-valid-corridor" {
		t.Fatalf("expected farther valid corridor driver, got %q", driverID)
	}
}

func TestRouteInsertionDetourExcludesRiderWalkSnapDistance(t *testing.T) {
	req := corridorRequest()
	req.WalkRadiusM = 1000
	req.OriWalkIso = rectPolygon(-0.01, -0.02, 0.01, 0.02)
	req.DestWalkIso = rectPolygon(-0.01, 0.98, 0.01, 1.02)
	directRideKm := haversineKm(req.Origin.Latitude, req.Origin.Longitude, req.Destination.Latitude, req.Destination.Longitude)
	polyline := encodePolyline([]GeoPoint{
		{Latitude: 0.006, Longitude: 0},
		{Latitude: 0.006, Longitude: 1},
	})

	got, ok := routeInsertionDetourKm(req, polyline, directRideKm)
	if !ok {
		t.Fatalf("expected route insertion detour to score offset corridor")
	}
	if got > 0.001 {
		t.Fatalf("expected driver insertion detour to exclude rider walk snap distance, got %.6f", got)
	}
}

func TestRouteInsertionDetourTrimsRoutePolylineBeforeScoring(t *testing.T) {
	req := corridorRequest()
	directRideKm := haversineKm(req.Origin.Latitude, req.Origin.Longitude, req.Destination.Latitude, req.Destination.Longitude)
	polyline := "  \n" + encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	}) + "\t"

	got, ok := routeInsertionDetourKm(req, polyline, directRideKm)
	if !ok {
		t.Fatalf("expected route insertion detour to trim and score a valid routePolyline")
	}
	if got != 0 {
		t.Fatalf("expected direct trimmed route to have zero detour, got %.6f", got)
	}
}

func TestDriverDetourUsesRouteInsertionDetourNotPickupDistance(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("direct-route-detour", 0, -0.10, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})
	directRideKm := haversineKm(req.Origin.Latitude, req.Origin.Longitude, req.Destination.Latitude, req.Destination.Longitude)

	got := driverDetourKm(req, driver, 10, directRideKm)
	if got != 0 {
		t.Fatalf("expected direct route insertion detour to ignore separate pickup distance, got %.6f", got)
	}
}

func TestPickBestDriverFromProfiles_RanksLowerRouteDetourAboveLoopingCorridor(t *testing.T) {
	req := corridorRequest()
	direct := corridorDriverWithPickupZone("zzz-direct-corridor", 0, 0, routeCorridor(), "zone-direct")
	direct.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})
	looping := corridorDriverWithPickupZone("aaa-looping-corridor", 0, 0, routeCorridor(), "zone-looping")
	looping.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 1, Longitude: 0},
		{Latitude: 1, Longitude: 1},
		{Latitude: 0, Longitude: 1},
	})

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{looping, direct}, nil, scoreWeights{Detour: 1, ETA: 0, Curb: 1})
	if err != nil {
		t.Fatalf("expected valid corridor driver, got error: %v", err)
	}
	if driverID != "zzz-direct-corridor" {
		t.Fatalf("expected direct route with lower detour to win, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_RanksRouteEtaProfileAboveEqualGeometry(t *testing.T) {
	req := corridorRequest()
	slowProfile := corridorDriverWithPickupZone("aaa-slow-profile", 0, -0.10, routeCorridor(), "zone-slow")
	slowProfile.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})
	slowProfile.RouteETAProfileSeconds = []int{0, 1800, 1900}
	fastProfile := corridorDriverWithPickupZone("zzz-fast-profile", 0, -0.10, routeCorridor(), "zone-fast")
	fastProfile.RoutePolyline = slowProfile.RoutePolyline
	fastProfile.RouteETAProfileSeconds = []int{0, 60, 1900}

	driverID, etaSec, err := pickBestDriverFromProfiles(req, []DriverProfile{slowProfile, fastProfile}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected route ETA profile winner, got error: %v", err)
	}
	if driverID != "zzz-fast-profile" {
		t.Fatalf("expected faster route ETA profile to beat equal-geometry lower ID, got %q", driverID)
	}
	if etaSec != 60 {
		t.Fatalf("expected pickup ETA from route ETA profile, got %d", etaSec)
	}
}

func TestPickBestDriverFromProfiles_IgnoresZeroProgressRouteEtaProfileForPickupRanking(t *testing.T) {
	req := corridorRequest()
	zeroProfile := corridorDriverWithPickupZone("aaa-zero-progress-profile", 0, -0.10, routeCorridor(), "zone-zero-profile")
	zeroProfile.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})
	zeroProfile.RouteETAProfileSeconds = []int{0, 0, 0}
	validProfile := corridorDriverWithPickupZone("zzz-valid-profile", 0, -0.10, routeCorridor(), "zone-valid-profile")
	validProfile.RoutePolyline = zeroProfile.RoutePolyline
	validProfile.RouteETAProfileSeconds = []int{0, 60, 1900}

	driverID, etaSec, err := pickBestDriverFromProfiles(req, []DriverProfile{zeroProfile, validProfile}, nil, scoreWeights{ETA: 1, Curb: 1})
	if err != nil {
		t.Fatalf("expected route ETA profile winner, got error: %v", err)
	}
	if driverID != "zzz-valid-profile" {
		t.Fatalf("expected zero-progress profile to fall back to route-distance ETA instead of beating valid profile, got %q eta=%d", driverID, etaSec)
	}
	if etaSec != 60 {
		t.Fatalf("expected valid route ETA profile pickup ETA 60, got %d", etaSec)
	}
}

func TestPickBestDriverFromProfiles_RanksShorterRiderWalkAboveEqualEta(t *testing.T) {
	req := corridorRequest()
	req.WalkRadiusM = 1000
	req.OriWalkIso = rectPolygon(-0.01, -0.02, 0.01, 0.02)
	req.DestWalkIso = rectPolygon(-0.01, 0.98, 0.01, 1.02)
	req.OriDriveIso = GeoJSONGeometry{}

	farWalk := corridorDriverWithPickupZone("aaa-far-walk", 0.006, -0.10, GeoJSONGeometry{}, "zone-far-walk")
	farWalk.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.006, Longitude: -0.10},
		{Latitude: 0.006, Longitude: 0},
		{Latitude: 0.006, Longitude: 1},
	})
	farWalk.RouteETAProfileSeconds = []int{0, 60, 600}
	nearWalk := corridorDriverWithPickupZone("zzz-near-walk", 0, -0.10, GeoJSONGeometry{}, "zone-near-walk")
	nearWalk.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})
	nearWalk.RouteETAProfileSeconds = []int{0, 60, 600}

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{farWalk, nearWalk}, nil, scoreWeights{ETA: 1, Walk: 1, Curb: 1})
	if err != nil {
		t.Fatalf("expected rider-walk ranking winner, got error: %v", err)
	}
	if driverID != "zzz-near-walk" {
		t.Fatalf("expected lower rider walk to beat equal ETA lower ID, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_NormalizesRoutePolylineBeforeRiderWalkRanking(t *testing.T) {
	req := corridorRequest()
	req.WalkRadiusM = 1000
	req.OriWalkIso = rectPolygon(-0.01, -0.02, 0.01, 0.02)
	req.DestWalkIso = rectPolygon(-0.01, 0.98, 0.01, 1.02)
	req.OriDriveIso = GeoJSONGeometry{}

	farWalk := corridorDriverWithPickupZone("aaa-far-walk-whitespace-route", 0.006, -0.10, GeoJSONGeometry{}, "zone-far-walk-whitespace")
	farWalk.RoutePolyline = " \n" + encodePolyline([]GeoPoint{
		{Latitude: 0.006, Longitude: -0.10},
		{Latitude: 0.006, Longitude: 0},
		{Latitude: 0.006, Longitude: 1},
	}) + "\t "
	farWalk.RouteETAProfileSeconds = []int{0, 60, 600}
	nearWalk := corridorDriverWithPickupZone("zzz-near-walk-normal-route", 0, -0.10, GeoJSONGeometry{}, "zone-near-walk-normal")
	nearWalk.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})
	nearWalk.RouteETAProfileSeconds = []int{0, 60, 600}

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{farWalk, nearWalk}, nil, scoreWeights{ETA: 1, Walk: 1, Curb: 1})
	if err != nil {
		t.Fatalf("expected rider-walk ranking winner, got error: %v", err)
	}
	if driverID != "zzz-near-walk-normal-route" {
		t.Fatalf("expected whitespace-padded routePolyline to still receive rider-walk penalty, got %q", driverID)
	}
}

func TestDriverPickupDistanceUsesRoutePositionNotRiderWalkSnap(t *testing.T) {
	req := corridorRequest()
	req.WalkRadiusM = 1000
	req.OriWalkIso = rectPolygon(-0.01, -0.02, 0.01, 0.02)
	req.DestWalkIso = rectPolygon(-0.01, 0.98, 0.01, 1.02)
	driver := corridorDriver("offset-route-pickup-eta", 0.006, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.006, Longitude: -0.10},
		{Latitude: 0.006, Longitude: 0},
		{Latitude: 0.006, Longitude: 1},
	})

	got := driverPickupDistanceKm(req, driver, 999)
	want := haversineKm(0.006, -0.10, 0.006, 0)
	if math.Abs(got-want) > 0.001 {
		t.Fatalf("expected driver pickup distance to stop at route pickup point, not include rider walk snap: got %.6f want %.6f", got, want)
	}
}

func TestPickBestDriverFromProfiles_RanksShorterRoutePickupEtaAboveNearestCurrentLocation(t *testing.T) {
	req := corridorRequest()
	nearButLatePickup := corridorDriverWithPickupZone("aaa-nearest-but-late-pickup", 0, 0.02, routeCorridor(), "zone-late")
	nearButLatePickup.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.02},
		{Latitude: 2, Longitude: 0.02},
		{Latitude: 2, Longitude: 0},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})
	fartherButSoonerPickup := corridorDriverWithPickupZone("zzz-farther-but-sooner-pickup", 0, -0.04, routeCorridor(), "zone-sooner")
	fartherButSoonerPickup.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.04},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{nearButLatePickup, fartherButSoonerPickup}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected valid corridor driver, got error: %v", err)
	}
	if driverID != "zzz-farther-but-sooner-pickup" {
		t.Fatalf("expected route pickup ETA to beat nearest current location, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_RanksLowerSeatLoadAboveTiedCandidate(t *testing.T) {
	req := corridorRequest()
	lowLoad := corridorDriverWithPickupZone("zzz-low-seat-load", 0, 0, routeCorridor(), "zone-low-load")
	lowLoad.HasSeatLedger = true
	lowLoad.ReservedSeats = 0
	highLoad := corridorDriverWithPickupZone("aaa-high-seat-load", 0, 0, routeCorridor(), "zone-high-load")
	highLoad.HasSeatLedger = true
	highLoad.ReservedSeats = 3

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{highLoad, lowLoad}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected valid corridor driver, got error: %v", err)
	}
	if driverID != "zzz-low-seat-load" {
		t.Fatalf("expected lower seat-load driver to win tied corridor match, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_RanksLowerCargoLoadAboveTiedCandidate(t *testing.T) {
	req := corridorRequest()
	req.LuggageManifest = map[string]int{"suitcase": 1}
	lowLoad := corridorDriverWithPickupZone("zzz-low-cargo-load", 0, 0, routeCorridor(), "zone-low-cargo")
	lowLoad.LuggageCapacity = map[string]int{"suitcase": 4}
	lowLoad.ReservedLuggage = map[string]int{"suitcase": 0}
	highLoad := corridorDriverWithPickupZone("aaa-high-cargo-load", 0, 0, routeCorridor(), "zone-high-cargo")
	highLoad.LuggageCapacity = map[string]int{"suitcase": 4}
	highLoad.ReservedLuggage = map[string]int{"suitcase": 3}

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{highLoad, lowLoad}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected valid corridor driver, got error: %v", err)
	}
	if driverID != "zzz-low-cargo-load" {
		t.Fatalf("expected lower cargo-load driver to win tied corridor match, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_RanksLowerPetLoadAboveTiedCandidate(t *testing.T) {
	req := corridorRequest()
	req.Pet = map[string]int{"small": 1}
	lowLoad := corridorDriverWithPickupZone("zzz-low-pet-load", 0, 0, routeCorridor(), "zone-low-pet")
	lowLoad.PetLimits = map[string]int{"small": 4}
	lowLoad.ReservedPets = map[string]int{"small": 0}
	highLoad := corridorDriverWithPickupZone("aaa-high-pet-load", 0, 0, routeCorridor(), "zone-high-pet")
	highLoad.PetLimits = map[string]int{"small": 4}
	highLoad.ReservedPets = map[string]int{"small": 3}

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{highLoad, lowLoad}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected valid corridor driver, got error: %v", err)
	}
	if driverID != "zzz-low-pet-load" {
		t.Fatalf("expected lower pet-load driver to win tied corridor match, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_RanksLowerChildSeatLoadAboveTiedCandidate(t *testing.T) {
	req := corridorRequest()
	req.ChildPassengers = []struct {
		AgeYears int `json:"ageYears"`
		WeightKg int `json:"weightKg"`
	}{{AgeYears: 3, WeightKg: 15}}
	lowLoad := corridorDriverWithPickupZone("zzz-low-child-seat-load", 0, 0, routeCorridor(), "zone-low-child-seat")
	lowLoad.ChildSeatInventory = map[string]int{"forward": 4}
	lowLoad.ReservedChildSeats = map[string]int{"forward": 0}
	highLoad := corridorDriverWithPickupZone("aaa-high-child-seat-load", 0, 0, routeCorridor(), "zone-high-child-seat")
	highLoad.ChildSeatInventory = map[string]int{"forward": 4}
	highLoad.ReservedChildSeats = map[string]int{"forward": 3}

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{highLoad, lowLoad}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected valid corridor driver, got error: %v", err)
	}
	if driverID != "zzz-low-child-seat-load" {
		t.Fatalf("expected lower child-seat-load driver to win tied corridor match, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_RequiresPickupZoneIDForReservation(t *testing.T) {
	req := corridorRequest()
	missingZone := corridorDriver("nearest-valid-but-missing-zone", 0.001, 0, routeCorridor())
	withZone := corridorDriverWithPickupZone("farther-valid-with-zone", 0.02, 0, routeCorridor(), "zone-reservable")

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{missingZone, withZone}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected planner to choose reservable corridor driver, got error: %v", err)
	}
	if driverID != "farther-valid-with-zone" {
		t.Fatalf("expected driver with pickupZoneId to beat unreservable missing-zone driver, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_TrimsExcludedDriverIDsForReservationRetry(t *testing.T) {
	req := corridorRequest()
	failedReservation := corridorDriverWithPickupZone("failed-reservation-driver", 0.001, 0, routeCorridor(), "zone-failed")
	nextCandidate := corridorDriverWithPickupZone("next-reservation-candidate", 0.02, 0, routeCorridor(), "zone-next")

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{failedReservation, nextCandidate}, []string{"  failed-reservation-driver\n"}, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected planner to choose next reservable corridor driver, got error: %v", err)
	}
	if driverID != "next-reservation-candidate" {
		t.Fatalf("expected trimmed excludedDriverIds to skip failed reservation candidate, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_HonorsRequestExcludedDriverIDs(t *testing.T) {
	req := corridorRequest()
	req.ExcludedDriverIDs = []string{"  failed-reservation-driver\n"}
	failedReservation := corridorDriverWithPickupZone("failed-reservation-driver", 0.001, 0, routeCorridor(), "zone-failed")
	nextCandidate := corridorDriverWithPickupZone("next-reservation-candidate", 0.02, 0, routeCorridor(), "zone-next")

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{failedReservation, nextCandidate}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected planner to honor request-level excludedDriverIds, got error: %v", err)
	}
	if driverID != "next-reservation-candidate" {
		t.Fatalf("expected request excludedDriverIds to skip failed reservation candidate, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_RejectsBlankPickupZoneIDForReservation(t *testing.T) {
	req := corridorRequest()
	blankZone := corridorDriverWithPickupZone("nearest-blank-zone", 0.001, 0, routeCorridor(), "  \n	  ")
	withZone := corridorDriverWithPickupZone("farther-valid-with-zone", 0.02, 0, routeCorridor(), "zone-reservable")

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{blankZone, withZone}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected planner to choose reservable corridor driver, got error: %v", err)
	}
	if driverID != "farther-valid-with-zone" {
		t.Fatalf("expected blank pickupZoneId to be rejected before reservation, got %q", driverID)
	}
}

func TestZoneCapacityFromLookupTreatsMissingZoneAsFull(t *testing.T) {
	active, capacity := zoneCapacityFromLookup(nil, false)
	if active != defaultPickupZoneCapacityCars() || capacity != defaultPickupZoneCapacityCars() {
		t.Fatalf("expected missing zone lookup to be treated as full default capacity, got active=%d capacity=%d", active, capacity)
	}
}

func TestZoneCapacityFromLookupDefaultsExistingZoneCapacity(t *testing.T) {
	active, capacity := zoneCapacityFromLookup(map[string]any{"activePickups": int64(3)}, true)
	if active != 3 || capacity != defaultPickupZoneCapacityCars() {
		t.Fatalf("expected existing zone to preserve active pickups and default capacity, got active=%d capacity=%d", active, capacity)
	}
}

func TestPickBestDriverFromProfiles_DefaultsMissingPickupZoneCapacityBeforeReservation(t *testing.T) {
	req := corridorRequest()
	fullDefaultZone := corridorDriverWithPickupZone("nearest-full-default-zone", 0.001, 0, routeCorridor(), "zone-full-default")
	fullDefaultZone.PickupZoneActivePickups = 10
	fullDefaultZone.PickupZoneCapacityCars = 0
	availableZone := corridorDriverWithPickupZone("farther-available-zone", 0.02, 0, routeCorridor(), "zone-available")
	availableZone.PickupZoneActivePickups = 9
	availableZone.PickupZoneCapacityCars = 0

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{fullDefaultZone, availableZone}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected planner to choose a corridor driver with default pickup-zone capacity available, got error: %v", err)
	}
	if driverID != "farther-available-zone" {
		t.Fatalf("expected missing pickup-zone capacity to default to reservation limit and reject full zone, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_RejectsFullDropoffZoneBeforeReservation(t *testing.T) {
	req := corridorRequest()
	fullDropoff := corridorDriverWithPickupZone("nearest-full-dropoff-zone", 0.001, 0, routeCorridor(), "pickup-zone-near")
	fullDropoff.DropoffZoneID = "dropoff-zone-full"
	fullDropoff.DropoffZoneActivePickups = 2
	fullDropoff.DropoffZoneCapacityCars = 2
	availableDropoff := corridorDriverWithPickupZone("farther-available-dropoff-zone", 0.02, 0, routeCorridor(), "pickup-zone-far")
	availableDropoff.DropoffZoneID = "dropoff-zone-available"
	availableDropoff.DropoffZoneActivePickups = 1
	availableDropoff.DropoffZoneCapacityCars = 2

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{fullDropoff, availableDropoff}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected planner to choose a driver with reservable dropoff capacity, got error: %v", err)
	}
	if driverID != "farther-available-dropoff-zone" {
		t.Fatalf("expected full dropoff zone to be rejected before reservation, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_RequiresDropoffZoneIDForLegalDropoff(t *testing.T) {
	req := corridorRequest()
	missingDropoffZone := corridorDriverWithPickupZone("nearest-missing-dropoff-zone", 0.001, 0, routeCorridor(), "pickup-zone-near")
	missingDropoffZone.DropoffZoneID = ""
	withDropoffZone := corridorDriverWithPickupZone("farther-with-dropoff-zone", 0.02, 0, routeCorridor(), "pickup-zone-far")
	withDropoffZone.DropoffZoneID = "dropoff-zone-available"
	withDropoffZone.DropoffZoneActivePickups = 1
	withDropoffZone.DropoffZoneCapacityCars = 2

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{missingDropoffZone, withDropoffZone}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected planner to choose a driver with a reservable dropoff zone, got error: %v", err)
	}
	if driverID != "farther-with-dropoff-zone" {
		t.Fatalf("expected planner to require a reservable dropoffZoneId for legal dropoff, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_RequiresDropoffZoneWhenDestinationDriveGeoPresent(t *testing.T) {
	req := corridorRequest()
	req.DestinationDriveGeo = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	missingDropoffZone := corridorDriverWithPickupZone("nearest-missing-dropoff-zone", 0.001, 0, routeCorridor(), "pickup-zone-near")
	missingDropoffZone.DropoffZoneID = ""
	withDropoffZone := corridorDriverWithPickupZone("farther-with-dropoff-zone", 0.02, 0, routeCorridor(), "pickup-zone-far")
	withDropoffZone.DropoffZoneID = "dropoff-zone-available"
	withDropoffZone.DropoffZoneActivePickups = 1
	withDropoffZone.DropoffZoneCapacityCars = 2

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{missingDropoffZone, withDropoffZone}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected planner to choose a driver with a reservable dropoff zone, got error: %v", err)
	}
	if driverID != "farther-with-dropoff-zone" {
		t.Fatalf("expected destinationDriveGeo requests to require planner-provided dropoffZoneId, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_RejectsFullPickupZoneBeforeReservation(t *testing.T) {
	req := corridorRequest()
	fullZone := corridorDriverWithPickupZone("nearest-full-zone", 0.001, 0, routeCorridor(), "zone-full")
	fullZone.PickupZoneActivePickups = 2
	fullZone.PickupZoneCapacityCars = 2
	availableZone := corridorDriverWithPickupZone("farther-available-zone", 0.02, 0, routeCorridor(), "zone-available")
	availableZone.PickupZoneActivePickups = 1
	availableZone.PickupZoneCapacityCars = 2

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{fullZone, availableZone}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected planner to choose a corridor driver with reservable curb capacity, got error: %v", err)
	}
	if driverID != "farther-available-zone" {
		t.Fatalf("expected planner to reject full pickup zone before reservation, got %q", driverID)
	}
}

func TestPickBestDriverProfileFromProfiles_RequiresPickupZoneIDForProductionSelection(t *testing.T) {
	req := corridorRequest()
	missingZone := corridorDriver("nearest-valid-but-missing-zone", 0.001, 0, routeCorridor())
	withZone := corridorDriverWithPickupZone("farther-valid-with-zone", 0.02, 0, routeCorridor(), "zone-reservable")

	driver, _, err := pickBestDriverProfileFromProfiles(req, []DriverProfile{missingZone, withZone}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected planner to choose reservable corridor driver, got error: %v", err)
	}
	if driver.ID != "farther-valid-with-zone" {
		t.Fatalf("expected production profile selector to filter missing pickupZoneId, got %q", driver.ID)
	}
}

func TestComputeDriverScore_RejectsExcessiveRouteDetour(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("excessive-detour", 0, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 3, Longitude: 0},
		{Latitude: 3, Longitude: 1},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected route with excessive insertion detour to be rejected")
	}
}

func TestComputeDriverScore_RejectsExcessiveDetourWhenLaterOriginProjectionIsNearest(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "1")
	req := corridorRequest()
	req.OriWalkIso = GeoJSONGeometry{}
	req.OriginWalkIso = GeoJSONGeometry{}
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("excessive-detour-later-origin", 0, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 3, Longitude: -0.10},
		{Latitude: 3, Longitude: 1.00},
		{Latitude: 0, Longitude: 1.00},
		{Latitude: 0.004, Longitude: 0.00},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected excessive detour to be measured from the first valid origin→destination pass, not skipped by a later nearest origin projection")
	}
}

func TestComputeDriverScore_RejectsExcessiveDetourBeforeRouteContinuesNearOrigin(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "1")
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0.004, Longitude: 0}
	req.Destination = GeoPoint{Latitude: 0.004, Longitude: 1}
	req.OriWalkIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	driver := corridorDriver("excessive-first-pass-detour", 0, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 2, Longitude: 0.50},
		{Latitude: 0, Longitude: 1},
		{Latitude: 0.004, Longitude: 0},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected excessive detour on first valid origin→destination pass to be rejected even when route later continues near origin")
	}
}

func TestComputeDriverScore_DoesNotRejectSparseDirectPolylineAsDetour(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "1")
	allowLongPickupETA(t)
	req := corridorRequest()
	driver := corridorDriver("sparse-direct-route", 0, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0.10},
		{Latitude: 0, Longitude: 0.90},
		{Latitude: 0, Longitude: 1.10},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected sparse direct polyline to use interpolated route positions instead of vertex overhang detour")
	}
}

func TestComputeDriverScore_RejectsRoutePickupEtaAboveThreshold(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_PICKUP_ETA_SECONDS", "300")
	req := corridorRequest()
	driver := corridorDriver("late-route-pickup", 0, 0.02, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.02},
		{Latitude: 2, Longitude: 0.02},
		{Latitude: 2, Longitude: 0},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected route pickup ETA above threshold to be rejected")
	}
}

func TestComputeDriverScore_RejectsRoutePickupEtaAboveDefaultThreshold(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("late-by-default", 0, -0.21, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.21},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected default pickup ETA threshold to reject a route reaching pickup after more than 30 minutes")
	}
}

func TestComputeDriverScore_RejectsPickupBeforeRiderCanWalkToRoutePickup(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "1000")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	driver := corridorDriver("pickup-too-soon-for-rider-walk", 0.006, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.006, Longitude: 0},
		{Latitude: 0.006, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected route pickup to be rejected when driver reaches pickup before rider can walk to the snapped route point")
	}
}

func TestComputeDriverScore_RejectsOriginDriveEntryTooLateForRiderWalk(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "1000")
	req := corridorRequest()
	req.OriDriveIso = rectPolygon(0.0055, -0.0005, 0.0065, 0.0005)
	driver := corridorDriver("origin-drive-entry-too-late", 0.006, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.006, Longitude: -0.10},
		{Latitude: 0.006, Longitude: 0},
		{Latitude: 0.006, Longitude: 1},
	})
	driver.RouteETAProfileSeconds = []int{0, 600, 1500}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected route to reject when originDriveGeo entry leaves too little time for rider to walk to pickup")
	}
}

func TestComputeDriverScore_RejectsRouteSnapOutsideWalkThreshold(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "500")
	req := corridorRequest()
	req.OriWalkIso = GeoJSONGeometry{}
	req.OriginWalkIso = GeoJSONGeometry{}
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	req.DestWalkIso = GeoJSONGeometry{}
	req.DestinationWalkIso = GeoJSONGeometry{}
	driver := corridorDriver("too-far-to-walk", 0, 0.01, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.01},
		{Latitude: 0, Longitude: 1.01},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected route snap outside rider walk threshold to be rejected")
	}
}

func TestComputeDriverScore_RejectsRouteSnapOutsideRequestWalkRadius(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "2000")
	req := corridorRequest()
	req.WalkRadiusM = 500
	req.OriWalkIso = rectPolygon(-0.02, -0.02, 0.02, 0.02)
	req.OriginWalkIso = GeoJSONGeometry{}
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	req.DestWalkIso = rectPolygon(-0.02, 0.98, 0.02, 1.02)
	req.DestinationWalkIso = GeoJSONGeometry{}
	driver := corridorDriver("outside-request-walk-radius", 0, 0.01, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.01},
		{Latitude: 0, Longitude: 1.01},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected request walkRadiusM to reject route snap even when env max and broad walk polygons allow it")
	}
}

func TestPickBestDriverFromProfiles_RetriesNextCandidateWhenReservationFails(t *testing.T) {
	req := corridorRequest()
	drivers := []DriverProfile{
		corridorDriverWithPickupZone("best-but-reservation-fails", 0.01, 0, routeCorridor(), "zone-first"),
		corridorDriverWithPickupZone("second-reservation-succeeds", 0.02, 0, routeCorridor(), "zone-second"),
	}

	attempted := []string{}
	driverID, _, err := pickBestDriverFromProfilesWithReservation(req, drivers, nil, defaultScoreWeights(), func(driver DriverProfile) bool {
		attempted = append(attempted, driver.ID)
		return driver.ID != "best-but-reservation-fails"
	})
	if err != nil {
		t.Fatalf("expected retry to choose second candidate, got error: %v", err)
	}
	if driverID != "second-reservation-succeeds" {
		t.Fatalf("expected second candidate after reservation failure, got %q", driverID)
	}
	if len(attempted) != 2 || attempted[0] != "best-but-reservation-fails" || attempted[1] != "second-reservation-succeeds" {
		t.Fatalf("expected reservation attempts in score order, got %#v", attempted)
	}
}

func TestBuildSingleHopJourneyAddsDirectRideTimeWhenRouteMissing(t *testing.T) {
	req := corridorRequest()
	req.Destination = GeoPoint{Latitude: 0, Longitude: 0.01}
	driver := corridorDriver("driver-without-route", 0, 0, routeCorridor())

	pickupEtaSec := 30
	journey := buildSingleHopJourney(req, driver, pickupEtaSec)
	expectedRideSec := int(haversineKm(0, 0, 0, 0.01) / 40.0 * 3600)
	expectedTotalSec := pickupEtaSec + expectedRideSec
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	if journey.Legs[0].EstimatedTimeSeconds != expectedTotalSec || journey.TotalEstimatedTimeSeconds != expectedTotalSec {
		t.Fatalf("expected pickup plus direct ride ETA %d seconds, got leg=%d total=%d", expectedTotalSec, journey.Legs[0].EstimatedTimeSeconds, journey.TotalEstimatedTimeSeconds)
	}
}

func TestBuildSingleHopJourneyAddsRouteRideTimeWhenEtaProfileMissing(t *testing.T) {
	req := corridorRequest()
	req.Destination = GeoPoint{Latitude: 0, Longitude: 0.01}
	req.OriWalkIso = rectPolygon(-0.001, -0.0001, 0.001, 0.0001)
	req.DestWalkIso = rectPolygon(-0.001, 0.009, 0.001, 0.011)
	req.OriDriveIso = GeoJSONGeometry{}
	driver := corridorDriver("driver-with-route-no-eta-profile", 0, -0.001, rectPolygon(-0.001, -0.002, 0.001, 0.011))
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.001},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.01},
	})

	pickupEtaSec := 30
	journey := buildSingleHopJourney(req, driver, pickupEtaSec)
	expectedRideSec := int(haversineKm(0, 0, 0, 0.01) / 40.0 * 3600)
	expectedTotalSec := pickupEtaSec + expectedRideSec
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	if journey.Legs[0].EstimatedTimeSeconds != expectedTotalSec || journey.TotalEstimatedTimeSeconds != expectedTotalSec {
		t.Fatalf("expected pickup plus route ride ETA %d seconds, got leg=%d total=%d", expectedTotalSec, journey.Legs[0].EstimatedTimeSeconds, journey.TotalEstimatedTimeSeconds)
	}
}

func TestBuildSingleHopJourneyFallsBackWhenRouteEtaProfileHasNoProgress(t *testing.T) {
	req := corridorRequest()
	req.Destination = GeoPoint{Latitude: 0, Longitude: 0.01}
	req.OriWalkIso = rectPolygon(-0.001, -0.0001, 0.001, 0.0001)
	req.DestWalkIso = rectPolygon(-0.001, 0.009, 0.001, 0.011)
	req.OriDriveIso = GeoJSONGeometry{}
	driver := corridorDriver("driver-with-zero-route-eta-profile", 0, -0.001, rectPolygon(-0.001, -0.002, 0.001, 0.011))
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.001},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.01},
	})
	driver.RouteETAProfileSeconds = []int{0, 0, 0}

	pickupEtaSec := 30
	journey := buildSingleHopJourney(req, driver, pickupEtaSec)
	expectedRideSec := int(haversineKm(0, 0, 0, 0.01) / 40.0 * 3600)
	expectedTotalSec := pickupEtaSec + expectedRideSec
	if journey.Legs[0].EstimatedTimeSeconds != expectedTotalSec || journey.TotalEstimatedTimeSeconds != expectedTotalSec {
		t.Fatalf("expected zero-progress route ETA profile to fall back to route-distance ETA %d, got leg=%d total=%d", expectedTotalSec, journey.Legs[0].EstimatedTimeSeconds, journey.TotalEstimatedTimeSeconds)
	}
}

func TestBuildSingleHopJourneyUsesRouteEtaProfileForTotalLegEta(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("driver-with-route-eta-profile", 0, -0.10, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})
	driver.RouteETAProfileSeconds = []int{0, 90, 690}

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	if journey.Legs[0].EstimatedTimeSeconds != 690 || journey.TotalEstimatedTimeSeconds != 690 {
		t.Fatalf("expected route ETA profile total 690 seconds, got leg=%d total=%d", journey.Legs[0].EstimatedTimeSeconds, journey.TotalEstimatedTimeSeconds)
	}
}

func TestDriverPickupEtaUsesOriginDriveGeoWhenWalkZoneMissing(t *testing.T) {
	req := corridorRequest()
	req.OriWalkIso = GeoJSONGeometry{}
	req.OriginWalkIso = GeoJSONGeometry{}
	req.OriDriveIso = rectPolygon(-0.01, 0.19, 0.01, 0.21)
	req.OriginDriveGeo = GeoJSONGeometry{}
	req.DestWalkIso = GeoJSONGeometry{}
	req.DestinationWalkIso = GeoJSONGeometry{}
	req.DestinationDriveGeo = rectPolygon(-0.01, 0.79, 0.01, 0.81)
	driver := corridorDriver("driver-drive-geo-pickup-eta", 0, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.2},
		{Latitude: 0, Longitude: 0.8},
		{Latitude: 0, Longitude: 1},
	})
	driver.RouteETAProfileSeconds = []int{0, 200, 800, 1000}

	got := driverPickupETASeconds(req, driver, 0)
	if got != 200 {
		t.Fatalf("expected pickup ETA to use origin drive geofence fallback when walk zone is missing, got %d", got)
	}
}

func TestBuildSingleHopJourneyIncludesPickupZoneID(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("driver-with-zone", 0.01, 0, routeCorridor())
	driver.PickupZoneID = "zone-123"

	journey := buildSingleHopJourney(req, driver, 90)

	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	if journey.Legs[0].PickupZoneID != "zone-123" {
		t.Fatalf("expected leg pickupZoneId to preserve driver zone, got %q", journey.Legs[0].PickupZoneID)
	}

	payload, err := json.Marshal(journey)
	if err != nil {
		t.Fatalf("marshal journey: %v", err)
	}
	if !json.Valid(payload) || !strings.Contains(string(payload), `"pickupZoneId":"zone-123"`) {
		t.Fatalf("expected JSON payload to expose pickupZoneId, got %s", payload)
	}
}

func TestBuildSingleHopJourneyUsesBackendSelectedRoutePickupAndDropoff(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("driver-with-route-points", 0.01, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.02},
		{Latitude: 0, Longitude: 0.50},
		{Latitude: 0, Longitude: 0.98},
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	leg := journey.Legs[0]
	if leg.Pickup == req.Origin || leg.Dropoff == req.Destination {
		t.Fatalf("expected backend-selected route pickup/dropoff, got pickup=%#v dropoff=%#v", leg.Pickup, leg.Dropoff)
	}
	if math.Abs(leg.Pickup.Longitude-0.02) > 0.000001 || math.Abs(leg.Dropoff.Longitude-0.98) > 0.000001 {
		t.Fatalf("expected pickup/dropoff snapped to route points, got pickup=%#v dropoff=%#v", leg.Pickup, leg.Dropoff)
	}
}

func TestBuildSingleHopJourneySkipsUnwalkableEarlyPickupProjection(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(-0.0001, -0.0001, 0.0001, 0.0001)
	req.DestWalkIso = rectPolygon(-0.0001, 0.9999, 0.0001, 1.0001)
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("journey-later-near-origin-route", 0.05, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.05, Longitude: -0.10}, // outside walk radius; must not be selected for display
		{Latitude: 0.05, Longitude: 0.50},
		{Latitude: 0.002, Longitude: 0}, // first walk-feasible pickup
		{Latitude: 0, Longitude: 1},
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	leg := journey.Legs[0]
	if math.Abs(leg.Pickup.Latitude-0.002) > 0.000001 || math.Abs(leg.Pickup.Longitude) > 0.000001 {
		t.Fatalf("expected backend-selected pickup to skip unwalkable early projection, got %#v", leg.Pickup)
	}
}

func TestBuildSingleHopJourneyUsesDriveGeosForSelectedPointsWhenWalkZonesMissing(t *testing.T) {
	req := corridorRequest()
	req.OriWalkIso = GeoJSONGeometry{}
	req.OriginWalkIso = GeoJSONGeometry{}
	req.OriDriveIso = rectPolygon(-0.01, 0.19, 0.01, 0.21)
	req.OriginDriveGeo = GeoJSONGeometry{}
	req.DestWalkIso = GeoJSONGeometry{}
	req.DestinationWalkIso = GeoJSONGeometry{}
	req.DestinationDriveGeo = rectPolygon(-0.01, 0.79, 0.01, 0.81)
	driver := corridorDriver("driver-drive-geo-points", 0, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.2},
		{Latitude: 0, Longitude: 0.8},
		{Latitude: 0, Longitude: 1},
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	leg := journey.Legs[0]
	assertGeoPointNear(t, leg.Pickup, GeoPoint{Latitude: 0, Longitude: 0.2})
	assertGeoPointNear(t, leg.Dropoff, GeoPoint{Latitude: 0, Longitude: 0.8})
}

func TestBuildSingleHopJourneyUsesOriginDriveGeoForPickupWhenWalkZoneIsBroad(t *testing.T) {
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0, Longitude: 0.05}
	req.OriWalkIso = rectPolygon(-0.01, -0.01, 0.01, 0.11)
	req.OriDriveIso = rectPolygon(-0.01, 0.095, 0.01, 0.105)
	driver := corridorDriver("driver-origin-drive-pickup", 0, -0.10, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.10},
		{Latitude: 0, Longitude: 1},
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	assertGeoPointNear(t, journey.Legs[0].Pickup, GeoPoint{Latitude: 0, Longitude: 0.10})
}

func TestBuildSingleHopJourneyUsesDestinationDriveGeoForDropoffWhenWalkZoneIsBroad(t *testing.T) {
	req := corridorRequest()
	req.Destination = GeoPoint{Latitude: 0, Longitude: 0.95}
	req.DestWalkIso = rectPolygon(-0.01, 0.90, 0.01, 1.01)
	req.DestinationDriveGeo = rectPolygon(-0.01, 0.995, 0.01, 1.005)
	driver := corridorDriver("driver-destination-drive-dropoff", 0, -0.10, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	assertGeoPointNear(t, journey.Legs[0].Dropoff, GeoPoint{Latitude: 0, Longitude: 1})
}

func TestComputeDriverScore_RejectsDestinationDriveGeoOutsideWalkZone(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.Destination = GeoPoint{Latitude: 0, Longitude: 0.95}
	req.DestWalkIso = rectPolygon(-0.01, 0.90, 0.01, 0.96)
	req.DestinationDriveGeo = rectPolygon(-0.01, 0.995, 0.01, 1.005)
	driver := corridorDriver("destination-drive-outside-walk", 0, -0.10, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected destinationDriveGeo outside destination walk zone to be rejected")
	}
}

func TestComputeDriverScore_RejectsBufferDestinationDriveGeoOutsideWalkZone(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.Destination = GeoPoint{Latitude: 0, Longitude: 0.95}
	req.DestWalkIso = rectPolygon(-0.01, 0.90, 0.01, 0.96)
	req.DestinationDriveGeo = rectPolygon(-0.01, 0.995, 0.01, 1.005)
	driver := corridorDriver("buffer-destination-drive-outside-walk", 0, -0.10, routeCorridor())

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected buffer-only candidate with disjoint destination walk/drive zones to be rejected")
	}
}

func TestBuildSingleHopJourneyPrefersRoutePointsInsideWalkZones(t *testing.T) {
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(-0.01, 0.010, 0.01, 0.020)
	req.DestWalkIso = rectPolygon(-0.01, 0.980, 0.01, 0.990)
	driver := corridorDriver("driver-with-walk-zone-points", 0.01, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.001},
		{Latitude: 0, Longitude: 0.015},
		{Latitude: 0, Longitude: 0.985},
		{Latitude: 0, Longitude: 0.999},
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	leg := journey.Legs[0]
	if math.Abs(leg.Pickup.Longitude-0.015) > 0.000001 || math.Abs(leg.Dropoff.Longitude-0.985) > 0.000001 {
		t.Fatalf("expected pickup/dropoff to prefer route points inside walk zones, got pickup=%#v dropoff=%#v", leg.Pickup, leg.Dropoff)
	}
}

func TestBuildSingleHopJourneyInterpolatesRoutePointsInsideWalkZones(t *testing.T) {
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	driver := corridorDriver("driver-with-crossing-segments", 0.01, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0.10},
		{Latitude: 0, Longitude: 0.90},
		{Latitude: 0, Longitude: 1.10},
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	leg := journey.Legs[0]
	if math.Abs(leg.Pickup.Longitude) > 0.000001 || math.Abs(leg.Dropoff.Longitude-1) > 0.000001 {
		t.Fatalf("expected pickup/dropoff interpolated inside walk zones, got pickup=%#v dropoff=%#v", leg.Pickup, leg.Dropoff)
	}
}

func TestBuildSingleHopJourneyUsesWalkZoneBoundaryWhenNearestProjectionIsOutside(t *testing.T) {
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0.05, Longitude: 0.05}
	req.OriWalkIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	driver := corridorDriver("driver-crosses-origin-zone-away-from-raw-origin", 0.01, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0.10},
		{Latitude: 0, Longitude: 0.90},
		{Latitude: 0, Longitude: 1.10},
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	leg := journey.Legs[0]
	if !pointInGeoJSONPolygon(leg.Pickup, req.OriWalkIso) {
		t.Fatalf("expected pickup to use a route/walk-zone boundary point, got pickup=%#v", leg.Pickup)
	}
	if math.Abs(leg.Pickup.Longitude+0.01) > 0.000001 || math.Abs(leg.Dropoff.Longitude-1) > 0.000001 {
		t.Fatalf("expected first legal boundary pickup and interpolated dropoff, got pickup=%#v dropoff=%#v", leg.Pickup, leg.Dropoff)
	}
}

func TestBuildSingleHopJourneyUsesWalkZoneOrderForRouteThatContinuesNearOrigin(t *testing.T) {
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0.004, Longitude: 0}
	req.Destination = GeoPoint{Latitude: 0.004, Longitude: 1}
	req.OriWalkIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	driver := corridorDriver("driver-continues-near-origin", 0.01, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 1.10},
		{Latitude: 0, Longitude: 0.005},
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	leg := journey.Legs[0]
	if math.Abs(leg.Pickup.Latitude) > 0.000001 || math.Abs(leg.Pickup.Longitude) > 0.000001 ||
		math.Abs(leg.Dropoff.Latitude) > 0.000001 || math.Abs(leg.Dropoff.Longitude-1) > 0.000001 {
		t.Fatalf("expected pickup/dropoff selected from first origin→destination route pass, got pickup=%#v dropoff=%#v", leg.Pickup, leg.Dropoff)
	}
}

func TestBuildSingleHopJourneyUsesFirstValidPassEvenWhenLaterPassIsCloser(t *testing.T) {
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0.004, Longitude: 0}
	req.Destination = GeoPoint{Latitude: 0.004, Longitude: 1}
	req.OriWalkIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	driver := corridorDriver("driver-has-later-closer-valid-pass", 0.01, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 1.10},
		{Latitude: 0.004, Longitude: 0.00},
		{Latitude: 0.004, Longitude: 1.00},
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	leg := journey.Legs[0]
	assertGeoPointNear(t, leg.Pickup, GeoPoint{Latitude: 0, Longitude: 0})
	assertGeoPointNear(t, leg.Dropoff, GeoPoint{Latitude: 0, Longitude: 1})
}

func TestBuildSingleHopJourneyUsesLaterDropoffProjectionWhenDestinationWalkZoneMissing(t *testing.T) {
	req := corridorRequest()
	req.Destination = GeoPoint{Latitude: 0.004, Longitude: 1}
	req.DestWalkIso = GeoJSONGeometry{}
	req.DestinationWalkIso = GeoJSONGeometry{}
	driver := corridorDriver("driver-later-destination-projection", 0.01, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 1.00},
		{Latitude: 0, Longitude: 0.00},
		{Latitude: 0, Longitude: 1.10},
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	leg := journey.Legs[0]
	assertGeoPointNear(t, leg.Pickup, GeoPoint{Latitude: 0, Longitude: 0})
	assertGeoPointNear(t, leg.Dropoff, GeoPoint{Latitude: 0, Longitude: 1.00})
}

func TestBuildSingleHopJourneyUsesEarlierPickupProjectionWhenOriginWalkZoneMissing(t *testing.T) {
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0.004, Longitude: 0}
	req.OriWalkIso = GeoJSONGeometry{}
	req.OriginWalkIso = GeoJSONGeometry{}
	driver := corridorDriver("driver-earlier-origin-projection", 0.01, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 1.00},
		{Latitude: 0.004, Longitude: 0.00},
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	leg := journey.Legs[0]
	assertGeoPointNear(t, leg.Pickup, GeoPoint{Latitude: 0, Longitude: 0})
	assertGeoPointNear(t, leg.Dropoff, GeoPoint{Latitude: 0, Longitude: 1.00})
}

func TestCalculateJourneyScoreDefaultsMissingCongestionToNeutral(t *testing.T) {
	got := calculateJourneyScore(600, 2, 0)
	want := calculateJourneyScore(600, 2, 1)
	if got != want {
		t.Fatalf("expected missing congestion factor to be neutral, got %f want %f", got, want)
	}
}

func TestScore2HopJourneyUsesRouteAwareResponseEta(t *testing.T) {
	req := corridorRequest()
	transfer := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.5}, TransferTimeSeconds: 7, CongestionFactor: 1}
	driver1 := corridorDriver("driver-leg-1-score-route-eta", 0, -0.10, routeCorridor())
	driver1.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.5},
	})
	driver1.RouteETAProfileSeconds = []int{0, 30, 330}
	driver2 := corridorDriver("driver-leg-2-score-route-eta", 0, 0.5, routeCorridor())
	driver2.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.5},
		{Latitude: 0, Longitude: 1},
	})
	driver2.RouteETAProfileSeconds = []int{0, 600}

	got := score2HopJourney(req, transfer, driver1, 30, driver2, 40)
	want := calculateJourneyScore(977, 2, 1)
	stalePickupOnlyScore := calculateJourneyScore(77, 2, 1)
	if got != want {
		t.Fatalf("expected score to use route-aware total ETA, got %f want %f", got, want)
	}
	if got == stalePickupOnlyScore {
		t.Fatalf("expected score not to use stale pickup-only total")
	}
}

func TestBuild2HopJourneyAddsDirectRideEtaWhenRoutesMissing(t *testing.T) {
	req := corridorRequest()
	transfer := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.5}, TransferTimeSeconds: 7}
	driver1 := corridorDriver("driver-leg-1-no-route", 0.01, 0, routeCorridor())
	driver2 := corridorDriver("driver-leg-2-no-route", 0.01, 0.5, routeCorridor())

	journey := build2HopJourney(req, transfer, driver1, 30, driver2, 40)

	expectedLeg1 := 30 + singleHopDirectRideETASeconds(buildLegRequest(req, req.Origin, transfer.Location))
	expectedLeg2 := 40 + singleHopDirectRideETASeconds(buildLegRequest(req, transfer.Location, req.Destination))
	expectedTotal := expectedLeg1 + expectedLeg2 + transfer.TransferTimeSeconds
	if len(journey.Legs) != 2 {
		t.Fatalf("expected two legs, got %d", len(journey.Legs))
	}
	if journey.Legs[0].EstimatedTimeSeconds != expectedLeg1 || journey.Legs[1].EstimatedTimeSeconds != expectedLeg2 || journey.TotalEstimatedTimeSeconds != expectedTotal {
		t.Fatalf("expected direct fallback ETAs %d/%d and total %d, got legs=%#v total=%d", expectedLeg1, expectedLeg2, expectedTotal, journey.Legs, journey.TotalEstimatedTimeSeconds)
	}
}

func TestBuild2HopJourneyIncludesPickupZoneIDs(t *testing.T) {
	req := corridorRequest()
	transfer := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.5}, TransferTimeSeconds: 7}
	driver1 := corridorDriver("driver-leg-1", 0.01, 0, routeCorridor())
	driver1.PickupZoneID = "zone-leg-1"
	driver2 := corridorDriver("driver-leg-2", 0.01, 0.5, routeCorridor())
	driver2.PickupZoneID = "zone-leg-2"

	journey := build2HopJourney(req, transfer, driver1, 30, driver2, 40)

	if len(journey.Legs) != 2 {
		t.Fatalf("expected two legs, got %d", len(journey.Legs))
	}
	if journey.Legs[0].PickupZoneID != "zone-leg-1" || journey.Legs[1].PickupZoneID != "zone-leg-2" {
		t.Fatalf("expected both pickupZoneIds to be preserved, got %#v", journey.Legs)
	}
	expectedLeg1 := 30 + singleHopDirectRideETASeconds(buildLegRequest(req, req.Origin, transfer.Location))
	expectedLeg2 := 40 + singleHopDirectRideETASeconds(buildLegRequest(req, transfer.Location, req.Destination))
	expectedTotal := expectedLeg1 + expectedLeg2 + transfer.TransferTimeSeconds
	if journey.TotalEstimatedTimeSeconds != expectedTotal {
		t.Fatalf("expected total time with direct fallback ride ETA, got %d want %d", journey.TotalEstimatedTimeSeconds, expectedTotal)
	}
}

func TestBuild2HopJourneyUsesRouteRideEtaPerLeg(t *testing.T) {
	req := corridorRequest()
	transfer := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.5}, TransferTimeSeconds: 7}
	driver1 := corridorDriver("driver-leg-1-route-eta", 0, -0.10, routeCorridor())
	driver1.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.5},
	})
	driver1.RouteETAProfileSeconds = []int{0, 30, 330}
	driver2 := corridorDriver("driver-leg-2-route-eta", 0, 0.5, routeCorridor())
	driver2.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.5},
		{Latitude: 0, Longitude: 1},
	})
	driver2.RouteETAProfileSeconds = []int{0, 600}

	journey := build2HopJourney(req, transfer, driver1, 30, driver2, 40)

	if len(journey.Legs) != 2 {
		t.Fatalf("expected two legs, got %d", len(journey.Legs))
	}
	if journey.Legs[0].EstimatedTimeSeconds != 330 || journey.Legs[1].EstimatedTimeSeconds != 640 || journey.TotalEstimatedTimeSeconds != 977 {
		t.Fatalf("expected per-leg route ETAs 330/640 and total 977, got legs=%#v total=%d", journey.Legs, journey.TotalEstimatedTimeSeconds)
	}
}

func TestBuild2HopJourneyTrimsRoutePolylineBeforeSelectingLegPointsAndEta(t *testing.T) {
	req := corridorRequest()
	transfer := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.5}, TransferTimeSeconds: 7}
	driver1 := corridorDriver("driver-leg-1-whitespace-route", 0, -0.10, routeCorridor())
	driver1.RoutePolyline = "  " + encodePolyline([]GeoPoint{
		{Latitude: 0.002, Longitude: 0},
		{Latitude: 0.002, Longitude: 0.498},
	}) + "\n"
	driver1.RouteETAProfileSeconds = []int{30, 330}
	driver2 := corridorDriver("driver-leg-2-route-eta", 0, 0.5, routeCorridor())
	driver2.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.5},
		{Latitude: 0, Longitude: 1},
	})
	driver2.RouteETAProfileSeconds = []int{0, 600}

	journey := build2HopJourney(req, transfer, driver1, 30, driver2, 40)

	if len(journey.Legs) != 2 {
		t.Fatalf("expected two legs, got %d", len(journey.Legs))
	}
	assertGeoPointNear(t, journey.Legs[0].Pickup, GeoPoint{Latitude: 0.002, Longitude: 0})
	assertGeoPointNear(t, journey.Legs[0].Dropoff, GeoPoint{Latitude: 0.002, Longitude: 0.498})
	if journey.Legs[0].EstimatedTimeSeconds != 330 {
		t.Fatalf("expected trimmed leg routePolyline to use route ETA profile, got %d", journey.Legs[0].EstimatedTimeSeconds)
	}
}

func TestBuild2HopJourneyUsesBackendSelectedRoutePickupAndDropoffPerLeg(t *testing.T) {
	req := corridorRequest()
	transfer := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.5}, TransferTimeSeconds: 7}
	driver1 := corridorDriver("driver-leg-1-route-points", 0.01, 0, routeCorridor())
	driver1.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.002},
		{Latitude: 0, Longitude: 0.498},
	})
	driver2 := corridorDriver("driver-leg-2-route-points", 0.01, 0.5, routeCorridor())
	driver2.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.502},
		{Latitude: 0, Longitude: 0.998},
	})

	journey := build2HopJourney(req, transfer, driver1, 30, driver2, 40)

	if len(journey.Legs) != 2 {
		t.Fatalf("expected two legs, got %d", len(journey.Legs))
	}
	assertGeoPointNear(t, journey.Legs[0].Pickup, GeoPoint{Latitude: 0, Longitude: 0.002})
	assertGeoPointNear(t, journey.Legs[0].Dropoff, GeoPoint{Latitude: 0, Longitude: 0.498})
	assertGeoPointNear(t, journey.Legs[1].Pickup, GeoPoint{Latitude: 0, Longitude: 0.502})
	assertGeoPointNear(t, journey.Legs[1].Dropoff, GeoPoint{Latitude: 0, Longitude: 0.998})
}

func TestScore3HopJourneyDefaultsEachMissingTransferCongestionToNeutral(t *testing.T) {
	req := corridorRequest()
	transfer1Missing := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.33}, TransferTimeSeconds: 7, CongestionFactor: 0}
	transfer2Neutral := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.66}, TransferTimeSeconds: 8, CongestionFactor: 1}
	transfer1Neutral := transfer1Missing
	transfer1Neutral.CongestionFactor = 1
	driver1 := corridorDriver("driver-leg-1-missing-congestion", 0, 0, routeCorridor())
	driver2 := corridorDriver("driver-leg-2-missing-congestion", 0, 0.33, routeCorridor())
	driver3 := corridorDriver("driver-leg-3-missing-congestion", 0, 0.66, routeCorridor())

	got := score3HopJourney(req, transfer1Missing, transfer2Neutral, driver1, 30, driver2, 40, driver3, 50)
	want := score3HopJourney(req, transfer1Neutral, transfer2Neutral, driver1, 30, driver2, 40, driver3, 50)
	if got != want {
		t.Fatalf("expected missing per-transfer congestion to be neutral before averaging, got %f want %f", got, want)
	}
}

func TestScore3HopJourneyUsesRouteAwareResponseEta(t *testing.T) {
	req := corridorRequest()
	transfer1 := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.33}, TransferTimeSeconds: 7, CongestionFactor: 1}
	transfer2 := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.66}, TransferTimeSeconds: 8, CongestionFactor: 1}
	driver1 := corridorDriver("driver-leg-1-score-3hop-route-eta", 0, -0.10, routeCorridor())
	driver1.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.33},
	})
	driver1.RouteETAProfileSeconds = []int{0, 30, 330}
	driver2 := corridorDriver("driver-leg-2-score-3hop-route-eta", 0, 0.33, routeCorridor())
	driver2.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.33},
		{Latitude: 0, Longitude: 0.66},
	})
	driver2.RouteETAProfileSeconds = []int{0, 360}
	driver3 := corridorDriver("driver-leg-3-score-3hop-route-eta", 0, 0.66, routeCorridor())
	driver3.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.66},
		{Latitude: 0, Longitude: 1},
	})
	driver3.RouteETAProfileSeconds = []int{0, 420}

	got := score3HopJourney(req, transfer1, transfer2, driver1, 30, driver2, 40, driver3, 50)
	want := calculateJourneyScore(1215, 3, 1)
	stalePickupOnlyScore := calculateJourneyScore(135, 3, 1)
	if got != want {
		t.Fatalf("expected score to use route-aware 3-hop total ETA, got %f want %f", got, want)
	}
	if got == stalePickupOnlyScore {
		t.Fatalf("expected score not to use stale pickup-only 3-hop total")
	}
}

func TestBuild3HopJourneyUsesRouteRideEtaPerLeg(t *testing.T) {
	req := corridorRequest()
	transfer1 := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.33}, TransferTimeSeconds: 7}
	transfer2 := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.66}, TransferTimeSeconds: 8}
	driver1 := corridorDriver("driver-leg-1-route-eta", 0, -0.10, routeCorridor())
	driver1.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.33},
	})
	driver1.RouteETAProfileSeconds = []int{0, 30, 330}
	driver2 := corridorDriver("driver-leg-2-route-eta", 0, 0.33, routeCorridor())
	driver2.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.33},
		{Latitude: 0, Longitude: 0.66},
	})
	driver2.RouteETAProfileSeconds = []int{0, 360}
	driver3 := corridorDriver("driver-leg-3-route-eta", 0, 0.66, routeCorridor())
	driver3.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.66},
		{Latitude: 0, Longitude: 1},
	})
	driver3.RouteETAProfileSeconds = []int{0, 420}

	journey := build3HopJourney(req, transfer1, transfer2, driver1, 30, driver2, 40, driver3, 50)

	if len(journey.Legs) != 3 {
		t.Fatalf("expected three legs, got %d", len(journey.Legs))
	}
	if journey.Legs[0].EstimatedTimeSeconds != 330 || journey.Legs[1].EstimatedTimeSeconds != 400 || journey.Legs[2].EstimatedTimeSeconds != 470 || journey.TotalEstimatedTimeSeconds != 1215 {
		t.Fatalf("expected per-leg route ETAs 330/400/470 and total 1215, got legs=%#v total=%d", journey.Legs, journey.TotalEstimatedTimeSeconds)
	}
}

func TestBuild3HopJourneyUsesBackendSelectedRoutePickupAndDropoffPerLeg(t *testing.T) {
	req := corridorRequest()
	transfer1 := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.33}, TransferTimeSeconds: 7}
	transfer2 := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.66}, TransferTimeSeconds: 8}
	driver1 := corridorDriver("driver-leg-1-route-points", 0.01, 0, routeCorridor())
	driver1.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.002},
		{Latitude: 0, Longitude: 0.328},
	})
	driver2 := corridorDriver("driver-leg-2-route-points", 0.01, 0.33, routeCorridor())
	driver2.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.332},
		{Latitude: 0, Longitude: 0.658},
	})
	driver3 := corridorDriver("driver-leg-3-route-points", 0.01, 0.66, routeCorridor())
	driver3.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0.662},
		{Latitude: 0, Longitude: 0.998},
	})

	journey := build3HopJourney(req, transfer1, transfer2, driver1, 30, driver2, 40, driver3, 50)

	if len(journey.Legs) != 3 {
		t.Fatalf("expected three legs, got %d", len(journey.Legs))
	}
	assertGeoPointNear(t, journey.Legs[0].Pickup, GeoPoint{Latitude: 0, Longitude: 0.002})
	assertGeoPointNear(t, journey.Legs[0].Dropoff, GeoPoint{Latitude: 0, Longitude: 0.328})
	assertGeoPointNear(t, journey.Legs[1].Pickup, GeoPoint{Latitude: 0, Longitude: 0.332})
	assertGeoPointNear(t, journey.Legs[1].Dropoff, GeoPoint{Latitude: 0, Longitude: 0.658})
	assertGeoPointNear(t, journey.Legs[2].Pickup, GeoPoint{Latitude: 0, Longitude: 0.662})
	assertGeoPointNear(t, journey.Legs[2].Dropoff, GeoPoint{Latitude: 0, Longitude: 0.998})
}

func TestBuildLegRequestRebindsWalkZonesToLegEndpoints(t *testing.T) {
	req := corridorRequest()
	req.WalkRadiusM = 1000
	transfer := GeoPoint{Latitude: 0, Longitude: 0.5}

	legReq := buildLegRequest(req, req.Origin, transfer)
	validLegDriver := corridorDriver("origin-to-transfer", 0.005, 0, rectPolygon(-0.005, -0.01, 0.005, 0.51))

	_, _, ok := computeDriverScore(legReq, validLegDriver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected leg request to use transfer as destination walk zone instead of original trip destination")
	}
}

func TestBuildLegRequestPreservesOriginalOriginWalkIsoForFirstLeg(t *testing.T) {
	req := corridorRequest()
	req.WalkRadiusM = 1500
	req.OriWalkIso = rectPolygon(-0.001, -0.001, 0.001, 0.001)
	transfer := GeoPoint{Latitude: 0, Longitude: 0.5}

	legReq := buildLegRequest(req, req.Origin, transfer)

	if !reflect.DeepEqual(legReq.OriWalkIso, req.OriWalkIso) || !reflect.DeepEqual(legReq.OriginWalkIso, req.OriWalkIso) {
		t.Fatalf("expected first leg to preserve original origin walk isochrone; got ori=%#v origin=%#v", legReq.OriWalkIso, legReq.OriginWalkIso)
	}
}

func TestBuildLegRequestPreservesOriginalDestinationWalkIsoForFinalLeg(t *testing.T) {
	req := corridorRequest()
	req.WalkRadiusM = 1500
	req.DestWalkIso = rectPolygon(-0.001, 0.999, 0.001, 1.001)
	transfer := GeoPoint{Latitude: 0, Longitude: 0.5}

	legReq := buildLegRequest(req, transfer, req.Destination)

	if !reflect.DeepEqual(legReq.DestWalkIso, req.DestWalkIso) || !reflect.DeepEqual(legReq.DestinationWalkIso, req.DestWalkIso) {
		t.Fatalf("expected final leg to preserve original destination walk isochrone; got dest=%#v destination=%#v", legReq.DestWalkIso, legReq.DestinationWalkIso)
	}
}

func TestBuildLegRequestRebindsDestinationDriveGeoToLegDestination(t *testing.T) {
	req := corridorRequest()
	req.WalkRadiusM = 1000
	req.DestinationDriveGeo = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	transfer := GeoPoint{Latitude: 0, Longitude: 0.5}

	legReq := buildLegRequest(req, req.Origin, transfer)
	validLegDriver := corridorDriver("origin-to-transfer-destination-drive", 0, 0, GeoJSONGeometry{})
	validLegDriver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.5},
	})

	_, _, ok := computeDriverScore(legReq, validLegDriver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected leg request to rebind destinationDriveGeo to the transfer endpoint instead of inheriting the original trip destination")
	}
}

func TestBuildLegRequestPreservesOriginalOriginDriveGeoForFirstLeg(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	req := corridorRequest()
	req.WalkRadiusM = 1500
	req.OriDriveIso = rectPolygon(-0.001, -0.001, 0.001, 0.001)
	req.OriginDriveGeo = GeoJSONGeometry{}
	transfer := GeoPoint{Latitude: 0, Longitude: 0.5}

	legReq := buildLegRequest(req, req.Origin, transfer)
	outsideOriginalDrive := corridorDriver("outside-original-origin-drive", 0.008, 0, GeoJSONGeometry{})
	outsideOriginalDrive.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.008, Longitude: 0},
		{Latitude: 0.008, Longitude: 0.5},
	})

	_, _, ok := computeDriverScore(legReq, outsideOriginalDrive, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected first-leg request to preserve original originDriveGeo instead of broadening it to a synthetic transfer geofence")
	}
}

func TestLegExcludedDriverIDsMergesReservationRetryAndPriorLegDrivers(t *testing.T) {
	req := corridorRequest()
	req.ExcludedDriverIDs = []string{" failed-reservation ", "already-filtered", "  "}

	excluded := legExcludedDriverIDs(req, "leg-1-driver", "failed-reservation", "\n")

	want := []string{"failed-reservation", "already-filtered", "leg-1-driver"}
	if !reflect.DeepEqual(excluded, want) {
		t.Fatalf("expected merged normalized exclusions %#v, got %#v", want, excluded)
	}
}

func allowLongPickupETA(t *testing.T) {
	t.Helper()
	t.Setenv("MAX_SINGLE_HOP_PICKUP_ETA_SECONDS", "28800")
}

func corridorRequest() RideRequest {
	return RideRequest{
		Origin:         GeoPoint{Latitude: 0, Longitude: 0},
		Destination:    GeoPoint{Latitude: 0, Longitude: 1},
		PassengerCount: 1,
		OriWalkIso:     rectPolygon(-0.01, -0.01, 0.01, 0.01),
		DestWalkIso:    rectPolygon(-0.01, 0.99, 0.01, 1.01),
		OriDriveIso:    rectPolygon(-0.05, -0.05, 0.05, 0.05),
	}
}

func corridorDriver(id string, lat, lon float64, buffer GeoJSONGeometry) DriverProfile {
	return DriverProfile{
		ID:              id,
		CurrentLocation: GeoPoint{Latitude: lat, Longitude: lon},
		CapacitySeats:   4,
		BufferPolygon:   buffer,
	}
}

func corridorDriverWithPickupZone(id string, lat, lon float64, buffer GeoJSONGeometry, pickupZoneID string) DriverProfile {
	driver := corridorDriver(id, lat, lon, buffer)
	driver.PickupZoneID = pickupZoneID
	driver.DropoffZoneID = pickupZoneID + "-dropoff"
	return driver
}

func routeCorridor() GeoJSONGeometry {
	return rectPolygon(-0.005, -0.01, 0.005, 1.01)
}

func polygonWithHole(outer [][]float64, holes ...[][]float64) GeoJSONGeometry {
	rings := make([][][]float64, 0, len(holes)+1)
	rings = append(rings, outer)
	rings = append(rings, holes...)
	return GeoJSONGeometry{Type: "Polygon", Coordinates: rings}
}

func multiPolygon(rings ...[][]float64) GeoJSONGeometry {
	polygons := make([][][][]float64, 0, len(rings))
	for _, ring := range rings {
		polygons = append(polygons, [][][]float64{ring})
	}
	return GeoJSONGeometry{Type: "MultiPolygon", Coordinates: polygons}
}

func rectRing(minLat, minLon, maxLat, maxLon float64) [][]float64 {
	return [][]float64{
		{minLon, minLat},
		{maxLon, minLat},
		{maxLon, maxLat},
		{minLon, maxLat},
		{minLon, minLat},
	}
}

func rectPolygon(minLat, minLon, maxLat, maxLon float64) GeoJSONGeometry {
	return GeoJSONGeometry{
		Type: "Polygon",
		Coordinates: [][][]float64{{
			{minLon, minLat},
			{maxLon, minLat},
			{maxLon, maxLat},
			{minLon, maxLat},
			{minLon, minLat},
		}},
	}
}

func assertGeoPointNear(t *testing.T, got, want GeoPoint) {
	t.Helper()
	if math.Abs(got.Latitude-want.Latitude) > 0.000001 || math.Abs(got.Longitude-want.Longitude) > 0.000001 {
		t.Fatalf("expected point near %#v, got %#v", want, got)
	}
}

func encodePolyline(points []GeoPoint) string {
	encoded := ""
	prevLat := 0
	prevLon := 0
	for _, point := range points {
		lat := int(math.Round(point.Latitude * 1e5))
		lon := int(math.Round(point.Longitude * 1e5))
		encoded += encodePolylineValue(lat - prevLat)
		encoded += encodePolylineValue(lon - prevLon)
		prevLat = lat
		prevLon = lon
	}
	return encoded
}

func encodePolylineValue(value int) string {
	value <<= 1
	if value < 0 {
		value = ^value
	}
	encoded := ""
	for value >= 0x20 {
		encoded += string(rune((0x20 | (value & 0x1f)) + 63))
		value >>= 5
	}
	encoded += string(rune(value + 63))
	return encoded
}
