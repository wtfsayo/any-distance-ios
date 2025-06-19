// Licensed under the Any Distance Source-Available License
//
//  RecordingViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/20/23.
//

import UIKit
import SwiftUI

class RecordingViewController: SwiftUIViewController<RecordingView> {

    var model: RecordingViewModel?

    // MARK: - Setup

    override func createSwiftUIView() {
        if let state = NSUbiquitousKeyValueStore.default.activityRecorderState,
           UIApplication.shared.topViewController == nil {
            let recorder = ActivityRecorder(savedState: state)
            model = RecordingViewModel(recorder: recorder)
            swiftUIView = RecordingView(model: model!)
            ADTabBarController.current?.setSelectedTab(.track)
        } else {
            let type: ActivityType = ActivityListProvider.recentlyUsedActivities(limit: 1).first ?? .walk
            let selectedGoalIdx = NSUbiquitousKeyValueStore.default.selectedGoalIdx(for: type)
            let defaultGoal = RecordingGoal(type: .time, unit: ADUser.current.distanceUnit, target: 1800)
            let goal = NSUbiquitousKeyValueStore.default.goals(for: type)[safe: selectedGoalIdx] ?? defaultGoal
            let recorder = ActivityRecorder(activityType: type,
                                            goal: goal,
                                            unit: ADUser.current.distanceUnit,
                                            settings: NSUbiquitousKeyValueStore.default.defaultRecordingSettings)
            model = RecordingViewModel(recorder: recorder)
            swiftUIView = RecordingView(model: model!)
        }
    }
}
