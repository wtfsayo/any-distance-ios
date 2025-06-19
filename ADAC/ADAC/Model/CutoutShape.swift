// Licensed under the Any Distance Source-Available License
//
//  CutoutShape.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/22/20.
//

import UIKit

enum CutoutShape: String, CaseIterable, Codable {
    case oval, rounded, fullScreen, arch, dip, circle, dots, shield, peak,
         stripe, wave, spark

    var displayName: String {
        switch self {
        case .oval: return "Oval"
        case .circle: return "Circle"
        case .arch: return "Arch"
        case .dip: return "Dip"
        case .rounded: return "Rounded"
        case .fullScreen: return "Full"
        case .dots: return "Dots"
        case .shield: return "Shield"
        case .peak: return "Peak"
        case .stripe: return "Stripes"
        case .wave: return "Wave"
        case .spark: return "Spark"
        }
    }

    var requiresSuperDistance: Bool {
        switch self {
        case .oval, .rounded, .fullScreen, .arch, .dip, .circle:
            return false
        default:
            return true
        }
    }

    var editorControlsImage: UIImage? {
        if self == .fullScreen {
            return UIImage(named: "glyph_full_screen")
        }

        return UIImage(named: "glyph_" + rawValue)
    }

    var editorControlsImageEdgeInsets: UIEdgeInsets {
        if self == .fullScreen {
            return UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)
        }

        return UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
    }

    var image: UIImage? {
        switch self {
        case .fullScreen:
            return nil
        default:
            return UIImage(named: "cutout_" + rawValue)
        }
    }
    
    var insets: UIEdgeInsets {
        switch self {
        case .oval:
            return .init(top: 30.0, left: 15.0, bottom: 18.0, right: 15.0)
        case .rounded:
            return .init(top: 30.0, left: 15.0, bottom: 20.0, right: 15.0)
        case .arch:
            return .init(top: 35.0, left: 15.0, bottom: 20.0, right: 15.0)
        case .dip:
            return .init(top: 30.0, left: 15.0, bottom: 20.0, right: 15.0)
        case .shield:
            return .init(top: 75.0, left: 15.0, bottom: 50.0, right: 15.0)
        case .stripe:
            return .init(top: 70.0, left: 0.0, bottom: 0.0, right: 0.0)
        case .wave:
            return .init(top: 50.0, left: 0.0, bottom: 0.0, right: 0.0)
        case .spark:
            return .init(top: 75.0, left: 0.0, bottom: 50.0, right: 0.0)
        case .circle:
            return .init(top: 125.0, left: 15.0, bottom: 125.0, right: 15.0)
        case .peak:
            return .init(top: 50.0, left: 0.0, bottom: 0.0, right: 0.0)
        case .dots:
            return .init(top: 40.0, left: 20.0, bottom: 50.0, right: 35.0)
        case .fullScreen:
            return .zero
        }
    }

}
