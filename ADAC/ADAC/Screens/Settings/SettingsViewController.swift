// Licensed under the Any Distance Source-Available License
//
//  SettingsViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/13/21.
//

import UIKit
import SwiftUI
import Combine
import MessageUI
import Sentry
import OneSignal

final class SettingsViewController: SwiftUIViewController<Settings> {

    // MARK: - Constants

    let screenName: String = "Settings"

    // MARK: - Variables

    var presentedInSheet = false
    var showCloseButton = false
    private lazy var model = SettingsViewModel(controller: self)
    private var subscribers: Set<AnyCancellable> = []

    // MARK: - Setup

    override func createSwiftUIView() {
        self.swiftUIView = Settings(model: model,
                                    presentedInSheet: presentedInSheet,
                                    showCloseButton: showCloseButton)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    private func setup() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateExternalServicesConnectionState),
                                               name: Notification.externalServicesConnectionStateChanged.name,
                                               object: nil)

        model.$activityShareReminderNotificationsOn
            .dropFirst()
            .sink { [weak self] value in
                self?.setActivityShareNotificationsOnAction(value)
            }
            .store(in: &subscribers)
        
        model.$featureNotificationsOn
            .dropFirst()
            .sink { [weak self] value in
                self?.setFeatureNotificationsOnAction(value)
            }
            .store(in: &subscribers)
        
        model.$collectiblesNotificationsOn
            .dropFirst()
            .sink { [weak self] value in
                self?.setCollectibleNotificationsOnAction(value)
            }
            .store(in: &subscribers)
        
        updateExternalServicesConnectionState()
    }

    @objc private func updateExternalServicesConnectionState() {
        let keychainStore = KeychainStore.shared
        if let wahooAuthorization = keychainStore.authorization(for: .wahoo) {
            model.wahooConnectionState = wahooAuthorization.expired ? .revoked : .connected
        } else {
            model.wahooConnectionState = .disconnected
        }
        
        if let garminAuthorization = keychainStore.authorization(for: .garmin) {
            model.garminConnectionState = garminAuthorization.expired ? .revoked : .connected
        } else {
            model.garminConnectionState = .disconnected
        }
    }

    private func showFailureAlert() {
        let alert = UIAlertController.defaultWith(title: "Oops", message: "Something went wrong. Please try again later.")
        present(alert, animated: true, completion: nil)
    }
    
    private func showNoPurchaseFoundAlert() {
        let alert = UIAlertController.defaultWith(title: "Oops", message: "No previous purchases were found. If this is a mistake contact support at support@anydistance.club")
        present(alert, animated: true, completion: nil)
    }

    // MARK: - Actions

    // MARK: - Header

    func closeAction() {
        Analytics.logEvent("Close", screenName, .buttonTap, withParameters: nil)
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Super Distance

    func cancelPlanAction() {
        Analytics.logEvent("Cancel Plan", screenName, .buttonTap, withParameters: nil)
        openUrl(withString: Links.downgradeSurvey.absoluteString)
    }

    func billingSupportAction() {
        Analytics.logEvent("Billing Support", screenName, .buttonTap, withParameters: nil)
        sendEmail(to: "billing@anydistance.club")
    }

    func renewsAction() {
        Analytics.logEvent("Renews", screenName, .buttonTap, withParameters: nil)
        openUrl(withString: Links.manageSubscription.absoluteString)
    }

    func seeFeaturesAction() {
        Analytics.logEvent("See Features", screenName, .buttonTap, withParameters: nil)
        let vc = UIHostingController(rootView: SuperDistanceView())
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true)
    }

    func joinBetaAction() {
        Analytics.logEvent("Join Beta", screenName, .buttonTap)
        openUrl(withString: Links.joinBeta.absoluteString)
    }

    func restoreAction() {
        Analytics.logEvent("Restore Purchase", screenName, .buttonTap, withParameters: nil)
        showActivityIndicator()
        iAPManager.shared.restorePurchases { [weak self] state in
            self?.hideActivityIndicator()
            switch state {
            case .failed:
                self?.showFailureAlert()
            case .restoredWithoutSubscription:
                self?.showNoPurchaseFoundAlert()
            default: break
            }
        }
    }


    // MARK: - Display

    func setDisplayAction(_ newValue: DistanceUnit) {
        ADUser.current.distanceUnit = newValue
        UserManager.shared.updateCurrentUser()
        NotificationCenter.default.post(.goalTypeChanged)
    }

    func setStepCountOnAction(_ newValue: Bool) {
        NSUbiquitousKeyValueStore.default.shouldShowStepCount = newValue
        NotificationCenter.default.post(.goalTypeChanged)
    }

    func setShowBrandingOnAction(_ newValue: Bool) {
        NSUbiquitousKeyValueStore.default.shouldShowAnyDistanceBranding = newValue
    }

    func setShowCollaborationsOnAction(_ newValue: Bool) {
        Analytics.logEvent(newValue ? "Opt In Collaboration Collectibles" : "Opt Out Collaboration Collectibles",
                           screenName, .buttonTap)
        NSUbiquitousKeyValueStore.default.shouldShowCollaborationCollectibles = newValue
        NotificationCenter.default.post(.goalTypeChanged)
    }

    // MARK: - App Icon

    func setAppIcon(_ idx: Int) {
        if let icon = AppIcon(rawValue: idx) {
            UIApplication.shared.setAlternateIconName(icon.alternateIconName, completionHandler: nil)
        }
    }

    // MARK: - Notifications

    func dailyRemindersAction() {
        let vc = PushNotificationsViewController()
        vc.isModalInPresentation = true
        self.present(vc, animated: true)
    }

    func setActivityShareNotificationsOnAction(_ newValue: Bool) {
        NSUbiquitousKeyValueStore.default.activityShareReminderNotificationsOn = newValue

        if NSUbiquitousKeyValueStore.default.activityShareReminderNotificationsOn {
            OneSignal.promptForPushNotifications(userResponse: { [weak self] accepted in
                if accepted {
                    ActivitiesData.shared.startObservingNewActivities(for: .appleHealth)
                } else {
                    self?.model.activityShareReminderNotificationsOn = false
                    NSUbiquitousKeyValueStore.default.activityShareReminderNotificationsOn = false
                    let alert = UIAlertController(title: "Open Settings to grant notifications permissions to Any Distance.",
                                                  message: nil,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
                    alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { (_) in
                        let url = URL(string: UIApplication.openSettingsURLString)!
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }))
                    self?.present(alert, animated: true, completion: nil)
                }
            }, fallbackToSettings: false)
        }
    }
    
    func setFeatureNotificationsOnAction(_ newValue: Bool) {
        NSUbiquitousKeyValueStore.default.featureUpdateNotificationsOn = newValue

        if NSUbiquitousKeyValueStore.default.featureUpdateNotificationsOn {
            OneSignal.promptForPushNotifications(userResponse: { [weak self] accepted in
                if !accepted {
                    self?.model.featureNotificationsOn = false
                }
                NSUbiquitousKeyValueStore.default.featureUpdateNotificationsOn = accepted
            }, fallbackToSettings: false)
        }

    }
    
    func setCollectibleNotificationsOnAction(_ newValue: Bool) {
        NSUbiquitousKeyValueStore.default.collectiblesNotificationsOn = newValue
        
        if NSUbiquitousKeyValueStore.default.collectiblesNotificationsOn {
            OneSignal.promptForPushNotifications(userResponse: { [weak self] accepted in
                if !accepted {
                    self?.model.collectiblesNotificationsOn = false
                }
                NSUbiquitousKeyValueStore.default.collectiblesNotificationsOn = accepted
            }, fallbackToSettings: false)
        }
    }


    // MARK: - Sync Connect

    func appleHealthAction() {
        presentExternalServiceAuth(.appleHealth)
    }

    func learnMoreSyncingAction() {
        openUrl(withString: Links.connectingServices.absoluteString)
    }
    
    // MARK: - External Services Connect
    
    func wahooAction() {
        presentExternalServiceAuth(.wahoo)
    }
    
    func garminAction() {
        presentExternalServiceAuth(.garmin)
    }
    
    fileprivate func presentExternalServiceAuth(_ service: ExternalService) {
        let authenticationVC = ExternalServiceAuthViewController(with: service)
        authenticationVC.delegate = self
        present(authenticationVC, animated: true)
    }

    // MARK: - About

    func workWithUsAction() {
        openUrl(withString: Links.workWithUs.absoluteString)
    }

    func requestNewFeaturesAction() {
        openUrl(withString: Links.requestNewFeatures.absoluteString)
    }

    func storeAction() {
        openUrl(withString: Links.adStore.absoluteString)
    }

    func followAction() {
        openUrl(withString: Links.instagram.absoluteString)
    }

    func contactAction() {
        sendEmail(to: "support@anydistance.club")
    }

    func sendFeedbackAction() {
        sendEmail(to: "support@anydistance.club")
    }

    func deleteAccountAction() {
        let alert = UIAlertController(title: "Delete Account",
                                      message: "Deleting your account will permanently delete your personal information, goal data, and collectibles. Are you sure you want to continue? There is no undo.",
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete Account", style: .destructive, handler: { (action) in
            Task {
                do {
                    try await UserManager.shared.deleteUser(.current)
                    DispatchQueue.main.async {
                        self.transitionToSignIn()
                    }
                } catch {
                    DispatchQueue.main.async {
                        let errorAlert = UIAlertController.defaultWith(title: "Error",
                                                                       message: "There was an error deleting your account. Please try again later, and if the problem continues, email us at support@anydistance.club.")
                        self.present(errorAlert, animated: true, completion: nil)
                    }
                }
            }
        }))

        present(alert, animated: true, completion: nil)
    }

    // MARK: - Take Note

    func privacyCommitmentAction() {
        Analytics.logEvent("Privacy commitment", screenName, .buttonTap)
        openUrl(withString: Links.privacyCommitment.absoluteString)
    }

    func privacyPolicyAction() {
        Analytics.logEvent("Privacy policy", screenName, .buttonTap)
        openUrl(withString: Links.privacyPolicy.absoluteString)
    }

    func termsAction() {
        Analytics.logEvent("Terms and conditions", screenName, .buttonTap)
        openUrl(withString: Links.termsAndConditions.absoluteString)
    }

    // MARK: - Admin

    func showOnboardingAction() {
        let onboarding = OnboardingViewController()
        onboarding.modalPresentationStyle = .overFullScreen
        UIView.animate(withDuration: 0.2) {
            UIApplication.shared.topWindow?.alpha = 0.0
        } completion: { _ in
            UIApplication.shared.topWindow?.rootViewController = onboarding
            UIView.animate(withDuration: 0.2) {
                UIApplication.shared.topWindow?.alpha = 1.0
            }
        }
    }

    // MARK: - Danger Zone

    func recalculateCollectiblesAction() {
        let alert = UIAlertController(title: "Are you sure?", message: "This cannot be undone.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Proceed", style: .default, handler: { _ in
            self.recalculateCollectibles()
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func recalculateCollectibles() {
        Analytics.logEvent("Recalculate collectibles", screenName, .buttonTap)
        showActivityIndicator()
        Task(priority: .userInitiated) {
            HealthKitActivitiesStore.shared.daysToSync = 365 * 3 // 3 years
            ADUser.current.lastCollectiblesRefreshDate = nil
            await ActivitiesData.shared.load(updateUserAndCollectibles: true)
            DispatchQueue.main.async {
                HealthKitActivitiesStore.shared.daysToSync = 180
                self.hideActivityIndicator()
            }
        }
    }

    // MARK: - Other Actions

    private func transitionToSignIn() {
        let onboardingVC = UIHostingController(rootView: OnboardingView(model: OnboardingViewModel()))
        UIView.animate(withDuration: 0.2) {
            UIApplication.shared.topWindow?.alpha = 0.0
        } completion: { _ in
            UIApplication.shared.topWindow?.rootViewController = onboardingVC
            UIView.animate(withDuration: 0.2) {
                UIApplication.shared.topWindow?.alpha = 1.0
            }
        }
    }
}

extension SettingsViewController: ExternalServiceAuthViewControllerDelegate {
    func externalServiceAuthViewController(_ viewController: ExternalServiceAuthViewController,
                                           finishedWith authorization: ExternalServiceAuthorization) {
        let keychain = KeychainStore.shared
        do {
            try keychain.save(authorization: authorization)
        } catch {
            SentrySDK.capture(error: error)
        }
        
        // TODO: Get rid of this
        NotificationCenter.default.post(.connectionStateChanged)
        NotificationCenter.default.post(.externalServicesConnectionStateChanged)
    }
}
