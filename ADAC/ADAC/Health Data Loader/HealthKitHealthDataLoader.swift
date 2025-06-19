// Licensed under the Any Distance Source-Available License
//
//  HealthKitHealthDataLoader.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/20/22.
//

import Foundation
import HealthKit
import CoreLocation
import CoreGraphics

enum HealthKitHealthDataLoaderError: Error {
    case failedCreatingHeartRateType
    case noActivitySummary
}

/// For getting data that doesn't require a specific `HKWorkout`
internal class GenericHealthKitHealthDataLoader {
    
    internal let store = HKHealthStore()
        
    internal func distance(for date: Date) async throws -> Float? {
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
    
    internal func stepCounts(for date: Date, minutesInterval: Int) async -> [Int]? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            fatalError("*** Unable to create a step count type ***")
        }

        let interval = DateComponents(minute: minutesInterval)
        let anchorDate = Calendar.current.startOfDay(for: Date())

        let startDate = Calendar.current.startOfDay(for: date)
        let endDate = Calendar.current.date(byAdding: DateComponents(day: 1), to: startDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        let stepCounts: [Int]? = await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                    quantitySamplePredicate: predicate,
                                                    options: .cumulativeSum,
                                                    anchorDate: anchorDate,
                                                    intervalComponents: interval)
            
            query.initialResultsHandler = { query, results, error in
                // Handle errors here.
                if let error = error as? HKError {
                    switch (error.code) {
                    case .errorDatabaseInaccessible:
                        // HealthKit couldn't access the database because the device is locked.
                        print("Error querying step count. Device locked.")
                        continuation.resume(returning: nil)
                        return
                    default:
                        print("Error in initialResultsHandler for stepCounts: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                }
                
                guard let statsCollection = results else {
                    // You should only hit this case if you have an unhandled error. Check for bugs
                    // in your code that creates the query, or explicitly handle the error.
                    continuation.resume(returning: nil)
                    return
                }
                
                var stepCounts: [Int] = []
                statsCollection.enumerateStatistics(from: startDate, to: endDate) { (statistics, _) in
                    if let quantity = statistics.sumQuantity() {
                        let value = Int(quantity.doubleValue(for: .count()))
                        stepCounts.append(value)
                    } else {
                        stepCounts.append(0)
                    }
                }
                
                continuation.resume(returning: stepCounts)
            }
            
            store.execute(query)
        }
        
        return stepCounts
    }
    
    internal func stepCounts(for activity: Activity) async -> [Int]? {
        return await self.stepCounts(for: activity.startDate, minutesInterval: 30)
    }

    internal func getActivityRingData(for date: Date) async throws -> HKActivitySummary {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.day, .month, .year, .era], from: date)
        components.calendar = calendar
        let predicate = HKQuery.predicateForActivitySummary(with: components)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let todaySummary = summaries?.first else {
                    continuation.resume(throwing: HealthKitHealthDataLoaderError.noActivitySummary)
                    return
                }

                continuation.resume(returning: todaySummary)
            }

            store.execute(query)
        }
    }
}

class HealthKitDailyStepsDataLoader: GenericHealthKitHealthDataLoader, HealthDataLoader {
    
    func coordinates(for activity: Activity) async throws -> [CLLocation] {
        return []
    }
    
    func heartRateSamples(for activity: Activity) async throws -> [HeartRateSample] {
        return []
    }
    
    func splits(for activity: Activity, unit: DistanceUnit) async -> [Split] {
        return []
    }
    
}

class HealthKitHealthDataLoader: GenericHealthKitHealthDataLoader, HealthDataLoader {
    
    func routeLocations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
        let coords: [CLLocation] = try await withCheckedThrowingContinuation { continuation in
            var allCoordinates: [CLLocation] = []
            let query = HKWorkoutRouteQuery(route: route) { (query, locations, done, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let locations = locations {
                    allCoordinates.append(contentsOf: locations)
                }
                
                if done && error == nil {
                    continuation.resume(returning: allCoordinates)
                }
            }

            store.execute(query)
        }

        return coords
    }

    func coordinates(for activity: Activity) async throws -> [CLLocation] {
        guard let workout = activity as? HKWorkout else {
            throw HealthDataLoaderError.typeMismatch
        }
        
        let predicate = HKQuery.predicateForObjects(from: workout)
        
        let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(type: HKSeriesType.workoutRoute(),
                                              predicate: predicate,
                                              anchor: nil,
                                              limit: HKObjectQueryNoLimit) { (_, routes, _, _, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let routes = routes as? [HKWorkoutRoute] {
                    continuation.resume(returning: routes)
                } else {
                    continuation.resume(returning: [])
                }
            }
            
            store.execute(query)
        }
        
        var coordinates: [CLLocation] = []
        for route in routes {
            let locations = try await routeLocations(for: route)
            coordinates.append(contentsOf: locations)
        }
        
        return coordinates
    }
    
    func heartRateSamples(for activity: Activity) async throws -> [HeartRateSample] {
        guard let workout = activity as? HKWorkout else {
            throw HealthDataLoaderError.typeMismatch
        }

        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitHealthDataLoaderError.failedCreatingHeartRateType
        }

        print("start")
        let samples: [HeartRateSample] = try await withCheckedThrowingContinuation { continuation in
            let seconds = Int(workout.duration / HeartRateGraph.numberOfSamplesToRequest).clamped(to: 1...Int.max)
            let interval = DateComponents(second: seconds)
            let workoutTimeInterval = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: [])
            let hrQuery = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                      quantitySamplePredicate: workoutTimeInterval,
                                                      options: [.discreteMin, .discreteMax, .discreteAverage],
                                                      anchorDate: workout.startDate,
                                                      intervalComponents: interval)
            hrQuery.initialResultsHandler = { query, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let statsCollection = results else {
                    continuation.resume(returning: [])
                    return
                }

                var heartRates: [HeartRateSample] = []
                statsCollection.enumerateStatistics(from: workout.startDate, to: workout.endDate) { statistics, _ in
                    if let avg = statistics.averageQuantity() {
                        let min = statistics.minimumQuantity() ?? avg
                        let max = statistics.maximumQuantity() ?? avg
                        let sample = HeartRateSample(minimumBpm: min.doubleValue(for: .count().unitDivided(by: .minute())),
                                                     averageBpm: avg.doubleValue(for: .count().unitDivided(by: .minute())),
                                                     maximumBpm: max.doubleValue(for: .count().unitDivided(by: .minute())),
                                                     startDate: statistics.startDate,
                                                     endDate: statistics.endDate)
                        heartRates.append(sample)
//                        print("got sample")
                    }
                }
                
                continuation.resume(returning: heartRates)
            }

            store.execute(hrQuery)
        }

        return samples
    }
    
    func splits(for activity: Activity,
                unit: DistanceUnit = ADUser.current.distanceUnit) async throws -> [Split] {
        guard let workout = activity as? HKWorkout else {
            throw HealthDataLoaderError.typeMismatch
        }
        
        guard let events = workout.workoutEvents else { return [] }
        print(events.map { $0.metadata })
        
        var splits: [Split] = []
        for event in events {
            if let split = Split(event)?.completedIfPartial(),
               split.unit == unit {
                splits.append(split)
            }
        }

        return splits
    }
    
}
