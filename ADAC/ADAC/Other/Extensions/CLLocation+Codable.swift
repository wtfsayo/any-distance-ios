// Licensed under the Any Distance Source-Available License
//
//  CLLocation+Codable.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/19/23.
//

import Foundation
import CoreLocation

extension CLLocation: Encodable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case altitude
        case horizontalAccuracy
        case verticalAccuracy
        case speed
        case course
        case timestamp
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(horizontalAccuracy, forKey: .horizontalAccuracy)
        try container.encode(verticalAccuracy, forKey: .verticalAccuracy)
        try container.encode(speed, forKey: .speed)
        try container.encode(course, forKey: .course)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

struct LocationWrapper: Codable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let altitude: CLLocationDistance
    let timestamp: Date

    init?(from location: CLLocation?) {
        guard let location = location else {
            return nil
        }

        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.timestamp = location.timestamp
    }

    init(latitude: CLLocationDegrees,
         longitude: CLLocationDegrees,
         altitude: CLLocationDistance,
         timestamp: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
    }

    init?(string: String) {
        let components = string.components(separatedBy: ",")
        guard components.count == 4 else {
            return nil
        }

        latitude = Double(components[0]) ?? 0
        longitude = Double(components[1]) ?? 0
        altitude = Double(components[2]) ?? 0
        timestamp = Date(timeIntervalSince1970: Double(components[3]) ?? 0)
    }

    func toString() -> String {
        return "\(latitude),\(longitude),\(altitude),\(timestamp.timeIntervalSince1970)"
    }
}

extension CLLocation {
    convenience init?(wrapper: LocationWrapper?) {
        guard let wrapper = wrapper else {
            return nil
        }

        self.init(coordinate: CLLocationCoordinate2DMake(wrapper.latitude, wrapper.longitude),
                  altitude: wrapper.altitude,
                  horizontalAccuracy: 1.0,
                  verticalAccuracy: 1.0,
                  timestamp: wrapper.timestamp)
    }
}
