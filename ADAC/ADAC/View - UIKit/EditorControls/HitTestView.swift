// Licensed under the Any Distance Source-Available License
//
//  HitTestView.swift
//  HitTestView
//
//  Created by Daniel Kuntz on 7/28/21.
//

import UIKit

class HitTestView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return outsideBoundsHitTest(point, with: event)
    }
}

class HitTestScrollView: UIScrollView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return outsideBoundsHitTest(point, with: event)
    }
}

extension UIView {
    func outsideBoundsHitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled else { return nil }
        guard !isHidden else { return nil }
        guard alpha >= 0.01 else { return nil }

        for subview in subviews.reversed() {
            let convertedPoint = subview.convert(point, from: self)
            if let candidate = subview.hitTest(convertedPoint, with: event) {
                return candidate
            }
        }
        return nil
    }
}
