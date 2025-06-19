// Licensed under the Any Distance Source-Available License
//
//  ActivitiesDataTests.swift
//  ADACTests
//
//  Created by Jarod Luebbert on 4/27/22.
//

import XCTest
import CoreLocation

@testable import ADAC

struct MockActivity: Activity {
    let id: String = UUID().uuidString
    let workoutSource: HealthKitWorkoutSource? = nil
    let clipsRoute: Bool = false
    let activityType: ActivityType
    let distance: Float
    let movingTime: TimeInterval
    let startDate: Date
    let startDateLocal: Date
    let endDate: Date
    let endDateLocal: Date
    let coordinates: [CLLocation]
    let activeCalories: Float
    let paceInUserSelectedUnit: Float
    let totalElevationGain: Float
    let distanceInUserSelectedUnit: Float
    let stepCount: Int?
}

class ActivitiesDataTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    // TODO: make this more thorough
    func testRemovingDuplicateActivities() throws {
        // distance and elevation
        let activity1 = MockActivity(activityType: .run,
                                     distance: 5.0,
                                     movingTime: 30.0 * 60.0,
                                     startDate: Date(),
                                     startDateLocal: Date(),
                                     endDate: Date(),
                                     endDateLocal: Date(),
                                     coordinates: [],
                                     activeCalories: 100.0,
                                     paceInUserSelectedUnit: 0.0,
                                     totalElevationGain: 5.0,
                                     distanceInUserSelectedUnit: 5.0,
                                     stepCount: nil)
        // no elevation
        let activity2 = MockActivity(activityType: .run,
                                     distance: 5.0,
                                     movingTime: 30.0 * 60.0,
                                     startDate: Date(),
                                     startDateLocal: Date(),
                                     endDate: Date(),
                                     endDateLocal: Date(),
                                     coordinates: [],
                                     activeCalories: 100.0,
                                     paceInUserSelectedUnit: 0.0,
                                     totalElevationGain: 0.0,
                                     distanceInUserSelectedUnit: 5.0,
                                     stepCount: nil)
        // no distance or elevation
        let activity3 = MockActivity(activityType: .run,
                                     distance: 0.0,
                                     movingTime: 30.0 * 60.0,
                                     startDate: Date(),
                                     startDateLocal: Date(),
                                     endDate: Date(),
                                     endDateLocal: Date(),
                                     coordinates: [],
                                     activeCalories: 100.0,
                                     paceInUserSelectedUnit: 0.0,
                                     totalElevationGain: 0.0,
                                     distanceInUserSelectedUnit: 5.0,
                                     stepCount: nil)

        let activities: [Activity] = [activity1, activity2, activity3]
        let filtered = activities.activitiesByRemovingDuplicates()
        XCTAssert(filtered.count == 1, "Removed duplicate activities")
        XCTAssert(filtered.first?.id == activity1.id, "Picked activity with the most data")
    }

}
