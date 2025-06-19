// Licensed under the Any Distance Source-Available License
//
//  RecordingLiveActivityAttributes.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/15/22.
//

import Foundation
#if os(iOS)
import ActivityKit
#endif

struct RecordingLiveActivityAttributes: Codable {
    public struct ContentState: Codable, Hashable {
        var uptime: TimeInterval
        var state: iPhoneActivityRecordingState
        var duration: TimeInterval
        var distance: Double
        var elevationAScended: Double
        var pace: TimeInterval
        var avgSpeed: Double
        var totalCalories: Double
        var goalProgress: Float
    }

    var activityType: ActivityType
    var unit: DistanceUnit
    var goal: RecordingGoal
}

#if os(iOS)
extension RecordingLiveActivityAttributes: ActivityAttributes {
    public typealias ActivityState = ContentState
}
#endif

struct RecordingLiveActivityData: Codable {
    var attributes: RecordingLiveActivityAttributes
    var state: RecordingLiveActivityAttributes.ContentState
}
