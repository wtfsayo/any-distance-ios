// Licensed under the Any Distance Source-Available License
//
//  ActivityDesign.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/22/22.
//

import Foundation
import UIKit

struct ActivityDesign: Codable, Equatable {
    
    enum Media: String, Codable {
        case none, fill, photo, video, arVideo
    }
    
    init(isStepCount: Bool) {
        self.id = UUID().uuidString
        self.isStepCount = isStepCount
        self.legacyPhotoFilename = nil
        self.legacyFilteredPhotoFilename = nil
        self.legacyVideoURL = nil
    }
    
    init(for activity: Activity) {
        let isStepCount = activity.activityType == .stepCount
        
        self.init(isStepCount: isStepCount)

        set(statisticType: .distance, enabled: activity.distance > 0.0 || isStepCount)
        set(statisticType: .elevationGain, enabled: false)
        set(statisticType: .pace, enabled: false)
        set(statisticType: .activeCal, enabled: false)
        set(statisticType: .stepCount, enabled: isStepCount)
        set(statisticType: .time, enabled: activity.movingTime > 0.0)
        set(statisticType: .location, enabled: activity.activityType.isDistanceBased)
        set(statisticType: .activityType, enabled: true)

        if isStepCount {
            graphType = .stepCount
        } else if activity.activityType.isDistanceBased {
            if iAPManager.shared.hasSuperDistanceFeatures {
                graphType = .route3d
            } else {
                graphType = .route2d
            }
        } else {
            graphType = iAPManager.shared.hasSuperDistanceFeatures ? .heartRate : .none
        }

        set(statisticType: .graph, enabled: true)
    }

    init(for activity: Activity, withDefault defaultDesign: ActivityDesign) {
        self.init(for: activity)

        for stat in StatisticType.allCases {
            // Only enable stats if they're already enabled to prevent showing stats for which
            // we have no data.
            let alreadyEnabled = self.shows(statisticType: stat)
            set(statisticType: stat,
                enabled: defaultDesign.shows(statisticType: stat) && alreadyEnabled)
        }

        if activity.activityType.isDistanceBased {
            if activity.workoutSource == .anyDistance {
                graphType = RecordingViewModel.mostRecentlySelectedRouteType
            } else {
                if defaultDesign.graphType == .heartRate {
                    graphType = .route2d
                } else {
                    graphType = defaultDesign.graphType
                }
            }
        } else if activity.activityType == .stepCount {
            graphType = .stepCount
        } else {
            graphType = .none
        }

        font = defaultDesign.font
        alignment = defaultDesign.alignment
        cutoutShape = defaultDesign.cutoutShape
    }
    
    // MARK: - Public
    
    let id: String
    
    var font: ADFont = .og
    var fill: Fill?
    var alignment: StatisticAlignment = .left
    var graphType: GraphType = .route2d
    
    private(set) var statisticsOptions = Set<StatisticType>()
    
    var photoZoom: Float = 1.0
    var photoOffset: CGPoint = .zero
    var photoFilter: PhotoFilter = .none
    
    var videoMode: VideoMode = .loop
    
    var graphTransform: CGAffineTransform = .identity
    var isStepCount: Bool = false
    var palette: Palette = .dark
    var cutoutShape: CutoutShape = .oval
    var media: Media = .none
    
    private enum CodingKeys: String, CodingKey {
        case id, font, alignment, graphType, statisticsOptions, photoZoom,
             photoOffset, photoFilter, legacyVideoURL, videoMode,
             graphTransform="routeTransform", // support legacy name
             isStepCount, palette, cutoutShape, legacyPhotoFilename,
             legacyFilteredPhotoFilename, fill, media
    }
    
    var hasSuperDistanceFeaturesEnabled: Bool {
        return (graphType.requiresSuperDistance ||
                palette.requiresSuperDistance ||
                photoFilter != .none ||
                cutoutShape.requiresSuperDistance)
    }
    
    // MARK: - Statistic Types
    
    mutating func toggle(statisticType: StatisticType) {
        set(statisticType: statisticType, enabled: !shows(statisticType: statisticType))
        
        // for step counts we don't show the "graphs" menu and instead
        // let you toggle the graph from stats
        if isStepCount && statisticType == .graph {
            graphType = shows(statisticType: .graph) ? .stepCount : .none
        }
    }
    
    mutating func set(statisticType: StatisticType, enabled: Bool) {
        if enabled {
            statisticsOptions.insert(statisticType)
        } else {
            statisticsOptions.remove(statisticType)
        }
    }
    
    func shows(statisticType: StatisticType) -> Bool {
        return statisticsOptions.contains(statisticType)
    }

    // MARK: - Legacy

    static let legacyCacheFileSuffix: String = "_activity_design.json"
    
    let legacyVideoURL: URL?
    let legacyPhotoFilename: String?
    let legacyFilteredPhotoFilename: String?
        
}
