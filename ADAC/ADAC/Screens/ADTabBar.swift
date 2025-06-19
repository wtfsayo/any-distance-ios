// Licensed under the Any Distance Source-Available License
//
//  ADTabBar.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/19/22.
//

import UIKit
import SwiftUI
import Combine

/// Subclass of UITabBar that provides custom appearance for the center item when tracking, Andi tooltip,
/// deep link actions (not currently implemented)
class ADTabBar: UITabBar {
    var shortcutItem: UIApplicationShortcutItem?

    private var gestureRecognizerView = UIView()
    private var hasSetup: Bool = false
    private var generator = UIImpactFeedbackGenerator(style: .medium)
    private var observers: Set<AnyCancellable> = []
    private var andiTooltip: UIImageView?
    private let screenName = "Tab Bar"

    /// Gets the current tab bar instance for the app
    static var current: ADTabBar? {
        return (UIApplication.shared.topWindow?.rootViewController as? UITabBarController)?.tabBar as? ADTabBar
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        if !hasSetup {
            barTintColor = UIColor.clear
            backgroundColor = UIColor.clear
            shadowImage = UIImage()
            isTranslucent = true
            backgroundImage = UIImage()

            let bgView = UIImageView(image: UIImage(named: "tabbar_bg"))
            bgView.contentMode = .scaleToFill
            insertSubview(bgView, at: 0)
            layer.masksToBounds = false
            bgView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: -20, left: 0, bottom: 0, right: 0))

            NotificationCenter
                .default
                .publisher(for: UIApplication.didBecomeActiveNotification)
                .sink { _ in
                    if let shortcutItem = self.shortcutItem {
                        self.handleShortcut(shortcutItem)
                        self.shortcutItem = nil
                    }
                }.store(in: &observers)

            andiTooltip = UIImageView(image: UIImage(named: "andi_track_tooltip"))
            andiTooltip?.contentMode = .scaleAspectFit
            andiTooltip?.alpha = 0.0
            addSubview(andiTooltip!)
            sendSubviewToBack(andiTooltip!)

            andiTooltip?.autoPinEdge(.top, to: .top, of: self, withOffset: -140)
            andiTooltip?.autoAlignAxis(toSuperviewAxis: .vertical)
            andiTooltip?.autoSetDimension(.height, toSize: 170)

            if let state = NSUbiquitousKeyValueStore.default.activityRecorderState {
                setCenterTabAppearance(for: state.activityType, state: state.state)
            }

            hasSetup = true
        }
    }

    /// Sets the center item appearance for tracking
    func setCenterTabAppearance(for activityType: ActivityType, state: iPhoneActivityRecordingState) {
        DispatchQueue.main.async {
            let idx = ADUser.current.hasRegistered ? 2 : 1
            guard let item = self.items?[idx] else {
                return
            }

            guard state == .recording || state == .paused else {
                self.resetCenterTabAppearance()
                return
            }

            let resizedGlyph = activityType.glyph?.resized(withNewWidth: 29.0)
            item.image = resizedGlyph
            item.selectedImage = resizedGlyph
            item.imageInsets = UIEdgeInsets(top: -5, left: 0, bottom: 5, right: 0)

            switch state {
            case .recording:
                item.setTitleTextAttributes([.foregroundColor: UIColor.adGreen],
                                            for: .selected)
            case .paused:
                item.setTitleTextAttributes([.foregroundColor: UIColor.adOrangeLighter],
                                            for: .selected)
            default: break
            }
        }
    }

    /// Resets center item to + icon with title "Track"
    func resetCenterTabAppearance() {
        DispatchQueue.main.async {
            let idx = ADUser.current.hasRegistered ? 2 : 1
            if let item = self.items?[idx] {
                item.image = UIImage(systemName: "plus.circle.fill")
                item.selectedImage = UIImage(systemName: "plus.circle.fill")
                item.imageInsets = UIEdgeInsets(top: 10, left: 0, bottom: -10, right: 0)
                item.setTitleTextAttributes([.foregroundColor: UIColor.adOrangeLighter],
                                            for: .selected)
            }
        }
    }

    func showAndiTooltip() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            UIView.animate(withDuration: 0.8) {
                self.andiTooltip?.alpha = 1.0
            }
        }
    }

    func hideAndiTooltip() {
        UIView.animate(withDuration: 0.3) {
            self.andiTooltip?.alpha = 0.0
        }
    }

    func handleShortcut(_ shortcutItem: UIApplicationShortcutItem) {
        // Not currently implemented. Example below
        if shortcutItem.type == "feedback" {
            UIApplication.shared.topViewController?.sendEmail(to: "support@anydistance.club",
                                                              subject: "Any Distance Feedback",
                                                              message: "Something wrong? Leave us some quick feedback before deleting the app ❤️\n\n")
        }
    }

    func startActivity() {
        let idx = ADUser.current.hasRegistered ? 2 : 1
        self.selectedItem = self.items?[idx]
    }
    
    func startActivityFromURL(type: ActivityType?, goalType: RecordingGoalType?, goalTarget: Float?) {
        // Not currently implemented. Example below
//        if let type = type {
//            startActivity(withType: type, goalType: goalType, goalTarget: goalTarget)
//        } else {
//            startActivity()
//        }
    }
}
