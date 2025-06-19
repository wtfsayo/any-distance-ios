// Licensed under the Any Distance Source-Available License
//
//  UnitConverter.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/26/20.
//

import Foundation

final class UnitConverter {
    
    // MARK: - Distance
    
    static func meters<T: BinaryFloatingPoint>(_ meters: T, toUnit unit: DistanceUnit) -> T {
        switch unit {
        case .miles:
            return metersToMiles(meters)
        case .kilometers:
            return metersToKilometers(meters)
        }
    }
    
    static func metersToFeet<T: BinaryFloatingPoint>(_ meters: T) -> T {
        return meters * 3.28084
    }

    static func metersToMiles<T: BinaryFloatingPoint>(_ meters: T) -> T {
        return meters / 1609.34
    }

    static func metersToKilometers<T: BinaryFloatingPoint>(_ meters: T) -> T {
        return meters / 1000
    }

    static func value<T: BinaryFloatingPoint>(_ value: T, inUnitToMeters unit: DistanceUnit) -> T {
        switch unit {
        case .miles:
            return milesToMeters(value)
        case .kilometers:
            return kilometersToMeters(value)
        }
    }

    static func milesToMeters<T: BinaryFloatingPoint>(_ miles: T) -> T {
        return miles * 1609.34
    }

    static func kilometersToMeters<T: BinaryFloatingPoint>(_ kilometers: T) -> T {
        return kilometers * 1000
    }
    
    // MARK: - Mass
    
    static func value<T: BinaryFloatingPoint>(_ value: T, fromUnit: MassUnit, toUnit: MassUnit) -> T {
        if fromUnit == .kilograms && toUnit == .pounds {
            return value * 2.20462
        } else if fromUnit == .pounds && toUnit == .kilograms {
            return value / 2.20462
        } else {
            return value
        }
    }
}
