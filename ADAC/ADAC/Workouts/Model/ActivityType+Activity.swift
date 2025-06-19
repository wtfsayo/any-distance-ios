// Licensed under the Any Distance Source-Available License
//
//  ActivityType+Activity.swift
//  ADAC
//
//  Created by Jarod Luebbert on 5/5/22.
//

import Foundation
import HealthKit

extension ActivityType {
        
    static func from(hkWorkoutType: HKWorkoutActivityType, isDistanceNil: Bool) -> ActivityType {
        switch hkWorkoutType {
        case .running:
            return .run
        case .cycling:
            return isDistanceNil ? .virtualRide : .bikeRide
        case .walking:
            return .walk
        case .hiking:
            return .hike
        case .downhillSkiing:
            return .downhillSkiing
        case .crossCountrySkiing:
            return .crossCountrySkiing
        case .snowboarding:
            return .snowboard
        case .paddleSports:
            return .kayak
        case .wheelchairWalkPace:
            return .wheelchairWalk
        case .wheelchairRunPace:
            return .wheelchairRun
        case .traditionalStrengthTraining:
            return .traditionalStrengthTraining
        case .functionalStrengthTraining:
            return .functionalStrengthTraining
        case .swimming:
            return .swimming
        case .coreTraining:
            return .coreTraining
        case .pilates:
            return .pilates
        case .yoga:
            return .yoga
        case .highIntensityIntervalTraining:
            return .hiit
        case .kickboxing:
            return .kickboxing
        case .skatingSports:
            return .rollerskating
        default:
            return .run
        }
    }
    
    static func from(wahooActivityType: WahooActivityType) -> ActivityType {
        switch wahooActivityType {
        case .biking, .biking_road, .biking_track, .biking_mountain,
                .biking_motocycling, .biking_cyclecross:
            return .bikeRide
        case .biking_recumbent:
            return .recumbentRide
        case .biking_indoor, .biking_indoor_trainer, .biking_indoor_cycling_class,
                .ebiking, .fe, .fe_general, .fe_bike, .fe_climber:
            return .virtualRide
        case .stair_climber:
            return .stairClimbing
        case .running, .running_track, .running_trail:
            return .run
        case .running_treadmill, .fe_treadmill:
            return .treadmillRun
        case .walking, .walking_speed, .walking_nordic:
            return .walk
        case .walking_treadmill:
            return .treadmillWalk
        case .hiking, .mountaineering:
            return .hike
        case .fe_elliptical:
            return .elliptical
        case .swimming_lap, .swimming_open_water:
            return .swimming
        case .snowboarding:
            return .snowboard
        case .skiing, .skiingcross_country:
            return .crossCountrySkiing
        case .skiing_downhill:
            return .downhillSkiing
        case .workout:
            return .traditionalStrengthTraining
        case .cardio_class:
            return .virtualRide
        case .wheelchair:
            return .wheelchairRun
        case .yoga:
            return .yoga
        case .windsurfing:
            return .surfing
        case .rowing, .fe_rower:
            return .rowing
        case .skating, .skating_inline:
            return .rollerskating
        case .skating_ice:
            return .snowSports
        case .sailing:
            return .sailing
        case .canoeing:
            return .paddleSports
        case .kayaking:
            return .kayak
        case .golfing:
            return .golf
        case .other:
            return .other
        default:
            return .unknown
        }
    }
    
    static func from(garminActivityType: GarminActivityType) -> ActivityType {
        switch garminActivityType {
            // running
        case .running, .indoor_running, .obstacle_run, .street_running, .track_running,
                .ultra_run, .virtual_run:
            return .run

        case .trail_running:
            return .trailRun

        case .treadmill_running:
            return .treadmillRun
            
            // biking
        case .cycling, .bmx, .cyclocross, .downhill_biking, .gravel_cycling,
                .indoor_cycling, .mountain_biking, .road_biking, .track_cycling:
            return .bikeRide

        case .recumbent_cycling:
            return .recumbentRide
            
        case .virtual_ride:
            return .virtualRide
            
            // not-supported
        case .fitness_equipment, .bouldering:
            return .unknown
            
        case .elliptical:
            return .elliptical
            
            // indoors
        case .indoor_climbing, .rock_climbing:
            return .climbing

        case .stair_climbing:
            return .stairClimbing

        case .indoor_cardio:
            return .mixedCardio

        case .pilates:
            return .pilates
            
        case .strength_training:
            return .traditionalStrengthTraining
        case .yoga:
            return .yoga
        case .hiking:
            return .hike
            
            // swimming
        case .swimming, .lap_swimming, .open_water_swimming:
            return .swimming
            
            // walking
        case .walking, .casual_walking, .speed_walking:
            return .walk

            // transitions
        case .transition, .bikeToRunTransition, .runToBikeTransition, .swimToBikeTransition:
            return .unknown

        case .golf:
            return .golf

        case .horseback_riding:
            return .equestrianSports

        case .hunting:
            return .hunting

        case .fishing:
            return .fishing

        case .paddling:
            return .paddleSports

        case .sailing:
            return .sailing

        case .tennis:
            return .tennis

        case .cross_country_skiing_ws:
            return .crossCountrySkiing

        case .winter_sports:
            return .snowSports

        case .wheelchair_push_run:
            return .wheelchairRun

        case .wheelchair_push_walk:
            return .wheelchairWalk

            // random
        case .motorcycling, .atv, .motocross, .auto_racing, .boating, .driving_general,
                .e_sport, .floor_climbing, .flying, .hang_gliding, .hunting_fishing,
                .inline_skating, .mountaineerin, .offshore_grinding, .onshore_grinding,
                .rc_drone, .sky_diving, .stop_watch, .wakeboarding, .whitewater_rafting_kayaking,
                .wind_kite_surfing, .wingsuit_flying, .diving, .apnea_diving, .apnea_hunting,
                .ccr_diving, .gauge_diving, .multi_gas_diving, .single_gas_diving,
                .backcountry_skiing_snowboarding_ws, .resort_skiing_snowboarding_ws,
                .skate_skiing_ws, .skating_ws, .snow_shoe_ws, .snowmobiling_ws,
                .stand_up_paddleboarding, .breathwork:
            return .unknown
            
        case .other:
            return .unknown
            
        case .rowing, .indoor_rowing:
            return .rowing
            
        case .surfing:
            return .surfing
        }
    }
    
}
