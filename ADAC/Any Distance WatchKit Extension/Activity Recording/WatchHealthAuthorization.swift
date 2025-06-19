// Licensed under the Any Distance Source-Available License
//
//  WatchHealthAuthorization.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 2/22/23.
//

import Foundation
import HealthKit

class WatchHealthAuthorization {
    private static let store = HKHealthStore()

    static func requestAuthorization() async throws -> Bool {
        let types: Set<HKSampleType> = Set([HKSampleType.workoutType(),
                                            HKSeriesType.workoutRoute(),
                                            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
                                            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
                                            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                                            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                                            HKQuantityType.quantityType(forIdentifier: .bodyMass)!])

        let authorized: Bool = try await withCheckedThrowingContinuation { continuation in
            store.requestAuthorization(toShare: types, read: types) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }

        return authorized
    }

    static func sharingAuthorizationStatus() -> HKAuthorizationStatus {
        let types: Set<HKSampleType> = Set([HKSampleType.workoutType(),
                                            HKSeriesType.workoutRoute(),
                                            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
                                            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                                            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                                            HKQuantityType.quantityType(forIdentifier: .bodyMass)!])
        var status: HKAuthorizationStatus = .sharingAuthorized
        for type in types {
            let typeStatus = store.authorizationStatus(for: type)
            if typeStatus == .notDetermined {
                return typeStatus
            } else {
                status = typeStatus
            }
        }

        return status
    }
}
