// Licensed under the Any Distance Source-Available License
//
//  CodableColor.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/3/22.
//

import UIKit

struct CodableColor: Codable {
    var red: CGFloat = 0.0, green: CGFloat = 0.0, blue: CGFloat = 0.0, alpha: CGFloat = 0.0

    var uiColor: UIColor {
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    init?(uiColor: UIColor?) {
        guard let uiColor = uiColor else {
            return nil
        }

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    }

    init(string: String) {
        if string.isEmpty {
            return
        }
        
        func decodeHex() {
            let uiColor = UIColor(hex: string)
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }

        if let data = string.data(using: .utf8) {
            do {
                self = try JSONDecoder().decode(CodableColor.self, from: data)
            } catch {
                decodeHex()
            }
        } else {
            decodeHex()
        }
    }
}
