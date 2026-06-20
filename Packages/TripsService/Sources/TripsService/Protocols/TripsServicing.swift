import Foundation
import Combine

// MARK: - Main Service Protocol

/// Protocol defining all trips service operations
public protocol TripsServicing {
    
    // MARK: - Trip Management
    
    /// Create a new trip
    func createTrip(title: String, scope: TripScope, duration: TripDuration, constraints: TripConstraints) async throws -> Trip
    
    /// Get trip by ID
    func getTrip(id: String) async throws -> Trip
    
    /// Get all user's trips
    func getMyTrips() async throws -> [Trip]
    
    /// Update trip details
    func updateTrip(_ trip: Trip) async throws -> Trip
    
    /// Delete a trip
    func deleteTrip(id: String) async throws
    
    /// Invite members to trip
    func inviteMembers(tripId: String, emails: [String], role: MemberRole) async throws
    
    // MARK: - Intake & Preferences
    
    /// Process voice/text intake for trip preferences
    func processIntake(tripId: String, input: String, type: IntakeType) async throws -> IntakeResult
    
    /// Update traveler preferences
    func updatePreferences(tripId: String, preferences: TravelerPreferences) async throws
    
    // MARK: - Itinerary Planning
    
    /// Generate itinerary for trip
    func planItinerary(tripId: String, options: PlanningOptions) async throws -> PlanningJob
    
    /// Get planning job status
    func getPlanningStatus(jobId: String) async throws -> PlanningJob
    
    /// Replace a segment with alternative
    func replaceSegment(tripId: String, segmentId: String, alternativeId: String) async throws -> Itinerary
    
    /// Get segment alternatives
    func getAlternatives(tripId: String, segmentId: String) async throws -> [Segment]
    
    /// Manually add segment to itinerary
    func addSegment(tripId: String, segment: Segment, dayNumber: Int) async throws -> Itinerary
    
    /// Remove segment from itinerary
    func removeSegment(tripId: String, segmentId: String) async throws -> Itinerary
    
    // MARK: - Booking Management
    
    /// Book confirmed segments
    func bookSegments(tripId: String, segmentIds: [String], paymentMethod: String) async throws -> BookingResult
    
    /// Get booking details
    func getBooking(id: String) async throws -> Booking
    
    /// Cancel booking
    func cancelBooking(bookingId: String, reason: String) async throws -> CancellationResult
    
    /// Modify booking
    func modifyBooking(bookingId: String, changes: BookingModification) async throws -> Booking
    
    // MARK: - Compliance & Documentation
    
    /// Get compliance requirements
    func getCompliance(tripId: String) async throws -> CompliancePack
    
    /// Update compliance checklist item
    func updateComplianceItem(tripId: String, itemId: String, completed: Bool) async throws
    
    /// Upload document
    func uploadDocument(tripId: String, document: Data, type: DocumentType) async throws -> String
    
    // MARK: - Budget Management
    
    /// Get budget plan
    func getBudgetPlan(tripId: String) async throws -> BudgetPlan
    
    /// Update budget plan
    func updateBudget(tripId: String, budget: BudgetPlan) async throws -> BudgetPlan
    
    /// Add expense
    func addExpense(tripId: String, expense: Expense) async throws
    
    /// Get price tracking
    func trackPrice(itemType: TrackableItemType, itemId: String) async throws -> PriceTracker
    
    /// Start savings plan
    func createSavingsPlan(tripId: String, targetAmount: Money, targetDate: Date) async throws -> SavingsPlan
    
    // MARK: - Real-time Assistance
    
    /// Get current trip segment (during active trip)
    func getCurrentSegment(tripId: String) async throws -> Segment?
    
    /// Report disruption
    func reportDisruption(tripId: String, segmentId: String, type: DisruptionType) async throws
    
    /// Request ride for segment
    func requestRide(tripId: String, segmentId: String) async throws -> RideRequest
    
    /// Get emergency contacts
    func getEmergencyContacts(tripId: String) async throws -> [ContactInfo]
    
    // MARK: - Search & Discovery
    
    /// Search destinations
    func searchDestinations(query: String, filters: DestinationFilters?) async throws -> [Destination]
    
    /// Search POIs
    func searchPOIs(location: String, type: POIType?, radius: Int?) async throws -> [PointOfInterest]
    
    /// Search flights
    func searchFlights(from: String, to: String, date: Date, returnDate: Date?) async throws -> [FlightOption]
    
    /// Search hotels
    func searchHotels(location: String, checkIn: Date, checkOut: Date, guests: Int) async throws -> [HotelOption]
    
    /// Get availability calendar
    func getAvailability(type: AvailabilityType, location: String, month: Date) async throws -> AvailabilityCalendar
    
    // MARK: - Voice Assistant
    
    /// Start voice planning session
    func startVoiceSession(tripId: String?) async throws -> VoiceSession
    
    /// Send voice command
    func sendVoiceCommand(sessionId: String, audioData: Data) async throws -> VoiceResponse
    
    /// End voice session
    func endVoiceSession(sessionId: String) async throws
    
    // MARK: - Publishers
    
    /// Trip updates publisher
    var tripUpdates: AnyPublisher<Trip, Never> { get }
    
    /// Itinerary updates publisher
    var itineraryUpdates: AnyPublisher<Itinerary, Never> { get }
    
    /// Budget alerts publisher
    var budgetAlerts: AnyPublisher<BudgetAlert, Never> { get }
    
    /// Disruption alerts publisher
    var disruptionAlerts: AnyPublisher<DisruptionAlert, Never> { get }
    
    /// Planning progress publisher
    var planningProgress: AnyPublisher<PlanningProgress, Never> { get }
}

// MARK: - Supporting Types

/// Intake type
public enum IntakeType: String, Codable {
    case text
    case voice
    case structured
}

/// Intake processing result
public struct IntakeResult: Codable {
    public let understood: Bool
    public let extractedPreferences: TravelerPreferences?
    public let extractedConstraints: TripConstraints?
    public let suggestedDestinations: [String]
    public let clarificationNeeded: [String]
    
    public init(
        understood: Bool,
        extractedPreferences: TravelerPreferences? = nil,
        extractedConstraints: TripConstraints? = nil,
        suggestedDestinations: [String] = [],
        clarificationNeeded: [String] = []
    ) {
        self.understood = understood
        self.extractedPreferences = extractedPreferences
        self.extractedConstraints = extractedConstraints
        self.suggestedDestinations = suggestedDestinations
        self.clarificationNeeded = clarificationNeeded
    }
}

/// Planning options
public struct PlanningOptions: Codable {
    public let priority: PlanningPriority
    public let optimizeFor: [OptimizationGoal]
    public let includeAlternatives: Bool
    public let maxAlternatives: Int
    public let dryRun: Bool
    
    public init(
        priority: PlanningPriority = .balanced,
        optimizeFor: [OptimizationGoal] = [.cost, .time],
        includeAlternatives: Bool = true,
        maxAlternatives: Int = 3,
        dryRun: Bool = false
    ) {
        self.priority = priority
        self.optimizeFor = optimizeFor
        self.includeAlternatives = includeAlternatives
        self.maxAlternatives = maxAlternatives
        self.dryRun = dryRun
    }
}

/// Planning priority
public enum PlanningPriority: String, Codable {
    case express // Fast planning, may be suboptimal
    case balanced // Normal planning
    case thorough // Comprehensive planning, slower
}

/// Optimization goals
public enum OptimizationGoal: String, Codable {
    case cost
    case time
    case comfort
    case experience
    case safety
    case sustainability
}

/// Planning job
public struct PlanningJob: Codable {
    public let id: String
    public let tripId: String
    public let status: JobStatus
    public let progress: Double
    public let estimatedCompletion: Date?
    public let result: Itinerary?
    public let error: String?
    
    public init(
        id: String,
        tripId: String,
        status: JobStatus,
        progress: Double,
        estimatedCompletion: Date? = nil,
        result: Itinerary? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.tripId = tripId
        self.status = status
        self.progress = progress
        self.estimatedCompletion = estimatedCompletion
        self.result = result
        self.error = error
    }
}

/// Job status
public enum JobStatus: String, Codable {
    case queued
    case processing
    case completed
    case failed
    case cancelled
}

/// Booking result
public struct BookingResult: Codable {
    public let successful: [Booking]
    public let failed: [BookingFailure]
    public let totalCost: Money
    public let paymentStatus: PaymentStatus
    
    public init(
        successful: [Booking],
        failed: [BookingFailure],
        totalCost: Money,
        paymentStatus: PaymentStatus
    ) {
        self.successful = successful
        self.failed = failed
        self.totalCost = totalCost
        self.paymentStatus = paymentStatus
    }
}

/// Booking failure
public struct BookingFailure: Codable {
    public let segmentId: String
    public let reason: String
    public let retryable: Bool
    
    public init(segmentId: String, reason: String, retryable: Bool) {
        self.segmentId = segmentId
        self.reason = reason
        self.retryable = retryable
    }
}

/// Payment status
public enum PaymentStatus: String, Codable {
    case pending
    case authorized
    case captured
    case failed
    case refunded
}

/// Cancellation result
public struct CancellationResult: Codable {
    public let bookingId: String
    public let cancelled: Bool
    public let fee: Money?
    public let refundAmount: Money?
    public let refundTimeline: String?
    
    public init(
        bookingId: String,
        cancelled: Bool,
        fee: Money? = nil,
        refundAmount: Money? = nil,
        refundTimeline: String? = nil
    ) {
        self.bookingId = bookingId
        self.cancelled = cancelled
        self.fee = fee
        self.refundAmount = refundAmount
        self.refundTimeline = refundTimeline
    }
}

/// Booking modification
public struct BookingModification: Codable {
    public let type: ModificationType
    public let details: [String: String]
    
    public init(type: ModificationType, details: [String: String]) {
        self.type = type
        self.details = details
    }
}

/// Modification type
public enum ModificationType: String, Codable {
    case date_change
    case passenger_change
    case seat_selection
    case upgrade
    case downgrade
}

/// Disruption type
public enum DisruptionType: String, Codable {
    case flight_delay
    case flight_cancellation
    case missed_connection
    case hotel_issue
    case weather
    case strike
    case other
}

/// Disruption alert
public struct DisruptionAlert: Codable {
    public let tripId: String
    public let segmentId: String
    public let type: DisruptionType
    public let severity: AlertSeverity
    public let message: String
    public let suggestedActions: [String]
    public let timestamp: Date
    
    public init(
        tripId: String,
        segmentId: String,
        type: DisruptionType,
        severity: AlertSeverity,
        message: String,
        suggestedActions: [String],
        timestamp: Date = Date()
    ) {
        self.tripId = tripId
        self.segmentId = segmentId
        self.type = type
        self.severity = severity
        self.message = message
        self.suggestedActions = suggestedActions
        self.timestamp = timestamp
    }
}

/// Planning progress
public struct PlanningProgress: Codable {
    public let jobId: String
    public let stage: PlanningStage
    public let progress: Double
    public let message: String
    
    public init(jobId: String, stage: PlanningStage, progress: Double, message: String) {
        self.jobId = jobId
        self.stage = stage
        self.progress = progress
        self.message = message
    }
}

/// Planning stage
public enum PlanningStage: String, Codable {
    case initializing
    case searching_flights
    case searching_hotels
    case finding_activities
    case optimizing
    case validating
    case finalizing
}

/// Ride request
public struct RideRequest: Codable {
    public let id: String
    public let tripId: String
    public let segmentId: String
    public let pickupLocation: String
    public let dropoffLocation: String
    public let pickupTime: Date
    public let status: String
    public let rideServiceId: String?
    
    public init(
        id: String,
        tripId: String,
        segmentId: String,
        pickupLocation: String,
        dropoffLocation: String,
        pickupTime: Date,
        status: String,
        rideServiceId: String? = nil
    ) {
        self.id = id
        self.tripId = tripId
        self.segmentId = segmentId
        self.pickupLocation = pickupLocation
        self.dropoffLocation = dropoffLocation
        self.pickupTime = pickupTime
        self.status = status
        self.rideServiceId = rideServiceId
    }
}