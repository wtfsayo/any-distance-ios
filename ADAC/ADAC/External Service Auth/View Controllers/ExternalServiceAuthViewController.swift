// Licensed under the Any Distance Source-Available License
//
//  ExternalServiceAuthViewController.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/13/22.
//

import UIKit
import SwiftUI
import Combine
import Sentry

protocol ExternalServiceAuthViewControllerDelegate: NSObjectProtocol {
    func externalServiceAuthViewController(_ viewController: ExternalServiceAuthViewController,
                                           finishedWith authorization: ExternalServiceAuthorization)
}

class ExternalServiceAuthViewController: SwiftUIViewController<ExternalServiceAuthView> {
    
    weak var delegate: ExternalServiceAuthViewControllerDelegate?
    
    // MARK: - Private
    
    private let viewModel: ExternalServiceAuthViewModel
    private var disposables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init(with externalService: ExternalService) {
        viewModel = ExternalServiceAuthViewModel(with: externalService)
        super.init()
    }
    
    override func createSwiftUIView() {
        swiftUIView = ExternalServiceAuthView(viewModel: viewModel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.adGray1
        
        bindViewModel()
    }
    
}

// MARK: - Private

extension ExternalServiceAuthViewController {
    
    private func showDisconnectedToast() {
        let parentView = presentingViewController?.view
        // TODO: Get rid of notification center for this
        NotificationCenter.default.post(.externalServicesConnectionStateChanged)
        dismiss(animated: true) {
            let tint = UIColor.adGreen
            let toastModel = ToastView.Model(title: "Disconnected from \(self.viewModel.externalService.displayName)",
                                             description: "You can always reconnect in Settings.",
                                             image: UIImage(systemName: "checkmark.circle.fill"),
                                             autohide: true)
            let toast = ToastView(model: toastModel,
                                  imageTint: tint,
                                  borderTint: tint)
            parentView?.present(toast: toast,
                                insets: .init(top: 0, left: 0, bottom: 50.0, right: 0))
            
        }
    }
    
    private func bindViewModel() {
        viewModel.onCancel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                self.dismiss(animated: true)
            }
            .store(in: &disposables)
        
        viewModel.onDisconnect
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self = self else { return }

                Analytics.logEvent("Disconnected \(self.viewModel.externalService.displayName)", "ExternalServiceAuthViewController", .withError)

                if let error = error as? Error {
                    SentrySDK.capture(error: error)
                }
                
                self.showDisconnectedToast()
            } receiveValue: { [weak self] in
                guard let self = self else { return }
                
                Analytics.logEvent("Disconnected \(self.viewModel.externalService.displayName)", "ExternalServiceAuthViewController", .otherEvent)

                self.showDisconnectedToast()
            }
            .store(in: &disposables)

        viewModel.onConnect
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }

                if iAPManager.shared.hasSuperDistanceFeatures {
                    self.viewModel.presentAuth(on: self)
                } else {
                    let vc = UIHostingController(rootView: SuperDistanceView())
                    vc.modalPresentationStyle = .overFullScreen
                    present(vc, animated: true)
                }
            }
            .store(in: &disposables)
        
        viewModel.onPresentURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self = self else { return }
                self.openUrl(withString: url.string)
            }
            .store(in: &disposables)
                
        viewModel.authorization
            .sink { error in
                print("Authorization error: \(error)")
            } receiveValue: { [weak self] authorization in
                guard let self = self else { return }
                let keychain = KeychainStore.shared
                do {
                    try keychain.save(authorization: authorization)
                } catch {
                    SentrySDK.capture(error: error)
                }
                
                // TODO: Get rid of this
                NotificationCenter.default.post(.connectionStateChanged)
                NotificationCenter.default.post(.externalServicesConnectionStateChanged)
                
                Analytics.logEvent("Connected \(authorization.service.displayName)", "ExternalServiceAuthViewController", .otherEvent)
                
                self.dismiss(animated: true) {
                    DispatchQueue.main.async {
                        let toastModel = ToastView.Model(title: "\(authorization.service.displayName) successfully connected",
                                                         description: "Your \(authorization.service.displayName) activities will now start syncing.",
                                                         image: UIImage(systemName: "checkmark.circle.fill"),
                                                         autohide: true)
                        let tint = UIColor.adGreen
                        let toast = ToastView(model: toastModel, imageTint: tint, borderTint: tint)
                        let topVC =  UIApplication.shared.topViewController
                        var bottomInset = 0.0
                        if let tabBarVC = topVC as? UITabBarController {
                            if let designVC = tabBarVC.selectedViewController?.topmostViewController as? DesignViewController {
                                bottomInset = designVC.editorControls.frame.height
                            } else {
                                bottomInset = tabBarVC.view.safeAreaInsets.bottom + 15.0
                            }
                        }
                        topVC?.view.present(toast: toast,
                                            insets: .init(top: 0, left: 0, bottom: bottomInset, right: 0))

                    }
                }

                self.delegate?.externalServiceAuthViewController(self, finishedWith: authorization)
            }
            .store(in: &disposables)
    }
    
}

