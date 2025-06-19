// Licensed under the Any Distance Source-Available License
//
//  Collectible3DSwiftUIView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/6/23.
//

import UIKit
import SwiftUI

struct Collectible3DSwiftUIView: UIViewRepresentable {
    let collectible: Collectible
    let earned: Bool
    let engraveInitials: Bool

    func makeUIView(context: Context) -> Collectible3DView {
        let view = Collectible3DView(frame: .zero)
        view.setup(withCollectible: collectible,
                   earned: earned,
                   engraveInitials: engraveInitials)
        return view
    }

    func updateUIView(_ uiView: Collectible3DView, context: Context) {}
}

struct Gear3DSwiftUIView: UIViewRepresentable {
    var usdzName: String
    var color: GearColor

    func makeUIView(context: Context) -> Gear3DView {
        let view = Gear3DView(frame: .zero)
        if let url = Bundle.main.url(forResource: usdzName, withExtension: "usdz") {
            view.setup(withLocalUsdzUrl: url, color: color)
        }
        return view
    }

    func updateUIView(_ uiView: Gear3DView, context: Context) {
        uiView.setColor(color: color)
    }
}
