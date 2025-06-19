// Licensed under the Any Distance Source-Available License
//
//  CoordinateRegion.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/19/22.
//

import Foundation
import CoreLocation

struct CoordinateRegion: Codable {
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double

    func contains(location: CLLocation) -> Bool {
        let center = CLLocation(latitude: latitude, longitude: longitude)
        let distanceMeters = center.distance(from: location)
        return distanceMeters <= radiusMeters
    }

    private func deg2rad(_ deg: Double) -> Double {
        return deg * .pi / 180.0
    }
}
