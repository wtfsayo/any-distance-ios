// Licensed under the Any Distance Source-Available License
//
//  Font.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/26/21.
//

import UIKit

enum ADFont: String, CaseIterable, Codable {
    case og
    case rounded
    case digit
    case artemis
    case bold
    case classical
    case chonk
    case mono
    case swish
    case swishIt

    var displayName: String {
        switch self {
        case .og: return "OG"
        case .rounded: return "Rounded"
        case .digit: return "Digit"
        case .artemis: return "Artemis"
        case .bold: return "Bold"
        case .classical: return "Classical"
        case .chonk: return "Chonk"
        case .mono: return "Mono"
        case .swish: return "Swish"
        case .swishIt: return "Italic"
        }
    }

    var editorControlsImage: UIImage? {
        if self == .swishIt {
            return UIImage(named: "glyph_font_swish_it")
        }

        return UIImage(named: "glyph_font_" + rawValue)
    }

    var primaryFont: UIFont? {
        switch self {
        case .og: return UIFont.presicav(size: 30)
        case .rounded: return UIFont(descriptor: UIFont.systemFont(ofSize: 37, weight: .medium).fontDescriptor.withDesign(.rounded)!, size: 36)
        case .digit: return UIFont(name: "Digital-7", size: 45)
        case .artemis: return UIFont(name: "NasalizationRg-Regular", size: 37)
        case .bold: return UIFont.systemFont(ofSize: 36, weight: .bold)
        case .classical: return UIFont(name: "Futura-Medium", size: 36)
        case .chonk: return UIFont(name: "JCHEadA", size: 42)
        case .mono: return UIFont.monospacedSystemFont(ofSize: 34, weight: .regular)
        case .swish: return UIFont(name: "Optima-Regular", size: 36)
        case .swishIt: return UIFont(name: "Didot-Italic", size: 36)
        }
    }

    var secondaryFont: UIFont? {
        switch self {
        case .og: return UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        case .rounded: return UIFont(descriptor: UIFont.systemFont(ofSize: 30, weight: .medium).fontDescriptor.withDesign(.rounded)!, size: 11)
        case .digit: return UIFont(name: "Menlo", size: 11)
        case .artemis: return UIFont(name: "NasalizationRg-Regular", size: 11)
        case .bold: return UIFont.systemFont(ofSize: 11, weight: .semibold)
        case .classical: return UIFont(name: "AvenirNext-Medium", size: 11)
        case .chonk: return UIFont(name: "GillSans", size: 11)
        case .mono: return UIFont.presicav(size: 10)
        case .swish: return UIFont(name: "Osaka", size: 11)
        case .swishIt: return UIFont(name: "Osaka", size: 11)
        }
    }

    var tertiaryFont: UIFont? {
        switch self {
        case .og: return UIFont.presicav(size: 8.5)
        case .rounded: return UIFont(descriptor: UIFont.systemFont(ofSize: 30, weight: .medium).fontDescriptor.withDesign(.rounded)!, size: 9)
        case .digit: return UIFont(name: "Menlo", size: 9)
        case .artemis: return UIFont(name: "NasalizationRg-Regular", size: 9)
        case .bold: return UIFont.systemFont(ofSize: 9, weight: .semibold)
        case .classical: return UIFont(name: "AvenirNext-Medium", size: 9)
        case .chonk: return UIFont(name: "GillSans", size: 9)
        case .mono: return UIFont.presicav(size: 8.5)
        case .swish: return UIFont(name: "Osaka", size: 9)
        case .swishIt: return UIFont(name: "Osaka", size: 9)
        }
    }

    var superscriptBaselineOffset: Float {
        switch self {
        case .og:
            return 12
        case .rounded:
            return 18
        case .digit:
            return 17
        case .artemis:
            return 17
        case .bold:
            return 16
        case .classical:
            return 18
        case .chonk:
            return 19
        case .mono:
            return 16
        case .swish:
            return 14
        case .swishIt:
            return 15
        }
    }
}
