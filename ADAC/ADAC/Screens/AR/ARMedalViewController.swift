// Licensed under the Any Distance Source-Available License
//
//  ARMedalViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/12/22.
//

import SwiftUI
import ARKit
import UIKit

final class ARMedalViewController: ARCollectibleViewController {
    override var showsWearableControls: Bool {
        return true
    }

    override init(_ collectible: Collectible, delegate: CollectibleAddToPostDelegate?) {
        let arView = WearableMedalARView()
        arView.setup(withCollectible: collectible, earned: true, engraveInitials: true)
        super.init(arView)
        addToPostDelegate = delegate
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func medalViewModeSwitched(_ viewMode: MedalARViewMode) {
        (arView as? WearableMedalARView)?.mode = viewMode
    }
}
