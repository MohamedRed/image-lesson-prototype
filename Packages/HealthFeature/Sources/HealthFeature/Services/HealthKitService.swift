import Foundation
import HealthKit
import Combine
import HealthService

/// HealthKit integration service with proper permissions and data mapping
public class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    
    @Published public var isAvailable: Bool = false
    @Published public var authorizedDataTypes: Set<HKObjectType> = []
    @Published public var permissionStatus: PermissionStatus = .notRequested
    
    public enum PermissionStatus {
        case notRequested
        case requesting
        case authorized
        case denied
        case restricted
    }
    
    // MARK: - Data Types Configuration
    
    /// All health data types the app wants to read
    public var readDataTypes: Set<HKObjectType> {
        let characteristicTypes: Set<HKObjectType> = [
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
            HKObjectType.characteristicType(forIdentifier: .bloodType)!
        ]
        
        let quantityTypes: Set<HKObjectType> = [
            // Vitals
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            
            // Body measurements
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,
            
            // Activity
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            
            // Blood
            HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
            
            // Nutrition
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
        ]
        
        let categoryTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!,
        ]
        
        let workoutType: Set<HKObjectType> = [
            HKObjectType.workoutType()
        ]
        
        return characteristicTypes.union(quantityTypes).union(categoryTypes).union(workoutType)
    }
    
    /// Data types the app wants to write (minimal)
    public var writeDataTypes: Set<HKSampleType> {
        return [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!,
        ]
    }
    
    public init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
        checkAuthorizationStatus()
    }
    
    // MARK: - Permission Management
    
    public func requestPermissions() -> AnyPublisher<Bool, Error> {
        guard isAvailable else {
            return Fail(error: HealthKitError.notAvailable)
                .eraseToAnyPublisher()
        }
        
        return Future<Bool, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(HealthKitError.serviceUnavailable))
                return
            }
            
            self.permissionStatus = .requesting
            
            self.healthStore.requestAuthorization(
                toShare: self.writeDataTypes,
                read: self.readDataTypes
            ) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.permissionStatus = .denied
                        promise(.failure(error))
                    } else {
                        self.permissionStatus = success ? .authorized : .denied
                        self.checkAuthorizationStatus()
                        promise(.success(success))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func checkAuthorizationStatus() {
        var authorizedTypes: Set<HKObjectType> = []
        
        for dataType in readDataTypes {
            let status = healthStore.authorizationStatus(for: dataType)
            if status == .sharingAuthorized {
                authorizedTypes.insert(dataType)
            }
        }
        
        self.authorizedDataTypes = authorizedTypes
        
        if authorizedTypes.isEmpty && permissionStatus == .notRequested {
            permissionStatus = .notRequested
        } else if !authorizedTypes.isEmpty {
            permissionStatus = .authorized
        }
    }
    
    // MARK: - Data Reading
    
    public func readLatestObservations(
        for types: [HKQuantityTypeIdentifier],
        limit: Int = 100
    ) -> AnyPublisher<[HealthObservation], Error> {
        let publishers = types.compactMap { identifier -> AnyPublisher<[HealthObservation], Error>? in
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
                return nil
            }
            
            return readQuantityData(for: quantityType, limit: limit)
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { arrays in
                arrays.flatMap { $0 }
            }
            .eraseToAnyPublisher()
    }
    
    private func readQuantityData(
        for quantityType: HKQuantityType,
        limit: Int = 100
    ) -> AnyPublisher<[HealthObservation], Error> {
        Future<[HealthObservation], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(HealthKitError.serviceUnavailable))
                return
            }
            
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                let observations = samples?.compactMap { sample -> HealthObservation? in
                    guard let quantitySample = sample as? HKQuantitySample else { return nil }
                    return self.mapToHealthObservation(quantitySample)
                } ?? []
                
                promise(.success(observations))
            }
            
            self.healthStore.execute(query)
        }
        .eraseToAnyPublisher()
    }
    
    public func readWorkouts(
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int = 50
    ) -> AnyPublisher<[HealthObservation], Error> {
        Future<[HealthObservation], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(HealthKitError.serviceUnavailable))
                return
            }
            
            var predicate: NSPredicate?
            if let startDate = startDate, let endDate = endDate {
                predicate = HKQuery.predicateForSamples(
                    withStart: startDate,
                    end: endDate,
                    options: .strictStartDate
                )
            }
            
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                let observations = samples?.compactMap { sample -> HealthObservation? in
                    guard let workout = sample as? HKWorkout else { return nil }
                    return self.mapWorkoutToObservation(workout)
                } ?? []
                
                promise(.success(observations))
            }
            
            self.healthStore.execute(query)
        }
        .eraseToAnyPublisher()
    }
    
    public func readSleepData(
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> AnyPublisher<[HealthObservation], Error> {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return Fail(error: HealthKitError.dataTypeNotSupported)
                .eraseToAnyPublisher()
        }
        
        return Future<[HealthObservation], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(HealthKitError.serviceUnavailable))
                return
            }
            
            var predicate: NSPredicate?
            if let startDate = startDate, let endDate = endDate {
                predicate = HKQuery.predicateForSamples(
                    withStart: startDate,
                    end: endDate,
                    options: .strictStartDate
                )
            }
            
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                let observations = samples?.compactMap { sample -> HealthObservation? in
                    guard let categorySample = sample as? HKCategorySample else { return nil }
                    return self.mapSleepToObservation(categorySample)
                } ?? []
                
                promise(.success(observations))
            }
            
            self.healthStore.execute(query)
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Background Delivery
    
    public func enableBackgroundDelivery(for types: [HKObjectType]) -> AnyPublisher<Void, Error> {
        let publishers = types.map { type -> AnyPublisher<Void, Error> in
            Future<Void, Error> { [weak self] promise in
                guard let self = self else {
                    promise(.failure(HealthKitError.serviceUnavailable))
                    return
                }
                
                self.healthStore.enableBackgroundDelivery(
                    for: type,
                    frequency: .immediate
                ) { success, error in
                    if let error = error {
                        promise(.failure(error))
                    } else {
                        promise(.success(()))
                    }
                }
            }
            .eraseToAnyPublisher()
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Data Writing
    
    public func saveBodyWeight(_ weight: Double, unit: HKUnit = HKUnit.gramUnit(with: .kilo)) -> AnyPublisher<Bool, Error> {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return Fail(error: HealthKitError.dataTypeNotSupported)
                .eraseToAnyPublisher()
        }
        
        let quantity = HKQuantity(unit: unit, doubleValue: weight)
        let sample = HKQuantitySample(
            type: weightType,
            quantity: quantity,
            start: Date(),
            end: Date()
        )
        
        return saveHealthKitSample(sample)
    }
    
    public func saveMindfulSession(duration: TimeInterval) -> AnyPublisher<Bool, Error> {
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else {
            return Fail(error: HealthKitError.dataTypeNotSupported)
                .eraseToAnyPublisher()
        }
        
        let startDate = Date().addingTimeInterval(-duration)
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: startDate,
            end: Date()
        )
        
        return saveHealthKitSample(sample)
    }
    
    private func saveHealthKitSample(_ sample: HKSample) -> AnyPublisher<Bool, Error> {
        Future<Bool, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(HealthKitError.serviceUnavailable))
                return
            }
            
            self.healthStore.save(sample) { success, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(success))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Data Mapping
    
    private func mapToHealthObservation(_ sample: HKQuantitySample) -> HealthObservation {
        let observationType = mapHKQuantityTypeToObservationType(sample.quantityType)
        let value = mapHKQuantityToObservationValue(sample.quantity, type: sample.quantityType)
        
        return HealthObservation(
            userId: "current_user", // Would be set by calling code
            type: observationType,
            value: value,
            date: sample.endDate,
            source: .healthKit,
            metadata: [
                "sourceRevision": sample.sourceRevision.source.name,
                "device": sample.device?.name ?? "Unknown"
            ]
        )
    }
    
    private func mapWorkoutToObservation(_ workout: HKWorkout) -> HealthObservation {
        let duration = workout.duration
        let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        
        var metadata: [String: String] = [
            "workoutType": workoutTypeToString(workout.workoutActivityType),
            "duration": String(duration),
            "calories": String(calories)
        ]
        
        if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
            metadata["distance"] = String(distance)
        }
        
        return HealthObservation(
            userId: "current_user",
            type: .workout,
            value: .duration(duration),
            date: workout.endDate,
            source: .healthKit,
            metadata: metadata
        )
    }
    
    private func mapSleepToObservation(_ sample: HKCategorySample) -> HealthObservation {
        let duration = sample.endDate.timeIntervalSince(sample.startDate)
        let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value)
        
        return HealthObservation(
            userId: "current_user",
            type: .sleep,
            value: .duration(duration),
            date: sample.endDate,
            source: .healthKit,
            metadata: [
                "sleepPhase": sleepValueToString(sleepValue),
                "startTime": ISO8601DateFormatter().string(from: sample.startDate)
            ]
        )
    }
    
    private func mapHKQuantityTypeToObservationType(_ quantityType: HKQuantityType) -> HealthObservation.ObservationType {
        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            return .heartRate
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue,
             HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue:
            return .bloodPressure
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            return .bloodOxygen
        case HKQuantityTypeIdentifier.bodyTemperature.rawValue:
            return .bodyTemperature
        case HKQuantityTypeIdentifier.respiratoryRate.rawValue:
            return .respiratoryRate
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return .weight
        case HKQuantityTypeIdentifier.height.rawValue:
            return .height
        case HKQuantityTypeIdentifier.bodyFatPercentage.rawValue:
            return .bodyFat
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return .steps
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
            return .distance
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            return .activeCalories
        case HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
            return .restingCalories
        case HKQuantityTypeIdentifier.bloodGlucose.rawValue:
            return .bloodGlucose
        case HKQuantityTypeIdentifier.dietaryWater.rawValue:
            return .hydration
        default:
            return .steps // fallback
        }
    }
    
    private func mapHKQuantityToObservationValue(_ quantity: HKQuantity, type: HKQuantityType) -> HealthObservation.ObservationValue {
        switch type.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            return .numeric(bpm, "bpm")
            
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            let kg = quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            return .numeric(kg, "kg")
            
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            let steps = quantity.doubleValue(for: HKUnit.count())
            return .numeric(steps, "steps")
            
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
             HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
            let calories = quantity.doubleValue(for: HKUnit.kilocalorie())
            return .numeric(calories, "kcal")
            
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
            let meters = quantity.doubleValue(for: HKUnit.meter())
            return .numeric(meters, "m")
            
        case HKQuantityTypeIdentifier.bloodGlucose.rawValue:
            let mgdL = quantity.doubleValue(for: HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci)))
            return .numeric(mgdL, "mg/dL")
            
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            let percent = quantity.doubleValue(for: HKUnit.percent())
            return .numeric(percent * 100, "%")
            
        default:
            return .numeric(quantity.doubleValue(for: HKUnit.count()), "count")
        }
    }
    
    // MARK: - Helper Functions
    
    private func workoutTypeToString(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Weight Training"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Other"
        }
    }
    
    private func sleepValueToString(_ value: HKCategoryValueSleepAnalysis?) -> String {
        switch value {
        case .inBed: return "In Bed"
        case .asleepCore: return "Core Sleep"
        case .asleepDeep: return "Deep Sleep"
        case .asleepREM: return "REM Sleep"
        case .awake: return "Awake"
        default: return "Unknown"
        }
    }
}

// MARK: - Error Types

public enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case serviceUnavailable
    case dataTypeNotSupported
    case permissionDenied
    case dataReadingFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .serviceUnavailable:
            return "HealthKit service is temporarily unavailable"
        case .dataTypeNotSupported:
            return "The requested data type is not supported"
        case .permissionDenied:
            return "Permission to access health data was denied"
        case .dataReadingFailed(let error):
            return "Failed to read health data: \(error.localizedDescription)"
        }
    }
}