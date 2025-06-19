// Licensed under the Any Distance Source-Available License
//
//  CollectibleType.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/1/21.
//

import UIKit

enum CollectibleType: Codable, RawRepresentable, Equatable {
    case location(CityMedal)
    case locationstate(StateMedal)
    case goal(Int)
    case goal_new(GoalMedal)
    case special(SpecialMedal)
    case activity(DistanceMedal)
    case totalDistance(DistanceMedal)
    case remote(RemoteCollectible)

    case remoteUnknown(String) // Remote collectibles which we can't decode for some reason.
                               // Keep them in ADUser's collectibles list but don't show them in the UI.

    // MARK: - Equatable

    static func == (lhs: CollectibleType, rhs: CollectibleType) -> Bool {
        // Old and new goal CollectibleType are equal if they have the same medal number
        switch (lhs, rhs) {
        case let (.goal_new(goalA), .goal(medalNumberB)):
            return goalA.medalNumber == medalNumberB
        case let (.goal(medalNumberA), .goal_new(goalB)):
            return medalNumberA == goalB.medalNumber
        default:
            return lhs.rawValue == rhs.rawValue
        }
    }

    // MARK: - RawRepresentable

    var rawValue: String {
        switch self {
        case .location(let l):
            return "location_\(l.rawValue)"
        case .locationstate(let l):
            return "locationstate_\(l.rawValue)"
        case .goal(let number):
            return "goal_\(number)"
        case .goal_new(let goal):
            do {
                let serializedGoal = try JSONEncoder().encode(goal)
                let goalString = String(data: serializedGoal, encoding: .utf8)!
                return "goalnew_" + goalString
            } catch {
                print("Error serializing goal string: \(error.localizedDescription)")
            }

            return ""
        case .special(let type):
            return "special_\(type.rawValue)"
        case .activity(let distance):
            return "activity_\(distance.rawValue)"
        case .totalDistance(let distance):
            return "totaldistance_\(distance.rawValue)"
        case .remote(let type):
            return "remote_\(type.rawValue)"
        case .remoteUnknown(let remainder):
            return "remote_\(remainder)"
        }
    }
    
    var rawValueWithoutType: String {
        return rawValue.components(separatedBy: "_").dropFirst().joined(separator: "_")
    }

    init?(rawValue: String) {
        guard let type = rawValue.components(separatedBy: "_").first else {
            return nil
        }

        let remainder = String(rawValue.dropFirst(type.count + 1))

        switch type {
        case "location":
            if let location = CityMedal(rawValue: remainder) {
                self = CollectibleType.location(location)
                return
            }
        case "locationstate":
            if let location = StateMedal(rawValue: remainder) {
                self = CollectibleType.locationstate(location)
                return
            }
        case "goal":
            if let number = Int(remainder),
               number >= 1 && number <= 15 {
                self = CollectibleType.goal(number)
                return
            }
        case "goalnew":
            do {
                let goal = try JSONDecoder().decode(GoalMedal.self,
                                                    from: remainder.data(using: .utf8)!)
                self = CollectibleType.goal_new(goal)
                return
            } catch {
                print("Error decoding achievement goal in AchievementType: \(error.localizedDescription)")
            }
        case "special":
            if let type = SpecialMedal(rawValue: remainder) {
                self = CollectibleType.special(type)
                return
            }
        case "remote":
            if let type = CollectibleLoader.shared.remoteCollectible(withRawValue: remainder) {
                self = CollectibleType.remote(type)
                return
            } else {
                self = CollectibleType.remoteUnknown(remainder)
                return
            }
        case "activity":
            if let distance = DistanceMedal(rawValue: remainder) {
                self = CollectibleType.activity(distance)
                return
            }
        case "totaldistance":
            if let distance = DistanceMedal(rawValue: remainder) {
                self = CollectibleType.totalDistance(distance)
                return
            }
        default:
            return nil
        }

        return nil
    }

    // MARK: - Convenience Accessors

    var totalDistance: Float? {
        switch self {
        case .totalDistance(let distance):
            return distance.unitlessDistance
        default:
            return nil
        }
    }

    var confettiColors: [UIColor] {
        switch self {
        case .location(let l):
            return l.confettiColors
        case .locationstate(let l):
            return l.confettiColors
        case .goal(let number):
            return GoalMedal.confettiColors(forNumber: number)
        case .goal_new(let goal):
            return GoalMedal.confettiColors(forNumber: goal.medalNumber)
        case .special(let type):
            return type.confettiColors
        case .activity(let distance), .totalDistance(let distance):
            return distance.confettiColors
        case .remote(let type):
            return type.confettiColors
        case .remoteUnknown(_):
            return []
        }
    }

    var blurb: String {
        switch self {
        case .location(let l):
            return l.blurb
        case .locationstate(let l):
            return l.blurb
        case .goal(_), .goal_new(_):
            return GoalMedal.randomBlurb()
        case .special(let type):
            return type.blurb
        case .activity(let distance), .totalDistance(let distance):
            return distance.blurb
        case .remote(let type):
            return type.blurb
        case .remoteUnknown(_):
            return ""
        }
    }

    var hintBlurb: String {
        switch self {
        case .location(let l):
            return l.hintBlurb
        case .locationstate(let l):
            return l.hintBlurb
        case .goal(_), .goal_new(_):
            return GoalMedal.hintBlurb
        case .special(let type):
            return type.hintBlurb
        case .activity(let distance), .totalDistance(let distance):
            return distance.hintBlurb
        case .remote(let type):
            return type.hintBlurb
        case .remoteUnknown(_):
            return ""
        }
    }
}
