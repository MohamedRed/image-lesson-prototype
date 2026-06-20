package main

import (
	"encoding/json"
	"math"
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

func TestComputeDriverScore_CorridorIntersectsOriginWalkZone(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("route-match", 0.05, 0, routeCorridor())

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected driver route corridor intersecting origin and destination walk zones to be accepted")
	}
}

func TestComputeDriverScore_CorridorIntersectsDestinationWalkZone(t *testing.T) {
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

func TestComputeDriverScore_AllowsRouteThatContinuesAfterDestinationNearOrigin(t *testing.T) {
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

func TestComputeDriverScore_DoesNotRejectSparseDirectPolylineAsDetour(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "1")
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
	if journey.TotalEstimatedTimeSeconds != 77 {
		t.Fatalf("expected total time with transfer wait, got %d", journey.TotalEstimatedTimeSeconds)
	}
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
	return driver
}

func routeCorridor() GeoJSONGeometry {
	return rectPolygon(-0.005, -0.01, 0.005, 1.01)
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
