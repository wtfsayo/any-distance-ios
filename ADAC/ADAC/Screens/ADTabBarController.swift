// Licensed under the Any Distance Source-Available License
//
//  ADTabBarController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/20/24.
//

import UIKit

class ADTabBarController: UITabBarController {

    /// Gets the current tab bar instance for the app
    static var current: ADTabBarController? {
        return (UIApplication.shared.topWindow?.rootViewController as? UITabBarController) as? ADTabBarController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        var items = self.viewControllers
        if !ADUser.current.hasRegistered {
            items?.remove(at: 0)
            let lastIdx = items!.count - 1
            items?.remove(at: lastIdx)
        }
        setViewControllers(items, animated: false)
    }

    func setSelectedTab(_ selectedTab: ADTabBarControllerTab) {
        switch selectedTab {
        case .you:
            selectedViewController = viewControllers?.first(where: { $0 is ProfileViewController })
        case .track:
            selectedViewController = viewControllers?.first(where: { $0 is RecordingViewController })
        case .stats:
            selectedViewController = viewControllers?.first(where: { $0 is ActivityProgressViewController })
        }
    }
}

enum ADTabBarControllerTab {
    case you
    case track
    case stats
}
