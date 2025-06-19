// Licensed under the Any Distance Source-Available License
//
//  ShapeWithHole.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/10/23.
//

import SwiftUI

struct ShapeWithHole: Shape {
    let cutout: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Rectangle().path(in: rect)
        let hole = Circle().path(in: CGRect(origin: CGPoint(x: rect.midX - cutout.width / 2, y: rect.midY - cutout.height / 2), size: cutout)).reversed
        path.addPath(hole)
        return path
    }
}

extension Path {
    var reversed: Path {
        let reversedCGPath = UIBezierPath(cgPath: cgPath)
            .reversing()
            .cgPath
        return Path(reversedCGPath)
    }
}
