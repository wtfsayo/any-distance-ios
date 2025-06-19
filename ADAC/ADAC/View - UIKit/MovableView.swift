// Licensed under the Any Distance Source-Available License
//
//  MovableView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/1/21.
//

import UIKit

protocol MovableViewDelegate: AnyObject {
    func movableView(_ movableView: MovableView, finishedTransformingTo newTransform: CGAffineTransform)
    func movableView(_ movableView: MovableView, scaledTo scale: CGFloat)
}

final class MovableView: UIView {

    // MARK: - Variables

    private(set) var panGestureRecognizer: UIPanGestureRecognizer?
    private(set) var pinchGestureRecognizer: UIPinchGestureRecognizer?
    private(set) var rotationGestureRecognizer: UIRotationGestureRecognizer?
    private(set) var doubleTapGestureRecognizer: UITapGestureRecognizer?
    private var activeGestureRecognizerCount: Int = 0
    private var scaleRange: ClosedRange<CGFloat> = 0.5...1.5

    private var currentScale: CGFloat = 1 {
        didSet {
            delegate?.movableView(self, scaledTo: currentScale.clamped(to: scaleRange))
        }
    }
    
    var gesturesEnabled: Bool = true {
        didSet {
            panGestureRecognizer?.isEnabled = gesturesEnabled
            pinchGestureRecognizer?.isEnabled = gesturesEnabled
            rotationGestureRecognizer?.isEnabled = gesturesEnabled
            doubleTapGestureRecognizer?.isEnabled = gesturesEnabled
        }
    }

    var isRotationEnabled: Bool = true {
        didSet {
            if !isRotationEnabled {
                let currentRotation = atan2f(Float(transform.b), Float(transform.a))
                transform = transform.rotated(by: CGFloat(-1 * currentRotation))
            }
        }
    }

    var isScaleEnabled: Bool = true {
        didSet {
            guard isScaleEnabled != oldValue else {
                return
            }

            if !isScaleEnabled {
                transform = transform.scaledBy(x: 1 / transform.a, y: 1 / transform.a)
                currentScale = 1
            } else {
                transform = transform.scaledBy(x: currentScale, y: currentScale)
            }
        }
    }

    weak var delegate: MovableViewDelegate?

    // MARK: - Setup

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureHandler(_:)))
        panGestureRecognizer?.delegate = self
        panGestureRecognizer?.isEnabled = gesturesEnabled
        addGestureRecognizer(panGestureRecognizer!)

        pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinchGestureHandler(_:)))
        pinchGestureRecognizer?.delegate = self
        pinchGestureRecognizer?.isEnabled = gesturesEnabled
        addGestureRecognizer(pinchGestureRecognizer!)

        rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(rotationGestureHandler(_:)))
        rotationGestureRecognizer?.delegate = self
        rotationGestureRecognizer?.isEnabled = gesturesEnabled
        addGestureRecognizer(rotationGestureRecognizer!)

        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(doubleTapGestureHandler(_:)))
        doubleTapGestureRecognizer?.numberOfTapsRequired = 2
        doubleTapGestureRecognizer?.delegate = self
        doubleTapGestureRecognizer?.isEnabled = gesturesEnabled
        addGestureRecognizer(doubleTapGestureRecognizer!)
    }

    func resetTransform() {
        transform = .identity
        currentScale = 1
    }

    func setTransform(_ newTransform: CGAffineTransform) {
        if isScaleEnabled {
            transform = newTransform
        } else {
            transform = newTransform.scaledBy(x: 1 / newTransform.a, y: 1 / newTransform.a)
        }

        currentScale = newTransform.a
    }

    @objc private func panGestureHandler(_ recognizer: UIPanGestureRecognizer) {
        handleRecognizer(recognizer)

        let translation = recognizer.translation(in: self)
        transform = transform.translatedBy(x: translation.x, y: translation.y)
        recognizer.setTranslation(.zero, in: self)
    }

    @objc private func pinchGestureHandler(_ recognizer: UIPinchGestureRecognizer) {
        handleRecognizer(recognizer)

        currentScale = (currentScale * recognizer.scale).clamped(to: scaleRange)

        if isScaleEnabled {
            transform = transform.scaledBy(x: recognizer.scale, y: recognizer.scale)
        }

        recognizer.scale = 1
    }

    @objc private func rotationGestureHandler(_ recognizer: UIRotationGestureRecognizer) {
        guard isRotationEnabled else {
            return
        }

        handleRecognizer(recognizer)
        transform = transform.rotated(by: recognizer.rotation)
        recognizer.rotation = 0
    }

    @objc private func doubleTapGestureHandler(_ recognizer: UITapGestureRecognizer) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            generator.impactOccurred()
        }

        UIView.animate(withDuration: 0.5,
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.1,
                       options: [],
                       animations: {
            self.transform = .identity
        }, completion: nil)

        currentScale = 1
        delegate?.movableView(self, finishedTransformingTo: .identity)
    }

    private func handleRecognizer(_ recognizer: UIGestureRecognizer) {
        guard gesturesEnabled else { return }

        switch recognizer.state {
        case .began:
            activeGestureRecognizerCount += 1
        case .ended, .cancelled, .failed:
            activeGestureRecognizerCount -= 1

            if activeGestureRecognizerCount == 0 {
                if isScaleEnabled {
                    delegate?.movableView(self, finishedTransformingTo: transform)
                } else {
                    delegate?.movableView(self, finishedTransformingTo: transform.scaledBy(x: currentScale, y: currentScale))
                }
            }
        default: break
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard gesturesEnabled else { return false }

        if activeGestureRecognizerCount > 0 {
            return bounds.contains(point)
        }

        if let visibleSubview = subviews.first(where: { $0.alpha == 1}) {
            let imageRect = CGSize.aspectFit(aspectRatio: visibleSubview.bounds.size, boundingSize: bounds.size)
            return imageRect.contains(point)
        }

        return false
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard gesturesEnabled else { return nil }
        
        if activeGestureRecognizerCount > 0 {
            return bounds.contains(point) ? self : nil
        }

        if let visibleSubview = subviews.first(where: { $0.alpha == 1 }) {
            let imageRect = CGSize.aspectFit(aspectRatio: visibleSubview.bounds.size, boundingSize: bounds.size)
            return imageRect.contains(point) ? self : nil
        }

        return nil
    }
}

extension MovableView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
