// Licensed under the Any Distance Source-Available License
//
//  DailyStepCount.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/9/21.
//

import HealthKit
import UIKit

struct DailyStepCount: ActivityTableViewDataClass, Codable {
    let startDate: Date
    let endDate: Date
    let timezoneId: String
    let count: Int
    
    var timezone: TimeZone {
        return TimeZone(identifier: timezoneId) ?? .current
    }
    
    var sortDate: Date {
        startDate
    }
    
    private enum CodingKeys: String, CodingKey {
        case startDate="date", endDate, timezoneId, count
    }
    
    init(startDate: Date, endDate: Date, timezone: TimeZone, count: Int) {
        self.startDate = startDate
        self.endDate = endDate
        self.timezoneId = timezone.identifier
        self.count = count
    }

    init(cachedActivity: CachedActivity) {
        self.startDate = cachedActivity.startDate
        self.endDate = cachedActivity.endDate
        self.timezoneId = "UTC"
        self.count = cachedActivity.stepCount ?? 0
    }
    
    var formattedCount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: count)) ?? "\(count)")
    }
        
    static var glyph: UIImage? {
        return UIImage(named: "activity_steps")
    }
}

extension DailyStepCount: Activity {
    
    var id: String {
        "hk_step_count_\(legacyId)"
    }
    
    var activityType: ActivityType {
        .stepCount
    }
    
    var distance: Float {
        HealthDataCache.shared.distance(for: startDate) ?? 0.0
    }

    /// Returns the step count distance for a given start date in the user selected unit
    var distanceForStartDate: Float? {
        get async {
            if let distanceMeters = HealthDataCache.shared.distance(for: startDate) {
                // update the cached value since the step count might have changed
                Task {
                    if let latestDistance = try? await loader.distance(for: startDate) {
                        HealthDataCache.shared.cache(distance: latestDistance, for: startDate)
                    }
                }

                return distanceMeters.metersToUserSelectedUnit
            }

            guard let distanceMeters = try? await loader.distance(for: startDate) else {
                return nil
            }

            HealthDataCache.shared.cache(distance: distanceMeters, for: startDate)

            return distanceMeters.metersToUserSelectedUnit
        }
    }
    
    var movingTime: TimeInterval {
        0.0
    }
    
    var startDateLocal: Date {
        startDate.convertFromTimeZone(timezone, toTimeZone: .current)
    }
    
    var endDateLocal: Date {
        endDate.convertFromTimeZone(timezone, toTimeZone: .current)
    }
    
    var activeCalories: Float {
        0.0
    }
    
    var totalElevationGain: Float {
        0.0
    }
    
    var stepCount: Int? {
        count
    }

    var workoutSource: HealthKitWorkoutSource? {
        return .appleHealth
    }
    
    var clipsRoute: Bool {
        return false
    }
}
