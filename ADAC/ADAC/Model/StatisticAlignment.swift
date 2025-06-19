// Licensed under the Any Distance Source-Available License
//
//  Alignment.swift
//  Alignment
//
//  Created by Daniel Kuntz on 8/3/21.
//

import UIKit

enum StatisticAlignment: String, Codable, CaseIterable {
    case left
    case center
    case right

    var icon: UIImage? {
        return UIImage(named: "glyph_align_" + rawValue)
    }

    init(idx: Int) {
        self = StatisticAlignment.allCases[idx]
    }

    var idx: Int {
        return StatisticAlignment.allCases.firstIndex(of: self)!
    }
}
