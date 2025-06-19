// Licensed under the Any Distance Source-Available License
//
//  LiveActivityManager.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/25/23.
//

import UIKit
import ActivityKit

class LiveActivityManager {
    static let shared = LiveActivityManager()

    @available(iOS 16.1, *)
    var liveActivity: ActivityKit.Activity<RecordingLiveActivityAttributes>? {
        get {
            return _liveActivity as? ActivityKit.Activity<RecordingLiveActivityAttributes>
        }

        set {
            _liveActivity = newValue
        }
    }
    var _liveActivity: Any?
    var liveActivityUptime: TimeInterval = 0

    // MARK: - iPhone ActivityRecorder

    func startLiveActivity(for recorder: ActivityRecorder) {
//        if #available(iOS 16.1, *) {
//            if let existingActivity = ActivityKit.Activity.activities.first as? ActivityKit.Activity<RecordingLiveActivityAttributes> {
//                self.liveActivity = existingActivity
//                return
//            }
//        }

        guard iAPManager.shared.hasSuperDistanceFeatures else {
            return
        }

        let initialState = RecordingLiveActivityAttributes.ActivityState(uptime: liveActivityUptime,
                                                                         state: recorder.state,
                                                                         duration: recorder.duration,
                                                                         distance: recorder.distanceInUnit,
                                                                         elevationAScended: recorder.elevationAscended,
                                                                         pace: recorder.pace,
                                                                         avgSpeed: recorder.avgSpeed,
                                                                         totalCalories: recorder.totalCalories,
                                                                         goalProgress: recorder.goalProgress)
        let attributes = RecordingLiveActivityAttributes(activityType: recorder.activityType,
                                                         unit: recorder.unit,
                                                         goal: recorder.goal)
        startLiveActivity(with: attributes, initialState: initialState)
    }

    func updateLiveActivity(for recorder: ActivityRecorder) {
        guard iAPManager.shared.hasSuperDistanceFeatures else {
            return
        }

        Task(priority: .userInitiated) {
            let updatedLiveActivityState = RecordingLiveActivityAttributes.ActivityState(uptime: liveActivityUptime,
                                                                                         state: recorder.state,
                                                                                         duration: recorder.duration,
                                                                                         distance: recorder.distanceInUnit,
                                                                                         elevationAScended: recorder.elevationAscended,
                                                                                         pace: recorder.pace,
                                                                                         avgSpeed: recorder.avgSpeed,
                                                                                         totalCalories: recorder.totalCalories,
                                                                                         goalProgress: recorder.goalProgress)
            await self.updateLiveActivity(with: updatedLiveActivityState)
        }
    }

    // MARK: - Watch ActivityRecorder

    func updateForWatchActivity(with data: RecordingLiveActivityData) {
        guard iAPManager.shared.hasSuperDistanceFeatures else {
            return
        }

        if #available(iOS 16.1, *) {
            if liveActivity == nil {
                startLiveActivity(with: data.attributes,
                                  initialState: data.state)
            } else {
                let isFinished = data.state.state == .saved ||
                                 data.state.state == .discarded ||
                                 data.state.state == .couldNotSave
                if isFinished {
                    Task {
                        await endLiveActivity()
                    }
                } else {
                    Task {
                        var data = data
                        data.state.uptime = liveActivityUptime
                        await updateLiveActivity(with: data.state)
                    }
                }
            }
        }
    }

    // MARK: - General Functions

    func startLiveActivity(with attributes: RecordingLiveActivityAttributes,
                           initialState: RecordingLiveActivityAttributes.ActivityState) {
        do {
            if #available(iOS 16.1, *) {
                print("starting")
                self.liveActivity = try ActivityKit.Activity.request(attributes: attributes,
                                                                     contentState: initialState)
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    func updateLiveActivity(with state: RecordingLiveActivityAttributes.ActivityState) async {
        if #available(iOS 16.1, *) {
            await self.liveActivity?.update(using: state)
        }
    }

    func endLiveActivity() async {
        if #available(iOS 16.1, *) {
            await self.liveActivity?.end(dismissalPolicy: .immediate)
            self.liveActivity = nil
        }
    }
}
