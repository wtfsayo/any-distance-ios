// Licensed under the Any Distance Source-Available License
//
//  AppIcon.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/27/21.
//

import UIKit

enum AppIcon: Int, CaseIterable {
    case flare
    case classic
    case noir
    case inverted
    case meter
    case sunset
    case berry
    case synthwave
    case rainbowGlass
    case adac
    case chromeo
    case neonFuture
    case aurora
    case greens
    case sun
    case dubDub
    case easyWay
    case iDistance
    case beta

    init(alternateIconName: String) {
        self = AppIcon.allCases.first(where: { $0.alternateIconName == alternateIconName}) ?? .classic
    }

    static var selectedIconIdx: Int {
        if let name = UIApplication.shared.alternateIconName {
            return AppIcon(alternateIconName: name).rawValue
        }
        return 0
    }

    var displayName: String {
        switch self {
        case .classic:
            return "OG"
        case .noir:
            return "Noir"
        case .inverted:
            return "Inverted"
        case .meter:
            return "Meter"
        case .sunset:
            return "Sunset"
        case .berry:
            return "Berry"
        case .beta:
            return "Betacon"
        case .flare:
            return "Flare"
        case .adac:
            return "ADAC"
        case .synthwave:
            return "Synthwave by @flarup"
        case .rainbowGlass:
            return "Rainbow by @flarup"
        case .chromeo:
            return "Chromeo"
        case .neonFuture:
            return "Neon Future"
        case .aurora:
            return "Aurora"
        case .greens:
            return "Greens"
        case .sun:
            return "Sun"
        case .dubDub:
            return "Dub Dub"
        case .easyWay:
            return "Easy Way"
        case .iDistance:
            return "iDistance"
        }
    }

    var previewImage: UIImage {
        switch self {
        case .flare:
            return UIImage(named: "AppIcon-Flare-Preview")!
        default:
            return UIImage(named: alternateIconName! + "-Preview")!
        }
    }

    var alternateIconName: String? {
        switch self {
        case .classic:
            return "AppIcon-Classic"
        case .noir:
            return "AppIcon-Noir"
        case .inverted:
            return "AppIcon-Inverted"
        case .meter:
            return "AppIcon-Progress"
        case .sunset:
            return "AppIcon-Sunset"
        case .berry:
            return "AppIcon-Berry"
        case .beta:
            return "AppIcon-Beta"
        case .flare:
            return nil
        case .adac:
            return "AppIcon-ADAC"
        case .synthwave:
            return "AppIcon-Synthwave"
        case .rainbowGlass:
            return "AppIcon-RainbowGlass"
        case .chromeo:
            return "AppIcon-Chromeo"
        case .neonFuture:
            return "AppIcon-NeonFuture"
        case .aurora:
            return "AppIcon-Aurora"
        case .greens:
            return "AppIcon-Greens"
        case .sun:
            return "AppIcon-Sun"
        case .dubDub:
            return "AppIcon-DubDub"
        case .easyWay:
            return "AppIcon-EasyWay"
        case .iDistance:
            return "AppIcon-iDistance"
        }
    }
}
