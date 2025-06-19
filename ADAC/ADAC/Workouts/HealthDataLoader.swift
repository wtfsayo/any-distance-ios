// Licensed under the Any Distance Source-Available License
//
//  HealthDataLoader.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/12/21.
//

import NotificationCenter
import HealthKit
import CoreLocation
import OAuthSwift

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

final class HealthDataLoader {

    static let shared = HealthDataLoader()

    private let store = HKHealthStore()

    private var workoutPredicate: NSPredicate {
        return NSCompoundPredicate(orPredicateWithSubpredicates: [HKQuery.predicateForWorkouts(with: .running),
                                                                  HKQuery.predicateForWorkouts(with: .cycling),
                                                                  HKQuery.predicateForWorkouts(with: .walking),
                                                                  HKQuery.predicateForWorkouts(with: .hiking),
                                                                  HKQuery.predicateForWorkouts(with: .elliptical),
                                                                  HKQuery.predicateForWorkouts(with: .downhillSkiing),
                                                                  HKQuery.predicateForWorkouts(with: .crossCountrySkiing),
                                                                  HKQuery.predicateForWorkouts(with: .snowboarding),
                                                                  HKQuery.predicateForWorkouts(with: .paddleSports),
                                                                  HKQuery.predicateForWorkouts(with: .wheelchairRunPace),
                                                                  HKQuery.predicateForWorkouts(with: .wheelchairWalkPace),
                                                                  HKQuery.predicateForWorkouts(with: .traditionalStrengthTraining),
                                                                  HKQuery.predicateForWorkouts(with: .functionalStrengthTraining),
                                                                  HKQuery.predicateForWorkouts(with: .swimming),
                                                                  HKQuery.predicateForWorkouts(with: .coreTraining),
                                                                  HKQuery.predicateForWorkouts(with: .pilates),
                                                                  HKQuery.predicateForWorkouts(with: .yoga),
                                                                  HKQuery.predicateForWorkouts(with: .highIntensityIntervalTraining),
                                                                  HKQuery.predicateForWorkouts(with: .kickboxing)])
    }

    func requestHealthKitAuthorization() async throws -> Bool {
        let typesToRead: Set<HKObjectType> = Set([HKObjectType.workoutType(),
                                                  HKSeriesType.workoutRoute(),
                                                  HKQuantityType.quantityType(forIdentifier: .heartRate)!,
                                                  HKQuantityType.quantityType(forIdentifier: .stepCount)!,
                                                  HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                                                  HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!])
        
        let hasAuthorization: Bool = try await withCheckedThrowingContinuation { continuation in
            store.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
        
        if hasAuthorization {
            startObservingNewActivities()
        }
        
        return hasAuthorization
    }

    func loadActivitiesAndStepCounts(_ completion: @escaping () -> Void) {
        Task {
            do {
                let authorized = try await requestHealthKitAuthorization()
                
                if authorized {
                    // activities
                    let lastActivitiesRefreshDate = UserDefaults.standard.lastActivitiesRefreshDate
                    async let appleHealthActivities = loadAppleHealthActivities()
                    var allActivities = [Activity]()
                    let wahooActivityLoader = WahooActivityLoader.shared
                    do {
                        let wahooActivities = try await wahooActivityLoader.getActivities()
                        let activities = wahooActivities
                            .map { Activity(with: $0) }
                            .filter { $0.activityType != .unknown }
                        allActivities.append(contentsOf: activities)
                    } catch let DecodingError.dataCorrupted(context) {
                        print("Failed loading Wahoo activities: \(context)")
                    } catch let DecodingError.keyNotFound(key, context) {
                        print("Failed loading Wahoo activities, key '\(key)' not found:", context.debugDescription)
                        print("codingPath:", context.codingPath)
                    } catch let DecodingError.valueNotFound(value, context) {
                        print("Failed loading Wahoo activities, value '\(value)' not found:", context.debugDescription)
                        print("codingPath:", context.codingPath)
                    } catch let DecodingError.typeMismatch(type, context)  {
                        print("Failed loading Wahoo activities, type '\(type)' mismatch:", context.debugDescription)
                        print("codingPath:", context.codingPath)
                    } catch {
                        print("Failed loading Wahoo activities: ", error)
                    }
                    allActivities.append(contentsOf: try await appleHealthActivities)
                    
                    // TODO: do this somewhere else
                    for activity in allActivities {
                        ActivityCache.cacheActivity(activity)

                        if let startDate = activity.startDate,
                           let lastRefresh = lastActivitiesRefreshDate,
                           startDate > lastRefresh {
                            // Send up new activities since the last activities refresh date
                            Analytics.logEvent("Activity Synced", "Activity Synced", .otherEvent,
                                               withParameters: ["sourceBundleId" : activity.shortenedSourceBundleId,
                                                                "activityType" : activity.activityType?.rawValue ?? "",
                                                                "activeCalories" : activity.activeCalories ?? 0,
                                                                "distanceMeters" : activity.distance ?? 0,
                                                                "date" : activity.startDate ?? Date()])
                        }
                    }
                    ActivityCache.removeDuplicatesByDate()
                    
                    let stepCounts = try await dailyStepCounts()
                    for stepCount in stepCounts {
                        await StepCountCache.cacheStepCount(stepCount)
                    }

                    let startOfToday = Calendar.current.startOfDay(for: Date())
                    let lastSendDate = UserDefaults.standard.lastStepCountEventSendDate ?? Date(timeIntervalSince1970: 0)
                    for stepCount in stepCounts where stepCount.date > lastSendDate && stepCount.date < startOfToday {
                        // Send up step counts after the last sync date and before today (because step count updates
                        // throughout the day and we want the final figure).
                        Analytics.logEvent("Step Count Synced", "Step Count Synced", .otherEvent,
                                           withParameters: ["stepCount" : stepCount.count,
                                                            "distanceMeters" : stepCount.distanceMeters ?? 0,
                                                            "date" : stepCount.date])
                    }
                    UserDefaults.standard.lastStepCountEventSendDate = Calendar.current.date(byAdding: .day,
                                                                                             value: -1,
                                                                                             to: startOfToday)
                }
            } catch {
                if let error = error as? HKError {
                    switch (error.code) {
                    case .errorDatabaseInaccessible:
                        // HealthKit couldn't access the database because the device is locked.
                        print("Error querying step count. Device locked.")
                        return
                    default:
                        print(error.localizedDescription)
                        return
                    }
                } else {
                    print("Error loading activities: \(error.localizedDescription)")
                }
            }
            
            completion()
        }
    }

    // MARK: - Activities

    private func loadAppleHealthActivities() async throws -> [Activity] {
        guard ADUser.current.hasLinkedAppleHealth else {
            return []
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let daysToSync = ADUser.current.daysOfActivitiesToSync ?? 30

        var lastRefreshMinus7Days: Date? {
            if let lastRefresh = UserDefaults.standard.lastActivitiesRefreshDate {
                return Calendar.current.date(byAdding: DateComponents(day: -7), to: lastRefresh)
            }

            return nil
        }

        let startDate = lastRefreshMinus7Days ??
                        ADUser.current.stravaRetireDate ??
                        Calendar.current.date(byAdding: DateComponents(day: -1 * daysToSync), to: Date())
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: [])
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [workoutPredicate, datePredicate])

        let activities: [Activity] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery.init(sampleType: .workoutType(),
                                           predicate: combinedPredicate,
                                           limit: 1000,
                                           sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                if let samples = samples as? [HKWorkout],
                   error == nil {
                    UserDefaults.standard.lastActivitiesRefreshDate = samples.first?.startDate
                    
                    let activities = samples.map { Activity($0) }
                    continuation.resume(returning: activities)
                } else if let error = error {
                    continuation.resume(throwing: error)
                }
            }

            store.execute(query)
        }

        return activities
    }

    func getActivity(withUUID uuid: UUID, completion: @escaping (HKWorkout?) -> Void) {
        let predicate = HKQuery.predicateForObject(with: uuid)
        let query = HKSampleQuery.init(sampleType: .workoutType(),
                                       predicate: predicate,
                                       limit: 0,
                                       sortDescriptors: nil) { (query, samples, error) in
            DispatchQueue.main.sync {
                guard let samples = samples as? [HKWorkout],
                      !samples.isEmpty,
                      error == nil else {
                    print(error?.localizedDescription as Any)
                    completion(nil)
                    return
                }

                completion(samples.first)
            }
        }

        store.execute(query)
    }

    func getCoordinates(forWorkout workout: HKWorkout, completion: @escaping ((_ coords: [CLLocation]?) -> Void)) {
        let runningObjectQuery = HKQuery.predicateForObjects(from: workout)
        let routeQuery = HKAnchoredObjectQuery(type: HKSeriesType.workoutRoute(),
                                               predicate: runningObjectQuery,
                                               anchor: nil,
                                               limit: HKObjectQueryNoLimit) { (query, samples, deletedObjects, anchor, error) in
            guard error == nil else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            if let samples = samples as? [HKWorkoutRoute],
               !samples.isEmpty {
                var coords: [CLLocation] = []

                var routeCount: Int = 0
                for route in samples {
                    self.queryRouteLocations(route) { routeCoords in
                        routeCount += 1
                        coords.append(contentsOf: routeCoords)

                        if routeCount == samples.count {
                            DispatchQueue.main.async {
                                completion(coords)
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }

        store.execute(routeQuery)
    }

    private func queryRouteLocations(_ route: HKWorkoutRoute, _ completion: @escaping ([CLLocation]) -> Void) {
        var coords: [CLLocation] = []

        let query = HKWorkoutRouteQuery(route: route) { (query, locationsOrNil, done, errorOrNil) in
            if let error = errorOrNil {
                print(error.localizedDescription)
                completion([])
                return
            }

            guard let locations = locationsOrNil else {
                completion([])
                return
            }

            coords.append(contentsOf: locations)

            if done {
                completion(coords)
            }
        }

        store.execute(query)
    }

    func getHeartRateData(forWorkout workout: HKWorkout, completion: @escaping ((_ heartRates: [HeartRateSample]?) -> Void)) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil)
            return
        }

        let seconds = Int(workout.duration / HeartRateGraphGenerator.numberOfSamplesRequired())
        let interval = DateComponents(second: seconds)
        let hrQuery = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                  quantitySamplePredicate: nil,
                                                  options: [.discreteMin, .discreteMax, .discreteAverage],
                                                  anchorDate: workout.startDate,
                                                  intervalComponents: interval)

        var heartRates: [HeartRateSample] = []
        hrQuery.initialResultsHandler = { query, results, error in
            if let error = error as? HKError {
                print(error.localizedDescription)
            }

            guard let statsCollection = results else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            statsCollection.enumerateStatistics(from: workout.startDate, to: workout.endDate) { statistics, stop in
                if let min = statistics.minimumQuantity(),
                   let max = statistics.maximumQuantity(),
                   let avg = statistics.averageQuantity() {
                    let sample = HeartRateSample(minimumBpm: min.doubleValue(for: .count().unitDivided(by: .minute())),
                                                 averageBpm: avg.doubleValue(for: .count().unitDivided(by: .minute())),
                                                 maximumBpm: max.doubleValue(for: .count().unitDivided(by: .minute())),
                                                 startDate: statistics.startDate,
                                                 endDate: statistics.endDate)
                    heartRates.append(sample)
                }
            }

            DispatchQueue.main.async {
                completion(heartRates)
            }
        }

        store.execute(hrQuery)
    }

    // MARK: - Step Count

    private func dailyStepCounts() async throws -> [DailyStepCount] {
        let interval = DateComponents(day: 1)
        let anchorDate = Calendar.current.startOfDay(for: Date())

        guard let quantityType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            fatalError("*** Unable to create a step count type ***")
        }

        let statisticCollections = try await store.statisticsCollection(for: quantityType,
                                                              quantitySamplePredicate: nil,
                                                              options: .cumulativeSum,
                                                              anchorDate: anchorDate,
                                                              intervalComponents: interval)
                
        var stepCounts: [DailyStepCount] = []

        let startOfToday = Calendar.current.startOfDay(for: Date())
        if let statisticCollections = statisticCollections {
            guard let startDate = Calendar.current.date(byAdding: DateComponents(day: -30),
                                                        to: startOfToday) else {
                return []
            }
            let endDate = Date()

            stepCounts = dailySteps(from: statisticCollections, startDate: startDate, endDate: endDate)
            
            for stepCount in stepCounts {
                let distanceInSelectedUnit = await stepCount.getDistanceInUserSelectedUnit() ?? 0
                let distanceMeters = UnitConverter.value(distanceInSelectedUnit, inUnitToMeters: ADUser.current.goalUnit ?? .miles)
                stepCount.distanceMeters = distanceMeters
            }
        }
        
        return stepCounts
    }
    
    private func dailySteps(from statisticsCollection: HKStatisticsCollection, startDate: Date, endDate: Date) -> [DailyStepCount] {
        var stepCounts: [DailyStepCount] = []
        statisticsCollection.enumerateStatistics(from: startDate, to: endDate) { (statistics, _) in
            if let quantity = statistics.sumQuantity() {
                let date = statistics.startDate
                let value = Int(quantity.doubleValue(for: .count()))
                
                let stepCount = DailyStepCount(date: date, timezone: .current, count: value)
                stepCounts.append(stepCount)
            }
        }
        return stepCounts
    }

    func getDistance(forDate date: Date) async throws -> Float? {
        guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return nil
        }

        let startDate = Calendar.current.startOfDay(for: date)
        let endDate = Calendar.current.date(byAdding: DateComponents(day: 1), to: startDate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        let distance: Float? = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: distanceType,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { (query, statistics, error) in
                guard let statistics = statistics else {
                    continuation.resume(returning: nil)
                    return
                }

                if let distance = statistics.sumQuantity()?.doubleValue(for: .meter()) {
                    continuation.resume(returning: Float(distance))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            store.execute(query)
        }
                
        return distance
    }

    func getHalfHourlyStepCounts(forDate date: Date,
                                 completion: @escaping (_ stepCountsByHalfHour: [Int]) -> Void) {
        let interval = DateComponents(minute: 30)
        let anchorDate = Calendar.current.startOfDay(for: Date())

        guard let quantityType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            fatalError("*** Unable to create a step count type ***")
        }

        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: nil,
                                                options: .cumulativeSum,
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)

        var stepCounts: [Int] = []
        query.initialResultsHandler = { query, results, error in
            // Handle errors here.
            if let error = error as? HKError {
                switch (error.code) {
                case .errorDatabaseInaccessible:
                    // HealthKit couldn't access the database because the device is locked.
                    print("Error querying step count. Device locked.")
                    return
                default:
                    print(error.localizedDescription)
                    return
                }
            }

            guard let statsCollection = results else {
                // You should only hit this case if you have an unhandled error. Check for bugs
                // in your code that creates the query, or explicitly handle the error.
                return
            }

            let startDate = Calendar.current.startOfDay(for: date)
            let endDate = Calendar.current.date(byAdding: DateComponents(day: 1), to: startDate)!

            statsCollection.enumerateStatistics(from: startDate, to: endDate) { (statistics, stop) in
                if let quantity = statistics.sumQuantity() {
                    let value = Int(quantity.doubleValue(for: .count()))
                    stepCounts.append(value)
                } else {
                    stepCounts.append(0)
                }
            }

            DispatchQueue.main.async {
                completion(stepCounts)
            }
        }

        store.execute(query)
    }

    // MARK: - Observing Workouts for Notifications

    func startObservingNewActivities() {
        func startObserving() {
            let sampleType = HKObjectType.workoutType()
            let query: HKObserverQuery = HKObserverQuery(sampleType: sampleType,
                                                         predicate: workoutPredicate,
                                                         updateHandler: self.activityAddedHandler)

            store.execute(query)
            store.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { (success, error) in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    print("Started listening for new activities in the background.")
                }
            }
        }

        if !UserDefaults.standard.hasSetNotificationsOn {
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                UserDefaults.standard.notificationsOn = (settings.authorizationStatus == .authorized)
                startObserving()
            }
        } else {
            startObserving()
        }
    }

    func activityAddedHandler(query: HKObserverQuery, completionHandler: @escaping HKObserverQueryCompletionHandler, error: Error?) {
        guard UserDefaults.standard.notificationsOn,
              Date().timeIntervalSince(UserDefaults.standard.lastNotificationDate) > 600 else {
            completionHandler()
            return
        }

        UserDefaults.standard.lastNotificationDate = Date()

        let count = ActivityCache.allActivities().count
        
        Task {
            do {
                let activities = try await loadAppleHealthActivities()
                
                guard activities.count > count else {
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = "Activity synced! 💪📲"
                content.body = "Open Any Distance to share it."

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

                Analytics.logEvent("Workout Notification Sent", "Workout Notification", .otherEvent)

                completionHandler()
            } catch {
                print("Error adding Activity: \(error)")
            }
        }
    }
}
