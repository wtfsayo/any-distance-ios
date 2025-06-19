// Licensed under the Any Distance Source-Available License
//
//  PushNotificationsViewController.swift
//  PushNotifications
//
//  Created by Daniel Kuntz on 9/19/21.
//

import UIKit
import OneSignal

final class PushNotificationsViewController: SwiftUIViewController<PushNotificationsView> {
    override func createSwiftUIView() {
        self.swiftUIView = PushNotificationsView()
    }
}
