// Licensed under the Any Distance Source-Available License
//
//  ActivityType.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/5/21.
//

import UIKit
import HealthKit

enum ActivityType: String, Codable, CaseIterable {
    /// Raw values shouldn't be changed once they are in a public release.
    case run = "Run"
    case dogRun = "DogRun"
    case strollerRun = "StrollerRun"
    case treadmillRun = "TreadmillRun"
    case trailRun = "TrailRun"
    case bikeRide = "Ride"
    case eBikeRide = "EBikeRide"
    case commuteRide = "CommuteRide"
    case recumbentRide = "RecumbentRide"
    case handCycling = "HandCycling"
    case walk = "Walk"
    case dogWalk = "DogWalk"
    case strollerWalk = "StrollerWalk"
    case treadmillWalk = "TreadmillWalk"
    case hotGirlWalk = "HotGirlWalk"
    case walkWithCane = "WalkWithCane"
    case walkWithWalker = "WalkWithWalker"
    case walkingMeeting = "WalkingMeeting"
    case deskWalk = "DeskWalk"
    case dance = "Dance"
    case cardioDance = "CardioDance"
    case stepCount = "Step Count"
    case hike = "Hike"
    case rucking = "Rucking"
    case kayak = "Kayaking"
    case paddleSports = "PaddleSports"
    case sailing = "Sailing"
    case crossCountrySkiing = "CrossCountrySkiing"
    case downhillSkiing = "DownhillSkiing"
    case snowboard = "Snowboard"
    case snowSports = "SnowSports"
    case skateboard = "Skateboarding"
    case wheelchairWalk = "Wheelchair Walk Pace"
    case wheelchairRun = "Wheelchair Run Pace"
    case virtualRide = "VirtualRide"
    case traditionalStrengthTraining = "TraditionalStrengthTraining"
    case functionalStrengthTraining = "FunctionalStrengthTraining"
    case adaptiveStrengthTraining = "AdaptiveStrengthTraining"
    case stairClimbing = "StairClimbing"
    case boxing = "Boxing"
    case kickboxing = "Kickboxing"
    case martialArts = "MartialArts"
    case taiChi = "TaiChi"
    case wrestling = "Wrestling"
    case climbing = "Climbing"
    case swimming = "Swimming"
    case waterFitness = "WaterFitness"
    case waterPolo = "WaterPolo"
    case waterSports = "WaterSports"
    case coreTraining = "CoreTraining"
    case pilates = "Pilates"
    case yoga = "Yoga"
    case hiit = "HIIT"
    case flexibility = "Flexibility"
    case gymnastics = "Gymnastics"
    case basketball = "Basketball"
    case baseball = "Baseball"
    case handball = "Handball"
    case softball = "Softball"
    case americanFootball = "AmericanFootball"
    case australianFootball = "AustralianFootball"
    case soccer = "Soccer"
    case archery = "Archery"
    case badminton = "Badminton"
    case golf = "Golf"
    case pickleball = "Pickleball"
    case tennis = "Tennis"
    case tableTennis = "TableTennis"
    case squash = "Squash"
    case racquetball = "Racquetball"
    case cricket = "Cricket"
    case volleyball = "Volleyball"
    case bowling = "Bowling"
    case hockey = "Hockey"
    case discSports = "DiscSports"
    case lacrosse = "Lacrosse"
    case rugby = "Rugby"
    case equestrianSports = "EquestrianSports"
    case fencing = "Fencing"
    case hunting = "Hunting"
    case barre = "Barre"
    case curling = "Curling"
    case surfing = "Surfing"
    case rollerskating = "Rollerskating"
    case elliptical = "Elliptical"
    case rowing = "Rowing"
    case jumpRope = "JumpRope"
    case fishing = "Fishing"
    case mindAndBody = "MindAndBody"
    case coldPlunge = "ColdPlunge"
    case cooldown = "Cooldown"
    case preparationAndRecovery = "PreparationAndRecovery"
    case mixedCardio = "MixedCardio"
    case crossTraining = "CrossTraining"
    case play = "Play"
    case other = "Other"
    case unknown = "Unknown"
    case all = "All"

    static let allCasesThatAllowGoals: [ActivityType] = [
        .run, .strollerRun, .dogRun, .trailRun, .treadmillRun, .bikeRide, .eBikeRide, .commuteRide,
        .recumbentRide, .virtualRide, .walk, .treadmillWalk, .dogWalk, .strollerWalk, .hotGirlWalk,
        .walkWithCane, .walkWithWalker, .walkingMeeting, .deskWalk, .stairClimbing, .golf, .hike,
        .rucking, .rollerskating, .lacrosse, .kayak, .paddleSports, .sailing, .crossCountrySkiing,
        .downhillSkiing, .snowboard, .snowSports, .wheelchairWalk, .wheelchairRun, .swimming,
        .waterFitness, .waterPolo, .waterSports, .climbing, .equestrianSports, .hunting, .skateboard,
        .rugby, .soccer, .tennis, .discSports, .crossCountrySkiing
    ]

    init(idx: Int) {
        self = ActivityType.allCases[idx.clamped(to: 0...ActivityType.allCases.count-1)]
    }

    init?(name: String) {
        if name.contains("Ski") {
            self = .downhillSkiing
            return
        }

        if name == "VirtualRun" {
            self = .run
            return
        }

        if name == "EBikeRide" {
            self = .eBikeRide
            return
        }

        self.init(rawValue: name)
    }

    var hkWorkoutType: HKWorkoutActivityType {
        switch self {
        case .run, .treadmillRun, .strollerRun, .dogRun, .trailRun:
            return .running
        case .bikeRide, .eBikeRide, .recumbentRide, .commuteRide:
            return .cycling
        case .handCycling:
            return .handCycling
        case .walk, .treadmillWalk, .strollerWalk, .dogWalk, .hotGirlWalk, .walkWithCane,
             .walkWithWalker, .walkingMeeting, .deskWalk:
            return .walking
        case .hike, .rucking:
            return .hiking
        case .kayak:
            return .paddleSports
        case .paddleSports:
            return .paddleSports
        case .sailing:
            return .sailing
        case .crossCountrySkiing:
            return .crossCountrySkiing
        case .downhillSkiing:
            return .downhillSkiing
        case .snowboard:
            return .snowboarding
        case .snowSports:
            return .snowSports
        case .wheelchairWalk:
            return .wheelchairWalkPace
        case .wheelchairRun:
            return .wheelchairRunPace
        case .virtualRide:
            return .cycling
        case .traditionalStrengthTraining:
            return .traditionalStrengthTraining
        case .functionalStrengthTraining:
            return .functionalStrengthTraining
        case .adaptiveStrengthTraining:
            return .traditionalStrengthTraining
        case .stairClimbing:
            return .stairClimbing
        case .swimming:
            return .swimming
        case .waterFitness:
            return .waterFitness
        case .waterPolo:
            return .waterPolo
        case .waterSports:
            return .waterSports
        case .coreTraining:
            return .coreTraining
        case .pilates:
            return .pilates
        case .yoga:
            return .yoga
        case .flexibility:
            return .flexibility
        case .gymnastics:
            return .gymnastics
        case .dance:
            return .socialDance
        case .cardioDance:
            return .cardioDance
        case .hiit:
            return .highIntensityIntervalTraining
        case .boxing:
            return .boxing
        case .kickboxing:
            return .kickboxing
        case .martialArts:
            return .martialArts
        case .taiChi:
            return .taiChi
        case .wrestling:
            return .wrestling
        case .climbing:
            return .climbing
        case .surfing:
            return .surfingSports
        case .rollerskating, .skateboard:
            return .skatingSports
        case .elliptical:
            return .elliptical
        case .rowing:
            return .rowing
        case .jumpRope:
            return .jumpRope
        case .mindAndBody:
            return .mindAndBody
        case .mixedCardio:
            return .mixedCardio
        case .basketball:
            return .basketball
        case .baseball:
            return .baseball
        case .handball:
            return .handball
        case .softball:
            return .softball
        case .americanFootball:
            return .americanFootball
        case .australianFootball:
            return .australianFootball
        case .soccer:
            return .soccer
        case .archery:
            return .archery
        case .badminton:
            return .badminton
        case .golf:
            return .golf
        case .pickleball:
            return .pickleball
        case .tennis:
            return .tennis
        case .tableTennis:
            return .tableTennis
        case .squash:
            return .squash
        case .racquetball:
            return .racquetball
        case .cricket:
            return .cricket
        case .volleyball:
            return .volleyball
        case .bowling:
            return .bowling
        case .hockey:
            return .hockey
        case .discSports:
            return .discSports
        case .lacrosse:
            return .lacrosse
        case .rugby:
            return .rugby
        case .equestrianSports:
            return .equestrianSports
        case .fencing:
            return .fencing
        case .hunting:
            return .hunting
        case .barre:
            return .barre
        case .curling:
            return .curling
        case .crossTraining:
            return .crossTraining
        case .fishing:
            return .fishing
        case .cooldown:
            return .cooldown
        case .coldPlunge, .preparationAndRecovery:
            return .preparationAndRecovery
        case .play:
            return .play
        case .unknown, .stepCount, .other, .all:
            return .other
        }
    }

    var locationType: HKWorkoutSessionLocationType {
        switch self {
        case .treadmillRun, .treadmillWalk, .elliptical, .virtualRide:
            return .indoor
        default:
            return .outdoor
        }
    }

    /// Returning a nil categoryString will remove this type from the list in RecordingActivityPickerView
    var categoryString: String? {
        switch self {
        case .run, .treadmillRun, .dogRun, .strollerRun, .trailRun:
            return "Running"
        case .bikeRide, .virtualRide, .eBikeRide, .recumbentRide, .commuteRide:
            return "Cycling"
        case .walk, .hike, .treadmillWalk, .dogWalk, .strollerWalk, .hotGirlWalk, .walkWithCane,
                .walkWithWalker, .walkingMeeting, .rucking, .deskWalk:
            return "Walking"
        case .kayak, .paddleSports, .sailing, .swimming, .surfing, .rowing, .waterFitness,
                .waterPolo, .waterSports:
            return "Water"
        case .downhillSkiing, .crossCountrySkiing, .snowboard, .snowSports:
            return "Snow"
        case .wheelchairWalk, .wheelchairRun, .adaptiveStrengthTraining:
            return "Wheelchair"
        case .boxing, .martialArts, .taiChi, .wrestling, .climbing, .flexibility, .gymnastics,
                .kickboxing, .coreTraining, .traditionalStrengthTraining, .functionalStrengthTraining,
                .stairClimbing, .pilates, .yoga, .hiit, .elliptical, .jumpRope, .mixedCardio,
                .crossTraining, .handCycling:
            return "Training"
        case .mindAndBody, .coldPlunge, .cooldown, .preparationAndRecovery:
            return "Recovery"
        case .basketball, .baseball, .handball, .softball, .americanFootball, .australianFootball,
                .soccer, .archery, .badminton, .golf, .pickleball, .tennis, .tableTennis, .squash,
                .racquetball, .cricket, .volleyball, .bowling, .hockey, .discSports, .lacrosse,
                .rugby, .equestrianSports, .fencing, .hunting, .barre, .curling, .fishing,
                .rollerskating, .dance, .cardioDance, .skateboard, .play:
            return "Sports"
        case .unknown, .stepCount, .other, .all:
            return nil
        }
    }
    
    /// Returns all matching activity types for a goal with the receiver's activity type, meaning all activity types that should count
    /// towards a goal.
    var matchingGoalActivityTypes: [ActivityType] {
        switch self {
        case .run:
            return [.run, .treadmillRun, .dogRun, .strollerRun, .trailRun]
        case .bikeRide:
            return [.bikeRide, .virtualRide, .eBikeRide, .recumbentRide, .commuteRide]
        case .walk:
            return [.walk, .treadmillWalk, .strollerWalk, .dogWalk, .hotGirlWalk, .walkWithCane,
                    .walkWithWalker, .walkingMeeting, .rucking]
        default:
            return [self]
        }
    }

    var isADCustom: Bool {
        switch self {
        case .dogRun, .strollerRun, .treadmillRun, .trailRun, .eBikeRide, .commuteRide, .recumbentRide,
                .treadmillWalk, .strollerWalk, .dogWalk, .hotGirlWalk, .walkWithCane, .walkWithWalker,
                .walkingMeeting, .deskWalk, .rucking, .coldPlunge:
            return true
        default:
            return false
        }
    }

    var idx: Int {
        return ActivityType.allCases.firstIndex(of: self) ?? 0
    }

    var displayName: String {
        switch self {
        case .bikeRide:
            return "Outdoor Ride"
        case .mindAndBody:
            return "Mindfulness"
        case .hiit:
            return "HIIT"
        case .virtualRide:
            return "Indoor Ride"
        case .rollerskating:
            return "Roller Skating"
        case .eBikeRide:
            return "E-Bike Ride"
        case .other:
            return "Workout"
        default:
            return rawValue.replacingOccurrences(of: " ", with: "").camelCaseToWords()
        }
    }

    var notificationDisplayName: String {
        switch self {
        case .hiit:
            return "HIIT Activity"
        case .mindAndBody, .handCycling, .dance, .cardioDance, .kayak, .paddleSports,
                .sailing, .crossCountrySkiing, .downhillSkiing, .snowboard, .snowSports, .skateboard,
                .wheelchairWalk, .wheelchairRun, .traditionalStrengthTraining,
                .functionalStrengthTraining, .adaptiveStrengthTraining, .stairClimbing, .boxing,
                .kickboxing, .martialArts, .taiChi, .wrestling, .climbing, .swimming, .waterFitness,
                .waterPolo, .waterSports, .coreTraining, .pilates, .yoga, .flexibility, .gymnastics,
                .basketball, .baseball, .softball, .americanFootball,
                .australianFootball, .soccer, .archery, .badminton, .golf, .pickleball, .tennis,
                .tableTennis, .squash, .racquetball, .cricket, .volleyball, .bowling, .hockey,
                .discSports, .lacrosse, .rugby, .equestrianSports, .fencing, .hunting, .barre,
                .curling, .surfing, .rollerskating, .elliptical, .rowing, .jumpRope, .fishing,
                .coldPlunge, .cooldown, .preparationAndRecovery, .mixedCardio, .crossTraining, .play,
                .rucking:
            return displayName.capitalized + " Activity"
        default:
            return displayName.capitalized
        }
    }

    var isDistanceBased: Bool {
        return ActivityType.allCasesThatAllowGoals.contains(self)
    }
    
    var showsRoute: Bool {
        return isDistanceBased && !isDistanceBasedIndoors
    }
    
    var isDistanceBasedIndoors: Bool {
        switch self {
        case .virtualRide, .treadmillRun, .treadmillWalk, .deskWalk:
            return true
        default:
            return false
        }
    }

    var glyphName: String {
        var activityName: String {
            switch self {
            case .hiit:
                return "hiit"
            case .eBikeRide:
                return "ebike_ride"
            case .stepCount:
                return "steps"
            default:
                return rawValue.replacingOccurrences(of: " ", with: "").camelCaseToSnakeCase()
            }
        }
        
        return "activity_" + activityName
    }

    var glyph: UIImage? {
        return UIImage(named: glyphName)
    }

    #if !os(watchOS)
    var tabBarGlyph: UIImage? {
        return glyph?.resized(withNewWidth: 28)
    }
    #endif

    var shouldShowSpeedInsteadOfPace: Bool {
        switch self {
        case .bikeRide, .recumbentRide, .commuteRide, .virtualRide, .eBikeRide, .downhillSkiing,
             .crossCountrySkiing, .snowboard, .snowSports, .kayak, .paddleSports, .sailing:
            return true
        default:
            return false
        }
    }
    
    var shouldPromptToAddDistance: Bool {
        switch self {
        case .treadmillRun, .treadmillWalk, .virtualRide:
            return true
        default:
            return false
        }
    }

}
