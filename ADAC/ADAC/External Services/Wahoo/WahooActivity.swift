// Licensed under the Any Distance Source-Available License
//
//  WahooActivity.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/14/22.
//

import Foundation

enum WahooActivityType: Int {
    // !! Order corresponds to proper `workoutTypeID`
    case biking = 0
    case running
    case fe
    case running_track
    case running_trail
    case running_treadmill
    case walking
    case walking_speed
    case walking_nordic
    case hiking
    case mountaineering
    case biking_cyclecross
    case biking_indoor
    case biking_mountain
    case biking_recumbent
    case biking_road
    case biking_track
    case biking_motocycling
    case fe_general
    case fe_treadmill
    case fe_elliptical
    case fe_bike
    case fe_rower
    case fe_climber
    case swimming_lap
    case swimming_open_water
    case snowboarding
    case skiing
    case skiing_downhill
    case skiingcross_country
    case skating
    case skating_ice
    case skating_inline
    case long_boarding
    case sailing
    case windsurfing
    case canoeing
    case kayaking
    case rowing
    case kiteboarding
    case stand_up_paddle_board
    case workout
    case cardio_class
    case stair_climber
    case wheelchair
    case golfing
    case other
    case biking_indoor_cycling_class = 49
    case walking_treadmill = 56
    case biking_indoor_trainer = 61
    case multisport = 62
    case transition = 63
    case ebiking = 64
    case tickr_offline = 65
    case yoga = 66
    case unknown = 255
    case invalid
}

extension WahooActivityType: Codable {
    init(from decoder: Decoder) throws {
        self = try WahooActivityType(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .invalid
    }
}

struct WahooActivitiesResponse: Codable {
    let activities: [WahooActivity]
    let total, page, perPage: Int
    let order, sort: String
    
    enum CodingKeys: String, CodingKey {
        case activities = "workouts"
        case total, page
        case perPage = "per_page"
        case order, sort
    }
}

struct WahooActivity: Codable {
    let activityId: Int
    let starts: Date
    let minutes: Float
    let name: String
    
    let workoutToken: String
    let workoutTypeID: WahooActivityType
    let createdAt: String
    let updatedAt: String
    
    let summary: WahooActivitySummary?
    
    enum CodingKeys: String, CodingKey {
        case activityId = "id"
        case starts, minutes, name
        case workoutToken = "workout_token"
        case workoutTypeID = "workout_type_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case summary = "workout_summary"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        activityId = try values.decode(Int.self, forKey: .activityId)
        starts = try values.decode(Date.self, forKey: .starts)
        minutes = try values.decode(Float.self, forKey: .minutes)
        name = try values.decode(String.self, forKey: .name)
        workoutToken = try values.decode(String.self, forKey: .workoutToken)
        workoutTypeID = try values.decode(WahooActivityType.self, forKey: .workoutTypeID)
        createdAt = try values.decode(String.self, forKey: .createdAt)
        updatedAt = try values.decode(String.self, forKey: .updatedAt)
        summary = try values.decodeIfPresent(WahooActivitySummary.self, forKey: .summary)
    }
}

fileprivate struct WahooActivityFile: Codable {
    let url: String
}

struct WahooActivitySummary: Codable {
    let id: Int
    let heartRateAvg: Float
    let powerBikeTssLast: Float
    let durationPausedAccum: Float
    let ascentAccum: Float
    let distanceAccum, workAccum: Float
    fileprivate let file: WahooActivityFile?
    let createdAt: Date
    let cadenceAvg: Float
    let durationTotalAccum: Float
    let powerBikeNPLast: Float
    let speedAvg: Float
    let updatedAt: Date
    let caloriesAccum: Float
    let durationActiveAccum: Float
    let powerAvg: Float
    
    var fitFileURL: URL? {
        guard let file = file else { return nil }
        return URL(string: file.url)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case heartRateAvg = "heart_rate_avg"
        case powerBikeTssLast = "power_bike_tss_last"
        case durationPausedAccum = "duration_paused_accum"
        case ascentAccum = "ascent_accum"
        case distanceAccum = "distance_accum"
        case workAccum = "work_accum"
        case file
        case createdAt = "created_at"
        case cadenceAvg = "cadence_avg"
        case durationTotalAccum = "duration_total_accum"
        case powerBikeNPLast = "power_bike_np_last"
        case speedAvg = "speed_avg"
        case updatedAt = "updated_at"
        case caloriesAccum = "calories_accum"
        case durationActiveAccum = "duration_active_accum"
        case powerAvg = "power_avg"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        heartRateAvg = try values.decodeStringToFloat(for: .heartRateAvg)
        powerBikeTssLast = try values.decodeStringToFloat(for: .powerBikeTssLast)
        durationPausedAccum = try values.decodeStringToFloat(for: .durationPausedAccum)
        ascentAccum = try values.decodeStringToFloat(for: .ascentAccum)
        distanceAccum = try values.decodeStringToFloat(for: .distanceAccum)
        workAccum = try values.decodeStringToFloat(for: .workAccum)
        createdAt = try values.decode(Date.self , forKey: .createdAt)
        cadenceAvg = try values.decodeStringToFloat(for: .cadenceAvg)
        durationTotalAccum = try values.decodeStringToFloat(for: .durationTotalAccum)
        powerBikeNPLast = try values.decodeStringToFloat(for: .powerBikeNPLast)
        speedAvg = try values.decodeStringToFloat(for: .speedAvg)
        updatedAt = try values.decode(Date.self , forKey: .updatedAt)
        caloriesAccum = try values.decodeStringToFloat(for: .caloriesAccum)
        durationActiveAccum = try values.decodeStringToFloat(for: .durationActiveAccum)
        powerAvg = try values.decodeStringToFloat(for: .powerAvg)
        file = try values.decode(WahooActivityFile.self, forKey: .file)
    }
}

fileprivate extension KeyedDecodingContainer {
    func decodeStringToFloat(for key: Key) throws -> Float {
        guard let string = try decodeIfPresent(String.self, forKey: key) else {
            return 0.0
        }
        return Float(string) ?? 0.0
    }
}

// MARK: - Activity

extension WahooActivity: Activity {
    
    var id: String {
        "wahoo_\(activityId)"
    }
    
    var activityType: ActivityType {
        ActivityType.from(wahooActivityType: workoutTypeID)
    }
    
    var distance: Float {
        Float(summary?.distanceAccum ?? 0.0)
    }
    
    var movingTime: TimeInterval {
        TimeInterval(summary?.durationActiveAccum ?? 0.0)
    }
    
    var startDate: Date {
        starts
    }
    
    var endDate: Date {
        startDate.addingTimeInterval(movingTime)
    }
    
    var startDateLocal: Date {
        starts.convertFromTimeZone(TimeZone(identifier: "UTC")!,
                                   toTimeZone: Calendar.current.timeZone)
    }
    
    var endDateLocal: Date {
        endDate.convertFromTimeZone(TimeZone(identifier: "UTC")!,
                                    toTimeZone: Calendar.current.timeZone)

    }
    
    var activeCalories: Float {
        summary?.caloriesAccum ?? 0.0
    }
    
    var totalElevationGain: Float {
        summary?.ascentAccum ?? 0.0
    }
    
    var stepCount: Int? {
        nil
    }

    var workoutSource: HealthKitWorkoutSource? {
        return nil
    }
    
    var clipsRoute: Bool {
        return false
    }
}
