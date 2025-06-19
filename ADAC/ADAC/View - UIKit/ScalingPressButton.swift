// Licensed under the Any Distance Source-Available License
//
//  ScalingPressButton.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/5/21.
//

import UIKit

class ScalingPressButton: ContinuousCornerButton {
    var id: String = ""

    var borderColor: UIColor? = .clear {
        didSet {
            borderView?.layer.borderColor = borderColor?.cgColor
        }
    }

    var borderWidth: CGFloat = 3 {
        didSet {
            borderView?.layer.borderWidth = borderWidth
        }
    }

    var borderSize: CGSize = .zero {
        didSet {
            borderWidthConstraint?.constant = borderSize.width
            borderHeightConstraint?.constant = borderSize.height
        }
    }

    var borderCornerRadius: CGFloat = 0 {
        didSet {
            borderView?.layer.cornerRadius = borderCornerRadius
        }
    }

    private var borderView: UIView?
    private var borderWidthConstraint: NSLayoutConstraint?
    private var borderHeightConstraint: NSLayoutConstraint?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        startAnimatingPressActions()
        setupBorder()
    }

    private func setupBorder() {
        borderView = UIView()
        borderView?.backgroundColor = .clear
        borderView?.isUserInteractionEnabled = false
        borderView?.layer.cornerCurve = .continuous
        borderColor = .clear
        borderWidth = 3
        borderCornerRadius = 0
        addSubview(borderView!)
        borderView?.autoCenterInSuperview()
        borderWidthConstraint = borderView?.autoSetDimension(.width, toSize: borderSize.width)
        borderHeightConstraint = borderView?.autoSetDimension(.height, toSize: borderSize.height)
    }

    private func startAnimatingPressActions() {
        adjustsImageWhenHighlighted = false
        addTarget(self, action: #selector(animateDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(animateUp), for: [.touchDragExit, .touchCancel, .touchUpInside, .touchUpOutside])
    }

    @objc private func animateDown(sender: UIButton) {
        UIView.animate(withDuration: 0.2,
                       delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: {
                        sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                       }, completion: nil)
    }

    @objc private func animateUp(sender: UIButton) {
        UIView.animate(withDuration: 0.2,
                       delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: {
                        sender.transform = .identity
                       }, completion: nil)
    }
}
