// Licensed under the Any Distance Source-Available License
//
//  StatisticType.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/22/20.
//

import Foundation
import UIKit

enum StatisticType: String, CaseIterable, Codable {
    case graph
    case stepCount
    case distance
    case activeCal
    case time
    case pace
    case elevationGain
    case location
    case activityType
    case goal

    static private let stepCountStats: [StatisticType] = [
        .graph, .stepCount, .distance, .activityType
    ]

    #if !os(watchOS)
    static func possibleStats(for activity: Activity) -> [StatisticType] {
        if activity.activityType == .stepCount {
            return stepCountStats
        } else {
            // TODO: this should be smarter and work through all activity types
            var stats: [StatisticType] = stats(for: activity)
            stats.append(.location)
            return stats
        }
    }

    static func stats(for activity: Activity) -> [StatisticType] {
        var stats: [StatisticType] = []
        
        if activity.activityType == .stepCount {
            stats.append(contentsOf: [.stepCount, .graph])
        }
        
        if activity.distance != 0.0 || activity.activityType == .stepCount {
            stats.append(.distance)
        }
        
        if activity.activeCalories != 0.0 {
            stats.append(.activeCal)
        }
        
        if activity.movingTime != 0.0 {
            stats.append(.time)
        }
        
        if activity.paceInUserSelectedUnit != 0.0 {
            stats.append(.pace)
        }
        
        if activity.totalElevationGain != 0.0 {
            stats.append(.elevationGain)
        }
        
        let goal = ADUser.current.goalToDisplay(forActivity: activity)
        if goal != nil {
            stats.append(.goal)
        }
        
        stats.append(.activityType)
        
        return stats
    }
    #endif

    var image: UIImage? {
        switch self {
        case .graph:
            return UIImage(named: "glyph_graph")
        case .stepCount:
            return UIImage(named: "glyph_pace")
        case .distance:
            #if os(watchOS)
            return UIImage(named: "glyph_distance_mi")
            #else
            return ADUser.current.distanceUnit == .miles ? UIImage(named: "glyph_distance_mi") : UIImage(named: "glyph_distance_km")
            #endif
        case .activeCal:
            return UIImage(named: "glyph_calories")
        case .time:
            return UIImage(named: "glyph_time")
        case .pace:
            return UIImage(named: "glyph_pace")
        case .elevationGain:
            return UIImage(named: "glyph_elevation")
        case .location:
            return UIImage(named: "glyph_location_big")
        case .activityType:
            return UIImage(named: "activity_steps")
        case .goal:
            return UIImage(named: "glyph_goal")
        }
    }

    var displayName: String {
        switch self {
        case .graph:
            return "Graph"
        case .stepCount:
            return "Step Count"
        case .distance:
            return "Distance"
        case .activeCal:
            return "Active Cal"
        case .time:
            return "Time"
        case .pace:
            return "Pace"
        case .elevationGain:
            return "Elevation"
        case .location:
            return "Location"
        case .activityType:
            return "Activity"
        case .goal:
            return "Goal"
        }
    }
    
    var fullDisplayName: String {
        switch self {
        case .activeCal:
            return "Calories"
        case .elevationGain:
            return "Elevation Gain"
        default:
            return displayName
        }
    }
    
    var calculationExplanation: String {
        switch self {
        case .time:
            return "Your activity time is calculated based on your time spent moving. Time spent paused is not counted here."
        case .distance:
            return "We use the GPS on your phone to follow your route and calculate accurate distance based on those GPS coordinates. We do this as GPS accuracy can be between 10-33 feet depending on the conditions and environment (Buildings! Trees! Weather!)."
        case .pace:
            return "Your pace is calculated by dividing your total moving time by your total recorded distance. Pace does not include time spent paused."
        case .activeCal:
            return "Calorie burn is calculated by an industry standard set of equations. Adding your weight in Settings will improve accuracy here. Please note: other factors (that we don’t collect or track) like age, temperature, body composition and more play a role in total calorie burn."
        default:
            return ""
        }
    }
    
    var color: UIColor {
        switch self {
        case .distance:
            return RecordingGoalType.distance.color
        case .time:
            return RecordingGoalType.time.color
        case .pace:
            return RecordingGoalType.open.color
        case .activeCal:
            return RecordingGoalType.calories.color
        default:
            return .black
        }
    }
}
