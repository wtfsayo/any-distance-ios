// Licensed under the Any Distance Source-Available License
//
//  iPhonePreferences.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 11/29/22.
//

import Foundation
import WatchConnectivity

class iPhonePreferences: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = iPhonePreferences()

    private(set) var prefs: [String: Any] = UserDefaults.standard.watchPrefs {
        didSet {
            updateVariables()
            UserDefaults.standard.watchPrefs = prefs
        }
    }

    @Published private(set) var distanceUnit: DistanceUnit = .miles
    @Published private(set) var shouldClipRoute: Bool = false
    @Published private(set) var showsStepCount: Bool = true
    @Published private(set) var routeClipPercentage: Double = 0.1

    var routeClipDescriptionString: String {
        let percentString = String(Int(routeClipPercentage * 100))
        return "This will clip the first and last \(percentString)% of your route if you choose to share it."
    }

    override init() {
        super.init()
        WCSession.default.delegate = self
        WCSession.default.activate()
        updateVariables()
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String : Any]) {
        prefs = applicationContext
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sendLiveActivityData(for recorder: WatchActivityRecorder) {
        let attributes = RecordingLiveActivityAttributes(activityType: recorder.activityType,
                                                         unit: recorder.unit,
                                                         goal: recorder.goal)
        let state = RecordingLiveActivityAttributes.ContentState(uptime: 0.0,
                                                                 state: recorder.state.iPhoneRecordingState,
                                                                 duration: recorder.duration,
                                                                 distance: recorder.distanceInUnit,
                                                                 elevationAScended: recorder.elevationAscended,
                                                                 pace: recorder.pace,
                                                                 avgSpeed: recorder.avgSpeed,
                                                                 totalCalories: recorder.totalCalories,
                                                                 goalProgress: recorder.goalProgress)
        let data = RecordingLiveActivityData(attributes: attributes, state: state)
        if let encodedData = try? JSONEncoder().encode(data) {
            WCSession.default.sendMessage(["liveActivityData": encodedData],
                                          replyHandler: nil)
        }

        switch recorder.state {
        case .couldNotSave, .discarded, .saved:
            cancelActivityStartedToastOniPhone()
        default: break
        }
    }

    func triggerActivityStartedNotificationOniPhone() {
        WCSession.default.sendMessage(["startActivity": true],
                                      replyHandler: nil)
    }

    func cancelActivityStartedToastOniPhone() {
        WCSession.default.sendMessage(["endActivity": true],
                                      replyHandler: nil)
    }

    func setClipRoute(_ on: Bool) {
        shouldClipRoute = on
        sendPrefsToiPhone()
    }

    func setDistanceUnit(_ unit: DistanceUnit) {
        distanceUnit = unit
        sendPrefsToiPhone()
    }

    private func updateVariables() {
        distanceUnit = DistanceUnit(rawValue: prefs[WatchPreferencesKey.unit.rawValue] as? Int ?? 0) ?? distanceUnit
        shouldClipRoute = prefs[WatchPreferencesKey.clipsRoute.rawValue] as? Bool ?? shouldClipRoute
        showsStepCount = prefs[WatchPreferencesKey.showsStepCount.rawValue] as? Bool ?? showsStepCount
        routeClipPercentage = prefs[WatchPreferencesKey.routeClipPercentage.rawValue] as? Double ?? routeClipPercentage
    }

    private func sendPrefsToiPhone() {
        let prefs: [String: Any] = [WatchPreferencesKey.unit.rawValue: distanceUnit.rawValue,
                                    WatchPreferencesKey.clipsRoute.rawValue: shouldClipRoute,
                                    WatchPreferencesKey.showsStepCount.rawValue: showsStepCount,
                                    WatchPreferencesKey.routeClipPercentage.rawValue: routeClipPercentage]

        do {
            try WCSession.default.updateApplicationContext(prefs)
            print("Transferring user preferences to iPhone: \(prefs)")
            self.prefs = prefs
        } catch {
            print(error.localizedDescription)
        }
    }
}

fileprivate extension UserDefaults {
    var watchPrefs: [String: Any] {
        get {
            return dictionary(forKey: "watchPrefs") ?? [:]
        }

        set {
            set(newValue, forKey: "watchPrefs")
        }
    }
}
