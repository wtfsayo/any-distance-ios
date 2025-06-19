// Licensed under the Any Distance Source-Available License
//
//  WatchHealthKitActivitiesStore.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 1/18/23.
//

import Foundation
import HealthKit

class WatchHealthKitActivitiesStore {

    static let shared = WatchHealthKitActivitiesStore()

    private let store = HKHealthStore()

    func getTodaysStepCount() async -> Int {
        let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay,
                                                    end: now,
                                                    options: [])

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepsQuantityType,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, result, _ in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: Int(sum.doubleValue(for: .count())))
            }

            store.execute(query)
        }

    }
}
