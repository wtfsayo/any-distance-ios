// Licensed under the Any Distance Source-Available License
//
//  FlickeringImageView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/7/21.
//

import UIKit

final class FlickeringImageView: UIImageView {

    // MARK: - Variables

    private var isLowered: Bool = false
    private var flickerCount: Int = 0

    // MARK: - Constants

    private let NUM_FLICKERS: Int = 8

    // MARK: - Setup

    override func awakeFromNib() {
        super.awakeFromNib()
        prepareForAnimation()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        startAnimation()
    }

    func prepareForAnimation() {
        alpha = 0.0
    }

    // MARK: - OnboardingContentView Methods

    func startAnimation() {
//        startFloating()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
//            self?.flicker()
//        }

        self.startGlowing()
        self.continueFlickering()
    }

    func startFloating() {
        let yTranslation: CGFloat = isLowered ? -7 : 7
        isLowered = !isLowered
        UIView.animate(withDuration: 2.0, delay: 0.0, options: [.curveEaseInOut, .beginFromCurrentState], animations: {
            self.transform = CGAffineTransform(translationX: 0.0, y: yTranslation)
        }, completion: { [weak self] (finished) in
            if finished {
                self?.startFloating()
            }
        })
    }

    func flicker() {
        let newAlpha: CGFloat = (alpha < 1.0) ? 1.0 : 0.2
        alpha = newAlpha
        flickerCount += 1

        if alpha == 1.0 && flickerCount >= NUM_FLICKERS {
            continueFlickering()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.startGlowing()
            }
        } else {
            let delay = TimeInterval.random(in: 0.05...0.07) - (0.03 * TimeInterval(flickerCount) / TimeInterval(NUM_FLICKERS))
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.flicker()
            }
        }
    }

    func continueFlickering() {
        let newAlpha: CGFloat = (alpha < 1.0) ? 1.0 : 0.2
        alpha = newAlpha

        var delay: TimeInterval {
            if alpha < 1.0 {
                return TimeInterval.random(in: 0.01...0.03)
            }

            return TimeInterval.random(in: 0.03...0.4)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.continueFlickering()
        }
    }

    func startGlowing(delay: TimeInterval = 0.0) {
        let duration = TimeInterval.random(in: 0.4...0.8)
        let newAlpha: CGFloat = (alpha < 1.0) ? 1.0 : 0.8
        UIView.animate(withDuration: duration, delay: delay, options: [.curveEaseInOut, .beginFromCurrentState], animations: {
            self.alpha = newAlpha
        }) { [weak self] (finished) in
            if finished {
                self?.startGlowing()
            }
        }
    }

    func stopAnimation() {
        //
    }
}
