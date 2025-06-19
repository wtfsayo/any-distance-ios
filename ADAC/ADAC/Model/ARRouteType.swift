// Licensed under the Any Distance Source-Available License
//
//  ARRouteType.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/18/22.
//

import Foundation

enum ARRouteType: Int {
    case route
    case routePlusStats
    case fullLayout

    var displayName: String {
        switch self {
        case .route:
            return "Route"
        case .routePlusStats:
            return "Route + Stats"
        case .fullLayout:
            return "Full Layout"
        }
    }
}
