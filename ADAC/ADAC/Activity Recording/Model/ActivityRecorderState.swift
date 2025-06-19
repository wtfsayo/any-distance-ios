// Licensed under the Any Distance Source-Available License
//
//  ActivityRecorderState.swift
//  ADAC
//
//  Created by Any Distance on 8/15/22.
//

import Foundation
import CoreLocation
import HealthKit
import Sentry

struct ActivityRecorderState: Codable {
    let unit: DistanceUnit
    let activityType: ActivityType
    let goal: RecordingGoal
    let settings: RecordingSettings
    let startDate: Date
    let state: iPhoneActivityRecordingState
    let duration: TimeInterval
    let distance: Double /// meters
    let elevationAscended: Double/// meters
    let pace: TimeInterval /// per mile or kilometer depending on unit
    let avgSpeed: Double /// mph or kmh depending on unit
    let totalCalories: Double
    let goalProgress: Float
    let goalMet: Bool
    let goalHalfwayPointReached: Bool
    let miSplits: [Split]
    let kmSplits: [Split]
    let heartRateData: [HeartRateSample]
    let currentLocation: LocationWrapper?
    let locations: [LocationWrapper]?
    let workoutEvents: [HKWorkoutEventWrapper]
    let didSendSafetyMessageAtStart: Bool

    private enum CodingKeys: String, CodingKey {
        case unit, activityType, goal, settings, startDate, state, duration, distance, elevationAscended,
             pace, avgSpeed, totalCalories, goalProgress, goalMet, goalHalfwayPointReached, miSplits,
             kmSplits, heartRateData, currentLocation, locations, workoutEvents, didSendSafetyMessageAtStart
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(unit, forKey: .unit)
        try? container.encode(activityType, forKey: .activityType)
        try? container.encode(goal, forKey: .goal)
        try? container.encode(settings, forKey: .settings)
        try? container.encode(startDate, forKey: .startDate)
        try? container.encode(state, forKey: .state)
        try? container.encode(duration, forKey: .duration)
        try? container.encode(distance, forKey: .distance)
        try? container.encode(elevationAscended, forKey: .elevationAscended)
        try? container.encode(pace, forKey: .pace)
        try? container.encode(avgSpeed, forKey: .avgSpeed)
        try? container.encode(totalCalories, forKey: .totalCalories)
        try? container.encode(goalProgress, forKey: .goalProgress)
        try? container.encode(goalMet, forKey: .goalMet)
        try? container.encode(goalHalfwayPointReached, forKey: .goalHalfwayPointReached)
        try? container.encode(miSplits, forKey: .miSplits)
        try? container.encode(kmSplits, forKey: .kmSplits)
        try? container.encode(heartRateData, forKey: .heartRateData)
        try? container.encode(currentLocation, forKey: .currentLocation)
        try? container.encode(locations, forKey: .locations)
        try? container.encode(workoutEvents, forKey: .workoutEvents)
        try? container.encode(didSendSafetyMessageAtStart, forKey: .didSendSafetyMessageAtStart)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unit = (try? container.decode(DistanceUnit.self, forKey: .unit)) ?? .miles
        activityType = (try? container.decode(ActivityType.self, forKey: .activityType)) ?? .run
        goal = (try? container.decode(RecordingGoal.self, forKey: .goal)) ?? RecordingGoal(type: .open, unit: .miles, target: 0)
        settings = (try? container.decode(RecordingSettings.self, forKey: .settings)) ?? NSUbiquitousKeyValueStore.default.defaultRecordingSettings
        startDate = (try? container.decode(Date.self, forKey: .startDate)) ?? Date()
        state = (try? container.decode(iPhoneActivityRecordingState.self, forKey: .state)) ?? .paused
        duration = (try? container.decode(TimeInterval.self, forKey: .duration)) ?? 0.0
        distance = (try? container.decode(Double.self, forKey: .distance)) ?? 0.0
        elevationAscended = (try? container.decode(Double.self, forKey: .elevationAscended)) ?? 0.0
        pace = (try? container.decode(TimeInterval.self, forKey: .pace)) ?? 0.0
        avgSpeed = (try? container.decode(Double.self, forKey: .avgSpeed)) ?? 0.0
        totalCalories = (try? container.decode(Double.self, forKey: .totalCalories)) ?? 0.0
        goalProgress = (try? container.decode(Float.self, forKey: .goalProgress)) ?? 0.0
        goalMet = (try? container.decode(Bool.self, forKey: .goalMet)) ?? false
        goalHalfwayPointReached = (try? container.decode(Bool.self, forKey: .goalHalfwayPointReached)) ?? false
        miSplits = (try? container.decode([Split?].self, forKey: .miSplits))?.compactMap { $0 } ?? []
        kmSplits = (try? container.decode([Split?].self, forKey: .kmSplits))?.compactMap { $0 } ?? []
        heartRateData = (try? container.decode([HeartRateSample?].self, forKey: .heartRateData))?.compactMap { $0 } ?? []
        currentLocation = try? container.decode(LocationWrapper.self, forKey: .currentLocation)
        locations = try? container.decode([LocationWrapper].self, forKey: .locations)
        workoutEvents = (try? container.decode([HKWorkoutEventWrapper?].self, forKey: .workoutEvents))?.compactMap { $0 } ?? []
        didSendSafetyMessageAtStart = (try? container.decode(Bool.self, forKey: .didSendSafetyMessageAtStart)) ?? false
    }

    init(unit: DistanceUnit,
         activityType: ActivityType,
         goal: RecordingGoal,
         settings: RecordingSettings,
         startDate: Date,
         state: iPhoneActivityRecordingState,
         duration: TimeInterval,
         distance: Double,
         elevationAscended: Double,
         pace: TimeInterval,
         avgSpeed: Double,
         totalCalories: Double,
         goalProgress: Float,
         goalMet: Bool,
         goalHalfwayPointReached: Bool,
         miSplits: [Split],
         kmSplits: [Split],
         heartRateData: [HeartRateSample],
         currentLocation: LocationWrapper?,
         locations: [LocationWrapper]?,
         workoutEvents: [HKWorkoutEventWrapper],
         didSendSafetyMessageAtStart: Bool) {
        self.unit = unit
        self.activityType = activityType
        self.goal = goal
        self.settings = settings
        self.startDate = startDate
        self.state = state
        self.duration = duration
        self.distance = distance
        self.elevationAscended = elevationAscended
        self.pace = pace
        self.avgSpeed = avgSpeed
        self.totalCalories = totalCalories
        self.goalProgress = goalProgress
        self.goalMet = goalMet
        self.goalHalfwayPointReached = goalHalfwayPointReached
        self.miSplits = miSplits
        self.kmSplits = kmSplits
        self.heartRateData = heartRateData
        self.currentLocation = currentLocation
        self.locations = locations
        self.workoutEvents = workoutEvents
        self.didSendSafetyMessageAtStart = didSendSafetyMessageAtStart
    }
}

struct HKWorkoutEventWrapper: Codable {
    let type: HKWorkoutEventType
    let dateInterval: DateInterval
    let encodableMetadata: [String: String]
    
    init(event: HKWorkoutEvent) {
        self.type = event.type
        self.dateInterval = event.dateInterval
        if let metadata = event.metadata {
            self.encodableMetadata = metadata.compactMapValues { value in
                if let codableValue = value as? String {
                    return codableValue
                }
                return nil
            }
        } else {
            self.encodableMetadata = [:]
        }
    }
}

extension HKWorkoutEvent {
    convenience init(wrapper: HKWorkoutEventWrapper) {
        self.init(type: wrapper.type,
                  dateInterval: wrapper.dateInterval,
                  metadata: wrapper.encodableMetadata)
    }
}

extension HKWorkoutEventType: Codable {}

extension Activity {
    func activityRecorderState() async throws -> ActivityRecorderState {
        let settings = RecordingSettings(clipRoute: clipsRoute)
        let coordinates = try await unclippedCoordinates
        let mileSplits = try? await loader.splits(for: self, unit: .miles)
        let kmSplits = try? await loader.splits(for: self, unit: .kilometers)
        let anyDistanceGoal = (self as? HKWorkout)?.anyDistanceGoal ?? RecordingGoal(type: .open,
                                                                                     unit: ADUser.current.distanceUnit,
                                                                                     target: 0.0)
        let anyDistanceGoalProgress = (self as? HKWorkout)?.anyDistanceGoalProgress ?? 0.0
        
        return ActivityRecorderState(unit: ADUser.current.distanceUnit,
                                     activityType: activityType,
                                     goal: anyDistanceGoal,
                                     settings: settings,
                                     startDate: startDateLocal,
                                     state: .saved,
                                     duration: movingTime,
                                     distance: Double(distance),
                                     elevationAscended: Double(totalElevationGain),
                                     pace: paceMeters,
                                     avgSpeed: Double(averageSpeed),
                                     totalCalories: Double(activeCalories),
                                     goalProgress: anyDistanceGoalProgress,
                                     goalMet: anyDistanceGoalProgress >= 1,
                                     goalHalfwayPointReached: anyDistanceGoalProgress >= 0.5,
                                     miSplits: mileSplits ?? [],
                                     kmSplits: kmSplits ?? [],
                                     heartRateData: [],
                                     currentLocation: nil,
                                     locations: coordinates.compactMap { LocationWrapper(from: $0) },
                                     workoutEvents: [],
                                     didSendSafetyMessageAtStart: false)
    }
}

extension NSUbiquitousKeyValueStore {
    var activityRecorderState: ActivityRecorderState? {
        get {
            if let data = data(forKey: "activityRecorderState") {
                do {
                    let decoded = try JSONDecoder().decode(ActivityRecorderState.self, from: data)
                    return decoded
                } catch {
                    let string = String(data: data, encoding: .utf8)
                    Analytics.logEvent("Error decoding recorder state",
                                       "error", .otherEvent, withParameters: ["data" : string])
                    SentrySDK.capture(error: error)
                }
            }

            return nil
        }

        set {
            if newValue == nil {
                set(nil as Any?, forKey: "activityRecorderState")
            } else {
                do {
                    let data = try JSONEncoder().encode(newValue)
                    set(data, forKey: "activityRecorderState")
                } catch {
                    Analytics.logEvent("Error saving recorder state", "error", .otherEvent)
                    SentrySDK.capture(error: error)
                }
            }
        }
    }
}
