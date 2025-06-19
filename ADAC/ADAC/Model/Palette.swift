// Licensed under the Any Distance Source-Available License
//
//  Palette.swift
//  ADAC
//
//  Created by Daniel Kuntz on 10/29/21.
//

import UIKit
import UIImageColors

struct Palette: Codable, Equatable  {
    var name: String
    var backgroundColor: UIColor
    var foregroundColor: UIColor
    var accentColor: UIColor
    
    var id: String {
        name.lowercased().replacingOccurrences(of: " ", with: "_")
    }
    
    static let defaultPalettes: [Palette] = [.dark, .light]

    static let dark: Palette = Palette(name: "Dark",
                                       backgroundColor: .black,
                                       foregroundColor: .white,
                                       accentColor: UIColor(realRed: 255, green: 198, blue: 99))

    static let light: Palette = Palette(name: "Light",
                                        backgroundColor: .white,
                                        foregroundColor: .black,
                                        accentColor: UIColor(realRed: 255, green: 198, blue: 99))

    var requiresSuperDistance: Bool {
        return name != "Dark" && name != "Light"
    }

    enum CodingKeys: String, CodingKey {
        case name
        case backgroundColor
        case foregroundColor
        case accentColor
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(EncodableColor(backgroundColor), forKey: .backgroundColor)
        try container.encode(EncodableColor(foregroundColor), forKey: .foregroundColor)
        try container.encode(EncodableColor(accentColor), forKey: .accentColor)
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)

        let background = try values.decode(EncodableColor.self, forKey: .backgroundColor)
        let foreground = try values.decode(EncodableColor.self, forKey: .foregroundColor)
        let accent = try values.decode(EncodableColor.self, forKey: .accentColor)
        backgroundColor = background.uiColor
        foregroundColor = foreground.uiColor
        accentColor = accent.uiColor
    }

    init(name: String, backgroundColor: UIColor, foregroundColor: UIColor, accentColor: UIColor) {
        self.name = name
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.accentColor = accentColor
    }
    
    static func palettes(from image: UIImage) async -> [Palette] {
        return await withCheckedContinuation({ continuation in
            Self.generatePalettes(fromImage: image) { palettes in
                continuation.resume(returning: palettes)
            }
        })
    }

    static func generatePalettes(fromImage image: UIImage, completion: @escaping ([Palette]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let colors = image.getColors(quality: .low) {
                var primary = colors.primary! //.withBrightness(1, saturation: 0.5)
                if primary.isReallyDark {
                    primary = colors.background
                }
                primary = primary.withMinBrightness(0.7)
                let secondary = colors.secondary.withMinBrightness(0.7) //.withBrightness(1, saturation: 0.5)

                var detail = colors.detail! //.withBrightness(1, saturation: 0.5)
                if detail.isReallyDark {
                    detail = primary
                }
                detail = colors.detail.withMinBrightness(0.7)

                var palettes: [Palette] = [Palette.dark, Palette.light]
                palettes.append(Palette(name: "Magic 1", backgroundColor: .black, foregroundColor: primary, accentColor: detail.withBrightness(1, saturation: 0.7)))
                palettes.append(Palette(name: "Magic 2", backgroundColor: .black, foregroundColor: secondary, accentColor: detail.withBrightness(1, saturation: 0.7)))
                palettes.append(Palette(name: "Magic 3", backgroundColor: .black, foregroundColor: detail, accentColor: primary.withBrightness(1, saturation: 0.7)))
                palettes.append(Palette(name: "Magic 4", backgroundColor: .black, foregroundColor: detail, accentColor: secondary.withBrightness(1, saturation: 0.7)))
                palettes.append(Palette(name: "Magic 5", backgroundColor: primary, foregroundColor: .black, accentColor: detail.withBrightness(1, saturation: 0.7)))
                palettes.append(Palette(name: "Magic 6", backgroundColor: secondary, foregroundColor: .black, accentColor: detail.withBrightness(1, saturation: 0.7)))
                palettes.append(Palette(name: "Magic 7", backgroundColor: detail, foregroundColor: .black, accentColor: primary.withBrightness(1, saturation: 0.7)))
                palettes.append(Palette(name: "Magic 8", backgroundColor: detail, foregroundColor: .black, accentColor: secondary.withBrightness(1, saturation: 0.7)))

                DispatchQueue.main.async {
                    completion(palettes)
                }
            }
        }
    }

    static func ==(lhs: Palette, rhs: Palette) -> Bool {
        return lhs.name == rhs.name &&
               lhs.backgroundColor.toHexString() == rhs.backgroundColor.toHexString() &&
               lhs.foregroundColor.toHexString() == rhs.foregroundColor.toHexString() &&
               lhs.accentColor.toHexString() == rhs.accentColor.toHexString()
    }
}

struct EncodableColor: Codable {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0

    init(_ uiColor: UIColor) {
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    }

    var uiColor: UIColor {
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

extension UIColor {
    var isReallyDark: Bool {
        return isBrightnessUnder(0.015)
    }

    func isBrightnessUnder(_ threshold: CGFloat) -> Bool {
        var b: CGFloat = 0
        getHue(nil, saturation: nil, brightness: &b, alpha: nil)
        return b <= threshold
    }

    func withMinBrightness(_ minB: CGFloat) -> UIColor {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        return UIColor(hue: h, saturation: s, brightness: max(b, minB), alpha: 1)
    }
}
