// Licensed under the Any Distance Source-Available License
//
//  UserDefaults+Recording.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/27/22.
//

import Foundation

extension NSUbiquitousKeyValueStore {
    func goals(for activityType: ActivityType) -> [RecordingGoal] {
        if let goals = goalDictionary[activityType] {
            return goals
        }

        if activityType.showsRoute {
            return RecordingGoal.defaultsForAllTypes(withUnit: ADUser.current.distanceUnit)
        } else {
            return RecordingGoal.defaults(for: [.open, .time, .calories],
                                          unit: ADUser.current.distanceUnit)
        }
    }

    func setGoals(_ goals: [RecordingGoal], for activityType: ActivityType) {
        goalDictionary[activityType] = goals
    }

    func selectedGoalIdx(for activityType: ActivityType) -> Int {
        return selectedGoalIndexDictionary[activityType] ?? 1
    }

    func setSelectedGoalIdx(_ idx: Int, for activityType: ActivityType) {
        selectedGoalIndexDictionary[activityType] = idx
    }
    
    var defaultRecordingSettings: RecordingSettings {
        get {
            if let encoded = data(forKey: "recordingSettings"),
               let decoded = try? JSONDecoder().decode(RecordingSettings.self, from: encoded) {
                return decoded
            }
            
            return RecordingSettings()
        }
        
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                set(encoded, forKey: "recordingSettings")
                WatchPreferences.shared.sendPreferencesToWatch()
            }
        }
    }

    private var goalDictionary: [ActivityType: [RecordingGoal]] {
        get {
            if let data = data(forKey: "goalDictionary") {
                return (try? JSONDecoder().decode([ActivityType: [RecordingGoal]].self, from: data)) ?? [:]
            }
            return [:]
        }

        set {
            if let encodedData = try? JSONEncoder().encode(newValue) {
                set(encodedData, forKey: "goalDictionary")
            }
        }
    }

    private var selectedGoalIndexDictionary: [ActivityType: Int] {
        get {
            if let data = data(forKey: "selectedGoalIndexDictionary") {
                return (try? JSONDecoder().decode([ActivityType: Int].self, from: data)) ?? [:]
            }
            return [:]
        }

        set {
            if let encodedData = try? JSONEncoder().encode(newValue) {
                set(encodedData, forKey: "selectedGoalIndexDictionary")
            }
        }
    }
}
