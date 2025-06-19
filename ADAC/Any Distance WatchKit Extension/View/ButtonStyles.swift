// Licensed under the Any Distance Source-Available License
//
//  ButtonStyles.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 8/17/22.
//

import SwiftUI

struct TransparentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}

struct ADWatchButtonStyle: ButtonStyle {
    var foregroundColor: Color
    var backgroundColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}
