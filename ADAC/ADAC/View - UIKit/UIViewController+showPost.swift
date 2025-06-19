// Licensed under the Any Distance Source-Available License
//
//  UIViewController+showPost.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/9/23.
//

import UIKit
import SwiftUI
import HealthKit

extension UIViewController {
    func showPostDraft(for activity: Activity) {
        Task(priority: .userInitiated) {
            var activity = activity
            if activity is CachedActivity {
                do {
                    let hkID = activity.id.replacingOccurrences(of: "health_kit_", with: "")
                    activity = try await HealthKitActivitiesStore.shared.hkWorkout(withId: hkID)
                } catch {
                    return
                }
            }

            guard let state = try? await activity.activityRecorderState() else {
                return
            }

            let recorder = ActivityRecorder(savedState: state, workout: activity)
            let model = RecordingViewModel(recorder: recorder)
            model.finishedRouteType = .threeD
            let rootView = RecordingView(model: model)
            let controller = UIHostingController(rootView: rootView)
            controller.modalPresentationStyle = .fullScreen
            controller.view.backgroundColor = .black

            DispatchQueue.main.async {
                self.present(controller, animated: true)
            }
        }
    }

    func showPost(_ post: Post, fromFrame: CGRect? = nil) {
        let recorder = ActivityRecorder(post: post)
        let model = RecordingViewModel(recorder: recorder,
                                       livePost: post)
        let rootView = RecordingView(model: model)
        let controller = UIHostingController(rootView: rootView)
        controller.view.backgroundColor = .black
        if fromFrame != nil {
            controller.modalPresentationStyle = .custom
            controller.transitioningDelegate = self
            PostPresentation.fromFrame = fromFrame
        } else {
            controller.modalPresentationStyle = .overFullScreen
        }

        DispatchQueue.main.async {
            self.present(controller, animated: true)
        }
    }
}

fileprivate class PostPresentation {
    static var fromFrame: CGRect? = nil
}

extension UIViewController: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController,
                                    presenting: UIViewController,
                                    source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
}

extension UIViewController: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        if transitionContext?.viewController(forKey: .to) is UIHostingController<RecordingView> {
            return 0.45
        } else {
            return 0.35
        }
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        // Retrieve the view controllers participating in the current transition from the context.
        let fromViewController = transitionContext.viewController(forKey: .from)!
        let toViewController = transitionContext.viewController(forKey: .to)!

        if toViewController is UIHostingController<RecordingView> {
            var snapshot: UIView?
            if let fromFrame = PostPresentation.fromFrame {
                snapshot = UIApplication.shared.topWindow?.resizableSnapshotView(from: fromFrame,
                                                                                 afterScreenUpdates: false,
                                                                                 withCapInsets: .zero)
                snapshot?.frame = fromFrame
                snapshot?.layer.cornerRadius = 24.0
                snapshot?.layer.cornerCurve = .continuous
                snapshot?.layer.masksToBounds = true


                toViewController.view.frame = CGRect(x: 0.0,
                                                     y: fromFrame.origin.y,
                                                     width: UIScreen.main.bounds.width,
                                                     height: fromFrame.height)
                toViewController.view.transform = CGAffineTransform(scaleX: fromFrame.width / toViewController.view.frame.width,
                                                                    y: 1.0)
            } else {
                toViewController.view.frame = UIScreen.main.bounds
                toViewController.view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }

            toViewController.view.layer.cornerRadius = 22.0
            toViewController.view.layer.cornerCurve = .continuous
            toViewController.view.layer.masksToBounds = true
            transitionContext.containerView.addSubview(toViewController.view)

            if let snapshot = snapshot {
                transitionContext.containerView.addSubview(snapshot)
            }

            let animator = UIViewPropertyAnimator(duration: transitionDuration(using: transitionContext),
                                                  controlPoint1: CGPoint(x: 0.4, y: 0.06),
                                                  controlPoint2: CGPoint(x: 0.09, y: 1.02)) {
                toViewController.view.transform = .identity
                toViewController.view.alpha = 1.0
                toViewController.view.frame = UIScreen.main.bounds
                toViewController.view.transform = .identity
                snapshot?.frame = UIScreen.main.bounds
                snapshot?.alpha = 0.0
            }

            animator.addCompletion { _ in
                snapshot?.removeFromSuperview()
                transitionContext.completeTransition(true)
            }

            animator.startAnimation()
        } else {
            fromViewController.view.layer.cornerRadius = 22.0
            fromViewController.view.layer.cornerCurve = .continuous
            fromViewController.view.layer.masksToBounds = true
            fromViewController.view.frame = UIScreen.main.bounds

            var snapshot: UIView?
            let coordinateSpace = UIScreen.main.coordinateSpace
            var fromFrame = PostPresentation.fromFrame
            var convertedFromFrame = PostPresentation.fromFrame == nil ? nil : toViewController.view.convert(PostPresentation.fromFrame!,
                                                                                                             from: coordinateSpace)
            if let fromFrame = convertedFromFrame {
                snapshot = toViewController.view.resizableSnapshotView(from: fromFrame,
                                                                       afterScreenUpdates: false,
                                                                       withCapInsets: .zero)

                if let snapshot = snapshot {
                    snapshot.frame = UIScreen.main.bounds
                    snapshot.layer.cornerRadius = 24.0
                    snapshot.layer.cornerCurve = .continuous
                    snapshot.layer.masksToBounds = true
                    snapshot.alpha = 0.0
                    transitionContext.containerView.addSubview(snapshot)
                }
            }

            let animator = UIViewPropertyAnimator(duration: transitionDuration(using: transitionContext),
                                                  controlPoint1: CGPoint(x: 0.36, y: 0.12),
                                                  controlPoint2: CGPoint(x: 0.21, y: 0.99)) {
                if let fromFrame = fromFrame {
                    var transform = CGAffineTransform(scaleX: fromFrame.width / UIScreen.main.bounds.width,
                                                      y: fromFrame.height / UIScreen.main.bounds.height)
                    transform = transform.concatenating(CGAffineTransform(translationX: fromFrame.midX - UIScreen.main.bounds.midX,
                                                                          y: -1 * (UIScreen.main.bounds.midY - fromFrame.midY)))
                    fromViewController.view.transform = transform
                }
                fromViewController.view.alpha = 0.0
                snapshot?.frame = fromFrame ?? UIScreen.main.bounds
                snapshot?.alpha = 1.0
            }

            animator.addCompletion { _ in
                transitionContext.completeTransition(true)
            }

            animator.startAnimation()
        }
    }
}
