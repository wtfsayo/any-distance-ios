// Licensed under the Any Distance Source-Available License
//
//  HKWorkout+Activity.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/21/22.
//

import Foundation
import HealthKit

extension HKWorkout {
    var workoutSource: HealthKitWorkoutSource? {
        return HealthKitWorkoutSource(rawValue: bundleIdentifierWithoutUUID)
    }
    
    var bundleIdentifierWithoutUUID: String {
        if sourceRevision.source.bundleIdentifier.contains(HealthKitWorkoutSource.appleHealth.rawValue) {
            return HealthKitWorkoutSource.appleHealth.rawValue
        } else {
            return sourceRevision.source.bundleIdentifier
        }
    }
}

extension HKWorkout: Activity {
    var id: String {
        return "health_kit_\(uuid.uuidString)"
    }
    
    var activityType: ActivityType {
        if let metadataTypeRawValue = metadata?[ADMetadataKey.activityType] as? String,
           let metadataType = ActivityType(rawValue: metadataTypeRawValue) {
            return metadataType
        }
        
        switch workoutActivityType {
        case .running:
            return hasHKIndoorWorkoutMetadataKey ? .treadmillRun : .run
        case .cycling:
            return hasHKIndoorWorkoutMetadataKey ? .virtualRide : .bikeRide
        case .walking:
            return hasHKIndoorWorkoutMetadataKey ? .treadmillWalk : .walk
        case .other:
            return .other
        default:
            return ActivityType.allCases.first(where: { $0.hkWorkoutType == workoutActivityType }) ?? .unknown
        }
    }

    var hasHKIndoorWorkoutMetadataKey: Bool {
        return metadata?[HKMetadataKeyIndoorWorkout] as? Bool == true
    }
    
    var distance: Float {
        guard let value = totalDistance?.doubleValue(for: .meter()) else {
            return Float(metadata?[ADMetadataKey.totalDistanceMeters] as? Double ?? 0.0)
        }
        return Float(value)
    }
    
    var movingTime: TimeInterval {
        duration
    }
    
    var startDateLocal: Date {
        if let workoutTimeZone = TimeZone(identifier: metadata?[HKMetadataKeyTimeZone] as? String ?? ""),
           let gmt = TimeZone(identifier: "GMT") {
            return startDate.convertFromTimeZone(gmt, toTimeZone: workoutTimeZone)
        }

        return startDate
    }

    var startDateUTCToLocal: Date {
        return startDate.convertFromTimeZone(TimeZone(identifier: "GMT")!,
                                             toTimeZone: TimeZone.current)
    }
    
    var endDateLocal: Date {
        if let workoutTimeZone = TimeZone(identifier: metadata?[HKMetadataKeyTimeZone] as? String ?? ""),
           let gmt = TimeZone(identifier: "GMT") {
            return endDate.convertFromTimeZone(gmt, toTimeZone: workoutTimeZone)
        }

        return endDate
    }
    
    var activeCalories: Float {
        return Float(totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
    }
    
    var totalElevationGain: Float {
        let elevation = metadata?[HKMetadataKeyElevationAscended] as? HKQuantity
        return elevation?.doubleValue(for: .meter()).float() ?? 0
    }
    
    var stepCount: Int? {
        nil
    }

    var clipsRoute: Bool {
        return metadata?[ADMetadataKey.clipRoute] as? Bool ?? false
    }

    var recordedWithADWatchApp: Bool {
        return metadata?[ADMetadataKey.wasRecordedOnWatch] as? Bool ?? false
    }
}

extension HKWorkout {
    var anyDistanceGoal: RecordingGoal {
        if let typeRaw = metadata?[ADMetadataKey.goalType] as? String,
           let type = RecordingGoalType(rawValue: typeRaw),
           let target = metadata?[ADMetadataKey.goalTarget] as? Float {
            return RecordingGoal(type: type, unit: ADUser.current.distanceUnit, target: target)
        }
        return RecordingGoal(type: .open, unit: ADUser.current.distanceUnit, target: 0)
    }
    
    var anyDistanceGoalProgress: Float {
        switch anyDistanceGoal.type {
        case .distance:
            return distance / anyDistanceGoal.target
        case .time:
            return Float(duration) / anyDistanceGoal.target
        case .calories:
            return activeCalories / anyDistanceGoal.target
        case .open:
            return 0
        }
    }
}
