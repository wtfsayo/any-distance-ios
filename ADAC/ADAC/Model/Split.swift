// Licensed under the Any Distance Source-Available License
//
//  Split.swift
//  ADAC
//
//  Created by Any Distance on 7/18/22.
//

import Foundation
import HealthKit

struct Split: Codable, Equatable, Hashable {
    let unit: DistanceUnit
    let startDate: Date
    var duration: TimeInterval
    let startDistanceMeters: Double
    var totalDistanceMeters: Double
    var isPartial: Bool = false

    var currentSplitDistanceMeters: Double {
        return totalDistanceMeters - startDistanceMeters
    }

    var endDate: Date {
        return startDate.addingTimeInterval(duration)
    }
    
    var avgSpeedInUnit: Double {
        return UnitConverter.meters(currentSplitDistanceMeters, toUnit: unit) / (duration / 3600)
    }

    func hkWorkoutEvent() -> HKWorkoutEvent {
        let distanceMeters = UnitConverter.value(1, inUnitToMeters: unit)
        return HKWorkoutEvent(type: .segment,
                              dateInterval: DateInterval(start: startDate, duration: duration.clamped(to: 0.1...Double.greatestFiniteMagnitude)),
                              metadata: [ADMetadataKey.isPartialSplit : isPartial ? 1 : 0,
                                         ADMetadataKey.activeDurationQuantity : HKQuantity(unit: .second(), doubleValue: duration),
                                         ADMetadataKey.splitDistanceQuantity : HKQuantity(unit: .meter(), doubleValue: distanceMeters),
                                         ADMetadataKey.splitMeasuringSystem : unit == .kilometers ? 1 : 2,
                                         ADMetadataKey.totalDistanceQuantity : HKQuantity(unit: .meter(), doubleValue: totalDistanceMeters),
                                         ADMetadataKey.startDistanceQuantity : HKQuantity(unit: .meter(), doubleValue: startDistanceMeters)])

    }

    func completedIfPartial() -> Split {
        guard isPartial else {
            return self
        }

        var completedSplit = self
        let fullSplitDistanceMeters = UnitConverter.value(1, inUnitToMeters: unit)
        completedSplit.duration = duration * (fullSplitDistanceMeters / currentSplitDistanceMeters)
        completedSplit.totalDistanceMeters = completedSplit.startDistanceMeters + fullSplitDistanceMeters
        completedSplit.isPartial = false
        return completedSplit
    }
    
    init?(_ hkWorkoutEvent: HKWorkoutEvent) {
        if let isPartial = hkWorkoutEvent.metadata?[ADMetadataKey.isPartialSplit] as? Bool,
           let duration = hkWorkoutEvent.metadata?[ADMetadataKey.activeDurationQuantity] as? HKQuantity,
           let splitDistance = hkWorkoutEvent.metadata?[ADMetadataKey.splitDistanceQuantity] as? HKQuantity,
           let measuringSystem = hkWorkoutEvent.metadata?[ADMetadataKey.splitMeasuringSystem] as? Int,
           let totalDistance = hkWorkoutEvent.metadata?[ADMetadataKey.totalDistanceQuantity] as? HKQuantity {
            self.isPartial = isPartial
            self.unit = measuringSystem == 1 ? .kilometers : .miles
            self.startDate = hkWorkoutEvent.dateInterval.start
            self.duration = duration.doubleValue(for: .second())
            self.totalDistanceMeters = totalDistance.doubleValue(for: .meter())
            if let encodedStartDistance = hkWorkoutEvent.metadata?[ADMetadataKey.startDistanceQuantity] as? HKQuantity {
                self.startDistanceMeters = encodedStartDistance.doubleValue(for: .meter())
            } else {
                self.startDistanceMeters = splitDistance.doubleValue(for: .meter()) * floor(totalDistanceMeters / splitDistance.doubleValue(for: .meter()))
            }
        } else {
            return nil
        }
    }
    
    init(unit: DistanceUnit, startDate: Date, duration: TimeInterval, startDistanceMeters: Double, totalDistanceMeters: Double, isPartial: Bool) {
        self.unit = unit
        self.startDate = startDate
        self.duration = duration
        self.startDistanceMeters = startDistanceMeters
        self.totalDistanceMeters = totalDistanceMeters
        self.isPartial = isPartial
    }
}
