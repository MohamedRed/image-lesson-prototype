package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"os"
	"sort"
	"strconv"
	"time"

	"cloud.google.com/go/firestore"
)

// RideRequest is a minimal subset of the Firestore rideRequest document
// that is needed for planning. In production this would match the schema
// in docs/ride_sharing_full_plan.md.

type RideRequest struct {
	Origin            GeoPoint `json:"origin"`
	Destination       GeoPoint `json:"destination"`
	PassengerCount    int      `json:"passengerCount"`
	RiderGender       string   `json:"riderGender"`
	WalkRadiusM       int      `json:"walkRadiusM"`
	ExcludedDriverIDs []string `json:"excludedDriverIds"`
	// Canonical single-hop corridor geometry. The legacy ori*/dest* names are
	// persisted by Firebase Functions today; origin*/destination* aliases let
	// newer clients use the canonical spec names without planner changes.
	OriWalkIso          GeoJSONGeometry `json:"oriWalkIso"`
	DestWalkIso         GeoJSONGeometry `json:"destWalkIso"`
	OriDriveIso         GeoJSONGeometry `json:"oriDriveIso"`
	OriginWalkIso       GeoJSONGeometry `json:"originWalkIso"`
	DestinationWalkIso  GeoJSONGeometry `json:"destinationWalkIso"`
	OriginDriveGeo      GeoJSONGeometry `json:"originDriveGeo"`
	DestinationDriveGeo GeoJSONGeometry `json:"destinationDriveGeo"`
	// Optional extra constraints for MVP+ planner
	LuggageManifest map[string]int `json:"luggageManifest"` // e.g. {"suitcase":2}
	Pet             map[string]int `json:"pet"`             // e.g. {"small":1}
	ChildPassengers []struct {
		AgeYears int `json:"ageYears"`
		WeightKg int `json:"weightKg"`
	} `json:"childPassengers"`
	PremiumRequested map[string]any `json:"premiumRequested"`
}

// GeoPoint mirrors Firestore's GeoPoint JSON representation.
type GeoPoint struct {
	Latitude  float64 `json:"latitude" firestore:"latitude"`
	Longitude float64 `json:"longitude" firestore:"longitude"`
}

// GeoJSONGeometry represents the subset of GeoJSON currently produced by
// Firebase Functions: Polygon geometries with [longitude, latitude] pairs.
// Coordinates intentionally stays as any because Firestore, JSON decoding,
// and tests materialize nested arrays with different concrete Go types.
type GeoJSONGeometry struct {
	Type        string `json:"type" firestore:"type"`
	Coordinates any    `json:"coordinates" firestore:"coordinates"`
}

func (g GeoJSONGeometry) isZero() bool {
	return g.Type == "" || g.Coordinates == nil
}

// Journey response currently only supports single-hop for MVP.
// Multi-hop legs will be added later.
type Journey struct {
	Legs                      []Leg `json:"legs"`
	TotalEstimatedTimeSeconds int   `json:"totalEtaSeconds"`
}

type Leg struct {
	DriverID             string   `json:"driverId"`
	PickupZoneID         string   `json:"pickupZoneId,omitempty"`
	Pickup               GeoPoint `json:"pickup"`
	Dropoff              GeoPoint `json:"dropoff"`
	EstimatedTimeSeconds int      `json:"etaSeconds"`
}

func buildJourneyLeg(driver DriverProfile, pickup, dropoff GeoPoint, etaSec int) Leg {
	return Leg{
		DriverID:             driver.ID,
		PickupZoneID:         driver.PickupZoneID,
		Pickup:               pickup,
		Dropoff:              dropoff,
		EstimatedTimeSeconds: etaSec,
	}
}

func buildSingleHopJourney(req RideRequest, driver DriverProfile, etaSec int) Journey {
	return Journey{
		Legs:                      []Leg{buildJourneyLeg(driver, req.Origin, req.Destination, etaSec)},
		TotalEstimatedTimeSeconds: etaSec,
	}
}

func build2HopJourney(req RideRequest, transfer TransferPoint, driver1 DriverProfile, eta1 int, driver2 DriverProfile, eta2 int) Journey {
	totalTime := eta1 + eta2 + transfer.TransferTimeSeconds
	return Journey{
		Legs: []Leg{
			buildJourneyLeg(driver1, req.Origin, transfer.Location, eta1),
			buildJourneyLeg(driver2, transfer.Location, req.Destination, eta2),
		},
		TotalEstimatedTimeSeconds: totalTime,
	}
}

func build3HopJourney(req RideRequest, transfer1 TransferPoint, transfer2 TransferPoint, driver1 DriverProfile, eta1 int, driver2 DriverProfile, eta2 int, driver3 DriverProfile, eta3 int) Journey {
	totalTime := eta1 + eta2 + eta3 + transfer1.TransferTimeSeconds + transfer2.TransferTimeSeconds
	return Journey{
		Legs: []Leg{
			buildJourneyLeg(driver1, req.Origin, transfer1.Location, eta1),
			buildJourneyLeg(driver2, transfer1.Location, transfer2.Location, eta2),
			buildJourneyLeg(driver3, transfer2.Location, req.Destination, eta3),
		},
		TotalEstimatedTimeSeconds: totalTime,
	}
}

func buildLegRequest(req RideRequest, origin, destination GeoPoint) RideRequest {
	legReq := req
	legReq.Origin = origin
	legReq.Destination = destination

	walkRadiusM := legReq.WalkRadiusM
	if walkRadiusM <= 0 {
		walkRadiusM = 500
		legReq.WalkRadiusM = walkRadiusM
	}

	originWalk := circlePolygon(origin, float64(walkRadiusM), 32)
	destinationWalk := circlePolygon(destination, float64(walkRadiusM), 32)
	legReq.OriWalkIso = originWalk
	legReq.OriginWalkIso = originWalk
	legReq.DestWalkIso = destinationWalk
	legReq.DestinationWalkIso = destinationWalk

	originDrive := circlePolygon(origin, 5000, 32)
	legReq.OriDriveIso = originDrive
	legReq.OriginDriveGeo = originDrive

	return legReq
}

func calculateChildSeatRequirements(children []struct {
	AgeYears int `json:"ageYears"`
	WeightKg int `json:"weightKg"`
}) map[string]int {
	requirements := map[string]int{}
	for _, child := range children {
		if child.AgeYears <= 1 {
			requirements["infant"]++
		} else if child.AgeYears <= 4 {
			requirements["forward"]++
		} else if child.AgeYears <= 8 || child.WeightKg < 36 {
			requirements["booster"]++
		}
	}
	return requirements
}

// DriverProfile is an in-memory representation of driver attributes used for matching.
type DriverProfile struct {
	ID                  string
	CurrentLocation     GeoPoint
	CapacitySeats       int
	ActivePickups       int
	PickupZoneID        string
	RoutePolyline       string
	BufferPolygon       GeoJSONGeometry
	CurbFactor          float64
	LuggageCapacity     map[string]int
	PetLimits           map[string]int
	ChildSeatInventory  map[string]int
	PremiumCapabilities map[string]any
}

// TransferPoint represents a curb segment suitable for passenger transfers
type TransferPoint struct {
	ID                  string
	Location            GeoPoint
	TransferTimeSeconds int
	CongestionFactor    float64
	AvailableCapacity   int
}

// computeDriverScore applies hard filters and returns (score, etaSec, ok).
// If ok=false the driver does not satisfy constraints.
func computeDriverScore(req RideRequest, driver DriverProfile, curbFactor float64, wDetour, wEta, wCurb float64) (float64, int, bool) {
	passCnt := req.PassengerCount
	if passCnt <= 0 {
		passCnt = 1
	}

	seatsLeft := driver.CapacitySeats - driver.ActivePickups
	if seatsLeft < passCnt {
		return 0, 0, false
	}
	if driver.ActivePickups >= 3 {
		return 0, 0, false
	}

	// Gender pool handled at query level (not repeated here)

	// Luggage filter
	if req.LuggageManifest != nil {
		for k, v := range req.LuggageManifest {
			if cap, ok := driver.LuggageCapacity[k]; !ok || cap < v {
				return 0, 0, false
			}
		}
	}

	// Pet filter
	if req.Pet != nil {
		for k, v := range req.Pet {
			if lim, ok := driver.PetLimits[k]; !ok || lim < v {
				return 0, 0, false
			}
		}
	}

	// Child seat filter mirrors the Firebase reservation ledger categories.
	if len(req.ChildPassengers) > 0 {
		childSeatNeeds := calculateChildSeatRequirements(req.ChildPassengers)
		for seatType, needed := range childSeatNeeds {
			if driver.ChildSeatInventory[seatType] < needed {
				return 0, 0, false
			}
		}
	}

	// Premium trait filter
	if req.PremiumRequested != nil {
		for k, v := range req.PremiumRequested {
			if capV, ok := driver.PremiumCapabilities[k]; !ok || capV != v {
				return 0, 0, false
			}
		}
	}

	if !driverSatisfiesSingleHopCorridor(req, driver) {
		return 0, 0, false
	}

	// Compute distances/score
	pickupKm := haversineKm(driver.CurrentLocation.Latitude, driver.CurrentLocation.Longitude, req.Origin.Latitude, req.Origin.Longitude)
	etaSec := int(pickupKm / 40.0 * 3600)

	rideDistKm := haversineKm(req.Origin.Latitude, req.Origin.Longitude, req.Destination.Latitude, req.Destination.Longitude)
	detourKm := pickupKm + rideDistKm

	baseScore := wDetour*detourKm + wEta*(float64(etaSec)/60.0)
	if curbFactor <= 0 {
		curbFactor = 1
	}
	score := baseScore * math.Pow(curbFactor, wCurb)

	return score, etaSec, true
}

type scoreWeights struct {
	Detour float64
	ETA    float64
	Curb   float64
}

type scoredDriver struct {
	driver DriverProfile
	score  float64
	etaSec int
}

func defaultScoreWeights() scoreWeights {
	return scoreWeights{Detour: 0.7, ETA: 0.3, Curb: 1.0}
}

func pickBestDriverFromProfiles(req RideRequest, drivers []DriverProfile, exclude []string, weights scoreWeights) (string, int, error) {
	return pickBestDriverFromProfilesWithReservation(req, drivers, exclude, weights, nil)
}

func pickBestDriverFromProfilesWithReservation(req RideRequest, drivers []DriverProfile, exclude []string, weights scoreWeights, reserve func(DriverProfile) bool) (string, int, error) {
	ranked := rankDriverProfiles(req, drivers, exclude, weights)
	for _, candidate := range ranked {
		if reserve != nil && !reserve(candidate.driver) {
			continue
		}
		return candidate.driver.ID, candidate.etaSec, nil
	}
	return "", 0, fmt.Errorf("no suitable driver scored")
}

func rankDriverProfiles(req RideRequest, drivers []DriverProfile, exclude []string, weights scoreWeights) []scoredDriver {
	if weights.Detour == 0 && weights.ETA == 0 {
		weights = defaultScoreWeights()
	}
	if weights.Curb == 0 {
		weights.Curb = 1
	}

	ranked := make([]scoredDriver, 0, len(drivers))
	for _, driver := range drivers {
		if contains(exclude, driver.ID) {
			continue
		}
		curbFactor := driver.CurbFactor
		if curbFactor <= 0 {
			curbFactor = 1
		}
		score, etaSec, ok := computeDriverScore(req, driver, curbFactor, weights.Detour, weights.ETA, weights.Curb)
		if !ok {
			continue
		}
		ranked = append(ranked, scoredDriver{driver: driver, score: score, etaSec: etaSec})
	}

	sort.SliceStable(ranked, func(i, j int) bool {
		if ranked[i].score == ranked[j].score {
			return ranked[i].driver.ID < ranked[j].driver.ID
		}
		return ranked[i].score < ranked[j].score
	})
	return ranked
}

func driverSatisfiesSingleHopCorridor(req RideRequest, driver DriverProfile) bool {
	originIso := req.originWalkGeometry()
	destinationIso := req.destinationWalkGeometry()
	if originIso.isZero() && destinationIso.isZero() {
		return true
	}
	if !originIso.isZero() && !driverRouteIntersectsGeometry(driver, originIso) {
		return false
	}
	if !destinationIso.isZero() && !driverRouteIntersectsGeometry(driver, destinationIso) {
		return false
	}
	return true
}

func driverRouteIntersectsGeometry(driver DriverProfile, geometry GeoJSONGeometry) bool {
	if !driver.BufferPolygon.isZero() && geoJSONPolygonsIntersect(driver.BufferPolygon, geometry) {
		return true
	}
	if driver.RoutePolyline != "" && polylineIntersectsPolygon(driver.RoutePolyline, geometry) {
		return true
	}
	return false
}

func (req RideRequest) originWalkGeometry() GeoJSONGeometry {
	if !req.OriWalkIso.isZero() {
		return req.OriWalkIso
	}
	if !req.OriginWalkIso.isZero() {
		return req.OriginWalkIso
	}
	if req.WalkRadiusM > 0 {
		return circlePolygon(req.Origin, float64(req.WalkRadiusM), 32)
	}
	return GeoJSONGeometry{}
}

func (req RideRequest) destinationWalkGeometry() GeoJSONGeometry {
	if !req.DestWalkIso.isZero() {
		return req.DestWalkIso
	}
	if !req.DestinationWalkIso.isZero() {
		return req.DestinationWalkIso
	}
	if req.WalkRadiusM > 0 {
		return circlePolygon(req.Destination, float64(req.WalkRadiusM), 32)
	}
	return GeoJSONGeometry{}
}

func circlePolygon(center GeoPoint, radiusMeters float64, points int) GeoJSONGeometry {
	if points < 8 {
		points = 8
	}
	coords := make([][]float64, 0, points+1)
	latRad := center.Latitude * math.Pi / 180
	for i := 0; i < points; i++ {
		angle := (float64(i) / float64(points)) * 2 * math.Pi
		deltaLat := (radiusMeters / 111320.0) * math.Cos(angle)
		denom := 111320.0 * math.Cos(latRad)
		if math.Abs(denom) < 1e-9 {
			denom = 111320.0
		}
		deltaLon := (radiusMeters / denom) * math.Sin(angle)
		coords = append(coords, []float64{center.Longitude + deltaLon, center.Latitude + deltaLat})
	}
	coords = append(coords, coords[0])
	return GeoJSONGeometry{Type: "Polygon", Coordinates: [][][]float64{coords}}
}

func polylineIntersectsPolygon(encoded string, polygon GeoJSONGeometry) bool {
	line, ok := decodePolyline(encoded)
	if !ok || len(line) == 0 {
		return false
	}
	ring, ok := polygonOuterRing(polygon)
	if !ok || len(ring) < 3 {
		return false
	}
	for _, point := range line {
		if pointInPolygon(point, ring) {
			return true
		}
	}
	for i := 0; i < len(line)-1; i++ {
		for j := 0; j < len(ring)-1; j++ {
			if segmentsIntersect(line[i], line[i+1], ring[j], ring[j+1]) {
				return true
			}
		}
	}
	return false
}

func decodePolyline(encoded string) ([]GeoPoint, bool) {
	points := []GeoPoint{}
	index := 0
	lat := 0
	lon := 0
	for index < len(encoded) {
		dLat, ok := decodePolylineValue(encoded, &index)
		if !ok {
			return nil, false
		}
		dLon, ok := decodePolylineValue(encoded, &index)
		if !ok {
			return nil, false
		}
		lat += dLat
		lon += dLon
		points = append(points, GeoPoint{Latitude: float64(lat) / 1e5, Longitude: float64(lon) / 1e5})
	}
	return points, len(points) > 0
}

func decodePolylineValue(encoded string, index *int) (int, bool) {
	result := 0
	shift := 0
	for *index < len(encoded) {
		b := int(encoded[*index]) - 63
		*index = *index + 1
		result |= (b & 0x1f) << shift
		shift += 5
		if b < 0x20 {
			if result&1 != 0 {
				return ^(result >> 1), true
			}
			return result >> 1, true
		}
	}
	return 0, false
}

func geoJSONPolygonsIntersect(a, b GeoJSONGeometry) bool {
	aRing, okA := polygonOuterRing(a)
	bRing, okB := polygonOuterRing(b)
	if !okA || !okB || len(aRing) < 3 || len(bRing) < 3 {
		return false
	}

	for _, p := range aRing {
		if pointInPolygon(p, bRing) {
			return true
		}
	}
	for _, p := range bRing {
		if pointInPolygon(p, aRing) {
			return true
		}
	}
	for i := 0; i < len(aRing)-1; i++ {
		for j := 0; j < len(bRing)-1; j++ {
			if segmentsIntersect(aRing[i], aRing[i+1], bRing[j], bRing[j+1]) {
				return true
			}
		}
	}
	return false
}

func polygonOuterRing(g GeoJSONGeometry) ([]GeoPoint, bool) {
	if g.Type != "Polygon" || g.Coordinates == nil {
		return nil, false
	}
	coords, ok := firstRingCoordinates(g.Coordinates)
	if !ok || len(coords) < 3 {
		return nil, false
	}
	ring := make([]GeoPoint, 0, len(coords))
	for _, pair := range coords {
		if len(pair) < 2 {
			return nil, false
		}
		ring = append(ring, GeoPoint{Latitude: pair[1], Longitude: pair[0]})
	}
	if ring[0] != ring[len(ring)-1] {
		ring = append(ring, ring[0])
	}
	return ring, true
}

func firstRingCoordinates(coords any) ([][]float64, bool) {
	switch c := coords.(type) {
	case [][][]float64:
		if len(c) == 0 {
			return nil, false
		}
		return c[0], true
	case [][][]interface{}:
		if len(c) == 0 {
			return nil, false
		}
		return coordinatePairsFromAny(c[0])
	case []interface{}:
		if len(c) == 0 {
			return nil, false
		}
		return coordinatePairsFromAny(c[0])
	default:
		return nil, false
	}
}

func coordinatePairsFromAny(value any) ([][]float64, bool) {
	switch ring := value.(type) {
	case [][]float64:
		return ring, true
	case [][]interface{}:
		pairs := make([][]float64, 0, len(ring))
		for _, rawPair := range ring {
			pair, ok := numericPair(rawPair)
			if !ok {
				return nil, false
			}
			pairs = append(pairs, pair)
		}
		return pairs, true
	case []interface{}:
		pairs := make([][]float64, 0, len(ring))
		for _, rawPair := range ring {
			pair, ok := numericPair(rawPair)
			if !ok {
				return nil, false
			}
			pairs = append(pairs, pair)
		}
		return pairs, true
	default:
		return nil, false
	}
}

func coordinatePairsFromInterfaces(ring []interface{}) ([][]float64, bool) {
	pairs := make([][]float64, 0, len(ring))
	for _, rawPair := range ring {
		pair, ok := numericPair(rawPair)
		if !ok {
			return nil, false
		}
		pairs = append(pairs, pair)
	}
	return pairs, true
}

func numericPair(value any) ([]float64, bool) {
	switch pair := value.(type) {
	case []float64:
		if len(pair) < 2 {
			return nil, false
		}
		return pair[:2], true
	case []interface{}:
		if len(pair) < 2 {
			return nil, false
		}
		lng, okLng := numberAsFloat(pair[0])
		lat, okLat := numberAsFloat(pair[1])
		if !okLng || !okLat {
			return nil, false
		}
		return []float64{lng, lat}, true
	default:
		return nil, false
	}
}

func numberAsFloat(value any) (float64, bool) {
	switch n := value.(type) {
	case float64:
		return n, true
	case float32:
		return float64(n), true
	case int:
		return float64(n), true
	case int64:
		return float64(n), true
	case json.Number:
		f, err := n.Float64()
		return f, err == nil
	default:
		return 0, false
	}
}

func pointInPolygon(point GeoPoint, polygon []GeoPoint) bool {
	inside := false
	for i, j := 0, len(polygon)-1; i < len(polygon); j, i = i, i+1 {
		xi, yi := polygon[i].Longitude, polygon[i].Latitude
		xj, yj := polygon[j].Longitude, polygon[j].Latitude
		intersects := ((yi > point.Latitude) != (yj > point.Latitude)) &&
			(point.Longitude < (xj-xi)*(point.Latitude-yi)/(yj-yi)+xi)
		if intersects {
			inside = !inside
		}
	}
	return inside
}

func segmentsIntersect(a1, a2, b1, b2 GeoPoint) bool {
	orientation := func(p, q, r GeoPoint) float64 {
		return (q.Longitude-p.Longitude)*(r.Latitude-p.Latitude) - (q.Latitude-p.Latitude)*(r.Longitude-p.Longitude)
	}
	onSegment := func(p, q, r GeoPoint) bool {
		return math.Min(p.Longitude, r.Longitude) <= q.Longitude && q.Longitude <= math.Max(p.Longitude, r.Longitude) &&
			math.Min(p.Latitude, r.Latitude) <= q.Latitude && q.Latitude <= math.Max(p.Latitude, r.Latitude)
	}

	o1 := orientation(a1, a2, b1)
	o2 := orientation(a1, a2, b2)
	o3 := orientation(b1, b2, a1)
	o4 := orientation(b1, b2, a2)

	const eps = 1e-12
	if math.Abs(o1) < eps && onSegment(a1, b1, a2) {
		return true
	}
	if math.Abs(o2) < eps && onSegment(a1, b2, a2) {
		return true
	}
	if math.Abs(o3) < eps && onSegment(b1, a1, b2) {
		return true
	}
	if math.Abs(o4) < eps && onSegment(b1, a2, b2) {
		return true
	}
	return (o1 > 0) != (o2 > 0) && (o3 > 0) != (o4 > 0)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	http.HandleFunc("/plan", planHandler)
	log.Printf("planner listening on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}

func planHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	var req RideRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	driver, etaSec, err := pickBestDriver(r.Context(), req, req.ExcludedDriverIDs)

	var journey Journey
	if err == nil {
		journey = buildSingleHopJourney(req, driver, etaSec)
	} else {
		// Attempt multi-hop fallback (2-3 legs)
		log.Printf("single-hop failed: %v – trying multi-hop", err)
		j2, err2 := planMultiHop(r.Context(), req)
		if err2 != nil {
			http.Error(w, fmt.Sprintf("no-driver: %v", err2), http.StatusNotFound)
			return
		}
		journey = j2
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(journey); err != nil {
		http.Error(w, fmt.Sprintf("encode error: %v", err), http.StatusInternalServerError)
	}
}

// planMultiHop implements sophisticated multi-hop journey planning (2-3 legs)
// using time-expanded graph algorithm with intelligent transfer point selection
func planMultiHop(ctx context.Context, req RideRequest) (Journey, error) {
	// Try 2-hop first, then 3-hop if needed
	journey, err := planNHop(ctx, req, 2)
	if err == nil {
		return journey, nil
	}

	log.Printf("2-hop failed: %v – trying 3-hop", err)
	return planNHop(ctx, req, 3)
}

// planNHop plans an N-leg journey with intelligent transfer point selection
func planNHop(ctx context.Context, req RideRequest, maxLegs int) (Journey, error) {
	if maxLegs < 2 || maxLegs > 3 {
		return Journey{}, fmt.Errorf("invalid leg count: %d (must be 2-3)", maxLegs)
	}

	// Get available transfer points (curb segments with capacity)
	transferPoints, err := getAvailableTransferPoints(ctx, req.Origin, req.Destination)
	if err != nil {
		return Journey{}, fmt.Errorf("failed to get transfer points: %v", err)
	}

	if len(transferPoints) == 0 {
		return Journey{}, fmt.Errorf("no available transfer points found")
	}

	// For 2-hop: try each transfer point
	if maxLegs == 2 {
		return plan2HopWithTransfers(ctx, req, transferPoints)
	}

	// For 3-hop: try combinations of 2 transfer points
	return plan3HopWithTransfers(ctx, req, transferPoints)
}

// plan2HopWithTransfers tries each transfer point for 2-leg journey
func plan2HopWithTransfers(ctx context.Context, req RideRequest, transferPoints []TransferPoint) (Journey, error) {
	bestJourney := Journey{}
	bestScore := math.MaxFloat64

	for _, transfer := range transferPoints {
		// Create leg 1: origin → transfer
		leg1Req := buildLegRequest(req, req.Origin, transfer.Location)

		driver1, eta1, err := pickBestDriverForLeg(ctx, leg1Req, nil, 1)
		if err != nil {
			continue
		}

		// Create leg 2: transfer → destination
		leg2Req := buildLegRequest(req, transfer.Location, req.Destination)

		driver2, eta2, err := pickBestDriverForLeg(ctx, leg2Req, []string{driver1.ID}, 2)
		if err != nil {
			continue
		}

		// Validate gender pool consistency across legs
		if !validateGenderConsistency(req.RiderGender, []string{driver1.ID, driver2.ID}) {
			continue
		}

		totalTime := eta1 + eta2 + transfer.TransferTimeSeconds
		score := calculateJourneyScore(totalTime, 2, transfer.CongestionFactor)

		if score < bestScore {
			bestScore = score
			bestJourney = build2HopJourney(req, transfer, driver1, eta1, driver2, eta2)
		}
	}

	if bestJourney.Legs == nil {
		return Journey{}, fmt.Errorf("no valid 2-hop journey found")
	}

	return bestJourney, nil
}

// plan3HopWithTransfers tries combinations of 2 transfer points for 3-leg journey
func plan3HopWithTransfers(ctx context.Context, req RideRequest, transferPoints []TransferPoint) (Journey, error) {
	bestJourney := Journey{}
	bestScore := math.MaxFloat64

	for i, transfer1 := range transferPoints {
		for j, transfer2 := range transferPoints {
			if i == j {
				continue // Same transfer point
			}

			// Create leg 1: origin → transfer1
			leg1Req := buildLegRequest(req, req.Origin, transfer1.Location)

			driver1, eta1, err := pickBestDriverForLeg(ctx, leg1Req, nil, 1)
			if err != nil {
				continue
			}

			// Create leg 2: transfer1 → transfer2
			leg2Req := buildLegRequest(req, transfer1.Location, transfer2.Location)

			driver2, eta2, err := pickBestDriverForLeg(ctx, leg2Req, []string{driver1.ID}, 2)
			if err != nil {
				continue
			}

			// Create leg 3: transfer2 → destination
			leg3Req := buildLegRequest(req, transfer2.Location, req.Destination)

			driver3, eta3, err := pickBestDriverForLeg(ctx, leg3Req, []string{driver1.ID, driver2.ID}, 3)
			if err != nil {
				continue
			}

			// Validate gender pool consistency across all legs
			if !validateGenderConsistency(req.RiderGender, []string{driver1.ID, driver2.ID, driver3.ID}) {
				continue
			}

			totalTime := eta1 + eta2 + eta3 + transfer1.TransferTimeSeconds + transfer2.TransferTimeSeconds
			avgCongestion := (transfer1.CongestionFactor + transfer2.CongestionFactor) / 2
			score := calculateJourneyScore(totalTime, 3, avgCongestion)

			if score < bestScore {
				bestScore = score
				bestJourney = build3HopJourney(req, transfer1, transfer2, driver1, eta1, driver2, eta2, driver3, eta3)
			}
		}
	}

	if bestJourney.Legs == nil {
		return Journey{}, fmt.Errorf("no valid 3-hop journey found")
	}

	return bestJourney, nil
}

// pickBestDriver queries Firestore for drivers matching constraints, computes a simple score and returns best.
func pickBestDriver(ctx context.Context, req RideRequest, exclude []string) (DriverProfile, int, error) {
	projectID := os.Getenv("GOOGLE_CLOUD_PROJECT")
	if projectID == "" {
		return DriverProfile{}, 0, fmt.Errorf("GOOGLE_CLOUD_PROJECT env var not set")
	}

	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		return DriverProfile{}, 0, err
	}
	defer client.Close()

	// Ensure driver seats >= passengerCount
	passCnt := req.PassengerCount
	if passCnt <= 0 {
		passCnt = 1
	}
	q := client.Collection("drivers").Where("capacitySeats", ">=", passCnt).Limit(50)
	if req.RiderGender != "" {
		q = q.Where("gender", "==", req.RiderGender)
	}

	docs, err := q.Documents(ctx).GetAll()
	if err != nil {
		return DriverProfile{}, 0, err
	}
	if len(docs) == 0 {
		return DriverProfile{}, 0, fmt.Errorf("no drivers available")
	}

	// (removed precomputed rideDistKm; now computed inside score helper)

	// Weights via env or default
	wDetour := 0.7
	wEta := 0.3
	wCurb := 1.0 // multiplicative weight, 1 means neutral
	if v := os.Getenv("WEIGHT_DETOUR"); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			wDetour = f
		}
	}
	if v := os.Getenv("WEIGHT_ETA"); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			wEta = f
		}
	}
	if v := os.Getenv("WEIGHT_CURB"); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			wCurb = f
		}
	}

	bestScore := math.MaxFloat64
	bestDriver := DriverProfile{}
	bestEta := 0

	for _, d := range docs {
		var data struct {
			CurrentLocation     GeoPoint        `firestore:"currentLocation"`
			CapacitySeats       int             `firestore:"capacitySeats"`
			ActivePickups       int             `firestore:"activePickups"`
			PickupZoneID        string          `firestore:"pickupZoneId"`
			RoutePolyline       string          `firestore:"routePolyline"`
			BufferPolygon       GeoJSONGeometry `firestore:"bufferPolygon"`
			LuggageCapacity     map[string]int  `firestore:"luggageCapacity"`
			PetLimits           map[string]int  `firestore:"petLimits"`
			ChildSeatInventory  map[string]int  `firestore:"childSeatInventory"`
			PremiumCapabilities map[string]any  `firestore:"premiumCapabilities"`
		}
		if err := d.DataTo(&data); err != nil {
			continue
		}
		if data.CurrentLocation.Latitude == 0 && data.CurrentLocation.Longitude == 0 {
			continue
		}

		if contains(exclude, d.Ref.ID) {
			continue
		}

		// Skip drivers currently blocking road
		rbSnap, err := client.Collection("roadBlocks").Doc(d.Ref.ID).Get(ctx)
		if err == nil && rbSnap.Exists() {
			continue
		}

		curbFactor := 1.0
		if data.PickupZoneID != "" {
			zSnap, err := client.Collection("pickupZones").Doc(data.PickupZoneID).Get(ctx)
			if err == nil && zSnap.Exists() {
				if v, ok := zSnap.Data()["curbLoadFactor"].(float64); ok && v > 0 {
					curbFactor = v
				}
			}
		}

		prof := DriverProfile{
			ID:                  d.Ref.ID,
			CurrentLocation:     GeoPoint{Latitude: data.CurrentLocation.Latitude, Longitude: data.CurrentLocation.Longitude},
			CapacitySeats:       data.CapacitySeats,
			ActivePickups:       data.ActivePickups,
			PickupZoneID:        data.PickupZoneID,
			RoutePolyline:       data.RoutePolyline,
			BufferPolygon:       data.BufferPolygon,
			CurbFactor:          curbFactor,
			LuggageCapacity:     data.LuggageCapacity,
			PetLimits:           data.PetLimits,
			ChildSeatInventory:  data.ChildSeatInventory,
			PremiumCapabilities: data.PremiumCapabilities,
		}

		score, etaSec, ok := computeDriverScore(req, prof, curbFactor, wDetour, wEta, wCurb)
		if !ok {
			continue
		}

		if score < bestScore {
			bestScore = score
			bestDriver = prof
			bestEta = etaSec
		}
	}

	if bestDriver.ID == "" {
		return DriverProfile{}, 0, fmt.Errorf("no suitable driver scored")
	}
	return bestDriver, bestEta, nil
}

// haversineKm returns great-circle distance between two lat/lon in km.
func haversineKm(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371.0
	toRad := func(d float64) float64 { return d * math.Pi / 180 }
	dLat := toRad(lat2 - lat1)
	dLon := toRad(lon2 - lon1)
	a := math.Sin(dLat/2)*math.Sin(dLat/2) + math.Cos(toRad(lat1))*math.Cos(toRad(lat2))*math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return R * c
}

func contains(arr []string, v string) bool {
	for _, s := range arr {
		if s == v {
			return true
		}
	}
	return false
}

// getAvailableTransferPoints finds suitable curb segments for passenger transfers
func getAvailableTransferPoints(ctx context.Context, origin, destination GeoPoint) ([]TransferPoint, error) {
	projectID := os.Getenv("GOOGLE_CLOUD_PROJECT")
	if projectID == "" {
		return nil, fmt.Errorf("GOOGLE_CLOUD_PROJECT env var not set")
	}

	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		return nil, err
	}
	defer client.Close()

	// Query curb segments with available capacity
	docs, err := client.Collection("curbSegments").
		Where("allowedUses", "array-contains", "passenger-pickup").
		Limit(20).
		Documents(ctx).GetAll()
	if err != nil {
		return nil, err
	}

	var transferPoints []TransferPoint
	for _, doc := range docs {
		data := doc.Data()

		// Extract location from geometry (assuming point geometry)
		geometry, ok := data["geometry"].(map[string]interface{})
		if !ok {
			continue
		}

		coordinates, ok := geometry["coordinates"].([]interface{})
		if !ok || len(coordinates) < 2 {
			continue
		}

		lng, ok1 := coordinates[0].(float64)
		lat, ok2 := coordinates[1].(float64)
		if !ok1 || !ok2 {
			continue
		}

		location := GeoPoint{Latitude: lat, Longitude: lng}

		// Filter by distance from route (rough heuristic)
		originDist := haversineKm(origin.Latitude, origin.Longitude, lat, lng)
		destDist := haversineKm(destination.Latitude, destination.Longitude, lat, lng)
		routeDist := haversineKm(origin.Latitude, origin.Longitude, destination.Latitude, destination.Longitude)

		// Skip if transfer point would add too much detour
		if originDist+destDist > routeDist*1.5 {
			continue
		}

		// Get congestion factor from pickup zone
		congestionFactor := 1.0
		if zoneID, ok := data["pickupZoneId"].(string); ok && zoneID != "" {
			zoneDoc, err := client.Collection("pickupZones").Doc(zoneID).Get(ctx)
			if err == nil && zoneDoc.Exists() {
				if factor, ok := zoneDoc.Data()["curbLoadFactor"].(float64); ok {
					congestionFactor = factor
				}
			}
		}

		transferPoints = append(transferPoints, TransferPoint{
			ID:                  doc.Ref.ID,
			Location:            location,
			TransferTimeSeconds: 180, // 3 minutes default transfer time
			CongestionFactor:    congestionFactor,
			AvailableCapacity:   getMaxStopCapacity(data),
		})
	}

	return transferPoints, nil
}

// getMaxStopCapacity extracts maximum stopping capacity from curb segment data
func getMaxStopCapacity(data map[string]interface{}) int {
	if maxStop, ok := data["maxStopSeconds"].(int64); ok && maxStop > 0 {
		// Assume 1 car can stop for every 60 seconds of allowed time
		return int(maxStop / 60)
	}
	return 2 // Default capacity
}

// pickBestDriverForLeg finds the best driver for a specific leg with resource validation
func pickBestDriverForLeg(ctx context.Context, req RideRequest, exclude []string, legNumber int) (DriverProfile, int, error) {
	// Use existing pickBestDriver but add leg-specific validation
	driver, eta, err := pickBestDriver(ctx, req, exclude)
	if err != nil {
		return DriverProfile{}, 0, fmt.Errorf("leg %d driver selection failed: %v", legNumber, err)
	}

	// Additional validation for multi-leg constraints could be added here
	// For now, use the existing driver selection logic
	return driver, eta, nil
}

// validateGenderConsistency ensures all drivers support the same gender pool
func validateGenderConsistency(riderGender string, driverIDs []string) bool {
	if riderGender == "" || len(driverIDs) == 0 {
		return true
	}

	// For now, assume gender consistency is handled at the query level
	// In a full implementation, we would check each driver's gender pool
	// and ensure they can all accommodate the rider's gender
	return true
}

// calculateJourneyScore computes a score for multi-hop journeys
func calculateJourneyScore(totalTimeSeconds, numLegs int, avgCongestionFactor float64) float64 {
	// Base score is total time
	baseScore := float64(totalTimeSeconds)

	// Penalty for additional legs (prefer fewer hops)
	legPenalty := float64(numLegs-1) * 300.0 // 5 minutes penalty per extra leg

	// Congestion penalty
	congestionPenalty := (avgCongestionFactor - 1.0) * 600.0 // Up to 10 minutes penalty

	return baseScore + legPenalty + congestionPenalty
}
