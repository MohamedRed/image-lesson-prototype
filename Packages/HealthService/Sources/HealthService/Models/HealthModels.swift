import Foundation
import HealthKit

// MARK: - Core Health Models

/// User health profile with demographics, consents, goals, and preferences
public struct HealthProfile: Codable, Identifiable {
    public let id: String
    public let userId: String
    public var demographics: Demographics?
    public var consents: [HealthConsent]
    public var goals: [HealthGoal]
    public var measurementPreferences: MeasurementPreferences
    public var conditions: [HealthCondition]
    public var emergencyContacts: [EmergencyContact]
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        demographics: Demographics? = nil,
        consents: [HealthConsent] = [],
        goals: [HealthGoal] = [],
        measurementPreferences: MeasurementPreferences = MeasurementPreferences(),
        conditions: [HealthCondition] = [],
        emergencyContacts: [EmergencyContact] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.demographics = demographics
        self.consents = consents
        self.goals = goals
        self.measurementPreferences = measurementPreferences
        self.conditions = conditions
        self.emergencyContacts = emergencyContacts
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Minimal demographics for personalization
public struct Demographics: Codable {
    public var birthYear: Int?
    public var biologicalSex: BiologicalSex?
    public var height: Measurement<UnitLength>?
    public var bloodType: BloodType?
    
    public init(
        birthYear: Int? = nil,
        biologicalSex: BiologicalSex? = nil,
        height: Measurement<UnitLength>? = nil,
        bloodType: BloodType? = nil
    ) {
        self.birthYear = birthYear
        self.biologicalSex = biologicalSex
        self.height = height
        self.bloodType = bloodType
    }
}

public enum BiologicalSex: String, Codable, CaseIterable {
    case male
    case female
    case other
}

public enum BloodType: String, Codable, CaseIterable {
    case aPositive = "A+"
    case aNegative = "A-"
    case bPositive = "B+"
    case bNegative = "B-"
    case abPositive = "AB+"
    case abNegative = "AB-"
    case oPositive = "O+"
    case oNegative = "O-"
}

/// Health consent tracking for data access and sharing
public struct HealthConsent: Codable, Identifiable {
    public let id: String
    public let type: ConsentType
    public let granted: Bool
    public let grantedAt: Date
    public let expiresAt: Date?
    
    public enum ConsentType: String, Codable {
        case healthKitRead
        case healthKitWrite
        case dataSharing
        case leaderboards
        case newsPersonalization
        case professionalAccess
        case aiInsights
    }
    
    public init(
        id: String = UUID().uuidString,
        type: ConsentType,
        granted: Bool,
        grantedAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.granted = granted
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
    }
}

/// Health goal definition
public struct HealthGoal: Codable, Identifiable {
    public let id: String
    public let type: GoalType
    public let title: String
    public let description: String
    public var target: TargetValue
    public var currentValue: Double?
    public let startDate: Date
    public let endDate: Date
    public var status: GoalStatus
    
    public enum GoalType: String, Codable, CaseIterable {
        case weightLoss
        case weightGain
        case muscleGain
        case endurance
        case strength
        case flexibility
        case nutrition
        case sleep
        case stress
        case custom
    }
    
    public enum GoalStatus: String, Codable {
        case active
        case paused
        case completed
        case abandoned
    }
    
    public struct TargetValue: Codable {
        public let value: Double
        public let unit: String
        public let comparisonType: ComparisonType
        
        public enum ComparisonType: String, Codable {
            case greaterThan
            case lessThan
            case equalTo
        }
        
        public init(value: Double, unit: String, comparisonType: ComparisonType) {
            self.value = value
            self.unit = unit
            self.comparisonType = comparisonType
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        type: GoalType,
        title: String,
        description: String,
        target: TargetValue,
        currentValue: Double? = nil,
        startDate: Date,
        endDate: Date,
        status: GoalStatus = .active
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.target = target
        self.currentValue = currentValue
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
    }
}

/// Medical incidents (surgeries, injuries, hospitalizations)
public struct HealthIncident: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let type: IncidentType
    public let title: String
    public let description: String
    public let date: Date
    public let notes: String?
    public let attachments: [String] // Storage URLs
    public let severity: Severity
    
    public enum IncidentType: String, Codable, CaseIterable {
        case surgery
        case injury
        case hospitalization
        case diagnosis
        case allergy
        case other
    }
    
    public enum Severity: String, Codable, CaseIterable {
        case minor
        case moderate
        case severe
        case critical
    }
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        type: IncidentType,
        title: String,
        description: String,
        date: Date,
        notes: String? = nil,
        attachments: [String] = [],
        severity: Severity
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.description = description
        self.date = date
        self.notes = notes
        self.attachments = attachments
        self.severity = severity
    }
}

/// Medication tracking
public struct Medication: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let name: String
    public let dosage: String
    public let frequency: MedicationFrequency
    public let schedule: [Date]
    public var adherenceLogs: [AdherenceLog]
    public let startDate: Date
    public let endDate: Date?
    public let prescribedBy: String?
    public let notes: String?
    public var isActive: Bool
    
    public struct MedicationFrequency: Codable {
        public let timesPerDay: Int
        public let specificTimes: [String]? // e.g., ["08:00", "20:00"]
        
        public init(timesPerDay: Int, specificTimes: [String]? = nil) {
            self.timesPerDay = timesPerDay
            self.specificTimes = specificTimes
        }
    }
    
    public struct AdherenceLog: Codable {
        public let date: Date
        public let taken: Bool
        public let notes: String?
        
        public init(date: Date, taken: Bool, notes: String? = nil) {
            self.date = date
            self.taken = taken
            self.notes = notes
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        dosage: String,
        frequency: MedicationFrequency,
        schedule: [Date],
        adherenceLogs: [AdherenceLog] = [],
        startDate: Date,
        endDate: Date? = nil,
        prescribedBy: String? = nil,
        notes: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.schedule = schedule
        self.adherenceLogs = adherenceLogs
        self.startDate = startDate
        self.endDate = endDate
        self.prescribedBy = prescribedBy
        self.notes = notes
        self.isActive = isActive
    }
}

/// Health observations (vitals, measurements, activities)
public struct HealthObservation: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let type: ObservationType
    public let value: ObservationValue
    public let date: Date
    public let source: DataSource
    public let metadata: [String: String]
    
    public enum ObservationType: String, Codable, CaseIterable {
        case heartRate
        case bloodPressure
        case bloodOxygen
        case bodyTemperature
        case respiratoryRate
        case weight
        case height
        case bodyFat
        case steps
        case distance
        case activeCalories
        case restingCalories
        case workout
        case sleep
        case bloodGlucose
        case hydration
        case stress
        case mood
    }
    
    public enum ObservationValue: Codable {
        case numeric(Double, String) // value, unit
        case range(Double, Double, String) // min, max, unit
        case duration(TimeInterval)
        case boolean(Bool)
        case text(String)
        
        public var displayValue: String {
            switch self {
            case .numeric(let value, let unit):
                return "\(value) \(unit)"
            case .range(let min, let max, let unit):
                return "\(min)-\(max) \(unit)"
            case .duration(let interval):
                return formatDuration(interval)
            case .boolean(let value):
                return value ? "Yes" : "No"
            case .text(let text):
                return text
            }
        }
        
        private func formatDuration(_ interval: TimeInterval) -> String {
            let hours = Int(interval) / 3600
            let minutes = (Int(interval) % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
    
    public enum DataSource: String, Codable {
        case healthKit
        case manual
        case wearable
        case `import`
    }
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        type: ObservationType,
        value: ObservationValue,
        date: Date = Date(),
        source: DataSource,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.value = value
        self.date = date
        self.source = source
        self.metadata = metadata
    }
}

/// Health condition tracking
public struct HealthCondition: Codable, Identifiable {
    public let id: String
    public let name: String
    public let icdCode: String? // ICD-10 code if available
    public let diagnosedDate: Date?
    public let status: ConditionStatus
    public let notes: String?
    
    public enum ConditionStatus: String, Codable {
        case active
        case resolved
        case managed
        case monitoring
    }
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        icdCode: String? = nil,
        diagnosedDate: Date? = nil,
        status: ConditionStatus = .active,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icdCode = icdCode
        self.diagnosedDate = diagnosedDate
        self.status = status
        self.notes = notes
    }
}

/// Measurement preferences
public struct MeasurementPreferences: Codable {
    public var weightUnit: WeightUnit
    public var heightUnit: HeightUnit
    public var distanceUnit: DistanceUnit
    public var temperatureUnit: TemperatureUnit
    public var bloodGlucoseUnit: BloodGlucoseUnit
    
    public enum WeightUnit: String, Codable, CaseIterable {
        case kilograms = "kg"
        case pounds = "lbs"
    }
    
    public enum HeightUnit: String, Codable, CaseIterable {
        case centimeters = "cm"
        case feet = "ft"
    }
    
    public enum DistanceUnit: String, Codable, CaseIterable {
        case kilometers = "km"
        case miles = "mi"
    }
    
    public enum TemperatureUnit: String, Codable, CaseIterable {
        case celsius = "°C"
        case fahrenheit = "°F"
    }
    
    public enum BloodGlucoseUnit: String, Codable, CaseIterable {
        case mgdL = "mg/dL"
        case mmolL = "mmol/L"
    }
    
    public init(
        weightUnit: WeightUnit = .kilograms,
        heightUnit: HeightUnit = .centimeters,
        distanceUnit: DistanceUnit = .kilometers,
        temperatureUnit: TemperatureUnit = .celsius,
        bloodGlucoseUnit: BloodGlucoseUnit = .mgdL
    ) {
        self.weightUnit = weightUnit
        self.heightUnit = heightUnit
        self.distanceUnit = distanceUnit
        self.temperatureUnit = temperatureUnit
        self.bloodGlucoseUnit = bloodGlucoseUnit
    }
}

/// Emergency contact information
public struct EmergencyContact: Codable, Identifiable {
    public let id: String
    public let name: String
    public let relationship: String
    public let phoneNumber: String
    public let email: String?
    public let isPrimary: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        relationship: String,
        phoneNumber: String,
        email: String? = nil,
        isPrimary: Bool = false
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.phoneNumber = phoneNumber
        self.email = email
        self.isPrimary = isPrimary
    }
}