// Licensed under the Any Distance Source-Available License
//
//  GarminActivity.swift
//  ADAC
//
//  Created by Jarod Luebbert on 7/11/22.
//

import Foundation

enum GarminActivityType: String {
    case running
    case indoor_running
    case obstacle_run
    case street_running
    case track_running
    case trail_running
    case treadmill_running
    case ultra_run
    case virtual_run
    case cycling
    case bmx
    case cyclocross
    case downhill_biking
    case gravel_cycling
    case indoor_cycling
    case mountain_biking
    case recumbent_cycling
    case road_biking
    case track_cycling
    case virtual_ride
    case fitness_equipment
    case bouldering
    case elliptical
    case indoor_cardio
    case indoor_climbing
    case indoor_rowing
    case pilates
    case stair_climbing
    case strength_training
    case yoga
    case hiking
    case swimming
    case lap_swimming
    case open_water_swimming
    case walking
    case casual_walking
    case speed_walking
    case transition
    case bikeToRunTransition
    case runToBikeTransition
    case swimToBikeTransition
    case motorcycling
    case atv
    case motocross
    case other
    case auto_racing
    case boating
    case breathwork
    case driving_general
    case e_sport
    case floor_climbing
    case flying
    case golf
    case hang_gliding
    case horseback_riding
    case hunting_fishing
    case hunting
    case fishing
    case inline_skating
    case mountaineerin
    case offshore_grinding
    case onshore_grinding
    case paddling
    case rc_drone
    case rock_climbing
    case rowing
    case sailing
    case sky_diving
    case stand_up_paddleboarding
    case stop_watch
    case surfing
    case tennis
    case wakeboarding
    case whitewater_rafting_kayaking
    case wind_kite_surfing
    case wingsuit_flying
    case diving
    case apnea_diving
    case apnea_hunting
    case ccr_diving
    case gauge_diving
    case multi_gas_diving
    case single_gas_diving
    case winter_sports
    case backcountry_skiing_snowboarding_ws
    case cross_country_skiing_ws
    case resort_skiing_snowboarding_ws
    case skate_skiing_ws
    case skating_ws
    case snow_shoe_ws
    case snowmobiling_ws
    case wheelchair_push_run
    case wheelchair_push_walk

    var displayName: String {
        rawValue
            .removing(suffix: "_ws")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

extension GarminActivityType: Codable {
    init(from decoder: Decoder) throws {
        self = try GarminActivityType(rawValue: decoder.singleValueContainer().decode(RawValue.self).lowercased()) ?? .other
    }
}

struct GarminActivity: Codable {
    let activityId: Int
    let summaryId: String
    let userId: String
    let summary: GarminActivitySummary
    let samples: [GarminActivitySample]
    let laps: [GarminActivityLap]?
}

struct GarminActivitySummary: Codable {
    let manual: Bool?
    let activityId: Int
    let deviceName: String?
    let activityName: String
    let activityType: GarminActivityType
    let distanceInMeters: Float?
    let durationInSeconds: TimeInterval
    let activeKilocalories: Float
    
    /// Start time of the activity in seconds since January 1, 1970, 00:00:00 UTC (Unix timestamp).
    let startTimeInSeconds: TimeInterval
    /// Offset in seconds to add to startTimeInSeconds to derive the “local” time of the device that captured the data.
    let startTimeOffsetInSeconds: TimeInterval
    
    let averageHeartRateInBeatsPerMinute: Int?
    let averageRunCadenceInStepsPerMinute: Float?
    let averageSpeedInMetersPerSecond: Float?
    let averagePaceInMinutesPerKilometer: Float?
    
    let maxHeartRateInBeatsPerMinute: Int?
    let maxPaceInMinutesPerKilometer: Float?
    let maxRunCadenceInStepsPerMinute: Float?
    let maxSpeedInMetersPerSecond: Float?
    let startingLatitudeInDegree: Float?
    let startingLongitudeInDegree: Float?
    let steps: Int?
    let totalElevationGainInMeters: Float?
    let totalElevationLossInMeters: Float?
}

struct GarminActivityLap: Codable {
    let startTimeInSeconds: TimeInterval
}

struct GarminActivitySample: Codable {
    let sTS: Double? // startTimeInSeconds
    let latD: Double? // latitudeInDegree
    let lonD: Double? // longitudeInDegree
    let eM: Double? // elevationInMeters
    let hR: Int? // heartRate
    let sMS: Double? // speedInMetersPerSecond
    let stepsPerMinute: Double?
    let tDM: Double? // totalDistanceInMeters
    
    /// Tip: In all cases, `movingDurationInSeconds <= timerDurationInSeconds <= clockDurationInSeconds`
    ///
    /// For example, a user is going for a run. He starts the timer at exactly noon. At 12:30 he pauses the timer
    /// (either manually or using auto-pause) to stop and chat with a friend, and at 12:35 he resumes the timer.
    ///
    /// At 12:40 he stands still for 2 minutes, waiting on a traffic signal at a busy intersection,
    /// then finishes his run and manually stops the timer at 1:00 pm.
    ///
    /// clockDurationInSeconds = 60 minutes (12:00 - 1:00)
    /// timerDurationInSeconds = 55 minutes (12:00-12:30 + 12:35-1:00)
    /// movingDurationInSeconds = 53 minutes (12:00-12:30 + 12:35-12:40 + 12:42-1:00)
    let tDS: Int? // timerDurationInSeconds - The amount of “timer time” in an activity
    let cDS: Int? // clockDurationInSeconds - The amount of real-world “clock time” from the start of an activity to the end
    let mDS: Int? // movingDurationInSeconds - The amount of “timer time” during which the athlete was moving (above a threshold speed)
}

extension GarminActivity: Activity {
    var id: String {
        "garmin_\(activityId)"
    }
    
    var activityType: ActivityType {
        ActivityType.from(garminActivityType: summary.activityType)
    }
    
    var workoutSource: HealthKitWorkoutSource? {
        return nil
    }
    
    var clipsRoute: Bool {
        return false
    }
    
    var distance: Float {
        summary.distanceInMeters ?? 0.0
    }
    
    var movingTime: TimeInterval {
        summary.durationInSeconds
    }
    
    var startDate: Date {
        Date(timeIntervalSince1970: summary.startTimeInSeconds)
    }
    
    var startDateLocal: Date {
        Date(timeIntervalSince1970: summary.startTimeInSeconds + summary.startTimeOffsetInSeconds)
    }
    
    var endDate: Date {
        Date(timeIntervalSince1970: summary.startTimeInSeconds + summary.durationInSeconds)
    }
    
    var endDateLocal: Date {
        Date(timeIntervalSince1970: summary.startTimeInSeconds + summary.startTimeOffsetInSeconds + summary.durationInSeconds)
    }
    
    var stepCount: Int? {
        summary.steps
    }
    
    var activeCalories: Float {
        summary.activeKilocalories
    }
    
    var totalElevationGain: Float {
        summary.totalElevationGainInMeters ?? 0.0
    }
    
}
