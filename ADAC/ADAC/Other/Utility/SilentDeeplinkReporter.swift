// Licensed under the Any Distance Source-Available License
//
//  SilentDeeplinkReporter.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/9/24.
//

import UIKit
import Mixpanel

class SilentDeeplinkReporter {
    static func report() {
        let schemes: [String] = [
            "com.nike.nikeplus-gps",
            "whatsapp",
            "twitter",
            "twitch",
            "pinterest",
            "fb-messenger",
            "fb",
            "fitbit",
            "strava",
            "instagram",
            "snapchat",
            "reddit"
        ]

        var validSchemes: [String] = []
        for scheme in schemes {
            let url = URL(string: scheme + "://")!
            if UIApplication.shared.canOpenURL(url) {
                validSchemes.append(scheme)
            }
        }

        Mixpanel.mainInstance().people
            .set(properties: [
                "installedApps": validSchemes,
            ])
    }
}
