package main

import (
	"encoding/json"
	"math"
	"net/http"
	"net/http/httptest"
	"os"
	"reflect"
	"strings"
	"testing"

	"google.golang.org/genproto/googleapis/type/latlng"
)

func TestRegisterPlannerRoutes_HealthEndpointReturnsOK(t *testing.T) {
	mux := http.NewServeMux()
	registerPlannerRoutes(mux)

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/health", nil)
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected /health to return 200 OK, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if strings.TrimSpace(recorder.Body.String()) != "ok" {
		t.Fatalf("expected /health body to be ok, got %q", recorder.Body.String())
	}
}

func TestPlannerDockerfileProductionContract(t *testing.T) {
	content, err := os.ReadFile("Dockerfile")
	if err != nil {
		t.Fatalf("planner service must include backend/planner/Dockerfile for docker-compose and Cloud Run image builds: %v", err)
	}
	text := string(content)
	checks := map[string]string{
		"multi-stage Go build":      "FROM golang:",
		"distroless runtime":        "FROM gcr.io/distroless/",
		"Cloud Run port exposure":   "EXPOSE 8080",
		"non-root runtime user":     "USER nonroot:nonroot",
		"planner binary entrypoint": "ENTRYPOINT [\"/planner\"]",
	}
	for name, needle := range checks {
		if !strings.Contains(text, needle) {
			t.Fatalf("Dockerfile missing %s contract %q", name, needle)
		}
	}
}

func TestPlanHandlerRejectsTrailingJSONBeforePlanning(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	body := `{"origin":{"latitude":1,"longitude":2},"destination":{"latitude":3,"longitude":4},"passengerCount":1} {"extra":true}`

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/plan", strings.NewReader(body))
	planHandler(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected malformed trailing JSON to return 400 before planner execution, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "invalid JSON") {
		t.Fatalf("expected invalid JSON error, got %q", recorder.Body.String())
	}
}

func TestPlanHandlerRejectsOversizedRequestBeforePlanning(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	body := `{"origin":{"latitude":1,"longitude":2},"destination":{"latitude":3,"longitude":4},"passengerCount":1,"ignored":"` + strings.Repeat("x", 1<<20) + `"}`

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/plan", strings.NewReader(body))
	planHandler(recorder, request)

	if recorder.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("expected oversized planner request to return 413 before planner execution, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "request body too large") {
		t.Fatalf("expected request body too large error, got %q", recorder.Body.String())
	}
}

func TestPlanHandlerRejectsNonPositivePassengerCountBeforePlanning(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	body := `{"origin":{"latitude":1,"longitude":2},"destination":{"latitude":3,"longitude":4},"passengerCount":0}`

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/plan", strings.NewReader(body))
	planHandler(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected non-positive passengerCount to return 400 before planner execution, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "invalid request") {
		t.Fatalf("expected invalid request error, got %q", recorder.Body.String())
	}
}

func TestPlanHandlerRejectsPassengerCountAboveClientRulesBeforePlanning(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	body := `{"origin":{"latitude":1,"longitude":2},"destination":{"latitude":3,"longitude":4},"passengerCount":7}`

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/plan", strings.NewReader(body))
	planHandler(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected passengerCount above client rules to return 400 before planner execution, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "invalid request") {
		t.Fatalf("expected invalid request error, got %q", recorder.Body.String())
	}
}

func TestPlanHandlerRejectsOutOfRangeCoordinatesBeforePlanning(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	body := `{"origin":{"latitude":91,"longitude":2},"destination":{"latitude":3,"longitude":4},"passengerCount":1}`

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/plan", strings.NewReader(body))
	planHandler(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected out-of-range origin latitude to return 400 before planner execution, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "invalid request") {
		t.Fatalf("expected invalid request error, got %q", recorder.Body.String())
	}
}

func TestPlanHandlerRejectsUnauthorizedPaymentBeforePlanning(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	body := `{"origin":{"latitude":1,"longitude":2},"destination":{"latitude":3,"longitude":4},"passengerCount":1,"requiresPaymentAuthorization":true,"paymentAuthorized":false}`

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/plan", strings.NewReader(body))
	planHandler(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected unauthorized required payment to return 400 before planner execution, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "invalid request") {
		t.Fatalf("expected invalid request error, got %q", recorder.Body.String())
	}
}

func TestPlanHandlerRejectsUnverifiedRequiredIdentityBeforePlanning(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	body := `{"origin":{"latitude":1,"longitude":2},"destination":{"latitude":3,"longitude":4},"passengerCount":1,"requiresRiderIdentity":true,"riderIdentityVerified":false}`

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/plan", strings.NewReader(body))
	planHandler(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected unverified required identity to return 400 before planner execution, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "invalid request") {
		t.Fatalf("expected invalid request error, got %q", recorder.Body.String())
	}
}

func TestPlanHandlerRejectsNegativeWalkRadiusBeforePlanning(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	body := `{"origin":{"latitude":1,"longitude":2},"destination":{"latitude":3,"longitude":4},"passengerCount":1,"walkRadiusM":-1}`

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/plan", strings.NewReader(body))
	planHandler(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected negative walkRadiusM to return 400 before planner execution, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "invalid request") {
		t.Fatalf("expected invalid request error, got %q", recorder.Body.String())
	}
}

func TestPlanHandlerRejectsNegativeLuggageCountBeforePlanning(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	body := `{"origin":{"latitude":1,"longitude":2},"destination":{"latitude":3,"longitude":4},"passengerCount":1,"luggageManifest":{"suitcase":-1}}`

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/plan", strings.NewReader(body))
	planHandler(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected negative luggage count to return 400 before planner execution, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "invalid request") {
		t.Fatalf("expected invalid request error, got %q", recorder.Body.String())
	}
}

func TestPlanHandlerRejectsNegativePetCountBeforePlanning(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	body := `{"origin":{"latitude":1,"longitude":2},"destination":{"latitude":3,"longitude":4},"passengerCount":1,"pet":{"small":-1}}`

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/plan", strings.NewReader(body))
	planHandler(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected negative pet count to return 400 before planner execution, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "invalid request") {
		t.Fatalf("expected invalid request error, got %q", recorder.Body.String())
	}
}

func TestPlanHandlerRejectsNegativeChildAgeBeforePlanning(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	body := `{"origin":{"latitude":1,"longitude":2},"destination":{"latitude":3,"longitude":4},"passengerCount":1,"childPassengers":[{"ageYears":-1,"weightKg":12}]}`

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/plan", strings.NewReader(body))
	planHandler(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected negative child age to return 400 before planner execution, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "invalid request") {
		t.Fatalf("expected invalid request error, got %q", recorder.Body.String())
	}
}

func TestPlanHandlerRejectsNegativeChildWeightBeforePlanning(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	body := `{"origin":{"latitude":1,"longitude":2},"destination":{"latitude":3,"longitude":4},"passengerCount":1,"childPassengers":[{"ageYears":3,"weightKg":-1}]}`

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/plan", strings.NewReader(body))
	planHandler(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected negative child weight to return 400 before planner execution, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "invalid request") {
		t.Fatalf("expected invalid request error, got %q", recorder.Body.String())
	}
}

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

func TestBoolHelpersRecognizeStringBackedAvailabilityFlags(t *testing.T) {
	raw := map[string]any{"isActive": " false "}
	if !rawBoolExists(raw, "isActive") {
		t.Fatalf("expected string-backed isActive flag to count as explicit availability state")
	}
	if boolValue(raw["isActive"], true) {
		t.Fatalf("expected string-backed false availability flag to parse as false, not fallback true")
	}
}

func TestDriverComplianceBoolValueUsesStringBackedRawValue(t *testing.T) {
	raw := map[string]any{"licenseVerified": " true ", "backgroundCheckPassed": " false "}
	if !driverComplianceBoolValue(raw, "licenseVerified", false) {
		t.Fatalf("expected string-backed true licenseVerified to override decoded false zero value")
	}
	if driverComplianceBoolValue(raw, "backgroundCheckPassed", true) {
		t.Fatalf("expected string-backed false backgroundCheckPassed to override decoded true fallback")
	}
}

func TestDriverSafetyBoolValueUsesStringBackedRawValue(t *testing.T) {
	raw := map[string]any{"isBlocked": " true ", "isStuck": " false "}
	if !driverSafetyBoolValue(raw, "isBlocked", false) {
		t.Fatalf("expected string-backed true isBlocked to override decoded false zero value")
	}
	if driverSafetyBoolValue(raw, "isStuck", true) {
		t.Fatalf("expected string-backed false isStuck to override decoded true fallback")
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

func TestComputeDriverScore_RejectsBlockedDriverVerificationStatus(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("blocked-verification-driver", 0, 0, routeCorridor())
	driver.VerificationStatus = "blocked"

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected blocked driver verification status to be rejected before scoring")
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

func TestCurrentPassengerGendersFromRawParsesFirestoreArray(t *testing.T) {
	got := currentPassengerGendersFromRaw([]any{" male ", "", "   ", 123, "female"})
	want := []string{"male", "female"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("expected raw currentPassengerGenders array %#v, got %#v", want, got)
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

func TestComputeDriverScore_RejectsStringBackedExclusiveRequestWithExistingReservedSeats(t *testing.T) {
	req := corridorRequest()
	req.RiderGender = "female"
	req.PremiumRequested = map[string]any{"exclusive": " true "}
	driver := corridorDriver("string-exclusive-capable-but-occupied", 0, 0, routeCorridor())
	driver.PremiumCapabilities = map[string]any{"exclusive": true}
	driver.ReservedSeats = 1
	driver.CurrentPassengerGenders = []string{"female"}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected string-backed exclusive request to reject a driver with existing reserved passengers")
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

func TestComputeDriverScore_IgnoresStringBackedFalsePremiumRequirement(t *testing.T) {
	req := corridorRequest()
	req.PremiumRequested = map[string]any{"exclusive": " false "}
	driver := corridorDriver("standard-driver-string-false-premium", 0, 0, routeCorridor())

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected string-backed false premium flag to be ignored instead of requiring an explicit false capability")
	}
}

func TestComputeDriverScore_AcceptsStringBackedPremiumCapability(t *testing.T) {
	req := corridorRequest()
	req.PremiumRequested = map[string]any{"exclusive": true}
	driver := corridorDriver("string-backed-exclusive-capability", 0, 0, routeCorridor())
	driver.PremiumCapabilities = map[string]any{"exclusive": " true "}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected string-backed true premium capability to satisfy an exclusive request")
	}
}

func TestPremiumCapabilitiesFromRawParsesTypedCapabilityMaps(t *testing.T) {
	capabilities := premiumCapabilitiesFromRaw(map[string]bool{"exclusive": true})
	if got, ok := capabilities["exclusive"].(bool); !ok || !got {
		t.Fatalf("expected raw typed premium capability map to preserve exclusive=true, got %#v", capabilities)
	}
}

func TestPremiumCapabilitiesFromRawParsesStringCapabilityMaps(t *testing.T) {
	capabilities := premiumCapabilitiesFromRaw(map[string]string{"exclusive": " true ", "  ": "true"})
	if got, ok := capabilities["exclusive"].(string); !ok || got != " true " {
		t.Fatalf("expected raw string premium capability map to preserve exclusive string value, got %#v", capabilities)
	}
	if _, ok := capabilities[""]; ok || len(capabilities) != 1 {
		t.Fatalf("expected blank premium capability keys to be ignored, got %#v", capabilities)
	}
}

func TestComputeDriverScore_RejectsNonPositivePassengerCount(t *testing.T) {
	req := RideRequest{Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 0}
	driver := DriverProfile{CapacitySeats: 4, CurrentLocation: GeoPoint{0, 0}}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected scorer to reject non-positive passengerCount instead of normalizing it to one passenger")
	}
}

func TestComputeDriverScore_RejectsNegativeWalkRadius(t *testing.T) {
	req := RideRequest{Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 1, WalkRadiusM: -1}
	driver := DriverProfile{CapacitySeats: 4, CurrentLocation: GeoPoint{0, 0}}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected scorer to reject negative walkRadiusM before corridor/walk math")
	}
}

func TestComputeDriverScore_RejectsOutOfRangeCoordinates(t *testing.T) {
	req := RideRequest{Origin: GeoPoint{Latitude: 0, Longitude: 181}, Destination: GeoPoint{Latitude: 0, Longitude: 181.1}, PassengerCount: 1}
	driver := DriverProfile{CapacitySeats: 4, CurrentLocation: GeoPoint{Latitude: 0, Longitude: 181}}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected scorer to reject out-of-range origin/destination coordinates before route math")
	}
}

func TestComputeDriverScore_RejectsOutOfRangeDriverCurrentLocation(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_PICKUP_ETA_SECONDS", "999999999")
	req := corridorRequest()
	driver := corridorDriver("invalid-driver-location", 0, 0, routeCorridor())
	driver.CurrentLocation = GeoPoint{Latitude: 0, Longitude: 181}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected scorer to reject out-of-range driver currentLocation before pickup ETA math")
	}
}

func TestComputeDriverScore_RejectsNegativeLuggageRequest(t *testing.T) {
	req := RideRequest{
		Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 1,
		LuggageManifest: map[string]int{"suitcase": -1},
	}
	driver := DriverProfile{
		CapacitySeats:   4,
		LuggageCapacity: map[string]int{"suitcase": 0},
		CurrentLocation: GeoPoint{0, 0},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected scorer to reject negative luggage requests before capacity math")
	}
}

func TestComputeDriverScore_RejectsNegativePetRequest(t *testing.T) {
	req := RideRequest{
		Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 1,
		Pet: map[string]int{"small": -1},
	}
	driver := DriverProfile{
		CapacitySeats:   4,
		PetLimits:       map[string]int{"small": 0},
		CurrentLocation: GeoPoint{0, 0},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected scorer to reject negative pet requests before capacity math")
	}
}

func TestComputeDriverScore_RejectsNegativeChildPassengerRequest(t *testing.T) {
	req := RideRequest{
		Origin: GeoPoint{0, 0}, Destination: GeoPoint{1, 1}, PassengerCount: 1,
		ChildPassengers: []struct {
			AgeYears int `json:"ageYears"`
			WeightKg int `json:"weightKg"`
		}{{AgeYears: -1, WeightKg: 12}},
	}
	driver := DriverProfile{
		CapacitySeats:      4,
		ChildSeatInventory: map[string]int{"infant": 0},
		CurrentLocation:    GeoPoint{0, 0},
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected scorer to reject negative child passenger requests before child-seat math")
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

func TestReservedSeatLedgerSumIgnoresNegativeEntries(t *testing.T) {
	reserved := sumReservedSeats([]struct {
		Seats int `firestore:"seats"`
	}{
		{Seats: 4},
		{Seats: -3},
	})
	if reserved != 4 {
		t.Fatalf("expected negative seat ledger entries to be ignored before summing, got %d", reserved)
	}
}

func TestReservedSeatLedgerFromRawParsesStringBackedSeats(t *testing.T) {
	reserved := reservedSeatsFromRaw([]any{
		map[string]any{"seats": " 2 "},
		map[string]any{"seats": int64(1)},
		map[string]any{"seats": -5},
	})
	if reserved != 3 {
		t.Fatalf("expected raw string-backed seat ledger to sum positive seats only, got %d", reserved)
	}
}

func TestCapacitySeatsFromRawParsesStringBackedCapacity(t *testing.T) {
	if got := capacitySeatsFromRaw(" 6 "); got != 6 {
		t.Fatalf("expected string-backed capacitySeats to parse as 6, got %d", got)
	}
	if got := capacitySeatsFromRaw(-2); got != 0 {
		t.Fatalf("expected negative capacitySeats to be ignored and left for defaulting, got %d", got)
	}
}

func TestActivePickupsFromRawParsesStringBackedLegacyOccupancy(t *testing.T) {
	if got := activePickupsFromRaw(" 3 "); got != 3 {
		t.Fatalf("expected string-backed activePickups to parse as 3, got %d", got)
	}
	if got := activePickupsFromRaw(-2); got != 0 {
		t.Fatalf("expected negative activePickups to be clamped to zero, got %d", got)
	}
}

func TestComputeDriverScore_ClampsNegativeReservedSeatLedgerLoad(t *testing.T) {
	req := corridorRequest()
	req.PassengerCount = 5
	driver := corridorDriver("negative-seat-ledger", 0, 0, routeCorridor())
	driver.CapacitySeats = 4
	driver.HasSeatLedger = true
	driver.ReservedSeats = -2

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected negative reserved seat ledger load not to create phantom capacity for an oversized group")
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

func TestResourceLedgerSumsIgnoreNegativeEntries(t *testing.T) {
	cargo := sumCargoLedger([]cargoLedgerEntry{
		{Items: map[string]int{"suitcase": 4}},
		{Items: map[string]int{"suitcase": -3}},
	})
	if got := cargo["suitcase"]; got != 4 {
		t.Fatalf("expected negative cargo ledger entries to be ignored before summing, got %d", got)
	}

	pets := sumPetLedger([]petLedgerEntry{
		{Pets: map[string]int{"small": 2}},
		{Pets: map[string]int{"small": -1}},
	})
	if got := pets["small"]; got != 2 {
		t.Fatalf("expected negative pet ledger entries to be ignored before summing, got %d", got)
	}

	childSeats := sumChildSeatLedger([]childSeatLedgerEntry{
		{Seats: map[string]int{"forward": 3}},
		{Seats: map[string]int{"forward": -2}},
	})
	if got := childSeats["forward"]; got != 3 {
		t.Fatalf("expected negative child-seat ledger entries to be ignored before summing, got %d", got)
	}
}

func TestResourceLedgerFromRawParsesStringBackedCounts(t *testing.T) {
	ledger := resourceLedgerFromRaw([]any{
		map[string]any{"items": map[string]any{"suitcase": " 2 ", "duffel": int64(1), "bad": -4}},
		map[string]any{"items": map[string]any{"suitcase": float64(1)}},
	}, "items")
	if got := ledger["suitcase"]; got != 3 {
		t.Fatalf("expected raw string-backed suitcase ledger to total 3, got %d", got)
	}
	if got := ledger["duffel"]; got != 1 {
		t.Fatalf("expected raw int64 duffel ledger to total 1, got %d", got)
	}
	if got := ledger["bad"]; got != 0 {
		t.Fatalf("expected negative raw resource ledger entries to be ignored, got %d", got)
	}
}

func TestResourceCountsFromRawParsesStringBackedCapacity(t *testing.T) {
	capacity := resourceCountsFromRaw(map[string]any{"suitcase": " 2 ", "duffel": int64(1), "bad": -4})
	if got := capacity["suitcase"]; got != 2 {
		t.Fatalf("expected raw string-backed suitcase capacity to parse as 2, got %d", got)
	}
	if got := capacity["duffel"]; got != 1 {
		t.Fatalf("expected raw int64 duffel capacity to parse as 1, got %d", got)
	}
	if got := capacity["bad"]; got != 0 {
		t.Fatalf("expected negative raw capacity entries to be ignored, got %d", got)
	}
}

func TestComputeDriverScore_ClampsNegativeReservedResourceLedgerLoad(t *testing.T) {
	req := RideRequest{
		Origin:          GeoPoint{0, 0},
		Destination:     GeoPoint{1, 1},
		PassengerCount:  1,
		LuggageManifest: map[string]int{"suitcase": 2},
	}
	driver := DriverProfile{
		CapacitySeats:   4,
		CurrentLocation: GeoPoint{0, 0},
		LuggageCapacity: map[string]int{"suitcase": 1},
		ReservedLuggage: map[string]int{"suitcase": -2},
		PickupZoneID:    "zone-negative-resource",
		DropoffZoneID:   "zone-negative-resource-dropoff",
		BufferPolygon:   routeCorridor(),
		HasSeatLedger:   true,
		ReservedSeats:   0,
	}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected negative reserved resource ledger load not to create phantom luggage capacity")
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

func TestComputeDriverScore_MalformedOriginWalkGeometryFallsBackToWalkRadiusForBufferCorridor(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.WalkRadiusM = 500
	req.OriWalkIso = GeoJSONGeometry{}
	req.OriginWalkIso = GeoJSONGeometry{Type: "Polygon", Coordinates: [][][]float64{}}
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("buffer-corridor-radius-origin-fallback", 0, 0, routeCorridor())

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected malformed originWalkIso to fall back to walkRadiusM circle for a valid buffer corridor")
	}
}

func TestComputeDriverScore_MalformedDestinationWalkGeometryFallsBackToWalkRadiusForBufferCorridor(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.WalkRadiusM = 500
	req.DestWalkIso = GeoJSONGeometry{}
	req.DestinationWalkIso = GeoJSONGeometry{Type: "Polygon", Coordinates: [][][]float64{}}
	driver := corridorDriver("buffer-corridor-radius-destination-fallback", 0, 0, routeCorridor())

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected malformed destinationWalkIso to fall back to walkRadiusM circle for a valid buffer corridor")
	}
}

func TestGeoPointFromRawParsesStringBackedCurrentLocation(t *testing.T) {
	point, ok := geoPointFromRaw(map[string]any{"latitude": " 0.05 ", "longitude": " -0.10 "})
	if !ok {
		t.Fatalf("expected string-backed Firestore currentLocation to parse")
	}
	if point.Latitude != 0.05 || point.Longitude != -0.10 {
		t.Fatalf("expected parsed currentLocation lat=0.05 lon=-0.10, got %#v", point)
	}
}

func TestGeoPointFromRawParsesNativeFirestoreLatLng(t *testing.T) {
	point, ok := geoPointFromRaw(&latlng.LatLng{Latitude: 0.05, Longitude: -0.10})
	if !ok {
		t.Fatalf("expected native Firestore latlng currentLocation to parse")
	}
	if point.Latitude != 0.05 || point.Longitude != -0.10 {
		t.Fatalf("expected parsed native currentLocation lat=0.05 lon=-0.10, got %#v", point)
	}
}

func TestGeoJSONGeometryFromRawParsesFirestoreMapRouteBuffer(t *testing.T) {
	raw := map[string]any{
		"type": "Polygon",
		"coordinates": []any{[]any{
			[]any{-0.01, -0.005},
			[]any{1.01, -0.005},
			[]any{1.01, 0.005},
			[]any{-0.01, 0.005},
			[]any{-0.01, -0.005},
		}},
	}

	geometry, ok := geoJSONGeometryFromRaw(raw)
	if !ok || !validGeoJSONPolygonGeometry(geometry) {
		t.Fatalf("expected Firestore map routeBuffer to parse into valid GeoJSON geometry, got ok=%v geometry=%#v", ok, geometry)
	}
}

func TestGeoJSONGeometryFromRawParsesStringBackedCoordinates(t *testing.T) {
	raw := map[string]any{
		"type": "Polygon",
		"coordinates": []any{[]any{
			[]any{"-0.01", "-0.005"},
			[]any{"1.01", "-0.005"},
			[]any{"1.01", "0.005"},
			[]any{"-0.01", "0.005"},
			[]any{"-0.01", "-0.005"},
		}},
	}

	geometry, ok := geoJSONGeometryFromRaw(raw)
	if !ok || !validGeoJSONPolygonGeometry(geometry) {
		t.Fatalf("expected string-backed raw routeBuffer coordinates to parse, got ok=%v geometry=%#v", ok, geometry)
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

func TestComputeDriverScore_TrimsGlobalWalkLimitBeforeRejectingBufferOnlyStaleWalkPolygons(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", " 300 ")
	req := corridorRequest()
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriWalkIso = rectPolygon(0.0045, -0.01, 0.0055, 0.01)
	req.DestWalkIso = rectPolygon(0.0045, 0.99, 0.0055, 1.01)
	driver := corridorDriver("buffer-only-stale-walk-polygons-above-trimmed-cap", 0.005, 0, rectPolygon(0.0045, -0.01, 0.0055, 1.01))

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected whitespace-padded global walk cap to reject buffer-only intersections above 300m from rider endpoints")
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

func TestComputeDriverScore_GlobalWalkLimitRejectsBufferOnlyDestinationWalkAndDriveCommonPointOutsideCap(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	req := corridorRequest()
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.06, 1.01)
	req.DestinationDriveGeo = rectPolygon(0.049, 0.99, 0.051, 1.01)
	driver := corridorDriver("buffer-only-destination-drive-common-point-too-far", 0.002, 0, rectPolygon(0.002, -0.01, 0.051, 1.01))

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected buffer-only destination walk+drive common point outside explicit walk cap to be rejected")
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
		{Latitude: 0.05, Longitude: 0},  // inside stale origin walk polygon but outside explicit walk cap
		{Latitude: 0, Longitude: 1},     // destination before legal pickup
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
		rectRing(0.04, 0.49, 0.06, 0.51),  // early legal drive area, but outside rider walk radius
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

func TestComputeDriverScore_RejectsDestinationWalkDropoffOutsideDestinationDriveGeo(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "100")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	req := corridorRequest()
	req.WalkRadiusM = 100
	req.OriWalkIso = rectPolygon(-0.0002, -0.0002, 0.0002, 0.0002)
	req.DestWalkIso = rectPolygon(-0.0002, 0.9998, 0.0002, 1.0002)
	req.OriDriveIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.DestinationDriveGeo = rectPolygon(0.009, 0.499, 0.011, 0.501)
	driver := corridorDriver("destination-walk-outside-destination-drive", 0, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0.01, Longitude: 0.50}, // enters destinationDriveGeo, but far from destination walk zone
		{Latitude: 0, Longitude: 1},       // reaches destination walk zone outside destinationDriveGeo
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected route dropoff outside destinationDriveGeo to be rejected even after an unrelated drive-geo pass")
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

func TestComputeDriverScore_IgnoresMalformedOptionalDestinationDriveGeo(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.DestinationDriveGeo = GeoJSONGeometry{Type: "Polygon", Coordinates: [][][]float64{}}
	driver := corridorDriver("valid-corridor-malformed-destination-drive", 0, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected malformed optional destinationDriveGeo to be ignored instead of rejecting a valid corridor match")
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

func TestRideRequestPrefersCanonicalWalkGeometriesOverStaleLegacy(t *testing.T) {
	originCanonical := rectPolygon(-0.01, -0.01, 0.01, 0.01)
	destinationCanonical := rectPolygon(-0.01, 0.99, 0.01, 1.01)
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(10, 10, 11, 11)
	req.OriginWalkIso = originCanonical
	req.DestWalkIso = rectPolygon(20, 20, 21, 21)
	req.DestinationWalkIso = destinationCanonical

	if !reflect.DeepEqual(req.originWalkGeometry(), originCanonical) {
		t.Fatalf("expected canonical originWalkIso to override stale legacy oriWalkIso, got %#v", req.originWalkGeometry())
	}
	if !reflect.DeepEqual(req.destinationWalkGeometry(), destinationCanonical) {
		t.Fatalf("expected canonical destinationWalkIso to override stale legacy destWalkIso, got %#v", req.destinationWalkGeometry())
	}
}

func TestComputeDriverScore_PrefersCanonicalOriginWalkIsoOverStaleLegacy(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(10, 10, 11, 11) // stale legacy geometry
	req.OriginWalkIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("canonical-origin-walk", 0, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected canonical originWalkIso to override stale legacy oriWalkIso")
	}
}

func TestRideRequestFallsBackToLegacyGeometryAliasesWhenCanonicalMalformed(t *testing.T) {
	malformed := GeoJSONGeometry{Type: "Polygon", Coordinates: [][][]float64{}}

	req := corridorRequest()
	legacyOriginWalk := rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.OriWalkIso = legacyOriginWalk
	req.OriginWalkIso = malformed
	if got := req.originWalkGeometry(); !reflect.DeepEqual(got, legacyOriginWalk) {
		t.Fatalf("expected valid legacy oriWalkIso when canonical originWalkIso is malformed, got %#v", got)
	}

	legacyDestinationWalk := rectPolygon(-0.01, 0.99, 0.01, 1.01)
	req.DestWalkIso = legacyDestinationWalk
	req.DestinationWalkIso = malformed
	if got := req.destinationWalkGeometry(); !reflect.DeepEqual(got, legacyDestinationWalk) {
		t.Fatalf("expected valid legacy destWalkIso when canonical destinationWalkIso is malformed, got %#v", got)
	}

	legacyOriginDrive := rectPolygon(-0.05, -0.05, 0.05, 0.05)
	req.OriDriveIso = legacyOriginDrive
	req.OriginDriveGeo = malformed
	if got := req.originDriveGeometry(); !reflect.DeepEqual(got, legacyOriginDrive) {
		t.Fatalf("expected valid legacy oriDriveIso when canonical originDriveGeo is malformed, got %#v", got)
	}

	canonicalWithMalformedHole := GeoJSONGeometry{
		Type: "Polygon",
		Coordinates: [][][]float64{
			rectRing(-0.05, -0.05, 0.05, 0.05),
			{{0, 0}}, // malformed hole: valid outer ring, invalid interior ring
		},
	}
	req.OriWalkIso = legacyOriginWalk
	req.OriginWalkIso = canonicalWithMalformedHole
	if got := req.originWalkGeometry(); !reflect.DeepEqual(got, legacyOriginWalk) {
		t.Fatalf("expected valid legacy oriWalkIso when canonical originWalkIso has malformed holes, got %#v", got)
	}

	canonicalWithNonFiniteCoordinate := GeoJSONGeometry{
		Type: "Polygon",
		Coordinates: [][][]float64{
			{{-0.05, -0.05}, {math.NaN(), -0.05}, {0.05, 0.05}, {-0.05, 0.05}, {-0.05, -0.05}},
		},
	}
	req.OriWalkIso = legacyOriginWalk
	req.OriginWalkIso = canonicalWithNonFiniteCoordinate
	if got := req.originWalkGeometry(); !reflect.DeepEqual(got, legacyOriginWalk) {
		t.Fatalf("expected valid legacy oriWalkIso when canonical originWalkIso has non-finite coordinates, got %#v", got)
	}

	canonicalWithDegenerateClosedRing := GeoJSONGeometry{
		Type: "Polygon",
		Coordinates: [][][]float64{
			{{-0.05, -0.05}, {0.05, 0.05}, {-0.05, -0.05}},
		},
	}
	req.OriWalkIso = legacyOriginWalk
	req.OriginWalkIso = canonicalWithDegenerateClosedRing
	if got := req.originWalkGeometry(); !reflect.DeepEqual(got, legacyOriginWalk) {
		t.Fatalf("expected valid legacy oriWalkIso when canonical originWalkIso has a degenerate closed ring, got %#v", got)
	}

	canonicalWithZeroAreaRing := GeoJSONGeometry{
		Type: "Polygon",
		Coordinates: [][][]float64{
			{{-0.05, -0.05}, {0.0, 0.0}, {0.05, 0.05}, {-0.05, -0.05}},
		},
	}
	req.OriWalkIso = legacyOriginWalk
	req.OriginWalkIso = canonicalWithZeroAreaRing
	if got := req.originWalkGeometry(); !reflect.DeepEqual(got, legacyOriginWalk) {
		t.Fatalf("expected valid legacy oriWalkIso when canonical originWalkIso has a zero-area ring, got %#v", got)
	}

	canonicalWithOutOfRangeCoordinate := GeoJSONGeometry{
		Type: "Polygon",
		Coordinates: [][][]float64{
			{{-0.05, -0.05}, {0.05, -0.05}, {0.05, 91.0}, {-0.05, -0.05}},
		},
	}
	req.OriWalkIso = legacyOriginWalk
	req.OriginWalkIso = canonicalWithOutOfRangeCoordinate
	if got := req.originWalkGeometry(); !reflect.DeepEqual(got, legacyOriginWalk) {
		t.Fatalf("expected valid legacy oriWalkIso when canonical originWalkIso has out-of-range coordinates, got %#v", got)
	}
}

func TestComputeDriverScore_PrefersCanonicalDestinationWalkIsoOverStaleLegacy(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.DestWalkIso = rectPolygon(10, 10, 11, 11) // stale legacy geometry
	req.DestinationWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("canonical-destination-walk", 0, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected canonical destinationWalkIso to override stale legacy destWalkIso")
	}
}

func TestComputeDriverScore_PrefersCanonicalOriginDriveGeoOverStaleLegacy(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.OriDriveIso = rectPolygon(10, 10, 11, 11) // stale legacy geometry
	req.OriginDriveGeo = rectPolygon(-0.05, -0.05, 0.05, 0.05)
	driver := corridorDriver("canonical-origin-drive", 0, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected canonical originDriveGeo to override stale legacy oriDriveIso")
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

func TestRoutePolylineEntersGeometryAfterOriginSkipsOriginOutsideExplicitWalkCap(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0, Longitude: 0}
	req.OriWalkIso = rectPolygon(-0.10, -0.10, 0.10, 0.10)
	req.OriginWalkIso = GeoJSONGeometry{}
	req.DestinationDriveGeo = GeoJSONGeometry{}
	destinationDrive := rectPolygon(0.047, 0.197, 0.053, 0.203)
	route := encodePolyline([]GeoPoint{
		{Latitude: 0.05, Longitude: 0},
		{Latitude: 0.05, Longitude: 0.20},
		{Latitude: 0.002, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	if routePolylineEntersGeometryAfterOrigin(req, route, destinationDrive) {
		t.Fatalf("expected destination-drive route-order helper to skip origin candidates outside explicit walk cap")
	}
}

func TestRoutePolylineEntersGeometryAfterOriginNormalizesRoutePolyline(t *testing.T) {
	req := corridorRequest()
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	destinationDrive := rectPolygon(-0.01, 0.99, 0.01, 1.01)
	polyline := " \n" + encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	}) + "\t "

	if !routePolylineEntersGeometryAfterOrigin(req, polyline, destinationDrive) {
		t.Fatalf("expected destination-drive route-order helper to normalize whitespace-padded routePolyline")
	}
}

func TestRoutePolylineEntersGeometryBeforeOriginNormalizesRoutePolyline(t *testing.T) {
	req := corridorRequest()
	originDrive := rectPolygon(-0.01, -0.101, 0.01, -0.099)
	polyline := " \n" + encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	}) + "\t "

	if !routePolylineEntersGeometryBeforeOrigin(req, polyline, originDrive) {
		t.Fatalf("expected origin-drive route-order helper to normalize whitespace-padded routePolyline")
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

func TestComputeDriverScore_RejectsDestinationDriveGeoOnlyBeforeWalkFeasiblePickupOffLaterPath(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "20000")
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "200")
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0, Longitude: 0}
	req.OriWalkIso = rectPolygon(-0.003, -0.003, 0.003, 0.003)
	req.OriginWalkIso = GeoJSONGeometry{}
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	req.Destination = GeoPoint{Latitude: 0, Longitude: 1}
	req.DestWalkIso = rectPolygon(-0.003, 0.997, 0.003, 1.003)
	req.DestinationWalkIso = GeoJSONGeometry{}
	req.DestinationDriveGeo = rectPolygon(0.047, 0.197, 0.053, 0.203)
	driver := corridorDriver("destination-drive-only-before-walk-feasible-pickup", 0.05, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.05, Longitude: 0},
		{Latitude: 0.05, Longitude: 0.20},
		{Latitude: 0.002, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected destinationDriveGeo pass before the actual walk-feasible pickup to be rejected")
	}
}

func TestComputeDriverScore_RejectsDestinationDriveGeoOnlyBeforeWalkFeasiblePickup(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "20000")
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0, Longitude: 0}
	req.OriWalkIso = rectPolygon(-0.003, -0.003, 0.003, 0.003)
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	req.Destination = GeoPoint{Latitude: 0, Longitude: 1}
	req.DestWalkIso = rectPolygon(-0.003, 0.997, 0.003, 1.003)
	req.DestinationWalkIso = GeoJSONGeometry{}
	req.DestinationDriveGeo = rectPolygon(-0.003, 0.397, 0.003, 0.403)
	driver := corridorDriver("destination-drive-before-walk-feasible-pickup", 0.05, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.05, Longitude: 0},  // near origin longitude, but outside explicit rider walk cap
		{Latitude: 0, Longitude: 0.40},  // only destination-drive pass, before legal pickup
		{Latitude: 0.002, Longitude: 0}, // later walk-feasible pickup
		{Latitude: 0, Longitude: 1},     // destination walk zone, outside destinationDriveGeo
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected destinationDriveGeo pass before the actual walk-feasible pickup to be rejected")
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

func TestComputeDriverScore_AllowsRouteExitingDestinationDriveGeoHoleAfterPickup(t *testing.T) {
	allowLongPickupETA(t)
	req := corridorRequest()
	req.Destination = GeoPoint{Latitude: 0, Longitude: 1}
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	req.DestinationWalkIso = req.DestWalkIso
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	req.DestinationDriveGeo = polygonWithHole(
		rectRing(-0.05, 0.95, 0.05, 1.05),
		rectRing(-0.001, 0.999, 0.001, 1.001),
	)
	driver := corridorDriver("route-exits-destination-drive-hole", 0, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1.0005},
		{Latitude: 0, Longitude: 1.002},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route crossing from a destinationDriveGeo hole into the valid drive ring after pickup to be accepted")
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

func TestComputeDriverScore_RejectsBufferMissingDestinationDriveGeoWhenWalkZoneMissing(t *testing.T) {
	allowLongPickupETA(t)
	req := RideRequest{
		Origin:              GeoPoint{Latitude: 0, Longitude: 0},
		Destination:         GeoPoint{Latitude: 0, Longitude: 1},
		PassengerCount:      1,
		OriDriveIso:         rectPolygon(-0.05, -0.05, 0.05, 0.05),
		DestinationDriveGeo: rectPolygon(-0.01, 0.99, 0.01, 1.01),
	}
	driver := corridorDriver("buffer-misses-destination-drive", 0, 1, rectPolygon(-0.01, -0.01, 0.01, 0.01))

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected buffer-only driver to be rejected when its corridor misses destinationDriveGeo, even if current location is inside the destination drive geofence")
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

func TestComputeDriverScore_AllowsRouteExitingOriginDriveGeoHoleBeforePickup(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	req := corridorRequest()
	req.Origin = GeoPoint{Latitude: 0, Longitude: 0}
	req.OriWalkIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.OriginWalkIso = req.OriWalkIso
	req.OriDriveIso = polygonWithHole(
		rectRing(-0.05, -0.05, 0.05, 0.05),
		rectRing(-0.001, -0.001, 0.001, 0.001),
	)
	req.OriginDriveGeo = req.OriDriveIso
	driver := corridorDriver("route-exits-origin-drive-hole", 0, -0.0005, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.0005},
		{Latitude: 0, Longitude: -0.002},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route crossing from an originDriveGeo hole into the valid drive ring before pickup to be accepted")
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

func TestComputeDriverScore_AllowsRouteExitingOriginWalkHoleWithinWalkCap(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "200")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "2000")
	req := corridorRequest()
	req.WalkRadiusM = 200
	req.Origin = GeoPoint{Latitude: 0, Longitude: 0}
	req.OriWalkIso = polygonWithHole(
		rectRing(-0.05, -0.05, 0.05, 0.05),
		rectRing(-0.001, -0.001, 0.001, 0.001),
	)
	req.OriginWalkIso = req.OriWalkIso
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("route-exits-origin-walk-hole", 0, -0.0005, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.0005},
		{Latitude: 0, Longitude: -0.002},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route crossing from a walk-zone hole into the valid ring within walk cap to be accepted")
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

func TestComputeDriverScore_AllowsRouteExitingDestinationWalkHoleWithinWalkCap(t *testing.T) {
	allowLongPickupETA(t)
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "200")
	req := corridorRequest()
	req.WalkRadiusM = 200
	req.Destination = GeoPoint{Latitude: 0, Longitude: 1}
	req.DestWalkIso = polygonWithHole(
		rectRing(-0.05, 0.95, 0.05, 1.05),
		rectRing(-0.001, 0.999, 0.001, 1.001),
	)
	req.DestinationWalkIso = req.DestWalkIso
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("route-exits-destination-walk-hole", 0, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1.0005},
		{Latitude: 0, Longitude: 1.002},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected route crossing from a destination walk-zone hole into the valid ring within walk cap to be accepted")
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

func TestComputeDriverScore_RejectsMalformedCanonicalRouteBuffer(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("malformed-canonical-route-buffer", 0.05, 0, GeoJSONGeometry{})
	driver.RoutePolyline = ""
	driver.RouteBuffer = GeoJSONGeometry{Type: "Polygon", Coordinates: [][][]float64{}}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected malformed canonical routeBuffer to be treated as absent and rejected")
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

func TestComputeDriverScore_FallsBackToRouteBufferWhenLegacyBufferMalformed(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("malformed-legacy-buffer-valid-route-buffer", 0.05, 0, GeoJSONGeometry{
		Type:        "Polygon",
		Coordinates: [][][]float64{},
	})
	driver.RouteBuffer = routeCorridor()

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected valid canonical routeBuffer to be used when legacy bufferPolygon is malformed")
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

func TestPickBestDriverFromProfiles_RanksRoutePolylineCorridorAboveNearestWrongDirection(t *testing.T) {
	req := corridorRequest()
	wrongDirection := corridorDriverWithPickupZone("nearest-route-wrong-direction", 0, 0.001, routeCorridor(), "zone-route-wrong")
	wrongDirection.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 1},
		{Latitude: 0, Longitude: 0},
	})
	valid := corridorDriverWithPickupZone("farther-route-valid-corridor", 0.10, 0, routeCorridor(), "zone-route-valid")
	valid.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{wrongDirection, valid}, nil, defaultScoreWeights())
	if err != nil {
		t.Fatalf("expected valid routePolyline corridor driver, got error: %v", err)
	}
	if driverID != "farther-route-valid-corridor" {
		t.Fatalf("expected farther valid routePolyline corridor driver, got %q", driverID)
	}
}

func TestSingleHopThresholdsIgnoreNonFiniteFloatEnv(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "+Inf")
	if got := maxSingleHopRouteDetourKm(); got != 25.0 {
		t.Fatalf("expected non-finite detour env to fall back to 25km, got %f", got)
	}
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "+Inf")
	if got := maxSingleHopWalkMeters(); got != 1000.0 {
		t.Fatalf("expected non-finite walk env to fall back to 1000m, got %f", got)
	}
}

func TestComputeDriverScore_TrimsPickupETAThresholdEnvBeforeRejectingLateRoute(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_PICKUP_ETA_SECONDS", " 60 ")
	req := corridorRequest()
	driver := corridorDriver("late-route-pickup", 0, -0.10, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})
	driver.RouteETAProfileSeconds = []int{0, 90, 600}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected whitespace-padded pickup ETA threshold to reject a 90-second route pickup against a 60-second limit")
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

func TestScoreWeightsFromEnvDefaultsNonFiniteValues(t *testing.T) {
	t.Setenv("WEIGHT_DETOUR", "+Inf")
	t.Setenv("WEIGHT_ETA", "NaN")
	t.Setenv("WEIGHT_WALK", "-Inf")
	t.Setenv("WEIGHT_CURB", "+Inf")

	weights := scoreWeightsFromEnv()
	defaults := defaultScoreWeights()
	if weights != defaults {
		t.Fatalf("expected non-finite env score weights to fall back to defaults, got %+v want %+v", weights, defaults)
	}
}

func TestScoreWeightsFromEnvTrimsConfiguredWeights(t *testing.T) {
	t.Setenv("WEIGHT_DETOUR", " 1.5 ")
	t.Setenv("WEIGHT_ETA", "\n0.25	")
	t.Setenv("WEIGHT_WALK", " 0.75 ")
	t.Setenv("WEIGHT_CURB", " 2 ")

	weights := scoreWeightsFromEnv()
	want := scoreWeights{Detour: 1.5, ETA: 0.25, Walk: 0.75, Curb: 2}
	if weights != want {
		t.Fatalf("expected whitespace-padded score weight env values to parse, got %+v want %+v", weights, want)
	}
}

func TestPickBestDriverFromProfiles_DefaultsNonFiniteScoreWeights(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "200000")
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

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{looping, direct}, nil, scoreWeights{Detour: math.NaN(), ETA: math.Inf(1), Walk: math.Inf(-1), Curb: math.NaN()})
	if err != nil {
		t.Fatalf("expected valid corridor driver with sanitized weights, got error: %v", err)
	}
	if driverID != "zzz-direct-corridor" {
		t.Fatalf("expected non-finite score weights to fall back before ranking, got %q", driverID)
	}
}

func TestPickBestDriverFromProfiles_DefaultsNonFiniteCurbFactor(t *testing.T) {
	for name, curbFactor := range map[string]float64{"nan": math.NaN(), "positive-infinity": math.Inf(1)} {
		t.Run(name, func(t *testing.T) {
			t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "200000")
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
			looping.CurbFactor = curbFactor

			driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{looping, direct}, nil, scoreWeights{Detour: 1, ETA: 0, Curb: 1})
			if err != nil {
				t.Fatalf("expected valid corridor driver with sanitized curb factor, got error: %v", err)
			}
			if driverID != "zzz-direct-corridor" {
				t.Fatalf("expected non-finite curb factor to be neutral before ranking, got %q", driverID)
			}
		})
	}
}

func TestRouteETAProfileSecondsFromRawParsesStringBackedNumbers(t *testing.T) {
	got := routeETAProfileSecondsFromRaw([]any{int64(0), " 60 ", float64(120)})
	want := []int{0, 60, 120}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("expected string-backed route ETA profile values %#v, got %#v", want, got)
	}
}

func TestRouteETAProfileSecondsFromRawParsesTypedStringSlices(t *testing.T) {
	got := routeETAProfileSecondsFromRaw([]string{" 0 ", "60", "120"})
	want := []int{0, 60, 120}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("expected typed string route ETA profile values %#v, got %#v", want, got)
	}
}

func TestRouteETAProfileSecondsFromRawRejectsNegativeValues(t *testing.T) {
	got := routeETAProfileSecondsFromRaw([]int64{0, -1})
	if got != nil {
		t.Fatalf("expected negative raw route ETA profile values to be treated as malformed, got %#v", got)
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

func TestPickBestDriverFromProfiles_IgnoresFlatPositiveRouteEtaProfileForPickupRanking(t *testing.T) {
	req := corridorRequest()
	flatProfile := corridorDriverWithPickupZone("aaa-flat-positive-profile", 0, -0.10, routeCorridor(), "zone-flat-positive-profile")
	flatProfile.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})
	flatProfile.RouteETAProfileSeconds = []int{300, 300, 300}
	validProfile := corridorDriverWithPickupZone("zzz-valid-profile", 0, -0.10, routeCorridor(), "zone-valid-profile")
	validProfile.RoutePolyline = flatProfile.RoutePolyline
	validProfile.RouteETAProfileSeconds = []int{0, 600, 1900}

	driverID, etaSec, err := pickBestDriverFromProfiles(req, []DriverProfile{flatProfile, validProfile}, nil, scoreWeights{ETA: 1, Curb: 1})
	if err != nil {
		t.Fatalf("expected route ETA profile winner, got error: %v", err)
	}
	if driverID != "zzz-valid-profile" {
		t.Fatalf("expected flat positive profile to fall back to route-distance ETA instead of beating valid profile, got %q eta=%d", driverID, etaSec)
	}
	if etaSec != 600 {
		t.Fatalf("expected valid route ETA profile pickup ETA 600, got %d", etaSec)
	}
}

func TestPickBestDriverFromProfiles_IgnoresRegressingRouteEtaProfileForPickupRanking(t *testing.T) {
	req := corridorRequest()
	route := encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: -0.05},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})
	regressingProfile := corridorDriverWithPickupZone("aaa-regressing-profile", 0, -0.10, routeCorridor(), "zone-regressing-profile")
	regressingProfile.RoutePolyline = route
	regressingProfile.RouteETAProfileSeconds = []int{0, 600, 60, 1900}
	validProfile := corridorDriverWithPickupZone("zzz-valid-profile", 0, -0.10, routeCorridor(), "zone-valid-profile")
	validProfile.RoutePolyline = route
	validProfile.RouteETAProfileSeconds = []int{0, 300, 600, 1900}

	driverID, etaSec, err := pickBestDriverFromProfiles(req, []DriverProfile{regressingProfile, validProfile}, nil, scoreWeights{ETA: 1, Curb: 1})
	if err != nil {
		t.Fatalf("expected route ETA profile winner, got error: %v", err)
	}
	if driverID != "zzz-valid-profile" {
		t.Fatalf("expected regressing pickup profile to fall back to route-distance ETA instead of beating valid profile, got %q eta=%d", driverID, etaSec)
	}
	if etaSec != 600 {
		t.Fatalf("expected valid route ETA profile pickup ETA 600, got %d", etaSec)
	}
}

func TestPickBestDriverFromProfiles_IgnoresNegativeRouteEtaProfileForPickupRanking(t *testing.T) {
	req := corridorRequest()
	route := encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: -0.05},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},
	})
	negativeProfile := corridorDriverWithPickupZone("aaa-negative-profile", 0, -0.10, routeCorridor(), "zone-negative-profile")
	negativeProfile.RoutePolyline = route
	negativeProfile.RouteETAProfileSeconds = []int{-600, -570, -540, 1900}
	validProfile := corridorDriverWithPickupZone("zzz-valid-profile", 0, -0.10, routeCorridor(), "zone-valid-profile")
	validProfile.RoutePolyline = route
	validProfile.RouteETAProfileSeconds = []int{0, 300, 600, 1900}

	driverID, etaSec, err := pickBestDriverFromProfiles(req, []DriverProfile{negativeProfile, validProfile}, nil, scoreWeights{ETA: 1, Curb: 1})
	if err != nil {
		t.Fatalf("expected route ETA profile winner, got error: %v", err)
	}
	if driverID != "zzz-valid-profile" {
		t.Fatalf("expected negative pickup profile to fall back to route-distance ETA instead of beating valid profile, got %q eta=%d", driverID, etaSec)
	}
	if etaSec != 600 {
		t.Fatalf("expected valid route ETA profile pickup ETA 600, got %d", etaSec)
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

func TestPickBestDriverFromProfiles_RanksWalkUsingDestinationDriveConstrainedDropoff(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "5000")
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", "200")
	req := corridorRequest()
	req.WalkRadiusM = 5000
	req.OriWalkIso = rectPolygon(-0.01, -0.02, 0.01, 0.02)
	req.OriDriveIso = GeoJSONGeometry{}
	req.Destination = GeoPoint{Latitude: 0, Longitude: 1}
	req.DestWalkIso = rectPolygon(-0.05, 0.95, 0.05, 1.05)
	req.DestinationWalkIso = GeoJSONGeometry{}
	req.DestinationDriveGeo = multiPolygon(
		rectRing(0.019, 0.99, 0.021, 1.01),
		rectRing(0.004, 0.99, 0.006, 1.01),
	)

	farLegalDropoff := corridorDriverWithPickupZone("aaa-far-legal-dropoff", 0, -0.10, GeoJSONGeometry{}, "zone-far-legal-dropoff")
	farLegalDropoff.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1},    // near destination walk zone, but outside destinationDriveGeo
		{Latitude: 0.02, Longitude: 1}, // first legal destination-drive dropoff, farther walk
	})
	farLegalDropoff.RouteETAProfileSeconds = []int{0, 60, 300, 600}

	nearLegalDropoff := corridorDriverWithPickupZone("zzz-near-legal-dropoff", 0, -0.10, GeoJSONGeometry{}, "zone-near-legal-dropoff")
	nearLegalDropoff.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0.005, Longitude: 1}, // legal destination-drive dropoff, closer walk
	})
	nearLegalDropoff.RouteETAProfileSeconds = []int{0, 60, 600}

	driverID, _, err := pickBestDriverFromProfiles(req, []DriverProfile{farLegalDropoff, nearLegalDropoff}, nil, scoreWeights{ETA: 1, Walk: 1, Curb: 1})
	if err != nil {
		t.Fatalf("expected rider-walk ranking winner using destination-drive-constrained dropoff, got error: %v", err)
	}
	if driverID != "zzz-near-legal-dropoff" {
		t.Fatalf("expected rider-walk ranking to ignore destination-walk-only snap outside destinationDriveGeo, got %q", driverID)
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

func TestZoneCapacityFromLookupParsesStringBackedIntegers(t *testing.T) {
	active, capacity := zoneCapacityFromLookup(map[string]any{"activePickups": " 3 ", "capacityCars": " 7 "}, true)
	if active != 3 || capacity != 7 {
		t.Fatalf("expected string-backed zone capacity fields to parse, got active=%d capacity=%d", active, capacity)
	}
}

func TestZoneCapacityFromLookupClampsNegativeActivePickups(t *testing.T) {
	active, capacity := zoneCapacityFromLookup(map[string]any{"activePickups": int64(-3), "capacityCars": int64(2)}, true)
	if active != 0 || capacity != 2 {
		t.Fatalf("expected negative zone activePickups to be normalized to zero, got active=%d capacity=%d", active, capacity)
	}
}

func TestIntValueFallsBackForNonFiniteFloats(t *testing.T) {
	if got := intValue(math.Inf(1), 7); got != 7 {
		t.Fatalf("expected +Inf numeric coercion to use fallback 7, got %d", got)
	}
	if got := intValue(math.Inf(-1), 7); got != 7 {
		t.Fatalf("expected -Inf numeric coercion to use fallback 7, got %d", got)
	}
	if got := intValue(math.NaN(), 7); got != 7 {
		t.Fatalf("expected NaN numeric coercion to use fallback 7, got %d", got)
	}
}

func TestZoneCapacityFromLookupIgnoresNonFiniteNumericFields(t *testing.T) {
	active, capacity := zoneCapacityFromLookup(map[string]any{"activePickups": math.Inf(1), "capacityCars": math.NaN()}, true)
	if active != 0 || capacity != defaultPickupZoneCapacityCars() {
		t.Fatalf("expected non-finite zone numbers to fall back safely, got active=%d capacity=%d", active, capacity)
	}
}

func TestCurbFactorFromZoneDataAcceptsIntegerAndRejectsNonFinite(t *testing.T) {
	if got := curbFactorFromZoneData(map[string]any{"curbLoadFactor": int64(2)}); got != 2 {
		t.Fatalf("expected integer curbLoadFactor to be accepted, got %f", got)
	}
	if got := curbFactorFromZoneData(map[string]any{"curbLoadFactor": math.Inf(1)}); got != 1 {
		t.Fatalf("expected non-finite curbLoadFactor to fall back to neutral 1.0, got %f", got)
	}
}

func TestCurbFactorFromZoneDataParsesStringBackedPositiveValues(t *testing.T) {
	if got := curbFactorFromZoneData(map[string]any{"curbLoadFactor": " 1.25 "}); got != 1.25 {
		t.Fatalf("expected string-backed positive curbLoadFactor to parse, got %f", got)
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

func TestComputeDriverScore_TrimsRouteDetourThresholdEnvBeforeRejectingLoopingRoute(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_DETOUR_KM", " 1 ")
	req := corridorRequest()
	driver := corridorDriver("small-loop-above-trimmed-detour-threshold", 0, 0, routeCorridor())
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: 0},
		{Latitude: 0.08, Longitude: 0.5},
		{Latitude: 0, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected whitespace-padded detour threshold to reject a route with >1km insertion detour")
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

func TestComputeDriverScore_TrimsPickupWalkTimingGraceEnvBeforeRejectingTooSoonPickup(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "1000")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", " 0 ")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(-0.01, -0.01, 0.01, 0.01)
	req.DestWalkIso = rectPolygon(-0.01, 0.99, 0.01, 1.01)
	driver := corridorDriver("pickup-too-soon-with-trimmed-zero-grace", 0.0005, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.0005, Longitude: 0},
		{Latitude: 0.0005, Longitude: 1},
	})

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected whitespace-padded zero pickup walk grace to reject an immediate pickup before rider walk time")
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

func TestComputeDriverScore_RejectsOriginDriveGeoOnlyBeforeWalkFeasiblePickup(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "1000")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "0")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(0.0055, -0.0005, 0.0065, 0.0005)
	req.DestWalkIso = rectPolygon(0.0055, 0.9995, 0.0065, 1.0005)
	req.OriDriveIso = multiPolygon(
		rectRing(0.0055, -0.1005, 0.0065, -0.0995), // early unrelated drive component
		rectRing(0.0055, -0.0005, 0.0065, 0.0005),  // actual legal pickup component
	)
	driver := corridorDriver("origin-drive-before-walk-feasible-pickup", 0.006, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.006, Longitude: -0.10},
		{Latitude: 0.006, Longitude: 0},
		{Latitude: 0.006, Longitude: 1},
	})
	driver.RouteETAProfileSeconds = []int{0, 600, 1500}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if ok {
		t.Fatalf("expected unrelated early originDriveGeo entry not to provide rider walk lead time for the later pickup component")
	}
}

func TestComputeDriverScore_FallsBackWhenOriginDriveLeadProfileHasNoProgress(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "1000")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "0")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(0.0055, -0.0005, 0.0065, 0.0005)
	req.DestWalkIso = rectPolygon(0.0055, 0.9995, 0.0065, 1.0005)
	req.OriDriveIso = rectPolygon(0.0055, -0.1005, 0.0065, 0.0005)
	driver := corridorDriver("flat-origin-drive-lead-profile", 0.006, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.006, Longitude: -0.10},
		{Latitude: 0.006, Longitude: 0},
		{Latitude: 0.006, Longitude: 1},
	})
	driver.RouteETAProfileSeconds = []int{300, 300, 300}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected flat origin-drive lead profile to fall back to route-distance lead time instead of rejecting a rider-walk-feasible corridor")
	}
}

func TestComputeDriverScore_FallsBackWhenOriginDriveLeadProfileRegresses(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "1000")
	t.Setenv("PICKUP_WALK_TIMING_GRACE_SECONDS", "0")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(0.0055, -0.0005, 0.0065, 0.0005)
	req.DestWalkIso = rectPolygon(0.0055, 0.9995, 0.0065, 1.0005)
	req.OriDriveIso = rectPolygon(0.0055, -0.1005, 0.0065, 0.0005)
	driver := corridorDriver("regressing-origin-drive-lead-profile", 0.006, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0.006, Longitude: -0.10},
		{Latitude: 0.006, Longitude: -0.05},
		{Latitude: 0.006, Longitude: 0},
		{Latitude: 0.006, Longitude: 1},
	})
	driver.RouteETAProfileSeconds = []int{0, 600, 60, 1500}

	_, _, ok := computeDriverScore(req, driver, 1, 0.7, 0.3, 1)
	if !ok {
		t.Fatalf("expected regressing origin-drive lead profile to fall back to route-distance lead time instead of rejecting a rider-walk-feasible corridor")
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

func TestBuildSingleHopJourneyFallsBackWhenRouteEtaProfileRegressesBetweenPickupAndDropoff(t *testing.T) {
	req := corridorRequest()
	req.Destination = GeoPoint{Latitude: 0, Longitude: 0.01}
	req.OriWalkIso = rectPolygon(-0.001, -0.0001, 0.001, 0.0001)
	req.DestWalkIso = rectPolygon(-0.001, 0.009, 0.001, 0.011)
	req.OriDriveIso = GeoJSONGeometry{}
	driver := corridorDriver("driver-with-regressing-route-eta-profile", 0, -0.001, rectPolygon(-0.001, -0.002, 0.001, 0.011))
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.001},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 0.005},
		{Latitude: 0, Longitude: 0.01},
	})
	driver.RouteETAProfileSeconds = []int{0, 30, 10, 90}

	pickupEtaSec := 30
	journey := buildSingleHopJourney(req, driver, pickupEtaSec)
	expectedRideSec := int(haversineKm(0, 0, 0, 0.01) / 40.0 * 3600)
	expectedTotalSec := pickupEtaSec + expectedRideSec
	if journey.Legs[0].EstimatedTimeSeconds != expectedTotalSec || journey.TotalEstimatedTimeSeconds != expectedTotalSec {
		t.Fatalf("expected regressing route ETA profile to fall back to route-distance ETA %d, got leg=%d total=%d", expectedTotalSec, journey.Legs[0].EstimatedTimeSeconds, journey.TotalEstimatedTimeSeconds)
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

func TestBuildSingleHopJourneyIncludesReservationZoneIDs(t *testing.T) {
	req := corridorRequest()
	driver := corridorDriver("driver-with-zones", 0.01, 0, routeCorridor())
	driver.PickupZoneID = "zone-123"
	driver.DropoffZoneID = "zone-456"

	journey := buildSingleHopJourney(req, driver, 90)

	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	if journey.Legs[0].PickupZoneID != "zone-123" {
		t.Fatalf("expected leg pickupZoneId to preserve driver zone, got %q", journey.Legs[0].PickupZoneID)
	}
	if journey.Legs[0].DropoffZoneID != "zone-456" {
		t.Fatalf("expected leg dropoffZoneId to preserve driver zone, got %q", journey.Legs[0].DropoffZoneID)
	}

	payload, err := json.Marshal(journey)
	if err != nil {
		t.Fatalf("marshal journey: %v", err)
	}
	if !json.Valid(payload) || !strings.Contains(string(payload), `"pickupZoneId":"zone-123"`) || !strings.Contains(string(payload), `"dropoffZoneId":"zone-456"`) {
		t.Fatalf("expected JSON payload to expose pickupZoneId and dropoffZoneId, got %s", payload)
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

func TestBuildSingleHopJourneySkipsUnwalkableEarlyDropoffProjection(t *testing.T) {
	t.Setenv("MAX_SINGLE_HOP_WALK_METERS", "300")
	req := corridorRequest()
	req.OriWalkIso = rectPolygon(-0.0001, -0.0001, 0.0001, 0.0001)
	req.DestWalkIso = rectPolygon(-0.01, 0.40, 0.01, 1.001) // stale/broad polygon contains the early far dropoff candidate
	req.OriDriveIso = GeoJSONGeometry{}
	req.OriginDriveGeo = GeoJSONGeometry{}
	driver := corridorDriver("journey-later-walk-feasible-dropoff-route", 0, -0.10, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0.01, Longitude: 0.40}, // inside stale broad destination polygon, but outside explicit walk cap
		{Latitude: 0.002, Longitude: 1},   // first walk-feasible dropoff
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	leg := journey.Legs[0]
	if math.Abs(leg.Dropoff.Latitude-0.002) > 0.000001 || math.Abs(leg.Dropoff.Longitude-1) > 0.000001 {
		t.Fatalf("expected backend-selected dropoff to skip stale unwalkable early projection, got %#v", leg.Dropoff)
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

func TestBuildSingleHopJourneySkipsDestinationWalkPointOutsideDriveGeo(t *testing.T) {
	req := corridorRequest()
	req.DestWalkIso = rectPolygon(-0.02, 0.98, 0.02, 1.02)
	req.DestinationDriveGeo = rectPolygon(0.009, 0.999, 0.011, 1.001)
	driver := corridorDriver("driver-later-legal-destination-drive-dropoff", 0.01, 0, GeoJSONGeometry{})
	driver.RoutePolyline = encodePolyline([]GeoPoint{
		{Latitude: 0, Longitude: -0.10},
		{Latitude: 0, Longitude: 0},
		{Latitude: 0, Longitude: 1.00},    // destination walk only, outside destinationDriveGeo
		{Latitude: 0.01, Longitude: 1.00}, // legal walk+drive dropoff
	})

	journey := buildSingleHopJourney(req, driver, 90)
	if len(journey.Legs) != 1 {
		t.Fatalf("expected one leg, got %d", len(journey.Legs))
	}
	leg := journey.Legs[0]
	assertGeoPointNear(t, leg.Dropoff, GeoPoint{Latitude: 0.01, Longitude: 1.00})
}

func TestCalculateJourneyScoreDefaultsMissingCongestionToNeutral(t *testing.T) {
	got := calculateJourneyScore(600, 2, 0)
	want := calculateJourneyScore(600, 2, 1)
	if got != want {
		t.Fatalf("expected missing congestion factor to be neutral, got %f want %f", got, want)
	}
}

func TestCalculateJourneyScoreDefaultsNonFiniteCongestionToNeutral(t *testing.T) {
	want := calculateJourneyScore(600, 2, 1)
	for _, factor := range []float64{math.NaN(), math.Inf(1), math.Inf(-1)} {
		got := calculateJourneyScore(600, 2, factor)
		if got != want {
			t.Fatalf("expected non-finite congestion factor %v to be neutral, got %f want %f", factor, got, want)
		}
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

func TestBuildMultiHopJourneyIncludesDropoffZoneIDs(t *testing.T) {
	req := corridorRequest()
	transfer1 := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.33}, TransferTimeSeconds: 7}
	transfer2 := TransferPoint{Location: GeoPoint{Latitude: 0, Longitude: 0.66}, TransferTimeSeconds: 8}
	driver1 := corridorDriver("driver-leg-1-dropoff-zone", 0.01, 0, routeCorridor())
	driver1.PickupZoneID = "pickup-zone-leg-1"
	driver1.DropoffZoneID = "dropoff-zone-leg-1"
	driver2 := corridorDriver("driver-leg-2-dropoff-zone", 0.01, 0.33, routeCorridor())
	driver2.PickupZoneID = "pickup-zone-leg-2"
	driver2.DropoffZoneID = "dropoff-zone-leg-2"
	driver3 := corridorDriver("driver-leg-3-dropoff-zone", 0.01, 0.66, routeCorridor())
	driver3.PickupZoneID = "pickup-zone-leg-3"
	driver3.DropoffZoneID = "dropoff-zone-leg-3"

	journey2 := build2HopJourney(req, transfer1, driver1, 30, driver2, 40)
	if len(journey2.Legs) != 2 {
		t.Fatalf("expected two legs, got %d", len(journey2.Legs))
	}
	if journey2.Legs[0].DropoffZoneID != "dropoff-zone-leg-1" || journey2.Legs[1].DropoffZoneID != "dropoff-zone-leg-2" {
		t.Fatalf("expected 2-hop dropoffZoneIds to be preserved for reservation, got %#v", journey2.Legs)
	}

	journey3 := build3HopJourney(req, transfer1, transfer2, driver1, 30, driver2, 40, driver3, 50)
	if len(journey3.Legs) != 3 {
		t.Fatalf("expected three legs, got %d", len(journey3.Legs))
	}
	if journey3.Legs[0].DropoffZoneID != "dropoff-zone-leg-1" || journey3.Legs[1].DropoffZoneID != "dropoff-zone-leg-2" || journey3.Legs[2].DropoffZoneID != "dropoff-zone-leg-3" {
		t.Fatalf("expected 3-hop dropoffZoneIds to be preserved for reservation, got %#v", journey3.Legs)
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

func TestTransferAvailableCapacitySubtractsActivePickups(t *testing.T) {
	full := map[string]interface{}{"maxStopSeconds": int64(120), "activePickups": int64(2)}
	if got := transferAvailableCapacity(full); got != 0 {
		t.Fatalf("expected full transfer curb to have zero remaining capacity, got %d", got)
	}

	partiallyAvailable := map[string]interface{}{"maxStopSeconds": int64(120), "activePickups": int64(1)}
	if got := transferAvailableCapacity(partiallyAvailable); got != 1 {
		t.Fatalf("expected transfer capacity to subtract active pickups, got %d", got)
	}
}

func TestTransferAvailableCapacityAcceptsFloatMaxStopSeconds(t *testing.T) {
	data := map[string]interface{}{"maxStopSeconds": float64(180), "activePickups": int64(1)}
	if got := transferAvailableCapacity(data); got != 2 {
		t.Fatalf("expected float maxStopSeconds to produce remaining capacity 2, got %d", got)
	}
}

func TestUsableTransferPointsFiltersFullTransferCapacity(t *testing.T) {
	transfers := []TransferPoint{
		{ID: "full-transfer", Location: GeoPoint{Latitude: 0, Longitude: 0.25}, AvailableCapacity: 0},
		{ID: "available-transfer", Location: GeoPoint{Latitude: 0, Longitude: 0.50}, AvailableCapacity: 1},
		{ID: "overbooked-transfer", Location: GeoPoint{Latitude: 0, Longitude: 0.75}, AvailableCapacity: -1},
	}

	got := usableTransferPoints(transfers)
	if len(got) != 1 || got[0].ID != "available-transfer" {
		t.Fatalf("expected only positive-capacity transfer points to remain, got %#v", got)
	}
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

func TestBuildLegRequestPreservesOriginalDestinationDriveGeoForFinalLeg(t *testing.T) {
	req := corridorRequest()
	req.WalkRadiusM = 1500
	req.DestinationDriveGeo = rectPolygon(-0.001, 0.999, 0.001, 1.001)
	transfer := GeoPoint{Latitude: 0, Longitude: 0.5}

	legReq := buildLegRequest(req, transfer, req.Destination)

	if !reflect.DeepEqual(legReq.DestinationDriveGeo, req.DestinationDriveGeo) {
		t.Fatalf("expected final leg to preserve original destinationDriveGeo; got %#v", legReq.DestinationDriveGeo)
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
