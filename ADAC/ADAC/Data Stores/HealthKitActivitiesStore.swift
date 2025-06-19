// Licensed under the Any Distance Source-Available License
//
//  HealthKitActivitiesStore.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/22/22.
//

import UIKit
import Foundation
import HealthKit
import Sentry
import UserNotifications
import Combine
import CoreLocation

extension HKHealthStore {
    func statisticsCollection(for quantityType: HKQuantityType,
                              quantitySamplePredicate: NSPredicate?,
                              options: HKStatisticsOptions,
                              anchorDate: Date,
                              intervalComponents: DateComponents) async throws -> HKStatisticsCollection? {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                    quantitySamplePredicate: quantitySamplePredicate,
                                                    options: options,
                                                    anchorDate: anchorDate,
                                                    intervalComponents: intervalComponents)
            
            query.initialResultsHandler = { (_, statisticsCollection, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: statisticsCollection)
                }
            }
            
            execute(query)
        }
    }
}

class HealthKitActivitiesStore: ActivitiesProviderStore {
    
    static let shared = HealthKitActivitiesStore()
    
    private let store = HKHealthStore()
    
    private var hasStartedObservingNewActivities = false
    
    let activitySynced: AnyPublisher<Activity, Never>
    var daysToSync: Int = 365
    private var activitySyncedValue = PassthroughSubject<Activity, Never>()
    
    private init() {
        activitySynced = activitySyncedValue.eraseToAnyPublisher()
    }
    
    private var workoutPredicate: NSPredicate {
        let allTypes = (1...80).compactMap { HKWorkoutActivityType(rawValue: $0) }
        let queriesForTypes = allTypes.map { HKQuery.predicateForWorkouts(with: $0) } + [HKQuery.predicateForWorkouts(with: .other)]
        return NSCompoundPredicate(orPredicateWithSubpredicates: queriesForTypes)
    }
    
    func isAuthorizedForAllTypes() async throws -> Bool {
        let typesToShare: Set<HKSampleType> = Set([
            HKSampleType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)!,
            HKObjectType.quantityType(forIdentifier: .distanceWheelchair)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        ])

        let typesToRead = Set([
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
            HKObjectType.activitySummaryType(),
            HKSampleType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)!,
            HKObjectType.quantityType(forIdentifier: .distanceWheelchair)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        ])

        let authorized: Bool = try await withCheckedThrowingContinuation { continuation in
            store.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
                UserDefaults.standard.hasAskedForHealthKitReadPermission = true
                UserDefaults.standard.hasAskedForHealthKitRingsPermission = true
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
        
        return authorized
    }

    func hasRequestedAuthorization() -> Bool {
        return isAuthorizedToShare() || UserDefaults.standard.hasAskedForHealthKitReadPermission
    }

    func hasRequestedRingsAuthorization() -> Bool {
        return UserDefaults.standard.hasAskedForHealthKitRingsPermission
    }

    func isAuthorizedToShare() -> Bool {
        let types: Set<HKSampleType> = Set([HKSampleType.workoutType(),
                                            HKSeriesType.workoutRoute(),
                                            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
                                            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                                            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
                                            HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)!,
                                            HKObjectType.quantityType(forIdentifier: .distanceWheelchair)!,
                                            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
                                            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                                            HKQuantityType.quantityType(forIdentifier: .bodyMass)!])
        for type in types {
            if store.authorizationStatus(for: type) != .sharingAuthorized {
                return false
            }
        }

        return true
    }

    func requestAuthorization(with analyticsScreenName: String, onSuccess: (() -> Void)? = nil) {
        let split = NSUbiquitousKeyValueStore.default.split(for: AndiHealthAuth.self)
        split.sendAnalytics()
        switch split {
        case .showAndi:
            Analytics.logEvent("Connect with Health (Andi)", analyticsScreenName, .buttonTap)
            let permissionsVC = AndiAppleHealthPermissionsViewController()
            permissionsVC.nextAction = {
                UIApplication.shared.topViewController?.dismiss(animated: true) {
                    self.linkWithAppleHealth(with: analyticsScreenName, onSuccess: onSuccess)
                }
            }
            UIApplication.shared.topViewController?.present(permissionsVC, animated: true)
        case .showOldHealthAuth:
            Analytics.logEvent("Connect with Health", analyticsScreenName, .buttonTap)
            let permissionsVC = AppleHealthPermissionsViewController()
            permissionsVC.nextAction = {
                UIApplication.shared.topViewController?.dismiss(animated: false) {
                    self.linkWithAppleHealth(with: analyticsScreenName, onSuccess: onSuccess)
                }
            }
            permissionsVC.modalPresentationStyle = .overFullScreen
            UIApplication.shared.topViewController?.present(permissionsVC, animated: false)
        }
    }

    private func linkWithAppleHealth(with analyticsScreenName: String, onSuccess: (() -> Void)?) {
        Analytics.logEvent("Alert Next", analyticsScreenName, .buttonTap)
        Task {
            do {
                let _ = try await HealthKitActivitiesStore.shared.isAuthorizedForAllTypes()
                if !HealthKitActivitiesStore.shared.isAuthorizedToShare() {
                    showAppleHealthSettingsAlert(with: analyticsScreenName)
                    return
                }
            } catch {
                showAppleHealthSettingsAlert(with: analyticsScreenName)
            }

            Analytics.logEvent("Health linked successfully", analyticsScreenName, .otherEvent)
            DispatchQueue.main.async {
                ReloadPublishers.healthKitAuthorizationChanged.send()
            }
            onSuccess?()
        }
    }

    private func showAppleHealthSettingsAlert(with analyticsScreenName: String) {
        Analytics.logEvent("Error linking health", analyticsScreenName, .otherEvent)
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Apple Health Error",
                                          message: "To continue, authorize Apple Health in Settings. Open the Settings app and tap \"Health\" -> \"Data Access & Devices\" -> \"Any Distance\" -> \"Turn All Categories On\"",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            UIApplication.shared.topViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    func loadLatestActivity() async -> Activity? {
        guard hasRequestedAuthorization() else {
            return nil
        }
        
        let activity: Activity? = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: [])
            let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [workoutPredicate, datePredicate])
            let query = HKSampleQuery.init(sampleType: .workoutType(),
                                           predicate: combinedPredicate,
                                           limit: 1,
                                           sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                if let samples = samples as? [HKWorkout],
                   error == nil {
                    continuation.resume(returning: samples.last)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            store.execute(query)
        }
        
        return activity
    }
    
    func load() async throws -> [Activity] {
        guard hasRequestedAuthorization() else {
            return []
        }

        let activities: [Activity] = try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let startDate = Calendar.current.date(byAdding: .day, value: -1 * daysToSync, to: Date())
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: [])
            let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [workoutPredicate, datePredicate])
            let query = HKSampleQuery.init(sampleType: .workoutType(),
                                           predicate: combinedPredicate,
                                           limit: HKObjectQueryNoLimit,
                                           sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                if let samples = samples as? [HKWorkout],
                   error == nil {
                    continuation.resume(returning: samples)
                } else if let error = error {
                    continuation.resume(throwing: error)
                }
            }
            
            store.execute(query)
        }
        
        // TODO: move this somewhere else
        fetchLatestBodyMassSample()
        
        return activities
    }

    func getActivities(with activityType: ActivityType, 
                       startDate: Date,
                       endDate: Date) async throws -> [Activity] {
        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
            let activityTypePredicate = HKQuery.predicateForWorkouts(with: activityType.hkWorkoutType)
            let combinedPredicate: NSCompoundPredicate = {
                if activityType.isADCustom {
                    let metadataPredicate = HKQuery.predicateForObjects(withMetadataKey: ADMetadataKey.activityType, allowedValues: [activityType.rawValue])
                    return NSCompoundPredicate(andPredicateWithSubpredicates: [activityTypePredicate, metadataPredicate, datePredicate])
                }

                return NSCompoundPredicate(andPredicateWithSubpredicates: [activityTypePredicate, datePredicate])
            }()
            let query = HKSampleQuery.init(sampleType: .workoutType(),
                                           predicate: combinedPredicate,
                                           limit: HKObjectQueryNoLimit,
                                           sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                if let samples = samples as? [HKWorkout],
                   error == nil {
                    continuation.resume(returning: samples)
                } else if let error = error {
                    continuation.resume(throwing: error)
                }
            }

            store.execute(query)
        }
    }

    func getHistoricalData(for activities: [Activity],
                           startDate: Date,
                           endDate: Date,
                           fields: [PartialKeyPath<Activity>]) async throws -> [PartialKeyPath<Activity>: [Float]] {
        var data: [PartialKeyPath<Activity>: [Float]] = [:]
        var curStartDate = startDate
        let gmt = TimeZone(identifier: "GMT")!
        curStartDate = startDate.convertFromTimeZone(.current, toTimeZone: gmt)
        var endDate = endDate.convertFromTimeZone(.current, toTimeZone: gmt)

        func appendZeroToAllFields() {
            for field in fields {
                if data[field] != nil {
                    data[field]?.append(0.0)
                } else {
                    data[field] = [0.0]
                }
            }
        }

        while curStartDate < endDate {
            guard let curEndDate = Calendar.current.date(byAdding: .day, value: 1, to: curStartDate) else {
                curStartDate = Calendar.current.date(byAdding: .day, value: 1, to: curStartDate) ?? endDate
                appendZeroToAllFields()
                continue
            }

            guard let startIdx = activities.firstIndex(where: { $0.startDate >= curStartDate }),
                  let endIdx = activities.firstIndex(where: { $0.startDate > curEndDate }) else {
                curStartDate = Calendar.current.date(byAdding: .day, value: 1, to: curStartDate) ?? endDate
                appendZeroToAllFields()
                continue
            }

            let activitiesWithinDate = activities[startIdx..<endIdx]

            for field in fields {
                let fieldValues: [Float] = activitiesWithinDate.map { $0[keyPath: field] as? Float ?? Float($0[keyPath: field] as? Double ?? 0.0) }
                let fieldValuesAggregate: Float = {
                    if field == \.paceInUserSelectedUnit || 
                       field == \.averageSpeedInUserSelectedUnit {
                        return fieldValues.avg()
                    }
                    return fieldValues.sum()
                }()

                if data[field] != nil {
                    data[field]?.append(fieldValuesAggregate)
                } else {
                    data[field] = [fieldValuesAggregate]
                }
            }

            curStartDate = Calendar.current.date(byAdding: .day, value: 1, to: curStartDate) ?? endDate
        }

        return data
    }

    func getHistoricalData(for goal: Goal,
                           field: PartialKeyPath<Activity>) async throws -> (weeklyAvg: Float, data: [Float]) {
        let startDate = goal.startDate
        let endDate = Date()
        var activities = ActivitiesData.shared.activities
            .map { $0.activity }
            .filter { goal.matches($0) }
            .sorted(by: { $0.startDateLocal < $1.startDateLocal })

        var data: [Float] = []
        var cumSum: Float = 0.0
        var curStartDate = startDate

        let numDays: Float = Float(endDate.timeIntervalSince(startDate) / 86400.0)
        var total: Float = 0.0

        while curStartDate < endDate {
            guard let curEndDate = Calendar.current.date(byAdding: .day, value: 1, to: curStartDate) else {
                data.append(cumSum)
                curStartDate = Calendar.current.date(byAdding: .day, value: 1, to: curStartDate) ?? endDate
                continue
            }

            let endIdx = activities.firstIndex(where: { $0.startDateLocal > curEndDate }) ?? activities.count
            let activitiesWithinDate = Array(activities[0..<endIdx])
            activities.removeFirst(endIdx)

            let fieldValues: [Float] = activitiesWithinDate.map { ($0[keyPath: field] as? Float ?? 0.0) }
            let fieldValuesSum = fieldValues.sum()
            data.append(cumSum + fieldValuesSum)
            cumSum += fieldValuesSum
            total += fieldValuesSum

            curStartDate = Calendar.current.date(byAdding: .day, value: 1, to: curStartDate) ?? endDate
        }
        let weeklyAvg = (total / (numDays / 7.0))

        return (weeklyAvg: weeklyAvg, data: data)
    }

    func getRouteData(for activities: [Activity]) async throws -> [[CLLocationCoordinate2D]] {
        return await withTaskGroup(of: [CLLocationCoordinate2D].self) { group in
            for activity in activities {
                group.addTask {
                    let locations = (try? await activity.coordinates.map { $0.coordinate }) ?? []
                    let s = max(1, locations.count / 600)
                    let simplifiedCoords = stride(from: 0, to: locations.count - 1, by: s).map { locations[$0] }
                    return simplifiedCoords
                }
            }

            var allCoords = [[CLLocationCoordinate2D]]()
            for await coords in group {
                allCoords.append(coords)
            }

            return allCoords
        }
    }

    func hkWorkout(withId id: String) async throws -> HKWorkout {
        guard let uuidString = id.components(separatedBy: "_").last,
              let uuid = UUID(uuidString: uuidString) else {
            throw HealthKitActivitiesStoreError.invalidId
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObject(with: uuid)
            let query = HKSampleQuery.init(sampleType: .workoutType(),
                                           predicate: predicate,
                                           limit: 1,
                                           sortDescriptors: nil) { query, samples, error in
                if let samples = samples as? [HKWorkout],
                   let first = samples.first,
                   error == nil {
                    continuation.resume(returning: first)
                } else if let error = error {
                    continuation.resume(throwing: error)
                }
            }
            
            store.execute(query)
        }
    }

    func deleteWorkout(_ workout: HKWorkout) async throws {
        try await store.delete(workout)
    }
    
    func loadDailySteps() async throws -> [Activity] {
        guard isAuthorizedToShare() else {
            return []
        }

        guard try await isAuthorizedForAllTypes(),
              NSUbiquitousKeyValueStore.default.shouldShowStepCount else {
            return []
        }
        
        // TODO: This takes a really long time
        return try await dailyStepCounts()
    }
    
    private func fetchLatestBodyMassSample() {
        guard isAuthorizedToShare() else {
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let bodyMassType = HKSampleType.quantityType(forIdentifier: .bodyMass)!
        
        let query = HKSampleQuery(sampleType: bodyMassType,
                                  predicate: nil,
                                  limit: 1,
                                  sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            if let sample = samples?.first as? HKQuantitySample {
                NSUbiquitousKeyValueStore.default.bodyMassKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                print("Updated body mass to \(NSUbiquitousKeyValueStore.default.bodyMassKg)")
            }
        }
        
        store.execute(query)
    }
    
    func writeBodyMass(_ value: Double, unit: MassUnit) async throws {
        let bodyMassType = HKSampleType.quantityType(forIdentifier: .bodyMass)!
        let valueKg = UnitConverter.value(value, fromUnit: unit, toUnit: .kilograms)
        NSUbiquitousKeyValueStore.default.bodyMassKg = valueKg
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: valueKg)
        let sample = HKQuantitySample(type: bodyMassType, quantity: quantity, start: Date(), end: Date())
        try await store.save(sample)
    }
    
    func currentBodyMass(in unit: MassUnit) -> Double {
        let bodyMassKg = NSUbiquitousKeyValueStore.default.bodyMassKg
        return UnitConverter.value(bodyMassKg, fromUnit: .kilograms, toUnit: unit)
    }
}

// MARK: - Daily Step Counts

extension HealthKitActivitiesStore {
    
    private func dailyStepCounts() async throws -> [DailyStepCount] {
        let interval = DateComponents(day: 1)
        let anchorDate = Calendar.current.startOfDay(for: Date())
        
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            fatalError("*** Unable to create a step count type ***")
        }

        let startDate = Calendar.current.date(byAdding: .day, value: -1 * daysToSync, to: Date())
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: [])

        let statisticCollections = try await store.statisticsCollection(for: quantityType,
                                                                        quantitySamplePredicate: datePredicate,
                                                                        options: .cumulativeSum,
                                                                        anchorDate: anchorDate,
                                                                        intervalComponents: interval)
        guard let statisticCollections = statisticCollections else {
            return []
        }
        
        let stepCounts: [DailyStepCount] = statisticCollections.statistics().map { statistic in
            guard let quantity = statistic.sumQuantity() else { return nil }
            let startDate = statistic.startDate
            let endDate = statistic.endDate
            let value = Int(quantity.doubleValue(for: .count()))
            let stepCount = DailyStepCount(startDate: startDate,
                                           endDate: endDate,
                                           timezone: .current,
                                           count: value)
            return stepCount
        }.compactMap({ $0 })
        
        return stepCounts
    }
}

enum HealthKitActivitiesStoreError: Error {
    case invalidId
    case notAuthorized
}

// MARK: - Push Notifications

extension HealthKitActivitiesStore {
    func startObservingNewActivities() async {
        guard !hasStartedObservingNewActivities && ADUser.current.hasFinishedOnboarding else { return }
        
        hasStartedObservingNewActivities = true
        
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let authorizedNotifications = settings.authorizationStatus == .authorized
        
        if !NSUbiquitousKeyValueStore.default.hasSetNotificationsOn {
            NSUbiquitousKeyValueStore.default.activityShareReminderNotificationsOn = authorizedNotifications
        }
        
        guard authorizedNotifications, NSUbiquitousKeyValueStore.default.activityShareReminderNotificationsOn else { return }
        
        let sampleType = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: sampleType,
                                    predicate: workoutPredicate,
                                    updateHandler: activityAddedHandler)
        store.execute(query)

        do {
            try await store.enableBackgroundDelivery(for: sampleType, frequency: .immediate)
        } catch {
            SentrySDK.capture(error: error)
        }
    }

    private func activityAddedHandler(query: HKObserverQuery, completionHandler: @escaping HKObserverQueryCompletionHandler, error: Error?) {
        Task {
            guard let lastHealthKitActivity = await HealthKitActivitiesStore.shared.loadLatestActivity(),
                  lastHealthKitActivity.activityType != .unknown,
                  lastHealthKitActivity.activityType != .other else {
                completionHandler()
                return
            }
            
            // synced
            activitySyncedValue.send(lastHealthKitActivity)
            print("Activity synced with id: \(lastHealthKitActivity.id)")
            
            guard NSUbiquitousKeyValueStore.default.activityShareReminderNotificationsOn else {
                completionHandler()
                return
            }
            
            guard lastHealthKitActivity.activityType != .stepCount else {
                completionHandler()
                return
            }
            
            let lastNotificationDate = UserDefaults.standard.lastNotificationDate

            guard lastHealthKitActivity.startDate > lastNotificationDate else {
                completionHandler()
                return
            }

            UserDefaults.standard.lastNotificationDate = Date()
        
            // only send notifications if the app is backgrounded
            guard await UIApplication.shared.applicationState != .active else {
                completionHandler()
                return
            }

            let content = UNMutableNotificationContent()
            if lastHealthKitActivity.activityType.isDistanceBased {
                content.title = "\(lastHealthKitActivity.distanceInUserSelectedUnit.rounded(toPlaces: 1))\(ADUser.current.distanceUnit.abbreviation) \(lastHealthKitActivity.activityType.displayName.lowercased()) synced! 📲"
            } else {
                let movingTime = lastHealthKitActivity.movingTime
                let hours = Int(movingTime) / 3600
                let minutes = (Int(movingTime) / 60) % 60
                var str = ""
                if hours > 0 {
                    str += "\(hours)hr "
                }
                str += "\(minutes)min"

                content.title = "\(str) \(lastHealthKitActivity.activityType.displayName.lowercased()) synced! 📲"
            }

            content.body = "Nice job! Tap to view your activity analysis."
            content.userInfo = ["activityId": lastHealthKitActivity.id]
            let request = UNNotificationRequest(identifier: lastHealthKitActivity.id,
                                                content: content,
                                                trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            
            Analytics.logEvent("Activity Notification Sent", "Activity Notification", .otherEvent)
            
            completionHandler()
        }
    }

}

fileprivate extension UserDefaults {
    var lastNotificationDate: Date {
        get {
            if object(forKey: "lastNotificationDate") == nil {
                let initialDate = Date()
                set(initialDate.timeIntervalSince1970, forKey: "lastNotificationDate")
                return initialDate
            }

            return Date(timeIntervalSince1970: double(forKey: "lastNotificationDate"))
        }

        set {
            set(newValue.timeIntervalSince1970, forKey: "lastNotificationDate")
        }
    }

    var hasAskedForHealthKitReadPermission: Bool {
        get {
            return bool(forKey: "hasAskedForHealthKitReadPermission")
        }

        set {
            set(newValue, forKey: "hasAskedForHealthKitReadPermission")
        }
    }

    var hasAskedForHealthKitRingsPermission: Bool {
        get {
            return bool(forKey: "hasAskedForHealthKitRingsPermission")
        }

        set {
            set(newValue, forKey: "hasAskedForHealthKitRingsPermission")
        }
    }
}

public extension NSUbiquitousKeyValueStore {
    var bodyMassKg: Double {
        get {
            if object(forKey: "bodyMassKg") == nil {
                return 75.0
            }
            return double(forKey: "bodyMassKg")
        }
        
        set {
            set(newValue, forKey: "bodyMassKg")
        }
    }
    
    func writeDefaultBodyMass() {
        bodyMassKg = 75.0
    }
    
    var hasSetBodyMass: Bool {
        return object(forKey: "bodyMassKg") != nil
    }
}
