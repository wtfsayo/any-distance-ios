// Licensed under the Any Distance Source-Available License
//
//  SignInViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/14/20.
//

import UIKit
import AuthenticationServices
import PureLayout
import Sentry
import Mixpanel

protocol SignInViewControllerDelegate: AnyObject {
    func authorizationController(didCompleteWithAuthorization authorization: ASAuthorization)
}

enum SignInViewControllerFunction {
    case signIn
    case join
}

/// View controller that displays a Sign In With Apple button and custom text depending on "function"
/// (.join or .signIn)
final class SignInViewController: UIViewController {

    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var topLabel: UILabel!

    // MARK: - Variables

    weak var delegate: SignInViewControllerDelegate?
    var signInWithAppleButton: ASAuthorizationAppleIDButton!
    let screenName = "Sign In"
    var function: SignInViewControllerFunction = .join

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        Analytics.logEvent(screenName, screenName, .screenViewed)
        setup()
    }

    func setup() {
        signInWithAppleButton = ASAuthorizationAppleIDButton(authorizationButtonType: .continue,
                                                             authorizationButtonStyle: .white)
        signInWithAppleButton.addTarget(self, action: #selector(signInWithAppleTapped), for: .touchUpInside)
        stackView.insertArrangedSubview(signInWithAppleButton, at: 4)
        signInWithAppleButton.autoSetDimension(.height, toSize: 50)
        signInWithAppleButton.autoMatch(.width, to: .width, of: view, withMultiplier: 0.85)
        signInWithAppleButton.cornerRadius = 8
        switch function {
        case .signIn:
            topLabel.text = "Sign In to\nAny Distance"
        case .join:
            topLabel.text = "Join Any Distance"
        }
    }

    @objc func signInWithAppleTapped() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()

        Analytics.logEvent("Sign In With Apple", screenName, .buttonTap)
    }

    @IBAction func closeTapped(_ sender: Any) {
        Analytics.logEvent("Close", screenName, .buttonTap)
        dismiss(animated: true, completion: nil)
    }

    @IBAction func privacyCommitmentTapped(_ sender: Any) {
        Analytics.logEvent("Privacy Commitment", screenName, .buttonTap)
        openUrl(withString: Links.privacyCommitment.absoluteString)
    }

    @IBAction func termsTapped(_ sender: Any) {
        Analytics.logEvent("Terms", screenName, .buttonTap)
        openUrl(withString: Links.termsAndConditions.absoluteString)
    }
}

extension SignInViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        dismiss(animated: true) {
            self.delegate?.authorizationController(didCompleteWithAuthorization: authorization)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Analytics.logEvent("Error - Sign In With Apple", screenName, .otherEvent, withParameters: ["error" : error.localizedDescription])
    }
}

extension SignInViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}
