// Licensed under the Any Distance Source-Available License
//
//  RecordingState.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/16/22.
//

import UIKit

enum iPhoneActivityRecordingState: Codable {
    case locationPermissionNeeded
    case ready
    case recording
    case waitingForGps
    case paused
    case saving
    case saved
    case couldNotSave
    case discarded

    var displayName: String {
        switch self {
        case .locationPermissionNeeded:
            return ""
        case .ready:
            return ""
        case .recording:
            return "TRACKING"
        case .waitingForGps:
            return "RE-CONNECTING TO GPS"
        case .paused:
            return "PAUSED"
        case .saving:
            return "SAVING TO APPLE HEALTH"
        case .saved:
            return "SAVED TO APPLE HEALTH"
        case .couldNotSave:
            return "COULD NOT SAVE ACTIVITY"
        case .discarded:
            return "ACTIVITY DISCARDED"
        }
    }

    var liveActivityDisplayName: String {
        switch self {
        case .waitingForGps:
            return "GPS Lost"
        default:
            return displayName.capitalized
        }
    }

    var displayColor: UIColor {
        switch self {
        case .ready:
            return .adOrangeLighter
        default:
            return .white
        }
    }

    var isFinished: Bool {
        return self == .saved
    }
}
