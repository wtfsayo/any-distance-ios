// Licensed under the Any Distance Source-Available License
//
//  HealthActivity.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/12/21.
//

import UIKit
import CoreLocation
import HealthKit

enum ActivityService: String, Codable {
    case appleHealth, wahoo
}

/// An activity synced from HealthKit
final class LegacyActivity: ActivityTableViewDataClass, Codable {
    var id: Int
    var type: String?
    var distance: Float? /// meters
    var movingTime: TimeInterval?
    var startDateLocal: Date = Date() /// start date in the workout's local time zone
    var endDateLocal: Date? /// end date in the workout's local time zone
    var startDate: Date? /// start date in UTC
    var endDate: Date? /// end date in UTC
    var averageSpeed: Float?
    var activeCalories: Int?
    var totalElevationGain: Float? /// meters
    var _design: LegacyActivityDesign?
    var goalMetDate: Date?
    var sourceBundleId: String?

    var stravaId: Int? /// HKMetadataKeyExternalUUID for the activity created by the source application (Garmin, Strava, etc.)
    var totalEnergyBurned: Float?
    var temperature: Float? /// farenheit
    var hkWorkoutId: String = ""

    var hkWorkout: HKWorkout?
    var wahooActivity: WahooActivity?
    
    var mapImage: UIImage?
    var mapImagePalette: Palette?
    var miniMapImage: UIImage?
    var elevationGraphImage: UIImage?
    var elevationGraphImagePalette: Palette?
    var heartRateGraphImage: UIImage?
    var heartRateGraphImagePalette: Palette?
    var fetchedElevationData: [Float]?

    var heartRateData: [HeartRateSample]?
    var isLoadingHeartRateData: Bool = false
    var heartRateDataListeners: [((_ heartRates: [HeartRateSample]?) -> Void)] = []

    private enum CodingKeys: String, CodingKey {
        case id, type, distance, movingTime, startDateLocal, endDateLocal, averageSpeed, totalElevationGain, fetchedElevationData,
             stravaId, totalEnergyBurned, temperature, hkWorkoutId, goalMetDate, startDate, endDate, sourceBundleId, heartRateData, activeCalories, wahooActivity, service
    }

    var sortDate: Date {
        return startDateLocal
    }
    
    ///
    // where the Activity was initialized from, by default assume Apple Health
    var service: ActivityService? = .appleHealth
    ///
    // where an Activity created from an HKWorkout came from
    var source: HealthKitWorkoutSource? {
        guard let sourceBundleId = sourceBundleId else {
            return nil
        }

        return HealthKitWorkoutSource(rawValue: sourceBundleId)
    }
    ///

    var activityType: ActivityType? {
        guard let type = type else {
            return nil
        }

        return ActivityType(name: type)
    }

    var legacyDesign: LegacyActivityDesign {
        if let design = _design {
            return design
        }

        _design = LegacyActivityDesignCache.legacyDesign(for: "\(self.id)")
        return _design!
    }

    /// Returns miles or kilometers depending on the user's
    /// selected unit.
    var distanceInUserSelectedUnit: Float? {
        guard let distance = distance else {
            return nil
        }

        let unit = ADUser.current.distanceUnit
        return UnitConverter.meters(distance, toUnit: unit)
    }

    /// Returns minutes per mile or minutes per kilometer depending
    /// on the user's selected unit.
    var paceInUserSelectedUnit: TimeInterval? {
        guard let averageSpeed = averageSpeed,
              averageSpeed.isNormal else {
            return nil
        }

        if ADUser.current.distanceUnit == .miles {
            return TimeInterval(1609 / averageSpeed)
        }

        return TimeInterval(1000 / averageSpeed)
    }

    var averageSpeedInUserSelectedUnit: Float? {
        guard let averageSpeed = averageSpeed else {
            return nil
        }

        if ADUser.current.distanceUnit == .miles {
            return averageSpeed * 2.237
        }

        return averageSpeed * 3.6
    }

    /// Returns meters if the user's selected unit is meters, and feet if
    /// the user's selected unit is miles.
    var elevationGainInUserSelectedUnit: Float? {
        guard let elevationGain = totalElevationGain else {
            return nil
        }

        if ADUser.current.distanceUnit == .miles {
            return elevationGain * 3.281
        }

        return elevationGain
    }

    /// The file name to use when caching this activity.
    var cacheFileName: String {
        switch service {
        case .appleHealth, .none:
            return "\(id)\(Self.appleHealthCacheFileSuffix)"
        case .wahoo:
            return "\(id)\(Self.wahooCacheFileSuffix)"
        }
    }

    /// The suffix of the file name (including extension to use when
    /// caching this activity.
    static var appleHealthCacheFileSuffix: String {
        return "_activity_health.json"
    }
    
    static var wahooCacheFileSuffix: String {
        return "_activity_wahoo.json"
    }

    /// Apple Health synced activities have a UUID at the end. If this is a Health activity,
    /// it will return the bundle ID without the UUID at the end. Otherwise, it will return the
    /// original bundle ID.
    var shortenedSourceBundleId: String {
        guard let sourceBundleId = sourceBundleId else {
            return ""
        }

        if sourceBundleId.contains("com.apple.health") {
            return "com.apple.health"
        }

        return sourceBundleId
    }

    // MARK: - Init

    init(_ workout: HKWorkout) {
        hkWorkout = workout
        hkWorkoutId = workout.uuid.uuidString
        
        service = .appleHealth

        type = ActivityType.from(hkWorkoutType: workout.workoutActivityType, isDistanceNil: false).rawValue
        id = Int(workout.startDate.timeIntervalSince1970)
        distance = Float(workout.totalDistance?.doubleValue(for: .meter()) ?? 0)
        movingTime = workout.duration
        activeCalories = Int(workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)

        startDate = workout.startDate
        endDate = workout.endDate

        if let workoutTimeZone = TimeZone(identifier: workout.metadata?[HKMetadataKeyTimeZone] as? String ?? ""),
           let gmt = TimeZone(identifier: "GMT") {
            startDateLocal = workout.startDate.convertFromTimeZone(gmt, toTimeZone: workoutTimeZone)
            endDateLocal = workout.endDate.convertFromTimeZone(gmt, toTimeZone: workoutTimeZone)
        } else {
            startDateLocal = workout.startDate
            endDateLocal = workout.endDate
        }

        sourceBundleId = workout.sourceRevision.source.bundleIdentifier

        if let stravaUuid = workout.metadata?[HKMetadataKeyExternalUUID] as? String,
           let idString = stravaUuid.components(separatedBy: "/").last {
            stravaId = Int(idString)
        }

        averageSpeed = ((distance ?? 0) / Float(movingTime ?? 1)).clamped(to: 0...10000)
        totalEnergyBurned = Float(workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)

        let elevation = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity
        totalElevationGain = elevation?.doubleValue(for: .meter()).float()

        let temp = workout.metadata?[HKMetadataKeyWeatherTemperature] as? HKQuantity
        temperature = temp?.doubleValue(for: .degreeFahrenheit()).float()
    }

    init(id: Int) {
        self.id = id
    }

}

extension LegacyActivity: Equatable {
    static func == (lhs: LegacyActivity, rhs: LegacyActivity) -> Bool {
        return lhs.id == rhs.id
    }
}

