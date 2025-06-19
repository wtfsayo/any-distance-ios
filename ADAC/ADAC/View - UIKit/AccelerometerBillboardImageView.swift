// Licensed under the Any Distance Source-Available License
//
//  AccelerometerBillboardImageView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/10/21.
//

import UIKit
import Combine

final class AccelerometerBillboardImageView: UIImageView {

    // MARK: - Variables

    private var motionManager = MotionManager()
    private var subscribers: Set<AnyCancellable> = []

    // MARK: - Setup

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        layer.transform.m34 = -1/500
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        motionManager.$pitch.sink { [weak self] pitch in
            let rotationAnimationX = CABasicAnimation(keyPath: "transform.rotation.x")
            rotationAnimationX.toValue = NSNumber(floatLiteral: (pitch - 0.5) * 2.5)
            rotationAnimationX.duration = 0.1
            rotationAnimationX.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self?.layer.add(rotationAnimationX, forKey: "rotationAnimationX")
        }.store(in: &subscribers)

        motionManager.$roll.sink { [weak self] roll in
            let rotationAnimationY = CABasicAnimation(keyPath: "transform.rotation.y")
            rotationAnimationY.toValue = NSNumber(floatLiteral: roll * -2.5)
            rotationAnimationY.duration = 0.1
            rotationAnimationY.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self?.layer.add(rotationAnimationY, forKey: "rotationAnimationY")
        }.store(in: &subscribers)
    }
}
