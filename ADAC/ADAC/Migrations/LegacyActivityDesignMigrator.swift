// Licensed under the Any Distance Source-Available License
//
//  LegacyActivityDesignMigrator.swift
//  ADAC
//
//  Created by Jarod Luebbert on 5/2/22.
//

import Foundation
import CoreGraphics

extension ActivityDesign {
    
    init(from legacyDesign: LegacyActivityDesign) async {
        self.id = UUID().uuidString
        self.isStepCount = legacyDesign.isStepCountDesign ?? isStepCount
        self.legacyPhotoFilename = legacyDesign.photoFileName
        self.legacyFilteredPhotoFilename = legacyDesign.filteredPhotoFileName
        self.font = legacyDesign.font ?? font
        self.alignment = legacyDesign.alignment ?? alignment
        self.graphType = legacyDesign.graphType ?? graphType
        self.legacyVideoURL = legacyDesign.videoUrl
        
        // save image for all sizes
        if let image = LegacyActivityDesignCache.photo(with: legacyDesign.photoFileName) {
            await save(photo: image)
        }
        
        // statistics
        self.set(statisticType: .graph, enabled: legacyDesign.routeEnabled ?? false)
        self.set(statisticType: .stepCount, enabled: legacyDesign.isStepCountDesign ?? false)
        self.set(statisticType: .distance, enabled: legacyDesign.distanceEnabled ?? false)
        self.set(statisticType: .time, enabled: legacyDesign.timeEnabled ?? false)
        self.set(statisticType: .pace, enabled: legacyDesign.paceEnabled ?? false)
        self.set(statisticType: .activeCal, enabled: legacyDesign.activeCalEnabled ?? false)
        self.set(statisticType: .activityType, enabled: legacyDesign.activityTypeEnabled ?? false)
        self.set(statisticType: .elevationGain, enabled: legacyDesign.elevationEnabled ?? false)
        self.set(statisticType: .goal, enabled: legacyDesign.goalEnabled ?? false)
        self.set(statisticType: .location, enabled: legacyDesign.locationEnabled ?? false)
        
        self.photoFilter = legacyDesign.photoFilter ?? photoFilter
        self.photoZoom = legacyDesign.photoZoom ?? photoZoom
        if let x = legacyDesign.photoOffsetX, let y = legacyDesign.photoOffsetY {
            self.photoOffset = CGPoint(x: CGFloat(x), y: CGFloat(y))
        }
        self.videoMode = legacyDesign.videoMode ?? videoMode
        self.palette = legacyDesign.palette ?? palette
        self.cutoutShape = legacyDesign.cutoutShape ?? cutoutShape
        self.graphTransform = legacyDesign.routeTransform ?? graphTransform
    }
    
}

/// Only need this for the `id` that `ActivityDesignStore` uses when saving Designs
struct LegacyActivityWrapper: Activity {
    var paceInUserSelectedUnit: TimeInterval {
        legacyActivity.paceInUserSelectedUnit ?? 0.0
    }
    
    var activityType: ActivityType {
        legacyActivity.activityType ?? .unknown
    }
    
    var distance: Float {
        legacyActivity.distance ?? 0.0
    }
    
    var movingTime: TimeInterval {
        legacyActivity.movingTime ?? 0.0
    }
    
    var startDate: Date {
        legacyActivity.startDate ?? Date()
    }
    
    var startDateLocal: Date {
        legacyActivity.startDateLocal
    }
    
    var endDate: Date {
        legacyActivity.endDate ?? Date()
    }
    
    var endDateLocal: Date {
        legacyActivity.endDateLocal ?? Date()
    }
    
    var activeCalories: Float {
        Float(legacyActivity.activeCalories ?? 0)
    }
    
    var totalElevationGain: Float {
        legacyActivity.totalElevationGain ?? 0.0
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
    
    let id: String
    
    private let legacyActivity: LegacyActivity
    
    init(from legacyActivity: LegacyActivity) {
        self.legacyActivity = legacyActivity
        switch legacyActivity.service {
        case .appleHealth, .none:
            self.id = "health_kit_\(legacyActivity.hkWorkoutId)"
        case .wahoo:
            self.id = "wahoo_\(legacyActivity.id)"
        }
    }
    
}

class LegacyActivityDesignMigrator {
    
    private let userDefaultsMigrationKey = "hasMigratedLegacyActivityDesigns"
    
    private var hasMigrated: Bool {
        NSUbiquitousKeyValueStore.default.bool(forKey: userDefaultsMigrationKey)
    }
    
    func migrateActivityDesigns() async throws {
        guard !hasMigrated else { return }
        
        let designStore = ActivityDesignStore.shared
        let activities = LegacyActivityCache.allActivities()
        for activity in activities {
            let mockActivity = LegacyActivityWrapper(from: activity)

            if activity.goalMetDate != nil {
                ActivitiesData.shared.meetGoal(for: mockActivity)
            }
            
            guard let legacyDesign = LegacyActivityDesignCache.legacyDesign(for: "\(activity.id)") else {
                continue
            }
            let design = await ActivityDesign(from: legacyDesign)
            try designStore.save(design: design, for: mockActivity)
        }
        let stepCounts = LegacyStepCountCache.allDailyStepCounts()
        for stepCount in stepCounts {
            guard let legacyDesign = LegacyActivityDesignCache.legacyDesign(for: "\(stepCount.legacyId)") else {
                continue
            }
            let design = await ActivityDesign(from: legacyDesign)
            try designStore.save(design: design, for: stepCount)
        }
        
        NSUbiquitousKeyValueStore.default.set(true, forKey: userDefaultsMigrationKey)
    }
    
}
