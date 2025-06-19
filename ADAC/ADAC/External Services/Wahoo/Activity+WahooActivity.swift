// Licensed under the Any Distance Source-Available License
//
//  Activity+WahooActivity.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/14/22.
//

import Foundation

extension Activity {
    
    convenience init(with wahooActivity: WahooActivity) {
        self.init(id: wahooActivity.id)
        
        _service = .wahoo
        movingTime = TimeInterval(wahooActivity.summary?.durationActiveAccum ?? 0.0)
        
        averageSpeed = wahooActivity.summary?.speedAvg
        startDate = wahooActivity.starts
        distance = wahooActivity.summary?.distanceAccum
        if let calories = wahooActivity.summary?.caloriesAccum {
            activeCalories = Int(calories)
        }
        averageSpeed = Float(wahooActivity.summary?.speedAvg ?? 0.0)
        startDateLocal = wahooActivity.starts.convertFromTimeZone(TimeZone(identifier: "UTC")!, toTimeZone: Calendar.current.timeZone)
        if let duration = movingTime {
            endDate = startDate?.addingTimeInterval(duration)
        }

        self.wahooActivity = wahooActivity
        
        if let wahooActivity = WahooActivityType(rawValue: wahooActivity.workoutTypeID) {
            let activityType = ActivityType(wahooActivityType: wahooActivity)
            // TODO: we need a better way to do this
            type = activityType.rawValue
        }
    }
    
}
