// Licensed under the Any Distance Source-Available License
//
//  CircularGoalProgressIndicator.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/23/20.
//

import UIKit

final class CircularGoalProgressIndicator: UIView {

    // MARK: - Constants

    var lineWidth: CGFloat {
        switch style {
        case .large:
            return 21.0
        case .medium:
            return 6.0
        case .small:
            return 4.0
        }
    }

    var dotDiameter: CGFloat {
        switch style {
        case .large:
            return 27.0
        case .medium:
            return 10.0
        case .small:
            return 6.0
        }
    }

    var dotShadowDiameter: CGFloat {
        switch style {
        case .large:
            return 130.0
        case .medium:
            return 60.0
        case .small:
            return 30.0
        }
    }

    // MARK: - Variables

    var style: CircularGoalProgressIndicatorStyle = .large {
        didSet {
            updateAppearance()
        }
    }

    private let gradientLayer: CAGradientLayer = {
        let gradientLayer = CAGradientLayer()
        gradientLayer.type = .conic
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 0.46, y: 0)
        return gradientLayer
    }()

    private var backgroundCircleLayer: CAShapeLayer?
    private var over100CircleLayer: CAShapeLayer?

    private lazy var dot: UIView = {
        let dot = UIView()
        dot.backgroundColor = GoalProgressIndicator().trackGradientColors.last
        dot.layer.cornerRadius = dotDiameter / 2
        return dot
    }()

    private var dotShadow = UIImageView(image: UIImage(named: "circular_goal_progress_dot_shadow"))

    private let gradientColors = GoalProgressIndicator().trackGradientColors

    @Clamped(initialValue: 0.0, 0...CGFloat.greatestFiniteMagnitude)
    var progress: CGFloat {
        didSet {
            updateAppearance()
        }
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        backgroundCircleLayer = CAShapeLayer()
        backgroundCircleLayer?.fillColor = UIColor.clear.cgColor
        backgroundCircleLayer?.strokeColor = UIColor.white.withAlphaComponent(0.07).cgColor
        backgroundCircleLayer?.lineWidth = lineWidth
        layer.addSublayer(backgroundCircleLayer!)

        gradientLayer.colors = gradientColors.map { $0.cgColor }
        gradientLayer.locations = [0, 0.5, 1]
        layer.addSublayer(gradientLayer)

        over100CircleLayer = CAShapeLayer()
        over100CircleLayer?.fillColor = UIColor.clear.cgColor
        over100CircleLayer?.strokeColor = gradientColors.last?.cgColor
        over100CircleLayer?.lineWidth = lineWidth
        over100CircleLayer?.isHidden = true
        layer.addSublayer(over100CircleLayer!)

        addSubview(dot)
        addSubview(dotShadow)
        updateAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateAppearance()
    }

    func updateAppearance() {
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        let backgroundPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        backgroundCircleLayer?.path = backgroundPath.cgPath
        backgroundCircleLayer?.frame = bounds
        backgroundCircleLayer?.strokeColor = style == .small ?
                                             UIColor.black.cgColor :
                                             UIColor.white.withAlphaComponent(0.07).cgColor

        gradientLayer.frame = bounds

        let startAngle: CGFloat = -1 * .pi / 2
        let arcAngle = 2 * .pi * progress //.clamped(to: 0...1)

        dot.frame = CGRect(x: radius * cos(startAngle + arcAngle) + center.x - dotDiameter / 2,
                           y: radius * sin(startAngle + arcAngle) + center.y - dotDiameter / 2,
                           width: dotDiameter,
                           height: dotDiameter)

        dotShadow.frame = CGRect(x: radius * cos(startAngle + arcAngle) + center.x - dotShadowDiameter / 2,
                                 y: radius * sin(startAngle + arcAngle) + center.y - dotShadowDiameter / 2,
                                 width: dotShadowDiameter,
                                 height: dotShadowDiameter)

        let color = colorOnGradient(withColors: gradientColors, percentage: progress)
        dotShadow.tintColor = color
        dot.backgroundColor = color
//        dot.applySketchShadow(color: color,
//                              alpha: 0.85,
//                              x: 0,
//                              y: 0,
//                              blur: 40,
//                              spread: 300)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if progress >= 0.99 {
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        } else {
            gradientLayer.endPoint = CGPoint(x: 0.46, y: 0)
        }
        CATransaction.commit()

        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: startAngle + arcAngle, clockwise: true)
        let mask = CAShapeLayer()
        mask.fillColor = UIColor.clear.cgColor
        mask.strokeColor = UIColor.white.cgColor
        mask.lineWidth = lineWidth
        mask.path = path.cgPath
        mask.lineCap = .round
        gradientLayer.mask = mask

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if progress > 1.0 {
            let leftoverProgress = (progress - 1.0).clamped(to: 0...1)
            let over100ArcAngle = 2 * .pi * leftoverProgress
            let over100Path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: startAngle + over100ArcAngle, clockwise: true)
            over100CircleLayer?.path = over100Path.cgPath
            over100CircleLayer?.lineCap = .round
            over100CircleLayer?.isHidden = false
        } else {
            over100CircleLayer?.isHidden = true
        }
        CATransaction.commit()
    }

    private func colorOnGradient(withColors colors: [UIColor], percentage: CGFloat) -> UIColor {
        if percentage >= 1 {
            return colors.last?.lighter(by: 10) ?? .white
        } else if percentage == 0 {
            return colors.first?.lighter(by: 10)! ?? .white
        }

        var firstColor: UIColor?
        var secondColor: UIColor?
        var firstPercent: CGFloat = 0
        var secondPercent: CGFloat = 1

        for (i, color) in colors.enumerated() {
            let colorPercent = CGFloat(i) / CGFloat(colors.count - 1)
            if colorPercent < percentage {
                firstColor = color
                firstPercent = colorPercent
            }

            if colorPercent >= percentage && secondColor == nil {
                secondColor = color
                secondPercent = colorPercent
            }
        }

        guard let color1 = firstColor,
              let color2 = secondColor else {
            return .white
        }

        let adjustedPercent = (percentage - firstPercent) / (secondPercent - firstPercent)

        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0

        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0

        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return UIColor(red: r1 + adjustedPercent * (r2 - r1),
                       green: g1 + adjustedPercent * (g2 - g1),
                       blue: b1 + adjustedPercent * (b2 - b1),
                       alpha: 1).lighter(by: 10)!
    }
}

enum CircularGoalProgressIndicatorStyle {
    case large
    case medium
    case small
}
