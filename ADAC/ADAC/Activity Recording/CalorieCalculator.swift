// Licensed under the Any Distance Source-Available License
//
//  CalorieCalculator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/11/22.
//

import Foundation

class CalorieCalculator {
    static func calories(for activityType: ActivityType,
                         duration: TimeInterval,
                         distance: Double,
                         elevationGain: Double) -> Double {
        let durationMinutes = duration / 60
        let mets = activityType.mets(forDuration: duration,
                                     distance: distance,
                                     elevationGain: elevationGain)
        let cals = (durationMinutes * 3.5 * mets * NSUbiquitousKeyValueStore.default.bodyMassKg) / 200.0
        return cals.isNaN ? 0 : cals.clamped(to: 0...Double.greatestFiniteMagnitude)
    }
}

fileprivate extension ActivityType {
    func mets(forDuration duration: TimeInterval,
              distance: Double,
              elevationGain: Double) -> Double {
        let speedMetersPerSecond = distance / duration
        let mph = speedMetersPerSecond * 2.237
        let elevationGainPerHour = elevationGain / (duration / 3600)
        
        switch self {
        case .bikeRide, .recumbentRide, .commuteRide:
            return max(0.87 * mph - 2.0, 5)
        case .eBikeRide:
            return max(0.4 * mph - 1.0, 3)
        case .run, .dogRun, .strollerRun, .trailRun:
            let grade = elevationGain / (distance - elevationGain)
            let gradeMultiplier: Double = 5
            return 1.4 * mph * (1 + (grade * gradeMultiplier))
        case .walk, .hike, .dogWalk, .strollerWalk, .hotGirlWalk, .walkWithCane, .walkWithWalker,
             .walkingMeeting, .rucking:
            let grade = elevationGain / (distance - elevationGain)
            let gradeMultiplier: Double = 5
            return 1.1 * mph * (1 + (grade * gradeMultiplier))
        case .treadmillRun:
            return 9.0
        case .treadmillWalk, .deskWalk:
            return 4.3
        case .kayak, .paddleSports:
            return 5.0
        case .sailing:
            return 4.0
        case .downhillSkiing, .crossCountrySkiing:
            return 1.3 * mph + 3.65
        case .snowboard, .snowSports:
            return 4.7
        case .wheelchairWalk:
            return 1.1 * mph
        case .wheelchairRun:
            return 1.3 * mph
        case .skateboard:
            return 1.9 * mph
        case .virtualRide:
            return 8.0
        case .traditionalStrengthTraining, .functionalStrengthTraining, .adaptiveStrengthTraining:
            return 5.0
        case .handCycling:
            return 5.2
        case .stairClimbing:
            return 7.0
        case .boxing:
            return 9.5
        case .martialArts:
            return 9.8
        case .taiChi:
            return 2.5
        case .wrestling:
            return 6.0
        case .climbing:
            return 7.0
        case .swimming, .waterFitness, .waterSports:
            return 2.0 * mph + 4.9
        case .waterPolo:
            return 10.0
        case .flexibility:
            return 2.3
        case .gymnastics:
            return 3.8
        case .coreTraining:
            return 5.0
        case .pilates:
            return 3.0
        case .barre:
            return 3.0
        case .yoga:
            return 2.8
        case .dance:
            return 5.5
        case .cardioDance:
            return 6.5
        case .hiit:
            return 7.0
        case .kickboxing:
            return 10.3
        case .basketball:
            return 6.5
        case .softball, .baseball, .handball:
            return 5.0
        case .americanFootball, .australianFootball:
            return 7
        case .soccer:
            return 8.5
        case .archery:
            return 4.3
        case .badminton:
            return 6.2
        case .tableTennis:
            return 4.0
        case .squash:
            return 7.3
        case .racquetball:
            return 8.0
        case .cricket:
            return 4.8
        case .volleyball:
            return 5.0
        case .bowling:
            return 3.0
        case .hockey:
            return 8.5
        case .discSports:
            return 7.0
        case .lacrosse:
            return 8.0
        case .rugby:
            return 7.3
        case .equestrianSports:
            return 5.5
        case .fencing:
            return 6.0
        case .hunting:
            return 6.0
        case .curling:
            return 4.0
        case .fishing:
            return 3.5
        case .surfing:
            return 3.5
        case .rollerskating:
            return 7.0
        case .elliptical:
            return 5.0
        case .rowing:
            return 7.0
        case .jumpRope:
            return 12.3
        case .mindAndBody:
            return 1.0
        case .coldPlunge:
            return 4.0
        case .cooldown:
            return 2.0
        case .preparationAndRecovery:
            return 2.0
        case .play:
            return 3.0
        case .mixedCardio:
            return 7.0
        case .golf:
            return 4.8
        case .pickleball:
            return 7.3
        case .tennis:
            return 7.3
        case .crossTraining:
            return 6.0
        case .unknown, .stepCount, .other, .all:
            return 0.0
        }
    }
}
