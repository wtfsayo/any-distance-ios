// Licensed under the Any Distance Source-Available License
//
//  ConfettiView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/21/21.
//

import UIKit
import QuartzCore

public final class ConfettiView: UIView {
    public var colors = GoalProgressIndicator().trackGradientColors
    public var intensity: Float = 0.8
    public var style: ConfettiViewStyle = .large

    private(set) var emitter: CAEmitterLayer?
    private var active = false
    private var image = UIImage(named: "confetti")?.cgImage

    public func startConfetti(beginAtTimeZero: Bool = true) {
        emitter?.removeFromSuperlayer()
        emitter = CAEmitterLayer()

        if beginAtTimeZero {
            emitter?.beginTime = CACurrentMediaTime()
        }

        emitter?.emitterPosition = CGPoint(x: frame.size.width / 2.0, y: -10)
        emitter?.emitterShape = .line
        emitter?.emitterSize = CGSize(width: frame.size.width, height: 1)

        var cells = [CAEmitterCell]()
        for color in colors {
            cells.append(confettiWithColor(color: color))
        }

        emitter?.emitterCells = cells

        switch style {
        case .large:
            emitter?.birthRate = 4
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.emitter?.birthRate = 0.6
            }
        case .small:
            emitter?.birthRate = 0.35
        }

        layer.addSublayer(emitter!)
        active = true
    }

    public func stopConfetti() {
        emitter?.birthRate = 0
        active = false
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        emitter?.emitterPosition = CGPoint(x: frame.size.width / 2.0, y: -10)
        emitter?.emitterSize = CGSize(width: frame.size.width, height: 1)
    }

    func confettiWithColor(color: UIColor) -> CAEmitterCell {
        let confetti = CAEmitterCell()
        confetti.birthRate = 12.0 * intensity
        confetti.lifetime = 14.0 * intensity
        confetti.lifetimeRange = 0
        confetti.color = color.cgColor
        confetti.velocity = CGFloat(350.0 * intensity)
        confetti.velocityRange = CGFloat(80.0 * intensity)
        confetti.emissionLongitude = CGFloat(Double.pi)
        confetti.emissionRange = CGFloat(Double.pi)
        confetti.spin = CGFloat(3.5 * intensity)
        confetti.spinRange = CGFloat(4.0 * intensity)
        confetti.scaleRange = CGFloat(intensity)
        confetti.scaleSpeed = CGFloat(-0.1 * intensity)
        confetti.contents = image
        confetti.contentsScale = 1.5
        confetti.setValue("plane", forKey: "particleType")
        confetti.setValue(Double.pi, forKey: "orientationRange")
        confetti.setValue(Double.pi / 2, forKey: "orientationLongitude")
        confetti.setValue(Double.pi / 2, forKey: "orientationLatitude")

        if style == .small {
            confetti.contentsScale = 3.0
            confetti.velocity = CGFloat(70.0 * intensity)
            confetti.velocityRange = CGFloat(20.0 * intensity)
        }

        return confetti
    }

    public func isActive() -> Bool {
        return self.active
    }
}

public enum ConfettiViewStyle {
    case large
    case small
}
