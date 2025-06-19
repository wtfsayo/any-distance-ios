// Licensed under the Any Distance Source-Available License
//
//  ItemType.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/19/22.
//

import UIKit
import Foundation

enum ItemType: String, Codable {
    case medal
    case foundItem

    var description: String {
        switch self {
        case .medal:
            return "Achievement"
        case .foundItem:
            return "Found Item"
        }
    }

    var backgroundColor: UIColor {
        switch self {
        case .medal:
            return UIColor(white: 0.2, alpha: 1)
        case .foundItem:
            return .adOrangeLighter
        }
    }

    var badgeImage: UIImage? {
        switch self {
        case .medal:
            return UIImage(named: "glyph_achievement")
        case .foundItem:
            return UIImage(named: "glyph_box")
        }
    }

    var badegeImageColor: UIColor {
        switch self {
        case .medal:
            return .white
        case .foundItem:
            return .black
        }
    }

    var sortOrder: Int {
        switch self {
        case .medal:
            return 1
        case .foundItem:
            return 0
        }
    }
}
