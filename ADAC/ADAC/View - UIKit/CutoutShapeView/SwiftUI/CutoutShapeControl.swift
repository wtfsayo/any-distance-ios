// Licensed under the Any Distance Source-Available License
//
//  CropControl.swift
//  SwiftPlayground
//
//  Created by Jarod Luebbert on 10/3/22.
//

import SwiftUI

struct CutoutShapeControl: UIViewRepresentable {
    @State var image: UIImage?
    @State var cutoutShape: CutoutShape

    func makeUIView(context: Context) -> CutoutShapeView {
        return CutoutShapeView(frame: .zero)
    }
    
    func updateUIView(_ uiView: CutoutShapeView, context: Context) {
        uiView.debugEnabled = true
        uiView.cutoutShape = cutoutShape
        uiView.image = image
    }

}

struct CutoutShapeControl_Previews: PreviewProvider {
    static var previews: some View {
        CutoutShapeControl(image: Fill.being.image,
                           cutoutShape: .circle)
    }
}
