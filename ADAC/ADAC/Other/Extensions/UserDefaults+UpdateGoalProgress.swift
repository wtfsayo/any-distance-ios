// Licensed under the Any Distance Source-Available License
//
//  UserDefaults+UpdateGoalProgress.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/19/24.
//

import Foundation
import WidgetKit

extension UserDefaults {
    func updateGoalProgress() {
        guard let goal = ADUser.current.goals.first(where: { !$0.isCompleted }) else {
            doesGoalExist = false
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        doesGoalExist = true
        goalProgress = goal.distanceInSelectedUnit / goal.targetDistanceInSelectedUnit
        goalActivityType = goal.activityType
        WidgetCenter.shared.reloadAllTimelines()
    }
}
