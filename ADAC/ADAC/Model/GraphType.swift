// Licensed under the Any Distance Source-Available License
//
//  GraphType.swift
//  ADAC
//
//  Created by Daniel Kuntz on 10/19/21.
//

import UIKit

enum GraphType: String, CaseIterable, Codable {
    case none
    case route2d
    case route3d
    case splits
    case heartRate
    case elevation
    case stepCount

    static let visibleCases: [GraphType] = [.none, .route2d, .route3d, .splits, .heartRate, .elevation]

    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .route2d:
            return "2D Route"
        case .route3d:
            return "3D Route"
        case .splits:
            return "Splits"
        case .heartRate:
            return "Heart Rate"
        case .elevation:
            return "Elevation"
        case .stepCount:
            return "Step Count"
        }
    }

    var requiresSuperDistance: Bool {
        switch self {
        case .none, .route2d, .stepCount:
            return false
        default:
            return true
        }
    }

    var requiresRouteData: Bool {
        switch self {
        case .route2d, .route3d, .elevation, .splits:
            return true
        default:
            return false
        }
    }

    var image: UIImage? {
        return UIImage(named: "glyph_graphs_" + rawValue)
    }
}
