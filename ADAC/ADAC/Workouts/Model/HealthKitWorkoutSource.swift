// Licensed under the Any Distance Source-Available License
//
//  HealthKitWorkoutSource.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/29/21.
//

import UIKit

enum HealthKitWorkoutSource: String {
    case anyDistance = "com.anydistance.anydistance"
    case strava = "com.strava.stravaride"
    case appleHealth = "com.apple.health"
    case nikeRunClub = "com.nike.nikeplus-gps"
    case garminConnect = "com.garmin.connect.mobile"
    case runkeeper = "RunKeeperPro"
    case peloton = "com.Peloton.PelotonApp"
    case wahooFitness = "com.WahooFitness.FisicaFitness"
    case komoot = "de.komoot.berlinbikeapp"
    
    var name: String {
        switch self {
        case .anyDistance:
            return "Any Distance"
        case .strava:
            return "Strava"
        case .appleHealth:
            return "Apple Health"
        case .nikeRunClub:
            return "Nike Run Club"
        case .garminConnect:
            return "Garmin Connect"
        case .runkeeper:
            return "RunKeeper"
        case .peloton:
            return "Peloton"
        case .wahooFitness:
            return "Wahoo Fitness"
        case .komoot:
            return "Komoot"
        }
    }
    
    // add integrations we support here so we can ask the user to
    // auth directly with the service
    var externalService: ExternalService? {
        switch self {
        case .garminConnect:
            return .garmin
        case .wahooFitness:
            return .wahoo
        default:
            return nil
        }
    }

    var hasRouteInfo: Bool {
        switch self {
        case .nikeRunClub, .garminConnect, .runkeeper, .peloton, .wahooFitness, .komoot:
            return false
        default:
            return true
        }
    }

    var contact: String {
        switch self {
        case .strava, .appleHealth, .peloton, .anyDistance:
            return ""
        case .nikeRunClub:
            return "https://instagram.com/nikerunning?utm_medium=copy_link"
        case .garminConnect:
            return "product.support@garmin.com"
        case .runkeeper:
            return "support@runkeeper.com"
        case .wahooFitness:
            return "support@wahoofitness.com"
        case .komoot:
            return "https://support.komoot.com/hc/en-us/requests/new"
        }
    }

    var contactIsLink: Bool {
        switch self {
        case .nikeRunClub, .komoot:
            return true
        default:
            return false
        }
    }

    var emailBody: String {
        return "Hi there!</br></br>Please consider allowing Apple Health to read Activity Route data when I sync an activity. I would like to display it when I share my activities with <a href=\"https://apps.apple.com/us/app/any-distance-share-workouts/id1545233932\">Any Distance – The Activity Story Designer</a>.</br></br>If you have any questions for them, please drop them a line at <a href=\"mailto:hi@anydistance.club\">hi@anydistance.club</a>.</br></br>Thank you!"
    }

    var image: UIImage? {
        switch self {
        case .strava:
            return UIImage(named: "glyph_strava")
        case .appleHealth:
            return UIImage(named: "glyph_applehealth")
        default:
            return nil
        }
    }

}
