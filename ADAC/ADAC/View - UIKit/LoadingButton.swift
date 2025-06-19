// Licensed under the Any Distance Source-Available License
//
//  LoadingButton.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/11/23.
//

import UIKit
import PureLayout

final class LoadingButton: ScalingPressButton {
    private var activityIndicator: UIActivityIndicatorView?

    var isLoading: Bool = false {
        didSet {
            updateLoadingState()
        }
    }

    private var image: UIImage?

    private func updateLoadingState() {
        if isLoading && activityIndicator == nil {
            activityIndicator = UIActivityIndicatorView()
            activityIndicator?.style = .medium
            activityIndicator?.color = .white
            activityIndicator?.alpha = 0.0
            activityIndicator?.transform = CGAffineTransform(scaleX: 0.0, y: 0.0)
            addSubview(activityIndicator!)
            activityIndicator?.startAnimating()
            activityIndicator?.autoPinEdgesToSuperviewEdges()

            self.image = image(for: .normal)
            UIView.transition(with: self,
                              duration: 0.2,
                              options: [.transitionCrossDissolve]) {
                self.setTitleColor(.clear, for: .normal)
                self.setImage(nil, for: .normal)
            }

            UIView.animate(withDuration: 0.4,
                           delay: 0.1,
                           usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 0.3) {
                self.activityIndicator?.alpha = 1.0
                self.activityIndicator?.transform = .identity
                self.backgroundColor = self.backgroundColor?.withAlphaComponent(0.12)
                self.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
            }

            isUserInteractionEnabled = false
        } else {
            UIView.animate(withDuration: 0.2, delay: 0.0, options: [.curveEaseOut]) {
                self.activityIndicator?.alpha = 0.0
                self.activityIndicator?.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                self.backgroundColor = self.backgroundColor?.withAlphaComponent(1)
                self.transform = .identity
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIView.transition(with: self, duration: 0.2, options: [.transitionCrossDissolve]) {
                    self.setTitleColor(.black, for: .normal)
                    self.setImage(self.image, for: .normal)
                } completion: { finished in
                    guard finished else {
                        return
                    }

                    self.activityIndicator?.removeFromSuperview()
                    self.activityIndicator = nil
                }
            }

            isUserInteractionEnabled = true
        }
    }
}
