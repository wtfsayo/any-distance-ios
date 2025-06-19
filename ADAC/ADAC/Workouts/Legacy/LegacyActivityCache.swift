// Licensed under the Any Distance Source-Available License
//
//  LegacyActivityCache.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/12/21.
//

import Foundation

final class LegacyActivityCache {
    private static var activities: [LegacyActivity] = []

    // MARK: - Read

    static func allActivities() -> [LegacyActivity] {
        if !activities.isEmpty {
            return activities
        }

        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true)

            let enumerator = FileManager.default.enumerator(atPath: documentsDirectory.path)
            let filePaths = enumerator?.allObjects as! [String]
            let healthActivityFilePaths = filePaths.filter {
                $0.contains(LegacyActivity.appleHealthCacheFileSuffix) ||
                $0.contains(LegacyActivity.wahooCacheFileSuffix)                
            }

            for path in healthActivityFilePaths {
                let url = documentsDirectory.appendingPathComponent(path)

                do {
                    let activity = try JSONDecoder().decode(LegacyActivity.self,
                                                            from: Data(contentsOf: url))
                    activities.append(activity)
                } catch {
                    print(error)
                }
            }
        } catch {
            print(error)
        }

        activities = activities.sorted(by: { $0.startDateLocal > $1.startDateLocal })
        removeDuplicatesByDate()
        
        return activities
    }

    static func activity(withId id: Int) -> LegacyActivity? {
        return allActivities().first(where: { $0.id == id })
    }

    static func activity(forCollectible collectible: Collectible) -> LegacyActivity? {
        return allActivities().first(where: { $0.startDateLocal < collectible.dateEarned })
    }

    static func cumulativeGoalDistance(forGoal goal: Goal) -> Float {
        if let mostRecent = allActivities().first(where: { $0.activityType == goal.activityType }) {
            return cumulativeGoalDistance(forActivityWithId: mostRecent.id, goal: goal)
        }

        return 0
    }

    static func cumulativeGoalDistance(forActivityWithId activityId: Int, goal: Goal) -> Float {
        let goalStartDate = Calendar.current.startOfDay(for: goal.startDate)
        let activities = allActivities().filter { $0.startDateLocal >= goalStartDate }
                                        .filter { $0.activityType == goal.activityType }
                                        .sorted { $0.startDateLocal < $1.startDateLocal }

        var totalDistanceM: Float = 0
        for a in activities {
            totalDistanceM += a.distance ?? 0

            if a.id == activityId {
                return UnitConverter.meters(totalDistanceM, toUnit: goal.unit)
            }
        }

        return UnitConverter.meters(totalDistanceM, toUnit: goal.unit)
    }

    // MARK: - Write

    static func cacheActivity(_ activity: LegacyActivity) {
        if let existingActivity = self.activity(withId: activity.id) {
            // Transfer over keys that are not part of HealthKit
            activity.goalMetDate = existingActivity.goalMetDate
            activity.heartRateData = existingActivity.heartRateData
        }

        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true)
            let fileUrl: URL = documentsDirectory.appendingPathComponent(activity.cacheFileName)
            try JSONEncoder().encode(activity).write(to: fileUrl)
        } catch {
            print(error)
        }

        if let idx = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[idx] = activity
            return
        }

        if let idx = activities.firstIndex(where: { $0.startDateLocal < activity.startDateLocal }) {
            activities.insert(activity, at: idx)
        } else {
            activities.append(activity)
        }
    }

    static func removeDuplicatesByDate() {
        let distanceThresholdMeters: Float = 10
        let durationThresholdSeconds: TimeInterval = 30
        let startTimeThresholdSeconds: TimeInterval = 300

        var i = 0
        while i < activities.count - 1 {
            let activity1 = activities[i]
            let activity2 = activities[i+1]

            // Check if the activity timestamps are within 5 minutes (300sec) of each other
            if abs(activity1.startDateLocal.timeIntervalSince(activity2.startDateLocal)) <= startTimeThresholdSeconds {
                let typeMatches = activity1.activityType == activity2.activityType

                if typeMatches {
                    var similarDistances = false
                    if let distance1 = activity1.distance,
                       let distance2 = activity2.distance {
                        similarDistances = abs(distance2 - distance1) <= distanceThresholdMeters
                    }

                    let duration1 = (activity1.endDateLocal ?? activity1.startDateLocal).timeIntervalSince(activity1.startDateLocal)
                    let duration2 = (activity2.endDateLocal ?? activity2.startDateLocal).timeIntervalSince(activity2.startDateLocal)
                    let similarDurations = abs(duration1 - duration2) <= durationThresholdSeconds

                    if similarDistances {
                        // Keep the activity that has elevation data.
                        if activity1.totalElevationGain != nil {
                            activities.remove(at: i+1)
                            continue
                        } else if activity2.totalElevationGain != nil {
                            activities.remove(at: i)
                            continue
                        } else if let latestIdx = [i, i+1].max(by: { activities[$0].startDateLocal < activities[$1].startDateLocal }) {
                            // If neither have elevation data, keep the first activity seen.
                            activities.remove(at: latestIdx)
                            continue
                        }
                    } else if similarDurations {
                        // One or both of these activities have no distance data. This could be caused by
                        // another app not sending this data for an indoor workout (ie Peloton). Keep
                        // the activity that has distance data.
                        if activity1.distance == nil {
                            activities.remove(at: i)
                            continue
                        } else if activity2.distance == nil {
                            activities.remove(at: i+1)
                            continue
                        } else if let latestIdx = [i, i+1].max(by: { activities[$0].startDateLocal < activities[$1].startDateLocal }) {
                            // If neither have distance data, keep the first activity seen.
                            activities.remove(at: latestIdx)
                            continue
                        }
                    }
                }
            }

            i += 1
        }
    }

    static func deleteAppleHealthCache() {
        activities.removeAll()

        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true)

            let enumerator = FileManager.default.enumerator(atPath: documentsDirectory.path)
            let filePaths = enumerator?.allObjects as! [String]

            let healthActivityFilePaths = filePaths.filter { $0.contains(LegacyActivity.appleHealthCacheFileSuffix) }
            for path in healthActivityFilePaths {
                let url = documentsDirectory.appendingPathComponent(path)
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    print(error)
                }
            }
        } catch {
            print(error)
        }
    }
}
