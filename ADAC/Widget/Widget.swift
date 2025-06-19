// Licensed under the Any Distance Source-Available License
//
//  Widget.swift
//  Widget
//
//  Created by Daniel Kuntz on 1/22/21.
//

import WidgetKit
import SwiftUI
import Intents

@main
struct ADACWidgets: WidgetBundle {
    var body: some Widget {
        GoalWidget()

        if #available(iOS 16.1, *) {
            RecordingActivityWidget()
        }
    }
}

struct Widget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GoalWidgetEntryView()
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            if #available(iOS 16.1, *) {
                let attributes = RecordingLiveActivityAttributes(activityType: .bikeRide,
                                                                 unit: .miles,
                                                                 goal: RecordingGoal(type: .distance, unit: .miles, target: 10000))
                let state = RecordingLiveActivityAttributes.ActivityState(uptime: 0,
                                                                          state: .recording,
                                                                          duration: 322.1,
                                                                          distance: 444.2,
                                                                          elevationAScended: 231.0,
                                                                          pace: 632.0,
                                                                          avgSpeed: 31.0,
                                                                          totalCalories: 125.1,
                                                                          goalProgress: 0.6)
                LockScreenLiveActivityView(attributes: attributes, state: state)
            }
        }
    }
}
