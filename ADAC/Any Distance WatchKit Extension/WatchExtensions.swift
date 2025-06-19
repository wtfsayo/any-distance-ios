// Licensed under the Any Distance Source-Available License
//
//  WatchExtensions.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 8/16/22.
//

import Foundation
import UIKit
import SwiftUI

public extension UIColor {
    /// Initialize a new color from HEX string representation.
    ///
    /// - Parameter hexString: hex string
    convenience init(hexString: String) {
        let hexString = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner   = Scanner(string: hexString)

        if hexString.hasPrefix("#") {
            scanner.scanLocation = 1
        }

        var color: UInt32 = 0

        if scanner.scanHexInt32(&color) {
            self.init(hex: color, useAlpha: hexString.count > 7)
        } else {
            self.init(hex: 0x000000)
        }
    }

    /// Initialize a new color from HEX string as UInt32 with optional alpha chanell.
    ///
    /// - Parameters:
    ///   - hex: hex value
    ///   - alphaChannel: `true` to include alpha channel, `false` to make it opaque.
    convenience init(hex: UInt32, useAlpha alphaChannel: Bool = false) {
        let mask = UInt32(0xFF)

        let r = hex >> (alphaChannel ? 24 : 16) & mask
        let g = hex >> (alphaChannel ? 16 : 8) & mask
        let b = hex >> (alphaChannel ? 8 : 0) & mask
        let a = alphaChannel ? hex & mask : 255

        let red   = CGFloat(r) / 255
        let green = CGFloat(g) / 255
        let blue  = CGFloat(b) / 255
        let alpha = CGFloat(a) / 255

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension Color {
    /// Creates a color from a hexadecimal color code.
    ///
    /// - Parameter hexadecimal: A hexadecimal representation of the color.
    ///
    /// - Returns: A `Color` from the given color code. Returns `nil` if the code is invalid.
    public init!(hexadecimal string: String) {
        var string: String = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if string.hasPrefix("#") {
            _ = string.removeFirst()
        }

        if !string.count.isMultiple(of: 2), let last = string.last {
            string.append(last)
        }

        if string.count > 8 {
            string = String(string.prefix(8))
        }

        let scanner = Scanner(string: string)

        var color: UInt64 = 0

        scanner.scanHexInt64(&color)

        if string.count == 2 {
            let mask = 0xFF

            let g = Int(color) & mask

            let gray = Double(g) / 255.0

            self.init(.sRGB, red: gray, green: gray, blue: gray, opacity: 1)
        } else if string.count == 4 {
            let mask = 0x00FF

            let g = Int(color >> 8) & mask
            let a = Int(color) & mask

            let gray = Double(g) / 255.0
            let alpha = Double(a) / 255.0

            self.init(.sRGB, red: gray, green: gray, blue: gray, opacity: alpha)
        } else if string.count == 6 {
            let mask = 0x0000FF

            let r = Int(color >> 16) & mask
            let g = Int(color >> 8) & mask
            let b = Int(color) & mask

            let red = Double(r) / 255.0
            let green = Double(g) / 255.0
            let blue = Double(b) / 255.0

            self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
        } else if string.count == 8 {
            let mask = 0x000000FF

            let r = Int(color >> 24) & mask
            let g = Int(color >> 16) & mask
            let b = Int(color >> 8) & mask
            let a = Int(color) & mask

            let red = Double(r) / 255.0
            let green = Double(g) / 255.0
            let blue = Double(b) / 255.0
            let alpha = Double(a) / 255.0

            self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
        } else {
            return nil
        }
    }

    /// Creates a color from a 6-digit hexadecimal color code.
    public init(hexadecimal6: Int) {
        let red = Double((hexadecimal6 & 0xFF0000) >> 16) / 255.0
        let green = Double((hexadecimal6 & 0x00FF00) >> 8) / 255.0
        let blue = Double(hexadecimal6 & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

extension MKMapRect: Equatable {
    public static func == (lhs: MKMapRect, rhs: MKMapRect) -> Bool {
        return lhs.origin.x == rhs.origin.x &&
               lhs.origin.y == rhs.origin.y &&
               lhs.size.width == rhs.size.width &&
               lhs.size.height == rhs.size.height
    }

    /// Returns the actual visible map rect displayed by a SwiftUI Map
    func expandedMapRectForScreen(withSafeAreaInsets safeAreaInsets: EdgeInsets) -> MKMapRect {
        let screenSize = WKInterfaceDevice.current().screenBounds.size
        let safeAreaRect = CGRect(x: safeAreaInsets.leading,
                                  y: safeAreaInsets.top,
                                  width: screenSize.width - safeAreaInsets.leading - safeAreaInsets.trailing,
                                  height: screenSize.height - safeAreaInsets.top - safeAreaInsets.bottom)
        let fittedRect = CGSize.aspectFit(aspectRatio: CGSize(width: self.size.width,
                                                              height: self.size.height),
                                          inRect: safeAreaRect)
        return MKMapRect(x: self.origin.x - ((fittedRect.origin.x / fittedRect.width) * self.width),
                         y: self.origin.y - ((fittedRect.origin.y / fittedRect.height) * self.height),
                         width: self.width * screenSize.width / fittedRect.width,
                         height: self.height * screenSize.height / fittedRect.height)
    }
}

extension NSUbiquitousKeyValueStore {
    var recentlyRecordedActivityTypes: [ActivityType] {
        get {
            if let data = data(forKey: "recentlyRecordedActivityTypes") {
                do {
                    return try JSONDecoder().decode([ActivityType].self, from: data)
                } catch {}
            }
            return []
        }

        set {
            do {
                let encoded = try JSONEncoder().encode(newValue.uniqued())
                set(encoded, forKey: "recentlyRecordedActivityTypes")
            } catch {}
        }
    }

    var autoPauseOn: Bool {
        get {
            if object(forKey: "autoPauseOn") == nil {
                return true
            }

            return bool(forKey: "autoPauseOn")
        }

        set {
            set(newValue, forKey: "autoPauseOn")
        }
    }
}
