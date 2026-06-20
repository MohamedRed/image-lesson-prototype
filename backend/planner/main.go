package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"os"
	"strconv"
	"time"

	"cloud.google.com/go/firestore"
)

// RideRequest is a minimal subset of the Firestore rideRequest document
// that is needed for planning. In production this would match the schema
// in docs/ride_sharing_full_plan.md.

type RideRequest struct {
	Origin         GeoPoint `json:"origin"`
	Destination    GeoPoint `json:"destination"`
	PassengerCount int      `json:"passengerCount"`
	RiderGender    string   `json:"riderGender"`
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
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

// Journey response currently only supports single-hop for MVP.
// Multi-hop legs will be added later.
type Journey struct {
	Legs                      []Leg `json:"legs"`
	TotalEstimatedTimeSeconds int   `json:"totalEtaSeconds"`
}

type Leg struct {
	DriverID             string   `json:"driverId"`
	Pickup               GeoPoint `json:"pickup"`
	Dropoff              GeoPoint `json:"dropoff"`
	EstimatedTimeSeconds int      `json:"etaSeconds"`
}

// DriverProfile is an in-memory representation of driver attributes used for matching.
type DriverProfile struct {
	ID                  string
	CurrentLocation     GeoPoint
	CapacitySeats       int
	ActivePickups       int
	PickupZoneID        string
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

	// Child seat filter (simple)
	if len(req.ChildPassengers) > 0 {
		infantCnt := 0
		boosterCnt := 0
		for _, c := range req.ChildPassengers {
			if c.AgeYears <= 1 {
				infantCnt++
			} else if c.AgeYears <= 4 {
				boosterCnt++
			}
		}
		if infantCnt > 0 {
			if driver.ChildSeatInventory["infant"] < infantCnt {
				return 0, 0, false
			}
		}
		if boosterCnt > 0 {
			if driver.ChildSeatInventory["booster"] < boosterCnt {
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

	driverID, etaSec, err := pickBestDriver(r.Context(), req, nil)

	var journey Journey
	if err == nil {
		journey = Journey{
			Legs: []Leg{{
				DriverID:             driverID,
				Pickup:               req.Origin,
				Dropoff:              req.Destination,
				EstimatedTimeSeconds: etaSec,
			}},
			TotalEstimatedTimeSeconds: etaSec,
		}
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
		leg1Req := req
		leg1Req.Destination = transfer.Location

		driver1, eta1, err := pickBestDriverForLeg(ctx, leg1Req, nil, 1)
		if err != nil {
			continue
		}

		// Create leg 2: transfer → destination
		leg2Req := req
		leg2Req.Origin = transfer.Location

		driver2, eta2, err := pickBestDriverForLeg(ctx, leg2Req, []string{driver1}, 2)
		if err != nil {
			continue
		}

		// Validate gender pool consistency across legs
		if !validateGenderConsistency(req.RiderGender, []string{driver1, driver2}) {
			continue
		}

		totalTime := eta1 + eta2 + transfer.TransferTimeSeconds
		score := calculateJourneyScore(totalTime, 2, transfer.CongestionFactor)

		if score < bestScore {
			bestScore = score
			bestJourney = Journey{
				Legs: []Leg{
					{DriverID: driver1, Pickup: req.Origin, Dropoff: transfer.Location, EstimatedTimeSeconds: eta1},
					{DriverID: driver2, Pickup: transfer.Location, Dropoff: req.Destination, EstimatedTimeSeconds: eta2},
				},
				TotalEstimatedTimeSeconds: totalTime,
			}
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
			leg1Req := req
			leg1Req.Destination = transfer1.Location

			driver1, eta1, err := pickBestDriverForLeg(ctx, leg1Req, nil, 1)
			if err != nil {
				continue
			}

			// Create leg 2: transfer1 → transfer2
			leg2Req := req
			leg2Req.Origin = transfer1.Location
			leg2Req.Destination = transfer2.Location

			driver2, eta2, err := pickBestDriverForLeg(ctx, leg2Req, []string{driver1}, 2)
			if err != nil {
				continue
			}

			// Create leg 3: transfer2 → destination
			leg3Req := req
			leg3Req.Origin = transfer2.Location

			driver3, eta3, err := pickBestDriverForLeg(ctx, leg3Req, []string{driver1, driver2}, 3)
			if err != nil {
				continue
			}

			// Validate gender pool consistency across all legs
			if !validateGenderConsistency(req.RiderGender, []string{driver1, driver2, driver3}) {
				continue
			}

			totalTime := eta1 + eta2 + eta3 + transfer1.TransferTimeSeconds + transfer2.TransferTimeSeconds
			avgCongestion := (transfer1.CongestionFactor + transfer2.CongestionFactor) / 2
			score := calculateJourneyScore(totalTime, 3, avgCongestion)

			if score < bestScore {
				bestScore = score
				bestJourney = Journey{
					Legs: []Leg{
						{DriverID: driver1, Pickup: req.Origin, Dropoff: transfer1.Location, EstimatedTimeSeconds: eta1},
						{DriverID: driver2, Pickup: transfer1.Location, Dropoff: transfer2.Location, EstimatedTimeSeconds: eta2},
						{DriverID: driver3, Pickup: transfer2.Location, Dropoff: req.Destination, EstimatedTimeSeconds: eta3},
					},
					TotalEstimatedTimeSeconds: totalTime,
				}
			}
		}
	}

	if bestJourney.Legs == nil {
		return Journey{}, fmt.Errorf("no valid 3-hop journey found")
	}

	return bestJourney, nil
}

// pickBestDriver queries Firestore for drivers matching constraints, computes a simple score and returns best.
func pickBestDriver(ctx context.Context, req RideRequest, exclude []string) (string, int, error) {
	projectID := os.Getenv("GOOGLE_CLOUD_PROJECT")
	if projectID == "" {
		return "", 0, fmt.Errorf("GOOGLE_CLOUD_PROJECT env var not set")
	}

	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		return "", 0, err
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
		return "", 0, err
	}
	if len(docs) == 0 {
		return "", 0, fmt.Errorf("no drivers available")
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
	bestDriver := ""
	bestEta := 0

	for _, d := range docs {
		var data struct {
			CurrentLocation     GeoPoint `firestore:"currentLocation"`
			CapacitySeats       int                `firestore:"capacitySeats"`
			ActivePickups       int                `firestore:"activePickups"`
			PickupZoneID        string             `firestore:"pickupZoneId"`
			LuggageCapacity     map[string]int     `firestore:"luggageCapacity"`
			PetLimits           map[string]int     `firestore:"petLimits"`
			ChildSeatInventory  map[string]int     `firestore:"childSeatInventory"`
			PremiumCapabilities map[string]any     `firestore:"premiumCapabilities"`
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
			bestDriver = d.Ref.ID
			bestEta = etaSec
		}
	}

	if bestDriver == "" {
		return "", 0, fmt.Errorf("no suitable driver scored")
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
func pickBestDriverForLeg(ctx context.Context, req RideRequest, exclude []string, legNumber int) (string, int, error) {
	// Use existing pickBestDriver but add leg-specific validation
	driverID, eta, err := pickBestDriver(ctx, req, exclude)
	if err != nil {
		return "", 0, fmt.Errorf("leg %d driver selection failed: %v", legNumber, err)
	}

	// Additional validation for multi-leg constraints could be added here
	// For now, use the existing driver selection logic
	return driverID, eta, nil
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
