// Licensed under the Any Distance Source-Available License
//
//  ActivitiesLoader.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/22/22.
//

import Foundation
import Accessibility
import Cache
import HealthKit
import Combine
import Sentry
import OneSignal

enum ActivitiesProvider: String, CaseIterable {
    case appleHealth, wahoo, garmin
}

class ActivitiesData: ObservableObject {
    
    typealias ActivityId = String
    
    static let shared = ActivitiesData()
    
    static var activitiesWithGoalMetFilename = "activities_with_goal_met.json"
    
    @Published private(set) var hasHealthKitActivities: Bool = false
    
    @Published private(set) var activities: [ActivityIdentifiable] = []
    
    private var disposables = Set<AnyCancellable>()
    
    private var allActivities: [Activity] {
        get async throws {
            let activities = await withTaskGroup(of: [Activity].self) { group in
                group.addTask {
                    do {
                        let hasGarminConnected = try await self.isAuthorized(for: .garmin)
                        let filteredHKActivities = (try await self.hkActivitiesStore.load()).filter { activity in
                            guard let healthKitSource = activity.workoutSource else {
                                return true
                            }

                            // filter out HK activities that come from garmin if
                            // the user has garmin connected
                            if healthKitSource == .garminConnect,
                               hasGarminConnected {
                                return false
                            }

                            return true
                        }
                        return filteredHKActivities
                    } catch {
                        SentrySDK.capture(error: error)
                        return []
                    }
                }

                group.addTask {
                    do {
                        return try await self.hkActivitiesStore.loadDailySteps()
                    } catch {
                        SentrySDK.capture(error: error)
                        return []
                    }
                }

                group.addTask {
                    do {
                        return try await self.wahooActivitiesStore.load()
                    } catch {
                        SentrySDK.capture(error: error)
                        return []
                    }
                }

                group.addTask {
                    do {
                        return try await self.garminActivitiesStore.load()
                    } catch {
                        SentrySDK.capture(error: error)
                        return []
                    }
                }

                var allActivities: [Activity] = []
                for await result in group {
                    allActivities.append(contentsOf: result)
                }

                return allActivities
            }

            return activities.activitiesByRemovingDuplicates()
        }
    }
    
    // MARK: - Private
    
    let hkActivitiesStore = HealthKitActivitiesStore.shared
    private let wahooActivitiesStore = WahooActivitiesStore.shared
    private let garminActivitiesStore = GarminActivitiesStore.shared
    
    private let activitiesCache: Storage<String, [CachedActivity]>?
    private var activitiesWithGoalMet = Set<ActivityId>()
    
    private static let documentsDirectory = try! FileManager.default.url(for: .documentDirectory,
                                                                         in: .userDomainMask,
                                                                         appropriateFor: nil,
                                                                         create: true)
    
    private static var activitiesWithGoalMetFile: URL {
        get throws {
            return documentsDirectory.appendingPathComponent(Self.activitiesWithGoalMetFilename)
        }
    }

    let activitiesReloadedPublisher = PassthroughSubject<Void, Never>()
    
    // MARK: - Init
    
    // use the shared instance
    private init() {
        do {
            activitiesWithGoalMet = try JSONDecoder().decode(Set<ActivityId>.self,
                                                             from: Data(contentsOf: Self.activitiesWithGoalMetFile))
        } catch {
            SentrySDK.capture(error: error)
        }
        
        let diskConfig = DiskConfig(name: "com.anydistance.ActivitiesCache")
        let memoryConfig = MemoryConfig(expiry: .never, countLimit: 500, totalCostLimit: 10)

        activitiesCache = try? Storage<String, [CachedActivity]>(
            diskConfig: diskConfig,
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forCodable(ofType: [CachedActivity].self)
        )

        if let cachedActivities = try? activitiesCache?.object(forKey: "activities") {
            activities = cachedActivities
                .filter { cachedActivity in
                    if !NSUbiquitousKeyValueStore.default.shouldShowStepCount {
                        return cachedActivity.activityType != .stepCount
                    } else {
                        return true
                    }
                }
                .sorted(by: { lhs, rhs in
                    return lhs.startDate.compare(rhs.startDate) == .orderedDescending
                })
                .map { ActivityIdentifiable(activity: $0) }
        }
        
        hkActivitiesStore.activitySynced
            .removeDuplicates(by: { lhs, rhs in
                return lhs.id == rhs.id
            })
            .filter { latestActivity in
                if !NSUbiquitousKeyValueStore.default.shouldShowStepCount && latestActivity.activityType == .stepCount {
                    return false
                }
                
                return true
            }
            .sink { [weak self] latestActivity in
                guard let self = self else { return }
                
                if !self.activities.contains(where: { $0.activity.id == latestActivity.id }) {
                    self.activities.insert(ActivityIdentifiable(activity: latestActivity), at: 0)
                }
                
                self.cacheActivities(activities: self.activities.map { $0.activity }.activitiesByRemovingDuplicates())
            }.store(in: &disposables)
        
        $activities.sink { [weak self] activities in
            guard let self = self else { return }
            let healthKitActivities = activities.filter({ $0.activity is HKWorkout || $0.activity is DailyStepCount })
            self.hasHealthKitActivities = !healthKitActivities.isEmpty
        }.store(in: &disposables)
    }
    
    // MARK: - Public
    
    func isAuthorized(for provider: ActivitiesProvider) async throws -> Bool {
        switch provider {
        case .appleHealth:
            return hkActivitiesStore.hasRequestedAuthorization()
        case .wahoo:
            return try await wahooActivitiesStore.isAuthorizedForAllTypes()
        case .garmin:
            return try await garminActivitiesStore.isAuthorizedForAllTypes()
        }
    }
    
    func load(updateUserAndCollectibles: Bool = true) async {
        guard hkActivitiesStore.hasRequestedAuthorization() else {
            return
        }
        
        do {
            let loadedActivities = try await allActivities
            activities = loadedActivities
                .sorted(by: { lhs, rhs in
                    return lhs.startDate.compare(rhs.startDate) == .orderedDescending
                })
                .map { ActivityIdentifiable(activity: $0) }
            
            cacheActivities(activities: loadedActivities)
            
            if updateUserAndCollectibles {
                await updateUserForNewActivities()
            }

            await MainActor.run {
                activitiesReloadedPublisher.send()
            }
        } catch {
            SentrySDK.capture(error: error)
        }
    }

    func hasTrackedADActivity() -> Bool {
        return activities.contains(where: { $0.activity.workoutSource == .anyDistance })
    }

    // MARK: - Activity Cacheing
    
    func cacheActivities(activities: [Activity]) {
        try? activitiesCache?.setObject(activities.map { CachedActivity(from: $0) },
                                        forKey: "activities")
    }
    
    // MARK: - Private

    func updateUserForNewActivities() async {
        let activities = activities.map { $0.activity }
            .sorted(by: { lhs, rhs in
                return lhs.startDate.compare(rhs.startDate) == .orderedDescending
            })

        guard !activities.isEmpty else {
            return
        }

        await MainActor.run {
            ADUser.current.updateTotalDistanceTracked(for: activities)
            ADUser.current.updateTotalTimeTracked(for: activities)
            ADUser.current.updateGear(for: activities)
        }

        if let firstActivity = activities.first {
            let collectibles = await CollectibleCalculator.collectibles(for: activities)
            await MainActor.run {
                CollectibleManager.grantCollectibles(collectibles)
                ADUser.current.lastCollectiblesRefreshDate = firstActivity.startDateLocal.addingTimeInterval(1)
            }
            if ADUser.current.hasRegistered {
                await UserManager.shared.updateCurrentUser()
            }
            Analytics.sendActivitySyncedEvents()
        }
    }
    
    // MARK: - Activity Getters
    
    func activity(with id: String) -> Activity? {
        return activities.first(where: { $0.activity.id.contains(id) })?.activity
    }
    
    func activity(for collectible: Collectible) -> Activity? {
        return activities.first(where: { $0.activity.startDateLocal < collectible.dateEarned })?.activity
    }
    
    // MARK: - Async Activity Getters
    
    func loadActivity(with id: String) async throws -> Activity? {
        let all = try await allActivities
        return all.first(where: { $0.id == id })
    }
    
    func loadActivity(for collectible: Collectible) async throws -> Activity? {
        return try await allActivities.first(where: { $0.startDateLocal < collectible.dateEarned })
    }

    // MARK: - Activity Deletion

    func deleteActivity(_ activity: Activity) async throws {
        guard let hkWorkout = activity as? HKWorkout else {
            return
        }

        try await self.hkActivitiesStore.deleteWorkout(hkWorkout)
        activities.removeAll(where: { $0.id == activity.id })

        // Remove activity distance from goals
        for goal in ADUser.current.goals {
            if goal.matches(activity),
               !goal.isCompleted,
               let currentDistanceMeters = goal.currentDistanceMeters {
                goal.currentDistanceMeters = (currentDistanceMeters - activity.distance)
                                                .clamped(to: 0...Float.greatestFiniteMagnitude)
            }
        }

        await MainActor.run {
            // Subtract from total distance tracked
            if let totalDistanceTrackedMeters = ADUser.current.totalDistanceTrackedMeters {
                ADUser.current.totalDistanceTrackedMeters = (totalDistanceTrackedMeters - Double(activity.distance))
                    .clamped(to: 0...Double.greatestFiniteMagnitude)
            }

            // Subtract from total time tracked
            ADUser.current.totalTimeTracked = (ADUser.current.totalTimeTracked - activity.movingTime)
                .clamped(to: 0...Double.greatestFiniteMagnitude)
        }
        await UserManager.shared.updateCurrentUser()

        ReloadPublishers.activityDeleted.send()
    }
    
    // MARK: - Push Notifications
    
    func startObservingNewActivitiesForAuthorizedProviders() {
        guard ADUser.current.hasFinishedOnboarding else {
            return
        }
        
        Task {
            for provider in ActivitiesProvider.allCases {
                let authorized = (try? await isAuthorized(for: provider)) ?? false
                
                if authorized {
                    startObservingNewActivities(for: provider)
                }

                OneSignal.sendTag("\(provider.rawValue)_connected", value: authorized ? "1" : "0")
            }
        }
    }
    
    func startObservingNewActivities(for provider: ActivitiesProvider) {
        Task {
            switch provider {
            case .appleHealth:
                await hkActivitiesStore.startObservingNewActivities()
            case .wahoo:
                await wahooActivitiesStore.startObservingNewActivities()
            case .garmin:
                await garminActivitiesStore.startObservingNewActivities()
            }
        }
    }
    
    // MARK: Goals
    
    func goalMet(for activity: Activity) -> Bool {
        activitiesWithGoalMet.contains(activity.id)
    }
    
    func meetGoal(for activity: Activity) {
        let (inserted, _) = activitiesWithGoalMet.insert(activity.id)
        if inserted {
            Task {
                do {
                    try JSONEncoder().encode(activitiesWithGoalMet).write(to: try Self.activitiesWithGoalMetFile,
                                                                          options: .atomic)
                } catch {
                    SentrySDK.capture(error: error)
                }
            }
        }
    }
    
}

extension Array where Element == Activity {
    
    func activitiesByRemovingDuplicates() -> [Activity] {
        let distanceThresholdMeters: Float = 10.0
        let timeThresholdSeconds = 30.0
        
        let activities = sorted(by: { $0.startDate.timeIntervalSince1970 > $1.startDate.timeIntervalSince1970 })
        var activitiesWithoutDupes = activities
        var checkedActivities: Set<ActivityIdentifiable> = []
        for (i, activity) in activities.enumerated() {
            guard !checkedActivities.contains(ActivityIdentifiable(activity: activity)) else {
                continue
            }

            let activityType = activity.activityType
            let startDate = activity.startDate

            guard activityType != .stepCount else {
                continue
            }
            
            // will include the current `activity`
            // only search within 10 indexes of the current activity
            let lowerBound = (i - 10).clamped(to: 0...activities.count-1)
            let upperBound = (i + 10).clamped(to: 0...activities.count-1)
            let surroundingActivities = activities[lowerBound...upperBound]

            let similarActivities = surroundingActivities.filter { otherActivity in
                let activityTypeExactMatch = (otherActivity.activityType == activityType)
                let activityTypeSimilarMatch = otherActivity.activityType.matchingGoalActivityTypes.contains(activityType) || activityType.matchingGoalActivityTypes.contains(otherActivity.activityType)
                let activityTypeMatch = activityTypeExactMatch || activityTypeSimilarMatch

                return activityTypeMatch &&
                       abs(otherActivity.startDate.timeIntervalSince(startDate)) <= timeThresholdSeconds &&
                       abs(activity.distance - otherActivity.distance) < distanceThresholdMeters
            }
            
            if !similarActivities.isEmpty {
                let garminActivity = similarActivities.first(where: { $0 is GarminActivity })
                let wahooActivity = similarActivities.first(where: { $0 is WahooActivity })
                let distanceAndElevation = similarActivities.first(where: { $0.distance > 0 && $0.totalElevationGain > 0 })
                let distance = similarActivities.first(where: { $0.distance > 0 })
                let elevation = similarActivities.first(where: { $0.totalElevationGain > 0 })
                let activityWithMostData = garminActivity ?? wahooActivity ?? distanceAndElevation ?? distance ?? elevation ?? activity
                // keep track of the duplicates so we don't check them again
                let checked = similarActivities.filter { $0.id != activityWithMostData.id }
                checkedActivities.formUnion(checked.map { ActivityIdentifiable(activity: $0) })
                // remove the duplicates
                activitiesWithoutDupes.removeAll(where: { obj in
                    checked.contains(where: { $0.id == obj.id })
                })
            }
        }
        
        return activitiesWithoutDupes
    }
    
}
