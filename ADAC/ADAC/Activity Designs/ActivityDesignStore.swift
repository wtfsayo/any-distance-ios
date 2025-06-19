// Licensed under the Any Distance Source-Available License
//
//  ActivityDesignStore.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/24/22.
//

import Foundation

class ActivityDesignStore {
    
    typealias ActivityId = String
    
    internal let filename = "activity_designs.json"
    private let defaultActivityId: ActivityId = "default_activity"
    private let defaultStepCountId: ActivityId = "default_stepcount"
    
    static let shared = ActivityDesignStore()
    
    @Published private(set) var designs: [ActivityId: ActivityDesign] = [:]
    
    // MARK: - Private
    
    private var fileURL: URL {
        get throws {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true)
            return documentsDirectory.appendingPathComponent(filename)
        }
    }
    
    // MARK: - Init
    
    private init() {
        do {
            designs = try JSONDecoder().decode([ActivityId: ActivityDesign].self,
                                               from: Data(contentsOf: try fileURL))
        } catch {
            print("Error loading activity designs: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public
        
    func design(for activity: Activity) -> ActivityDesign {
        return designs[activity.id] ?? defaultDesign(for: activity)
    }

    func save(design: ActivityDesign, for activity: Activity) throws {
        designs[activity.id] = design

        if activity.activityType == .stepCount {
            designs[defaultStepCountId] = design
        } else {
            designs[defaultActivityId] = design
        }
        
        try JSONEncoder().encode(designs).write(to: try fileURL, options: .atomic)
    }
    
    // MARK: - Private
    
    private func defaultDesign(for activity: Activity) -> ActivityDesign {
        if activity.activityType == .stepCount,
           let defaultStepCountDesign = designs[defaultStepCountId] {
            return ActivityDesign(for: activity, withDefault: defaultStepCountDesign)
        } else if activity.activityType != .stepCount,
          let defaultActivityDesign = designs[defaultActivityId] {
            return ActivityDesign(for: activity, withDefault: defaultActivityDesign)
        }

        return ActivityDesign(for: activity)
    }
    
}
