// Licensed under the Any Distance Source-Available License
//
//  Activity.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/21/22.
//

import Foundation
import CoreLocation
import HealthKit

protocol Activity: ActivityTableViewDataClass {
    /// `id` should be namespaced to their type to avoid conflicts, ex: "wahoo_12345"
    var id: String { get }
    
    var activityType: ActivityType { get }
    var distance: Float { get } // meters
    var movingTime: TimeInterval { get }
    var startDate: Date { get } // UTC
    var startDateLocal: Date { get } // startDate in the user's current time zone
    var endDate: Date { get } // UTC
    var endDateLocal: Date { get } // endDate in the user's current time zone
    var coordinates: [CLLocation] { get async throws }
    var splits: [Split] { get async throws }
    var stepCount: Int? { get }
    var workoutSource: HealthKitWorkoutSource? { get }
    var clipsRoute: Bool { get }
    
    //
    var activeCalories: Float { get }
    var totalElevationGain: Float { get }
}

// Workaround for not being able to declare `Activity` as `Identifiable`
struct ActivityIdentifiable: Identifiable, Hashable {
    
    var id: String {
        activity.id
    }
    
    // MARK: - Private
    
    let activity: Activity
    
    // MARK: - Init
        
    init(activity: Activity) {
        self.activity = activity
    }
    
    static func == (lhs: ActivityIdentifiable, rhs: ActivityIdentifiable) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var wasRecordedInAnyDistance: Bool {
        return (self.activity as? HKWorkout)?.workoutSource == .anyDistance
    }
}

// MARK: - Legacy Support

extension Activity {
    
    var legacyId: Int {
        Int(startDate.timeIntervalSince1970)
    }
    
}

// MARK: - Generic

fileprivate class FormatHelpers {
    
    static let shared = FormatHelpers()
    
    private init() {}
    
    lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/YY"
        return dateFormatter
    }()
    
    lazy var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

}

extension Float {
    
    func abbreviated() -> String {
        let number = self
        let abbrev = ["K", "M", "B", "T"]
        
        var absNumber = abs(number)
        var place = -1
        
        while absNumber > 999.0 {
            absNumber /= 1000.0
            place += 1
        }
        
        if let abbreviation = abbrev[safe: place] {
            return "\(absNumber.rounded(toPlaces: 1))\(abbreviation)"
        } else {
            return "\(self.rounded(toPlaces: 1))"
        }
    }
    
    private static var defaultUnit: DistanceUnit = .miles
    
    private var unit: DistanceUnit {
        return ADUser.current.distanceUnit ?? Self.defaultUnit
    }
    
    var metersToUserSelectedUnit: Float {
        return UnitConverter.meters(self, toUnit: unit)
    }
    
    var metersToUserSelectedUnitFormatted: String {
        return "\(metersToUserSelectedUnit.abbreviated()) \(unit.abbreviation)"
    }
    
    // for elevation, show it in "ft" if the selected unit is miles
    var elevationMetersToUserSelectedUnitFormatted: String {
        let abbreviation: String
        let converted: Float
        if unit == .miles {
            abbreviation = "ft"
            converted = UnitConverter.metersToFeet(self)
        } else {
            abbreviation = unit.abbreviation
            converted = metersToUserSelectedUnit
        }
        return "\(converted.abbreviated()) \(abbreviation)"
    }
}

extension Activity {
    var distanceInUserSelectedUnit: Float {
        return distance.metersToUserSelectedUnit
    }
    
    var elevationGainInUserSelectedUnit: Float {
        if ADUser.current.distanceUnit == .miles {
            return totalElevationGain * 3.281
        }

        return totalElevationGain
    }
    
    var averageSpeedInUserSelectedUnit: Float {
        if ADUser.current.distanceUnit == .miles {
            return averageSpeed * 2.237
        }

        return averageSpeed * 3.6
    }
    
    /// Returns seconds per mile or seconds per kilometer depending
    /// on the user's selected unit.
    var paceInUserSelectedUnit: TimeInterval {
        guard averageSpeed.isNormal && averageSpeed > 0.0 else {
            return 0.0
        }

        if ADUser.current.distanceUnit == .miles {
            return TimeInterval(1609.34 / averageSpeed)
        }

        return TimeInterval(1000 / averageSpeed)
    }

    var paceMeters: TimeInterval {
        if ADUser.current.distanceUnit == .miles {
            return paceInUserSelectedUnit / 1609.34
        }

        return paceInUserSelectedUnit / 1000.0
    }
    
    var averageSpeed: Float {
        (distance / Float(movingTime)).clamped(to: 0...10000)
    }
    
    var dateString: String {
        return FormatHelpers.shared.dateFormatter.string(from: startDate)
    }
    
    var sortDate: Date {
        startDateLocal
    }
    
    var formattedStepCount: String {
        guard let stepCount = stepCount else { return "0" }
        return FormatHelpers.shared.numberFormatter.string(from: NSNumber(value: stepCount)) ?? "\(stepCount)"
    }
}
