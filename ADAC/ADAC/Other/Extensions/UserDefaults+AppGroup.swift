// Licensed under the Any Distance Source-Available License
//
//  UserDefaults+AppGroup.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/29/21.
//

import Foundation

extension UserDefaults {
    static let appGroup = UserDefaults(suiteName: "group.com.anydistance")!

    var goalProgress: Float {
        get {
            return float(forKey: "goalProgress")
        }

        set {
            set(newValue, forKey: "goalProgress")
        }
    }

    var goalActivityType: ActivityType {
        get {
            let raw = string(forKey: "goalActivityType") ?? ""
            return ActivityType(rawValue: raw) ?? .run
        }

        set {
            set(newValue.rawValue, forKey: "goalActivityType")
        }
    }

    var doesGoalExist: Bool {
        get {
            return bool(forKey: "doesGoalExist")
        }

        set {
            set(newValue, forKey: "doesGoalExist")
        }
    }
}
