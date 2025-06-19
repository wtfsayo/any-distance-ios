// Licensed under the Any Distance Source-Available License
//
//  BackgroundClearView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/29/22.
//

import SwiftUI

struct BackgroundClearView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
