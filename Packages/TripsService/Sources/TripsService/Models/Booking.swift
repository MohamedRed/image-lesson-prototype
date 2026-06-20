import Foundation

// MARK: - Booking Models

/// Booking information for trip components
public struct Booking: Codable, Hashable, Identifiable {
    public let id: String
    public let tripId: String
    public let segmentId: String?
    public let type: BookingType
    public let vendor: VendorInfo
    public var status: BookingStatus
    public let price: Money
    public let currency: String
    public var policies: BookingPolicies
    public var confirmationCodes: [String]
    public var documents: [BookingDocument]
    public let bookedAt: Date
    public var modifiedAt: Date?
    public var cancellationInfo: CancellationInfo?
    
    public init(
        id: String = UUID().uuidString,
        tripId: String,
        segmentId: String? = nil,
        type: BookingType,
        vendor: VendorInfo,
        status: BookingStatus,
        price: Money,
        currency: String,
        policies: BookingPolicies,
        confirmationCodes: [String] = [],
        documents: [BookingDocument] = [],
        bookedAt: Date = Date(),
        modifiedAt: Date? = nil,
        cancellationInfo: CancellationInfo? = nil
    ) {
        self.id = id
        self.tripId = tripId
        self.segmentId = segmentId
        self.type = type
        self.vendor = vendor
        self.status = status
        self.price = price
        self.currency = currency
        self.policies = policies
        self.confirmationCodes = confirmationCodes
        self.documents = documents
        self.bookedAt = bookedAt
        self.modifiedAt = modifiedAt
        self.cancellationInfo = cancellationInfo
    }
}

/// Type of booking
public enum BookingType: String, Codable, CaseIterable {
    case flight
    case hotel
    case car_rental
    case activity
    case insurance
    case transport
    case package
}

/// Vendor information
public struct VendorInfo: Codable, Hashable {
    public let id: String
    public let name: String
    public let type: VendorType
    public let contactInfo: ContactInfo?
    public let logoURL: String?
    public let websiteURL: String?
    
    public init(
        id: String,
        name: String,
        type: VendorType,
        contactInfo: ContactInfo? = nil,
        logoURL: String? = nil,
        websiteURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.contactInfo = contactInfo
        self.logoURL = logoURL
        self.websiteURL = websiteURL
    }
}

/// Vendor type
public enum VendorType: String, Codable, CaseIterable {
    case airline
    case hotel
    case ota // Online Travel Agency
    case car_rental
    case tour_operator
    case insurance
    case direct
}

/// Booking status
public enum BookingStatus: String, Codable, CaseIterable {
    case pending
    case confirmed
    case ticketed
    case checked_in
    case completed
    case cancelled
    case refunded
    case failed
}

/// Booking policies
public struct BookingPolicies: Codable, Hashable {
    public let cancellationPolicy: CancellationPolicy?
    public let modificationPolicy: ModificationPolicy?
    public let refundPolicy: RefundPolicy?
    public let baggagePolicy: String?
    public let checkInPolicy: String?
    
    public init(
        cancellationPolicy: CancellationPolicy? = nil,
        modificationPolicy: ModificationPolicy? = nil,
        refundPolicy: RefundPolicy? = nil,
        baggagePolicy: String? = nil,
        checkInPolicy: String? = nil
    ) {
        self.cancellationPolicy = cancellationPolicy
        self.modificationPolicy = modificationPolicy
        self.refundPolicy = refundPolicy
        self.baggagePolicy = baggagePolicy
        self.checkInPolicy = checkInPolicy
    }
}

/// Cancellation policy
public struct CancellationPolicy: Codable, Hashable {
    public let deadlines: [CancellationDeadline]
    public let fees: [Money]
    public let terms: String
    
    public init(deadlines: [CancellationDeadline], fees: [Money], terms: String) {
        self.deadlines = deadlines
        self.fees = fees
        self.terms = terms
    }
}

/// Cancellation deadline
public struct CancellationDeadline: Codable, Hashable {
    public let date: Date
    public let feePercentage: Int
    public let description: String
    
    public init(date: Date, feePercentage: Int, description: String) {
        self.date = date
        self.feePercentage = feePercentage
        self.description = description
    }
}

/// Modification policy
public struct ModificationPolicy: Codable, Hashable {
    public let allowed: Bool
    public let fee: Money?
    public let restrictions: String?
    
    public init(allowed: Bool, fee: Money? = nil, restrictions: String? = nil) {
        self.allowed = allowed
        self.fee = fee
        self.restrictions = restrictions
    }
}

/// Refund policy
public struct RefundPolicy: Codable, Hashable {
    public let refundable: Bool
    public let conditions: String?
    public let processingTime: String?
    
    public init(refundable: Bool, conditions: String? = nil, processingTime: String? = nil) {
        self.refundable = refundable
        self.conditions = conditions
        self.processingTime = processingTime
    }
}

/// Booking document
public struct BookingDocument: Codable, Hashable {
    public let type: DocumentType
    public let number: String
    public let url: String?
    public let expiryDate: Date?
    
    public init(type: DocumentType, number: String, url: String? = nil, expiryDate: Date? = nil) {
        self.type = type
        self.number = number
        self.url = url
        self.expiryDate = expiryDate
    }
}

/// Document type
public enum DocumentType: String, Codable, CaseIterable {
    case ticket
    case boarding_pass
    case voucher
    case invoice
    case confirmation
    case insurance_policy
    case visa
    case passport
}

/// Cancellation information
public struct CancellationInfo: Codable, Hashable {
    public let cancelledAt: Date
    public let reason: String
    public let fee: Money?
    public let refundAmount: Money?
    public let refundStatus: RefundStatus
    
    public init(
        cancelledAt: Date,
        reason: String,
        fee: Money? = nil,
        refundAmount: Money? = nil,
        refundStatus: RefundStatus
    ) {
        self.cancelledAt = cancelledAt
        self.reason = reason
        self.fee = fee
        self.refundAmount = refundAmount
        self.refundStatus = refundStatus
    }
}

/// Refund status
public enum RefundStatus: String, Codable, CaseIterable {
    case pending
    case processing
    case completed
    case failed
    case not_applicable
}

// MARK: - Compliance Models

/// Compliance pack for trip requirements
public struct CompliancePack: Codable, Hashable {
    public let id: String
    public var visaRequirements: [VisaRequirement]
    public var checklist: [ComplianceItem]
    public var deadlines: [ComplianceDeadline]
    public var insurance: InsuranceInfo?
    public var localRegulations: [LocalRegulation]
    public var healthRequirements: [HealthRequirement]
    public let generatedAt: Date
    public var lastUpdatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        visaRequirements: [VisaRequirement] = [],
        checklist: [ComplianceItem] = [],
        deadlines: [ComplianceDeadline] = [],
        insurance: InsuranceInfo? = nil,
        localRegulations: [LocalRegulation] = [],
        healthRequirements: [HealthRequirement] = [],
        generatedAt: Date = Date(),
        lastUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.visaRequirements = visaRequirements
        self.checklist = checklist
        self.deadlines = deadlines
        self.insurance = insurance
        self.localRegulations = localRegulations
        self.healthRequirements = healthRequirements
        self.generatedAt = generatedAt
        self.lastUpdatedAt = lastUpdatedAt
    }
}

/// Visa requirement
public struct VisaRequirement: Codable, Hashable, Identifiable {
    public let id: String
    public let country: String
    public let type: VisaType
    public let required: Bool
    public let processingTime: String
    public let validityPeriod: String
    public let cost: Money
    public let documents: [String]
    public let applicationURL: String?
    public let notes: String?
    
    public init(
        id: String = UUID().uuidString,
        country: String,
        type: VisaType,
        required: Bool,
        processingTime: String,
        validityPeriod: String,
        cost: Money,
        documents: [String],
        applicationURL: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.country = country
        self.type = type
        self.required = required
        self.processingTime = processingTime
        self.validityPeriod = validityPeriod
        self.cost = cost
        self.documents = documents
        self.applicationURL = applicationURL
        self.notes = notes
    }
}

/// Visa type
public enum VisaType: String, Codable, CaseIterable {
    case tourist
    case business
    case transit
    case eVisa
    case visaOnArrival
    case visaFree
}

/// Compliance checklist item
public struct ComplianceItem: Codable, Hashable, Identifiable {
    public let id: String
    public let category: ComplianceCategory
    public let title: String
    public let description: String
    public var completed: Bool
    public let mandatory: Bool
    public let deadline: Date?
    public var completedAt: Date?
    public var documentRef: String?
    
    public init(
        id: String = UUID().uuidString,
        category: ComplianceCategory,
        title: String,
        description: String,
        completed: Bool = false,
        mandatory: Bool = true,
        deadline: Date? = nil,
        completedAt: Date? = nil,
        documentRef: String? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.description = description
        self.completed = completed
        self.mandatory = mandatory
        self.deadline = deadline
        self.completedAt = completedAt
        self.documentRef = documentRef
    }
}

/// Compliance category
public enum ComplianceCategory: String, Codable, CaseIterable {
    case documentation
    case health
    case insurance
    case legal
    case financial
    case customs
}

/// Compliance deadline
public struct ComplianceDeadline: Codable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let date: Date
    public let type: DeadlineType
    public let description: String
    public let reminderDays: Int
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        date: Date,
        type: DeadlineType,
        description: String,
        reminderDays: Int = 7
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.type = type
        self.description = description
        self.reminderDays = reminderDays
    }
}

/// Deadline type
public enum DeadlineType: String, Codable, CaseIterable {
    case visa_application
    case passport_expiry
    case booking_payment
    case document_submission
    case insurance_purchase
    case vaccination
}

/// Insurance information
public struct InsuranceInfo: Codable, Hashable {
    public let provider: String
    public let policyNumber: String?
    public let coverage: InsuranceCoverage
    public let emergencyNumber: String
    public let validFrom: Date
    public let validTo: Date
    public let cost: Money
    
    public init(
        provider: String,
        policyNumber: String? = nil,
        coverage: InsuranceCoverage,
        emergencyNumber: String,
        validFrom: Date,
        validTo: Date,
        cost: Money
    ) {
        self.provider = provider
        self.policyNumber = policyNumber
        self.coverage = coverage
        self.emergencyNumber = emergencyNumber
        self.validFrom = validFrom
        self.validTo = validTo
        self.cost = cost
    }
}

/// Insurance coverage
public struct InsuranceCoverage: Codable, Hashable {
    public let medical: Bool
    public let tripCancellation: Bool
    public let baggage: Bool
    public let flightDelay: Bool
    public let emergency

: Bool
    public let rentalCar: Bool
    public let adventure: Bool
    
    public init(
        medical: Bool = true,
        tripCancellation: Bool = true,
        baggage: Bool = true,
        flightDelay: Bool = true,
        emergency: Bool = true,
        rentalCar: Bool = false,
        adventure: Bool = false
    ) {
        self.medical = medical
        self.tripCancellation = tripCancellation
        self.baggage = baggage
        self.flightDelay = flightDelay
        self.emergency = emergency
        self.rentalCar = rentalCar
        self.adventure = adventure
    }
}

/// Local regulation
public struct LocalRegulation: Codable, Hashable {
    public let country: String
    public let type: RegulationType
    public let description: String
    public let penalty: String?
    public let reference: String?
    
    public init(
        country: String,
        type: RegulationType,
        description: String,
        penalty: String? = nil,
        reference: String? = nil
    ) {
        self.country = country
        self.type = type
        self.description = description
        self.penalty = penalty
        self.reference = reference
    }
}

/// Regulation type
public enum RegulationType: String, Codable, CaseIterable {
    case customs
    case currency
    case photography
    case dress_code
    case alcohol
    case behavior
    case environment
}

/// Health requirement
public struct HealthRequirement: Codable, Hashable {
    public let type: HealthRequirementType
    public let name: String
    public let required: Bool
    public let description: String
    public let validityPeriod: String?
    public let clinics: [String]
    
    public init(
        type: HealthRequirementType,
        name: String,
        required: Bool,
        description: String,
        validityPeriod: String? = nil,
        clinics: [String] = []
    ) {
        self.type = type
        self.name = name
        self.required = required
        self.description = description
        self.validityPeriod = validityPeriod
        self.clinics = clinics
    }
}

/// Health requirement type
public enum HealthRequirementType: String, Codable, CaseIterable {
    case vaccination
    case test
    case medication
    case certificate
}