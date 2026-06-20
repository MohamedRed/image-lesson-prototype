import Foundation
import HealthKit
import Combine
import BackgroundTasks
import UserNotifications
import os.log
import UIKit
import HealthService

@available(iOS 16.0, *)
public class HealthKitBackgroundService: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    private let healthStore = HKHealthStore()
    private let logger = Logger(subsystem: "com.liive.health", category: "BackgroundService")
    
    private var cancellables = Set<AnyCancellable>()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Background delivery queries
    private var backgroundQueries: [String: HKObserverQuery] = [:]
    
    // Data types for background monitoring
    private let backgroundDataTypes: [HKSampleType] = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .height)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ]
    
    // Workout types for background monitoring
    private let workoutType = HKObjectType.workoutType()
    
    // Notification identifiers
    private struct NotificationIdentifiers {
        static let dailyHealthSync = "daily_health_sync"
        static let healthDataAvailable = "health_data_available"
        static let criticalHealthChange = "critical_health_change"
    }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupBackgroundDelivery()
        registerBackgroundTasks()
        scheduleBackgroundRefresh()
    }
    
    // MARK: - Background Task Registration
    
    private func registerBackgroundTasks() {
        // Register background app refresh task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.liive.health.background-sync",
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
        
        // Register background processing task for heavy operations
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.liive.health.background-processing",
            using: nil
        ) { task in
            self.handleBackgroundProcessing(task: task as! BGProcessingTask)
        }
        
        logger.info("Background tasks registered successfully")
    }
    
    // MARK: - Background Delivery Setup
    
    private func setupBackgroundDelivery() {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit is not available")
            return
        }
        
        // Enable background delivery for each data type
        for dataType in backgroundDataTypes {
            enableBackgroundDelivery(for: dataType)
        }
        
        // Enable background delivery for workouts
        enableBackgroundDelivery(for: workoutType)
        
        logger.info("Background delivery setup completed for \(self.backgroundDataTypes.count + 1) data types")
    }
    
    private func enableBackgroundDelivery(for sampleType: HKSampleType) {
        // Enable background delivery
        healthStore.enableBackgroundDelivery(
            for: sampleType,
            frequency: .immediate
        ) { [weak self] success, error in
            if let error = error {
                self?.logger.error("Failed to enable background delivery for \(sampleType.identifier): \(error.localizedDescription)")
            } else if success {
                self?.logger.info("Background delivery enabled for \(sampleType.identifier)")
                self?.setupObserverQuery(for: sampleType)
            }
        }
    }
    
    private func setupObserverQuery(for sampleType: HKSampleType) {
        let query = HKObserverQuery(
            sampleType: sampleType,
            predicate: nil
        ) { [weak self] query, completionHandler, error in
            
            guard let self = self else {
                completionHandler()
                return
            }
            
            if let error = error {
                self.logger.error("Observer query error for \(sampleType.identifier): \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            // Handle new data available
            Task {
                await self.handleNewHealthData(for: sampleType)
                completionHandler()
            }
        }
        
        backgroundQueries[sampleType.identifier] = query
        healthStore.execute(query)
        
        logger.info("Observer query setup for \(sampleType.identifier)")
    }
    
    // MARK: - Background Task Handlers
    
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        logger.info("Background sync task started")
        
        // Schedule next background refresh
        scheduleBackgroundRefresh()
        
        // Set expiration handler
        task.expirationHandler = {
            self.logger.warning("Background sync task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Perform background sync
        Task {
            let success = await performBackgroundSync()
            task.setTaskCompleted(success: success)
            self.logger.info("Background sync task completed with success: \(success)")
        }
    }
    
    private func handleBackgroundProcessing(task: BGProcessingTask) {
        logger.info("Background processing task started")
        
        task.expirationHandler = {
            self.logger.warning("Background processing task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Perform heavy background processing
        Task {
            let success = await performBackgroundProcessing()
            task.setTaskCompleted(success: success)
            self.logger.info("Background processing task completed with success: \(success)")
        }
    }
    
    // MARK: - Data Synchronization
    
    private func performBackgroundSync() async -> Bool {
        logger.info("Performing background health data sync")
        
        do {
            // Start background task to prevent suspension
            await startBackgroundTask()
            
            // Sync recent health data (last 24 hours)
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate) ?? endDate
            
            var syncSuccess = true
            
            // Sync each data type
            for dataType in backgroundDataTypes {
                let success = await syncHealthData(
                    for: dataType,
                    startDate: startDate,
                    endDate: endDate
                )
                syncSuccess = syncSuccess && success
            }
            
            // Sync workouts
            let workoutSuccess = await syncWorkouts(
                startDate: startDate,
                endDate: endDate
            )
            syncSuccess = syncSuccess && workoutSuccess
            
            // Update last sync timestamp
            if syncSuccess {
                UserDefaults.standard.set(Date(), forKey: "lastHealthKitSync")
                await scheduleHealthSyncNotification()
            }
            
            await endBackgroundTask()
            
            logger.info("Background sync completed with success: \(syncSuccess)")
            return syncSuccess
            
        } catch {
            logger.error("Background sync failed: \(error.localizedDescription)")
            await endBackgroundTask()
            return false
        }
    }
    
    private func performBackgroundProcessing() async -> Bool {
        logger.info("Performing background health data processing")
        
        do {
            await startBackgroundTask()
            
            // Perform data aggregation and analysis
            let success = await performHealthAnalytics()
            
            // Clean up old data
            await cleanupOldHealthData()
            
            // Update health insights
            await updateHealthInsights()
            
            await endBackgroundTask()
            
            return success
            
        } catch {
            logger.error("Background processing failed: \(error.localizedDescription)")
            await endBackgroundTask()
            return false
        }
    }
    
    private func handleNewHealthData(for sampleType: HKSampleType) async {
        logger.info("New health data available for \(sampleType.identifier)")
        
        // Get the most recent data
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -1, to: endDate) ?? endDate
        
        // Sync the new data
        let success = await syncHealthData(
            for: sampleType,
            startDate: startDate,
            endDate: endDate
        )
        
        if success {
            // Check for critical health changes
            await checkForCriticalHealthChanges(sampleType: sampleType)
            
            // Update real-time insights
            await updateRealTimeInsights(for: sampleType)
        }
    }
    
    private func syncHealthData(
        for sampleType: HKSampleType,
        startDate: Date,
        endDate: Date
    ) async -> Bool {
        
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )
            
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { query, samples, error in
                
                if let error = error {
                    self.logger.error("Failed to query \(sampleType.identifier): \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                
                guard let samples = samples, !samples.isEmpty else {
                    self.logger.debug("No new samples found for \(sampleType.identifier)")
                    continuation.resume(returning: true)
                    return
                }
                
                // Convert and upload samples
                Task {
                    let success = await self.uploadHealthSamples(samples)
                    continuation.resume(returning: success)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func syncWorkouts(startDate: Date, endDate: Date) async -> Bool {
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )
            
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { query, samples, error in
                
                if let error = error {
                    self.logger.error("Failed to query workouts: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                
                guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                    self.logger.debug("No new workouts found")
                    continuation.resume(returning: true)
                    return
                }
                
                Task {
                    let success = await self.uploadWorkouts(workouts)
                    continuation.resume(returning: success)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func uploadHealthSamples(_ samples: [HKSample]) async -> Bool {
        logger.info("Uploading \(samples.count) health samples")
        
        // Convert samples to FHIR-like dicts for import payload
        let observations = samples.compactMap { sample -> HealthObservation? in
            let hkIdentifier = (sample as? HKQuantitySample)?.quantityType.identifier
                ?? (sample as? HKCategorySample)?.categoryType.identifier
            let obsType = mapHealthKitIdentifierToObservationType(hkIdentifier ?? "unknown")
            
            if let qs = sample as? HKQuantitySample {
                let unit = getPreferredUnit(for: qs.quantityType)
                let value = qs.quantity.doubleValue(for: unit)
                return HealthObservation(
                    userId: "me",
                    type: obsType,
                    value: .numeric(value, unit.unitString),
                    date: sample.endDate,
                    source: .healthKit,
                    metadata: ["hkType": qs.quantityType.identifier]
                )
            }
            
            if let cs = sample as? HKCategorySample {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                return HealthObservation(
                    userId: "me",
                    type: obsType,
                    value: .duration(duration),
                    date: sample.endDate,
                    source: .healthKit,
                    metadata: ["hkType": cs.categoryType.identifier]
                )
            }
            return nil
        }
        
        guard !observations.isEmpty else {
            logger.warning("No valid observations to upload")
            return false
        }
        
        do {
            // Upload via import endpoint
            let manifest = HealthKitImportRequest.ImportManifest(
                startDate: samples.map { $0.startDate }.min() ?? Date(),
                endDate: samples.map { $0.endDate }.max() ?? Date(),
                dataTypes: Array(Set(samples.map { $0.sampleType.identifier })),
                recordCount: observations.count
            )
            let payload = HealthKitImportRequest(observations: observations, manifest: manifest)
            let success = try await HealthService.shared.importHealthKitData(payload)
                .map { _ in true }
                .replaceError(with: false)
                .async()
            
            if success {
                logger.info("Successfully uploaded \(observations.count) health observations")
                
                // Store local backup
                await storeLocalBackup(observationsToDicts(observations))
                
                return true
            } else {
                logger.error("Failed to upload health observations")
                
                // Store for retry
                await storeForRetry(observationsToDicts(observations))
                
                return false
            }
            
        } catch {
            logger.error("Health data upload error: \(error.localizedDescription)")
            await storeForRetry(observationsToDicts(observations))
            return false
        }
    }
    
    private func uploadWorkouts(_ workouts: [HKWorkout]) async -> Bool {
        logger.info("Uploading \(workouts.count) workouts")
        
        let observations: [HealthObservation] = workouts.map { workout in
            let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            return HealthObservation(
                userId: "me",
                type: .workout,
                value: .numeric(calories, "kcal"),
                date: workout.endDate,
                source: .healthKit,
                metadata: [
                    "activityType": String(workout.workoutActivityType.rawValue),
                    "duration": String(workout.duration),
                    "distanceMeters": String(workout.totalDistance?.doubleValue(for: .meter()) ?? 0)
                ]
            )
        }
        
        do {
            let manifest = HealthKitImportRequest.ImportManifest(
                startDate: workouts.map { $0.startDate }.min() ?? Date(),
                endDate: workouts.map { $0.endDate }.max() ?? Date(),
                dataTypes: [HKWorkoutType.workoutType().identifier],
                recordCount: observations.count
            )
            let importRequest = HealthKitImportRequest(observations: observations, manifest: manifest)
            let success = try await HealthService.shared.importHealthKitData(importRequest)
                .map { _ in true }
                .replaceError(with: false)
                .async()
            
            if success {
                logger.info("Successfully uploaded \(workouts.count) workouts")
                return true
            } else {
                logger.error("Failed to upload workouts")
                return false
            }
            
        } catch {
            logger.error("Workout upload error: \(error.localizedDescription)")
            return false
        }
    }
    
    private func convertSampleToFHIR(_ sample: HKSample) -> [String: Any]? {
        var fhirObservation: [String: Any] = [
            "resourceType": "Observation",
            "id": sample.uuid.uuidString,
            "effectiveDateTime": sample.endDate.toISO8601String(),
            "issued": sample.endDate.toISO8601String()
        ]
        
        // Handle quantity samples
        if let quantitySample = sample as? HKQuantitySample {
            let identifier = quantitySample.quantityType.identifier
            let unit = getPreferredUnit(for: quantitySample.quantityType)
            let value = quantitySample.quantity.doubleValue(for: unit)
            
            fhirObservation["code"] = [
                "coding": [[
                    "system": "http://loinc.org",
                    "code": mapHealthKitToLOINC(identifier),
                    "display": identifier
                ]]
            ]
            
            fhirObservation["valueQuantity"] = [
                "value": value,
                "unit": unit.unitString,
                "system": "http://unitsofmeasure.org"
            ]
            
            // Add numeric value for easy querying
            fhirObservation["value"] = [
                "numeric": value
            ]
            
        } else if let categorySample = sample as? HKCategorySample {
            let identifier = categorySample.categoryType.identifier
            
            fhirObservation["code"] = [
                "coding": [[
                    "system": "http://loinc.org",
                    "code": mapHealthKitToLOINC(identifier),
                    "display": identifier
                ]]
            ]
            
            if identifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue {
                fhirObservation["valueQuantity"] = [
                    "value": sample.endDate.timeIntervalSince(sample.startDate),
                    "unit": "s",
                    "system": "http://unitsofmeasure.org"
                ]
                
                fhirObservation["value"] = [
                    "numeric": sample.endDate.timeIntervalSince(sample.startDate)
                ]
            }
        }
        
        // Add metadata
        if let metadata = sample.metadata {
            fhirObservation["meta"] = metadata
        }
        
        // Add type for easier backend processing
        if let quantitySample = sample as? HKQuantitySample {
            fhirObservation["type"] = mapHealthKitIdentifierToType(quantitySample.quantityType.identifier)
        } else if let categorySample = sample as? HKCategorySample {
            fhirObservation["type"] = mapHealthKitIdentifierToType(categorySample.categoryType.identifier)
        }
        
        return fhirObservation
    }
    
    // MARK: - Background Task Management
    
    private func startBackgroundTask() async {
        await MainActor.run {
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                Task { await self?.endBackgroundTask() }
            }
        }
    }
    
    private func endBackgroundTask() async {
        await MainActor.run {
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
    }
    
    // MARK: - Scheduling
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.liive.health.background-sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60) // 4 hours from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background refresh scheduled")
        } catch {
            logger.error("Could not schedule background refresh: \(error.localizedDescription)")
        }
    }
    
    private func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: "com.liive.health.background-processing")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // 24 hours from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background processing scheduled")
        } catch {
            logger.error("Could not schedule background processing: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Health Analytics
    
    private func performHealthAnalytics() async -> Bool {
        logger.info("Performing health analytics")
        
        // Calculate daily aggregations
        let success = await calculateDailyAggregations()
        
        if success {
            // Update health score
            await updateHealthScore()
            
            // Generate insights
            await generateHealthInsights()
        }
        
        return success
    }
    
    private func calculateDailyAggregations() async -> Bool {
        // This would calculate daily totals, averages, etc.
        // For now, return success
        logger.info("Daily aggregations calculated")
        return true
    }
    
    private func updateHealthScore() async {
        // Calculate and update user's health score
        logger.info("Health score updated")
    }
    
    private func generateHealthInsights() async {
        // Generate personalized health insights
        logger.info("Health insights generated")
    }
    
    private func updateRealTimeInsights(for sampleType: HKSampleType) async {
        // Update real-time insights based on new data
        logger.info("Real-time insights updated for \(sampleType.identifier)")
    }
    
    // MARK: - Critical Health Monitoring
    
    private func checkForCriticalHealthChanges(sampleType: HKSampleType) async {
        // Check for significant health changes that require immediate attention
        
        guard let quantityType = sampleType as? HKQuantityType else { return }
        
        // Get recent samples
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate) ?? endDate
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { query, samples, error in
                
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume()
                    return
                }
                
                Task {
                    await self.analyzeCriticalChanges(samples: samples, quantityType: quantityType)
                    continuation.resume()
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func analyzeCriticalChanges(samples: [HKQuantitySample], quantityType: HKQuantityType) async {
        let identifier = quantityType.identifier
        let unit = getPreferredUnit(for: quantityType)
        
        switch identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            let values = samples.map { $0.quantity.doubleValue(for: unit) }
            if let maxHeartRate = values.max(), maxHeartRate > 180 {
                await sendCriticalHealthAlert(
                    title: "High Heart Rate Detected",
                    body: "Your heart rate reached \(Int(maxHeartRate)) BPM. Consider consulting your doctor if this persists."
                )
            }
            
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue:
            let values = samples.map { $0.quantity.doubleValue(for: unit) }
            if let maxBP = values.max(), maxBP > 180 {
                await sendCriticalHealthAlert(
                    title: "High Blood Pressure Alert",
                    body: "Your blood pressure reading was \(Int(maxBP)) mmHg. Please consult your healthcare provider."
                )
            }
            
        case HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            let values = samples.map { $0.quantity.doubleValue(for: unit) }
            if let avgRHR = values.first, avgRHR > 100 {
                await sendCriticalHealthAlert(
                    title: "Elevated Resting Heart Rate",
                    body: "Your resting heart rate is \(Int(avgRHR)) BPM, which may indicate a health concern."
                )
            }
            
        default:
            break
        }
    }
    
    // MARK: - Notifications
    
    private func sendCriticalHealthAlert(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if #available(iOS 15.0, *) {
            content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        } else {
            content.sound = .default
        }
        content.categoryIdentifier = "CRITICAL_HEALTH"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifiers.criticalHealthChange,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Critical health alert sent: \(title)")
        } catch {
            logger.error("Failed to send critical health alert: \(error.localizedDescription)")
        }
    }
    
    private func scheduleHealthSyncNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Health Data Synced"
        content.body = "Your health data has been successfully synchronized."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifiers.dailyHealthSync,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.debug("Health sync notification scheduled")
        } catch {
            logger.error("Failed to schedule health sync notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Storage
    
    private func storeLocalBackup(_ observations: [[String: Any]]) async {
        // Store local backup of health data
        let backupKey = "health_backup_\(Date().timeIntervalSince1970)"
        UserDefaults.standard.set(observations, forKey: backupKey)
        logger.debug("Stored local backup with \(observations.count) observations")
    }
    
    private func storeForRetry(_ observations: [[String: Any]]) async {
        // Store failed uploads for retry
        var retryQueue = UserDefaults.standard.array(forKey: "health_retry_queue") as? [[[String: Any]]] ?? []
        retryQueue.append(observations)
        UserDefaults.standard.set(retryQueue, forKey: "health_retry_queue")
        logger.info("Stored \(observations.count) observations for retry")
    }
    
    private func cleanupOldHealthData() async {
        // Clean up old local data to prevent storage bloat
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        let oldBackupKeys = allKeys.filter { key in
            key.starts(with: "health_backup_") &&
            Date().timeIntervalSince1970 - (Double(key.replacingOccurrences(of: "health_backup_", with: "")) ?? 0) > 7 * 24 * 60 * 60
        }
        
        oldBackupKeys.forEach { userDefaults.removeObject(forKey: $0) }
        
        if !oldBackupKeys.isEmpty {
            logger.info("Cleaned up \(oldBackupKeys.count) old backup files")
        }
    }
    
    private func updateHealthInsights() async {
        // Update health insights based on latest data
        logger.info("Health insights updated")
    }
    
    // MARK: - Helper Functions
    
    private func observationsToDicts(_ observations: [HealthObservation]) -> [[String: Any]] {
        observations.map { obs in
            var dict: [String: Any] = [
                "id": obs.id,
                "date": obs.date.toISO8601String(),
                "type": obs.type.rawValue,
                "source": obs.source.rawValue
            ]
            switch obs.value {
            case .numeric(let value, let unit):
                dict["value"] = ["numeric": value, "unit": unit]
            case .range(let min, let max, let unit):
                dict["value"] = ["min": min, "max": max, "unit": unit]
            case .duration(let interval):
                dict["value"] = ["duration": interval]
            case .boolean(let bool):
                dict["value"] = ["boolean": bool]
            case .text(let text):
                dict["value"] = ["text": text]
            }
            if !obs.metadata.isEmpty { dict["metadata"] = obs.metadata }
            return dict
        }
    }

    private func getPreferredUnit(for quantityType: HKQuantityType) -> HKUnit {
        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return HKUnit.count()
        case HKQuantityTypeIdentifier.heartRate.rawValue,
             HKQuantityTypeIdentifier.restingHeartRate.rawValue,
             HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue:
            return HKUnit.count().unitDivided(by: HKUnit.minute())
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            return HKUnit.kilocalorie()
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return HKUnit.gramUnit(with: .kilo)
        case HKQuantityTypeIdentifier.height.rawValue:
            return HKUnit.meter()
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue,
             HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue:
            return HKUnit.millimeterOfMercury()
        default:
            return HKUnit.count()
        }
    }
    
    private func mapHealthKitToLOINC(_ identifier: String) -> String {
        // Map HealthKit identifiers to LOINC codes
        switch identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return "55423-8"
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            return "8867-4"
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return "29463-7"
        case HKQuantityTypeIdentifier.height.rawValue:
            return "8302-2"
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue:
            return "8480-6"
        case HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue:
            return "8462-4"
        case HKCategoryTypeIdentifier.sleepAnalysis.rawValue:
            return "93832-4"
        default:
            return identifier
        }
    }
    
    private func mapHealthKitIdentifierToType(_ identifier: String) -> String {
        switch identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return "steps"
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            return "heart_rate"
        case HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            return "resting_heart_rate"
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            return "calories"
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return "weight"
        case HKQuantityTypeIdentifier.height.rawValue:
            return "height"
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue:
            return "blood_pressure_systolic"
        case HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue:
            return "blood_pressure_diastolic"
        case HKCategoryTypeIdentifier.sleepAnalysis.rawValue:
            return "sleep"
        default:
            return "unknown"
        }
    }

    private func mapHealthKitIdentifierToObservationType(_ identifier: String) -> HealthObservation.ObservationType {
        switch identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return .steps
        case HKQuantityTypeIdentifier.heartRate.rawValue,
             HKQuantityTypeIdentifier.restingHeartRate.rawValue,
             HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue:
            return .heartRate
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            return .activeCalories
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return .weight
        case HKQuantityTypeIdentifier.height.rawValue:
            return .height
        case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue,
             HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue:
            return .bloodPressure
        case HKCategoryTypeIdentifier.sleepAnalysis.rawValue:
            return .sleep
        default:
            return .mood
        }
    }
    
    // MARK: - Public Interface
    
    public func requestBackgroundDeliveryPermission() async -> Bool {
        // Request permission for background delivery
        let typesToRead: Set<HKSampleType> = Set(backgroundDataTypes + [workoutType])
        
        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                if let error = error {
                    self.logger.error("Failed to request HealthKit authorization: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                } else {
                    self.logger.info("HealthKit authorization granted: \(success)")
                    if success {
                        self.setupBackgroundDelivery()
                    }
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    public func forceSync() async -> Bool {
        logger.info("Force sync requested")
        return await performBackgroundSync()
    }
    
    public func getLastSyncDate() -> Date? {
        return UserDefaults.standard.object(forKey: "lastHealthKitSync") as? Date
    }
    
    public func retryFailedUploads() async -> Bool {
        guard var retryQueue = UserDefaults.standard.array(forKey: "health_retry_queue") as? [[[String: Any]]],
              !retryQueue.isEmpty else {
            logger.debug("No failed uploads to retry")
            return true
        }
        
        logger.info("Retrying \(retryQueue.count) failed upload batches")
        
        var successCount = 0
        
        for (index, observations) in retryQueue.enumerated() {
            let success = await uploadHealthObservations(observations)
            if success {
                successCount += 1
                retryQueue.remove(at: index)
            }
        }
        
        // Update retry queue
        UserDefaults.standard.set(retryQueue, forKey: "health_retry_queue")
        
        logger.info("Successfully retried \(successCount) upload batches")
        return successCount > 0
    }
    
    private func uploadHealthObservations(_ observations: [[String: Any]]) async -> Bool {
        // Fallback adapter: convert dicts to observations with minimal mapping
        let mapped: [HealthObservation] = observations.compactMap { dict in
            guard let dateStr = dict["effectiveDateTime"] as? String,
                  let date = ISO8601DateFormatter().date(from: dateStr),
                  let typeStr = dict["type"] as? String else { return nil }
            let obsType = mapHealthKitIdentifierToObservationType(typeStr)
            let valueNum = (dict["value"] as? [String: Any])?["numeric"] as? Double ?? 0
            return HealthObservation(
                userId: "me",
                type: obsType,
                value: .numeric(valueNum, ""),
                date: date,
                source: .healthKit,
                metadata: [:]
            )
        }
        let manifest = HealthKitImportRequest.ImportManifest(
            startDate: mapped.map { $0.date }.min() ?? Date(),
            endDate: mapped.map { $0.date }.max() ?? Date(),
            dataTypes: [],
            recordCount: mapped.count
        )
        do {
            _ = try await HealthService.shared.importHealthKitData(HealthKitImportRequest(observations: mapped, manifest: manifest))
                .async()
            return true
        } catch {
            logger.error("Health observations import failed: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Extensions

private extension Date {
    func toISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}