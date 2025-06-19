// Licensed under the Any Distance Source-Available License
//
//  ActivityListProvider.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/29/22.
//

import Foundation
import HealthKit

class ActivityListProvider {
    static let recentlyUsedSectionName: String = "Recently Used"
    static let popularSectionName: String = "Popular"

    static func activityTypesByCategory() -> [String: [ActivityType]] {
        let allCasesWithCategory = ActivityType.allCases.filter { $0.categoryString != nil}
        var dictionary = Dictionary(grouping: allCasesWithCategory) { $0.categoryString! }
        let recentlyUsed = recentlyUsedActivities()
        dictionary[recentlyUsedSectionName] = recentlyUsed
        dictionary[popularSectionName] = popularActivities()
        return dictionary
    }

    static func recentlyUsedActivities(limit: Int = 5) -> [ActivityType] {
        #if os(watchOS)
        let storedTypes = NSUbiquitousKeyValueStore.default.recentlyRecordedActivityTypes
        if storedTypes.isEmpty {
            return [.run, .bikeRide, .walk]
        }

        return Array(storedTypes[0..<min(storedTypes.count, limit)])
        #else
        let adActivities = ActivitiesData.shared.activities
            .map { $0.activity }
            .filter { $0.workoutSource == .anyDistance }

        var activityTypes: [ActivityType] = []
        for activity in adActivities {
            if !activityTypes.contains(activity.activityType) {
                activityTypes.append(activity.activityType)
            }

            if activityTypes.count == limit {
                break
            }
        }

        if activityTypes.isEmpty {
            return [.run, .bikeRide, .walk]
        } else {
            return activityTypes
        }
        #endif
    }

    static func popularActivities() -> [ActivityType] {
        return [.run, .walk, .bikeRide]
    }
}
