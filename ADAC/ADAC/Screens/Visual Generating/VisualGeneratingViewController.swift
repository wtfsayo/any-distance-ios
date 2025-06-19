// Licensed under the Any Distance Source-Available License
//
//  ActivityIndicatorViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/31/20.
//

import UIKit
import MessageUI
import PureLayout
import SwiftUI

protocol VisualGeneratingActor: UIViewController {
    func cancelTapped()
}

/// Protocol for a ViewController that can show a blurry full screen overlay with a progress indicator
/// and custom loading text
protocol VisualGenerating: VisualGeneratingActor {
    var containerView: UIView { get set }
    var darkView: UIVisualEffectView? { get set }
    var generatingHost: UIHostingController<GeneratingVisualsView>? { get set }
    var generatingModel: GeneratingVisualsViewModel { get set }

    func setupVisualGenerating()
    func adjustVisualGeneratingViewPlacement()
    func setProgress(_ progress: Float, animated: Bool)
    func showActivityIndicator()
    func hideActivityIndicator()
    func showDarkView(withLabel text: String)
    func hideDarkView()
    func cancelTapped()
}

extension VisualGenerating {
    func setupVisualGenerating() {
        darkView = UIVisualEffectView(frame: UIScreen.main.bounds)
        darkView?.effect = nil
        darkView?.isUserInteractionEnabled = false

        let viewToPin = (navigationController == nil ? view : navigationController?.view)!
        viewToPin.addSubview(darkView!)
        darkView?.autoPinEdgesToSuperviewEdges()

        containerView.backgroundColor = .clear
        containerView.alpha = 0
        viewToPin.addSubview(containerView)
        containerView.autoPinEdgesToSuperviewEdges()

        generatingModel.controller = self
        let loadingView = GeneratingVisualsView(model: generatingModel)
        generatingHost = UIHostingController(rootView: loadingView)
        containerView.addSubview(generatingHost!.view)
        generatingHost?.view.backgroundColor = .clear
        generatingHost?.view.autoPinEdgesToSuperviewEdges()
    }

    func adjustVisualGeneratingViewPlacement() {
        if let darkView = darkView {
            view.bringSubviewToFront(darkView)
        }
        view.bringSubviewToFront(containerView)
    }

    func setProgress(_ progress: Float, animated: Bool) {
        generatingModel.setProgress(progress, animated: animated)
    }

    func showActivityIndicator() {
        let viewToTransition = navigationController == nil ? view : navigationController?.view
        UIView.transition(with: viewToTransition!, duration: 0.3, options: [.transitionCrossDissolve], animations: {
            self.darkView?.effect = UIBlurEffect(style: .dark)
            self.darkView?.isUserInteractionEnabled = true
            self.containerView.alpha = 1.0
            self.tabBarController?.tabBar.alpha = 0.0
        }, completion: nil)
    }

    func hideActivityIndicator() {
        let viewToTransition = navigationController == nil ? view : navigationController?.view
        UIView.transition(with: viewToTransition!, duration: 0.3, options: [.transitionCrossDissolve], animations: {
            self.darkView?.effect = nil
            self.darkView?.isUserInteractionEnabled = false
            self.containerView.alpha = 0.0
            self.tabBarController?.tabBar.alpha = 1.0
        }, completion: nil)
    }

    func showDarkView(withLabel text: String = "") {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        self.darkView?.contentView.addSubview(label)
        label.autoCenterInSuperview()

        let viewToTransition = navigationController == nil ? view : navigationController?.view
        UIView.transition(with: viewToTransition!, duration: 0.3, options: [.transitionCrossDissolve], animations: {
            self.darkView?.effect = UIBlurEffect(style: .dark)
            self.darkView?.alpha = 1.0
        }, completion: nil)
    }

    func hideDarkView() {
        self.darkView?.contentView.subviews.first(where: { $0 is UILabel })?.removeFromSuperview()

        let viewToTransition = navigationController == nil ? view : navigationController?.view
        UIView.transition(with: viewToTransition!, duration: 0.3, options: [.transitionCrossDissolve], animations: {
            self.darkView?.effect = nil
            self.darkView?.alpha = 0.0
        }, completion: nil)
    }
}

/// A UIViewController that conforms to VisualGenerating. Subclass this to get VisualGenerating
/// functionality in custom view controllers.
class VisualGeneratingViewController: UIViewController, VisualGenerating {

    // MARK: - Variables

    internal var containerView = UIView()
    internal var darkView: UIVisualEffectView?
    internal var generatingHost: UIHostingController<GeneratingVisualsView>?
    var generatingModel = GeneratingVisualsViewModel()

    // MARK: - Setup Views

    override func viewDidLoad() {
        super.viewDidLoad()
        setupVisualGenerating()
    }
    
    deinit {
        darkView?.removeFromSuperview()
        containerView.removeFromSuperview()
        generatingHost = nil
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustVisualGeneratingViewPlacement()
    }

    func cancelTapped() {
        hideActivityIndicator()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

/// A UITableViewController that conforms to VisualGenerating. Subclass this to get VisualGenerating
/// functionality in custom view controllers.
class VisualGeneratingTableViewController: UITableViewController, VisualGenerating {

    // MARK: - Variables

    internal var containerView = UIView()
    internal var darkView: UIVisualEffectView?
    internal var generatingHost: UIHostingController<GeneratingVisualsView>?
    var generatingModel = GeneratingVisualsViewModel()

    // MARK: - Setup Views

    override func viewDidLoad() {
        super.viewDidLoad()
        setupVisualGenerating()
    }
    
    deinit {
        containerView.removeFromSuperview()
        darkView?.removeFromSuperview()
        generatingHost = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustVisualGeneratingViewPlacement()
    }

    func cancelTapped() {
        hideActivityIndicator()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

