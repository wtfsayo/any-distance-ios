// Licensed under the Any Distance Source-Available License
//
//  WatchPreferences.swift
//  ADAC
//
//  Created by Daniel Kuntz on 11/29/22.
//

import UIKit
import WatchConnectivity
import Sentry
import ActivityKit
import UserNotifications
import Combine

class WatchPreferences: NSObject {
    static let shared = WatchPreferences()

    @available(iOS 16.1, *)
    var liveActivity: ActivityKit.Activity<RecordingLiveActivityAttributes>? {
        get {
            return _liveActivity as? ActivityKit.Activity<RecordingLiveActivityAttributes>
        }

        set {
            _liveActivity = newValue
        }
    }
    var _liveActivity: Any?
    private var shouldShowToastOnNextLaunch: Bool = false
    private var observers: Set<AnyCancellable> = []

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            if WCSession.default.activationState != .activated {
                WCSession.default.activate()
            }
        }

        NotificationCenter
            .default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                if self.shouldShowToastOnNextLaunch {
                    self.showActivityStartedToast()
                    self.shouldShowToastOnNextLaunch = false
                }
            }.store(in: &observers)
    }

    func sendPreferencesToWatch() {
        guard WCSession.isSupported() else {
            return
        }

        let prefs: [String: Any] = [WatchPreferencesKey.unit.rawValue: (ADUser.current.distanceUnit).rawValue,
                                    WatchPreferencesKey.clipsRoute.rawValue: NSUbiquitousKeyValueStore.default.defaultRecordingSettings.clipRoute,
                                    WatchPreferencesKey.showsStepCount.rawValue: NSUbiquitousKeyValueStore.default.shouldShowStepCount,
                                    WatchPreferencesKey.routeClipPercentage.rawValue: NSUbiquitousKeyValueStore.default.defaultRecordingSettings.routeClipPercentage]
        do {
            try WCSession.default.updateApplicationContext(prefs)
            print("Transferring user preferences to watch: \(prefs)")
        } catch {
            SentrySDK.capture(error: error)
            print(error.localizedDescription)
        }
    }
}

extension WatchPreferences: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        sendPreferencesToWatch()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String : Any]) {
        if let clipRoute = applicationContext[WatchPreferencesKey.clipsRoute.rawValue] as? Bool {
            NSUbiquitousKeyValueStore.default.defaultRecordingSettings.clipRoute = clipRoute
        }

        if let routeClipPercentage = applicationContext[WatchPreferencesKey.routeClipPercentage.rawValue] as? Double {
            NSUbiquitousKeyValueStore.default.defaultRecordingSettings.routeClipPercentage = routeClipPercentage
        }

        if let unit = applicationContext[WatchPreferencesKey.unit.rawValue] as? Int,
           let distanceUnit = DistanceUnit(rawValue: unit) {
            ADUser.current.distanceUnit = distanceUnit
            UserManager.shared.updateCurrentUser()
            NotificationCenter.default.post(.goalTypeChanged)
        }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any]) {
        if let liveActivityData = message["liveActivityData"] as? Data,
           let decodedData = try? JSONDecoder().decode(RecordingLiveActivityData.self,
                                                       from: liveActivityData) {
            LiveActivityManager.shared.updateForWatchActivity(with: decodedData)
        } else if message["startActivity"] != nil {
            sendNotification(with: "Activity started!",
                             body: "Tap to open the 📱 app and see this activity on your lock screen.",
                             afterTime: 1.0)
            showActivityStartedToast()
        } else if message["endActivity"] != nil {
            cancelActivityStartedToastOnNextLaunch()
        }
    }

    private func sendNotification(with title: String, body: String = "", afterTime time: TimeInterval = 0) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        content.interruptionLevel = .timeSensitive
        let trigger = time > 0 ? UNTimeIntervalNotificationTrigger(timeInterval: time, repeats: false) : nil
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("ERROR!")
                print(error.localizedDescription)
            }
        }
    }

    func showActivityStartedToast() {
        if UIApplication.shared.applicationState != .active {
            shouldShowToastOnNextLaunch = true
            return
        }

        DispatchQueue.main.async {
            let toastModel = ToastView.Model(title: "Activity Started on Watch",
                                             description: "Check your progress on your lock screen",
                                             image: UIImage(systemName: "applewatch"),
                                             autohide: true)
            let toast = ToastView(model: toastModel,
                                  imageTint: .white,
                                  borderTint: .systemGreen)
            let insets = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
            UIApplication.shared.topViewController?.view.present(toast: toast, insets: insets)
        }
    }

    func cancelActivityStartedToastOnNextLaunch() {
        shouldShowToastOnNextLaunch = false
    }
}

