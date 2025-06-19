// Licensed under the Any Distance Source-Available License
//
//  CollectibleCalculator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/1/21.
//

import Foundation
import OneSignal

final class CollectibleCalculator {
    /// Filters out one-time only collectibles that the user has already earned.
    static func userCollectiblesAfterGranting(_ collectibles: [Collectible],
                                              sendEvents: Bool = true) -> (granted: [Collectible], all: [Collectible]) {
        var userCollectibles = ADUser.current.collectibles
        var collectibles = collectibles
        var i = 0

        // Keep track of which collectibles we have granted for each section name, segmented by
        // collectible dateEarned. Collectibles earned by the same activity will have the same
        // dateEarned. We are trying to limit the number of collectibles earned per section name per
        // activity.
        var foundItemSectionsGranted: [Date: [String]] = [:]

        while i < collectibles.count {
            let collectible = collectibles[i]

            // Filter out collectibles that can only be earned once.
            if collectible.canOnlyBeEarnedOnce,
               userCollectibles.contains(where: { $0.type.rawValue == collectible.type.rawValue }) {
                collectibles.remove(at: i)
                continue
            }

            // Filter out duplicates that are already in the user's collectibles list.
            if userCollectibles.contains(collectible) {
                collectibles.remove(at: i)
                continue
            }

            // Only grant one found item per section name to avoid overloading users with items for
            // one activity.
            switch collectible.type {
            case .remote(let remote):
                if let sections = foundItemSectionsGranted[collectible.dateEarned] {
                    if sections.contains(remote.sectionName) {
                        collectibles.remove(at: i)
                        continue
                    } else {
                        foundItemSectionsGranted[collectible.dateEarned] = sections + [remote.sectionName]
                    }
                } else {
                    foundItemSectionsGranted[collectible.dateEarned] = [remote.sectionName]
                }
            default: break
            }

            userCollectibles.append(collectible)
            i += 1

            if sendEvents {
                Analytics.logEvent("Collectible Earned",
                                   "Collectibles", .otherEvent,
                                   withParameters: ["collectibleType" : collectible.type.rawValue])
            }
        }

        userCollectibles.sort(by: { $0.dateEarned > $1.dateEarned })
        return (granted: collectibles, all: userCollectibles)
    }
    
    static func collectibles(for activities: [Activity]) async -> [Collectible] {
        var oneDayBeforeSignup: Date {
            if let signupDate = ADUser.current.signupDate,
               let oneDayBefore = Calendar.current.date(byAdding: .day, value: -1, to: signupDate) {
                return oneDayBefore
            }

            return Date(timeIntervalSince1970: 0)
        }

        var startDate = ADUser.current.lastCollectiblesRefreshDate ??
                        oneDayBeforeSignup

        let activitiesMinusCached = activities.filter { !($0 is CachedActivity) }
        // Calculate goal collectibles for all activities (minus cached).
        async let goalCollectibles = calculateGoalCollectibles(for: activitiesMinusCached)

        // Filter out step counts for the remaining collectible subtypes.
        let activitiesMinusStepCounts = activitiesMinusCached.filter { $0.startDateLocal > startDate && !($0 is DailyStepCount) }

        guard !activitiesMinusStepCounts.isEmpty else {
            return await goalCollectibles
        }

        // Calculate remote collectibles for activities spanning back to 1 day before signup, or the
        // last refresh date (whichever is sooner).
        async let remoteCollectibles = calculateRemoteCollectibles(forActivities: activitiesMinusStepCounts)

        // Filter back to activities after the signup date for remaining collectible subtypes.
        startDate = ADUser.current.lastCollectiblesRefreshDate ??
                    ADUser.current.signupDate ??
                    Date(timeIntervalSince1970: 0)
        let activitiesAfterStartDate = activitiesMinusStepCounts.filter { $0.startDateLocal > startDate }

        // Calculate remaining collectible subtypes.
        async let locationCollectibles = locationCollectibles(for: activitiesAfterStartDate)
        let specialCollectibles = calculateSpecialCollectibles(forActivities: activitiesAfterStartDate)
        let activityCollectibles = calculateActivityCollectibles(forActivities: activitiesAfterStartDate)
        let totalDistanceCollectibles = calculateTotalDistanceCollectibles()
        let all = (await locationCollectibles) +
                  (await remoteCollectibles) +
                  (await goalCollectibles) +
                  specialCollectibles +
                  activityCollectibles +
                  totalDistanceCollectibles
        return all
    }

    /// Calculates goal collectibles and adds new activity distances to all goals.
    private static func calculateGoalCollectibles(for activities: [Activity]) async -> [Collectible] {
        let goals = ADUser.current.goals

        if ADUser.current.lastGoalRefreshDate == nil {
            await MainActor.run {
                ADUser.current.lastGoalRefreshDate = activities.first?.startDateLocal
            }
        }

        // Grab all activities synced since the user's last goal refresh date
        let latestActivities = activities.filter { $0.startDateLocal > ADUser.current.lastGoalRefreshDate! }
        let allActivities = ActivitiesData.shared.activities.map { $0.activity }
        let allStepCounts = allActivities.filter { $0 is DailyStepCount }

        var collectibles: [Collectible] = []

        for goal in goals {
            guard !goal.isCompleted else {
                continue
            }

            @discardableResult func issueCollectible(dateEarned: Date) -> Collectible {
                let collectibleGoal = GoalMedal(goal: goal,
                                                      completionDistanceMeters: goal.completionDistanceMeters)
                let collectible = Collectible(type: CollectibleType.goal_new(collectibleGoal),
                                              dateEarned: dateEarned)
                collectibles.append(collectible)
                return collectible
            }

            if var currentDistanceMeters = goal.currentDistanceMeters {
                // Update the goal's currentDistanceMeters with each activity. Stop if the goal is
                // completed and set the activity's goalMetDate appropriately.
                for activity in latestActivities {
                    if goal.matches(activity) {
                        currentDistanceMeters += activity.distance
                        goal.currentDistanceMeters = currentDistanceMeters

                        if goal.markAsCompletedIfNecessary() {
                            issueCollectible(dateEarned: activity.startDateLocal.addingTimeInterval(1))
                            ActivitiesData.shared.meetGoal(for: activity)
                            break
                        }
                    }
                }
            } else {
                // This goal doesn't have a currentDistanceMeters. Calculate it and check if we need
                // to issue a collectible
                await goal.calculateCurrentDistanceMetersIfNecessary(for: allActivities, saveToCloudKit: false)
                if goal.markAsCompletedIfNecessary() {
                    issueCollectible(dateEarned: Date())
                }
            }
        }

        await MainActor.run {
            ADUser.current.lastGoalRefreshDate = latestActivities.first?.sortDate ?? ADUser.current.lastGoalRefreshDate
        }
        return collectibles
    }

    private static func locationCollectibles(for activities: [Activity]) async -> [Collectible] {
        var collectibles: [Collectible] = []

        for activity in activities {
            if let cityAndState = try? await activity.cityAndState {
                if let city = cityAndState.components(separatedBy: ",").first,
                   let location = CityMedal.new(fromCityName: city),
                   !collectibles.contains(where: { $0.type == CollectibleType.location(location) }) {
                    let collectible = Collectible(type: CollectibleType.location(location),
                                                  dateEarned: activity.startDateLocal.addingTimeInterval(1))
                    collectibles.append(collectible)
                }

                if let state = cityAndState.components(separatedBy: ",").last?.trimmingCharacters(in: .whitespaces),
                   let location = StateMedal.new(fromAbbreviation: state),
                   !collectibles.contains(where: { $0.type == CollectibleType.locationstate(location) }) {
                    let collectible = Collectible(type: CollectibleType.locationstate(location),
                                                  dateEarned: activity.startDateLocal.addingTimeInterval(1))
                    collectibles.append(collectible)
                }
            }
        }
        
        return collectibles
    }

    private static func calculateSpecialCollectibles(forActivities activities: [Activity]) -> [Collectible] {
        var collectibles: [Collectible] = []

        for activity in activities {
            for type in SpecialMedal.allCases {
                if let date = type.date,
                   date.matches(activity.startDateLocal) {
                    let collectible = Collectible(type: CollectibleType.special(type),
                                                  dateEarned: activity.startDateLocal.addingTimeInterval(1))
                    collectibles.append(collectible)
                }
            }
        }

        return collectibles
    }

    private static func calculateRemoteCollectibles(forActivities activities: [Activity]) async -> [Collectible] {
        var collectibles: [Collectible] = []

        for activity in activities {
            var remoteCollectiblesForActivity: [RemoteCollectible] = []

            for remote in CollectibleLoader.shared.remoteCollectibles.values {
                // Check if collectible can be earned
                guard remote.canBeEarned,
                      activity.dateMatches(for: remote),
                      activity.dailyDateRangeMatches(for: remote),
                      activity.activityTypeMatches(for: remote),
                      activity.isWithinDistanceRange(for: remote),
                      activity.isWithinMovingTimeRange(for: remote),
                      iAPManager.shared.superDistanceStateMatches(for: remote),
                      await activity.isWithinCoordinateRegions(for: remote) else {
                    continue
                }

                // All conditions match. Grant the collectible
                remoteCollectiblesForActivity.append(remote)
            }

            // Sort by moving time difference to prepare for per-section filtering in
            // userCollectiblesAfterGranting(_:sendEvents:)
            remoteCollectiblesForActivity.sort(by: {
                activity.movingTimeDifference(for: $0) < activity.movingTimeDifference(for: $1)
            })

            let collectiblesForActivity = remoteCollectiblesForActivity.map { remote in
                return Collectible(type: .remote(remote),
                                   dateEarned: activity.startDateLocal.addingTimeInterval(1))
            }
            collectibles.append(contentsOf: collectiblesForActivity)
        }

        return collectibles
    }

    private static func calculateActivityCollectibles(forActivities activities: [Activity]) -> [Collectible] {
        var collectibles: [Collectible] = []

        let unit = ADUser.current.distanceUnit
        for activity in activities {
            guard activity.distanceInUserSelectedUnit < DistanceMedal.activityCollectibleMaximumDistance else {
                continue
            }

            var medals = DistanceMedal.all(matchingDistance: activity.distanceInUserSelectedUnit,
                                           unit: unit,
                                           activityType: activity.activityType)

            // If you earn a higher value medal, remove the 1mi/km medal from the list. 1mi/km is
            // the lowest distance medal, so we can just check if there is more than one medal
            // in the list of matching medals. The other medal will always be a greater distance than
            // 1mi/km.
            if medals.count > 1 {
                medals.removeAll(where: { $0.unitlessDistance == 1 })
            }

            for medal in medals {
                let collectible = Collectible(type: .activity(medal),
                                              dateEarned: activity.startDateLocal.addingTimeInterval(1))
                collectibles.append(collectible)
            }
        }

        return collectibles
    }

    private static func calculateTotalDistanceCollectibles() -> [Collectible] {
        let totalDistanceTracked = ADUser.current.totalDistanceTracked
        let unit = ADUser.current.distanceUnit

        // Make sure the total distance tracked is greater than the minimum for total distance
        // collectibles.
        guard totalDistanceTracked >= DistanceMedal.totalDistanceCollectibleMinimumDistance else {
            return []
        }

        var totalDistanceMedals = DistanceMedal.allTotalDistanceMedals(forDistance: totalDistanceTracked,
                                                                       unit: unit)

        // Filter by medals already earned
        totalDistanceMedals = totalDistanceMedals.filter { medal in
            let medalAlreadyEarned = ADUser.current.collectibles.contains { existingCollectible in
                switch existingCollectible.type {
                case .totalDistance(let existingMedal):
                    return existingMedal == medal
                default:
                    return false
                }
            }

            return !medalAlreadyEarned
        }

        return totalDistanceMedals.map { medal in
            return Collectible(type: CollectibleType.totalDistance(medal),
                               dateEarned: Date())
        }
    }
}

fileprivate extension Activity {
    func dateMatches(for remote: RemoteCollectible) -> Bool {
        if let start = remote.startDate,
           let end = remote.endDate {
            return start.timeIntervalSince1970 <= startDateLocal.timeIntervalSince1970 &&
                   startDateLocal.timeIntervalSince1970 <= end.timeIntervalSince1970
        }
        return true
    }

    func dailyDateRangeMatches(for remote: RemoteCollectible) -> Bool {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let remoteStart = remote.dailyStartDate ?? startOfToday
        let remoteEnd = remote.dailyEndDate ?? startOfToday.addingTimeInterval(60*60*24-1) // 11:59:59 PM

        // Get just the hour minute and second
        let timeStart = Calendar.current.dateComponents([.hour, .minute, .second], from: remoteStart)
        let timeEnd = Calendar.current.dateComponents([.hour, .minute, .second], from: remoteEnd)
        let timeActivity = Calendar.current.dateComponents([.hour, .minute, .second], from: startDateLocal)

        // Normalize all dates
        guard let adjustedStart = Calendar.current.date(byAdding: timeStart, to: startOfToday),
              let adjustedEnd = Calendar.current.date(byAdding: timeEnd, to: startOfToday),
              let adjustedActivity = Calendar.current.date(byAdding: timeActivity, to: startOfToday) else {
            return false
        }

        return adjustedStart <= adjustedActivity && adjustedActivity <= adjustedEnd
    }

    func activityTypeMatches(for remote: RemoteCollectible) -> Bool {
        if remote.activityTypes.isEmpty {
            return true
        }

        return remote.activityTypes.contains(activityType)
    }

    func isWithinDistanceRange(for remote: RemoteCollectible) -> Bool {
        return remote.minDistanceMeters <= Double(distance) &&
               Double(distance) <= remote.maxDistanceMeters
    }

    func isWithinMovingTimeRange(for remote: RemoteCollectible) -> Bool {
        return movingTime >= remote.minDuration
    }

    func isWithinCoordinateRegions(for remote: RemoteCollectible) async -> Bool {
        if self.activityType.isDistanceBased {
            let coordinates = (try? await coordinates) ?? []
            guard let firstCoordinate = coordinates.first,
                  let lastCoordinate = coordinates.last else {
                // Activity has no coordinates. If there are defined coordinate regions, we
                // don't know where the activity took place, so return false. Otherwise,
                // return true.
                return remote.coordinateRegions.isEmpty
            }

            // Activity has coordinates. Check to see if the remote has defined coordinate
            // regions. If not, this activity passes.
            guard !remote.coordinateRegions.isEmpty else {
                return true
            }

            // Activity has coordinates and remote has defined regions. Check if any of the
            // regions overlap with the activity's coordinates.
            for region in remote.coordinateRegions {
                if region.contains(location: firstCoordinate) || region.contains(location: lastCoordinate) {
                    return true
                }
            }

            // No coordinate regions overlap, so this activity does not pass.
            return false
        } else {
            guard let coordinate = nonDistanceBasedCoordinate else {
                // Activity has no coordinates. If there are defined coordinate regions, we
                // don't know where the activity took place, so return false. Otherwise,
                // return true.
                return remote.coordinateRegions.isEmpty
            }

            // Activity has coordinates. Check to see if the remote has defined coordinate
            // regions. If not, this activity passes.
            guard !remote.coordinateRegions.isEmpty else {
                return true
            }

            // Activity has coordinates and remote has defined regions. Check if any of the
            // regions overlap with the activity's coordinates.
            for region in remote.coordinateRegions {
                if region.contains(location: coordinate) {
                    return true
                }
            }

            // No coordinate regions overlap, so this activity does not pass.
            return false
        }
    }

    /// Difference between the remote's minDuration and this activity's movingTime.
    /// Returns Float.greatestFiniteMagnitude if the activity's movingTime does not
    /// exceed the remote's minDuration.
    func movingTimeDifference(for remote: RemoteCollectible) -> Float {
        if movingTime < remote.minDuration {
            return Float.greatestFiniteMagnitude
        }

        return Float(movingTime - remote.minDuration)
    }
}

fileprivate extension iAPManager {
    func superDistanceStateMatches(for remote: RemoteCollectible) -> Bool {
        if remote.superDistanceRequired {
            return hasSuperDistanceFeatures
        }

        return true
    }
}
