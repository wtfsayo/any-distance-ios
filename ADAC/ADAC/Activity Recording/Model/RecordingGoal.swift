// Licensed under the Any Distance Source-Available License
//
//  RecordingGoal.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/29/22.
//

import Foundation
import UIKit

enum RecordingGoalType: String, Codable, CaseIterable {
    case open
    case time
    case distance
    case calories

    var displayName: String {
        switch self {
        case .open:
            return "Just Go"
        case .time:
            return "Time Goal"
        case .distance:
            return "Distance Goal"
        case .calories:
            return "Calorie Goal"
        }
    }

    func unitString(forDistanceUnit unit: DistanceUnit) -> String {
        switch self {
        case .open:
            return ""
        case .time:
            return "MINUTES"
        case .distance:
            return unit.fullName.uppercased()
        case .calories:
            return "ACTIVE CALORIES"
        }
    }

    var promptText: String {
        switch self {
        case .open:
            return "Just Go"
        case .time:
            return "Set a time goal"
        case .distance:
            return "Set a distance goal"
        case .calories:
            return "Set a calorie goal"
        }
    }

    var color: UIColor {
        switch self {
        case .open:
            return UIColor.adGreen
        case .time:
            return UIColor(hex: "FE2727")
        case .distance:
            return UIColor(hex: "0A84FF")
        case .calories:
            return UIColor(hex: "ED7E11")
        }
    }

    var lighterColor: UIColor {
        switch self {
        case .open:
            return UIColor.adGreen
        case .time:
            return UIColor(hex: "FE2727")
        case .distance:
            return UIColor(hex: "11BFED")
        case .calories:
            return UIColor.adOrangeLighter
        }
    }

    #if os(watchOS)
    var glyph: UIImage? {
        switch self {
        case .open:
            return UIImage(systemName: "arrow.right.circle.fill")
        case .time:
            return UIImage(named: "glyph_time")
        case .distance:
            return iPhonePreferences.shared.distanceUnit == .miles ? UIImage(named: "glyph_distance_mi_filled") : UIImage(named: "glyph_distance_km_filled")
        case .calories:
            return UIImage(named: "glyph_calories")
        }
    }
    #else
    func glyph(forDistanceUnit unit: DistanceUnit) -> UIImage? {
        switch self {
        case .open:
            return nil
        case .time:
            return UIImage(named: "glyph_time")?.resized(withNewWidth: 22)
        case .distance:
            return unit.filledGlyph?.resized(withNewWidth: 19)
        case .calories:
            return UIImage(named: "glyph_calories")?.resized(withNewWidth: 15)
        }
    }
    #endif

    var defaultTarget: Float {
        switch self {
        case .open:
            return 0.0
        case .time:
            return 1800.0
        case .distance:
            return 1.0
        case .calories:
            return 400.0
        }
    }

    var targetRange: ClosedRange<Float> {
        switch self {
        case .open:
            return 0.0...0.0
        case .time:
            return buttonIncrement...86400.0
        case .distance:
            return buttonIncrement...1000.0
        case .calories:
            return buttonIncrement...10000.0
        }
    }

    var slideIncrement: Float {
        switch self {
        case .open:
            return 0.0
        case .time:
            return 300.0
        case .distance:
            return 0.5
        case .calories:
            return 10
        }
    }
    
    var buttonIncrement: Float {
        switch self {
        case .open:
            return 0.0
        case .time:
            return 60.0
        case .distance:
            return 0.1
        case .calories:
            return 1
        }
    }

    var crownIncrement: Float {
        switch self {
        case .open:
            return 0.0
        case .time:
            return 1.0
        case .distance:
            return 0.01
        case .calories:
            return 0.1
        }
    }

    #if !TARGET_IS_EXTENSION
    var statisticType: StatisticType? {
        switch self {
        case .open:
            return nil
        case .time:
            return .time
        case .distance:
            return .distance
        case .calories:
            return .activeCal
        }
    }
    #endif
}

class RecordingGoal: ObservableObject, Codable, Equatable {
    static func ==(lhs: RecordingGoal, rhs: RecordingGoal) -> Bool {
        return lhs === rhs
    }

    let type: RecordingGoalType
    @Published var unit: DistanceUnit
    @Published private(set) var target: Float

    private enum CodingKeys: String, CodingKey {
        case type, unit, target
    }

    init(type: RecordingGoalType, unit: DistanceUnit, target: Float) {
        self.type = type
        self.unit = unit
        self.target = target.clamped(to: type.targetRange)
    }

    static func defaultsForAllTypes(withUnit unit: DistanceUnit) -> [RecordingGoal] {
        return defaults(for: RecordingGoalType.allCases, unit: unit)
    }

    static func defaults(for types: [RecordingGoalType], unit: DistanceUnit) -> [RecordingGoal] {
        return types.map { RecordingGoal(type: $0, unit: unit, target: $0.defaultTarget) }
    }

    var formattedTarget: String {
        switch type {
        case .open:
            return ""
        case .time:
            return TimeInterval(target).timeFormatted(includeSeconds: false)
        case .distance:
            return String(target.rounded(toPlaces: 1))
        case .calories:
            return String(Int(target))
        }
    }

    var formattedUnitString: String {
        switch type {
        case .time:
            return (target >= 60 * 60) ? "HOURS" : (target == 60) ? "MINUTE" : "MINUTES"
        default:
            return type.unitString(forDistanceUnit: unit)
        }
    }

    var formattedShortUnitString: String {
        switch type {
        case .time:
            return (target >= 60 * 60) ? "HRS" : "MIN"
        case .distance:
            return unit.abbreviation.uppercased()
        case .calories:
            return "CAL"
        default:
            return ""
        }
    }

    var shortFormattedTargetWithUnit: String {
        switch type {
        case .time:
            var string = ""
            let hrs = Int(target) / 3600
            if hrs > 0 {
                string += "\(hrs)H "
            }

            let min = Int(target) / 60 % 60
            if min > 0 {
                string += "\(min)" + (hrs > 0 ? "M" : "MIN")
            }

            return string
        case .open:
            return "NO GOAL"
        default:
            return formattedTarget + formattedShortUnitString
        }
    }

    var lowercasedFormattedTargetWithUnit: String {
        switch type {
        case .open:
            return shortFormattedTargetWithUnit.capitalized
        default:
            return shortFormattedTargetWithUnit.lowercased()
        }
    }

    var iMessageFormatted: String {
        switch type {
        case .open:
            return ""
        case .time:
            return shortFormattedTargetWithUnit.lowercased() + " "
        case .distance:
            return formattedTarget + unit.abbreviation + " "
        case .calories:
            return formattedTarget + "cal "
        }
    }

    func setTarget(_ newTarget: Float) {
        self.target = newTarget.clamped(to: type.targetRange)
        self.objectWillChange.send()
    }

    // MARK: - Codable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(target, forKey: .target)
        try container.encode(unit, forKey: .unit)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(RecordingGoalType.self, forKey: .type)
        target = try container.decode(Float.self, forKey: .target)
        unit = try container.decode(DistanceUnit.self, forKey: .unit)
    }
}
