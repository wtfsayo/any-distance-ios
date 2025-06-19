// Licensed under the Any Distance Source-Available License
//
//  ARCollectibleViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/11/22.
//

import SwiftUI
import ARKit
import UIKit

protocol CollectibleAddToPostDelegate: AnyObject {
    func addPhotoToPost(_ image: UIImage, forCollectible collectible: Collectible)
    func addVideoToPost(withUrl url: URL, forCollectible collectible: Collectible)
}

class ARCollectibleViewController: ARViewController<CollectibleARSCNView> {
    weak var addToPostDelegate: CollectibleAddToPostDelegate?

    override var shareScreenShowsAddToPostButton: Bool {
        return addToPostDelegate != nil
    }

    override init(_ arView: CollectibleARSCNView) {
        super.init(arView)
    }

    init(_ collectible: Collectible, delegate: CollectibleAddToPostDelegate?) {
        let arView = CollectibleARSCNView()
        arView.setup(withCollectible: collectible, earned: true, engraveInitials: true)
        addToPostDelegate = delegate
        super.init(arView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func addToPost(_ image: UIImage) {
        if let collectible = arView?.collectible {
            addToPostDelegate?.addPhotoToPost(image, forCollectible: collectible)
        }
    }

    override func addToPost(_ videoUrl: URL) {
        if let collectible = arView?.collectible {
            addToPostDelegate?.addVideoToPost(withUrl: videoUrl, forCollectible: collectible)
        }
    }
}
