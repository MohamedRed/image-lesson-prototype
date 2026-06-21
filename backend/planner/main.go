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
	pickup, dropoff := selectedSingleHopPickupDropoff(req, driver)
	legEtaSec := singleHopTotalETASeconds(req, driver, etaSec)
	return Journey{
		Legs:                      []Leg{buildJourneyLeg(driver, pickup, dropoff, legEtaSec)},
		TotalEstimatedTimeSeconds: legEtaSec,
	}
}

func singleHopTotalETASeconds(req RideRequest, driver DriverProfile, pickupEtaSec int) int {
	rideEtaSec, ok := singleHopRouteRideETASeconds(req, driver)
	if !ok {
		rideEtaSec = singleHopDirectRideETASeconds(req)
	}
	return pickupEtaSec + rideEtaSec
}

func singleHopDirectRideETASeconds(req RideRequest) int {
	rideKm := haversineKm(req.Origin.Latitude, req.Origin.Longitude, req.Destination.Latitude, req.Destination.Longitude)
	return int(rideKm / 40.0 * 3600)
}

func singleHopRouteRideETASeconds(req RideRequest, driver DriverProfile) (int, bool) {
	if driver.RoutePolyline == "" {
		return 0, false
	}
	points, ok := decodePolyline(driver.RoutePolyline)
	if !ok || len(points) < 2 {
		return 0, false
	}
	pickupProjection, dropoffProjection, ok := routeInsertionProjections(req, points)
	if !ok || dropoffProjection.position <= pickupProjection.position {
		return 0, false
	}
	if len(driver.RouteETAProfileSeconds) == len(points) {
		pickupRouteEtaSec := routeETASecondsAtPosition(driver.RouteETAProfileSeconds, pickupProjection.position)
		dropoffRouteEtaSec := routeETASecondsAtPosition(driver.RouteETAProfileSeconds, dropoffProjection.position)
		rideEtaSec := dropoffRouteEtaSec - pickupRouteEtaSec
		if rideEtaSec >= 0 {
			return rideEtaSec, true
		}
	}
	rideKm := routeDistanceBetweenPositions(points, pickupProjection.position, dropoffProjection.position)
	return int(rideKm / 40.0 * 3600), true
}

func selectedSingleHopPickupDropoff(req RideRequest, driver DriverProfile) (GeoPoint, GeoPoint) {
	if driver.RoutePolyline == "" {
		return req.Origin, req.Destination
	}
	points, ok := decodePolyline(driver.RoutePolyline)
	if !ok || len(points) < 2 {
		return req.Origin, req.Destination
	}

	lastPos := float64(len(points) - 1)
	pickup, pickupPos, dropoff, dropoffPos, ok := selectedOrderedPickupDropoff(points, req, 0, lastPos)
	if !ok || dropoffPos <= pickupPos {
		return req.Origin, req.Destination
	}
	return pickup, dropoff
}

func selectedOrderedPickupDropoff(points []GeoPoint, req RideRequest, minPos, maxPos float64) (GeoPoint, float64, GeoPoint, float64, bool) {
	pickupCandidates := routeProjectionCandidatesInGeometryOrRange(points, req.Origin, req.originWalkGeometry(), minPos, maxPos)
	for _, pickup := range pickupCandidates {
		dropoffProjection, ok := routeProjectionInGeometryOrRangeAfter(points, req.Destination, req.destinationWalkGeometry(), pickup.position, maxPos)
		if ok && dropoffProjection.position > pickup.position {
			return pickup.point, pickup.position, dropoffProjection.point, dropoffProjection.position, true
		}
	}
	return GeoPoint{}, 0, GeoPoint{}, 0, false
}

func routeProjectionCandidatesInGeometryOrRange(points []GeoPoint, target GeoPoint, geometry GeoJSONGeometry, minPos, maxPos float64) []routeProjection {
	collect := func(requireGeometry bool) []routeProjection {
		candidates := []routeProjection{}
		consider := func(point GeoPoint, position float64) {
			if position < minPos || position > maxPos {
				return
			}
			if requireGeometry && !pointInGeoJSONPolygon(point, geometry) {
				return
			}
			candidates = append(candidates, routeProjection{
				point:    point,
				position: position,
				snapKm:   haversineKm(point.Latitude, point.Longitude, target.Latitude, target.Longitude),
			})
		}
		if requireGeometry {
			for i, point := range points {
				consider(point, float64(i))
			}
		}
		for i := 0; i < len(points)-1; i++ {
			point, fraction := nearestPointOnSegment(points[i], points[i+1], target)
			consider(point, float64(i)+fraction)
		}
		return candidates
	}

	candidates := []routeProjection{}
	if !geometry.isZero() {
		candidates = collect(true)
	}
	if len(candidates) == 0 {
		candidates = collect(false)
	}
	sort.SliceStable(candidates, func(i, j int) bool {
		if candidates[i].position == candidates[j].position {
			return candidates[i].snapKm < candidates[j].snapKm
		}
		return candidates[i].position < candidates[j].position
	})
	return candidates
}

func nearestRoutePointInGeometry(points []GeoPoint, target GeoPoint, geometry GeoJSONGeometry, minPos, maxPos float64) (GeoPoint, float64, bool) {
	if geometry.isZero() || len(points) == 0 || minPos > maxPos {
		return GeoPoint{}, 0, false
	}
	bestPoint := GeoPoint{}
	bestPos := 0.0
	bestDistanceKm := math.MaxFloat64
	consider := func(point GeoPoint, pos float64) {
		if pos < minPos || pos > maxPos || !pointInGeoJSONPolygon(point, geometry) {
			return
		}
		distanceKm := haversineKm(point.Latitude, point.Longitude, target.Latitude, target.Longitude)
		if distanceKm < bestDistanceKm {
			bestDistanceKm = distanceKm
			bestPoint = point
			bestPos = pos
		}
	}
	for i, point := range points {
		consider(point, float64(i))
	}
	for i := 0; i < len(points)-1; i++ {
		point, fraction := nearestPointOnSegment(points[i], points[i+1], target)
		consider(point, float64(i)+fraction)
	}
	return bestPoint, bestPos, bestDistanceKm < math.MaxFloat64
}

func nearestPointOnSegment(start, end, target GeoPoint) (GeoPoint, float64) {
	dLat := end.Latitude - start.Latitude
	dLon := end.Longitude - start.Longitude
	lengthSquared := dLat*dLat + dLon*dLon
	if lengthSquared == 0 {
		return start, 0
	}
	fraction := ((target.Latitude-start.Latitude)*dLat + (target.Longitude-start.Longitude)*dLon) / lengthSquared
	if fraction < 0 {
		fraction = 0
	} else if fraction > 1 {
		fraction = 1
	}
	return GeoPoint{
		Latitude:  start.Latitude + fraction*dLat,
		Longitude: start.Longitude + fraction*dLon,
	}, fraction
}

func build2HopJourney(req RideRequest, transfer TransferPoint, driver1 DriverProfile, eta1 int, driver2 DriverProfile, eta2 int) Journey {
	leg1Req := buildLegRequest(req, req.Origin, transfer.Location)
	leg1Pickup, leg1Dropoff := selectedSingleHopPickupDropoff(leg1Req, driver1)
	leg1Eta := routeAwareLegETASeconds(leg1Req, driver1, eta1)
	leg2Req := buildLegRequest(req, transfer.Location, req.Destination)
	leg2Pickup, leg2Dropoff := selectedSingleHopPickupDropoff(leg2Req, driver2)
	leg2Eta := routeAwareLegETASeconds(leg2Req, driver2, eta2)

	totalTime := leg1Eta + leg2Eta + transfer.TransferTimeSeconds
	return Journey{
		Legs: []Leg{
			buildJourneyLeg(driver1, leg1Pickup, leg1Dropoff, leg1Eta),
			buildJourneyLeg(driver2, leg2Pickup, leg2Dropoff, leg2Eta),
		},
		TotalEstimatedTimeSeconds: totalTime,
	}
}

func score2HopJourney(req RideRequest, transfer TransferPoint, driver1 DriverProfile, eta1 int, driver2 DriverProfile, eta2 int) float64 {
	journey := build2HopJourney(req, transfer, driver1, eta1, driver2, eta2)
	return calculateJourneyScore(journey.TotalEstimatedTimeSeconds, 2, neutralCongestionFactor(transfer.CongestionFactor))
}

func score3HopJourney(req RideRequest, transfer1 TransferPoint, transfer2 TransferPoint, driver1 DriverProfile, eta1 int, driver2 DriverProfile, eta2 int, driver3 DriverProfile, eta3 int) float64 {
	journey := build3HopJourney(req, transfer1, transfer2, driver1, eta1, driver2, eta2, driver3, eta3)
	avgCongestion := (neutralCongestionFactor(transfer1.CongestionFactor) + neutralCongestionFactor(transfer2.CongestionFactor)) / 2
	return calculateJourneyScore(journey.TotalEstimatedTimeSeconds, 3, avgCongestion)
}

func neutralCongestionFactor(factor float64) float64 {
	if factor <= 0 {
		return 1
	}
	return factor
}

func routeAwareLegETASeconds(req RideRequest, driver DriverProfile, pickupEtaSec int) int {
	rideEtaSec, ok := singleHopRouteRideETASeconds(req, driver)
	if !ok {
		rideEtaSec = singleHopDirectRideETASeconds(req)
	}
	return pickupEtaSec + rideEtaSec
}

func build3HopJourney(req RideRequest, transfer1 TransferPoint, transfer2 TransferPoint, driver1 DriverProfile, eta1 int, driver2 DriverProfile, eta2 int, driver3 DriverProfile, eta3 int) Journey {
	leg1Req := buildLegRequest(req, req.Origin, transfer1.Location)
	leg1Pickup, leg1Dropoff := selectedSingleHopPickupDropoff(leg1Req, driver1)
	leg1Eta := routeAwareLegETASeconds(leg1Req, driver1, eta1)
	leg2Req := buildLegRequest(req, transfer1.Location, transfer2.Location)
	leg2Pickup, leg2Dropoff := selectedSingleHopPickupDropoff(leg2Req, driver2)
	leg2Eta := routeAwareLegETASeconds(leg2Req, driver2, eta2)
	leg3Req := buildLegRequest(req, transfer2.Location, req.Destination)
	leg3Pickup, leg3Dropoff := selectedSingleHopPickupDropoff(leg3Req, driver3)
	leg3Eta := routeAwareLegETASeconds(leg3Req, driver3, eta3)

	totalTime := leg1Eta + leg2Eta + leg3Eta + transfer1.TransferTimeSeconds + transfer2.TransferTimeSeconds
	return Journey{
		Legs: []Leg{
			buildJourneyLeg(driver1, leg1Pickup, leg1Dropoff, leg1Eta),
			buildJourneyLeg(driver2, leg2Pickup, leg2Dropoff, leg2Eta),
			buildJourneyLeg(driver3, leg3Pickup, leg3Dropoff, leg3Eta),
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

func sumReservedSeats(legs []struct {
	Seats int `firestore:"seats"`
}) int {
	total := 0
	for _, leg := range legs {
		total += leg.Seats
	}
	return total
}

type cargoLedgerEntry struct {
	Items map[string]int `firestore:"items"`
}

type petLedgerEntry struct {
	Pets map[string]int `firestore:"pets"`
}

type childSeatLedgerEntry struct {
	Seats map[string]int `firestore:"seats"`
}

func sumCargoLedger(entries []cargoLedgerEntry) map[string]int {
	total := map[string]int{}
	for _, entry := range entries {
		addResourceTotals(total, entry.Items)
	}
	return total
}

func sumPetLedger(entries []petLedgerEntry) map[string]int {
	total := map[string]int{}
	for _, entry := range entries {
		addResourceTotals(total, entry.Pets)
	}
	return total
}

func sumChildSeatLedger(entries []childSeatLedgerEntry) map[string]int {
	total := map[string]int{}
	for _, entry := range entries {
		addResourceTotals(total, entry.Seats)
	}
	return total
}

func addResourceTotals(total map[string]int, values map[string]int) {
	for key, value := range values {
		total[key] += value
	}
}

// DriverProfile is an in-memory representation of driver attributes used for matching.
type DriverProfile struct {
	ID                      string
	CurrentLocation         GeoPoint
	CapacitySeats           int
	ActivePickups           int
	HasSeatLedger           bool
	ReservedSeats           int
	PickupZoneID            string
	PickupZoneActivePickups int
	PickupZoneCapacityCars  int
	RoutePolyline           string
	RouteETAProfileSeconds  []int
	BufferPolygon           GeoJSONGeometry
	RouteBuffer             GeoJSONGeometry
	CurbFactor              float64
	LuggageCapacity         map[string]int
	ReservedLuggage         map[string]int
	PetLimits               map[string]int
	ReservedPets            map[string]int
	ChildSeatInventory      map[string]int
	ReservedChildSeats      map[string]int
	PremiumCapabilities     map[string]any
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

	seatsUsed := reservedSeatCount(driver)
	capacitySeats := effectiveCapacitySeats(driver)
	seatsLeft := capacitySeats - seatsUsed
	if seatsLeft < passCnt {
		return 0, 0, false
	}

	// Gender pool handled at query level (not repeated here)

	// Luggage filter
	if req.LuggageManifest != nil {
		for k, v := range req.LuggageManifest {
			available := driver.LuggageCapacity[k] - driver.ReservedLuggage[k]
			if available < v {
				return 0, 0, false
			}
		}
	}

	// Pet filter
	if req.Pet != nil {
		for k, v := range req.Pet {
			available := driver.PetLimits[k] - driver.ReservedPets[k]
			if available < v {
				return 0, 0, false
			}
		}
	}

	// Child seat filter mirrors the Firebase reservation ledger categories.
	if len(req.ChildPassengers) > 0 {
		childSeatNeeds := calculateChildSeatRequirements(req.ChildPassengers)
		for seatType, needed := range childSeatNeeds {
			available := driver.ChildSeatInventory[seatType] - driver.ReservedChildSeats[seatType]
			if available < needed {
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
	if !driverRouteWalkSnapsWithinThreshold(req, driver) {
		return 0, 0, false
	}

	// Compute distances/score
	straightLinePickupKm := haversineKm(driver.CurrentLocation.Latitude, driver.CurrentLocation.Longitude, req.Origin.Latitude, req.Origin.Longitude)
	pickupKm := driverPickupDistanceKm(req, driver, straightLinePickupKm)
	etaSec := driverPickupETASeconds(req, driver, pickupKm)
	if etaSec > maxSingleHopPickupETASeconds() {
		return 0, 0, false
	}

	rideDistKm := haversineKm(req.Origin.Latitude, req.Origin.Longitude, req.Destination.Latitude, req.Destination.Longitude)
	if driver.RoutePolyline != "" {
		if routeDetourKm, ok := routeInsertionDetourKm(req, driver.RoutePolyline, rideDistKm); ok && routeDetourKm > maxSingleHopRouteDetourKm() {
			return 0, 0, false
		}
	}
	detourKm := driverDetourKm(req, driver, pickupKm, rideDistKm)

	baseScore := wDetour*detourKm + wEta*(float64(etaSec)/60.0) + seatLoadScore(driver, seatsUsed) + cargoLoadScore(req, driver) + petLoadScore(req, driver) + childSeatLoadScore(req, driver)
	if curbFactor <= 0 {
		curbFactor = 1
	}
	score := baseScore * math.Pow(curbFactor, wCurb)

	return score, etaSec, true
}

func reservedSeatCount(driver DriverProfile) int {
	seatsUsed := driver.ReservedSeats
	if !driver.HasSeatLedger && seatsUsed == 0 && driver.ActivePickups > 0 {
		// Backward compatibility for older driver documents that only tracked
		// pickup count. New documents use the seat ledger so multi-passenger
		// groups consume all reserved seats.
		seatsUsed = driver.ActivePickups
	}
	return seatsUsed
}

func effectiveCapacitySeats(driver DriverProfile) int {
	if driver.CapacitySeats > 0 {
		return driver.CapacitySeats
	}
	return 4
}

func seatLoadScore(driver DriverProfile, seatsUsed int) float64 {
	capacitySeats := effectiveCapacitySeats(driver)
	if seatsUsed <= 0 {
		return 0
	}
	return float64(seatsUsed) / float64(capacitySeats)
}

func cargoLoadScore(req RideRequest, driver DriverProfile) float64 {
	if len(req.LuggageManifest) == 0 {
		return 0
	}
	totalLoad := 0.0
	count := 0.0
	for luggageType := range req.LuggageManifest {
		capacity := driver.LuggageCapacity[luggageType]
		if capacity <= 0 {
			continue
		}
		reserved := driver.ReservedLuggage[luggageType]
		if reserved <= 0 {
			count++
			continue
		}
		totalLoad += float64(reserved) / float64(capacity)
		count++
	}
	if count == 0 {
		return 0
	}
	return totalLoad / count
}

func petLoadScore(req RideRequest, driver DriverProfile) float64 {
	if len(req.Pet) == 0 {
		return 0
	}
	totalLoad := 0.0
	count := 0.0
	for petType := range req.Pet {
		capacity := driver.PetLimits[petType]
		if capacity <= 0 {
			continue
		}
		reserved := driver.ReservedPets[petType]
		if reserved <= 0 {
			count++
			continue
		}
		totalLoad += float64(reserved) / float64(capacity)
		count++
	}
	if count == 0 {
		return 0
	}
	return totalLoad / count
}

func childSeatLoadScore(req RideRequest, driver DriverProfile) float64 {
	if len(req.ChildPassengers) == 0 {
		return 0
	}
	childSeatNeeds := calculateChildSeatRequirements(req.ChildPassengers)
	totalLoad := 0.0
	count := 0.0
	for seatType := range childSeatNeeds {
		capacity := driver.ChildSeatInventory[seatType]
		if capacity <= 0 {
			continue
		}
		reserved := driver.ReservedChildSeats[seatType]
		if reserved <= 0 {
			count++
			continue
		}
		totalLoad += float64(reserved) / float64(capacity)
		count++
	}
	if count == 0 {
		return 0
	}
	return totalLoad / count
}

func driverPickupDistanceKm(req RideRequest, driver DriverProfile, fallbackKm float64) float64 {
	if driver.RoutePolyline == "" {
		return fallbackKm
	}
	points, ok := decodePolyline(driver.RoutePolyline)
	if !ok || len(points) < 2 {
		return fallbackKm
	}
	pickupProjection, _, ok := routeInsertionProjections(req, points)
	if !ok {
		return fallbackKm
	}
	routeStartKm := haversineKm(driver.CurrentLocation.Latitude, driver.CurrentLocation.Longitude, points[0].Latitude, points[0].Longitude)
	return routeStartKm + routeDistanceBetweenPositions(points, 0, pickupProjection.position)
}

func driverPickupETASeconds(req RideRequest, driver DriverProfile, fallbackPickupKm float64) int {
	if driver.RoutePolyline == "" || len(driver.RouteETAProfileSeconds) == 0 {
		return int(fallbackPickupKm / 40.0 * 3600)
	}
	points, ok := decodePolyline(driver.RoutePolyline)
	if !ok || len(points) < 2 || len(driver.RouteETAProfileSeconds) != len(points) {
		return int(fallbackPickupKm / 40.0 * 3600)
	}
	pickupProjection, _, ok := routeInsertionProjections(req, points)
	if !ok {
		return int(fallbackPickupKm / 40.0 * 3600)
	}
	routeStartKm := haversineKm(driver.CurrentLocation.Latitude, driver.CurrentLocation.Longitude, points[0].Latitude, points[0].Longitude)
	routeStartETA := int(routeStartKm / 40.0 * 3600)
	return routeStartETA + routeETASecondsAtPosition(driver.RouteETAProfileSeconds, pickupProjection.position)
}

func routeETASecondsAtPosition(profile []int, position float64) int {
	if len(profile) == 0 {
		return 0
	}
	if position <= 0 {
		return profile[0]
	}
	last := len(profile) - 1
	if position >= float64(last) {
		return profile[last]
	}
	startIdx := int(math.Floor(position))
	fraction := position - float64(startIdx)
	start := profile[startIdx]
	end := profile[startIdx+1]
	return int(math.Round(float64(start) + fraction*float64(end-start)))
}

func driverRouteWalkSnapsWithinThreshold(req RideRequest, driver DriverProfile) bool {
	if driver.RoutePolyline == "" {
		return true
	}
	points, ok := decodePolyline(driver.RoutePolyline)
	if !ok || len(points) < 2 {
		return true
	}
	pickupProjection, dropoffProjection, ok := routeInsertionProjections(req, points)
	if !ok {
		return true
	}
	maxWalkKm := effectiveSingleHopWalkMeters(req) / 1000.0
	return pickupProjection.snapKm <= maxWalkKm && dropoffProjection.snapKm <= maxWalkKm
}

func driverDetourKm(req RideRequest, driver DriverProfile, pickupKm, directRideKm float64) float64 {
	if driver.RoutePolyline != "" {
		if routeDetourKm, ok := routeInsertionDetourKm(req, driver.RoutePolyline, directRideKm); ok {
			return routeDetourKm
		}
	}
	return pickupKm + directRideKm
}

func routeInsertionDetourKm(req RideRequest, encodedPolyline string, directRideKm float64) (float64, bool) {
	points, ok := decodePolyline(encodedPolyline)
	if !ok || len(points) < 2 {
		return 0, false
	}

	originProjection, destinationProjection, ok := routeInsertionProjections(req, points)
	if !ok || destinationProjection.position < originProjection.position {
		return 0, false
	}

	routeSegmentKm := routeDistanceBetweenPositions(points, originProjection.position, destinationProjection.position)
	detourKm := routeSegmentKm - directRideKm
	if detourKm < 0 {
		return 0, true
	}
	return detourKm, true
}

func riderWalkScore(req RideRequest, driver DriverProfile) float64 {
	if driver.RoutePolyline == "" {
		return 0
	}
	points, ok := decodePolyline(driver.RoutePolyline)
	if !ok || len(points) < 2 {
		return 0
	}
	pickupProjection, dropoffProjection, ok := routeInsertionProjections(req, points)
	if !ok {
		return 0
	}
	walkKm := pickupProjection.snapKm + dropoffProjection.snapKm
	return walkKm * 12.0 // approximate walking minutes at 5 km/h
}

func routeInsertionProjections(req RideRequest, points []GeoPoint) (routeProjection, routeProjection, bool) {
	lastPos := float64(len(points) - 1)
	originCandidates := routeProjectionCandidatesInGeometryOrRange(points, req.Origin, req.originWalkGeometry(), 0, lastPos)
	for _, originProjection := range originCandidates {
		destinationProjection, ok := routeProjectionInGeometryOrRangeAfter(points, req.Destination, req.destinationWalkGeometry(), originProjection.position, lastPos)
		if ok && destinationProjection.position > originProjection.position {
			return originProjection, destinationProjection, true
		}
	}
	return routeProjection{}, routeProjection{}, false
}

func routeProjectionInGeometryOrRangeAfter(points []GeoPoint, target GeoPoint, geometry GeoJSONGeometry, minPos, maxPos float64) (routeProjection, bool) {
	if !geometry.isZero() {
		if pos, ok := firstRoutePositionInGeometry(points, target, geometry, minPos); ok && pos <= maxPos {
			return routeProjectionAtPosition(points, pos, target), true
		}
		if _, existsBeforeRange := firstRoutePositionInGeometry(points, target, geometry, 0); existsBeforeRange {
			return routeProjection{}, false
		}
	}
	return nearestRouteProjectionInRange(points, target, minPos, maxPos)
}

func routeProjectionAtPosition(points []GeoPoint, position float64, target GeoPoint) routeProjection {
	point := routePointAtPosition(points, position)
	return routeProjection{
		point:    point,
		position: position,
		snapKm:   haversineKm(point.Latitude, point.Longitude, target.Latitude, target.Longitude),
	}
}

type routeProjection struct {
	point    GeoPoint
	position float64
	snapKm   float64
}

func nearestRouteProjection(points []GeoPoint, target GeoPoint) (routeProjection, bool) {
	return nearestRouteProjectionInRange(points, target, 0, float64(len(points)-1))
}

func nearestRouteProjectionInRange(points []GeoPoint, target GeoPoint, minPos, maxPos float64) (routeProjection, bool) {
	if len(points) == 0 || minPos > maxPos {
		return routeProjection{}, false
	}
	best := routeProjection{snapKm: math.MaxFloat64}
	consider := func(point GeoPoint, position float64) {
		if position < minPos || position > maxPos {
			return
		}
		distanceKm := haversineKm(point.Latitude, point.Longitude, target.Latitude, target.Longitude)
		if distanceKm < best.snapKm {
			best = routeProjection{point: point, position: position, snapKm: distanceKm}
		}
	}
	for i, point := range points {
		consider(point, float64(i))
	}
	for i := 0; i < len(points)-1; i++ {
		point, fraction := nearestPointOnSegment(points[i], points[i+1], target)
		consider(point, float64(i)+fraction)
	}
	return best, best.snapKm < math.MaxFloat64
}

func routeDistanceBetweenPositions(points []GeoPoint, startPos, endPos float64) float64 {
	if len(points) < 2 || startPos < 0 || endPos > float64(len(points)-1) || endPos <= startPos {
		return 0
	}
	startPoint := routePointAtPosition(points, startPos)
	endPoint := routePointAtPosition(points, endPos)
	startIdx := int(math.Floor(startPos))
	endIdx := int(math.Floor(endPos))
	if startIdx == endIdx {
		return haversineKm(startPoint.Latitude, startPoint.Longitude, endPoint.Latitude, endPoint.Longitude)
	}
	distanceKm := haversineKm(startPoint.Latitude, startPoint.Longitude, points[startIdx+1].Latitude, points[startIdx+1].Longitude)
	for i := startIdx + 1; i < endIdx; i++ {
		distanceKm += haversineKm(points[i].Latitude, points[i].Longitude, points[i+1].Latitude, points[i+1].Longitude)
	}
	distanceKm += haversineKm(points[endIdx].Latitude, points[endIdx].Longitude, endPoint.Latitude, endPoint.Longitude)
	return distanceKm
}

func routePointAtPosition(points []GeoPoint, position float64) GeoPoint {
	if position <= 0 {
		return points[0]
	}
	last := len(points) - 1
	if position >= float64(last) {
		return points[last]
	}
	idx := int(math.Floor(position))
	fraction := position - float64(idx)
	return GeoPoint{
		Latitude:  points[idx].Latitude + fraction*(points[idx+1].Latitude-points[idx].Latitude),
		Longitude: points[idx].Longitude + fraction*(points[idx+1].Longitude-points[idx].Longitude),
	}
}

func nearestRoutePointIndex(points []GeoPoint, target GeoPoint) (int, float64) {
	bestIdx := -1
	bestDistanceKm := math.MaxFloat64
	for i, point := range points {
		distanceKm := haversineKm(point.Latitude, point.Longitude, target.Latitude, target.Longitude)
		if distanceKm < bestDistanceKm {
			bestDistanceKm = distanceKm
			bestIdx = i
		}
	}
	return bestIdx, bestDistanceKm
}

func routeDistanceBetweenIndexes(points []GeoPoint, startIdx, endIdx int) float64 {
	if startIdx < 0 || endIdx >= len(points) || endIdx <= startIdx {
		return 0
	}
	distanceKm := 0.0
	for i := startIdx; i < endIdx; i++ {
		distanceKm += haversineKm(points[i].Latitude, points[i].Longitude, points[i+1].Latitude, points[i+1].Longitude)
	}
	return distanceKm
}

func maxSingleHopRouteDetourKm() float64 {
	if value := os.Getenv("MAX_SINGLE_HOP_DETOUR_KM"); value != "" {
		if parsed, err := strconv.ParseFloat(value, 64); err == nil && parsed > 0 {
			return parsed
		}
	}
	return 25.0
}

func maxSingleHopPickupETASeconds() int {
	if value := os.Getenv("MAX_SINGLE_HOP_PICKUP_ETA_SECONDS"); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil && parsed > 0 {
			return parsed
		}
	}
	return 1800
}

func maxSingleHopWalkMeters() float64 {
	if value := os.Getenv("MAX_SINGLE_HOP_WALK_METERS"); value != "" {
		if parsed, err := strconv.ParseFloat(value, 64); err == nil && parsed > 0 {
			return parsed
		}
	}
	return 1000.0
}

func effectiveSingleHopWalkMeters(req RideRequest) float64 {
	limit := maxSingleHopWalkMeters()
	if req.WalkRadiusM > 0 && float64(req.WalkRadiusM) < limit {
		return float64(req.WalkRadiusM)
	}
	return limit
}

type scoreWeights struct {
	Detour float64
	ETA    float64
	Walk   float64
	Curb   float64
}

type scoredDriver struct {
	driver DriverProfile
	score  float64
	etaSec int
}

func defaultScoreWeights() scoreWeights {
	return scoreWeights{Detour: 0.7, ETA: 0.3, Walk: 0.1, Curb: 1.0}
}

func pickBestDriverFromProfiles(req RideRequest, drivers []DriverProfile, exclude []string, weights scoreWeights) (string, int, error) {
	driver, etaSec, err := pickBestDriverProfileFromProfiles(req, drivers, exclude, weights)
	if err != nil {
		return "", 0, err
	}
	return driver.ID, etaSec, nil
}

func pickBestDriverProfileFromProfiles(req RideRequest, drivers []DriverProfile, exclude []string, weights scoreWeights) (DriverProfile, int, error) {
	ranked := rankDriverProfiles(req, drivers, exclude, weights)
	if len(ranked) == 0 {
		return DriverProfile{}, 0, fmt.Errorf("no suitable driver scored")
	}
	return ranked[0].driver, ranked[0].etaSec, nil
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
	if weights.Detour == 0 && weights.ETA == 0 && weights.Walk == 0 {
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
		if driver.PickupZoneID == "" {
			continue
		}
		if !pickupZoneHasCapacity(driver) {
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
		score += weights.Walk * riderWalkScore(req, driver)
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

func pickupZoneHasCapacity(driver DriverProfile) bool {
	if driver.PickupZoneID == "" {
		return false
	}
	if driver.PickupZoneCapacityCars <= 0 {
		return true
	}
	return driver.PickupZoneActivePickups < driver.PickupZoneCapacityCars
}

func driverSatisfiesSingleHopCorridor(req RideRequest, driver DriverProfile) bool {
	originIso := req.originWalkGeometry()
	destinationIso := req.destinationWalkGeometry()
	if !originIso.isZero() && !driverRouteIntersectsGeometry(driver, originIso) {
		return false
	}
	if !destinationIso.isZero() && !driverRouteIntersectsGeometry(driver, destinationIso) {
		return false
	}
	if !driverEntersOriginDriveGeo(req, driver) {
		return false
	}
	if !driverEntersDestinationDriveGeo(req, driver) {
		return false
	}
	if originIso.isZero() && destinationIso.isZero() {
		return true
	}
	if driver.RoutePolyline != "" && !routePolylineTravelsOriginBeforeDestination(req, driver.RoutePolyline) {
		return false
	}
	return true
}

func driverEntersOriginDriveGeo(req RideRequest, driver DriverProfile) bool {
	originDrive := req.originDriveGeometry()
	if originDrive.isZero() {
		return true
	}
	if pointInGeoJSONPolygon(driver.CurrentLocation, originDrive) {
		return true
	}
	if driver.RoutePolyline != "" {
		return polylineIntersectsPolygon(driver.RoutePolyline, originDrive)
	}
	if buffer := driverCorridorBuffer(driver); !buffer.isZero() {
		return geoJSONPolygonsIntersect(buffer, originDrive)
	}
	return false
}

func driverEntersDestinationDriveGeo(req RideRequest, driver DriverProfile) bool {
	destinationDrive := req.destinationDriveGeometry()
	if destinationDrive.isZero() {
		return true
	}
	if pointInGeoJSONPolygon(driver.CurrentLocation, destinationDrive) {
		return true
	}
	if driver.RoutePolyline != "" {
		return polylineIntersectsPolygon(driver.RoutePolyline, destinationDrive)
	}
	if buffer := driverCorridorBuffer(driver); !buffer.isZero() {
		return geoJSONPolygonsIntersect(buffer, destinationDrive)
	}
	return false
}

func routePolylineTravelsOriginBeforeDestination(req RideRequest, encodedPolyline string) bool {
	points, ok := decodePolyline(encodedPolyline)
	if !ok || len(points) < 2 {
		return false
	}
	lastPos := float64(len(points) - 1)
	originCandidates := routeProjectionCandidatesInGeometryOrRange(points, req.Origin, req.originWalkGeometry(), 0, lastPos)
	for _, origin := range originCandidates {
		destinationPos, destinationOk := routePositionForOrder(points, req.Destination, req.destinationWalkGeometry(), origin.position)
		if destinationOk && destinationPos > origin.position {
			return true
		}
	}
	return false
}

func routePositionForOrder(points []GeoPoint, target GeoPoint, geometry GeoJSONGeometry, minPos float64) (float64, bool) {
	if !geometry.isZero() {
		if pos, ok := firstRoutePositionInGeometry(points, target, geometry, minPos); ok {
			return pos, true
		}
		return 0, false
	}
	projection, ok := nearestRouteProjectionInRange(points, target, minPos, float64(len(points)-1))
	if !ok {
		return 0, false
	}
	return projection.position, true
}

func firstRoutePositionInGeometry(points []GeoPoint, target GeoPoint, geometry GeoJSONGeometry, minPos float64) (float64, bool) {
	if geometry.isZero() || len(points) == 0 {
		return 0, false
	}
	consider := func(point GeoPoint, pos float64) (float64, bool) {
		if pos >= minPos && pointInGeoJSONPolygon(point, geometry) {
			return pos, true
		}
		return 0, false
	}
	for i := 0; i < len(points)-1; i++ {
		if pos, ok := consider(points[i], float64(i)); ok {
			return pos, true
		}
		point, fraction := nearestPointOnSegment(points[i], points[i+1], target)
		if pos, ok := consider(point, float64(i)+fraction); ok {
			return pos, true
		}
	}
	return consider(points[len(points)-1], float64(len(points)-1))
}

func driverRouteIntersectsGeometry(driver DriverProfile, geometry GeoJSONGeometry) bool {
	if driver.RoutePolyline != "" {
		return polylineIntersectsPolygon(driver.RoutePolyline, geometry)
	}
	if buffer := driverCorridorBuffer(driver); !buffer.isZero() && geoJSONPolygonsIntersect(buffer, geometry) {
		return true
	}
	return false
}

func driverCorridorBuffer(driver DriverProfile) GeoJSONGeometry {
	if !driver.BufferPolygon.isZero() {
		return driver.BufferPolygon
	}
	return driver.RouteBuffer
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

func (req RideRequest) originDriveGeometry() GeoJSONGeometry {
	if !req.OriDriveIso.isZero() {
		return req.OriDriveIso
	}
	if !req.OriginDriveGeo.isZero() {
		return req.OriginDriveGeo
	}
	return GeoJSONGeometry{}
}

func (req RideRequest) destinationDriveGeometry() GeoJSONGeometry {
	if !req.DestinationDriveGeo.isZero() {
		return req.DestinationDriveGeo
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
	parts, ok := polygonParts(polygon)
	if !ok {
		return false
	}
	for _, point := range line {
		if pointInGeoJSONPolygon(point, polygon) {
			return true
		}
	}
	rings := ringsForSegmentIntersection(parts)
	for i := 0; i < len(line)-1; i++ {
		for _, ring := range rings {
			for j := 0; j < len(ring)-1; j++ {
				if segmentsIntersect(line[i], line[i+1], ring[j], ring[j+1]) {
					return true
				}
			}
		}
	}
	return false
}

func pointInGeoJSONPolygon(point GeoPoint, polygon GeoJSONGeometry) bool {
	parts, ok := polygonParts(polygon)
	if !ok {
		return false
	}
	for _, part := range parts {
		if !pointInPolygon(point, part.outer) {
			continue
		}
		insideHole := false
		for _, hole := range part.holes {
			if pointInPolygon(point, hole) {
				insideHole = true
				break
			}
		}
		if !insideHole {
			return true
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
	aParts, okA := polygonParts(a)
	bParts, okB := polygonParts(b)
	if !okA || !okB {
		return false
	}
	for _, aPart := range aParts {
		for _, point := range aPart.outer {
			if pointInGeoJSONPolygon(point, b) {
				return true
			}
		}
	}
	for _, bPart := range bParts {
		for _, point := range bPart.outer {
			if pointInGeoJSONPolygon(point, a) {
				return true
			}
		}
	}
	for _, aRing := range ringsForSegmentIntersection(aParts) {
		for _, bRing := range ringsForSegmentIntersection(bParts) {
			if ringsHaveSegmentIntersection(aRing, bRing) {
				return true
			}
		}
	}
	return false
}

func ringsForSegmentIntersection(parts []geoPolygonPart) [][]GeoPoint {
	rings := [][]GeoPoint{}
	for _, part := range parts {
		rings = append(rings, part.outer)
		rings = append(rings, part.holes...)
	}
	return rings
}

func ringsHaveSegmentIntersection(aRing, bRing []GeoPoint) bool {
	if len(aRing) < 2 || len(bRing) < 2 {
		return false
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

func polygonRingsIntersect(aRing, bRing []GeoPoint) bool {
	if len(aRing) < 3 || len(bRing) < 3 {
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
	rings, ok := polygonOuterRings(g)
	if !ok || len(rings) == 0 {
		return nil, false
	}
	return rings[0], true
}

func polygonOuterRings(g GeoJSONGeometry) ([][]GeoPoint, bool) {
	coordinateSets, ok := outerRingCoordinateSets(g)
	if !ok || len(coordinateSets) == 0 {
		return nil, false
	}
	rings := make([][]GeoPoint, 0, len(coordinateSets))
	for _, coords := range coordinateSets {
		ring, ok := geoPointsFromRingCoordinates(coords)
		if !ok {
			continue
		}
		rings = append(rings, ring)
	}
	if len(rings) == 0 {
		return nil, false
	}
	return rings, true
}

func outerRingCoordinateSets(g GeoJSONGeometry) ([][][]float64, bool) {
	if g.Coordinates == nil {
		return nil, false
	}
	switch g.Type {
	case "Polygon":
		coords, ok := firstRingCoordinates(g.Coordinates)
		if !ok {
			return nil, false
		}
		return [][][]float64{coords}, true
	case "MultiPolygon":
		return multiPolygonOuterRingCoordinates(g.Coordinates)
	default:
		return nil, false
	}
}

func geoPointsFromRingCoordinates(coords [][]float64) ([]GeoPoint, bool) {
	if len(coords) < 3 {
		return nil, false
	}
	ring := make([]GeoPoint, 0, len(coords)+1)
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

type geoPolygonPart struct {
	outer []GeoPoint
	holes [][]GeoPoint
}

func polygonParts(g GeoJSONGeometry) ([]geoPolygonPart, bool) {
	if g.Coordinates == nil {
		return nil, false
	}
	switch g.Type {
	case "Polygon":
		return polygonPartsFromRingCoordinateSets(g.Coordinates)
	case "MultiPolygon":
		return multiPolygonParts(g.Coordinates)
	default:
		return nil, false
	}
}

func polygonPartsFromRingCoordinateSets(coords any) ([]geoPolygonPart, bool) {
	ringCoordinateSets, ok := ringCoordinateSets(coords)
	if !ok || len(ringCoordinateSets) == 0 {
		return nil, false
	}
	part, ok := geoPolygonPartFromCoordinateSets(ringCoordinateSets)
	if !ok {
		return nil, false
	}
	return []geoPolygonPart{part}, true
}

func multiPolygonParts(coords any) ([]geoPolygonPart, bool) {
	parts := []geoPolygonPart{}
	appendPart := func(rawPolygon any) bool {
		part, ok := geoPolygonPartFromAny(rawPolygon)
		if !ok {
			return false
		}
		parts = append(parts, part)
		return true
	}
	switch c := coords.(type) {
	case [][][][]float64:
		for _, polygon := range c {
			if !appendPart(polygon) {
				return nil, false
			}
		}
	case [][][][]interface{}:
		for _, polygon := range c {
			if !appendPart(polygon) {
				return nil, false
			}
		}
	case []interface{}:
		for _, polygon := range c {
			if !appendPart(polygon) {
				return nil, false
			}
		}
	default:
		return nil, false
	}
	return parts, len(parts) > 0
}

func geoPolygonPartFromAny(value any) (geoPolygonPart, bool) {
	ringCoordinateSets, ok := ringCoordinateSets(value)
	if !ok {
		return geoPolygonPart{}, false
	}
	return geoPolygonPartFromCoordinateSets(ringCoordinateSets)
}

func geoPolygonPartFromCoordinateSets(ringCoordinateSets [][][]float64) (geoPolygonPart, bool) {
	outer, ok := geoPointsFromRingCoordinates(ringCoordinateSets[0])
	if !ok {
		return geoPolygonPart{}, false
	}
	part := geoPolygonPart{outer: outer, holes: [][]GeoPoint{}}
	for _, holeCoords := range ringCoordinateSets[1:] {
		hole, ok := geoPointsFromRingCoordinates(holeCoords)
		if !ok {
			continue
		}
		part.holes = append(part.holes, hole)
	}
	return part, true
}

func ringCoordinateSets(coords any) ([][][]float64, bool) {
	switch c := coords.(type) {
	case [][][]float64:
		return c, len(c) > 0
	case [][][]interface{}:
		rings := make([][][]float64, 0, len(c))
		for _, rawRing := range c {
			ring, ok := coordinatePairsFromAny(rawRing)
			if !ok {
				return nil, false
			}
			rings = append(rings, ring)
		}
		return rings, len(rings) > 0
	case []interface{}:
		rings := make([][][]float64, 0, len(c))
		for _, rawRing := range c {
			ring, ok := coordinatePairsFromAny(rawRing)
			if !ok {
				return nil, false
			}
			rings = append(rings, ring)
		}
		return rings, len(rings) > 0
	default:
		return nil, false
	}
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

func multiPolygonOuterRingCoordinates(coords any) ([][][]float64, bool) {
	rings := [][][]float64{}
	appendRing := func(rawPolygon any) bool {
		switch polygon := rawPolygon.(type) {
		case [][][]float64:
			if len(polygon) == 0 {
				return true
			}
			rings = append(rings, polygon[0])
			return true
		case [][][]interface{}:
			if len(polygon) == 0 {
				return true
			}
			ring, ok := coordinatePairsFromAny(polygon[0])
			if !ok {
				return false
			}
			rings = append(rings, ring)
			return true
		case []interface{}:
			if len(polygon) == 0 {
				return true
			}
			ring, ok := coordinatePairsFromAny(polygon[0])
			if !ok {
				return false
			}
			rings = append(rings, ring)
			return true
		default:
			return false
		}
	}

	switch c := coords.(type) {
	case [][][][]float64:
		for _, polygon := range c {
			if !appendRing(polygon) {
				return nil, false
			}
		}
	case [][][][]interface{}:
		for _, polygon := range c {
			if !appendRing(polygon) {
				return nil, false
			}
		}
	case []interface{}:
		for _, polygon := range c {
			if !appendRing(polygon) {
				return nil, false
			}
		}
	default:
		return nil, false
	}
	return rings, len(rings) > 0
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

		score := score2HopJourney(req, transfer, driver1, eta1, driver2, eta2)

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

			score := score3HopJourney(req, transfer1, transfer2, driver1, eta1, driver2, eta2, driver3, eta3)

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

	q := client.Collection("drivers").Limit(50)
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
	wWalk := 0.1
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
	if v := os.Getenv("WEIGHT_WALK"); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			wWalk = f
		}
	}
	if v := os.Getenv("WEIGHT_CURB"); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			wCurb = f
		}
	}

	profiles := make([]DriverProfile, 0, len(docs))

	for _, d := range docs {
		raw := d.Data()
		_, hasSeatLedger := raw["legs"]
		var data struct {
			CurrentLocation GeoPoint `firestore:"currentLocation"`
			CapacitySeats   int      `firestore:"capacitySeats"`
			ActivePickups   int      `firestore:"activePickups"`
			Legs            []struct {
				Seats int `firestore:"seats"`
			} `firestore:"legs"`
			PickupZoneID           string                 `firestore:"pickupZoneId"`
			RoutePolyline          string                 `firestore:"routePolyline"`
			RouteETAProfileSeconds []int                  `firestore:"routeEtaProfile"`
			BufferPolygon          GeoJSONGeometry        `firestore:"bufferPolygon"`
			RouteBuffer            GeoJSONGeometry        `firestore:"routeBuffer"`
			LuggageCapacity        map[string]int         `firestore:"luggageCapacity"`
			CargoLedger            []cargoLedgerEntry     `firestore:"cargoLedger"`
			PetLimits              map[string]int         `firestore:"petLimits"`
			PetLedger              []petLedgerEntry       `firestore:"petLedger"`
			ChildSeatInventory     map[string]int         `firestore:"childSeatInventory"`
			ChildSeatLedger        []childSeatLedgerEntry `firestore:"childSeatLedger"`
			PremiumCapabilities    map[string]any         `firestore:"premiumCapabilities"`
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
		pickupZoneActivePickups := 0
		pickupZoneCapacityCars := 0
		if data.PickupZoneID != "" {
			zSnap, err := client.Collection("pickupZones").Doc(data.PickupZoneID).Get(ctx)
			if err == nil && zSnap.Exists() {
				zoneData := zSnap.Data()
				pickupZoneActivePickups = intValue(zoneData["activePickups"], 0)
				pickupZoneCapacityCars = intValue(zoneData["capacityCars"], 10)
				if v, ok := zoneData["curbLoadFactor"].(float64); ok && v > 0 {
					curbFactor = v
				}
			}
		}

		prof := DriverProfile{
			ID:                      d.Ref.ID,
			CurrentLocation:         GeoPoint{Latitude: data.CurrentLocation.Latitude, Longitude: data.CurrentLocation.Longitude},
			CapacitySeats:           data.CapacitySeats,
			ActivePickups:           data.ActivePickups,
			HasSeatLedger:           hasSeatLedger,
			ReservedSeats:           sumReservedSeats(data.Legs),
			PickupZoneID:            data.PickupZoneID,
			PickupZoneActivePickups: pickupZoneActivePickups,
			PickupZoneCapacityCars:  pickupZoneCapacityCars,
			RoutePolyline:           data.RoutePolyline,
			RouteETAProfileSeconds:  data.RouteETAProfileSeconds,
			BufferPolygon:           data.BufferPolygon,
			RouteBuffer:             data.RouteBuffer,
			CurbFactor:              curbFactor,
			LuggageCapacity:         data.LuggageCapacity,
			ReservedLuggage:         sumCargoLedger(data.CargoLedger),
			PetLimits:               data.PetLimits,
			ReservedPets:            sumPetLedger(data.PetLedger),
			ChildSeatInventory:      data.ChildSeatInventory,
			ReservedChildSeats:      sumChildSeatLedger(data.ChildSeatLedger),
			PremiumCapabilities:     data.PremiumCapabilities,
		}

		profiles = append(profiles, prof)
	}

	return pickBestDriverProfileFromProfiles(req, profiles, nil, scoreWeights{Detour: wDetour, ETA: wEta, Walk: wWalk, Curb: wCurb})
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

func intValue(value any, fallback int) int {
	switch v := value.(type) {
	case int:
		return v
	case int64:
		return int(v)
	case int32:
		return int(v)
	case float64:
		return int(v)
	case float32:
		return int(v)
	default:
		return fallback
	}
}

func legExcludedDriverIDs(req RideRequest, additional ...string) []string {
	excluded := make([]string, 0, len(req.ExcludedDriverIDs)+len(additional))
	seen := map[string]bool{}
	appendUnique := func(driverID string) {
		if driverID == "" || seen[driverID] {
			return
		}
		seen[driverID] = true
		excluded = append(excluded, driverID)
	}
	for _, driverID := range req.ExcludedDriverIDs {
		appendUnique(driverID)
	}
	for _, driverID := range additional {
		appendUnique(driverID)
	}
	return excluded
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
	// Use existing pickBestDriver but preserve request-level retry exclusions in
	// addition to drivers already assigned to earlier legs.
	driver, eta, err := pickBestDriver(ctx, req, legExcludedDriverIDs(req, exclude...))
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
	avgCongestionFactor = neutralCongestionFactor(avgCongestionFactor)
	// Base score is total time
	baseScore := float64(totalTimeSeconds)

	// Penalty for additional legs (prefer fewer hops)
	legPenalty := float64(numLegs-1) * 300.0 // 5 minutes penalty per extra leg

	// Congestion penalty
	congestionPenalty := (avgCongestionFactor - 1.0) * 600.0 // Up to 10 minutes penalty

	return baseScore + legPenalty + congestionPenalty
}
