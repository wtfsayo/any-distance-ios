// Licensed under the Any Distance Source-Available License
//
//  CachedActivity.swift
//  ADAC
//
//  Created by Jarod Luebbert on 5/4/22.
//

import Foundation
import HealthKit

/// A wrapper around `Activity` for cacheing activity items to disk
struct CachedActivity: Activity, Codable {
    let id: String
    let activityType: ActivityType
    let distance: Float
    let movingTime: TimeInterval
    let startDate: Date
    let startDateLocal: Date
    let endDate: Date
    let endDateLocal: Date
    let activeCalories: Float
    let totalElevationGain: Float
    let stepCount: Int?
    let sourceBundleId: String?
    
    init(from activity: Activity) {
        self.id = activity.id
        self.activityType = activity.activityType
        self.distance = activity.distance
        self.movingTime = activity.movingTime
        self.startDate = activity.startDate
        self.startDateLocal = activity.startDateLocal
        self.endDate = activity.endDate
        self.endDateLocal = activity.endDateLocal
        self.activeCalories = activity.activeCalories
        self.totalElevationGain = activity.totalElevationGain
        self.stepCount = activity.stepCount
        self.sourceBundleId = (activity as? HKWorkout)?.bundleIdentifierWithoutUUID
    }

    var workoutSource: HealthKitWorkoutSource? {
        return HealthKitWorkoutSource(rawValue: sourceBundleId ?? "")
    }
    
    var clipsRoute: Bool {
        return false
    }
}
