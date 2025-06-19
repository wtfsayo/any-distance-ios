// Licensed under the Any Distance Source-Available License
//
//  ADMetadataKey.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/13/22.
//

import Foundation

class ADMetadataKey {
    static let goalType = "ADGoalType"
    static let goalTarget = "ADGoalTarget"
    static let clipRoute = "ADClipRoute"
    static let activityType = "ADActivityType"
    static let restoredFromSavedState = "ADWasRestoredFromSavedState"
    static let nonDistanceBasedCoordinate = "ADNonDistanceBasedCoordinate"
    static let totalDistanceMeters = "ADTotalDistanceMeters"
    static let wasRecordedOnWatch = "ADWasRecordedOnWatch"

    static let isPartialSplit = "ADIsPartialSplit"
    static let activeDurationQuantity = "ADActiveDurationQuantity"
    static let splitDistanceQuantity = "ADSplitDistanceQuantity"
    static let splitMeasuringSystem = "ADSplitMeasuringSystem"
    static let totalDistanceQuantity = "ADTotalDistanceQuantity"
    static let startDistanceQuantity = "ADStartDistanceQuantity"
}

enum ADEventType: String {
    static let key = "ADEventType"

    case saveState = "ADSaveState"
    case restoreState = "ADRestoreState"
}
