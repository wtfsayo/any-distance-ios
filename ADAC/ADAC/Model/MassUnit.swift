// Licensed under the Any Distance Source-Available License
//
//  MassUnit.swift
//  ADAC
//
//  Created by Any Distance on 8/1/22.
//

import Foundation

enum MassUnit: Int, Codable {
    case pounds
    case kilograms
    
    var abbreviation: String {
        switch self {
        case .pounds:
            return "lb"
        case .kilograms:
            return "kg"
        }
    }

    var fullName: String {
        switch self {
        case .pounds:
            return "pounds"
        case .kilograms:
            return "kilograms"
        }
    }

    var fullNameSingular: String {
        switch self {
        case .pounds:
            return "pound"
        case .kilograms:
            return "kilogram"
        }
    }
}
