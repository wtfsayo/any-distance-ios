// Licensed under the Any Distance Source-Available License
//
//  SceneKitCleaner.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/14/22.
//

import Foundation
import SceneKit

class SceneKitCleaner {
    static let shared = SceneKitCleaner()

    private var displayLink: CADisplayLink?
    private var views: [ViewWrapper] = []

    init() {
        displayLink = CADisplayLink(target: self, selector: #selector(self.cleanupSceneKitViews))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func cleanupSceneKitViews() {
        views = views.filter { $0.view != nil }
        for wrapper in views {
            if let collectible3DView = wrapper.view as? Collectible3DView {
                collectible3DView.cleanupOrSetupIfNecessary()
            } else if let gearView = wrapper.view as? Gear3DView {
                gearView.cleanupOrSetupIfNecessary()
            }
        }
    }

    func add(_ view: UIView) {
        if !views.contains(where: { $0.view === view }) {
            views.append(ViewWrapper(view))
        }
    }
}

fileprivate class ViewWrapper {
    weak var view: UIView?
    init(_ view: UIView) {
        self.view = view
    }
}
