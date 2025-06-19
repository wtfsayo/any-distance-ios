// Licensed under the Any Distance Source-Available License
//
//  Analytics.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/12/21.
//

import Foundation
import Mixpanel
import HealthKit
import OneSignal

final class Analytics {
    static func sendActivitySyncedEvents() {
        let lastSyncedDate = NSUbiquitousKeyValueStore.default.lastActivitiesSyncedDate
        let newActivites = ActivitiesData.shared.activities
            .map { $0.activity }
            .filter { activity in
                return !(activity is CachedActivity) &&
                       !(activity is DailyStepCount) &&
                       activity.startDate > lastSyncedDate
            }
        
        NSUbiquitousKeyValueStore.default.lastActivitiesSyncedDate = newActivites.first?.startDate ?? lastSyncedDate

        for activity in newActivites {
            var params: [String: Any] = [:]
            if let hkWorkout = activity as? HKWorkout {
                params["sourceBundleId"] = hkWorkout.bundleIdentifierWithoutUUID
                params["recordedWithADWatchApp"] = hkWorkout.recordedWithADWatchApp
            }

            params["integration"] = activity.id.components(separatedBy: "_").first
            params["activityType"] = activity.activityType.rawValue
            params["distanceMeters"] = activity.distance
            params["activeCalories"] = activity.activeCalories
            params["elevationGainMeters"] = activity.totalElevationGain
            params["movingTime"] = activity.movingTime

            Analytics.logEvent("v2 Activity Synced", "Activity Synced", .otherEvent, withParameters: params)
        }
    }

    static func logEvent(_ eventName: String, _ screenName: String, _ eventType: EventType, withParameters parameters: [String: Any]? = nil) {
        #if !DEBUG
        var fullName: String
        if eventType == .screenViewed {
            fullName = "[\(screenName)] [\(eventType.rawValue)]"
        } else {
            fullName = "[\(screenName)] [\(eventType.rawValue)] \(eventName)"
        }
        Mixpanel.mainInstance().track(event: fullName, properties: parameters as? Properties ?? nil)
        #endif
    }
}

enum EventType: String {
    case buttonTap = "Button Tap"
    case screenViewed = "Screen Viewed"
    case otherEvent = "Other"
    case withError = "With Error"
}

fileprivate extension NSUbiquitousKeyValueStore {
    var lastActivitiesSyncedDate: Date {
        get {
            if object(forKey: "lastActivitiesSyncedDate") == nil {
                return Date()
            }

            return Date(timeIntervalSince1970: double(forKey: "lastActivitiesSyncedDate"))
        }

        set {
            set(newValue.timeIntervalSince1970, forKey: "lastActivitiesSyncedDate")
        }
    }
}
