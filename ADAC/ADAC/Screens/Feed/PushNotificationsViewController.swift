// Licensed under the Any Distance Source-Available License
//
//  PushNotificationsViewController.swift
//  PushNotifications
//
//  Created by Daniel Kuntz on 9/19/21.
//

import UIKit
import OneSignal

final class PushNotificationsViewController: UIViewController {

    // MARK: - Constants

    private let screenName = "Need a Reminder?"

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        Analytics.logEvent(screenName, screenName, .screenViewed)
    }

    // MARK: - Actions

    @IBAction func closeTapped(_ sender: Any) {
        Analytics.logEvent("Close", screenName, .buttonTap)
        dismiss(animated: true, completion: nil)
    }

    @IBAction func allowTapped(_ sender: Any) {
        Analytics.logEvent("Allow Push Notifications", screenName, .buttonTap)

        OneSignal.promptForPushNotifications(userResponse: { [weak self] accepted in
            guard let self = self else { return }
            
            if accepted {
                Analytics.logEvent("Notifications Permission Granted", self.screenName, .otherEvent)
                
                DispatchQueue.main.async {
                    UserDefaults.standard.enableAllNotifications()
                    ActivitiesData.shared.startObservingNewActivities(for: .appleHealth)
                    self.dismiss(animated: true, completion: nil)
                }
            } else {
                Analytics.logEvent("Notifications Permission Denied", self.screenName, .otherEvent)
            }
        }, fallbackToSettings: true)
    }
    
}
