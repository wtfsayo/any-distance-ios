// Licensed under the Any Distance Source-Available License
//
//  ScreenshotObserver.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/27/24.
//

import UIKit

class ScreenshotObserver {
    static let shared = ScreenshotObserver()

    init() {
        NotificationCenter.default.addObserver(self, 
                                               selector: #selector(screenshotDetected),
                                               name: UIApplication.userDidTakeScreenshotNotification,
                                               object: nil)
    }

    @objc func screenshotDetected() {
        var vc: UIViewController?
        if let tabBar = UIApplication.shared.topViewController as? ADTabBarController {
            vc = tabBar.selectedViewController
        } else {
            vc = UIApplication.shared.topViewController
        }

        if let navVC = vc as? UINavigationController {
            vc = navVC.visibleViewController
        }

        if let recordingVC = vc as? RecordingViewController,
           let model = recordingVC.model {
            Analytics.logEvent("Screenshot", "Screenshot", .otherEvent,
                               withParameters: ["viewController": description(for: vc),
                                                "recorderState": model.recorder.state.displayName])
        } else {
            Analytics.logEvent("Screenshot", "Screenshot", .otherEvent,
                               withParameters: ["viewController": description(for: vc)])
        }
    }

    private func description(for viewController: UIViewController?) -> String {
        guard let description = viewController?.description.split(separator: " ").first else { return "" }
        return String(description).trimmingCharacters(in: CharacterSet(charactersIn: "<:"))
    }
}
