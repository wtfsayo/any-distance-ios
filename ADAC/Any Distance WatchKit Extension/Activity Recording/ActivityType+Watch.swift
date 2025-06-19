// Licensed under the Any Distance Source-Available License
//
//  ActivityType+Watch.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 2/8/23.
//

import Foundation

extension ActivityType {
    var supportsAutoPause: Bool {
        switch self {
        case .run, .bikeRide, .eBikeRide, .recumbentRide, .treadmillRun:
            return true
        default:
            return false
        }
    }

    var supportsRouteClip: Bool {
        guard showsRoute else {
            return false
        }

        switch self {
        case .climbing, .stairClimbing, .waterPolo, .waterSports, .waterFitness, .lacrosse, .pickleball, .rugby, .soccer, .tennis:
            return false
        default:
            return true
        }
    }
}
