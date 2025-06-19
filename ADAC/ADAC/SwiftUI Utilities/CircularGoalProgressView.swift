// Licensed under the Any Distance Source-Available License
//
//  CircularGoalProgressView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/29/23.
//

import SwiftUI

struct CircularGoalProgressView: UIViewRepresentable {
    var style: CircularGoalProgressIndicatorStyle
    var progress: CGFloat

    func makeUIView(context: Context) -> CircularGoalProgressIndicator {
        let indicator = CircularGoalProgressIndicator(frame: .zero)
        indicator.style = style
        indicator.progress = progress
        return indicator
    }

    func updateUIView(_ uiView: CircularGoalProgressIndicator, context: Context) {
        uiView.style = style
        uiView.progress = progress
    }
}
