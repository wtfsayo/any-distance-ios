// Licensed under the Any Distance Source-Available License
//
//  ContinuousCornerView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/17/20.
//

import UIKit

final class ContinuousCornerView: UIView {
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        layer.cornerCurve = .continuous
    }
}

final class ContinuousCornerImageView: UIImageView {
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        layer.cornerCurve = .continuous
    }
}

class ContinuousCornerButton: UIButton {
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        layer.cornerCurve = .continuous
    }
}
