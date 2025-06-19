// Licensed under the Any Distance Source-Available License
//
//  LightBlurGlyph.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/28/23.
//

import SwiftUI

struct LightBlurGlyph: View {
    var symbolName: String
    var size: CGFloat

    var body: some View {
        Color.white
            .opacity(0.8)
            .frame(width: size, height: size)
            .mask {
                Image(systemName: symbolName)
                    .resizable()
            }
    }
}
