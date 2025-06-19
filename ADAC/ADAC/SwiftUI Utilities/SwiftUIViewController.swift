// Licensed under the Any Distance Source-Available License
//
//  SwiftUIViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/14/21.
//

import UIKit
import SwiftUI

class SwiftUIViewController<T: View>: UIViewController, ObservableObject {

    // MARK: - Variables

    var activityIndicator = UIActivityIndicatorView(style: .large)
    var darkView: UIVisualEffectView!

    var container: UIView!
    var swiftUIView: T!
    lazy var hostingController: UIHostingController = UIHostingController(rootView: swiftUIView)

    // MARK: - Constructor

    func createSwiftUIView() {
        fatalError("Must override createSwiftUIView() and initialize instance property swiftUIView.")
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        addContainer()
        addActivityIndicator()
    }

    private func addContainer() {
        createSwiftUIView()

        container = UIView()
        container.backgroundColor = .clear
        view.addSubview(container)
        container.autoPinEdgesToSuperviewEdges()

        addChild(hostingController)
        container.addSubview(hostingController.view)
        hostingController.view.backgroundColor = .clear
        hostingController.view.autoPinEdgesToSuperviewEdges()
        hostingController.didMove(toParent: self)
    }

    private func addActivityIndicator() {
        darkView = UIVisualEffectView(frame: UIScreen.main.bounds)
        darkView.effect = nil
        darkView.isUserInteractionEnabled = false

        let viewToPin = (navigationController == nil ? view : navigationController?.view)!
        viewToPin.addSubview(darkView)
        darkView.autoPinEdgesToSuperviewEdges()

        viewToPin.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.autoAlignAxis(toSuperviewAxis: .vertical)
        activityIndicator.autoAlignAxis(.horizontal, toSameAxisOf: viewToPin, withOffset: 0)

        activityIndicator.isUserInteractionEnabled = false
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        activityIndicator.alpha = 0
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        hostingController.view.frame = container.bounds
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.bringSubviewToFront(darkView)
        view.bringSubviewToFront(activityIndicator)
    }

    // MARK: - Activity Indicator

    func showActivityIndicator() {
        let viewToTransition = navigationController == nil ? view : navigationController?.view
        UIView.transition(with: viewToTransition!, duration: 0.3, options: [.transitionCrossDissolve], animations: {
            self.darkView.effect = UIBlurEffect(style: .dark)
            self.darkView.isUserInteractionEnabled = true
            self.darkView.alpha = 1
            self.activityIndicator.alpha = 1
        }, completion: nil)
    }

    func hideActivityIndicator() {
        let viewToTransition = navigationController == nil ? view : navigationController?.view
        UIView.transition(with: viewToTransition!, duration: 0.3, options: [.transitionCrossDissolve], animations: {
            self.darkView.effect = nil
            self.darkView.isUserInteractionEnabled = false
            self.darkView.alpha = 0
            self.activityIndicator.alpha = 0
        }, completion: nil)
    }
}
