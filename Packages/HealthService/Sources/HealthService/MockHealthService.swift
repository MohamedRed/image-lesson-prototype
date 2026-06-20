import Foundation
import Combine

/// Mock implementation of HealthService for development and testing
public class MockHealthService: ObservableObject {
    public static let shared = MockHealthService()
    
    // MARK: - Mock Data Storage
    
    private var healthProfiles: [String: HealthProfile] = [:]
    private var observations: [HealthObservation] = []
    private var programs: [HealthProgram] = []
    private var insights: [HealthInsight] = []
    private var challenges: [HealthChallenge] = []
    private var professionals: [HealthProfessional] = []
    private var appointments: [HealthAppointment] = []
    private var medications: [Medication] = []
    private var incidents: [HealthIncident] = []
    private var newsItems: [HealthNewsItem] = []
    private var leaderboardEntries: [LeaderboardEntry] = []
    
    // MARK: - Publishers
    
    @Published public var currentHealthScore: Int = 75
    @Published public var activePrograms: [HealthProgram] = []
    @Published public var unreadInsights: Int = 3
    
    public init() {
        setupMockData()
    }
    
    // MARK: - Setup Mock Data
    
    private func setupMockData() {
        // Create mock user health profile
        let mockProfile = HealthProfile(
            userId: "mock-user",
            demographics: HealthProfile.Demographics(
                age: 32,
                biologicalSex: "male",
                height: 180,
                weight: 75
            ),
            goals: [
                HealthProfile.Goal(
                    id: "goal1",
                    type: .fitness,
                    target: "Lose 5kg",
                    deadline: Date().addingTimeInterval(90 * 24 * 60 * 60),
                    progress: 0.3,
                    isActive: true
                ),
                HealthProfile.Goal(
                    id: "goal2",
                    type: .wellness,
                    target: "Improve sleep quality",
                    deadline: Date().addingTimeInterval(30 * 24 * 60 * 60),
                    progress: 0.6,
                    isActive: true
                )
            ],
            conditions: ["Mild Hypertension"],
            allergies: ["Peanuts", "Dust"],
            preferences: HealthProfile.Preferences(
                notificationsEnabled: true,
                dataSharing: .anonymized,
                units: .metric,
                language: "en"
            )
        )
        healthProfiles["mock-user"] = mockProfile
        
        // Create mock observations
        observations = generateMockObservations()
        
        // Create mock programs
        programs = [
            HealthProgram(
                id: "program1",
                name: "30-Day Fitness Challenge",
                description: "Build strength and improve cardiovascular health with daily workouts",
                category: .fitness,
                difficulty: .intermediate,
                durationDays: 30,
                steps: [
                    HealthProgram.ProgramStep(
                        id: "step1",
                        day: 1,
                        type: .exercise,
                        title: "Morning Cardio",
                        description: "30 minutes of moderate cardio",
                        duration: 30,
                        targetMetrics: ["heartRate": 130, "calories": 250],
                        completed: true,
                        completedAt: Date().addingTimeInterval(-24 * 60 * 60)
                    ),
                    HealthProgram.ProgramStep(
                        id: "step2",
                        day: 2,
                        type: .exercise,
                        title: "Strength Training",
                        description: "Upper body workout",
                        duration: 45,
                        targetMetrics: ["sets": 3, "reps": 12],
                        completed: false,
                        completedAt: nil
                    )
                ],
                status: .active,
                startDate: Date().addingTimeInterval(-24 * 60 * 60),
                progress: 0.1,
                outcomes: []
            ),
            HealthProgram(
                id: "program2",
                name: "Better Sleep Program",
                description: "Improve your sleep quality with science-backed techniques",
                category: .wellness,
                difficulty: .beginner,
                durationDays: 14,
                steps: [
                    HealthProgram.ProgramStep(
                        id: "step3",
                        day: 1,
                        type: .education,
                        title: "Understanding Sleep Cycles",
                        description: "Learn about REM and deep sleep",
                        duration: 15,
                        targetMetrics: [:],
                        completed: true,
                        completedAt: Date().addingTimeInterval(-12 * 60 * 60)
                    )
                ],
                status: .active,
                startDate: Date().addingTimeInterval(-12 * 60 * 60),
                progress: 0.07,
                outcomes: []
            )
        ]
        activePrograms = programs.filter { $0.status == .active }
        
        // Create mock insights
        insights = [
            HealthInsight(
                id: "insight1",
                category: .activity,
                type: .recommendation,
                priority: .high,
                title: "Low Activity Alert",
                message: "Your step count has been below 5,000 for the past 3 days. Try taking a short walk after lunch!",
                triggerData: ["avgSteps": 3500],
                evidenceLinks: [
                    "https://health.gov/physical-activity-guidelines"
                ],
                actionItems: [
                    "Take a 10-minute walk",
                    "Use stairs instead of elevator",
                    "Park farther from entrances"
                ],
                createdAt: Date().addingTimeInterval(-2 * 60 * 60),
                expiresAt: Date().addingTimeInterval(24 * 60 * 60),
                isRead: false,
                isDismissed: false
            ),
            HealthInsight(
                id: "insight2",
                category: .sleep,
                type: .trend,
                priority: .medium,
                title: "Sleep Pattern Improving",
                message: "Your average sleep duration increased by 45 minutes this week. Keep up the good habits!",
                triggerData: ["avgSleep": 7.5, "improvement": 0.75],
                evidenceLinks: [],
                actionItems: [
                    "Maintain consistent bedtime",
                    "Continue limiting screen time before bed"
                ],
                createdAt: Date().addingTimeInterval(-12 * 60 * 60),
                expiresAt: nil,
                isRead: false,
                isDismissed: false
            ),
            HealthInsight(
                id: "insight3",
                category: .nutrition,
                type: .alert,
                priority: .low,
                title: "Hydration Reminder",
                message: "Remember to drink water regularly throughout the day.",
                triggerData: ["waterIntake": 1.2],
                evidenceLinks: [],
                actionItems: [
                    "Drink 8 glasses of water daily",
                    "Keep a water bottle at your desk"
                ],
                createdAt: Date().addingTimeInterval(-6 * 60 * 60),
                expiresAt: Date().addingTimeInterval(6 * 60 * 60),
                isRead: true,
                isDismissed: false
            )
        ]
        
        // Create mock challenges
        challenges = [
            HealthChallenge(
                id: "challenge1",
                name: "10K Steps Daily",
                description: "Walk 10,000 steps every day for a week",
                type: .individual,
                category: .activity,
                startDate: Date(),
                endDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
                rules: [
                    "Walk at least 10,000 steps each day",
                    "Track your steps using the app",
                    "Complete all 7 days to win"
                ],
                rewards: ["50 points", "Achievement badge"],
                participants: 156,
                status: .active,
                userProgress: HealthChallenge.UserProgress(
                    joined: true,
                    currentScore: 2,
                    targetScore: 7,
                    rank: 23,
                    completedDays: [Date().addingTimeInterval(-24 * 60 * 60), Date().addingTimeInterval(-48 * 60 * 60)]
                )
            ),
            HealthChallenge(
                id: "challenge2",
                name: "Mindfulness March",
                description: "Practice daily meditation and mindfulness",
                type: .team,
                category: .wellness,
                startDate: Date().addingTimeInterval(-5 * 24 * 60 * 60),
                endDate: Date().addingTimeInterval(25 * 24 * 60 * 60),
                rules: [
                    "Meditate for at least 10 minutes daily",
                    "Log your sessions in the app",
                    "Team average counts for scoring"
                ],
                rewards: ["100 points", "Premium meditation content"],
                participants: 89,
                status: .active,
                userProgress: nil
            )
        ]
        
        // Create mock professionals
        professionals = [
            HealthProfessional(
                id: "pro1",
                name: "Dr. Sarah Johnson",
                title: "Certified Nutritionist",
                type: .dietician,
                specialties: ["Weight Management", "Sports Nutrition", "Diabetes"],
                qualifications: [
                    "PhD in Nutrition Science",
                    "Registered Dietitian (RD)",
                    "Certified Diabetes Educator"
                ],
                experienceYears: 12,
                rating: 4.8,
                reviewCount: 234,
                location: "New York, NY",
                languages: ["English", "Spanish"],
                availability: HealthProfessional.Availability(
                    nextAvailable: Date().addingTimeInterval(2 * 24 * 60 * 60),
                    consultationTypes: [.inPerson, .video],
                    timeSlots: []
                ),
                pricing: HealthProfessional.Pricing(
                    consultationFee: 150,
                    currency: "USD",
                    duration: 60,
                    insuranceAccepted: ["Blue Cross", "Aetna", "United Healthcare"]
                ),
                telehealthEnabled: true,
                profileImageUrl: "https://example.com/dr-johnson.jpg",
                bio: "Dr. Johnson specializes in personalized nutrition plans that fit your lifestyle.",
                isVerified: true
            ),
            HealthProfessional(
                id: "pro2",
                name: "Mike Chen",
                title: "Personal Trainer & Wellness Coach",
                type: .coach,
                specialties: ["HIIT", "Strength Training", "Injury Recovery"],
                qualifications: [
                    "NASM Certified Personal Trainer",
                    "Corrective Exercise Specialist",
                    "Performance Enhancement Specialist"
                ],
                experienceYears: 8,
                rating: 4.9,
                reviewCount: 189,
                location: "Los Angeles, CA",
                languages: ["English", "Mandarin"],
                availability: HealthProfessional.Availability(
                    nextAvailable: Date().addingTimeInterval(24 * 60 * 60),
                    consultationTypes: [.video],
                    timeSlots: []
                ),
                pricing: HealthProfessional.Pricing(
                    consultationFee: 100,
                    currency: "USD",
                    duration: 45,
                    insuranceAccepted: []
                ),
                telehealthEnabled: true,
                profileImageUrl: "https://example.com/mike-chen.jpg",
                bio: "Transform your fitness journey with personalized training programs.",
                isVerified: true
            )
        ]
        
        // Create mock appointments
        appointments = [
            HealthAppointment(
                id: "apt1",
                professionalId: "pro1",
                professionalName: "Dr. Sarah Johnson",
                userId: "mock-user",
                type: .consultation,
                scheduledFor: Date().addingTimeInterval(3 * 24 * 60 * 60),
                duration: 60,
                status: .confirmed,
                location: .video,
                meetingLink: "https://meet.example.com/health-apt1",
                notes: "Initial nutrition consultation",
                remindersSent: [],
                createdAt: Date().addingTimeInterval(-24 * 60 * 60)
            )
        ]
        
        // Create mock medications
        medications = [
            Medication(
                id: "med1",
                name: "Metformin",
                dosage: "500mg",
                frequency: "Twice daily",
                schedule: ["08:00", "20:00"],
                startDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                endDate: nil,
                purpose: "Blood sugar management",
                prescribedBy: "Dr. Smith",
                remindersEnabled: true,
                adherenceLogs: [
                    Medication.AdherenceLog(
                        date: Date(),
                        taken: true,
                        time: "08:00",
                        notes: nil
                    ),
                    Medication.AdherenceLog(
                        date: Date().addingTimeInterval(-24 * 60 * 60),
                        taken: true,
                        time: "08:00",
                        notes: nil
                    ),
                    Medication.AdherenceLog(
                        date: Date().addingTimeInterval(-24 * 60 * 60),
                        taken: false,
                        time: "20:00",
                        notes: "Forgot evening dose"
                    )
                ],
                sideEffects: ["Nausea", "Dizziness"],
                interactions: [],
                refillDate: Date().addingTimeInterval(15 * 24 * 60 * 60),
                isActive: true
            ),
            Medication(
                id: "med2",
                name: "Vitamin D3",
                dosage: "2000 IU",
                frequency: "Once daily",
                schedule: ["09:00"],
                startDate: Date().addingTimeInterval(-60 * 24 * 60 * 60),
                endDate: nil,
                purpose: "Vitamin D supplementation",
                prescribedBy: "Self",
                remindersEnabled: false,
                adherenceLogs: [],
                sideEffects: [],
                interactions: [],
                refillDate: nil,
                isActive: true
            )
        ]
        
        // Create mock incidents
        incidents = [
            HealthIncident(
                id: "inc1",
                type: .injury,
                title: "Ankle Sprain",
                date: Date().addingTimeInterval(-14 * 24 * 60 * 60),
                description: "Twisted ankle while jogging in the park",
                severity: .moderate,
                treatment: "RICE protocol, physical therapy",
                provider: "City Medical Center",
                followUpRequired: true,
                followUpDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
                documents: [],
                notes: "Recovering well, continue PT exercises"
            )
        ]
        
        // Create mock news items
        newsItems = [
            HealthNewsItem(
                id: "news1",
                title: "New Study: Mediterranean Diet Reduces Heart Disease Risk by 30%",
                summary: "Research from Harvard Medical School shows significant cardiovascular benefits",
                category: .research,
                source: "Harvard Medical School",
                publishedAt: Date().addingTimeInterval(-6 * 60 * 60),
                url: "https://example.com/news/mediterranean-diet",
                imageUrl: "https://example.com/images/med-diet.jpg",
                tags: ["nutrition", "heart-health", "research"],
                credibilityScore: 0.95,
                relevanceScore: 0.8,
                personalizedFor: ["heart-health"],
                readTime: 5
            ),
            HealthNewsItem(
                id: "news2",
                title: "5 Simple Exercises to Improve Posture While Working from Home",
                summary: "Physical therapists recommend these desk-friendly stretches",
                category: .tips,
                source: "WebMD",
                publishedAt: Date().addingTimeInterval(-12 * 60 * 60),
                url: "https://example.com/news/posture-exercises",
                imageUrl: "https://example.com/images/posture.jpg",
                tags: ["exercise", "workplace", "wellness"],
                credibilityScore: 0.85,
                relevanceScore: 0.9,
                personalizedFor: ["fitness"],
                readTime: 3
            ),
            HealthNewsItem(
                id: "news3",
                title: "FDA Approves New Treatment for Chronic Migraines",
                summary: "Breakthrough therapy shows promise for patients with frequent migraines",
                category: .news,
                source: "FDA News",
                publishedAt: Date().addingTimeInterval(-24 * 60 * 60),
                url: "https://example.com/news/migraine-treatment",
                imageUrl: "https://example.com/images/medical.jpg",
                tags: ["medical", "treatment", "FDA"],
                credibilityScore: 1.0,
                relevanceScore: 0.6,
                personalizedFor: [],
                readTime: 7
            )
        ]
        
        // Create mock leaderboard entries
        leaderboardEntries = generateMockLeaderboard()
    }
    
    private func generateMockObservations() -> [HealthObservation] {
        var observations: [HealthObservation] = []
        let now = Date()
        
        // Generate step count data for the past 7 days
        for i in 0..<7 {
            let date = now.addingTimeInterval(Double(-i) * 24 * 60 * 60)
            let steps = Double.random(in: 3000...12000)
            
            observations.append(HealthObservation(
                id: "obs-steps-\(i)",
                userId: "mock-user",
                type: .steps,
                value: .numeric(steps, "steps"),
                date: date,
                source: .healthKit,
                metadata: ["device": "iPhone"]
            ))
        }
        
        // Generate heart rate data
        for i in 0..<14 {
            let date = now.addingTimeInterval(Double(-i) * 12 * 60 * 60)
            let heartRate = Double.random(in: 60...85)
            
            observations.append(HealthObservation(
                id: "obs-hr-\(i)",
                userId: "mock-user",
                type: .heartRate,
                value: .numeric(heartRate, "bpm"),
                date: date,
                source: .healthKit,
                metadata: ["context": "resting"]
            ))
        }
        
        // Generate sleep data
        for i in 0..<7 {
            let date = now.addingTimeInterval(Double(-i) * 24 * 60 * 60)
            let sleepHours = Double.random(in: 5.5...9.0)
            
            observations.append(HealthObservation(
                id: "obs-sleep-\(i)",
                userId: "mock-user",
                type: .sleep,
                value: .duration(sleepHours * 3600),
                date: date,
                source: .manual,
                metadata: ["quality": sleepHours > 7 ? "good" : "fair"]
            ))
        }
        
        // Generate weight data
        for i in 0..<4 {
            let date = now.addingTimeInterval(Double(-i) * 7 * 24 * 60 * 60)
            let weight = 75.0 + Double.random(in: -2...2)
            
            observations.append(HealthObservation(
                id: "obs-weight-\(i)",
                userId: "mock-user",
                type: .weight,
                value: .numeric(weight, "kg"),
                date: date,
                source: .manual,
                metadata: [:]
            ))
        }
        
        // Add blood pressure data
        observations.append(HealthObservation(
            id: "obs-bp-1",
            userId: "mock-user",
            type: .bloodPressure,
            value: .range(110, 125, "mmHg"),
            date: now.addingTimeInterval(-2 * 24 * 60 * 60),
            source: .manual,
            metadata: ["systolic": "125", "diastolic": "80"]
        ))
        
        // Add mood data
        for i in 0..<3 {
            let date = now.addingTimeInterval(Double(-i) * 24 * 60 * 60)
            let moods = ["happy", "neutral", "stressed", "energetic"]
            
            observations.append(HealthObservation(
                id: "obs-mood-\(i)",
                userId: "mock-user",
                type: .mood,
                value: .text(moods.randomElement()!),
                date: date,
                source: .manual,
                metadata: ["notes": "Feeling good after workout"]
            ))
        }
        
        return observations.sorted { $0.date > $1.date }
    }
    
    private func generateMockLeaderboard() -> [LeaderboardEntry] {
        var entries: [LeaderboardEntry] = []
        let userNames = ["FitRunner23", "HealthyLife", "ActiveMom", "GymPro", "WellnessGuru", 
                        "CardioKing", "YogaMaster", "StepChamp", "FitnessFan", "HealthNut"]
        
        // Add current user
        entries.append(LeaderboardEntry(
            id: "lead-me",
            userId: "mock-user",
            username: "You",
            bucket: LeaderboardBucket(
                geoLevel: .city,
                ageBracket: .age30_39,
                category: .overall
            ),
            rank: 23,
            score: 850,
            percentile: 77,
            healthScore: 75,
            metrics: LeaderboardEntry.Metrics(
                steps: 8500,
                activeMinutes: 45,
                sleepScore: 82,
                consistencyDays: 12
            ),
            trend: .up,
            isCurrentUser: true,
            anonymizedId: "user_23"
        ))
        
        // Add other users
        for i in 0..<10 {
            let rank = i + 1
            let score = 1000 - (i * 50) + Int.random(in: -20...20)
            
            entries.append(LeaderboardEntry(
                id: "lead-\(i)",
                userId: "user-\(i)",
                username: userNames[i],
                bucket: LeaderboardBucket(
                    geoLevel: .city,
                    ageBracket: .age30_39,
                    category: .overall
                ),
                rank: rank,
                score: score,
                percentile: 100 - (rank * 10),
                healthScore: 90 - (i * 3),
                metrics: LeaderboardEntry.Metrics(
                    steps: 12000 - (i * 500),
                    activeMinutes: 60 - (i * 3),
                    sleepScore: 90 - (i * 2),
                    consistencyDays: 20 - i
                ),
                trend: [.up, .down, .stable].randomElement()!,
                isCurrentUser: false,
                anonymizedId: "user_\(rank)"
            ))
        }
        
        return entries.sorted { $0.rank < $1.rank }
    }
    
    // MARK: - Overview & Profile
    
    public func getHealthOverview() -> AnyPublisher<HealthOverviewResponse, Error> {
        Just(HealthOverviewResponse(
            profile: healthProfiles["mock-user"]!,
            todaySummary: HealthOverviewResponse.TodaySummary(
                date: Date(),
                healthScore: currentHealthScore,
                steps: 6543,
                activeMinutes: 28,
                calories: 1850,
                sleepHours: 7.2,
                waterIntake: 1.5,
                mood: "energetic",
                completedActivities: 2,
                medicationAdherence: 0.75
            ),
            activePrograms: activePrograms.prefix(2).map { program in
                HealthOverviewResponse.ActiveProgramSummary(
                    programId: program.id,
                    programName: program.name,
                    currentStep: program.steps.first { !$0.completed }?.title ?? "Completed",
                    progress: program.progress,
                    nextDeadline: Date().addingTimeInterval(24 * 60 * 60)
                )
            },
            insights: insights.filter { !$0.isRead }.prefix(3).map { $0 },
            upcomingAppointments: appointments.filter { $0.status == .confirmed }.prefix(2).map { $0 }
        ))
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }
    
    public func updateHealthProfile(_ profile: HealthProfile) -> AnyPublisher<HealthProfile, Error> {
        healthProfiles[profile.userId] = profile
        return Just(profile)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func updateConsent(_ consent: HealthConsent) -> AnyPublisher<HealthConsent, Error> {
        Just(consent)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(100), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Observations
    
    public func getObservations(
        type: HealthObservation.ObservationType? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        pageToken: String? = nil
    ) -> AnyPublisher<ObservationsResponse, Error> {
        var filtered = observations
        
        if let type = type {
            filtered = filtered.filter { $0.type == type }
        }
        
        if let startDate = startDate {
            filtered = filtered.filter { $0.date >= startDate }
        }
        
        if let endDate = endDate {
            filtered = filtered.filter { $0.date <= endDate }
        }
        
        let pageSize = 20
        let startIndex = pageToken.flatMap { Int($0) } ?? 0
        let endIndex = min(startIndex + pageSize, filtered.count)
        let pageObservations = Array(filtered[startIndex..<endIndex])
        let nextPageToken = endIndex < filtered.count ? "\(endIndex)" : nil
        
        return Just(ObservationsResponse(
            observations: pageObservations,
            pageToken: nextPageToken,
            hasMore: nextPageToken != nil
        ))
        .setFailureType(to: Error.self)
        .delay(for: .milliseconds(300), scheduler: RunLoop.main)
        .eraseToAnyPublisher()
    }
    
    public func saveObservation(_ observation: HealthObservation) -> AnyPublisher<HealthObservation, Error> {
        var newObservation = observation
        newObservation.id = "obs-\(UUID().uuidString.prefix(8))"
        observations.insert(newObservation, at: 0)
        
        return Just(newObservation)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func importHealthKitData(_ importRequest: HealthKitImportRequest) -> AnyPublisher<ImportResult, Error> {
        // Simulate processing the import
        let processedCount = importRequest.observations.count
        let skippedCount = Int.random(in: 0...2)
        
        // Add observations to our mock data
        for obs in importRequest.observations {
            observations.insert(obs, at: 0)
        }
        
        return Just(ImportResult(
            processedCount: processedCount,
            skippedCount: skippedCount,
            errorCount: 0,
            warnings: skippedCount > 0 ? ["Some duplicate observations were skipped"] : nil
        ))
        .setFailureType(to: Error.self)
        .delay(for: .milliseconds(500), scheduler: RunLoop.main)
        .eraseToAnyPublisher()
    }
    
    // MARK: - Programs
    
    public func createProgram(_ payload: CreateProgramRequest) -> AnyPublisher<CreateProgramResponse, Error> {
        let newProgram = HealthProgram(
            id: "program-\(UUID().uuidString.prefix(8))",
            name: "Custom \(payload.goal.capitalized) Program",
            description: "AI-generated program based on your goals and constraints",
            category: mapGoalToCategory(payload.goal),
            difficulty: .intermediate,
            durationDays: 21,
            steps: generateProgramSteps(for: payload.goal),
            status: .draft,
            startDate: nil,
            progress: 0,
            outcomes: []
        )
        
        programs.append(newProgram)
        
        return Just(CreateProgramResponse(
            program: newProgram,
            alternatives: []
        ))
        .setFailureType(to: Error.self)
        .delay(for: .milliseconds(800), scheduler: RunLoop.main)
        .eraseToAnyPublisher()
    }
    
    public func getPrograms() -> AnyPublisher<[HealthProgram], Error> {
        Just(programs)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func getProgram(_ id: String) -> AnyPublisher<HealthProgram, Error> {
        if let program = programs.first(where: { $0.id == id }) {
            return Just(program)
                .setFailureType(to: Error.self)
                .delay(for: .milliseconds(100), scheduler: RunLoop.main)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: HealthServiceError.httpError(404))
                .eraseToAnyPublisher()
        }
    }
    
    public func updateProgramProgress(_ programId: String, _ payload: ProgressUpdateRequest) -> AnyPublisher<HealthProgram, Error> {
        guard let index = programs.firstIndex(where: { $0.id == programId }) else {
            return Fail(error: HealthServiceError.httpError(404))
                .eraseToAnyPublisher()
        }
        
        var program = programs[index]
        
        // Update step completion
        if let stepIndex = program.steps.firstIndex(where: { $0.id == payload.stepId }) {
            program.steps[stepIndex].completed = payload.completed
            program.steps[stepIndex].completedAt = payload.completed ? Date() : nil
            
            if let feedback = payload.feedback {
                program.steps[stepIndex].userFeedback = feedback
            }
        }
        
        // Update program progress
        let completedSteps = program.steps.filter { $0.completed }.count
        program.progress = Double(completedSteps) / Double(program.steps.count)
        
        // Update program status if needed
        if program.progress >= 1.0 {
            program.status = .completed
        }
        
        programs[index] = program
        
        if program.status == .active {
            activePrograms = programs.filter { $0.status == .active }
        }
        
        return Just(program)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func pauseProgram(_ id: String) -> AnyPublisher<HealthProgram, Error> {
        guard let index = programs.firstIndex(where: { $0.id == id }) else {
            return Fail(error: HealthServiceError.httpError(404))
                .eraseToAnyPublisher()
        }
        
        programs[index].status = .paused
        activePrograms = programs.filter { $0.status == .active }
        
        return Just(programs[index])
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(100), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func resumeProgram(_ id: String) -> AnyPublisher<HealthProgram, Error> {
        guard let index = programs.firstIndex(where: { $0.id == id }) else {
            return Fail(error: HealthServiceError.httpError(404))
                .eraseToAnyPublisher()
        }
        
        programs[index].status = .active
        activePrograms = programs.filter { $0.status == .active }
        
        return Just(programs[index])
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(100), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Insights
    
    public func getInsights(category: HealthInsight.InsightCategory? = nil) -> AnyPublisher<[HealthInsight], Error> {
        var filtered = insights
        
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }
        
        return Just(filtered)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func markInsightRead(_ id: String) -> AnyPublisher<Void, Error> {
        if let index = insights.firstIndex(where: { $0.id == id }) {
            insights[index].isRead = true
            unreadInsights = insights.filter { !$0.isRead }.count
        }
        
        return Just(())
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(100), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func dismissInsight(_ id: String) -> AnyPublisher<Void, Error> {
        if let index = insights.firstIndex(where: { $0.id == id }) {
            insights[index].isDismissed = true
        }
        
        return Just(())
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(100), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Leaderboards
    
    public func getLeaderboard(
        bucket: LeaderboardBucket.GeoLevel = .city,
        category: LeaderboardBucket.CompetitionCategory = .overall
    ) -> AnyPublisher<LeaderboardResponse, Error> {
        let filtered = leaderboardEntries.filter { entry in
            entry.bucket.geoLevel == bucket && entry.bucket.category == category
        }
        
        return Just(LeaderboardResponse(
            bucket: LeaderboardBucket(
                geoLevel: bucket,
                ageBracket: .age30_39,
                category: category
            ),
            entries: filtered,
            userEntry: filtered.first { $0.isCurrentUser },
            lastUpdated: Date(),
            nextUpdate: Date().addingTimeInterval(60 * 60)
        ))
        .setFailureType(to: Error.self)
        .delay(for: .milliseconds(300), scheduler: RunLoop.main)
        .eraseToAnyPublisher()
    }
    
    public func getChallenges() -> AnyPublisher<[HealthChallenge], Error> {
        Just(challenges)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func joinChallenge(_ id: String) -> AnyPublisher<HealthChallenge, Error> {
        guard let index = challenges.firstIndex(where: { $0.id == id }) else {
            return Fail(error: HealthServiceError.httpError(404))
                .eraseToAnyPublisher()
        }
        
        challenges[index].userProgress = HealthChallenge.UserProgress(
            joined: true,
            currentScore: 0,
            targetScore: 7,
            rank: challenges[index].participants + 1,
            completedDays: []
        )
        challenges[index].participants += 1
        
        return Just(challenges[index])
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - News
    
    public func getHealthNews(pageToken: String? = nil) -> AnyPublisher<NewsResponse, Error> {
        let pageSize = 10
        let startIndex = pageToken.flatMap { Int($0) } ?? 0
        let endIndex = min(startIndex + pageSize, newsItems.count)
        let pageNews = Array(newsItems[startIndex..<endIndex])
        let nextPageToken = endIndex < newsItems.count ? "\(endIndex)" : nil
        
        return Just(NewsResponse(
            articles: pageNews,
            pageToken: nextPageToken,
            hasMore: nextPageToken != nil
        ))
        .setFailureType(to: Error.self)
        .delay(for: .milliseconds(200), scheduler: RunLoop.main)
        .eraseToAnyPublisher()
    }
    
    // MARK: - Professionals
    
    public func searchProfessionals(
        type: HealthProfessional.ProfessionalType? = nil,
        specialty: String? = nil,
        location: String? = nil,
        telehealthOnly: Bool = false,
        pageToken: String? = nil
    ) -> AnyPublisher<ProfessionalSearchResponse, Error> {
        var filtered = professionals
        
        if let type = type {
            filtered = filtered.filter { $0.type == type }
        }
        
        if let specialty = specialty {
            filtered = filtered.filter { pro in
                pro.specialties.contains { $0.lowercased().contains(specialty.lowercased()) }
            }
        }
        
        if telehealthOnly {
            filtered = filtered.filter { $0.telehealthEnabled }
        }
        
        return Just(ProfessionalSearchResponse(
            professionals: filtered,
            totalCount: filtered.count,
            pageToken: nil,
            hasMore: false
        ))
        .setFailureType(to: Error.self)
        .delay(for: .milliseconds(300), scheduler: RunLoop.main)
        .eraseToAnyPublisher()
    }
    
    public func getProfessional(_ id: String) -> AnyPublisher<HealthProfessional, Error> {
        if let professional = professionals.first(where: { $0.id == id }) {
            return Just(professional)
                .setFailureType(to: Error.self)
                .delay(for: .milliseconds(100), scheduler: RunLoop.main)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: HealthServiceError.httpError(404))
                .eraseToAnyPublisher()
        }
    }
    
    public func bookAppointment(_ payload: BookAppointmentRequest) -> AnyPublisher<BookAppointmentResponse, Error> {
        let newAppointment = HealthAppointment(
            id: "apt-\(UUID().uuidString.prefix(8))",
            professionalId: payload.professionalId,
            professionalName: professionals.first { $0.id == payload.professionalId }?.name ?? "Professional",
            userId: "mock-user",
            type: payload.type,
            scheduledFor: payload.scheduledFor,
            duration: payload.duration,
            status: .pending,
            location: payload.preferredLocation,
            meetingLink: payload.preferredLocation == .video ? "https://meet.example.com/health-\(UUID().uuidString.prefix(8))" : nil,
            notes: payload.notes,
            remindersSent: [],
            createdAt: Date()
        )
        
        appointments.append(newAppointment)
        
        return Just(BookAppointmentResponse(
            appointment: newAppointment,
            confirmationCode: "HLTH-\(UUID().uuidString.prefix(6).uppercased())",
            paymentRequired: false,
            amount: nil
        ))
        .setFailureType(to: Error.self)
        .delay(for: .milliseconds(400), scheduler: RunLoop.main)
        .eraseToAnyPublisher()
    }
    
    public func getAppointments() -> AnyPublisher<[HealthAppointment], Error> {
        Just(appointments)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func cancelAppointment(_ id: String) -> AnyPublisher<HealthAppointment, Error> {
        guard let index = appointments.firstIndex(where: { $0.id == id }) else {
            return Fail(error: HealthServiceError.httpError(404))
                .eraseToAnyPublisher()
        }
        
        appointments[index].status = .cancelled
        
        return Just(appointments[index])
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Voice Assistant
    
    public func interpretVoiceInput(_ payload: VoiceInterpretRequest) -> AnyPublisher<VoiceInterpretResponse, Error> {
        // Simulate AI processing
        let responses = [
            "I understand you want to track your workout. Let me help you log that activity.",
            "Based on your health data, I recommend focusing on cardiovascular exercises this week.",
            "Your sleep pattern has been improving. Keep maintaining your bedtime routine.",
            "Would you like me to schedule an appointment with a nutritionist?"
        ]
        
        return Just(VoiceInterpretResponse(
            understood: true,
            intent: "health_query",
            entities: ["topic": "workout", "action": "track"],
            response: responses.randomElement()!,
            suggestedActions: [
                "Log workout",
                "View progress",
                "Set reminder"
            ],
            requiresConfirmation: false
        ))
        .setFailureType(to: Error.self)
        .delay(for: .milliseconds(600), scheduler: RunLoop.main)
        .eraseToAnyPublisher()
    }
    
    // MARK: - Medications & Incidents
    
    public func getMedications() -> AnyPublisher<[Medication], Error> {
        Just(medications)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func saveMedication(_ medication: Medication) -> AnyPublisher<Medication, Error> {
        var newMedication = medication
        if newMedication.id.isEmpty {
            newMedication.id = "med-\(UUID().uuidString.prefix(8))"
        }
        
        if let index = medications.firstIndex(where: { $0.id == newMedication.id }) {
            medications[index] = newMedication
        } else {
            medications.append(newMedication)
        }
        
        return Just(newMedication)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func updateMedicationAdherence(_ medicationId: String, log: Medication.AdherenceLog) -> AnyPublisher<Medication, Error> {
        guard let index = medications.firstIndex(where: { $0.id == medicationId }) else {
            return Fail(error: HealthServiceError.httpError(404))
                .eraseToAnyPublisher()
        }
        
        medications[index].adherenceLogs.append(log)
        
        return Just(medications[index])
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(100), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func getIncidents() -> AnyPublisher<[HealthIncident], Error> {
        Just(incidents)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    public func saveIncident(_ incident: HealthIncident) -> AnyPublisher<HealthIncident, Error> {
        var newIncident = incident
        if newIncident.id.isEmpty {
            newIncident.id = "inc-\(UUID().uuidString.prefix(8))"
        }
        
        if let index = incidents.firstIndex(where: { $0.id == newIncident.id }) {
            incidents[index] = newIncident
        } else {
            incidents.append(newIncident)
        }
        
        return Just(newIncident)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func mapGoalToCategory(_ goal: String) -> HealthProgram.ProgramCategory {
        switch goal.lowercased() {
        case let g where g.contains("weight") || g.contains("fitness"):
            return .fitness
        case let g where g.contains("sleep") || g.contains("stress") || g.contains("wellness"):
            return .wellness
        case let g where g.contains("diet") || g.contains("nutrition"):
            return .nutrition
        case let g where g.contains("disease") || g.contains("medical"):
            return .medical
        default:
            return .wellness
        }
    }
    
    private func generateProgramSteps(for goal: String) -> [HealthProgram.ProgramStep] {
        var steps: [HealthProgram.ProgramStep] = []
        
        for day in 1...7 {
            let stepTypes: [HealthProgram.StepType] = [.exercise, .nutrition, .education, .meditation, .task]
            let stepType = stepTypes.randomElement()!
            
            steps.append(HealthProgram.ProgramStep(
                id: "step-\(day)",
                day: day,
                type: stepType,
                title: "Day \(day): \(stepType.rawValue.capitalized) Activity",
                description: "Complete this \(stepType.rawValue) to progress toward your goal",
                duration: Int.random(in: 15...45),
                targetMetrics: [:],
                completed: false,
                completedAt: nil
            ))
        }
        
        return steps
    }
}

// MARK: - Extension for Async Publisher Support

extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        _ = cancellable // Retain until completion
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                    }
                )
        }
    }
}