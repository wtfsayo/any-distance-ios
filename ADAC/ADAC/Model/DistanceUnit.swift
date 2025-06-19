// Licensed under the Any Distance Source-Available License
//
//  DistanceUnit.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/15/20.
//

import UIKit

enum DistanceUnit: Int, Codable {
    case miles
    case kilometers

    var abbreviation: String {
        switch self {
        case .miles:
            return "mi"
        case .kilometers:
            return "km"
        }
    }

    var speedAbbreviation: String {
        switch self {
        case .miles:
            return "mph"
        case .kilometers:
            return "km/h"
        }
    }

    var fullName: String {
        switch self {
        case .miles:
            return "miles"
        case .kilometers:
            return "kilometers"
        }
    }

    var fullNameSingular: String {
        switch self {
        case .miles:
            return "mile"
        case .kilometers:
            return "kilometer"
        }
    }

    var filledGlyph: UIImage? {
        switch self {
        case .miles:
            return UIImage(named: "glyph_distance_mi_filled")
        case .kilometers:
            return UIImage(named: "glyph_distance_km_filled")
        }
    }
}
