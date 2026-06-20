import Foundation
import Combine

/// Mock implementation of TripsServicing for development and testing
public class MockTripsService: TripsServicing {
    
    // MARK: - Properties
    
    private var trips: [String: Trip] = [:]
    private var bookings: [String: Booking] = [:]
    private var itineraries: [String: Itinerary] = [:]
    private var planningJobs: [String: PlanningJob] = [:]
    private var voiceSessions: [String: VoiceSession] = [:]
    
    // Publishers
    private let tripUpdatesSubject = PassthroughSubject<Trip, Never>()
    private let itineraryUpdatesSubject = PassthroughSubject<Itinerary, Never>()
    private let budgetAlertsSubject = PassthroughSubject<BudgetAlert, Never>()
    private let disruptionAlertsSubject = PassthroughSubject<DisruptionAlert, Never>()
    private let planningProgressSubject = PassthroughSubject<PlanningProgress, Never>()
    
    public var tripUpdates: AnyPublisher<Trip, Never> {
        tripUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var itineraryUpdates: AnyPublisher<Itinerary, Never> {
        itineraryUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var budgetAlerts: AnyPublisher<BudgetAlert, Never> {
        budgetAlertsSubject.eraseToAnyPublisher()
    }
    
    public var disruptionAlerts: AnyPublisher<DisruptionAlert, Never> {
        disruptionAlertsSubject.eraseToAnyPublisher()
    }
    
    public var planningProgress: AnyPublisher<PlanningProgress, Never> {
        planningProgressSubject.eraseToAnyPublisher()
    }
    
    public init() {
        setupMockData()
    }
    
    // MARK: - Trip Management
    
    public func createTrip(title: String, scope: TripScope, duration: TripDuration, constraints: TripConstraints) async throws -> Trip {
        let trip = Trip(
            ownerId: "mock-user",
            title: title,
            scope: scope,
            duration: duration,
            startWindow: DateInterval(start: Date(), duration: TimeInterval(duration.days * 24 * 60 * 60)),
            constraints: constraints
        )
        trips[trip.id] = trip
        tripUpdatesSubject.send(trip)
        return trip
    }
    
    public func getTrip(id: String) async throws -> Trip {
        guard let trip = trips[id] else {
            throw TripsError.tripNotFound
        }
        return trip
    }
    
    public func getMyTrips() async throws -> [Trip] {
        return Array(trips.values)
    }
    
    public func updateTrip(_ trip: Trip) async throws -> Trip {
        trips[trip.id] = trip
        tripUpdatesSubject.send(trip)
        return trip
    }
    
    public func deleteTrip(id: String) async throws {
        trips.removeValue(forKey: id)
    }
    
    public func inviteMembers(tripId: String, emails: [String], role: MemberRole) async throws {
        guard var trip = trips[tripId] else {
            throw TripsError.tripNotFound
        }
        
        for email in emails {
            let member = TripMember(
                userId: UUID().uuidString,
                name: "Mock User",
                role: role
            )
            trip.members.append(member)
        }
        
        trips[tripId] = trip
        tripUpdatesSubject.send(trip)
    }
    
    // MARK: - Intake & Preferences
    
    public func processIntake(tripId: String, input: String, type: IntakeType) async throws -> IntakeResult {
        // Simulate AI processing
        try await Task.sleep(nanoseconds: 500_000_000)
        
        return IntakeResult(
            understood: true,
            extractedPreferences: TravelerPreferences(
                destinations: ["Paris, France"],
                climatePreference: .temperate,
                activityTypes: [.sightseeing, .culinary, .hiking],
                accommodationType: .hotel,
                transportPreference: .balanced,
                languages: ["en"]
            ),
            suggestedDestinations: ["Paris, France", "Tokyo, Japan", "Barcelona, Spain"],
            clarificationNeeded: []
        )
    }
    
    public func updatePreferences(tripId: String, preferences: TravelerPreferences) async throws {
        guard var trip = trips[tripId] else {
            throw TripsError.tripNotFound
        }
        // Mirror into metadata tags for mock purposes
        trip.metadata.tags = preferences.destinations
        trips[tripId] = trip
        tripUpdatesSubject.send(trip)
    }
    
    // MARK: - Itinerary Planning
    
    public func planItinerary(tripId: String, options: PlanningOptions) async throws -> PlanningJob {
        let jobId = UUID().uuidString
        let job = PlanningJob(
            id: jobId,
            tripId: tripId,
            status: .processing,
            progress: 0.0,
            estimatedCompletion: Date().addingTimeInterval(30)
        )
        planningJobs[jobId] = job
        
        // Simulate planning progress
        Task {
            for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                let stage = PlanningStage.allCases[min(Int(progress * Double(PlanningStage.allCases.count)), PlanningStage.allCases.count - 1)]
                
                planningProgressSubject.send(PlanningProgress(
                    jobId: jobId,
                    stage: stage,
                    progress: progress,
                    message: "Processing \(stage.rawValue)..."
                ))
                
                if progress >= 1.0 {
                    let itinerary = createMockItinerary(tripId: tripId)
                    itineraries[tripId] = itinerary
                    
                    planningJobs[jobId] = PlanningJob(
                        id: job.id,
                        tripId: job.tripId,
                        status: .completed,
                        progress: 1.0,
                        estimatedCompletion: job.estimatedCompletion,
                        result: itinerary,
                        error: nil
                    )
                    
                    itineraryUpdatesSubject.send(itinerary)
                }
            }
        }
        
        return job
    }
    
    public func getPlanningStatus(jobId: String) async throws -> PlanningJob {
        guard let job = planningJobs[jobId] else {
            throw TripsError.planningJobNotFound
        }
        return job
    }
    
    public func replaceSegment(tripId: String, segmentId: String, alternativeId: String) async throws -> Itinerary {
        guard var itinerary = itineraries[tripId] else {
            throw TripsError.itineraryNotFound
        }
        
        // Find and replace segment id in itinerary days; also replace the matching segment instance in the array
        if let segIndexGlobal = itinerary.segments.firstIndex(where: { $0.id == segmentId }) {
            var newSegment = itinerary.segments[segIndexGlobal]
            newSegment = Segment(
                id: alternativeId,
                type: newSegment.type,
                title: newSegment.title,
                description: newSegment.description,
                timeWindow: newSegment.timeWindow,
                location: newSegment.location,
                content: newSegment.content,
                cost: newSegment.cost,
                bookingRef: newSegment.bookingRef,
                mediaRefs: newSegment.mediaRefs,
                notes: newSegment.notes,
                safety: newSegment.safety,
                status: newSegment.status,
                metadata: newSegment.metadata
            )
            itinerary.segments[segIndexGlobal] = newSegment
        }
        for dayIndex in itinerary.days.indices {
            itinerary.days[dayIndex].segments = itinerary.days[dayIndex].segments.map { $0 == segmentId ? alternativeId : $0 }
        }
        
        itineraries[tripId] = itinerary
        itineraryUpdatesSubject.send(itinerary)
        return itinerary
    }
    
    public func getAlternatives(tripId: String, segmentId: String) async throws -> [Segment] {
        // Return mock alternatives
        return [
            createMockSegment(type: .activity),
            createMockSegment(type: .activity),
            createMockSegment(type: .activity)
        ]
    }
    
    public func addSegment(tripId: String, segment: Segment, dayNumber: Int) async throws -> Itinerary {
        guard var itinerary = itineraries[tripId] else {
            throw TripsError.itineraryNotFound
        }
        
        if dayNumber < itinerary.days.count {
            itinerary.days[dayNumber].segments.append(segment.id)
            itinerary.segments.append(segment)
            itineraries[tripId] = itinerary
            itineraryUpdatesSubject.send(itinerary)
        }
        
        return itinerary
    }
    
    public func removeSegment(tripId: String, segmentId: String) async throws -> Itinerary {
        guard var itinerary = itineraries[tripId] else {
            throw TripsError.itineraryNotFound
        }
        
        for dayIndex in itinerary.days.indices {
            itinerary.days[dayIndex].segments.removeAll { $0 == segmentId }
        }
        itinerary.segments.removeAll { $0.id == segmentId }
        
        itineraries[tripId] = itinerary
        itineraryUpdatesSubject.send(itinerary)
        return itinerary
    }
    
    // MARK: - Booking Management
    
    public func bookSegments(tripId: String, segmentIds: [String], paymentMethod: String) async throws -> BookingResult {
        var successful: [Booking] = []
        
        for segmentId in segmentIds {
            let booking = Booking(
                tripId: tripId,
                segmentId: segmentId,
                type: .activity,
                vendor: VendorInfo(
                    id: UUID().uuidString,
                    name: "Mock Vendor",
                    type: .tour_operator
                ),
                status: .confirmed,
                price: Money(amount: 150.00),
                currency: "USD",
                policies: BookingPolicies(),
                confirmationCodes: ["MOCK-\(UUID().uuidString.prefix(6))"]
            )
            bookings[booking.id] = booking
            successful.append(booking)
        }
        
        return BookingResult(
            successful: successful,
            failed: [],
            totalCost: Money(amount: Double(successful.count) * 150.00),
            paymentStatus: .captured
        )
    }
    
    public func getBooking(id: String) async throws -> Booking {
        guard let booking = bookings[id] else {
            throw TripsError.bookingNotFound
        }
        return booking
    }
    
    public func cancelBooking(bookingId: String, reason: String) async throws -> CancellationResult {
        guard var booking = bookings[bookingId] else {
            throw TripsError.bookingNotFound
        }
        
        booking.status = .cancelled
        booking.cancellationInfo = CancellationInfo(
            cancelledAt: Date(),
            reason: reason,
            fee: Money(amount: 25.00),
            refundAmount: Money(amount: 125.00),
            refundStatus: .pending
        )
        
        bookings[bookingId] = booking
        
        return CancellationResult(
            bookingId: bookingId,
            cancelled: true,
            fee: Money(amount: 25.00),
            refundAmount: Money(amount: 125.00),
            refundTimeline: "5-7 business days"
        )
    }
    
    public func modifyBooking(bookingId: String, changes: BookingModification) async throws -> Booking {
        guard var booking = bookings[bookingId] else {
            throw TripsError.bookingNotFound
        }
        
        booking.modifiedAt = Date()
        bookings[bookingId] = booking
        
        return booking
    }
    
    // MARK: - Compliance & Documentation
    
    public func getCompliance(tripId: String) async throws -> CompliancePack {
        return CompliancePack(
            visaRequirements: [
                VisaRequirement(
                    country: "France",
                    type: .tourist,
                    required: false,
                    processingTime: "N/A",
                    validityPeriod: "90 days",
                    cost: Money(amount: 0.0),
                    documents: [],
                    notes: "Visa-free for US citizens up to 90 days"
                )
            ],
            checklist: [
                ComplianceItem(
                    category: .documentation,
                    title: "Valid Passport",
                    description: "Ensure passport is valid for at least 6 months",
                    mandatory: true,
                    deadline: Date().addingTimeInterval(30 * 24 * 60 * 60)
                )
            ],
            deadlines: [],
            healthRequirements: []
        )
    }
    
    public func updateComplianceItem(tripId: String, itemId: String, completed: Bool) async throws {
        // Update mock compliance item
    }
    
    public func uploadDocument(tripId: String, document: Data, type: DocumentType) async throws -> String {
        return "mock-document-\(UUID().uuidString)"
    }
    
    // MARK: - Budget Management
    
    public func getBudgetPlan(tripId: String) async throws -> BudgetPlan {
        return BudgetPlan(
            tripId: tripId,
            target: Money(amount: 5000.00),
            current: Money(amount: 1250.00),
            forecast: Money(amount: 4800.00),
            allocations: [
                BudgetAllocation(
                    category: .accommodation,
                    allocated: Money(amount: 2000.00),
                    spent: Money(amount: 500.00),
                    percentage: 40.0
                ),
                BudgetAllocation(
                    category: .transport,
                    allocated: Money(amount: 1500.00),
                    spent: Money(amount: 400.00),
                    percentage: 30.0
                )
            ]
        )
    }
    
    public func updateBudget(tripId: String, budget: BudgetPlan) async throws -> BudgetPlan {
        return budget
    }
    
    public func addExpense(tripId: String, expense: Expense) async throws {
        // Add expense to mock data
    }
    
    public func trackPrice(itemType: TrackableItemType, itemId: String) async throws -> PriceTracker {
        return PriceTracker(
            itemType: itemType,
            itemId: itemId,
            itemDescription: "Mock \(itemType.rawValue)",
            priceHistory: [
                PricePoint(price: Money(amount: 320.00), date: Date().addingTimeInterval(-7 * 24 * 60 * 60)),
                PricePoint(price: Money(amount: 310.00), date: Date().addingTimeInterval(-3 * 24 * 60 * 60)),
                PricePoint(price: Money(amount: 299.00), date: Date())
            ],
            alertThreshold: nil,
            currentPrice: Money(amount: 299.00),
            startedAt: Date(),
            lastCheckedAt: Date()
        )
    }
    
    public func createSavingsPlan(tripId: String, targetAmount: Money, targetDate: Date) async throws -> SavingsPlan {
        let monthsUntilTrip = max(1, Calendar.current.dateComponents([.month], from: Date(), to: targetDate).month ?? 1)
        let monthlyAmount = targetAmount.amount / Decimal(monthsUntilTrip)
        
        return SavingsPlan(
            targetAmount: targetAmount,
            startDate: Date(),
            targetDate: targetDate,
            frequency: .monthly,
            suggestedAmount: Money(amount: monthlyAmount, currency: targetAmount.currency)
        )
    }
    
    // MARK: - Real-time Assistance
    
    public func getCurrentSegment(tripId: String) async throws -> Segment? {
        guard let itinerary = itineraries[tripId] else {
            return nil
        }
        
        // Return first segment for demo
        return itinerary.segments.first
    }
    
    public func reportDisruption(tripId: String, segmentId: String, type: DisruptionType) async throws {
        let alert = DisruptionAlert(
            tripId: tripId,
            segmentId: segmentId,
            type: type,
            severity: .warning,
            message: "Disruption reported: \(type.rawValue)",
            suggestedActions: ["Contact airline", "Check alternative flights", "Review insurance coverage"]
        )
        
        disruptionAlertsSubject.send(alert)
    }
    
    public func requestRide(tripId: String, segmentId: String) async throws -> RideRequest {
        return RideRequest(
            id: UUID().uuidString,
            tripId: tripId,
            segmentId: segmentId,
            pickupLocation: "Current Location",
            dropoffLocation: "Airport Terminal 2",
            pickupTime: Date().addingTimeInterval(15 * 60),
            status: "requested"
        )
    }
    
    public func getEmergencyContacts(tripId: String) async throws -> [ContactInfo] {
        return [
            ContactInfo(
                name: "Emergency Services",
                phone: "911",
                email: nil
            ),
            ContactInfo(
                name: "Trip Insurance",
                phone: "1-800-INSURANCE",
                email: "claims@insurance.com"
            )
        ]
    }
    
    // MARK: - Search & Discovery
    
    public func searchDestinations(query: String, filters: DestinationFilters?) async throws -> [Destination] {
        return [
            Destination(
                name: "Paris",
                country: "France",
                type: .city,
                description: "The City of Light offers iconic landmarks, world-class museums, and exquisite cuisine.",
                imageURL: "https://example.com/paris.jpg",
                popularMonths: [4, 5, 6, 9, 10],
                attractions: ["Eiffel Tower", "Louvre Museum", "Notre-Dame"],
                avgCostPerDay: Money(amount: 150.00),
                safetyRating: 4.2,
                tags: ["romantic", "culture", "food", "history"]
            ),
            Destination(
                name: "Tokyo",
                country: "Japan",
                type: .city,
                description: "A vibrant metropolis blending ancient tradition with cutting-edge technology.",
                imageURL: "https://example.com/tokyo.jpg",
                popularMonths: [3, 4, 10, 11],
                attractions: ["Senso-ji Temple", "Tokyo Tower", "Shibuya Crossing"],
                avgCostPerDay: Money(amount: 120.00),
                safetyRating: 4.8,
                tags: ["technology", "culture", "food", "shopping"]
            )
        ]
    }
    
    public func searchPOIs(location: String, type: POIType?, radius: Int?) async throws -> [PointOfInterest] {
        return [
            PointOfInterest(
                name: "Eiffel Tower",
                type: .monument,
                description: "Iconic iron lattice tower and symbol of Paris",
                location: Location(name: "Eiffel Tower", address: "Champ de Mars, Paris", coordinates: Coordinates(latitude: 48.8584, longitude: 2.2945)),
                rating: 4.6,
                reviewCount: 145000,
                priceLevel: .moderate,
                duration: 2 * 60 * 60,
                ticketPrice: Money(amount: 28.30),
                bookingRequired: true,
                tags: ["landmark", "views", "historic"]
            )
        ]
    }
    
    public func searchFlights(from: String, to: String, date: Date, returnDate: Date?) async throws -> [FlightOption] {
        let outbound = FlightLeg(
            segments: [
                FlightSegment(
                    airline: "Mock Air",
                    flightNumber: "MA123",
                    departure: Airport(code: "JFK", name: "John F. Kennedy", city: "New York", country: "USA", terminal: "4"),
                    arrival: Airport(code: "CDG", name: "Charles de Gaulle", city: "Paris", country: "France", terminal: "2E"),
                    departureTime: date,
                    arrivalTime: date.addingTimeInterval(8 * 60 * 60),
                    duration: 8 * 60 * 60
                )
            ],
            totalDuration: 8 * 60 * 60,
            stops: 0
        )
        
        var inbound: FlightLeg? = nil
        if let returnDate = returnDate {
            inbound = FlightLeg(
                segments: [
                    FlightSegment(
                        airline: "Mock Air",
                        flightNumber: "MA456",
                        departure: Airport(code: "CDG", name: "Charles de Gaulle", city: "Paris", country: "France", terminal: "2E"),
                        arrival: Airport(code: "JFK", name: "John F. Kennedy", city: "New York", country: "USA", terminal: "4"),
                        departureTime: returnDate,
                        arrivalTime: returnDate.addingTimeInterval(9 * 60 * 60),
                        duration: 9 * 60 * 60
                    )
                ],
                totalDuration: 9 * 60 * 60,
                stops: 0
            )
        }
        
        return [
            FlightOption(
                outbound: outbound,
                inbound: inbound,
                price: Money(amount: 850.00),
                bookingClass: "Economy",
                baggageIncluded: BaggageInfo(carry: 1, checked: 1, weight: 23),
                changeable: true,
                refundable: false,
                provider: "Mock Travel"
            )
        ]
    }
    
    public func searchHotels(location: String, checkIn: Date, checkOut: Date, guests: Int) async throws -> [HotelOption] {
        return [
            HotelOption(
                name: "Grand Hotel Paris",
                address: "123 Champs-Élysées, Paris",
                location: Location(name: "Grand Hotel Paris", address: "123 Champs-Élysées", coordinates: Coordinates(latitude: 48.8698, longitude: 2.3078)),
                starRating: 5,
                guestRating: 4.7,
                reviewCount: 2341,
                roomTypes: [
                    RoomType(
                        name: "Deluxe Room",
                        description: "Elegant room with city views",
                        maxOccupancy: 2,
                        bedConfiguration: "1 King bed",
                        size: 35,
                        price: Money(amount: 450.00),
                        breakfast: true,
                        available: 3
                    )
                ],
                amenities: ["WiFi", "Pool", "Spa", "Gym", "Restaurant", "Bar"],
                images: ["https://example.com/hotel1.jpg"],
                cancellationPolicy: "Free cancellation up to 24 hours before check-in",
                provider: "Mock Hotels"
            )
        ]
    }
    
    public func getAvailability(type: AvailabilityType, location: String, month: Date) async throws -> AvailabilityCalendar {
        var days: [DayAvailability] = []
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: month)!
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: calendar.startOfDay(for: month)) {
                days.append(DayAvailability(
                    date: date,
                    available: Bool.random(),
                    price: Money(amount: Double.random(in: 100...500)),
                    remaining: Int.random(in: 0...10)
                ))
            }
        }
        
        return AvailabilityCalendar(
            type: type,
            location: location,
            month: month,
            days: days
        )
    }
    
    // MARK: - Voice Assistant
    
    public func startVoiceSession(tripId: String?) async throws -> VoiceSession {
        let session = VoiceSession(
            id: UUID().uuidString,
            tripId: tripId,
            startedAt: Date(),
            language: "en-US",
            status: .active
        )
        voiceSessions[session.id] = session
        return session
    }
    
    public func sendVoiceCommand(sessionId: String, audioData: Data) async throws -> VoiceResponse {
        return VoiceResponse(
            sessionId: sessionId,
            understood: true,
            action: "search_flights",
            parameters: ["from": "New York", "to": "Paris"],
            response: "I found several flights from New York to Paris. The best option is $850 on Mock Air.",
            requiresConfirmation: false
        )
    }
    
    public func endVoiceSession(sessionId: String) async throws {
        voiceSessions.removeValue(forKey: sessionId)
    }
    
    // MARK: - Private Helpers
    
    private func setupMockData() {
        // Create sample trip
        let sampleTrip = Trip(
            ownerId: "mock-user",
            title: "European Adventure",
            scope: .international,
            duration: TripDuration(days: 7, nights: 6, isFlexible: false),
            startWindow: DateInterval(start: Date().addingTimeInterval(30 * 24 * 60 * 60), duration: 7 * 24 * 60 * 60),
            constraints: TripConstraints(
                budget: BudgetConstraint(total: Money(amount: 5000.0)),
                seasons: [.spring],
                visaRequirements: [],
                accessibility: AccessibilityNeeds(),
                dietary: [],
                mobility: .normal,
                familyFriendly: false,
                petFriendly: false,
                mustInclude: ["Paris", "Rome"],
                mustAvoid: []
            ),
            status: .planned
        )
        trips[sampleTrip.id] = sampleTrip
        
        // Create sample itinerary
        let sampleItinerary = createMockItinerary(tripId: sampleTrip.id)
        itineraries[sampleTrip.id] = sampleItinerary
    }
    
    private func createMockItinerary(tripId: String) -> Itinerary {
        var days: [ItineraryDay] = []
        var allSegments: [Segment] = []
        
        for dayNum in 1...7 {
            let seg1 = createMockSegment(type: .activity)
            let seg2 = createMockSegment(type: .meal)
            let seg3 = createMockSegment(type: .activity)
            allSegments.append(contentsOf: [seg1, seg2, seg3])
            let day = ItineraryDay(
                dayNumber: dayNum,
                date: Date().addingTimeInterval(Double(29 + dayNum) * 24 * 60 * 60),
                title: "Day \(dayNum)",
                segments: [seg1.id, seg2.id, seg3.id]
            )
            days.append(day)
        }
        
        return Itinerary(
            days: days,
            segments: allSegments,
            alternativeOptions: [:],
            optimizationScore: nil
        )
    }
    
    private func createMockSegment(type: SegmentType) -> Segment {
        switch type {
        case .activity:
            return Segment(
                type: .activity,
                title: "Museum Visit",
                description: "Explore the local art museum",
                timeWindow: DateInterval(start: Date(), duration: 2 * 60 * 60),
                location: Location(name: "Louvre Museum", address: "Museum Address", coordinates: Coordinates(latitude: 48.8606, longitude: 2.3376)),
                content: .activity(ActivityInfo(name: "Museum Visit", type: .cultural, venue: "Louvre", address: "Museum Address", duration: 2 * 60 * 60, ticketRequired: true, ticketInfo: nil, guideInfo: nil, difficulty: .easy)),
                cost: Money(amount: 25.0),
                status: .planned
            )
        case .meal:
            return Segment(
                type: .meal,
                title: "Lunch at Bistro",
                description: "Traditional local cuisine",
                timeWindow: DateInterval(start: Date(), duration: 1.5 * 60 * 60),
                location: Location(name: "Local Bistro", address: "Bistro Address", coordinates: Coordinates(latitude: 48.8566, longitude: 2.3522)),
                content: .meal(MealInfo(restaurant: "Local Bistro", cuisine: "French", address: "Bistro Address", reservationTime: nil, reservationName: nil, dietaryOptions: [])),
                cost: Money(amount: 45.0),
                status: .planned
            )
        default:
            return Segment(
                type: type,
                title: "\(type.rawValue.capitalized) Segment",
                description: "Mock \(type.rawValue) segment",
                timeWindow: DateInterval(start: Date(), duration: 2 * 60 * 60),
                location: Location(name: "City Center"),
                content: .activity(ActivityInfo(name: "Walk", type: .sightseeing, venue: nil, address: "", duration: 2 * 60 * 60, ticketRequired: false, ticketInfo: nil, guideInfo: nil, difficulty: .easy)),
                cost: Money(amount: 100.0),
                status: .planned
            )
        }
    }
}

// MARK: - Supporting Types

/// Voice session
public struct VoiceSession: Codable {
    public let id: String
    public let tripId: String?
    public let startedAt: Date
    public let language: String
    public let status: SessionStatus
    
    public enum SessionStatus: String, Codable {
        case active
        case paused
        case ended
    }
}

/// Voice response
public struct VoiceResponse: Codable {
    public let sessionId: String
    public let understood: Bool
    public let action: String?
    public let parameters: [String: String]?
    public let response: String
    public let requiresConfirmation: Bool
}

/// Planning stage cases
extension PlanningStage: CaseIterable {
    public static var allCases: [PlanningStage] = [
        .initializing,
        .searching_flights,
        .searching_hotels,
        .finding_activities,
        .optimizing,
        .validating,
        .finalizing
    ]
}

/// Trips error enum
public enum TripsError: LocalizedError {
    case tripNotFound
    case itineraryNotFound
    case bookingNotFound
    case planningJobNotFound
    case invalidInput
    case networkError
    case unauthorized
    
    public var errorDescription: String? {
        switch self {
        case .tripNotFound:
            return "Trip not found"
        case .itineraryNotFound:
            return "Itinerary not found"
        case .bookingNotFound:
            return "Booking not found"
        case .planningJobNotFound:
            return "Planning job not found"
        case .invalidInput:
            return "Invalid input provided"
        case .networkError:
            return "Network error occurred"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}