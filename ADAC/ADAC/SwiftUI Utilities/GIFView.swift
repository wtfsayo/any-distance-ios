// Licensed under the Any Distance Source-Available License
//
//  GIFView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/7/22.
//

import SwiftyGif
import SwiftUI

struct GIFView: UIViewRepresentable {
    var gifName: String

    func makeUIView(context: Context) -> UIImageView {
        if let image = try? UIImage(gifName: gifName) {
            return UIImageView(gifImage: image)
        }

        return UIImageView(frame: .zero)
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}
}
