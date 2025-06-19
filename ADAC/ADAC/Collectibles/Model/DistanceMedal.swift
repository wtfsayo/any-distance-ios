// Licensed under the Any Distance Source-Available License
//
//  CollectibleDistance.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/4/21.
//

import UIKit

enum DistanceMedal: String, CaseIterable {
    case k_5
    case k_10
    case half_marathon
    case full_marathon

    case mi_1
    case mi_10
    case mi_20
    case mi_30
    case mi_40
    case mi_50
    case mi_75
    case mi_100
    case mi_200
    case mi_300
    case mi_400
    case mi_500
    case mi_600
    case mi_700
    case mi_800
    case mi_900
    case mi_1000
    case mi_1100
    case mi_1200
    case mi_1300
    case mi_1400
    case mi_1500
    case mi_1600
    case mi_1700
    case mi_1800
    case mi_1900
    case mi_2000

    case km_1
    case km_20
    case km_30
    case km_40
    case km_50
    case km_75
    case km_100
    case km_200
    case km_300
    case km_400
    case km_500
    case km_600
    case km_700
    case km_800
    case km_900
    case km_1000
    case km_1100
    case km_1200
    case km_1300
    case km_1400
    case km_1500
    case km_1600
    case km_1700
    case km_1800
    case km_1900
    case km_2000

    /// These are unitless, representing miles or kilometers depending on the user's selected unit.
    static let activityCollectibleMaximumDistance: Float = 50
    static let totalDistanceCollectibleMinimumDistance: Float = 100

    /// Returns the allowed distance range in meters.
    var rangeMeters: Range<Float>? {
        switch self {
        case .k_5:
            return 4988..<7000
        case .k_10:
            return 9976..<12000
        case .half_marathon:
            return 21082..<42000
        case .full_marathon:
            return 42000..<Float.greatestFiniteMagnitude
        default:
            if let unit = associatedUnit {
                let lowerBound = UnitConverter.value(unitlessDistance, inUnitToMeters: unit)
                return lowerBound..<Float.greatestFiniteMagnitude
            }

            return nil
        }
    }

    var allowedActivityTypes: [ActivityType] {
        switch self {
        case .half_marathon, .full_marathon:
            return [.run]
        default:
            return ActivityType.allCases
        }
    }

    /// Basically just the number in the name. Returns the distance associated with this medal,
    /// expressed in the unit the medal is in.
    var unitlessDistance: Float {
        if let string = rawValue.components(separatedBy: "_").last,
           let distance = Float(string) {
            return distance
        }

        return 0
    }

    var associatedUnit: DistanceUnit? {
        if let string = rawValue.components(separatedBy: "_").first {
            switch string {
            case "mi":
                return .miles
            case "km":
                return .kilometers
            default:
                return nil
            }
        }

        return nil
    }

    var shorterDescription: String {
        switch self {
        case .k_5:
            return "5K"
        case .k_10:
            return "10K"
        case .half_marathon:
            return "Half Marathon"
        case .full_marathon:
            return "Full Marathon"
        default:
            return "\(Int(unitlessDistance))\(associatedUnit?.abbreviation.uppercased() ?? "")"
        }
    }

    var description: String {
        if shorterDescription.contains("Marathon") {
            return shorterDescription
        }

        return shorterDescription + " Medal"
    }

    /// Returns all DistanceMedals that fit the provided distance and unit (including 5K, 10K, half,
    /// full marathon)
    static func all(matchingDistance distance: Float,
                    unit: DistanceUnit,
                    activityType: ActivityType? = nil) -> [DistanceMedal] {
        var medals: [DistanceMedal] = []

        // Find all DistanceMedals with a range that contains the distance.
        let distanceMeters = UnitConverter.value(distance, inUnitToMeters: unit)
        let distancesInCorrectUnit = allCases.filter { $0.associatedUnit == unit || $0.associatedUnit == nil }
                                             .reversed()
        medals.append(contentsOf: distancesInCorrectUnit.filter { medal in
            let distanceIsInRange = medal.rangeMeters?.contains(distanceMeters) ?? false
            let activityTypeMatches: Bool = {
                if let activityType = activityType {
                    return medal.allowedActivityTypes.contains(activityType)
                }
                return true
            }()

            return distanceIsInRange && activityTypeMatches
        })

        return medals
    }

    /// Returns all DistanceMedals for total distance tracked, up to the provided distance
    static func allTotalDistanceMedals(forDistance distance: Float, unit: DistanceUnit) -> [DistanceMedal] {
        return all(matchingDistance: distance, unit: unit).filter { medal in
            medal.unitlessDistance >= totalDistanceCollectibleMinimumDistance && medal.associatedUnit == unit
        }
    }

    var confettiColors: [UIColor] {
        let goldAndBlackColors = [UIColor(realRed: 236, green: 181, blue: 112),
                                  UIColor(realRed: 160, green: 110, blue: 41),
                                  UIColor(realRed: 177, green: 134, blue: 77),
                                  UIColor(realRed: 44, green: 44, blue: 44)]
        if unitlessDistance < 100 {
            if self == .half_marathon || self == .full_marathon {
                return goldAndBlackColors
            }

            return [UIColor(realRed: 220, green: 220, blue: 220),
                    UIColor(realRed: 188, green: 188, blue: 188),
                    UIColor(realRed: 152, green: 152, blue: 152),
                    UIColor(realRed: 117, green: 117, blue: 117)]
        } else if unitlessDistance < 1000 {
            return [UIColor(realRed: 235, green: 182, blue: 113),
                    UIColor(realRed: 208, green: 184, blue: 141),
                    UIColor(realRed: 148, green: 110, blue: 48),
                    UIColor(realRed: 128, green: 84, blue: 27)]
        } else {
            return goldAndBlackColors
        }
    }

    var blurb: String {
        let unitName = associatedUnit?.fullName ?? "miles"
        let unitNameSingular = associatedUnit?.fullNameSingular ?? "mile"

        switch self {
        case .k_5:
            return "5K! Wonderful work. You are doing great."
        case .k_10:
            return "10K in the bag. Congrats and keep it up!"
        case .half_marathon:
            return "That's a half marathon. Well done and congratulations!"
        case .full_marathon:
            return "You completed a full marathon! Amazing effort and congratulations."
        case .mi_1, .km_1:
            return "1 \(unitNameSingular) is not nothing. Nice going!"
        case .mi_10:
            return "Extraordinary effort! 10 \(unitName) down."
        case .mi_20, .km_20:
            return "That's 20 \(unitName)! A big accomplishment. Congrats!"
        case .mi_30, .km_30:
            return "30 \(unitName). Super strong effort. Nice work!"
        case .mi_40, .km_40:
            return "A 40 \(unitNameSingular) accomplishment done. Nice!"
        case .mi_50, .km_50:
            return "You earned it. Fifty \(unitName) is no small feat!"
        case .mi_75, .km_75:
            return "Extraordinary effort! 75 \(unitName) down."
        case .mi_100, .km_100:
            return "Outstanding! The big 100. Well done!"
        case .mi_200, .km_200:
            return "Great work on 200 \(unitName). A big victory."
        case .mi_300, .km_300:
            return "What a feat! 300 \(unitName) done. Congrats!"
        case .mi_400, .km_400:
            return "That's 400 \(unitName)! A big accomplishment. Congrats!"
        case .mi_500, .km_500:
            return "500 \(unitName). Super strong effort. Nice work!"
        case .mi_600, .km_600:
            return "You earned it. 600 \(unitName) is no small feat!"
        case .mi_700, .km_700:
            return "A 700 \(unitNameSingular) accomplishment done. Nice!"
        case .mi_800, .km_800:
            return "Extraordinary effort! 800 \(unitName) down."
        case .mi_900, .km_900:
            return "900 \(unitName)! Wonderful work. You are doing great."
        case .mi_1000, .km_1000:
            return "Hold for applause. The big 1000 \(unitName). Well done!"
        case .mi_1100, .km_1100:
            return "Kudos! 1100 \(unitName) checked off. Great work!"
        case .mi_1200, .km_1200:
            return "A 1200 \(unitNameSingular) accomplishment done. Nice!"
        case .mi_1300, .km_1300:
            return "1300 \(unitName)! Wonderful work. You are doing great."
        case .mi_1400, .km_1400:
            return "Extraordinary effort! 1400 \(unitName) down."
        case .mi_1500, .km_1500:
            return "1500 \(unitName) is not nothing. Incredible effort!"
        case .mi_1600, .km_1600:
            return "You earned this! The 1600 \(unitName) collectible is yours."
        case .mi_1700, .km_1700:
            return "Phenomenal distance! 1700 \(unitName) is yours."
        case .mi_1800, .km_1800:
            return "Fantastic, that's how you do it. Well done on 1800 \(unitName)!"
        case .mi_1900, .km_1900:
            return "Unreal. Congratulations on 1900 \(unitName)!"
        case .mi_2000, .km_2000:
            return "Two thousand \(unitName)! Congratulations on an amazing effort."
        }
    }

    var hintBlurb: String {
        switch self {
        case .k_5:
            return "Earn this collectible by completing a 5K (3.1 mi / 5.0 km)."
        case .k_10:
            return "Earn this collectible by completing a 10K (6.2 mi / 10.0 km)."
        case .half_marathon:
            return "Earn this collectible by completing a half marathon (13.1 mi / 21.1 km)."
        case .full_marathon:
            return "Earn this collectible by completing a full marathon (26.2 mi / 42.2 km)."
        default:
            let unit = associatedUnit ?? .miles
            let unitName = (unitlessDistance > 1) ? unit.fullName : unit.fullNameSingular

            if unitlessDistance <= DistanceMedal.activityCollectibleMaximumDistance {
                return "Earn this collectible by completing an individual activity of \(Int(unitlessDistance)) \(unitName) or more."
            } else {
                return "Sync a total of at least \(Int(unitlessDistance)) \(unitName) to earn this collectible."
            }
        }
    }
}
