// Licensed under the Any Distance Source-Available License
//
//  ConfettiSwiftUIView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/13/22.
//

import SwiftUI

struct ConfettiSwiftUIView: UIViewRepresentable {
    typealias UIViewType = ConfettiView
    var confettiColors: [UIColor]
    var style: ConfettiViewStyle = .large
    var beginAtTimeZero: Bool = true
    @Binding var isStarted: Bool

    func makeUIView(context: Context) -> ConfettiView {
        let view = ConfettiView(frame: .zero)
        view.colors = confettiColors
        view.style = style
        if isStarted {
            view.startConfetti(beginAtTimeZero: beginAtTimeZero)
        }
        return view
    }

    func updateUIView(_ uiView: ConfettiView, context: Context) {
        if isStarted {
            uiView.startConfetti(beginAtTimeZero: beginAtTimeZero)
        } else {
            uiView.stopConfetti()
        }
    }
}

#Preview {
    ConfettiSwiftUIView(confettiColors: [.adOrange, .adOrangeLighter, .adYellow, .adRed, .adBrown],
                        isStarted: .constant(true))
    .ignoresSafeArea()
}
