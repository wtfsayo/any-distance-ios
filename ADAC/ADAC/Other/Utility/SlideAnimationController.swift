// Licensed under the Any Distance Source-Available License
//
//  SlideAnimationController.swift
//  Perfect Pitch
//
//  Created by Daniel Kuntz on 4/1/16.
//  Copyright © 2016 Coda Labs. All rights reserved.
//

import UIKit

final class SlidePresentAnimationController: NSObject, UIViewControllerAnimatedTransitioning {

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.6
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let toViewController: UIViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
        let fromViewController: UIViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!
        
        toViewController.view.frame = CGRect(x: toViewController.view.frame.width, y: 0, width: toViewController.view.frame.width, height: toViewController.view.frame.height)
        
        transitionContext.containerView.addSubview(toViewController.view!)
        
        let darkView = UIView(frame: fromViewController.view.bounds)
        darkView.layer.backgroundColor = UIColor(white: 0.0, alpha: 1.0).cgColor
        darkView.alpha = 0.0
        fromViewController.view.addSubview(darkView)
        
        UIView.animate(withDuration: self.transitionDuration(using: .none),
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.6,
                       options: [.allowUserInteraction, .beginFromCurrentState],
                       animations: {
            toViewController.view.frame.origin.x -= toViewController.view.frame.width
            fromViewController.view.frame.origin.x -= toViewController.view.frame.width
            }, completion: { finished in
                if finished {
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                    darkView.removeFromSuperview()
                }
        })
        
    }
}
